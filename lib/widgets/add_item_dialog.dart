import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import 'fields/item_name_field.dart';
import 'fields/price_field.dart';
import 'fields/tax_field.dart';
import 'fields/quantity_field.dart';
import 'fields/memo_field.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int currentListId,
  required List<String> historyNames,
  Item? item,
}) async {
  final isEdit = item != null;
  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController(text: item?.name ?? '');
  final priceCtrl = TextEditingController(
    text: item?.price.toString() ?? '0',
  );
  final taxCtrl = TextEditingController(
    text: item != null ? (item.taxRate * 100).toInt().toString() : '0',
  );
  final quantityCtrl = TextEditingController(
    text: item?.quantity.toString() ?? '1',
  );
  final memoCtrl = TextEditingController(text: item?.memo ?? '');

  await showDialog<void>(
    context: context,

    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isEdit ? '商品編集' : '商品追加'),

        content: SingleChildScrollView(
          child: Form(
            key: formKey,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                ItemNameField(
                  controller: nameCtrl,
                  historyNames: historyNames,
                ),
                const SizedBox(height: 12),
                PriceField(controller: priceCtrl),
                const SizedBox(height: 12),
                TaxField(controller: taxCtrl),
                const SizedBox(height: 12),
                QuantityField(controller: quantityCtrl),
                const SizedBox(height: 12),
                MemoField(controller: memoCtrl),
              ],
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),

          FilledButton(
            onPressed: () async {
              print('[DEBUG] 追加ボタン onPressed 開始');
              final formState = formKey.currentState;
              print('[DEBUG] formKey.currentState = $formState');
              if (formState == null) {
                print('[DEBUG] formState が null → return');
                return;
              }
              final valid = formState.validate();
              print('[DEBUG] validate() = $valid');
              if (!valid) return;

              final name = nameCtrl.text.trim();
              final price = int.tryParse(priceCtrl.text) ?? 0;
              final taxRate = (double.tryParse(taxCtrl.text) ?? 0) / 100;
              final quantity = int.tryParse(quantityCtrl.text) ?? 1;
              final memo = memoCtrl.text.trim();

              try {
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
                  print('[DEBUG] addItem 呼び出し前');
                  await ref.read(itemProvider.notifier).addItem(newItem);
                  print('[DEBUG] addItem 完了');
                  await DatabaseHelper.instance.upsertHistory(name);
                }
              } catch (e, st) {
                print('[DEBUG] 例外発生: $e\n$st');
                return;
              }

              print('[DEBUG] Navigator.pop 直前');
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            },

            child: Text(isEdit ? '保存' : '追加'),
          ),
        ],
      );
    },
  );

  nameCtrl.dispose();
  priceCtrl.dispose();
  taxCtrl.dispose();
  quantityCtrl.dispose();
  memoCtrl.dispose();
}
