import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/item.dart';

/// 税込合計の表示ウィジェット（タブ直下固定）
///
/// price は税込単価として保存されているため、合計 = sum(price × quantity)。
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '未購入 ¥${fmt.format(_sum(unchecked))}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '購入済 ¥${fmt.format(_sum(checked))}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
