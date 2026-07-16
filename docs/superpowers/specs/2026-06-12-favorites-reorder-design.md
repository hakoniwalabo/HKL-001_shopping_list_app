# よく買うもの 並べ替え機能 設計書

**作成日：2026-06-12**
**対象バージョン：** spec rev8.2 の 8.11節 に追加

---

## 1. 概要

よく買うものダイアログに以下の2点を追加する。

1. **並べ替え機能** — ドラッグハンドルを長押ししてアイテムを並べ替える
2. **Undo 位置保持** — スワイプ削除後に「元に戻す」を押すと元の位置に復元される

操作感はメインリスト（`ReorderableListView`）に統一する。

---

## 2. UI 変更

### 2.1 リスト描画

`ListView.builder` → `ReorderableListView.builder` に置き換える。

高さ制約は `LimitedBox(maxHeight: 320)` → `ConstrainedBox(constraints: BoxConstraints(maxHeight: 320))` に変更する（`ReorderableListView` は `shrinkWrap` 非対応のため）。

### 2.2 各アイテム行

```
Dismissible（スワイプ左→削除）
 └─ ListTile
     ├─ leading:  Checkbox（タップでチェック切替）    ← 変更なし
     ├─ title:    商品名                              ← 変更なし
     ├─ subtitle: ¥価格 × 個数                       ← 変更なし
     ├─ onTap:    _EditFavoriteDialog を開く          ← 変更なし
     └─ trailing: ReorderableDragStartListener        ← 新規
                   └─ Icon(Icons.drag_handle)
```

---

## 3. データ変更

DBスキーマの変更なし。`database_helper.dart` に2メソッドを追加する。

### 3.1 `reorderFavorites`

```dart
Future<void> reorderFavorites(List<int> orderedIds) async
```

渡された ID 順に `sortOrder` を 0, 1, 2… と一括更新する。バッチ処理で実行。

### 3.2 `restoreFavorite`

```dart
Future<void> restoreFavorite(String name, int price, int quantity, int sortOrder, {int? categoryId}) async
```

Undo 専用 INSERT。`insertFavorite`（MAX+1 採番）と異なり、削除前の `sortOrder` をそのまま指定して挿入する。

（2026-07-05 追記：`categoryId` の任意引数を追加。2026-06-29 `835622a` で、Undo（元に戻す）時に商品のカテゴリ情報が失われるバグを修正するために追加された。呼び出し側は `restoreFavorite(name, price, quantity, sortOrder, categoryId: ...)` のように削除前の categoryId を渡す。）

---

## 4. 処理フロー

### 4.1 ドラッグ並べ替え（新規）

```
ハンドルアイコンを長押してドラッグ
→ onReorderItem(oldIndex, newIndex) 発火
→ _favorites リストをメモリ上で並べ替え → setState
→ reorderFavorites(orderedIds) でDB一括更新（失敗時は _load() でDB状態へロールバック）
```

（2026-07-05 追記：以下2点を現行コードに合わせて修正した。
1) `ReorderableListView.builder` の `onReorder:` ではなく、Flutter 3.44.0 の新API `onReorderItem:` を使用している（本プロジェクトの `Feedback.md` にも記録あり）。このAPIは `newIndex` が並べ替え後の実インデックスとして渡されるため、旧APIで必要だった `if (newIndex > oldIndex) newIndex--;` の調整は不要かつ行っていない。
2) 同日 `804c505`（2026-06-12）で、DB更新失敗時に `_load()` でメモリ上の一覧をDBの実値へロールバックする `try/catch` が追加された。以下のコードサンプルは実装に合わせて更新済み。）

```dart
Future<void> _onReorderItem(int oldIndex, int newIndex) async {
  final list = [..._favorites];
  final item = list.removeAt(oldIndex);
  list.insert(newIndex, item);
  setState(() => _favorites = list);
  try {
    await DatabaseHelper.instance.reorderFavorites(
      list.map((f) => f['id'] as int).toList(),
    );
  } catch (_) {
    await _load();
  }
}
```

### 4.2 Undo 位置保持（修正）

`_pendingUndoFavorite = Map.from(fav)` はすでに `sortOrder` カラムを含んでいる。Undo 時の呼び出しを変更する。

```
（変更前）insertFavorite(name, price, quantity)
           → sortOrder = MAX+1 → 末尾に出現

（変更後）restoreFavorite(name, price, quantity, sortOrder)
           → 元の sortOrder で INSERT → 元の位置に出現
```

---

## 5. 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/widgets/favorites_dialog.dart` | `ListView.builder` → `ReorderableListView.builder`、`LimitedBox` → `ConstrainedBox`、`trailing` にドラッグハンドル追加、Undo 呼び出しを `restoreFavorite` に変更、`_onReorder` メソッド追加（2026-07-05 追記：実装上のメソッド名は `_onReorderItem`。4.1節を参照） |
| `lib/database/database_helper.dart` | `reorderFavorites`・`restoreFavorite` メソッド追加 |

`help_dialog.dart` の更新は不要（操作説明に変更なし）。

---

## 6. エッジケース

| ケース | 対応 |
|--------|------|
| Undo 前に他アイテムをドラッグ移動した場合 | 復元アイテムは元の sortOrder 値で挿入されるため、近似位置に出現する（許容） |
| アイテムが1件のみ | `ReorderableListView` は1件でも問題なく動作する |
| アイテムが0件 | `_favorites.isEmpty` 分岐で「まだ登録されていません」を表示しリストを描画しないため影響なし |
