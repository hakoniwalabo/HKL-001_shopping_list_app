import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/item.dart';
import '../providers/item_provider.dart';
import '../database/database_helper.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int currentListId,
  required List<String> historyNames,
  Item? item,
  required List<Item> items,
}) async {
  final isEdit = item != null;

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

  final formKey = GlobalKey<FormState>();

  final nameFocusNode = FocusNode();

  nameFocusNode.addListener(() {
    if (!nameFocusNode.hasFocus) return;

    final text = nameController.text;
    if (text.isEmpty) return;

    nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  });

  await showDialog(
    context: context,

    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? '商品編集' : '商品追加'),

            content: SingleChildScrollView(
              child: Form(
                key: formKey,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return historyNames;
                        }

                        return historyNames
                            .where(
                              (option) => option.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                            )
                            .take(100);
                      },

                      onSelected: (selection) {
                        nameController.text = selection;
                      },

                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            // 初期値同期（1回だけ）
                            if (controller.text.isEmpty &&
                                nameController.text.isNotEmpty &&
                                ModalRoute.of(context)?.isCurrent == true) {
                              controller.text = nameController.text;
                            }

                            return TextFormField(
                              controller: controller,
                              focusNode: nameFocusNode,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: '商品名',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '商品名を入力してください';
                                }
                                return null;
                              },
                            );
                          },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: priceController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                      decoration: const InputDecoration(labelText: '価格'),

                      validator: (value) {
                        final price = int.tryParse(value ?? '');

                        if (price == null || price < 0) {
                          return '0以上の数値を入力してください';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: taxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: const InputDecoration(labelText: '税率（%）'),

                      validator: (value) {
                        final tax = double.tryParse(value ?? '');

                        if (tax == null || tax < 0) {
                          return '0以上を入力してください';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,

                      decoration: const InputDecoration(labelText: '数量'),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: memoController,

                      decoration: const InputDecoration(labelText: 'メモ'),

                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },

                child: const Text('キャンセル'),
              ),

              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final name = nameController.text.trim();

                  final price = int.tryParse(priceController.text) ?? 0;

                  final quantity = int.tryParse(quantityController.text) ?? 1;

                  final memo = memoController.text.trim();

                  if (isEdit) {
                    final updatedItem = item.copyWith(
                      name: name,
                      price: price,
                      taxRate: (double.tryParse(taxController.text) ?? 0) / 100,
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
                      taxRate: (double.tryParse(taxController.text) ?? 0) / 100,
                      quantity: quantity,
                      memo: memo,
                      listId: currentListId,
                      sortOrder: DateTime.now().millisecondsSinceEpoch,
                    );

                    await ref.read(itemProvider.notifier).addItem(newItem);

                    await DatabaseHelper.instance.upsertHistory(name);
                  }

                  if (!context.mounted) return;

                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },

                child: Text(isEdit ? '保存' : '追加'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  priceController.dispose();
  quantityController.dispose();
  memoController.dispose();
  taxController.dispose();
  nameFocusNode.dispose();
}
