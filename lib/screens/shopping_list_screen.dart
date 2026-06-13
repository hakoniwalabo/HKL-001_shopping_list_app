import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share;

import '../database/database_helper.dart';
import '../models/item.dart';
import '../models/shopping_list.dart';
import '../providers/item_provider.dart';
import '../providers/purchase_provider.dart';
import '../widgets/ad_banner.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/list_management_buttons.dart';
import '../widgets/list_section.dart';
import '../widgets/list_tab_bar.dart';
import '../widgets/favorites_dialog.dart';
import '../widgets/help_dialog.dart';
import '../widgets/total_summary.dart';
import '../widgets/upgrade_dialog.dart';
import '../services/backup_service.dart';

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
    // 上限チェック（設計書 §8.10）
    if (shoppingLists.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リストは最大10件まで作成できます')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SingleFieldDialog(
        title: '新規リスト',
        labelText: 'リスト名',
        submitLabel: '追加',
        onSubmit: (name) async {
          final newList = ShoppingList(name: name);
          final id = await DatabaseHelper.instance.insertList(newList);
          await loadLists();
          if (!mounted) return;
          await changeList(id);
          final newIndex = shoppingLists.indexWhere((e) => e.id == id);
          if (newIndex != -1) {
            _tabController?.animateTo(newIndex);
          }
        },
      ),
    );
  }

  /// 現在のリストをテキスト化してOS共有シートで送る
  Future<void> _shareCurrentList() async {
    final currentList = shoppingLists.firstWhere(
      (e) => e.id == currentListId,
      orElse: () => ShoppingList(name: '買い物リスト'),
    );

    final items = await DatabaseHelper.instance.getItemsByListId(currentListId);

    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リストが空です')),
      );
      return;
    }

    final fmt = NumberFormat('#,###');
    final buf = StringBuffer();
    buf.writeln('【${currentList.name}】');
    buf.writeln('─' * 20);

    final unchecked = items.where((e) => !e.isChecked).toList();
    final checked = items.where((e) => e.isChecked).toList();

    for (final item in unchecked) {
      final qty = item.quantity > 1 ? ' ×${item.quantity}' : '';
      final price = item.price > 0 ? '  ¥${fmt.format(item.price * item.quantity)}' : '';
      final memo = item.memo.isNotEmpty ? '  ※${item.memo}' : '';
      buf.writeln('□ ${item.name}$qty$price$memo');
    }

    if (checked.isNotEmpty) {
      buf.writeln('');
      for (final item in checked) {
        final qty = item.quantity > 1 ? ' ×${item.quantity}' : '';
        final price = item.price > 0 ? '  ¥${fmt.format(item.price * item.quantity)}' : '';
        buf.writeln('✓ ${item.name}$qty$price');
      }
    }

    buf.writeln('─' * 20);

    final uncheckedTotal = unchecked.fold(0, (s, e) => s + e.price * e.quantity);
    final checkedTotal = checked.fold(0, (s, e) => s + e.price * e.quantity);
    if (uncheckedTotal > 0) buf.writeln('未購入合計: ¥${fmt.format(uncheckedTotal)}');
    if (checkedTotal > 0) buf.writeln('購入済合計: ¥${fmt.format(checkedTotal)}');

    await Share.share(buf.toString());
  }

  Future<void> _exportBackup() async {
    try {
      await BackupService.export();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップの作成に失敗しました')),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('バックアップデータを読み込む'),
        content: const Text(
          '既存のデータは残したまま、バックアップのデータが追加されます。よろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('読み込む'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await BackupService.import();
      if (result == null) return;
      if (!mounted) return;
      await loadLists();
      if (!mounted) return;
      await ref.read(itemProvider.notifier).changeList(currentListId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${result.listCount}リスト・${result.itemCount}件の商品・'
            '${result.favoriteCount}件のよく買うものを追加しました',
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.message == 'unsupported_version'
                ? '対応していないバックアップ形式です'
                : '読み込めないファイルです',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('読み込みに失敗しました')),
      );
    }
  }

  /// 現在のリストを複製する
  Future<void> _duplicateCurrentList() async {
    if (shoppingLists.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リストは最大10件まで作成できます')),
      );
      return;
    }

    final currentList = shoppingLists.firstWhere(
      (e) => e.id == currentListId,
      orElse: () => ShoppingList(name: '買い物リスト'),
    );

    final baseName = '${currentList.name}のコピー';
    final existingNames = shoppingLists.map((e) => e.name).toSet();
    String newName = baseName;
    if (existingNames.contains(baseName)) {
      int i = 2;
      while (existingNames.contains('$baseName($i)')) { i++; }
      newName = '$baseName($i)';
    }
    final newId = await DatabaseHelper.instance.duplicateList(currentListId, newName);

    await loadLists();

    if (!mounted) return;

    final newIndex = shoppingLists.indexWhere((e) => e.id == newId);
    if (newIndex != -1) {
      _tabController?.animateTo(newIndex);
      await changeList(newId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$newName」を作成しました')),
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

                // 削除前に現在のインデックスを保存（削除後は左隣へ）
                final deletedIndex = shoppingLists.indexWhere(
                  (e) => e.id == currentListId,
                );

                await DatabaseHelper.instance.deleteList(currentListId);

                await loadLists();

                if (!mounted) return;

                if (shoppingLists.isEmpty) {
                  navigator.pop();
                  return;
                }

                // 1つ左を選択（先頭を削除した場合は先頭のまま）
                final nextIndex = (deletedIndex - 1).clamp(
                  0,
                  shoppingLists.length - 1,
                );
                _tabController?.animateTo(nextIndex);

                navigator.pop();

                await changeList(shoppingLists[nextIndex].id!);
              },

              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameListDialog(ShoppingList list) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SingleFieldDialog(
        title: 'タブ名変更',
        labelText: 'タブ名',
        initialText: list.name,
        submitLabel: '変更',
        onSubmit: (newName) async {
          await DatabaseHelper.instance.updateListName(list.id!, newName);
          await loadLists();
          if (!mounted) return;
          setState(() {});
        },
      ),
    );
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

  void _showMoveToTabDialog(Item item) {
    final others = shoppingLists.where((l) => l.id != currentListId).toList();

    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('移動先のリストがありません')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移動先のリスト'),
        children: others
            .map(
              (list) => SimpleDialogOption(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(itemProvider.notifier)
                      .moveItemToList(item.id!, list.id!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「${list.name}」に移動しました')),
                  );
                },
                child: Text(list.name),
              ),
            )
            .toList(),
      ),
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
    const kHideAds = bool.fromEnvironment('HIDE_ADS');
    final isAdFree = kHideAds || ref.watch(purchaseProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物リスト'),

        actions: [
          ListManagementButtons(
            onAddList: _showAddListDialog,
            onDuplicateList: _duplicateCurrentList,
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'よく買うものから追加',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final count = await showDialog<int>(
                context: context,
                builder: (_) =>
                    FavoritesDialog(currentListId: currentListId),
              );
              if (!mounted) return;
              if (count != null && count > 0) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$count件追加しました')),
                );
              }
            },
          ),
          PopupMenuButton<_OptionItem>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'オプション',
            onSelected: (item) {
              switch (item) {
                case _OptionItem.deleteList:
                  _showDeleteListDialog();
                case _OptionItem.share:
                  _shareCurrentList();
                case _OptionItem.upgrade:
                  showDialog<void>(
                    context: context,
                    builder: (_) => const UpgradeDialog(),
                  );
                case _OptionItem.help:
                  showDialog<void>(
                    context: context,
                    builder: (_) => const HelpDialog(),
                  );
                case _OptionItem.backup:
                  _exportBackup();
                case _OptionItem.importBackup:
                  _importBackup();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _OptionItem.deleteList,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('リストを削除'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _OptionItem.share,
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('テキストで共有'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _OptionItem.backup,
                child: ListTile(
                  leading: Icon(Icons.backup_outlined),
                  title: Text('バックアップ'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _OptionItem.importBackup,
                child: ListTile(
                  leading: Icon(Icons.restore_outlined),
                  title: Text('バックアップデータを読み込む'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (!isAdFree)
                const PopupMenuItem(
                  value: _OptionItem.upgrade,
                  child: ListTile(
                    leading: Icon(Icons.star_outline),
                    title: Text('広告を削除'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: _OptionItem.help,
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('使い方'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],

        bottom: ListTabBar(
          shoppingLists: shoppingLists,
          tabController: _tabController,
          onRenameTab: _showRenameListDialog,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: itemAsync.when(
        data: (items) {
          final unchecked = items.where((e) => !e.isChecked).toList();
          final checked = items.where((e) => e.isChecked).toList();

          return Column(
            children: [
              // 合計表示（タブ直下・設計書 §5.2 / §8.8）
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TotalSummary(items: items),
              ),
              const Divider(height: 1),
              // リスト本体
              Expanded(
                child: items.isEmpty
                    ? const EmptyStateView()
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: ListView(
                          children: [
                            if (checked.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _showDeleteCheckedDialog,
                                    icon: const Icon(Icons.delete_sweep),
                                    label: const Text('購入済み削除'),
                                  ),
                                ),
                              ),
                            ListSection(
                              title: '未購入',

                              items: unchecked,

                              reorderable: true,

                              numberFormat: numberFormat,

                              onMoveToTab: (item) => () => _showMoveToTabDialog(item),

                              onTap: (item) => () {
                                // ダイアログを閉じた後に履歴を再読み込み（§8.9）
                                showAddItemDialog(
                                  context: context,
                                  currentListId: currentListId,
                                  historyNames: historyNames,
                                  item: item,
                                ).then((_) {
                                  if (mounted) loadHistory();
                                });
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

                              onMoveToTab: (item) => () => _showMoveToTabDialog(item),

                              onTap: (item) => () {
                                showAddItemDialog(
                                  context: context,
                                  currentListId: currentListId,
                                  historyNames: historyNames,
                                  item: item,
                                ).then((_) {
                                  if (mounted) loadHistory();
                                });
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
                        ),
                      ),
              ),
            ],
          );
        },

        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, stack) => Center(child: Text('Error: $error')),
          ),
          ),
          // バナー広告（広告なし購入済みの場合は非表示）
          if (!isAdFree) const AdBannerWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showAddItemDialog(
            context: context,
            currentListId: currentListId,
            historyNames: historyNames,
          );
          if (mounted) await loadHistory();
        },

        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}

enum _OptionItem { share, upgrade, help, deleteList, backup, importBackup }

class _SingleFieldDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String? initialText;
  final String submitLabel;
  final Future<void> Function(String value) onSubmit;

  const _SingleFieldDialog({
    required this.title,
    required this.labelText,
    this.initialText,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<_SingleFieldDialog> createState() => _SingleFieldDialogState();
}

class _SingleFieldDialogState extends State<_SingleFieldDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      actionsOverflowDirection: VerticalDirection.down,
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.labelText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context);
            await widget.onSubmit(value);
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
