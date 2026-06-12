# よく買うもの 並べ替え・Undo 位置保持 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** よく買うものダイアログにドラッグ並べ替えを追加し、スワイプ削除後の Undo で元の位置に復元されるよう修正する。

**Architecture:** `ListView.builder` を `ReorderableListView.builder` に置き換えてドラッグ並べ替えを実現する。ドラッグ開始は各行 trailing の `Icons.drag_handle` に `ReorderableDragStartListener` をラップして行う。Undo 位置保持は `insertFavorite`（MAX+1 採番）の代わりに `restoreFavorite`（元の sortOrder を指定して INSERT）を呼ぶことで解決する。

**Tech Stack:** Flutter, sqflite (sqflite パッケージ), Riverpod 3.x, Dart

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `lib/database/database_helper.dart` | `reorderFavorites`・`restoreFavorite` の2メソッドを追加 |
| `lib/widgets/favorites_dialog.dart` | `ReorderableListView` 切り替え・ドラッグハンドル追加・Undo 修正 |

---

## Task 1: DatabaseHelper に `reorderFavorites` と `restoreFavorite` を追加

**Files:**
- Modify: `lib/database/database_helper.dart:423`（`deleteFavorite` の直後に挿入）

- [ ] **Step 1: `reorderFavorites` を追加する**

`lib/database/database_helper.dart` の 423 行目（`deleteFavorite` の閉じ括弧 `}` の直後）に以下を挿入する。

```dart
  Future<void> reorderFavorites(List<int> orderedIds) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(
        'favorites',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
```

- [ ] **Step 2: `restoreFavorite` を追加する**

`reorderFavorites` の直後に以下を挿入する。

```dart
  Future<void> restoreFavorite(
    String name,
    int price,
    int quantity,
    int sortOrder,
  ) async {
    final db = await database;
    await db.insert('favorites', {
      'name': name,
      'price': price,
      'quantity': quantity,
      'sortOrder': sortOrder,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
```

- [ ] **Step 3: `flutter analyze` を実行してエラーがないことを確認する**

```
flutter analyze
```

期待出力: `No issues found!`

- [ ] **Step 4: コミット**

```bash
git add lib/database/database_helper.dart
git commit -m "feat: DatabaseHelper に reorderFavorites・restoreFavorite を追加"
```

---

## Task 2: FavoritesDialog を ReorderableListView に変更

**Files:**
- Modify: `lib/widgets/favorites_dialog.dart`

### Step 1: `_onReorder` メソッドを `_FavoritesDialogState` に追加する

- [ ] `_load()` メソッドの直後（44 行目付近）に以下を追加する。

```dart
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final list = [..._favorites];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _favorites = list);
    await DatabaseHelper.instance.reorderFavorites(
      list.map((f) => f['id'] as int).toList(),
    );
  }
```

### Step 2: `LimitedBox` を `ConstrainedBox` に置き換え、`ListView.builder` を `ReorderableListView.builder` に変更する

- [ ] 現在の `LimitedBox` + `ListView.builder` ブロック（139〜207 行）を以下で置き換える。

```dart
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _favorites.length,
                onReorder: _onReorder,
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
                      _undoTimer?.cancel();
                      _undoTimer = Timer(const Duration(seconds: 5), () {
                        if (!mounted) return;
                        setState(() => _pendingUndoFavorite = null);
                      });
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
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  );
                },
              ),
            ),
```

- [ ] **Step 3: `flutter analyze` を実行してエラーがないことを確認する**

```
flutter analyze
```

期待出力: `No issues found!`

- [ ] **Step 4: コミット**

```bash
git add lib/widgets/favorites_dialog.dart
git commit -m "feat: よく買うものにドラッグ並べ替えを追加"
```

---

## Task 3: Undo 呼び出しを `restoreFavorite` に変更

**Files:**
- Modify: `lib/widgets/favorites_dialog.dart:103-110`

- [ ] **Step 1: Undo バナーの `onPressed` 内の `insertFavorite` を `restoreFavorite` に変更する**

変更前（`favorites_dialog.dart` 103〜110 行付近）:

```dart
                        onPressed: () async {
                          _undoTimer?.cancel();
                          final data = _pendingUndoFavorite!;
                          setState(() => _pendingUndoFavorite = null);
                          await DatabaseHelper.instance.insertFavorite(
                            data['name'] as String,
                            data['price'] as int,
                            data['quantity'] as int,
                          );
                          await _load();
                        },
```

変更後:

```dart
                        onPressed: () async {
                          _undoTimer?.cancel();
                          final data = _pendingUndoFavorite!;
                          setState(() => _pendingUndoFavorite = null);
                          await DatabaseHelper.instance.restoreFavorite(
                            data['name'] as String,
                            data['price'] as int,
                            data['quantity'] as int,
                            data['sortOrder'] as int,
                          );
                          await _load();
                        },
```

- [ ] **Step 2: `flutter analyze` を実行してエラーがないことを確認する**

```
flutter analyze
```

期待出力: `No issues found!`

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/favorites_dialog.dart
git commit -m "fix: よく買うものの Undo で元の並び順を復元するよう修正"
```

---

## Task 4: 実機テスト

実機（AQUOS sense9）で以下を確認する。

- [ ] **並べ替えテスト**
  1. よく買うものに3件以上登録する
  2. ♡ ボタンからダイアログを開く
  3. `≡` アイコンを長押しして別の位置にドラッグする
  4. ドラッグ後の順番がアプリ再起動後も保持されていることを確認する（DBに永続化）

- [ ] **Undo 位置保持テスト**
  1. よく買うものに3件以上登録してダイアログを開く
  2. リストの先頭または中間の商品を左スワイプして削除する
  3. 「元に戻す」をタップする
  4. 復元された商品が末尾ではなく元の位置（またはその近く）に表示されることを確認する

- [ ] **既存動作の回帰テスト**
  - Checkbox でチェックのオン/オフが正常に動作する
  - 行タップで編集ダイアログが開く
  - 左スワイプで削除できる
  - 「直接登録」「履歴から登録」「リストに追加」が正常に動作する
  - 全選択 / 全解除ボタンが正常に動作する
