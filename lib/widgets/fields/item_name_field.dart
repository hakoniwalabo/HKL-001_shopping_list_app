import 'package:flutter/material.dart';

class ItemNameField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> historyNames;

  const ItemNameField({
    super.key,
    required this.controller,
    required this.historyNames,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
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
        controller.text = selection;
      },

      fieldViewBuilder: (context, autocompleteController, focusNode, _) {
        // 編集モード時、Autocomplete内部controllerに初期値を反映する
        if (autocompleteController.text.isEmpty && controller.text.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (autocompleteController.text.isEmpty) {
              autocompleteController.text = controller.text;
            }
          });
        }

        return TextFormField(
          controller: autocompleteController,
          focusNode: focusNode,
          autofocus: true,
          decoration: const InputDecoration(labelText: '商品名'),
          onChanged: (value) => controller.text = value,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '商品名を入力してください';
            }

            return null;
          },
        );
      },
    );
  }
}
