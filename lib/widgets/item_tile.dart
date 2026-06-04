import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/item.dart';

class ItemTile extends StatelessWidget {
  final Item item;
  final int? reorderIndex;
  final NumberFormat numberFormat;

  final VoidCallback onTap;

  final Future<void> Function() onDismissed;

  final Future<void> Function(bool?) onToggleCheck;

  final VoidCallback? onMoveToTab;

  const ItemTile({
    super.key,
    required this.item,
    required this.numberFormat,
    required this.onTap,
    required this.onDismissed,
    required this.onToggleCheck,
    this.reorderIndex,
    this.onMoveToTab,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${item.id}_${item.isChecked}'),
      direction: DismissDirection.endToStart,

      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text('削除', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),

      onDismissed: (_) async {
        await onDismissed();
      },

      child: ListTile(
        leading: Checkbox(value: item.isChecked, onChanged: onToggleCheck),

        onTap: onTap,
        onLongPress: onMoveToTab,

        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : null,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '単価: ¥${numberFormat.format(item.price)} / '
              '個数: ${item.quantity} / '
              '税込合計: ¥${numberFormat.format(item.price * item.quantity)}',
            ),

            if (item.memo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.memo,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),

        trailing: reorderIndex != null
            ? ReorderableDragStartListener(
                index: reorderIndex!,
                child: const Icon(Icons.drag_handle),
              )
            : null,
      ),
    );
  }
}
