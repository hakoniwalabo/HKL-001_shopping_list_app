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
