import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/item.dart';
import 'item_tile.dart';

class ListSection extends StatelessWidget {
  final String title;
  final List<Item> items;
  final bool reorderable;

  final NumberFormat numberFormat;

  final Future<void> Function(int oldIndex, int newIndex)? onReorder;

  final Future<void> Function(Item item) onToggleCheck;

  final Future<void> Function(Item item) onDelete;

  final VoidCallback Function(Item item) onTap;

  final VoidCallback Function(Item item)? onMoveToTab;

  const ListSection({
    super.key,
    required this.title,
    required this.items,
    required this.reorderable,
    required this.numberFormat,
    required this.onToggleCheck,
    required this.onDelete,
    required this.onTap,
    this.onReorder,
    this.onMoveToTab,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.all(8),

          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        if (reorderable)
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),

            onReorderItem: (oldIndex, newIndex) async {
              if (onReorder != null) {
                await onReorder!(oldIndex, newIndex);
              }
            },

            children: [
              for (int i = 0; i < items.length; i++)
                ItemTile(
                  key: ValueKey(items[i].id),

                  item: items[i],

                  reorderIndex: i,

                  numberFormat: numberFormat,

                  onTap: onTap(items[i]),

                  onToggleCheck: (value) async {
                    await onToggleCheck(items[i]);
                  },

                  onDismissed: () async {
                    await onDelete(items[i]);
                  },

                  onMoveToTab: onMoveToTab != null
                      ? onMoveToTab!(items[i])
                      : null,
                ),
            ],
          )
        else
          ...items.map(
            (item) => ItemTile(
              key: ValueKey(item.id),

              item: item,

              numberFormat: numberFormat,

              onTap: onTap(item),

              onToggleCheck: (value) async {
                await onToggleCheck(item);
              },

              onDismissed: () async {
                await onDelete(item);
              },

              onMoveToTab: onMoveToTab != null ? onMoveToTab!(item) : null,
            ),
          ),
      ],
    );
  }
}
