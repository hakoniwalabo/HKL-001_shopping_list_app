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
  final VoidCallback? onAddToFavorites;

  const ItemTile({
    super.key,
    required this.item,
    required this.numberFormat,
    required this.onTap,
    required this.onDismissed,
    required this.onToggleCheck,
    this.reorderIndex,
    this.onMoveToTab,
    this.onAddToFavorites,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = item.price > 0 ? '¥${numberFormat.format(item.price)}' : '-';
    final totalText = item.price > 0
        ? '¥${numberFormat.format(item.price * item.quantity)}'
        : '-';
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
        onLongPress: (onMoveToTab == null && onAddToFavorites == null)
            ? null
            : () async {
                final result = await showModalBottomSheet<String>(
                  context: context,
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onMoveToTab != null)
                        ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: const Text('別タブに移動'),
                          onTap: () => Navigator.pop(context, 'move'),
                        ),
                      if (onAddToFavorites != null)
                        ListTile(
                          leading: const Icon(Icons.star_outline),
                          title: const Text('よく買うものに登録'),
                          onTap: () => Navigator.pop(context, 'favorite'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.close),
                        title: const Text('キャンセル'),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
                if (result == 'move') onMoveToTab?.call();
                if (result == 'favorite') onAddToFavorites?.call();
              },

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
              '個数: ${item.quantity} / '
              '単価: $priceText / '
              '税込合計: $totalText',
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
