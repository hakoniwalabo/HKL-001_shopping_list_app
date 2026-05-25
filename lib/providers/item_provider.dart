import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/item.dart';

class ItemNotifier extends AsyncNotifier<List<Item>> {
  int currentListId = 1;
  @override
  Future<List<Item>> build() async {
    await DatabaseHelper.instance.normalizeAllSortOrders(currentListId);

    return DatabaseHelper.instance.getItemsByListId(currentListId);
  }

  Future<void> changeList(int listId) async {
    currentListId = listId;

    state = const AsyncLoading();

    final items = await DatabaseHelper.instance.getItemsByListId(listId);

    state = AsyncData(items);
  }

  Future<void> addItem(Item item) async {
    final current = state.value ?? [];

    final newItem = item.copyWith(
      sortOrder: current.length,
      listId: currentListId,
    );

    final id = await DatabaseHelper.instance.insertItem(newItem);

    final insertedItem = newItem.copyWith(id: id);

    state = AsyncData([...current, insertedItem]);
  }

  Future<void> updateItem(Item item) async {
    final current = state.value ?? [];

    final updated = current.map((e) {
      if (e.id == item.id) {
        return item;
      }

      return e;
    }).toList();

    state = AsyncData(updated);

    await DatabaseHelper.instance.updateItem(item);
  }

  Future<void> toggleCheck(int id) async {
    final current = state.value ?? [];

    final updated = current.map((item) {
      if (item.id == id) {
        return item.copyWith(isChecked: !item.isChecked);
      }

      return item;
    }).toList();

    state = AsyncData(updated);

    final target = updated.firstWhere((e) => e.id == id);

    await DatabaseHelper.instance.updateItem(target);
  }

  Future<void> reorderUncheckedItems(int oldIndex, int newIndex) async {
    final current = state.value ?? [];

    final unchecked = current.where((e) => !e.isChecked).toList();

    final checked = current.where((e) => e.isChecked).toList();

    if (newIndex > oldIndex) {
      newIndex--;
    }

    final movedItem = unchecked.removeAt(oldIndex);

    unchecked.insert(newIndex, movedItem);

    final merged = [...unchecked, ...checked];

    final updated = <Item>[];

    for (int i = 0; i < merged.length; i++) {
      updated.add(merged[i].copyWith(sortOrder: i));
    }

    state = AsyncData(updated);

    await DatabaseHelper.instance.updateSortOrders(updated);
  }

  Future<Item?> deleteItemById(int id) async {
    final current = state.value ?? [];

    Item? deletedItem;

    final updated = current.where((item) {
      final shouldKeep = item.id != id;

      if (!shouldKeep) {
        deletedItem = item;
      }

      return shouldKeep;
    }).toList();

    state = AsyncData(updated);

    await DatabaseHelper.instance.deleteItem(id);

    await DatabaseHelper.instance.normalizeAllSortOrders(currentListId);

    final refreshed = await DatabaseHelper.instance.getItemsByListId(
      currentListId,
    );

    state = AsyncData(refreshed);

    return deletedItem;
  }

  Future<List<Item>> deleteCheckedItemsWithUndo() async {
    final current = state.value ?? [];

    final checkedItems = current.where((e) => e.isChecked).toList();

    final uncheckedItems = current.where((e) => !e.isChecked).toList();

    state = AsyncData(uncheckedItems);

    await DatabaseHelper.instance.deleteCheckedItems(currentListId);

    await DatabaseHelper.instance.normalizeAllSortOrders(currentListId);

    final refreshed = await DatabaseHelper.instance.getItemsByListId(
      currentListId,
    );

    state = AsyncData(refreshed);

    return checkedItems;
  }

  Future<void> restoreItemWithOrder(Item item) async {
    await DatabaseHelper.instance.insertItemWithId(
      item.copyWith(listId: currentListId),
    );

    await DatabaseHelper.instance.normalizeAllSortOrders(currentListId);

    final refreshed = await DatabaseHelper.instance.getItemsByListId(
      currentListId,
    );

    state = AsyncData(refreshed);
  }
}

final itemProvider = AsyncNotifierProvider<ItemNotifier, List<Item>>(
  ItemNotifier.new,
);
