# よく買うもの機能 v2 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** よく買う商品を登録・管理し、AppBar ♡ ボタンから複数選択して現在のリストに一括追加できる機能を実装する。

**Architecture:** DatabaseHelper に favorites テーブル（DB v6）と 5 つの CRUD メソッドを追加する。`FavoritesDialog`（ConsumerStatefulWidget）で favorites の表示・編集・削除・選択をローカル setState で管理し、`addFavoriteItemsToList` 後のみ `ItemNotifier.changeList()` で Riverpod を使用する。リスト削除ボタンは AppBar から ⋮ メニューへ移動し、空いたスペースに ♡ ボタンを配置する。

**Tech Stack:** Flutter / Dart, sqflite, flutter_riverpod (ConsumerStatefulWidget), Material3

---

## File Structure

| 操作 | ファイル | 内容 |
|------|---------|------|
| Modify | `lib/database/database_helper.dart` | version 5→6・favorites テーブル・CRUD 5メソッド |
| Modify | `lib/widgets/list_management_buttons.dart` | `onDeleteList` 削除（2ボタン構成へ） |
| Modify | `lib/screens/shopping_list_screen.dart` | AppBar 全変更（♡ボタン追加・⋮ メニュー更新） |
| Create | `lib/widgets/history_select_dialog.dart` | `HistorySelectDialog` |
| Create | `lib/widgets/favorites_dialog.dart` | `FavoritesDialog`・`_AddFavoriteDialog`・`_EditFavoriteDialog` |
| Modify | `lib/widgets/help_dialog.dart` | リスト削除説明更新・よく買うもの項目追加 |

---

### Task 1: DB v6 マイグレーション + favorites CRUD

**Files:**
- Modify: `lib/database/database_helper.dart`

- [ ] **Step 1: openDatabase の version を 6 に変更する**

`_initDB` メソッド内の `version: 5` を変更する：

```dart
return await openDatabase(
  path,
  version: 6,
  onCreate: _createDB,
  onUpgrade: _onUpgrade,
);
```

- [ ] **Step 2: `_createDB` に favorites テーブルを追加する**

`_createDB` メソッド内の `db.insert('lists', ...)` 呼び出しの後に追加する：

```dart
    await db.execute('''
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
```

- [ ] **Step 3: `_onUpgrade` に DB v6 アップグレード処理を追加する**

`_onUpgrade` メソッドの末尾（`if (oldVersion < 5) { ... }` ブロックの閉じ `}` の後）に追加する：

```dart
    if (oldVersion < 6) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
    }
```

- [ ] **Step 4: favorites CRUD メソッド 5 件を追加する**

`DatabaseHelper` クラスの末尾（`duplicateList` メソッドの閉じ `}` の直後、クラスの閉じ `}` の前）に追加する：

```dart
  // -------------------------
  // favorites CRUD
  // -------------------------

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return await db.query('favorites', orderBy: 'sortOrder ASC');
  }

  Future<void> insertFavorite(String name, int price, int quantity) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(sortOrder) as maxOrder FROM favorites',
    );
    final maxOrder = (result.first['maxOrder'] as int?) ?? -1;
    await db.insert('favorites', {
      'name': name,
      'price': price,
      'quantity': quantity,
      'sortOrder': maxOrder + 1,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateFavorite(
      int id, String name, int price, int quantity) async {
    final db = await database;
    await db.update(
      'favorites',
      {'name': name, 'price': price, 'quantity': quantity},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFavorite(int id) async {
    final db = await database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addFavoriteItemsToList(
      List<int> favoriteIds, int listId) async {
    final db = await database;
    await db.transaction((txn) async {
      final maxResult = await txn.rawQuery(
        'SELECT MAX(sortOrder) as maxOrder FROM items WHERE listId = ?',
        [listId],
      );
      int nextOrder = ((maxResult.first['maxOrder'] as int?) ?? -1) + 1;
      for (final favId in favoriteIds) {
        final rows = await txn.query(
          'favorites',
          where: 'id = ?',
          whereArgs: [favId],
        );
        if (rows.isEmpty) continue;
        final fav = rows.first;
        await txn.insert('items', {
          'name': fav['name'],
          'price': fav['price'],
          'quantity': fav['quantity'],
          'isChecked': 0,
          'memo': '',
          'listId': listId,
          'sortOrder': nextOrder++,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }
```

- [ ] **Step 5: flutter analyze を実行してエラーがないことを確認する**

```
flutter analyze lib/database/database_helper.dart
```

期待出力：`No issues found!`

- [ ] **Step 6: コミットする**

