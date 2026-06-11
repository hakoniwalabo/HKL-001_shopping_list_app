# よく買うもの登録機能 設計書

**作成日：2026-06-11**
**最終更新：2026-06-11（AppBar レイアウト変更を反映）**

---

## 1. 概要

よく買う商品をあらかじめ登録しておき、ダイアログから複数選択して現在のリストに一括追加できる機能。

- 登録方法：直接入力 または 入力履歴（item_history）から選択
- よく買うリストは全リスト共通（listId に依存しない）
- 追加時に金額・個数の確認ステップなし（登録値をそのまま使用）

---

## 2. データ設計

### 2.1 favorites テーブル（新設）

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK（自動採番） |
| name | TEXT | 商品名 |
| price | INTEGER | 税込単価 |
| quantity | INTEGER | 個数（デフォルト: 1） |
| sortOrder | INTEGER | 並び順 |
| createdAt | INTEGER | 作成日時（UnixミリS） |

### 2.2 DBマイグレーション

- DB version 5 → 6
- `_createDB` と `onUpgrade`（`oldVersion < 6`）の両方に `CREATE TABLE favorites` を追加

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

### 3.1 AppBar レイアウト（変更後）

```
[タイトル]  [+ リスト追加]  [⎘ リスト複製]  [♡ よく買うもの]  [⋮]
```

- 「リスト削除」は AppBar から除去し、⋮ オプションメニューへ移動
- ♡ は `Icons.favorite_border`、tooltip「よく買うものから追加」

### 3.2 ⋮ オプションメニュー（変更後）

```
🗑 リストを削除
📤 テキストで共有
⭐ 広告を削除（未購入時のみ）
❓ 使い方
```

### 3.3 よく買うものダイアログ（`favorites_dialog.dart`）

```
Dialog
 ├─ タイトル「よく買うもの」
 ├─ 商品一覧（CheckboxListTile）
 │   ├─ 商品名・金額・個数を表示
 │   └─ 長押しで削除（確認なし）
 ├─ 「直接登録」ボタン → _AddFavoriteDialog（このファイル内に定義）
 ├─ 「履歴から登録」ボタン → history_select_dialog.dart を開く
 └─ 「リストに追加」ボタン（チェックした商品を現在のリストに一括追加）
     └─ 0件選択時はボタン無効化
```

### 3.4 _AddFavoriteDialog（favorites_dialog.dart 内）

- 入力フィールド：商品名（必須）・金額（0以上）・個数（1以上）
- 「登録」ボタンで `insertFavorite()` → favorites_dialog の一覧をリロード

### 3.5 履歴選択ダイアログ（`history_select_dialog.dart`）

```
Dialog
 ├─ タイトル「履歴から登録」
 ├─ item_history 一覧（CheckboxListTile・count DESC 順）
 └─ 「登録」ボタン
     └─ 選択した名前を price=0・quantity=1 で favorites に INSERT
```

> 履歴は商品名のみ保持のため、金額・個数はデフォルト値で登録される。

---

## 4. コンポーネント設計

### 4.1 新規ファイル

| ファイル | 内容 |
|---------|------|
| `lib/widgets/favorites_dialog.dart` | よく買うものダイアログ本体・`_AddFavoriteDialog` を内包 |
| `lib/widgets/history_select_dialog.dart` | 履歴から選択するダイアログ |

### 4.2 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/database/database_helper.dart` | favorites テーブル追加・DB v6 マイグレーション・CRUD メソッド追加 |
| `lib/widgets/list_management_buttons.dart` | `onDeleteList` コールバックを削除 |
| `lib/screens/shopping_list_screen.dart` | AppBar に ♡ ボタン追加・`_OptionItem.deleteList` 追加・⋮ メニューに削除を移動 |
| `lib/widgets/help_dialog.dart` | 「よく買うものから追加」説明項目を追加 |

### 4.3 DatabaseHelper 追加メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| getFavorites | `Future<List<Map<String, dynamic>>> getFavorites()` | 全件取得（sortOrder ASC） |
| insertFavorite | `Future<void> insertFavorite(String name, int price, int quantity)` | 新規登録 |
| deleteFavorite | `Future<void> deleteFavorite(int id)` | 削除 |
| addFavoriteItemsToList | `Future<void> addFavoriteItemsToList(List<int> favoriteIds, int listId)` | 選択した favorites を items に一括 INSERT（トランザクション） |

---

## 5. 処理フロー

### よく買うものをリストに追加

```
AppBar ♡ ボタンタップ
→ favorites_dialog 表示
→ 商品を複数チェック
→「リストに追加」ボタンタップ
→ addFavoriteItemsToList(selectedIds, currentListId)
→ items に一括 INSERT（sortOrder は MAX+1 から連番）
→ ItemNotifier.reload()
→ ダイアログ閉じる → SnackBar「X件追加しました」
```

### 直接登録

```
「直接登録」ボタンタップ
→ _AddFavoriteDialog 表示（名前・金額・個数）
→ insertFavorite() → favorites テーブルに保存
→ favorites_dialog 一覧をリロード
```

### 履歴から登録

```
「履歴から登録」ボタンタップ
→ history_select_dialog 表示（item_history を count DESC で表示）
→ 複数選択して「登録」タップ
→ 選択した名前ごとに insertFavorite(name, 0, 1)
→ favorites_dialog 一覧をリロード
```

---

## 6. エラー・エッジケース

| ケース | 対応 |
|--------|------|
| favorites が0件 | 「まだ登録されていません」の空状態表示 |
| 0件選択で「リストに追加」 | ボタンを無効化（disabled） |
| 同名商品を重複登録 | 許容する（favorites はマスターなので複数持てる） |
| 履歴が0件 | history_select_dialog で「履歴がありません」表示 |

---

## 7. ヘルプ更新

`help_dialog.dart` に以下の `_HelpItem` を追加する。

- **よく買うものから追加**：AppBar のハートボタンからよく買う商品を登録・管理できます。チェックして「リストに追加」を押すと一括追加されます。
