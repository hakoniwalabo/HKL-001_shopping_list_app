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
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController(text: item?.name ?? '');
  final priceController = TextEditingController(
    text: item?.price.toString() ?? '0',
  );
  final taxController = TextEditingController(
    text: item != null ? (item.taxRate * 100).toInt().toString() : '0',
  );
  final quantityController = TextEditingController(
    text: item?.quantity.toString() ?? '1',
  );
  final memoController = TextEditingController(text: item?.memo ?? '');

  await showDialog<void>(
    context: context,

    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isEdit ? '商品編集' : '商品追加'),

        content: SingleChildScrollView(
          child: AddItemForm(
            formKey: formKey,
            nameController: nameController,
            priceController: priceController,
            taxController: taxController,
            quantityController: quantityController,
            memoController: memoController,
            historyNames: historyNames,
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),

          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;

              final name = nameController.text.trim();
              final price = int.tryParse(priceController.text) ?? 0;
              final taxRate =
                  (double.tryParse(taxController.text) ?? 0) / 100;
              final quantity =
                  int.tryParse(quantityController.text) ?? 1;
              final memo = memoController.text.trim();

              if (isEdit) {
                final updatedItem = item.copyWith(
                  name: name,
                  price: price,
                  taxRate: taxRate,
                  quantity: quantity,
                  memo: memo,
                );

                await ref
                    .read(itemProvider.notifier)
                    .updateItem(updatedItem);
              } else {
                final newItem = Item(
                  name: name,
                  price: price,
                  taxRate: taxRate,
                  quantity: quantity,
                  memo: memo,
                  listId: currentListId,
                  sortOrder: DateTime.now().millisecondsSinceEpoch,
                );

                await ref.read(itemProvider.notifier).addItem(newItem);
                await DatabaseHelper.instance.upsertHistory(name);
              }

              if (!dialogContext.mounted) return;

              Navigator.of(dialogContext).pop();
            },

            child: Text(isEdit ? '保存' : '追加'),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  priceController.dispose();
  taxController.dispose();
  quantityController.dispose();
  memoController.dispose();
}
