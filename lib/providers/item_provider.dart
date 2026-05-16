import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/item.dart';

class ItemNotifier extends AsyncNotifier<List<Item>> {
  @override
  Future<List<Item>> build() async {
    return await DatabaseHelper.instance.getItems();
  }

  Future<void> refreshItems() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      return await DatabaseHelper.instance.getItems();
    });
  }

  Future<void> addItem(Item item) async {
    final current = state.value ?? [];

    item.sortOrder = current.length;

    await DatabaseHelper.instance.insertItem(item);

    await refreshItems();
  }

  Future<void> updateItem(Item item) async {
    await DatabaseHelper.instance.updateItem(item);

    await refreshItems();
  }

  Future<void> toggleCheck(int id) async {
    final current = state.valueOrNull ?? [];

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
    final current = state.valueOrNull ?? [];

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
    final current = state.valueOrNull ?? [];

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

    return deletedItem;
  }

  Future<List<Item>> deleteCheckedItemsWithUndo() async {
    final current = state.valueOrNull ?? [];

    final checkedItems = current.where((e) => e.isChecked).toList();

    final uncheckedItems = current.where((e) => !e.isChecked).toList();

    state = AsyncData(uncheckedItems);

    await DatabaseHelper.instance.deleteCheckedItems();

    return checkedItems;
  }

  Future<void> deleteItem(int id) async {
    await DatabaseHelper.instance.deleteItem(id);

    await refreshItems();
  }

  Future<void> updateSortOrders(List<Item> items) async {
    await DatabaseHelper.instance.updateSortOrders(items);

    await refreshItems();
  }

  Future<void> deleteCheckedItems() async {
    await DatabaseHelper.instance.deleteCheckedItems();

    await refreshItems();
  }

  Future<void> restoreItem(Item item) async {
    await DatabaseHelper.instance.insertItemWithId(item);

    await refreshItems();
  }

  Future<void> restoreItemWithOrder(Item item) async {
    await DatabaseHelper.instance.insertItemWithId(item);

    await refreshItems();

    await normalizeSortOrder();
  }

  Future<void> normalizeSortOrder() async {
    final items = state.value ?? [];

    for (int i = 0; i < items.length; i++) {
      items[i].sortOrder = i;
    }

    await DatabaseHelper.instance.updateSortOrders(items);

    state = AsyncData([...items]);
  }
}

final itemProvider = AsyncNotifierProvider<ItemNotifier, List<Item>>(
  ItemNotifier.new,
);