```
git add lib/database/database_helper.dart
git commit -m "feat: DB v6 favorites テーブル追加・CRUD メソッド5件実装"
```

---

### Task 2: AppBar 全変更（ListManagementButtons リファクタリング・♡ ボタン追加・⋮ メニュー更新）

`onDeleteList` の削除は `list_management_buttons.dart` と `shopping_list_screen.dart` の両方に影響するため、一括で変更してコンパイルエラーを避ける。

**Files:**
- Modify: `lib/widgets/list_management_buttons.dart`
- Modify: `lib/screens/shopping_list_screen.dart`

- [ ] **Step 1: `list_management_buttons.dart` を2ボタン構成に書き換える**

ファイル全体を以下で置き換える：

```dart
import 'package:flutter/material.dart';

class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onDuplicateList;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onDuplicateList,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onAddList,
          icon: const Icon(Icons.add),
          tooltip: 'リストを追加',
        ),
        IconButton(
          onPressed: onDuplicateList,
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'リストを複製',
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: `shopping_list_screen.dart` に `favorites_dialog.dart` の import を追加する**

ファイル先頭の import 群（`help_dialog.dart` import の直後）に追加する：

```dart
import '../widgets/favorites_dialog.dart';
```

- [ ] **Step 3: `_OptionItem` enum に `deleteList` を追加する**

ファイル末尾付近の enum を以下に変更する：

```dart
enum _OptionItem { share, upgrade, help, deleteList }
```

- [ ] **Step 4: AppBar の `actions:` リスト全体を置き換える**

`build` メソッド内の以下の範囲を置き換える：

置き換え前（`actions:` から `bottom:` の直前まで）：
```dart
        actions: [
          ListManagementButtons(
            onAddList: _showAddListDialog,
            onDeleteList: _showDeleteListDialog,
            onDuplicateList: _duplicateCurrentList,
          ),
          PopupMenuButton<_OptionItem>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'オプション',
            onSelected: (item) {
              switch (item) {
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
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _OptionItem.share,
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('テキストで共有'),
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
```

置き換え後：
```dart
        actions: [
          ListManagementButtons(
            onAddList: _showAddListDialog,
            onDuplicateList: _duplicateCurrentList,
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'よく買うものから追加',
            onPressed: () async {
              final count = await showDialog<int>(
                context: context,
                builder: (_) =>
                    FavoritesDialog(currentListId: currentListId),
              );
              if (!mounted) return;
              if (count != null && count > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
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
```

- [ ] **Step 5: flutter analyze を実行してエラーがないことを確認する**

```
flutter analyze lib/widgets/list_management_buttons.dart lib/screens/shopping_list_screen.dart
```

期待出力：`No issues found!`（`FavoritesDialog` は次タスクで作成するため、この時点では `shopping_list_screen.dart` のみ analyze エラーになる可能性がある。Step 6 のコミットは Task 4 完了後に行う。）

---

### Task 3: HistorySelectDialog を新規作成

**Files:**
- Create: `lib/widgets/history_select_dialog.dart`

- [ ] **Step 1: `history_select_dialog.dart` を新規作成する**

```dart
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class HistorySelectDialog extends StatefulWidget {
  final Future<void> Function(List<String> names) onRegister;

  const HistorySelectDialog({super.key, required this.onRegister});

  @override
  State<HistorySelectDialog> createState() => _HistorySelectDialogState();
}

class _HistorySelectDialogState extends State<HistorySelectDialog> {
  List<String> _allNames = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final names = await DatabaseHelper.instance.getHistoryNames();
    if (!mounted) return;
    setState(() {
      _allNames = names;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('履歴から登録'),
      content: SizedBox(
        width: double.maxFinite,
        child: _allNames.isEmpty
            ? const Text('履歴がありません')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _allNames.length,
                itemBuilder: (_, i) {
                  final name = _allNames[i];
                  return CheckboxListTile(
                    value: _selected.contains(name),
                    title: Text(name),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(name);
                        } else {
                          _selected.remove(name);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  final names = _selected.toList();
                  Navigator.pop(context);
                  await widget.onRegister(names);
                },
          child: const Text('登録'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: flutter analyze を実行する**

```
flutter analyze lib/widgets/history_select_dialog.dart
```

期待出力：`No issues found!`

---

### Task 4: FavoritesDialog を新規作成

**Files:**
- Create: `lib/widgets/favorites_dialog.dart`

- [ ] **Step 1: `favorites_dialog.dart` を新規作成する**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../providers/item_provider.dart';
import 'history_select_dialog.dart';

class FavoritesDialog extends ConsumerStatefulWidget {
  final int currentListId;

  const FavoritesDialog({super.key, required this.currentListId});

  @override
  ConsumerState<FavoritesDialog> createState() => _FavoritesDialogState();
}

class _FavoritesDialogState extends ConsumerState<FavoritesDialog> {
  List<Map<String, dynamic>> _favorites = [];
  final Set<int> _selectedIds = {};
  Map<String, dynamic>? _pendingUndoFavorite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = data;
      _selectedIds.removeWhere(
        (id) => !data.any((f) => f['id'] as int == id),
      );
    });
  }

  Future<void> _addToList() async {
    final ids = _selectedIds.toList();
    await DatabaseHelper.instance.addFavoriteItemsToList(
      ids,
      widget.currentListId,
    );
    await ref.read(itemProvider.notifier).changeList(widget.currentListId);
    if (!mounted) return;
    Navigator.pop(context, ids.length);
  }

  bool get _allSelected =>
      _favorites.isNotEmpty &&
      _favorites.every((f) => _selectedIds.contains(f['id'] as int));

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        for (final f in _favorites) {
          _selectedIds.add(f['id'] as int);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('よく買うもの'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_favorites.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(
                    _allSelected ? Icons.deselect : Icons.select_all,
                  ),
                  label: Text(_allSelected ? '全解除' : '全選択'),
                ),
              ),
            if (_favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('まだ登録されていません'),
              )
            else
              LimitedBox(
                maxHeight: 320,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _favorites.length,
                  itemBuilder: (_, i) {
                    final fav = _favorites[i];
                    final id = fav['id'] as int;
                    final name = fav['name'] as String;
                    final price = fav['price'] as int;
                    final qty = fav['quantity'] as int;
                    final subtitle =
                        price > 0 ? '¥$price × $qty' : '数量: $qty';
                    return Dismissible(
                      key: ValueKey(id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) async {
                        _pendingUndoFavorite = Map.from(fav);
                        _selectedIds.remove(id);
                        await DatabaseHelper.instance.deleteFavorite(id);
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('削除しました'),
                            action: SnackBarAction(
                              label: '元に戻す',
                              onPressed: () async {
                                final data = _pendingUndoFavorite;
                                if (data == null) return;
                                await DatabaseHelper.instance.insertFavorite(
                                  data['name'] as String,
                                  data['price'] as int,
                                  data['quantity'] as int,
                                );
                                _pendingUndoFavorite = null;
                                await _load();
                              },
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: Checkbox(
                          value: _selectedIds.contains(id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                        ),
                        title: Text(name),
                        subtitle: Text(subtitle),
                        onTap: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => _EditFavoriteDialog(
                              id: id,
                              initialName: name,
                              initialPrice: price,
                              initialQuantity: qty,
                            ),
                          );
                          await _load();
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => _AddFavoriteDialog(onAdded: _load),
            );
          },
          child: const Text('直接登録'),
        ),
        TextButton(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => HistorySelectDialog(
                onRegister: (names) async {
                  for (final name in names) {
                    await DatabaseHelper.instance.insertFavorite(name, 0, 1);
                  }
                  await _load();
                },
              ),
            );
          },
          child: const Text('履歴から登録'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty ? null : _addToList,
          child: const Text('リストに追加'),
        ),
      ],
    );
  }
}

class _AddFavoriteDialog extends StatefulWidget {
  final Future<void> Function() onAdded;

  const _AddFavoriteDialog({required this.onAdded});

  @override
  State<_AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<_AddFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('よく買うものに登録'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '商品名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
            ),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '税込価格'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
              },
            ),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '個数'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await DatabaseHelper.instance.insertFavorite(
              _nameCtrl.text.trim(),
              int.parse(_priceCtrl.text),
              int.parse(_qtyCtrl.text),
            );
            if (!mounted) return;
            Navigator.pop(context);
            await widget.onAdded();
          },
          child: const Text('登録'),
        ),
      ],
    );
  }
}

class _EditFavoriteDialog extends StatefulWidget {
  final int id;
  final String initialName;
  final int initialPrice;
  final int initialQuantity;

  const _EditFavoriteDialog({
    required this.id,
    required this.initialName,
    required this.initialPrice,
    required this.initialQuantity,
  });

  @override
  State<_EditFavoriteDialog> createState() => _EditFavoriteDialogState();
}

class _EditFavoriteDialogState extends State<_EditFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _priceCtrl = TextEditingController(text: widget.initialPrice.toString());
    _qtyCtrl =
        TextEditingController(text: widget.initialQuantity.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('よく買うものを編集'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '商品名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
            ),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '税込価格'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
              },
            ),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '個数'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await DatabaseHelper.instance.updateFavorite(
              widget.id,
              _nameCtrl.text.trim(),
              int.parse(_priceCtrl.text),
              int.parse(_qtyCtrl.text),
            );
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: flutter analyze を実行してエラーがないことを確認する**

