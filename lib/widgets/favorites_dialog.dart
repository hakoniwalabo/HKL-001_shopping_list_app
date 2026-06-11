import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../providers/item_provider.dart';
import 'history_select_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  bool get _allSelected =>
      _favorites.isNotEmpty &&
      _favorites.every((f) => _selectedIds.contains(f['id'] as int));

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        for (final f in _favorites) {
          _selectedIds.add(f['id'] as int);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('よく買うもの'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_favorites.isNotEmpty)
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
            else
              LimitedBox(
                maxHeight: 320,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _favorites.length,
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
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('削除しました'),
                            action: SnackBarAction(
                              label: '元に戻す',
                              onPressed: () async {
                                final data = _pendingUndoFavorite;
                                if (data == null) return;
                                await DatabaseHelper.instance.insertFavorite(
                                  data['name'] as String,
                                  data['price'] as int,
                                  data['quantity'] as int,
                                );
                                _pendingUndoFavorite = null;
                                await _load();
                              },
                            ),
                          ),
                        );
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
                            ),
                          );
                          await _load();
                        },
                      ),
                    );
                  },
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
        TextButton(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => HistorySelectDialog(
                onRegister: (names) async {
                  for (final name in names) {
                    await DatabaseHelper.instance.insertFavorite(name, 0, 1);
                  }
                  await _load();
                },
              ),
            );
          },
          child: const Text('履歴から登録'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty ? null : _addToList,
          child: const Text('リストに追加'),
        ),
      ],
    );
  }
}

class _AddFavoriteDialog extends StatefulWidget {
  final Future<void> Function() onAdded;

  const _AddFavoriteDialog({required this.onAdded});

  @override
  State<_AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<_AddFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('よく買うものに登録'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '商品名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
            ),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '税込価格'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
              },
            ),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '個数'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
              },
            ),
          ],
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

class _EditFavoriteDialog extends StatefulWidget {
  final int id;
  final String initialName;
  final int initialPrice;
  final int initialQuantity;

  const _EditFavoriteDialog({
    required this.id,
    required this.initialName,
    required this.initialPrice,
    required this.initialQuantity,
  });

  @override
  State<_EditFavoriteDialog> createState() => _EditFavoriteDialogState();
}

class _EditFavoriteDialogState extends State<_EditFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _priceCtrl = TextEditingController(text: widget.initialPrice.toString());
    _qtyCtrl =
        TextEditingController(text: widget.initialQuantity.toString());
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
    return AlertDialog(
      title: const Text('よく買うものを編集'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '商品名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
            ),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '税込価格'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
              },
            ),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '個数'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
              },
            ),
          ],
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
