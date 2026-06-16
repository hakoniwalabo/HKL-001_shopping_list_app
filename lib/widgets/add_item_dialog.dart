import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import 'fields/item_name_field.dart';
import 'fields/price_field.dart';
import 'fields/quantity_field.dart';
import 'fields/memo_field.dart';

Future<void> showAddItemDialog({
  required BuildContext context,
  required int currentListId,
  required List<String> historyNames,
  Item? item,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _AddItemDialogContent(
      currentListId: currentListId,
      historyNames: historyNames,
      item: item,
    ),
  );
}

/// 「閉じる」確認ダイアログの選択肢
enum _CloseAction { cancel, discard, add }

class _AddItemDialogContent extends ConsumerStatefulWidget {
  final int currentListId;
  final List<String> historyNames;
  final Item? item;

  const _AddItemDialogContent({
    required this.currentListId,
    required this.historyNames,
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

  // 連続追加用: 名前欄へ再フォーカスするためのノードと追加件数
  final FocusNode _nameFocus = FocusNode();
  int _addedCount = 0;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _memoCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit({bool closeAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;

    final item = widget.item;
    if (item != null) {
      // 編集時: メモも反映
      final memo = _memoCtrl.text.trim();
      final updatedItem = item.copyWith(
        name: name,
        price: price,
        quantity: quantity,
        memo: memo,
      );
      await ref.read(itemProvider.notifier).updateItem(updatedItem);
      // 名前が変わった場合のみ履歴を更新（設計書 §8.9）
      if (name != item.name) {
        await DatabaseHelper.instance.upsertHistory(name);
      }
    } else {
      // 追加時: 税込価格をそのまま保存・memo=空固定
      final newItem = Item(
        name: name,
        price: price,
        quantity: quantity,
        memo: '',
        listId: widget.currentListId,
      );
      await ref.read(itemProvider.notifier).addItem(newItem);
      await DatabaseHelper.instance.upsertHistory(name);

      if (!mounted) return;
      // 「追加して閉じる」経由の場合はそのままダイアログを閉じる
      if (closeAfter) {
        Navigator.of(context).pop();
        return;
      }
      // 連続入力: ダイアログを閉じず、入力欄をクリアして名前欄へ再フォーカス
      setState(() => _addedCount++);
      _nameCtrl.clear();
      _priceCtrl.text = '0';
      _quantityCtrl.text = '1';
      _nameFocus.requestFocus();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// 追加モードで「閉じる」を押したときの処理。
  /// 名前欄に未追加のテキストが残っている場合は確認してから閉じる。
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
      // バリデーションを通れば追加してダイアログを閉じる。
      // 通らなければ閉じず、入力画面でエラーを表示する。
      await _submit(closeAfter: true);
      return;
    }

    // 破棄して閉じる
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return AlertDialog(
      title: Text(isEdit ? '商品編集' : '商品追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 連続追加のフィードバック（追加モードのみ）
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
              // 追加・編集 共通
              ItemNameField(
                controller: _nameCtrl,
                historyNames: widget.historyNames,
                focusNode: _nameFocus,
              ),
              const SizedBox(height: 12),
              PriceField(controller: _priceCtrl),
              const SizedBox(height: 12),
              QuantityField(controller: _quantityCtrl),
              // 編集時のみ: メモを表示
              if (isEdit) ...[
                const SizedBox(height: 12),
                MemoField(controller: _memoCtrl),
              ],
            ],
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
