import 'package:flutter/material.dart';

import '../../models/favorite_suggestion.dart';

const int _maxSuggestions = 8;
const int _maxFavoriteSuggestions = 5;

class NameSuggestion {
  final String name;
  final FavoriteSuggestion? favorite;

  const NameSuggestion(this.name, [this.favorite]);
}

// よく買うもの（最大5件）を先に、残り枠に履歴（同名重複除去）を合計8件まで並べる。
List<NameSuggestion> buildNameSuggestions({
  required String text,
  required List<String> history,
  List<FavoriteSuggestion> favorites = const [],
}) {
  if (text.isEmpty) return [];
  final lower = text.toLowerCase();
  bool matches(String n) => n.toLowerCase().contains(lower);
  final favs = favorites
      .where((f) => matches(f.name))
      .take(_maxFavoriteSuggestions)
      .map((f) => NameSuggestion(f.name, f));
  final hist = history.where(matches).toSet().map(NameSuggestion.new);
  return [...favs, ...hist].take(_maxSuggestions).toList();
}

class ItemNameField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<String> candidateNames;
  final List<FavoriteSuggestion> favoriteSuggestions;
  final ValueChanged<FavoriteSuggestion>? onFavoriteSelected;

  const ItemNameField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.candidateNames,
    this.favoriteSuggestions = const [],
    this.onFavoriteSelected,
  });

  @override
  State<ItemNameField> createState() => _ItemNameFieldState();
}

class _ItemNameFieldState extends State<ItemNameField> {
  FocusNode? _internalFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;
  List<NameSuggestion> _suggestions = [];

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
    setState(
      () => _suggestions = buildNameSuggestions(
        text: text,
        history: widget.candidateNames,
        favorites: widget.favoriteSuggestions,
      ),
    );
  }

  void _selectSuggestion(NameSuggestion suggestion) {
    final favorite = suggestion.favorite;
    final onSelected = widget.onFavoriteSelected;
    if (favorite != null && onSelected != null) {
      onSelected(favorite);
    } else {
      widget.controller.text = suggestion.name;
    }
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
                      leading: s.favorite != null
                          ? const Icon(Icons.star, size: 18)
                          : null,
                      title: Text(s.name),
                      subtitle: s.favorite != null
                          ? Text(s.favorite!.subtitle)
                          : null,
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
