import '../database/database_helper.dart';
import 'package:flutter/material.dart';
import '../models/item.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
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

  List<Item> items = [];
  List<String> historyNames = [];

  // ★ 追加＋編集 共通ダイアログ
  void _showAddItemDialog({Item? item}) {
    TextEditingController autoController = TextEditingController(
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
                initialValue: TextEditingValue(
                  text: item?.name == '未入力' ? '' : item?.name ?? '',
                ),
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
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
                  );

                  await DatabaseHelper.instance.insertItem(newItem);
                } else {
                  item.name = name;
                  item.price = price;
                  item.taxRate = tax;

                  await DatabaseHelper.instance.updateItem(item);
                }

                await DatabaseHelper.instance.upsertHistory(name);

                await loadItems(); // ← ここでUI更新
                await loadHistory();

                Navigator.pop(context);
              },
              child: Text(item == null ? '追加' : '更新'),
            ),
          ],
        );
      },
    );
  }

  List<Item> get uncheckedItems => items.where((e) => !e.isChecked).toList();

  List<Item> get checkedItems => items.where((e) => e.isChecked).toList();

  double get uncheckedSubtotal => uncheckedItems.fold(0, (s, e) => s + e.price);

  double get uncheckedTotal =>
      uncheckedItems.fold(0, (s, e) => s + e.price * (1 + e.taxRate));

  double get checkedSubtotal => checkedItems.fold(0, (s, e) => s + e.price);

  double get checkedTotal =>
      checkedItems.fold(0, (s, e) => s + e.price * (1 + e.taxRate));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('買い物リスト')),
      body: Column(
        children: [
          // ===== 未購入 =====
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    '未購入',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: uncheckedItems.length,
                    itemBuilder: (context, index) {
                      final item = uncheckedItems[index];
                      return CheckboxListTile(
                        title: GestureDetector(
                          onTap: () => _showAddItemDialog(item: item), // ★ 編集
                          child: Text(item.name),
                        ),
                        subtitle: Text(
                          '税別: ¥${item.price} / 税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / 税率: ${(item.taxRate * 100).toInt()}%',
                        ),
                        value: item.isChecked,
                        onChanged: (value) async {
                          item.isChecked = value!;

                          await DatabaseHelper.instance.updateItem(item);
                          await loadItems();
                        },
                      );
                    },
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
              ],
            ),
          ),

          const Divider(),

          // ===== 購入済 =====
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    '購入済',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: checkedItems.length,
                    itemBuilder: (context, index) {
                      final item = checkedItems[index];
                      return CheckboxListTile(
                        title: GestureDetector(
                          onTap: () => _showAddItemDialog(item: item), // ★ 編集
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        subtitle: Text(
                          '税別: ¥${item.price} / 税込: ¥${(item.price * (1 + item.taxRate)).toInt()} / 税率: ${(item.taxRate * 100).toInt()}%',
                        ),
                        value: item.isChecked,
                        onChanged: (value) async {
                          item.isChecked = value!;

                          await DatabaseHelper.instance.updateItem(item);
                          await loadItems();
                        },
                      );
                    },
                  ),
                ),
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
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(), // ★ 追加
        child: const Icon(Icons.add),
      ),
    );
  }
}
