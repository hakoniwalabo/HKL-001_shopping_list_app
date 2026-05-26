import 'package:flutter/material.dart';

class MemoField extends StatelessWidget {
  final TextEditingController controller;

  const MemoField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'メモ'),
      maxLines: 3,
    );
  }
}
