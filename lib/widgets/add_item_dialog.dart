import 'package:flutter/material.dart';

import '../models/item.dart';
import 'form/add_item_form.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required int currentListId,
  required List<String> historyNames,
  Item? item,
}) async {
  final isEdit = item != null;
  final formKey = GlobalKey<AddItemFormState>();

  await showDialog(
    context: context,

    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isEdit ? '商品編集' : '商品追加'),

        content: SingleChildScrollView(
          child: AddItemForm(
            key: formKey,
            currentListId: currentListId,
            historyNames: historyNames,
            item: item,
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),

          FilledButton(
            onPressed: () => formKey.currentState?.submit(),
            child: Text(isEdit ? '保存' : '追加'),
          ),
        ],
      );
    },
  );
}
