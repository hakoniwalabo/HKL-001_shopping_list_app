import 'package:flutter/material.dart';

class ItemNameField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> historyNames;

  const ItemNameField({
    super.key,
    required this.controller,
    required this.historyNames,
  });

  @override
  State<ItemNameField> createState() => _ItemNameFieldState();
}

class _ItemNameFieldState extends State<ItemNameField> {
  final _focusNode = FocusNode();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(widget.controller.text);
    } else {
      setState(() => _suggestions = []);
    }
  }

  void _updateSuggestions(String text) {
    final filtered = text.isEmpty
        ? widget.historyNames
        : widget.historyNames
            .where((n) => n.toLowerCase().contains(text.toLowerCase()))
            .toList();
    setState(() => _suggestions = filtered.take(8).toList());
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: const InputDecoration(labelText: '商品名'),
          onChanged: _updateSuggestions,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '商品名を入力してください';
            }
            return null;
          },
        ),
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: Material(
              elevation: 2,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(_suggestions[index]),
                    onTap: () => _selectSuggestion(_suggestions[index]),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
