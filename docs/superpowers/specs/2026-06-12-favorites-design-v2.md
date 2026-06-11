# よく買うもの機能 設計書 v2

**作成日：2026-06-12**
**前バージョン：** `docs/superpowers/specs/2026-06-11-favorites-design.md`
**改訂理由：** 仮想テスト結果（`docs/testers/virtual_test_report_favorites_2026-06-11.md`）を反映

---

## 1. 改訂サマリー

| 変更点 | 理由 |
|--------|------|
| `updateFavorite` メソッドを追加 | 編集時に delete+re-insert すると位置が崩れる（体験を壊さない方針） |
| `CheckboxListTile` → `Dismissible + ListTile + Checkbox` | タップ→編集・スワイプ→削除の操作を分離するため |
| タップ→編集ダイアログ（`_EditFavoriteDialog`）を追加 | テスト09（加藤里奈）：price=0 商品の編集手段がなかった |
| スワイプ削除＋ Undo SnackBar | テスト06（渡辺誠一）：長押し誤削除リスクを排除。既存 ItemTile と操作統一 |
| 全選択 / 全解除トグルボタンを追加 | テスト02・07・10：件数が多いとき全チェックが面倒 |
| リスト削除を AppBar から ⋮ メニューへ移動 | AppBar スペースの確保 |

---

## 2. データ設計

### 2.1 favorites テーブル（新設・v1 と同一）

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK（自動採番） |
| name | TEXT | 商品名 |
| price | INTEGER | 税込単価（デフォルト: 0） |
| quantity | INTEGER | 個数（デフォルト: 1） |
| sortOrder | INTEGER | 並び順 |
| createdAt | INTEGER | 作成日時（UnixミリS） |

### 2.2 DBマイグレーション

DB version 5 → 6。`_createDB` と `onUpgrade`（`oldVersion < 6`）の両方で `CREATE TABLE IF NOT EXISTS favorites` を実行。

```sql
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
```

---

## 3. 画面設計

### 3.1 AppBar レイアウト

```
[タイトル]  [+ リスト追加]  [⎘ リスト複製]  [♡ よく買うもの]  [⋮]
```

⋮ オプションメニュー：

```
🗑 リストを削除  ← AppBar から移動
📤 テキストで共有
⭐ 広告を削除（未購入時のみ）
❓ 使い方
```

### 3.2 よく買うものダイアログ（`favorites_dialog.dart`）

```
AlertDialog
 ├─ タイトル「よく買うもの」
 ├─ [全選択 / 全解除] トグルボタン  ← favorites 0件時は非表示
 ├─ 商品一覧
 │   ├─ 0件時：「まだ登録されていません」
 │   └─ 1件以上：
 │       Dismissible（スワイプ左→削除）
 │        └─ ListTile
 │            ├─ leading: Checkbox（タップでチェック切替）
 │            ├─ title: 商品名
 │            ├─ subtitle: ¥価格 × 個数（price=0 なら「数量: N」）
 │            └─ onTap: _EditFavoriteDialog を開く
 ├─ 「直接登録」TextButton → _AddFavoriteDialog
 ├─ 「履歴から登録」TextButton → HistorySelectDialog
 └─ 「リストに追加」FilledButton（0件選択時は disabled）
```

### 3.3 直接登録ダイアログ（`_AddFavoriteDialog`・favorites_dialog.dart 内）

```
AlertDialog タイトル「よく買うものに登録」
 ├─ 商品名（必須・TextFormField）
 ├─ 税込価格（0以上・TextFormField）
 ├─ 個数（1以上・TextFormField）
 └─ [キャンセル] [登録]
```

「登録」で `insertFavorite(name, price, quantity)` → favorites 一覧をリロード。

### 3.4 編集ダイアログ（`_EditFavoriteDialog`・favorites_dialog.dart 内）

```
AlertDialog タイトル「よく買うものを編集」
 ├─ 商品名（必須・TextFormField・既存値で初期化）
 ├─ 税込価格（0以上・TextFormField・既存値で初期化）
 ├─ 個数（1以上・TextFormField・既存値で初期化）
 └─ [キャンセル] [保存]
```

「保存」で `updateFavorite(id, name, price, quantity)` → favorites 一覧をリロード。

### 3.5 履歴選択ダイアログ（`history_select_dialog.dart`）

```
AlertDialog タイトル「履歴から登録」
 ├─ item_history 一覧（CheckboxListTile・count DESC 順）
 │   └─ 0件時：「履歴がありません」
 └─ [キャンセル] [登録]（0件選択時は disabled）
```

