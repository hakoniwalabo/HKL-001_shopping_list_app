import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// リストごとの予算表示ウィジェット（TotalSummary直上・独立した1行）
///
/// budget が0円のときは「未設定」として扱い、「予算 -」と表示する。
class BudgetSummary extends StatelessWidget {
  final int budget;
  final VoidCallback onTap;

  const BudgetSummary({
    super.key,
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final text = budget == 0 ? '予算 -' : '予算 ¥${fmt.format(budget)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
