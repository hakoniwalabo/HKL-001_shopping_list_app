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

  @override
  void initState() {
    super.initState();
    loadItems();
    loadHistory();
  }

  Future<void> loadItems() async {
    final data = await DatabaseHelper.instance.getItems();

    data.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

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
                Navigator.pop(context);
              },
              child: Text(item == null ? '追加' : '更新'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUncheckedItem(Item item, int index) {
    return ListTile(
      key: ValueKey('${item.id}_${item.isChecked}'),
      leading: Checkbox(
        value: item.isChecked,
        onChanged: (value) async {
          if (value == null) return;
          setState(() {
            item.isChecked = value;
          });
          await DatabaseHelper.instance.updateItem(item);
          await loadItems(); // ← OK（順序重要）
        },
      ),
      title: GestureDetector(
        onTap: () => _showAddItemDialog(item: item),
        child: Text(item.name),
      ),
      subtitle: Text(
        '税別: ¥${item.price} / 税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / 税率: ${(item.taxRate * 100).toInt()}%',
      ),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
    );
  }

  Widget _buildCheckedItem(Item item) {
    return ListTile(
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
      title: GestureDetector(
        onTap: () => _showAddItemDialog(item: item),
        child: Text(
          item.name,
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      ),
      subtitle: Text(
        '税別: ¥${item.price} / 税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / 税率: ${(item.taxRate * 100).toInt()}%',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = uncheckedItems;

    return Scaffold(
      appBar: AppBar(title: const Text('買い物リスト')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('未購入', style: TextStyle(fontWeight: FontWeight.bold)),
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

              // 元リスト内の対象インデックスを取得
              final targetList = items.where((e) => !e.isChecked).toList();

              final movedItem = targetList[oldIndex];

              // items上の位置を取得
              final oldIndexInItems = items.indexOf(movedItem);

              // 削除
              items.removeAt(oldIndexInItems);

              // 挿入位置を計算
              final newTarget = targetList[newIndex];
              final newIndexInItems = items.indexOf(newTarget);

              items.insert(newIndexInItems, movedItem);

              // sortOrder更新
              for (int i = 0; i < items.length; i++) {
                items[i].sortOrder = i;
                await DatabaseHelper.instance.updateItem(items[i]);
              }

              await loadItems();
            },
            children: [
              for (int i = 0; i < list.length; i++)
                _buildUncheckedItem(list[i], i),
            ],
          ),

          const Divider(),

          if (checkedItems.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('購入済', style: TextStyle(fontWeight: FontWeight.bold)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
