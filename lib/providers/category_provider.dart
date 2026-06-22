import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    return _fetch();
  }

  Future<List<Category>> _fetch() async {
    final rows = await DatabaseHelper.instance.getCategories();
    return rows.map(Category.fromMap).toList();
  }

  // addCategory は作成した id を返す（ダイアログでドロップダウン選択状態にするため）。
  Future<int> addCategory(String name) async {
    final id = await DatabaseHelper.instance.insertCategory(name);
    state = AsyncData(await _fetch());
    return id;
  }

  Future<void> deleteCategory(int id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    state = AsyncData(await _fetch());
  }
}

final categoryProvider =
    AsyncNotifierProvider<CategoryNotifier, List<Category>>(
  CategoryNotifier.new,
);
