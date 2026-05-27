import 'package:flutter/material.dart';

class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onDeleteList;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onDeleteList,
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
          onPressed: onDeleteList,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'リストを削除',
        ),
      ],
    );
  }
}
