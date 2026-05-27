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
  required int currentListId,
  required List<String> historyNames,
  Item? item,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _AddItemDialogContent(
      currentListId: currentListId,
      historyNames: historyNames,
      item: item,
    ),
  );
}

class _AddItemDialogContent extends ConsumerStatefulWidget {
  final int currentListId;
  final List<String> historyNames;
  final Item? item;

  const _AddItemDialogContent({
    required this.currentListId,
    required this.historyNames,
    this.item,
  });

  @override
  ConsumerState<_AddItemDialogContent> createState() =>
      _AddItemDialogContentState();
}

class _AddItemDialogContentState extends ConsumerState<_AddItemDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _priceCtrl = TextEditingController(text: item?.price.toString() ?? '0');
    _taxCtrl = TextEditingController(
      text: item != null ? (item.taxRate * 100).toInt().toString() : '0',
    );
    _quantityCtrl = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    _memoCtrl = TextEditingController(text: item?.memo ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _taxCtrl.dispose();
    _quantityCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;

    final item = widget.item;
    if (item != null) {
      // 編集時: 税率・メモも反映
      final taxRate = (double.tryParse(_taxCtrl.text) ?? 0) / 100;
      final memo = _memoCtrl.text.trim();
      final updatedItem = item.copyWith(
        name: name,
        price: price,
        taxRate: taxRate,
        quantity: quantity,
        memo: memo,
      );
      await ref.read(itemProvider.notifier).updateItem(updatedItem);
      // 名前が変わった場合のみ履歴を更新（設計書 §8.9）
      if (name != item.name) {
        await DatabaseHelper.instance.upsertHistory(name);
      }
    } else {
      // 追加時: 税込価格をそのまま保存・taxRate=0固定・memo=空固定
      final newItem = Item(
        name: name,
        price: price,
        taxRate: 0.0,
        quantity: quantity,
        memo: '',
        listId: widget.currentListId,
      );
      await ref.read(itemProvider.notifier).addItem(newItem);
      await DatabaseHelper.instance.upsertHistory(name);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return AlertDialog(
      title: Text(isEdit ? '商品編集' : '商品追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 追加・編集 共通
              ItemNameField(
                controller: _nameCtrl,
                historyNames: widget.historyNames,
              ),
              const SizedBox(height: 12),
              PriceField(controller: _priceCtrl),
              const SizedBox(height: 12),
              QuantityField(controller: _quantityCtrl),
              // 編集時のみ: 税率・メモを表示
              if (isEdit) ...[
                const SizedBox(height: 12),
                TaxField(controller: _taxCtrl),
                const SizedBox(height: 12),
                MemoField(controller: _memoCtrl),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? '保存' : '追加'),
        ),
      ],
    );
  }
}
