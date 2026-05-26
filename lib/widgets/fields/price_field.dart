import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PriceField extends StatelessWidget {
  final TextEditingController controller;

  const PriceField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: '価格'),
      validator: (value) {
        final price = int.tryParse(value ?? '');

        if (price == null || price < 0) {
          return '0以上の数値を入力してください';
        }

        return null;
      },
    );
  }
}
