import 'package:flutter/material.dart';
import '../models/item.dart';
import '../database/database_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_provider.dart';
import 'package:flutter/services.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  List<String> historyNames = [];
  List<Item>? _pendingUndoItems;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final data = await DatabaseHelper.instance.getHistoryNames();
    setState(() {
      historyNames = data;
    });
  }

  List<Item> uncheckedItems(List<Item> items) =>
      items.where((e) => !e.isChecked).toList();

  List<Item> checkedItems(List<Item> items) =>
      items.where((e) => e.isChecked).toList();

  double uncheckedSubtotal(List<Item> items) =>
      uncheckedItems(items).fold(0, (s, e) => s + e.price);

  double uncheckedTotal(List<Item> items) =>
      uncheckedItems(items).fold(0, (s, e) => s + e.price * (1 + e.taxRate));

  double checkedSubtotal(List<Item> items) =>
      checkedItems(items).fold(0, (s, e) => s + e.price);

  double checkedTotal(List<Item> items) =>
      checkedItems(items).fold(0, (s, e) => s + e.price * (1 + e.taxRate));

  void _showAddItemDialog({Item? item, required List<Item> items}) {
    final autoController = TextEditingController(
      text: item?.name == '未入力' ? '' : item?.name ?? '',
    );
    final priceController = TextEditingController(
      text: item != null && item.price != 0 ? item.price.toString() : '',
    );
    final taxController = TextEditingController(
      text: item != null && item.taxRate != 0
          ? (item.taxRate * 100).toString()
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item == null ? '商品追加' : '商品編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return historyNames;
                  }
                  return historyNames.where(
                    (option) => option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: (selection) {
                  autoController.text = selection;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                      controller.text = autoController.text;
                      controller.addListener(() {
                        autoController.text = controller.text;
                      });

                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: '商品名'),
                      );
                    },
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: '金額',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: taxController,
                decoration: const InputDecoration(
                  labelText: '税率（%）',
                  hintText: '0',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context); // ←先に取得
                final trimmedName = autoController.text.trim();

                final name = trimmedName.isNotEmpty ? trimmedName : '未入力';

                final price = int.tryParse(priceController.text) ?? 0;

                if (price < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('金額は0以上の数字を入力してください')),
                  );

                  return;
                }

                final taxPercent = double.tryParse(taxController.text) ?? 0;

                if (taxPercent < 0 || taxPercent > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('税率は0〜100で入力してください')),
                  );

                  return;
                }
                final tax = taxPercent / 100;

                if (item == null) {
                  final newItem = Item(
                    name: name,
                    price: price,
                    taxRate: tax,
                    isChecked: false,
                    sortOrder: items.length,
                  );

                  await ref.read(itemProvider.notifier).addItem(newItem);
                } else {
                  final updatedItem = item.copyWith(
                    name: name,
                    price: price,
                    taxRate: tax,
                  );

                  await ref.read(itemProvider.notifier).updateItem(updatedItem);
                }

                await DatabaseHelper.instance.upsertHistory(name);

                await loadHistory();

                if (!mounted) return;
                navigator.pop(); // ←安全
              },
              child: Text(item == null ? '追加' : '更新'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCheckedDialog() {
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('購入済みを削除'),

          content: const Text('購入済みの商品をすべて削除しますか？'),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text('キャンセル'),
            ),

            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);

                final deletedItems = await ref
                    .read(itemProvider.notifier)
                    .deleteCheckedItemsWithUndo();

                _pendingUndoItems = List.from(deletedItems);

                if (!mounted) return;

                navigator.pop();

                _showUndoSnackBar(
                  message: '${_pendingUndoItems?.length ?? 0}件削除しました',
                );
              },

              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  void _showUndoSnackBar({required String message}) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    final snackBar = SnackBar(
      duration: const Duration(seconds: 5),

      content: Text(message),

      action: SnackBarAction(
        label: '元に戻す',

        onPressed: () async {
          final items = _pendingUndoItems;

          if (items == null || items.isEmpty) return;

          for (final item in items) {
            await ref.read(itemProvider.notifier).restoreItemWithOrder(item);
          }

          _pendingUndoItems = null;
        },
      ),
    );

    final controller = messenger.showSnackBar(snackBar);

    controller.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        _pendingUndoItems = null;
      }
    });
  }

  Widget _buildItemTile(Item item, {int? reorderIndex}) {
    return Dismissible(
      key: ValueKey('${item.id}_${item.isChecked}'),
      direction: DismissDirection.endToStart,

      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text('削除', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),

      onDismissed: (_) async {
        final deleted = await ref
            .read(itemProvider.notifier)
            .deleteItemById(item.id!);

        if (deleted != null) {
          _pendingUndoItems = [deleted];
        }

        if (!mounted) return;

        _showUndoSnackBar(message: '削除しました');
      },

      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (value) async {
            if (value == null) return;

            await ref.read(itemProvider.notifier).toggleCheck(item.id!);
          },
        ),

        onTap: () => _showAddItemDialog(
          item: item,
          items: ref.read(itemProvider).value ?? [],
        ),

        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : null,
          ),
        ),

        subtitle: Text(
          '税別: ¥${item.price} / '
          '税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / '
          '税率: ${(item.taxRate * 100).toInt()}%',
        ),

        trailing: reorderIndex != null
            ? ReorderableDragStartListener(
                index: reorderIndex,
                child: const Icon(Icons.drag_handle),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemProvider);

    final items = itemAsync.value ?? [];
    final checked = checkedItems(items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物リスト'),

        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),

            onPressed: checked.isEmpty ? null : _showDeleteCheckedDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: itemAsync.when(
          data: (items) {
            final unchecked = uncheckedItems(items);
            final checked = checkedItems(items);

            return items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('＋ボタンから追加してください'),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          '未購入',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('税別合計: ¥${uncheckedSubtotal(items).toInt()}'),
                            Text('税込合計: ¥${uncheckedTotal(items).toInt()}'),
                          ],
                        ),
                      ),

                      ReorderableListView(
                        buildDefaultDragHandles: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) async {
                          await ref
                              .read(itemProvider.notifier)
                              .reorderUncheckedItems(oldIndex, newIndex);
                        },
                        children: [
                          for (int i = 0; i < unchecked.length; i++)
                            _buildItemTile(unchecked[i], reorderIndex: i),
                        ],
                      ),

                      const Divider(thickness: 1.5),

                      if (checked.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            '購入済',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                      if (checked.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('税別合計: ¥${checkedSubtotal(items).toInt()}'),
                              Text('税込合計: ¥${checkedTotal(items).toInt()}'),
                            ],
                          ),
                        ),

                      ...checked.map((item) => _buildItemTile(item)),
                    ],
                  );
          },

          loading: () => const Center(child: CircularProgressIndicator()),

          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showAddItemDialog(items: ref.read(itemProvider).value ?? []),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}
