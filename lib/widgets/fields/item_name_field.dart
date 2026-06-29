import 'package:flutter/material.dart';

class ItemNameField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  const ItemNameField({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  State<ItemNameField> createState() => _ItemNameFieldState();
}

class _ItemNameFieldState extends State<ItemNameField> {
  FocusNode? _internalFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: false,
      decoration: const InputDecoration(labelText: '商品名'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '商品名を入力してください';
        }
        return null;
      },
    );
  }
}
