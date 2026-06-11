# よく買うもの機能 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** よく買う商品を登録・管理し、ダイアログから複数選択して現在のリストに一括追加できる機能を実装する。

**Architecture:** DatabaseHelper に favorites テーブル（DB v6）と CRUD メソッドを追加し、2つの新規ウィジェット（FavoritesDialog・HistorySelectDialog）を作成。AppBar の ♡ ボタンから起動し、リスト削除は ⋮ メニューに移動する。

**Tech Stack:** Flutter / Dart, sqflite, flutter_riverpod, Material3

---

## ファイルマップ

| 操作 | ファイル | 変更内容 |
|------|---------|---------|
| 変更 | `lib/database/database_helper.dart` | DB v6・favorites テーブル・CRUD 4メソッド追加 |
| 新規 | `lib/widgets/favorites_dialog.dart` | FavoritesDialog + _AddFavoriteDialog |
| 新規 | `lib/widgets/history_select_dialog.dart` | HistorySelectDialog |
| 変更 | `lib/widgets/list_management_buttons.dart` | onDeleteList 削除 |
| 変更 | `lib/screens/shopping_list_screen.dart` | ♡ ボタン追加・⋮ にリスト削除移動・FavoritesDialog 接続 |
| 変更 | `lib/widgets/help_dialog.dart` | リスト削除説明更新・よく買うもの項目追加 |
| 変更 | `test/item_test.dart` | favorites sortOrder ロジックのテスト追加 |

---

## Task 1: DatabaseHelper — DB v6 + favorites CRUD

**Files:**
- Modify: `lib/database/database_helper.dart`
- Modify: `test/item_test.dart`

---

- [ ] **Step 1: item_test.dart に favorites sortOrder テストを追加**

`test/item_test.dart` の末尾（`}` の直前）に以下を追加する。

```dart
  // --------------------------------------------------------
  // favorites sortOrder 採番ロジック（設計書 §8.11）
  // --------------------------------------------------------
  group('favorites sortOrder 採番', () {
    int nextSortOrder(List<int> existing) {
      if (existing.isEmpty) return 0;
      return existing.reduce((a, b) => a > b ? a : b) + 1;
    }

    test('既存アイテムがない場合は 0 から開始', () {
      expect(nextSortOrder([]), 0);
    });

    test('既存アイテムがある場合は MAX + 1', () {
      expect(nextSortOrder([0, 2, 1]), 3);
    });

    test('favorites を複数追加時に sortOrder が連番になる', () {
      final base = nextSortOrder([0, 1]);
      final orders = List.generate(3, (i) => base + i);
      expect(orders, [2, 3, 4]);
    });
  });
```

- [ ] **Step 2: テストを実行してパスすることを確認**

```powershell
dart test test/item_test.dart
```

期待: `All tests passed.`（既存9件 + 新規3件 = 12件）

- [ ] **Step 3: database_helper.dart の DB バージョンを 6 に変更**

`_initDB` の `version: 5` を `version: 6` に変更する。

```dart
return await openDatabase(
  path,
  version: 6,
  onCreate: _createDB,
  onUpgrade: _onUpgrade,
);
```

- [ ] **Step 4: _createDB に favorites テーブルを追加**

`_createDB` メソッド内の既存 `db.execute` の末尾に追加する。

```dart
await db.execute('''
CREATE TABLE favorites(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
```

- [ ] **Step 5: _onUpgrade に v6 マイグレーションを追加**

`_onUpgrade` の末尾（`version 4 → 5` ブロックの後）に追加する。

```dart
if (oldVersion < 6) {
  await db.execute('''
CREATE TABLE IF NOT EXISTS favorites(
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

- [ ] **Step 6: favorites CRUD メソッドを追加**

`database_helper.dart` の末尾の `}` の直前に以下を追加する。

```dart
// -------------------------
// favorites CRUD
// -------------------------

Future<List<Map<String, dynamic>>> getFavorites() async {
  final db = await database;
  return await db.query('favorites', orderBy: 'sortOrder ASC, createdAt ASC');
}

