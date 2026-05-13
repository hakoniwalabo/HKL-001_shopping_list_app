import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/item.dart';

final itemListProvider = FutureProvider<List<Item>>((ref) async {
  return await DatabaseHelper.instance.getItems();
});
