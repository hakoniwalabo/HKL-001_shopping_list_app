import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/item.dart';

/// 税込合計の表示ウィジェット（タブ直下固定）
///
/// price は税込単価として保存されているため、合計 = sum(price × quantity)。
/// 未購入合計／購入済合計が0円のときは「未購入 -」「購入済 -」と表示する。
class TotalSummary extends StatelessWidget {
  final List<Item> items;

  const TotalSummary({super.key, required this.items});

  static int _sum(List<Item> items) =>
      items.fold(0, (s, e) => s + e.price * e.quantity);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final unchecked = items.where((e) => !e.isChecked).toList();
    final checked = items.where((e) => e.isChecked).toList();

    final uncheckedSum = _sum(unchecked);
    final checkedSum = _sum(checked);
    final uncheckedText =
        uncheckedSum > 0 ? '未購入 ¥${fmt.format(uncheckedSum)}' : '未購入 -';
    final checkedText =
        checkedSum > 0 ? '購入済 ¥${fmt.format(checkedSum)}' : '購入済 -';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            uncheckedText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            checkedText,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