Future<void> insertFavorite(String name, int price, int quantity) async {
  final db = await database;
  final result = await db.rawQuery(
    'SELECT MAX(sortOrder) as maxOrder FROM favorites',
  );
  final nextSortOrder = (result.first['maxOrder'] as int? ?? -1) + 1;
  await db.insert('favorites', {
    'name': name,
    'price': price,
    'quantity': quantity,
    'sortOrder': nextSortOrder,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  });
}

Future<void> deleteFavorite(int id) async {
  final db = await database;
  await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
}

Future<void> addFavoriteItemsToList(
  List<int> favoriteIds,
  int listId,
) async {
  final db = await database;
  await db.transaction((txn) async {
    final result = await txn.rawQuery(
      'SELECT MAX(sortOrder) as maxOrder FROM items WHERE listId = ?',
      [listId],
    );
    var nextSortOrder = (result.first['maxOrder'] as int? ?? -1) + 1;

    final placeholders = favoriteIds.map((_) => '?').join(', ');
    final favorites = await txn.rawQuery(
      'SELECT * FROM favorites WHERE id IN ($placeholders)',
      favoriteIds,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final fav in favorites) {
      await txn.insert('items', {
        'name': fav['name'],
        'price': fav['price'],
        'quantity': fav['quantity'],
        'isChecked': 0,
        'createdAt': now,
        'sortOrder': nextSortOrder++,
        'memo': '',
        'listId': listId,
      });
    }
  });
}
```

- [ ] **Step 7: flutter analyze を実行してエラーがないか確認**

```powershell
flutter analyze lib/database/database_helper.dart
```

期待: `No issues found!`

- [ ] **Step 8: コミット**

```powershell
git add lib/database/database_helper.dart test/item_test.dart
git commit -m "feat: DB v6 - favorites テーブル追加・CRUD メソッド実装"
```

---

## Task 2: favorites_dialog.dart 新規作成

**Files:**
- Create: `lib/widgets/favorites_dialog.dart`

---

- [ ] **Step 1: favorites_dialog.dart を新規作成**

`lib/widgets/favorites_dialog.dart` を以下の内容で作成する。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final data = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = data;
    });
  }

  Future<void> _deleteFavorite(int id) async {
    await DatabaseHelper.instance.deleteFavorite(id);
    setState(() => _selectedIds.remove(id));
    await _loadFavorites();
  }

  Future<void> _addToList() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    await DatabaseHelper.instance.addFavoriteItemsToList(
      _selectedIds.toList(),
      widget.currentListId,
    );
    await ref.read(itemProvider.notifier).changeList(widget.currentListId);
    if (!mounted) return;
    Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('よく買うもの'),
      content: SizedBox(
        width: double.maxFinite,
        child: _favorites.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('まだ登録されていません')),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final fav = _favorites[index];
                  final id = fav['id'] as int;
                  final name = fav['name'] as String;
                  final price = fav['price'] as int;
                  final quantity = fav['quantity'] as int;
                  final subtitle = price > 0
                      ? '¥${_fmt.format(price)} × $quantity'
                      : '数量: $quantity';
                  return CheckboxListTile(
                    value: _selectedIds.contains(id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      });
                    },
                    title: Text(name),
                    subtitle: Text(subtitle),
                    onLongPress: () => _deleteFavorite(id),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => _AddFavoriteDialog(onAdded: _loadFavorites),
            );
          },
          child: const Text('直接登録'),
        ),
        TextButton(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => HistorySelectDialog(onAdded: _loadFavorites),
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
  final VoidCallback onAdded;

  const _AddFavoriteDialog({required this.onAdded});

  @override
  State<_AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<_AddFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _quantityCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;
    await DatabaseHelper.instance.insertFavorite(name, price, quantity);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onAdded();
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '税込価格'),
              onTap: () => _priceCtrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _priceCtrl.text.length,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 0) ? '0以上の数値を入力してください' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '個数'),
              onTap: () => _quantityCtrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _quantityCtrl.text.length,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1) ? '1以上の数値を入力してください' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('登録'),
        ),
      ],
    );
  }
}
```

