import 'package:flutter/material.dart';
import '../models/item.dart';
import '../database/database_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_provider.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list.dart';
import 'dart:async';
import '../widgets/item_tile.dart';
import '../widgets/total_summary.dart';
import '../widgets/add_item_dialog.dart';

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
  bool _isChangingTab = false;
  final numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();

    loadHistory();
    loadLists();
  }

  Future<void> loadHistory() async {
    final data = await DatabaseHelper.instance.getHistoryNames();

    if (!mounted) return;

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

    if (!mounted) return;

    setState(() {
      shoppingLists = data;
    });
  }

  Future<void> changeList(int listId) async {
    currentListId = listId;

    await ref.read(itemProvider.notifier).changeList(listId);

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _showAddListDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('新規リスト'),

          actionsOverflowDirection: VerticalDirection.down,

          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'リスト名'),
            ),
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
    ).whenComplete(() {
      controller.dispose();
    });
  }

  Future<void> _showDeleteListDialog() async {
    // 最低1個は残す
    if (shoppingLists.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最後のリストは削除できません')));

      return;
    }

    ShoppingList? currentList;

    try {
      currentList = shoppingLists.firstWhere((e) => e.id == currentListId);
    } catch (_) {
      currentList = null;
    }

    if (currentList == null) {
      return;
    }

    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('リスト削除'),

          content: Text(
            '「${currentList!.name}」を削除しますか？\n'
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

                if (!mounted) return;

                _tabController?.animateTo(0);

                if (shoppingLists.isEmpty) {
                  return;
                }

                final nextList = shoppingLists.first;

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

          actionsOverflowDirection: VerticalDirection.down,

          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'リスト名'),
            ),
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
    ).whenComplete(() {
      controller.dispose();
    });
  }

  Future<void> _handleTabChange() async {
    if (_tabController == null) return;

    if (_isChangingTab) return;

    if (_tabController!.indexIsChanging) return;

    if (_tabController!.index >= shoppingLists.length) {
      return;
    }

    _isChangingTab = true;

    try {
      final selectedList = shoppingLists[_tabController!.index];

      await changeList(selectedList.id!);
    } finally {
      _isChangingTab = false;
    }
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

      final messenger = ScaffoldMessenger.maybeOf(context);

      if (messenger == null) return;

      messenger.clearSnackBars();
    });
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
    final checked = items.where((e) => e.isChecked).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                shoppingLists.isEmpty
                    ? '買い物リスト'
                    : (() {
                        try {
                          return shoppingLists
                              .firstWhere((e) => e.id == currentListId)
                              .name;
                        } catch (_) {
                          return '買い物リスト';
                        }
                      })(),
              ),
            ),

            IconButton(
              onPressed: _showAddListDialog,
              icon: const Icon(Icons.add),
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
            final unchecked = items.where((e) => !e.isChecked).toList();
            final checked = items.where((e) => e.isChecked).toList();

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

                      TotalSummary(
                        items: items,
                        showDetailedTotal: showDetailedTotal,

                        onToggle: () {
                          setState(() {
                            showDetailedTotal = !showDetailedTotal;
                          });
                        },
                      ),

                      ReorderableListView(
                        buildDefaultDragHandles: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(itemProvider.notifier)
                              .reorderUncheckedItems(oldIndex, newIndex);
                        },
                        children: [
                          for (int i = 0; i < unchecked.length; i++)
                            ItemTile(
                              item: unchecked[i],
                              reorderIndex: i,
                              numberFormat: numberFormat,

                              onTap: () => showAddItemDialog(
                                context: context,
                                ref: ref,
                                currentListId: currentListId,
                                historyNames: historyNames,
                                item: unchecked[i],
                                items: ref.read(itemProvider).value ?? [],
                              ),

                              onToggleCheck: (value) async {
                                if (value == null) return;

                                await ref
                                    .read(itemProvider.notifier)
                                    .toggleCheck(unchecked[i].id!);
                              },

                              onDismissed: () async {
                                final deleted = await ref
                                    .read(itemProvider.notifier)
                                    .deleteItemById(unchecked[i].id!);

                                if (deleted != null) {
                                  _pendingUndoItems = [deleted];
                                }

                                if (!mounted) return;

                                _showUndoSnackBar(message: '削除しました');
                              },
                            ),
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

                      ...checked.map(
                        (item) => ItemTile(
                          item: item,
                          numberFormat: numberFormat,

                          onTap: () => showAddItemDialog(
                            context: context,
                            ref: ref,
                            currentListId: currentListId,
                            historyNames: historyNames,
                            item: item,
                            items: ref.read(itemProvider).value ?? [],
                          ),

                          onToggleCheck: (value) async {
                            if (value == null) return;

                            await ref
                                .read(itemProvider.notifier)
                                .toggleCheck(item.id!);
                          },

                          onDismissed: () async {
                            final deleted = await ref
                                .read(itemProvider.notifier)
                                .deleteItemById(item.id!);

                            if (deleted != null) {
                              _pendingUndoItems = [deleted];
                            }

                            if (!mounted) return;

                            _showUndoSnackBar(message: '削除しました');
                          },
                        ),
                      ),
                    ],
                  );
          },

          loading: () => const Center(child: CircularProgressIndicator()),

          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddItemDialog(
          context: context,
          ref: ref,
          currentListId: currentListId,
          historyNames: historyNames,
          items: ref.read(itemProvider).value ?? [],
        ),

        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}
