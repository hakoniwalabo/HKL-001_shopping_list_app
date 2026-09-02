import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantityField extends StatelessWidget {
  final TextEditingController controller;

  const QuantityField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: '個数'),
      onTap: () => controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      ),
      validator: (value) {
        final quantity = int.tryParse(value ?? '');

        if (quantity == null || quantity < 1) {
          return '1以上の整数を入力してください';
        }

        return null;
      },
    );
  }
}
