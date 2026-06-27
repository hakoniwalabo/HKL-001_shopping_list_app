import 'package:flutter/material.dart';

class ItemNameField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> historyNames;

  /// 外部からフォーカスを制御したい場合に渡す。未指定なら内部で生成する。
  final FocusNode? focusNode;

  const ItemNameField({
    super.key,
    required this.controller,
    required this.historyNames,
    this.focusNode,
  });

  @override
  State<ItemNameField> createState() => _ItemNameFieldState();
}

class _ItemNameFieldState extends State<ItemNameField> {
  FocusNode? _internalFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    // 内部生成したノードのみ破棄する（外部注入ノードは呼び出し側が管理）
    _internalFocusNode?.dispose();
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
    // 空欄（フォーカス取得直後・連続追加でのクリア直後）では候補を出さない。
    // 入力文字がある場合のみ履歴を絞り込んで表示する。
    if (text.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final filtered = widget.historyNames
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
          autofocus: false,
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
          Material(
            elevation: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions
                  .map(
                    (s) => ListTile(
                      dense: true,
                      title: Text(s),
                      onTap: () => _selectSuggestion(s),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
