import 'package:flutter/material.dart';

class TaxField extends StatelessWidget {
  final TextEditingController controller;

  const TaxField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: '税率（%）'),
      validator: (value) {
        final tax = double.tryParse(value ?? '');

        if (tax == null || tax < 0) {
          return '0以上を入力してください';
        }

        return null;
      },
    );
  }
}
