import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import 'fields/item_name_field.dart';
import 'fields/price_field.dart';
import 'fields/quantity_field.dart';
import 'fields/memo_field.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required int currentListId,
  Item? item,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _AddItemDialogContent(
      currentListId: currentListId,
      item: item,
    ),
  );
}

enum _CloseAction { cancel, discard, add }

class _AddItemDialogContent extends ConsumerStatefulWidget {
  final int currentListId;
  final Item? item;

  const _AddItemDialogContent({
    required this.currentListId,
    this.item,
  });

  @override
  ConsumerState<_AddItemDialogContent> createState() =>
      _AddItemDialogContentState();
}

class _AddItemDialogContentState extends ConsumerState<_AddItemDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _memoCtrl;

  final FocusNode _nameFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  int _addedCount = 0;
  int? _selectedCategoryId;
  bool _addToFavorites = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _priceCtrl = TextEditingController(text: item?.price.toString() ?? '0');
    _quantityCtrl = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    _memoCtrl = TextEditingController(text: item?.memo ?? '');
    _selectedCategoryId = item?.categoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _memoCtrl.dispose();
    _nameFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({bool closeAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;

    final item = widget.item;
    if (item != null) {
      final memo = _memoCtrl.text.trim();
      final updatedItem = item
          .copyWith(name: name, price: price, quantity: quantity, memo: memo)
          .copyWithNullableCategory(categoryId: _selectedCategoryId);
      await ref.read(itemProvider.notifier).updateItem(updatedItem);
    } else {
      final newItem = Item(
        name: name,
        price: price,
        quantity: quantity,
        memo: '',
        listId: widget.currentListId,
        categoryId: _selectedCategoryId,
      );
      await ref.read(itemProvider.notifier).addItem(newItem);
      if (_addToFavorites) {
        bool doInsert = true;
        final exists = await DatabaseHelper.instance.favoriteNameExists(name);
        if (exists && mounted) {
          doInsert = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('既に登録されています'),
                  content: Text('「$name」はよく買うものに登録済みです。追加しますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('キャンセル'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('追加'),
                    ),
                  ],
                ),
              ) ??
              false;
        }
        if (doInsert) {
          await DatabaseHelper.instance.insertFavorite(
            name,
            price,
            quantity,
            categoryId: _selectedCategoryId,
          );
        }
      }

      if (!mounted) return;
      if (closeAfter) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _addedCount++;
      });
      _nameCtrl.value = TextEditingValue.empty;
      _priceCtrl.text = '0';
      _quantityCtrl.text = '1';
      _nameFocus.requestFocus();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleClose() async {
    if (_nameCtrl.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<_CloseAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未追加の入力があります'),
        content: Text('「${_nameCtrl.text.trim()}」はまだ追加されていません。'),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_CloseAction.cancel),
            child: const Text('入力に戻る'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_CloseAction.discard),
            child: const Text('破棄して閉じる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_CloseAction.add),
            child: const Text('追加して閉じる'),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == _CloseAction.cancel) return;
    if (action == _CloseAction.add) {
      await _submit(closeAfter: true);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
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
    if (!mounted) return;
    setState(() => _selectedCategoryId = id);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final categories = ref.watch(categoryProvider).value ?? <Category>[];

    return AlertDialog(
      title: Text(isEdit ? '商品編集' : '商品追加'),
      content: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isEdit && _addedCount > 0) ...[
                  Text(
                    '$_addedCount件追加しました',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ItemNameField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                ),
                const SizedBox(height: 12),
                PriceField(controller: _priceCtrl),
                const SizedBox(height: 12),
                QuantityField(controller: _quantityCtrl),
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  MemoField(controller: _memoCtrl),
                ],
                const SizedBox(height: 12),
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
                            value: null,
                            child: Text('なし'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
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
                if (!isEdit) ...[
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: _addToFavorites,
                    onChanged: (v) => setState(() => _addToFavorites = v ?? false),
                    title: const Text('よく買うものに登録'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isEdit ? () => Navigator.of(context).pop() : _handleClose,
          child: Text(isEdit ? 'キャンセル' : '閉じる'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? '保存' : '追加'),
        ),
      ],
    );
  }
}
