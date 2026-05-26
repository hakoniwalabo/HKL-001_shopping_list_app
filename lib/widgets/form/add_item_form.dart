import 'package:flutter/material.dart';

import '../fields/item_name_field.dart';
import '../fields/price_field.dart';
import '../fields/tax_field.dart';
import '../fields/quantity_field.dart';
import '../fields/memo_field.dart';

class AddItemForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController taxController;
  final TextEditingController quantityController;
  final TextEditingController memoController;
  final List<String> historyNames;

  const AddItemForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.priceController,
    required this.taxController,
    required this.quantityController,
    required this.memoController,
    required this.historyNames,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          ItemNameField(
            controller: nameController,
            historyNames: historyNames,
          ),

          const SizedBox(height: 12),

          PriceField(controller: priceController),

          const SizedBox(height: 12),

          TaxField(controller: taxController),

          const SizedBox(height: 12),

          QuantityField(controller: quantityController),

          const SizedBox(height: 12),

          MemoField(controller: memoController),
        ],
      ),
    );
  }
}
