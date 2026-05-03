import 'package:flutter/material.dart';
import '../models/item.dart';
import '../database/database_helper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<Item> items = [];
  List<String> historyNames = [];
  Item? _deletedItem;

  @override
  void initState() {
    super.initState();
    loadItems();
    loadHistory();
  }

  Future<void> loadItems() async {
    final data = await DatabaseHelper.instance.getItems();

    setState(() {
      items = data;
    });
  }

  Future<void> loadHistory() async {
    final data = await DatabaseHelper.instance.getHistoryNames();
    setState(() {
      historyNames = data;
    });
  }

  List<Item> get uncheckedItems => items.where((e) => !e.isChecked).toList();
  List<Item> get checkedItems => items.where((e) => e.isChecked).toList();

  double get uncheckedSubtotal => uncheckedItems.fold(0, (s, e) => s + e.price);
  double get uncheckedTotal =>
      uncheckedItems.fold(0, (s, e) => s + e.price * (1 + e.taxRate));

  double get checkedSubtotal => checkedItems.fold(0, (s, e) => s + e.price);
  double get checkedTotal =>
      checkedItems.fold(0, (s, e) => s + e.price * (1 + e.taxRate));

  void _showAddItemDialog({Item? item}) {
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
                  final newItem = Item(
                    name: name,
                    price: price,
                    taxRate: tax,
                    isChecked: false,
                    sortOrder: items.length,
                  );
                  await DatabaseHelper.instance.insertItem(newItem);
                } else {
                  item.name = name;
                  item.price = price;
                  item.taxRate = tax;
                  await DatabaseHelper.instance.updateItem(item);
                }

                await DatabaseHelper.instance.upsertHistory(name);

                await loadItems();
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

        await loadItems();

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

                  await loadItems();
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
            setState(() {
              item.isChecked = value;
            });
            await DatabaseHelper.instance.updateItem(item);
            await loadItems();
          },
        ),
        onTap: () => _showAddItemDialog(item: item),
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

        await loadItems();

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

                await loadItems();
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
            setState(() {
              item.isChecked = value;
            });
            await DatabaseHelper.instance.updateItem(item);
            await loadItems();
          },
        ),

        onTap: () => _showAddItemDialog(item: item),
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
    final list = uncheckedItems;

    return Scaffold(
      appBar: AppBar(title: const Text('買い物リスト')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: items.isEmpty
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
                        Text('税別合計: ¥${uncheckedSubtotal.toInt()}'),
                        Text('税込合計: ¥${uncheckedTotal.toInt()}'),
                      ],
                    ),
                  ),

                  ReorderableListView(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;

                      final list = uncheckedItems;

                      // 並び替え（未購入リスト内）
                      final movedItem = list.removeAt(oldIndex);
                      list.insert(newIndex, movedItem);

                      // items全体を再構築
                      final newItems = [
                        ...list, // 未購入（並び替え済み）
                        ...checkedItems, // 購入済（そのまま）
                      ];

                      // sortOrderを再割り当て
                      for (int i = 0; i < newItems.length; i++) {
                        newItems[i].sortOrder = i;
                      }

                      // DB更新（まとめて）
                      await DatabaseHelper.instance.updateSortOrders(newItems);

                      await loadItems();
                    },
                    children: [
                      for (int i = 0; i < list.length; i++)
                        _buildUncheckedItem(list[i], i),
                    ],
                  ),

                  const Divider(thickness: 1.5),

                  if (checkedItems.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '購入済',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                  if (checkedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('税別合計: ¥${checkedSubtotal.toInt()}'),
                          Text('税込合計: ¥${checkedTotal.toInt()}'),
                        ],
                      ),
                    ),

                  ...checkedItems.map(_buildCheckedItem),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}
