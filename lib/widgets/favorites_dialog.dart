import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import 'fields/item_name_field.dart';

class FavoritesDialog extends ConsumerStatefulWidget {
  final int currentListId;

  const FavoritesDialog({super.key, required this.currentListId});

  @override
  ConsumerState<FavoritesDialog> createState() => _FavoritesDialogState();
}

class _FavoritesDialogState extends ConsumerState<FavoritesDialog> {
  List<Map<String, dynamic>> _favorites = [];
  final Set<int> _selectedIds = {};
  Map<String, dynamic>? _pendingUndoFavorite;
  Timer? _undoTimer;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = data;
      _selectedIds.removeWhere(
        (id) => !data.any((f) => f['id'] as int == id),
      );
    });
  }

  Future<void> _onReorderItem(int oldIndex, int newIndex) async {
    final list = [..._favorites];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _favorites = list);
    try {
      await DatabaseHelper.instance.reorderFavorites(
        list.map((f) => f['id'] as int).toList(),
      );
    } catch (_) {
      await _load();
    }
  }

  Future<void> _addToList() async {
    final ids = _selectedIds.toList();
    await DatabaseHelper.instance.addFavoriteItemsToList(
      ids,
      widget.currentListId,
    );
    await ref.read(itemProvider.notifier).changeList(widget.currentListId);
    if (!mounted) return;
    Navigator.pop(context, ids.length);
  }

  List<Map<String, dynamic>> get _filteredFavorites =>
      _searchText.isEmpty
          ? _favorites
          : _favorites
              .where((f) => (f['name'] as String)
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()))
              .toList();

  bool get _allSelected =>
      _filteredFavorites.isNotEmpty &&
      _filteredFavorites.every((f) => _selectedIds.contains(f['id'] as int));

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        for (final f in _filteredFavorites) {
          _selectedIds.remove(f['id'] as int);
        }
      } else {
        for (final f in _filteredFavorites) {
          _selectedIds.add(f['id'] as int);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('よく買うもの')),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pendingUndoFavorite != null)
              Material(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '削除しました',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          _undoTimer?.cancel();
                          final data = _pendingUndoFavorite!;
                          setState(() => _pendingUndoFavorite = null);
                          await DatabaseHelper.instance.restoreFavorite(
                            data['name'] as String,
                            data['price'] as int,
                            data['quantity'] as int,
                            data['sortOrder'] as int,
                            categoryId: data['categoryId'] as int?,
                          );
                          await _load();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                        ),
                        child: const Text('元に戻す'),
                      ),
                    ],
                  ),
                ),
              ),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '検索',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchText.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchText = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
            const SizedBox(height: 8),
            if (_filteredFavorites.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(
                    _allSelected ? Icons.deselect : Icons.select_all,
                  ),
                  label: Text(_allSelected ? '全解除' : '全選択'),
                ),
              ),
            if (_favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('まだ登録されていません'),
              )
            else if (_searchText.isEmpty)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Scrollbar(
                    controller: _scrollCtrl,
                    thumbVisibility: true,
                    child: ReorderableListView.builder(
                      scrollController: _scrollCtrl,
                      shrinkWrap: true,
                      itemCount: _favorites.length,
                      onReorderItem: _onReorderItem,
                      itemBuilder: (_, i) {
                        final fav = _favorites[i];
                        final id = fav['id'] as int;
                        final name = fav['name'] as String;
                        final price = fav['price'] as int;
                        final qty = fav['quantity'] as int;
                        final subtitle =
                            price > 0 ? '¥$price × $qty' : '数量: $qty';
                        return Dismissible(
                          key: ValueKey(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) async {
                            _pendingUndoFavorite = Map.from(fav);
                            _selectedIds.remove(id);
                            await DatabaseHelper.instance.deleteFavorite(id);
                            await _load();
                            if (!mounted) return;
                            _undoTimer?.cancel();
                            _undoTimer = Timer(const Duration(seconds: 5), () {
                              if (!mounted) return;
                              setState(() => _pendingUndoFavorite = null);
                            });
                          },
                          child: ListTile(
                            leading: Checkbox(
                              value: _selectedIds.contains(id),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                            ),
                            title: Text(name),
                            subtitle: Text(subtitle),
                            onTap: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => _EditFavoriteDialog(
                                  id: id,
                                  initialName: name,
                                  initialPrice: price,
                                  initialQuantity: qty,
                                  initialCategoryId: fav['categoryId'] as int?,
                                ),
                              );
                              await _load();
                            },
                            trailing: ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredFavorites.length,
                    itemBuilder: (_, i) {
                      final fav = _filteredFavorites[i];
                      final id = fav['id'] as int;
                      final name = fav['name'] as String;
                      final price = fav['price'] as int;
                      final qty = fav['quantity'] as int;
                      final subtitle = price > 0 ? '¥$price × $qty' : '数量: $qty';
                      return Dismissible(
                        key: ValueKey(id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          _pendingUndoFavorite = Map.from(fav);
                          _selectedIds.remove(id);
                          await DatabaseHelper.instance.deleteFavorite(id);
                          await _load();
                          if (!mounted) return;
                          _undoTimer?.cancel();
                          _undoTimer = Timer(const Duration(seconds: 5), () {
                            if (!mounted) return;
                            setState(() => _pendingUndoFavorite = null);
                          });
                        },
                        child: ListTile(
                          leading: Checkbox(
                            value: _selectedIds.contains(id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              });
                            },
                          ),
                          title: Text(name),
                          subtitle: Text(subtitle),
                          onTap: () async {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => _EditFavoriteDialog(
                                id: id,
                                initialName: name,
                                initialPrice: price,
                                initialQuantity: qty,
                                initialCategoryId: fav['categoryId'] as int?,
                              ),
                            );
                            await _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => _AddFavoriteDialog(onAdded: _load),
            );
          },
          child: const Text('直接登録'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty ? null : _addToList,
          child: const Text('リストに追加'),
        ),
      ],
    );
  }
}

