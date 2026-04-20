import 'package:flutter/material.dart';
import '../models/item.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<Item> items = [
    Item(name: 'りんご', price: 100, taxRate: 0.1),
    Item(name: 'パン', price: 200, taxRate: 0.1),
  ];

  // ★ 追加＋編集 共通ダイアログ
  void _showAddItemDialog({Item? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '',
    );
    final taxController = TextEditingController(
      text: item != null ? (item.taxRate * 100).toInt().toString() : '10',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item == null ? '商品追加' : '商品編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '商品名'),
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
              onPressed: () {
                final name = nameController.text;
                final price = int.tryParse(priceController.text) ?? 0;
                final taxPercent = double.tryParse(taxController.text) ?? 0;
                final tax = taxPercent / 100.0;

                if (name.isEmpty || price <= 0) return;

                setState(() {
                  if (item == null) {
                    // 新規追加
                    items.add(Item(name: name, price: price, taxRate: tax));
                  } else {
                    // 編集（上書き）
                    item.name = name;
                    item.price = price;
                    item.taxRate = tax;
                  }
                });

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
                        onChanged: (value) {
                          setState(() {
                            item.isChecked = value!;
                          });
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
                        onChanged: (value) {
                          setState(() {
                            item.isChecked = value!;
                          });
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
