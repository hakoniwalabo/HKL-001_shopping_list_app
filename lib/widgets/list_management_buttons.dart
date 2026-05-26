import 'package:flutter/material.dart';

class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onRenameList;
  final VoidCallback onDeleteList;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onRenameList,
    required this.onDeleteList,
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
      ],
    );
  }
}
