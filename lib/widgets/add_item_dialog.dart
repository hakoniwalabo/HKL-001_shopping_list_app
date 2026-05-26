import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import 'form/add_item_form.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required WidgetRef ref,
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
            onAddItem: (newItem) =>
                ref.read(itemProvider.notifier).addItem(newItem),
            onUpdateItem: (updatedItem) =>
                ref.read(itemProvider.notifier).updateItem(updatedItem),
            onUpsertHistory: (name) =>
                DatabaseHelper.instance.upsertHistory(name),
            onSuccess: () => Navigator.of(dialogContext).pop(),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),

          FilledButton(
            onPressed: () async {
              await formKey.currentState?.submit();
            },
            child: Text(isEdit ? '保存' : '追加'),
          ),
        ],
      );
    },
  );
}
