import 'package:flutter/material.dart';

import '../models/item.dart';
import 'form/add_item_form.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required int currentListId,
  required List<String> historyNames,
  Item? item,
}) async {
  await showDialog(
    context: context,

    builder: (dialogContext) {
      return AlertDialog(
        title: Text(item != null ? '商品編集' : '商品追加'),

        content: SingleChildScrollView(
          child: AddItemForm(
            currentListId: currentListId,
            historyNames: historyNames,
            item: item,
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
    },
  );
}
