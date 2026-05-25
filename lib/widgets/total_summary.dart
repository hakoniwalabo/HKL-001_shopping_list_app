import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/item.dart';

class TotalSummary extends StatelessWidget {
  final List<Item> items;
  final bool showDetailedTotal;
  final VoidCallback onToggle;
  final numberFormat = NumberFormat('#,###');

  List<Item> uncheckedItems(List<Item> items) =>
      items.where((e) => !e.isChecked).toList();

  List<Item> checkedItems(List<Item> items) =>
      items.where((e) => e.isChecked).toList();

  int uncheckedSubtotal(List<Item> items) =>
      uncheckedItems(items).fold(0, (s, e) => s + (e.price * e.quantity));

  double uncheckedTotal(List<Item> items) => uncheckedItems(
    items,
  ).fold(0, (s, e) => s + (e.price * e.quantity) * (1 + e.taxRate));

  int checkedSubtotal(List<Item> items) =>
      checkedItems(items).fold(0, (s, e) => s + (e.price * e.quantity));

  double checkedTotal(List<Item> items) => checkedItems(
    items,
  ).fold(0, (s, e) => s + (e.price * e.quantity) * (1 + e.taxRate));

  TotalSummary({
    super.key,
    required this.items,
    required this.showDetailedTotal,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),

        onTap: onToggle,

        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),

          crossFadeState: showDetailedTotal
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,

          firstChild: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '未購入 ¥${numberFormat.format(uncheckedTotal(items).toInt())}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                Text(
                  '購入済 ¥${numberFormat.format(checkedTotal(items).toInt())}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          secondChild: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  '未購入',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                Text(
                  '税別 ¥${numberFormat.format(uncheckedSubtotal(items).toInt())}',
                ),

                Text(
                  '税込 ¥${numberFormat.format(uncheckedTotal(items).toInt())}',
                ),

                const SizedBox(height: 12),

                Text(
                  '購入済',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),

                Text(
                  '税別 ¥${numberFormat.format(checkedSubtotal(items).toInt())}',
                ),

                Text('税込 ¥${numberFormat.format(checkedTotal(items).toInt())}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
