import 'package:flutter/material.dart';

class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onDuplicateList;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onDuplicateList,
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
      ],
    );
  }
}
