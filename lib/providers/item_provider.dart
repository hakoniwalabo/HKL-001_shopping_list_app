import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/item.dart';

class ItemNotifier extends AsyncNotifier<List<Item>> {
  int currentListId = 1;

  @override
  Future<List<Item>> build() async {
    // normalizeAllSortOrders は reorder 時のみ実施。起動時は不要
    return DatabaseHelper.instance.getItemsByListId(currentListId);
  }

  Future<void> changeList(int listId) async {
    currentListId = listId;
    state = const AsyncLoading();
    final items = await DatabaseHelper.instance.getItemsByListId(listId);
    state = AsyncData(items);
  }

  Future<void> addItem(Item item) async {
    // sortOrder は現在の末尾 + 1（state が null なら 0）
    final current = state.value ?? [];
    final maxSortOrder = current.isEmpty
        ? 0
        : current.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final newItem = item.copyWith(
      listId: currentListId,
      sortOrder: maxSortOrder,
    );

    // DB書き込み → 再取得 → state更新（1回のみ）
    await DatabaseHelper.instance.insertItem(newItem);
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);
  }

  Future<void> updateItem(Item item) async {
    await DatabaseHelper.instance.updateItem(item);
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);
  }

  Future<void> toggleCheck(int id) async {
    final current = state.value ?? [];
    final target = current.firstWhere((e) => e.id == id);
    final toggled = target.copyWith(isChecked: !target.isChecked);

    // DB書き込みを先に行い、UIはDB取得後に1回だけ更新
    await DatabaseHelper.instance.updateItem(toggled);
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);
  }

  Future<void> reorderUncheckedItems(int oldIndex, int newIndex) async {
    final current = state.value ?? [];
    final unchecked = current.where((e) => !e.isChecked).toList();
    final checked = current.where((e) => e.isChecked).toList();

    // onReorderItem は removal 後の挿入インデックスを返すため、
    // onReorder と異なり newIndex-- の補正は不要
    final movedItem = unchecked.removeAt(oldIndex);
    unchecked.insert(newIndex, movedItem);

    final merged = [...unchecked, ...checked];
    final updated = <Item>[];
    for (int i = 0; i < merged.length; i++) {
      updated.add(merged[i].copyWith(sortOrder: i));
    }

    // reorder は即時フィードバックが重要なので optimistic update を維持
    state = AsyncData(updated);
    await DatabaseHelper.instance.updateSortOrders(updated);
  }

  Future<Item?> deleteItemById(int id) async {
    // 削除対象を先に取得（Undo用）
    final current = state.value ?? [];
    Item? deletedItem;
    for (final item in current) {
      if (item.id == id) {
        deletedItem = item;
        break;
      }
    }

    // normalizeAllSortOrders は不要（sortOrder に gap があっても表示・reorder に影響しない）
    await DatabaseHelper.instance.deleteItem(id);
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);

    return deletedItem;
  }

  Future<List<Item>> deleteCheckedItemsWithUndo() async {
    // 削除対象を先に取得（Undo用）
    final current = state.value ?? [];
    final checkedItems = current.where((e) => e.isChecked).toList();

    await DatabaseHelper.instance.deleteCheckedItems(currentListId);
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);

    return checkedItems;
  }

  Future<void> moveItemToList(int itemId, int targetListId) async {
    await DatabaseHelper.instance.updateItemListId(itemId, targetListId);
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);
  }

  Future<void> restoreItemWithOrder(Item item) async {
    await DatabaseHelper.instance.insertItemWithId(
      item.copyWith(listId: currentListId),
    );
    // normalize しないことで sortOrder が復元され、元の位置に戻る
    final refreshed =
        await DatabaseHelper.instance.getItemsByListId(currentListId);
    state = AsyncData(refreshed);
  }
}

final itemProvider = AsyncNotifierProvider<ItemNotifier, List<Item>>(
  ItemNotifier.new,
);