> **注意:** `history_select_dialog.dart` のインポートが含まれている。Task 3 完了前に analyze するとエラーになるため、Task 2 と Task 3 は続けて実施すること。

- [ ] **Step 2: コミットは Task 3 完了後にまとめて行う（Step 2 はスキップ）**

---

## Task 3: history_select_dialog.dart 新規作成

**Files:**
- Create: `lib/widgets/history_select_dialog.dart`

---

- [ ] **Step 1: history_select_dialog.dart を新規作成**

`lib/widgets/history_select_dialog.dart` を以下の内容で作成する。

```dart
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class HistorySelectDialog extends StatefulWidget {
  final VoidCallback onAdded;

  const HistorySelectDialog({super.key, required this.onAdded});

  @override
  State<HistorySelectDialog> createState() => _HistorySelectDialogState();
}

class _HistorySelectDialogState extends State<HistorySelectDialog> {
  List<String> _historyNames = [];
  final Set<String> _selectedNames = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.instance.getHistoryNames();
    if (!mounted) return;
    setState(() {
      _historyNames = data;
    });
  }

  Future<void> _submit() async {
    if (_selectedNames.isEmpty) return;
    for (final name in _selectedNames) {
      await DatabaseHelper.instance.insertFavorite(name, 0, 1);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('履歴から登録'),
      content: SizedBox(
        width: double.maxFinite,
        child: _historyNames.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('履歴がありません')),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _historyNames.length,
                itemBuilder: (context, index) {
                  final name = _historyNames[index];
                  return CheckboxListTile(
                    value: _selectedNames.contains(name),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedNames.add(name);
                        } else {
                          _selectedNames.remove(name);
                        }
                      });
                    },
                    title: Text(name),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _selectedNames.isEmpty ? null : _submit,
          child: const Text('登録'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: flutter analyze を実行してエラーがないか確認**

```powershell
flutter analyze lib/widgets/favorites_dialog.dart lib/widgets/history_select_dialog.dart
```

期待: `No issues found!`

- [ ] **Step 3: コミット**

```powershell
git add lib/widgets/favorites_dialog.dart lib/widgets/history_select_dialog.dart
git commit -m "feat: FavoritesDialog・HistorySelectDialog を新規作成"
```

---

## Task 4: AppBar リファクタ — リスト削除を ⋮ 移動・♡ ボタン追加

**Files:**
- Modify: `lib/widgets/list_management_buttons.dart`
- Modify: `lib/screens/shopping_list_screen.dart`

---

- [ ] **Step 1: list_management_buttons.dart から onDeleteList を削除**

`lib/widgets/list_management_buttons.dart` を以下に書き換える。

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

- [ ] **Step 2: shopping_list_screen.dart のインポートに favorites_dialog を追加**

既存の import 群の末尾（`upgrade_dialog.dart` の次）に追加する。

```dart
import '../widgets/favorites_dialog.dart';
```

- [ ] **Step 3: _OptionItem enum に deleteList を追加**

ファイル末尾付近の enum を更新する。

```dart
enum _OptionItem { share, upgrade, help, deleteList }
```

- [ ] **Step 4: ListManagementButtons の呼び出しを更新**

`shopping_list_screen.dart` の `ListManagementButtons(...)` 呼び出しを以下に変更する（`onDeleteList` 引数を削除）。

```dart
ListManagementButtons(
  onAddList: _showAddListDialog,
  onDuplicateList: _duplicateCurrentList,
),
```

- [ ] **Step 5: AppBar に ♡ ボタンを追加**

`ListManagementButtons(...)` と `PopupMenuButton(...)` の間に以下を挿入する。

```dart
IconButton(
  onPressed: () async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => FavoritesDialog(currentListId: currentListId),
    );
    if (!mounted) return;
    if (count != null && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count件追加しました')),
      );
    }
  },
  icon: const Icon(Icons.favorite_border),
  tooltip: 'よく買うものから追加',
),
```

- [ ] **Step 6: PopupMenuButton の itemBuilder に deleteList を追加**

`itemBuilder: (_) => [` の直後（share の PopupMenuItem より前）に以下を挿入する。

```dart
const PopupMenuItem(
  value: _OptionItem.deleteList,
  child: ListTile(
    leading: Icon(Icons.delete_outline),
    title: Text('リストを削除'),
    contentPadding: EdgeInsets.zero,
  ),
),
```

- [ ] **Step 7: onSelected に deleteList のハンドリングを追加**

`onSelected: (item) { switch (item) {` ブロックに以下の case を追加する。

```dart
case _OptionItem.deleteList:
  _showDeleteListDialog();
```

- [ ] **Step 8: flutter analyze を実行してエラーがないか確認**

```powershell
flutter analyze lib/widgets/list_management_buttons.dart lib/screens/shopping_list_screen.dart
```

期待: `No issues found!`

- [ ] **Step 9: コミット**

```powershell
git add lib/widgets/list_management_buttons.dart lib/screens/shopping_list_screen.dart
git commit -m "feat: AppBar に ♡ ボタン追加・リスト削除を ⋮ メニューへ移動"
```

---

## Task 5: help_dialog.dart 更新

**Files:**
- Modify: `lib/widgets/help_dialog.dart`

---

- [ ] **Step 1: リスト削除の説明文を ⋮ メニュー起動に変更**

`help_dialog.dart` 内の「リストを削除」`_HelpItem` の `description` を以下に変更する。

変更前:
```dart
_HelpItem(
  icon: Icons.delete_outline,
  label: 'リストを削除',
  description: 'AppBar右上の「🗑」ボタン\n（最後のリストは削除できません）',
),
```

変更後:
```dart
_HelpItem(
  icon: Icons.delete_outline,
  label: 'リストを削除',
  description: 'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）',
),
```

- [ ] **Step 2: よく買うもの項目を追加**

「テキストで共有」の `_HelpItem` の直前に以下を挿入する。

```dart
_HelpItem(
  icon: Icons.favorite_border,
  label: 'よく買うものから追加',
  description: 'AppBar右上のハートボタンからよく買う商品を登録・管理できます。チェックして「リストに追加」を押すと一括追加されます',
),
```

- [ ] **Step 3: flutter analyze を実行してエラーがないか確認**

```powershell
flutter analyze lib/widgets/help_dialog.dart
```

期待: `No issues found!`

- [ ] **Step 4: コミット**

```powershell
git add lib/widgets/help_dialog.dart
git commit -m "docs: ヘルプによく買うもの項目追加・リスト削除の説明を更新"
```

---

## Task 6: 全体確認・動作テスト

- [ ] **Step 1: flutter analyze でプロジェクト全体を確認**

```powershell
flutter analyze
```

期待: `No issues found!`

- [ ] **Step 2: dart test を実行して全テストがパスすることを確認**

```powershell
dart test test/item_test.dart
```

期待: `All tests passed.`（12件）

- [ ] **Step 3: 動作確認チェックリスト**

実機または emulator で以下をすべて確認する。

| # | 操作 | 期待結果 |
|---|------|---------|
| 1 | AppBar に ♡ アイコンが表示される | `Icons.favorite_border` が表示される |
| 2 | ♡ タップ → よく買うもの0件 | 「まだ登録されていません」が表示される |
| 3 | 「直接登録」から名前・金額・個数を入力して登録 | 一覧に追加される |
| 4 | 「履歴から登録」で複数選択して登録 | price=0・quantity=1 で一覧に追加される |
| 5 | 登録済み商品を1件以上チェックして「リストに追加」 | SnackBar「X件追加しました」、リストに商品が追加される |
| 6 | 0件選択時「リストに追加」ボタン | disabled（グレーアウト）になる |
| 7 | よく買うもの一覧の商品を長押し | 削除される |
| 8 | ⋮ メニューに「リストを削除」が表示される | 削除ダイアログが開く |
| 9 | AppBar に 🗑 ボタンが表示されない | 削除ボタンが AppBar から消えている |
| 10 | ヘルプを開く | 「よく買うものから追加」の説明が表示される |