```
flutter analyze lib/widgets/favorites_dialog.dart lib/widgets/history_select_dialog.dart lib/screens/shopping_list_screen.dart lib/widgets/list_management_buttons.dart
```

期待出力：`No issues found!`

- [ ] **Step 3: Task 2〜4 をまとめてコミットする**

```
git add lib/widgets/list_management_buttons.dart lib/screens/shopping_list_screen.dart lib/widgets/history_select_dialog.dart lib/widgets/favorites_dialog.dart
git commit -m "feat: よく買うもの機能を実装（FavoritesDialog・HistorySelectDialog・AppBar 更新）"
```

---

### Task 5: HelpDialog を更新

**Files:**
- Modify: `lib/widgets/help_dialog.dart`

- [ ] **Step 1: リスト削除の description を更新する**

以下の `_HelpItem` を変更する：

変更前：
```dart
            _HelpItem(
              icon: Icons.delete_outline,
              label: 'リストを削除',
              description: 'AppBar右上の「🗑」ボタン\n（最後のリストは削除できません）',
            ),
```

変更後：
```dart
            _HelpItem(
              icon: Icons.delete_outline,
              label: 'リストを削除',
              description: 'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）',
            ),
```

- [ ] **Step 2: よく買うもの項目を追加する**

「テキストで共有」の `_HelpItem` の直前に追加する：

