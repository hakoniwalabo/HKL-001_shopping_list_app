import 'package:flutter/material.dart';

class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onRenameList;
  final VoidCallback onDeleteList;
  final VoidCallback? onDeleteChecked;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onRenameList,
    required this.onDeleteList,
    required this.onDeleteChecked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            IconButton(onPressed: onAddList, icon: const Icon(Icons.add)),

            IconButton(onPressed: onRenameList, icon: const Icon(Icons.edit)),

            IconButton(onPressed: onDeleteList, icon: const Icon(Icons.delete)),
          ],
        ),

        TextButton.icon(
          onPressed: onDeleteChecked,

          icon: const Icon(Icons.delete_sweep),

          label: const Text('購入済み削除'),
        ),
      ],
    );
  }
}
