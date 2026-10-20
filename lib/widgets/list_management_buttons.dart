import 'package:flutter/material.dart';

class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onDuplicateList;
  final VoidCallback onToggleReorderMode;
  final bool isReorderMode;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onDuplicateList,
    required this.onToggleReorderMode,
    required this.isReorderMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onAddList,
          icon: const Icon(Icons.add),
          tooltip: 'リストを追加',
        ),
        IconButton(
          onPressed: onDuplicateList,
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'リストを複製',
        ),
        IconButton(
          onPressed: onToggleReorderMode,
          icon: Icon(
            Icons.reorder,
            color: isReorderMode
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          tooltip: isReorderMode ? '並び替えを終了' : 'リストを並び替え',
        ),
      ],
    );
  }
}