```dart
            _HelpItem(
              icon: Icons.favorite_border,
              label: 'よく買うものから追加',
              description: 'AppBar右上のハートボタンから定番商品を登録・管理できます。チェックして「リストに追加」を押すと一括追加されます。商品をタップすると価格・個数を編集できます',
            ),
```

- [ ] **Step 3: プロジェクト全体の flutter analyze を実行する**

```
flutter analyze
```

期待出力：`No issues found!`

- [ ] **Step 4: コミットする**

```
git add lib/widgets/help_dialog.dart
git commit -m "feat: ヘルプ画面を更新（リスト削除説明・よく買うもの項目追加）"
```

---

## セルフレビュー

**Spec coverage チェック（`docs/superpowers/specs/2026-06-12-favorites-design-v2.md` 対照）：**

| 仕様 | 対応タスク |
|------|-----------|
| favorites テーブル + DB v6 マイグレーション | Task 1 |
| getFavorites / insertFavorite / updateFavorite / deleteFavorite / addFavoriteItemsToList | Task 1 |
| AppBar ♡ ボタン（Icons.favorite_border） | Task 2 |
| リスト削除を ⋮ メニューへ移動 | Task 2 |
| `onDeleteList` コールバック削除 | Task 2 |
| 全選択 / 全解除トグルボタン | Task 4 |
| Dismissible + ListTile + Checkbox(leading) | Task 4 |
| スワイプ削除 + Undo SnackBar | Task 4 |
| タップ → `_EditFavoriteDialog` | Task 4 |
| `_AddFavoriteDialog`（直接登録） | Task 4 |
| `HistorySelectDialog`（履歴から登録） | Task 3 |
| リストに追加 → `addFavoriteItemsToList` + `ItemNotifier.changeList` + SnackBar | Task 2 + 4 |
| favorites 0件時の空状態表示 | Task 4（`_favorites.isEmpty` 分岐） |
| favorites 0件時 全選択ボタン非表示 | Task 4（`if (_favorites.isNotEmpty)` 条件） |
| help_dialog.dart 更新 | Task 5 |

**Placeholder scan：** なし。全ステップにコードあり。

**Type consistency：**
- `DatabaseHelper.instance.getFavorites()` → `Future<List<Map<String, dynamic>>>` — Task 1 定義と Task 4 使用が一致
- `insertFavorite(String, int, int)` — Task 1 定義と Task 3・4 使用が一致
- `updateFavorite(int, String, int, int)` — Task 1 定義と Task 4 使用が一致
- `deleteFavorite(int)` — Task 1 定義と Task 4 使用が一致
- `addFavoriteItemsToList(List<int>, int)` — Task 1 定義と Task 4 使用が一致
- `ref.read(itemProvider.notifier).changeList(int)` — 既存コード（`shopping_list_screen.dart:100`）と一致
- `Navigator.pop(context, ids.length)` → `showDialog<int>` で受け取る — Task 2 と Task 4 が一致
