import 'package:flutter/material.dart';
import '../models/item.dart';
import '../database/database_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_provider.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  List<String> historyNames = [];
  Item? _deletedItem;

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
                decoration: const InputDecoration(labelText: '金額'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: taxController,
                decoration: const InputDecoration(labelText: '税率（%）'),
                keyboardType: TextInputType.number,
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
                final name = autoController.text.isNotEmpty
                    ? autoController.text
                    : '未入力';

                final price = int.tryParse(priceController.text) ?? 0;
                final taxPercent = double.tryParse(taxController.text) ?? 0;
                final tax = taxPercent / 100.0;

                if (item == null) {
                  // 既存を後ろへずらす
                  for (final e in items) {
                    e.sortOrder = (e.sortOrder ?? 0) + 1;
                  }

                  await DatabaseHelper.instance.updateSortOrders(items);

                  // 新規を先頭へ
                  final newItem = Item(
                    name: name,
                    price: price,
                    taxRate: tax,
                    isChecked: false,
                    sortOrder: 0,
                  );

                  await DatabaseHelper.instance.insertItem(newItem);
                } else {
                  item.name = name;
                  item.price = price;
                  item.taxRate = tax;
                  await DatabaseHelper.instance.updateItem(item);
                }

                await DatabaseHelper.instance.upsertHistory(name);

                ref.invalidate(itemListProvider);
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

  Widget _buildUncheckedItem(Item item, int index) {
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
        _deletedItem = item;

        await DatabaseHelper.instance.deleteItem(item.id!);

        if (!mounted) return; // ←追加

        ref.invalidate(itemListProvider);

        if (!mounted) return; // ←追加

        final messenger = ScaffoldMessenger.of(context); // ←ここで取得

        messenger.showSnackBar(
          SnackBar(
            content: const Text('削除しました'),
            action: SnackBarAction(
              label: '元に戻す',
              onPressed: () async {
                if (_deletedItem != null) {
                  await DatabaseHelper.instance.insertItemWithId(_deletedItem!);

                  if (!mounted) return; // ←追加

                  ref.invalidate(itemListProvider);
                }
              },
            ),
          ),
        );
      },

      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (value) async {
            if (value == null) return;

            item.isChecked = value;

            await DatabaseHelper.instance.updateItem(item);
            ref.invalidate(itemListProvider);
          },
        ),
        onTap: () => _showAddItemDialog(
          item: item,
          items: ref.read(itemListProvider).value ?? [],
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          '税別: ¥${item.price} / 税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / 税率: ${(item.taxRate * 100).toInt()}%',
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
      ),
    );
  }

  Widget _buildCheckedItem(Item item) {
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
        _deletedItem = item;

        await DatabaseHelper.instance.deleteItem(item.id!);

        if (!mounted) return;

        ref.invalidate(itemListProvider);

        if (!mounted) return;

        final messenger = ScaffoldMessenger.of(context);

        messenger.showSnackBar(
          SnackBar(
            content: const Text('削除しました'),
            action: SnackBarAction(
              label: '元に戻す',
              onPressed: () async {
                if (_deletedItem == null) return;

                await DatabaseHelper.instance.insertItemWithId(_deletedItem!);

                if (!mounted) return;

                ref.invalidate(itemListProvider);
              },
            ),
          ),
        );
      },

      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (value) async {
            if (value == null) return;

            item.isChecked = value;

            await DatabaseHelper.instance.updateItem(item);
            ref.invalidate(itemListProvider);
          },
        ),

        onTap: () => _showAddItemDialog(
          item: item,
          items: ref.read(itemListProvider).value ?? [],
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : null,
          ),
        ),

        subtitle: Text(
          '税別: ¥${item.price} / 税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / 税率: ${(item.taxRate * 100).toInt()}%',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('買い物リスト')),
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
                          if (newIndex > oldIndex) newIndex--;

                          final movedItem = unchecked.removeAt(oldIndex);

                          unchecked.insert(newIndex, movedItem);

                          final newItems = [...unchecked, ...checked];

                          for (int i = 0; i < newItems.length; i++) {
                            newItems[i].sortOrder = i;
                          }

                          await DatabaseHelper.instance.updateSortOrders(
                            newItems,
                          );

                          ref.invalidate(itemListProvider);
                        },
                        children: [
                          for (int i = 0; i < unchecked.length; i++)
                            _buildUncheckedItem(unchecked[i], i),
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

                      ...checked.map(_buildCheckedItem),
                    ],
                  );
          },

          loading: () => const Center(child: CircularProgressIndicator()),

          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showAddItemDialog(items: ref.read(itemListProvider).value ?? []),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}