class _AddFavoriteDialog extends ConsumerStatefulWidget {
  final Future<void> Function() onAdded;

  const _AddFavoriteDialog({required this.onAdded});

  @override
  ConsumerState<_AddFavoriteDialog> createState() =>
      _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends ConsumerState<_AddFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '1');
  int? _selectedCategoryId;
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _nameFocus = FocusNode();
  List<String> _candidateNames = [];

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final data = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _candidateNames = data.map((f) => f['name'] as String).toList();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _scrollCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _showNewCategoryDialog(List<Category> categories) async {
    String newName = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリを追加'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
          onChanged: (v) => newName = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (confirmed != true || newName.isEmpty || !mounted) return;
    final id = await ref.read(categoryProvider.notifier).addCategory(newName);
    setState(() => _selectedCategoryId = id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).value ?? <Category>[];
    return AlertDialog(
      title: const Text('よく買うものに登録'),
      content: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemNameField(
                controller: _nameCtrl,
                candidateNames: _candidateNames,
                focusNode: _nameFocus,
              ),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '税込価格'),
                onTap: () => _priceCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _priceCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
                },
              ),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '個数'),
                onTap: () => _qtyCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _qtyCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ（任意）',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      initialValue: _selectedCategoryId,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('なし')),
                        ...categories.map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '新規カテゴリ',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _showNewCategoryDialog(categories),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await DatabaseHelper.instance.insertFavorite(
              _nameCtrl.text.trim(),
              int.parse(_priceCtrl.text),
              int.parse(_qtyCtrl.text),
              categoryId: _selectedCategoryId,
            );
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
            await widget.onAdded();
          },
          child: const Text('登録'),
        ),
      ],
    );
  }
}

class _EditFavoriteDialog extends ConsumerStatefulWidget {
  final int id;
  final String initialName;
  final int initialPrice;
  final int initialQuantity;
  final int? initialCategoryId;

  const _EditFavoriteDialog({
    required this.id,
    required this.initialName,
    required this.initialPrice,
    required this.initialQuantity,
    this.initialCategoryId,
  });

  @override
  ConsumerState<_EditFavoriteDialog> createState() =>
      _EditFavoriteDialogState();
}

class _EditFavoriteDialogState extends ConsumerState<_EditFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _priceCtrl = TextEditingController(text: widget.initialPrice.toString());
    _qtyCtrl = TextEditingController(text: widget.initialQuantity.toString());
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).value ?? <Category>[];
    return AlertDialog(
      title: const Text('よく買うものを編集'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '商品名'),
                onTap: () => _nameCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _nameCtrl.text.length,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
              ),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '税込価格'),
                onTap: () => _priceCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _priceCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
                },
              ),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '個数'),
                onTap: () => _qtyCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _qtyCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                decoration: const InputDecoration(
                  labelText: 'カテゴリ（任意）',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                initialValue: _selectedCategoryId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('なし')),
                  ...categories.map((c) => DropdownMenuItem<int?>(
                      value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await DatabaseHelper.instance.updateFavorite(
              widget.id,
              _nameCtrl.text.trim(),
              int.parse(_priceCtrl.text),
              int.parse(_qtyCtrl.text),
              categoryId: _selectedCategoryId,
            );
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
