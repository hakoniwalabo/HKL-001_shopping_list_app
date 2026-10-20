import 'package:flutter/material.dart';

import '../models/shopping_list.dart';

class ListReorderBar extends StatelessWidget implements PreferredSizeWidget {
  final List<ShoppingList> shoppingLists;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const ListReorderBar({
    super.key,
    required this.shoppingLists,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (shoppingLists.isEmpty) {
      return const SizedBox.shrink();
    }

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      itemCount: shoppingLists.length,
      onReorderItem: (oldIndex, newIndex) =>
          onReorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final list = shoppingLists[index];
        return Padding(
          key: ValueKey(list.id),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: ReorderableDragStartListener(
            index: index,
            child: Chip(
              avatar: const Icon(Icons.drag_handle, size: 18),
              label: Text(list.name),
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
