import 'package:flutter/material.dart';
import '../models/item.dart';
import '../database/database_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen>
    with TickerProviderStateMixin {
  List<String> historyNames = [];
  List<Item>? _pendingUndoItems;
  List<ShoppingList> shoppingLists = [];

  TabController? _tabController;

  int currentListId = 1;
  bool showDetailedTotal = false;
  final _formKey = GlobalKey<FormState>();
  final numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();

    loadHistory();
    loadLists();
  }

  Future<void> loadHistory() async {
    final data = await DatabaseHelper.instance.getHistoryNames();
    setState(() {
      historyNames = data;
    });
  }

  Future<void> loadLists() async {
    final data = await DatabaseHelper.instance.getLists();

    if (data.isNotEmpty) {
      final exists = data.any((e) => e.id == currentListId);

      if (!exists) {
        currentListId = data.first.id!;
      }
    }

    final currentIndex = data.indexWhere((e) => e.id == currentListId);

    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();

    if (data.isNotEmpty) {
      _tabController = TabController(
        length: data.length,
        vsync: this,
        initialIndex: currentIndex == -1 ? 0 : currentIndex,
      );

      _tabController?.addListener(_handleTabChange);
    } else {
      _tabController = null;
    }

    setState(() {
      shoppingLists = data;
    });
  }

  Future<void> changeList(int listId) async {
    currentListId = listId;

    await ref.read(itemProvider.notifier).changeList(listId);

    setState(() {});
  }

  Future<void> _showAddListDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('新規リスト'),

          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'リスト名'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),

            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                final navigator = Navigator.of(context);

                final newList = ShoppingList(name: name);

                final id = await DatabaseHelper.instance.insertList(newList);

                await loadLists();

                if (!mounted) return;

                navigator.pop();

                await changeList(id);

                final newIndex = shoppingLists.indexWhere((e) => e.id == id);

                if (newIndex != -1) {
                  _tabController?.animateTo(newIndex);
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteListDialog() async {
    // 最低1個は残す
    if (shoppingLists.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最後のリストは削除できません')));

      return;
    }

    final currentList = shoppingLists.firstWhere((e) => e.id == currentListId);

    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('リスト削除'),

          content: Text(
            '「${currentList.name}」を削除しますか？\n'
            '商品もすべて削除されます。',
          ),

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

                await DatabaseHelper.instance.deleteList(currentListId);

                await loadLists();

                _tabController?.animateTo(0);

                final nextList = shoppingLists.first;

                if (!mounted) return;

                navigator.pop();

                await changeList(nextList.id!);
              },

              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameListDialog() async {
    final currentList = shoppingLists.firstWhere((e) => e.id == currentListId);

    final controller = TextEditingController(text: currentList.name);

    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('リスト名変更'),

          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'リスト名'),
          ),

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

                final newName = controller.text.trim();

                if (newName.isEmpty) {
                  return;
                }

                await DatabaseHelper.instance.updateListName(
                  currentListId,
                  newName,
                );

                await loadLists();

                if (!mounted) return;

                navigator.pop();

                setState(() {});
              },

              child: const Text('変更'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleTabChange() async {
    if (_tabController == null) return;

    if (_tabController!.indexIsChanging) return;

    final selectedList = shoppingLists[_tabController!.index];

    await changeList(selectedList.id!);
  }

  List<Item> uncheckedItems(List<Item> items) =>
      items.where((e) => !e.isChecked).toList();

  List<Item> checkedItems(List<Item> items) =>
      items.where((e) => e.isChecked).toList();

  int uncheckedSubtotal(List<Item> items) =>
      uncheckedItems(items).fold(0, (s, e) => s + (e.price * e.quantity));

  double uncheckedTotal(List<Item> items) => uncheckedItems(
    items,
  ).fold(0, (s, e) => s + (e.price * e.quantity) * (1 + e.taxRate));

  int checkedSubtotal(List<Item> items) =>
      checkedItems(items).fold(0, (s, e) => s + (e.price * e.quantity));

  double checkedTotal(List<Item> items) => checkedItems(
    items,
  ).fold(0, (s, e) => s + (e.price * e.quantity) * (1 + e.taxRate));

  void _showAddItemDialog({Item? item, required List<Item> items}) {
    final autoController = TextEditingController(
      text: item?.name == '未入力' ? '' : item?.name ?? '',
    );
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '0',
    );
    final taxController = TextEditingController(
      text: item != null ? (item.taxRate * 100).toInt().toString() : '0',
    );
    final quantityController = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    final priceFocusNode = FocusNode();
    final taxFocusNode = FocusNode();
    final quantityFocusNode = FocusNode();
    final memoController = TextEditingController(text: item?.memo ?? '');

    void selectAllOnFocus(
      FocusNode focusNode,
      TextEditingController controller,
    ) {
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          Future.delayed(Duration.zero, () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          });
        }
      });
    }

    selectAllOnFocus(priceFocusNode, priceController);
    selectAllOnFocus(taxFocusNode, taxController);
    selectAllOnFocus(quantityFocusNode, quantityController);

    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text(item == null ? '商品追加' : '商品編集'),
          content: Form(
            key: _formKey,
            child: Column(
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

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: '商品名'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '商品名を入力してください';
                            }

                            return null;
                          },
                        );
                      },
                ),
                TextFormField(
                  controller: priceController,
                  focusNode: priceFocusNode,
                  decoration: const InputDecoration(
                    labelText: '金額',
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final price = int.tryParse(value ?? '');

                    if (price == null) {
                      return '数値を入力してください';
                    }

                    if (price < 0) {
                      return '0以上を入力してください';
                    }

                    return null;
                  },
                ),
                TextFormField(
                  controller: taxController,
                  focusNode: taxFocusNode,
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
                  validator: (value) {
                    final tax = double.tryParse(value ?? '');

                    if (tax == null) {
                      return '数値を入力してください';
                    }

                    if (tax < 0 || tax > 100) {
                      return '0〜100で入力してください';
                    }

                    return null;
                  },
                ),
                TextFormField(
                  controller: quantityController,
                  focusNode: quantityFocusNode,
                  decoration: const InputDecoration(
                    labelText: '個数',
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');

                    if (quantity == null || quantity <= 0) {
                      return '1以上を入力してください';
                    }

                    return null;
                  },
                ),
                TextFormField(
                  controller: memoController,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    hintText: '任意',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
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

                final quantity = int.tryParse(quantityController.text) ?? 1;

                if (item == null) {
                  final newItem = Item(
                    listId: currentListId,
                    name: name,
                    price: price,
                    taxRate: tax,
                    isChecked: false,
                    sortOrder: items.length,
                    quantity: quantity,
                    memo: memoController.text.trim(),
                  );

                  await ref.read(itemProvider.notifier).addItem(newItem);
                } else {
                  final updatedItem = item.copyWith(
                    name: name,
                    price: price,
                    taxRate: tax,
                    quantity: quantity,
                    memo: memoController.text.trim(),
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
    ).whenComplete(() {
      priceFocusNode.dispose();
      taxFocusNode.dispose();
      quantityFocusNode.dispose();
    });
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

    messenger.showSnackBar(snackBar);

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;

      if (_pendingUndoItems != null) {
        _pendingUndoItems = null;
        messenger.clearSnackBars();
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

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '単価: ¥${numberFormat.format(item.price)} / '
              '個数: ${item.quantity} / '
              '税込合計: ¥${numberFormat.format(((item.price * item.quantity) * (1 + item.taxRate)).toInt())}',
            ),

            if (item.memo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.memo,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
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
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemProvider);

    final items = itemAsync.value ?? [];
    final checked = checkedItems(items);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                shoppingLists.isEmpty
                    ? '買い物リスト'
                    : shoppingLists
                          .firstWhere((e) => e.id == currentListId)
                          .name,
              ),
            ),

            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showRenameListDialog,
            ),

            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteListDialog,
            ),

            IconButton(
              onPressed: _showAddListDialog,
              icon: const Icon(Icons.add),
            ),

            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: checked.isEmpty ? null : _showDeleteCheckedDialog,
            ),
          ],
        ),

        bottom: shoppingLists.isEmpty || _tabController == null
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,

                tabs: [for (final list in shoppingLists) Tab(text: list.name)],
              ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),

                          onTap: () {
                            setState(() {
                              showDetailedTotal = !showDetailedTotal;
                            });
                          },

                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),

                            crossFadeState: showDetailedTotal
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,

                            firstChild: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '未購入 ¥${numberFormat.format(uncheckedTotal(items).toInt())}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    '購入済 ¥${numberFormat.format(checkedTotal(items).toInt())}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),

                            secondChild: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    '未購入',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    '税別 ¥${numberFormat.format(uncheckedSubtotal(items).toInt())}',
                                  ),

                                  Text(
                                    '税込 ¥${numberFormat.format(uncheckedTotal(items).toInt())}',
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    '購入済',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),

                                  Text(
                                    '税別 ¥${numberFormat.format(checkedSubtotal(items).toInt())}',
                                  ),

                                  Text(
                                    '税込 ¥${numberFormat.format(checkedTotal(items).toInt())}',
                                  ),
                                ],
                              ),
                            ),
                          ),
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
