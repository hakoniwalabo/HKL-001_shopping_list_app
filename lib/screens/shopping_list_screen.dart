import 'package:flutter/material.dart';
import '../models/item.dart';
import '../database/database_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_provider.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list.dart';
import 'dart:async';
import '../widgets/add_item_dialog.dart';
import '../widgets/list_section.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/list_management_buttons.dart';
import '../widgets/list_tab_bar.dart';

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

    final oldController = _tabController;

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

    oldController?.removeListener(_handleTabChange);
    oldController?.dispose();

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
        toolbarHeight: 72,
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

            ListManagementButtons(
              onAddList: _showAddListDialog,

              onRenameList: _showRenameListDialog,

              onDeleteList: _showDeleteListDialog,

              onDeleteChecked: checked.isEmpty
                  ? null
                  : _showDeleteCheckedDialog,
            ),
          ],
        ),

        bottom: ListTabBar(
          shoppingLists: shoppingLists,
          tabController: _tabController,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: itemAsync.when(
          data: (items) {
            final unchecked = items.where((e) => !e.isChecked).toList();
            final checked = items.where((e) => e.isChecked).toList();

            return items.isEmpty
                ? const EmptyStateView()
                : ListView(
                    children: [
                      ListSection(
                        title: '未購入',

                        items: unchecked,

                        reorderable: true,

                        numberFormat: numberFormat,

                        onTap: (item) => () {
                          showAddItemDialog(
                            context: context,
                            ref: ref,
                            currentListId: currentListId,
                            historyNames: historyNames,
                            item: item,
                            items: ref.read(itemProvider).value ?? [],
                          );
                        },

                        onToggleCheck: (item) async {
                          await ref
                              .read(itemProvider.notifier)
                              .toggleCheck(item.id!);
                        },

                        onDelete: (item) async {
                          final deleted = await ref
                              .read(itemProvider.notifier)
                              .deleteItemById(item.id!);

                          if (deleted != null) {
                            _pendingUndoItems = [deleted];
                          }

                          if (!mounted) return;

                          _showUndoSnackBar(message: '削除しました');
                        },

                        onReorder: (oldIndex, newIndex) async {
                          await ref
                              .read(itemProvider.notifier)
                              .reorderUncheckedItems(oldIndex, newIndex);
                        },
                      ),

                      const Divider(thickness: 1.5),

                      ListSection(
                        title: '購入済',

                        items: checked,

                        reorderable: false,

                        numberFormat: numberFormat,

                        onTap: (item) => () {
                          showAddItemDialog(
                            context: context,
                            ref: ref,
                            currentListId: currentListId,
                            historyNames: historyNames,
                            item: item,
                            items: ref.read(itemProvider).value ?? [],
                          );
                        },

                        onToggleCheck: (item) async {
                          await ref
                              .read(itemProvider.notifier)
                              .toggleCheck(item.id!);
                        },

                        onDelete: (item) async {
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