「登録」で選択した名前ごとに `insertFavorite(name, 0, 1)` を実行 → favorites_dialog の一覧をリロード。

---

## 4. コンポーネント設計

### 4.1 新規ファイル

| ファイル | 内容 |
|---------|------|
| `lib/widgets/favorites_dialog.dart` | `FavoritesDialog`・`_AddFavoriteDialog`・`_EditFavoriteDialog` を定義 |
| `lib/widgets/history_select_dialog.dart` | `HistorySelectDialog` を定義 |

### 4.2 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/database/database_helper.dart` | favorites テーブル・DB v6 マイグレーション・CRUD 5メソッド追加 |
| `lib/widgets/list_management_buttons.dart` | `onDeleteList` コールバックを削除 |
| `lib/screens/shopping_list_screen.dart` | AppBar に ♡ ボタン追加・`_OptionItem.deleteList` 追加・⋮ メニューにリスト削除追加 |
| `lib/widgets/help_dialog.dart` | リスト削除説明更新・よく買うもの項目追加 |

### 4.3 DatabaseHelper メソッド一覧

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| getFavorites | `Future<List<Map<String, dynamic>>> getFavorites()` | 全件取得（sortOrder ASC） |
| insertFavorite | `Future<void> insertFavorite(String name, int price, int quantity)` | 新規登録（sortOrder は MAX+1） |
| updateFavorite | `Future<void> updateFavorite(int id, String name, int price, int quantity)` | 既存レコードを UPDATE（位置保持） |
| deleteFavorite | `Future<void> deleteFavorite(int id)` | 1件削除 |
| addFavoriteItemsToList | `Future<void> addFavoriteItemsToList(List<int> favoriteIds, int listId)` | 選択した favorites を items に一括 INSERT（トランザクション） |

---

## 5. 処理フロー

### よく買うものをリストに追加

```
AppBar ♡ ボタンタップ
→ FavoritesDialog 表示
→ 商品を複数チェック（または全選択ボタン）
→「リストに追加」ボタンタップ
→ addFavoriteItemsToList(selectedIds, currentListId)
→ ItemNotifier.changeList(currentListId)
→ ダイアログ閉じる（int count を返す）
→ SnackBar「X件追加しました」
```

### 直接登録

```
「直接登録」ボタンタップ
→ _AddFavoriteDialog 表示
→ 名前・価格・個数を入力して「登録」
→ insertFavorite(name, price, quantity)
→ favorites 一覧をリロード
```

### 編集

```
アイテム行をタップ
→ _EditFavoriteDialog 表示（既存値で初期化）
→ 編集して「保存」
→ updateFavorite(id, name, price, quantity)
→ favorites 一覧をリロード（位置は変わらない）
```

### 履歴から登録

```
「履歴から登録」ボタンタップ
→ HistorySelectDialog 表示
→ 複数選択して「登録」
→ 選択した名前ごとに insertFavorite(name, 0, 1)
→ favorites 一覧をリロード
```

### スワイプ削除・Undo

```
アイテムを左スワイプ
→ Dismissible が削除を検知
→ _pendingUndoFavorite に削除データを保持
→ deleteFavorite(id)
→ favorites 一覧をリロード
→ SnackBar「削除しました」＋「元に戻す」
→（元に戻す タップ時）insertFavorite(name, price, quantity)
→ favorites 一覧をリロード
```

---

## 6. 状態管理

`FavoritesDialog` は `ConsumerStatefulWidget`。Riverpod は `addFavoriteItemsToList` 後の `ItemNotifier.changeList()` 呼び出しにのみ使用。それ以外の favorites CRUD は `setState` でローカル管理。

---

## 7. エラー・エッジケース

| ケース | 対応 |
|--------|------|
| favorites 0件 | 「まだ登録されていません」表示・全選択ボタン非表示 |
| 0件選択で「リストに追加」 | ボタンを disabled |
| 同名商品の重複登録 | 許容（favorites はマスターなので複数持てる） |
| 履歴 0件 | HistorySelectDialog で「履歴がありません」表示 |
| Undo 後の位置 | sortOrder が MAX+1 になるため末尾に移動（許容） |

---

## 8. ヘルプ更新

`help_dialog.dart` に以下を追加・変更する。

**変更：** リストを削除
```
'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）'
```

**追加：** よく買うものから追加
```
icon: Icons.favorite_border
label: 'よく買うものから追加'
description: 'AppBar右上のハートボタンから定番商品を登録・管理できます。チェックして「リストに追加」を押すと一括追加されます。商品をタップすると価格・個数を編集できます'
```
