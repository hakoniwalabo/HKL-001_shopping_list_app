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

    final newItem = item.copyWith(sortOrder: current.length);

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

    return deletedItem;
  }

  Future<List<Item>> deleteCheckedItemsWithUndo() async {
    final current = state.value ?? [];

    final checkedItems = current.where((e) => e.isChecked).toList();

    final uncheckedItems = current.where((e) => !e.isChecked).toList();

    state = AsyncData(uncheckedItems);

    await DatabaseHelper.instance.deleteCheckedItems();

    return checkedItems;
  }

  Future<void> deleteItem(int id) async {
    final current = state.value ?? [];

    final updated = current.where((e) => e.id != id).toList();

    state = AsyncData(updated);

    await DatabaseHelper.instance.deleteItem(id);
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
    final current = state.value ?? [];

    await DatabaseHelper.instance.insertItemWithId(item);

    final updated = [...current, item]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    state = AsyncData(updated);
  }
}

final itemProvider = AsyncNotifierProvider<ItemNotifier, List<Item>>(
  ItemNotifier.new,
);
