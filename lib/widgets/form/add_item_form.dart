import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../fields/item_name_field.dart';
import '../fields/price_field.dart';
import '../fields/tax_field.dart';
import '../fields/quantity_field.dart';
import '../fields/memo_field.dart';

class AddItemForm extends StatefulWidget {
  final int currentListId;
  final List<String> historyNames;
  final Item? item;
  final Future<void> Function(Item) onAddItem;
  final Future<void> Function(Item) onUpdateItem;
  final Future<void> Function(String) onUpsertHistory;
  final VoidCallback onSuccess;

  const AddItemForm({
    super.key,
    required this.currentListId,
    required this.historyNames,
    required this.onAddItem,
    required this.onUpdateItem,
    required this.onUpsertHistory,
    required this.onSuccess,
    this.item,
  });

  @override
  State<AddItemForm> createState() => AddItemFormState();
}

class AddItemFormState extends State<AddItemForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _taxController;
  late final TextEditingController _quantityController;
  late final TextEditingController _memoController;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(text: item?.price.toString() ?? '0');
    _taxController = TextEditingController(
      text: item != null ? (item.taxRate * 100).toInt().toString() : '0',
    );
    _quantityController = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    _memoController = TextEditingController(text: item?.memo ?? '');

    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) return;

      final text = _nameController.text;
      if (text.isEmpty) return;

      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _taxController.dispose();
    _quantityController.dispose();
    _memoController.dispose();
    _nameFocusNode.dispose();

    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text) ?? 0;
    final taxRate = (double.tryParse(_taxController.text) ?? 0) / 100;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final memo = _memoController.text.trim();

    final item = widget.item;

    if (item != null) {
      final updatedItem = item.copyWith(
        name: name,
        price: price,
        taxRate: taxRate,
        quantity: quantity,
        memo: memo,
      );

      await widget.onUpdateItem(updatedItem);
    } else {
      final newItem = Item(
        name: name,
        price: price,
        taxRate: taxRate,
        quantity: quantity,
        memo: memo,
        listId: widget.currentListId,
        sortOrder: DateTime.now().millisecondsSinceEpoch,
      );

      await widget.onAddItem(newItem);
      await widget.onUpsertHistory(name);
    }

    if (!mounted) return;

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          ItemNameField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            historyNames: widget.historyNames,
          ),

          const SizedBox(height: 12),

          PriceField(controller: _priceController),

          const SizedBox(height: 12),

          TaxField(controller: _taxController),

          const SizedBox(height: 12),

          QuantityField(controller: _quantityController),

          const SizedBox(height: 12),

          MemoField(controller: _memoController),
        ],
      ),
    );
  }
}
