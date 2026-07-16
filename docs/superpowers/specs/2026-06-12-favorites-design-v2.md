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
| スワイプ削除＋ Undo SnackBar | テスト06（渡辺誠一）：長押し誤削除リスクを排除。既存 ItemTile と操作統一（2026-07-05 追記：同日中に SnackBar はダイアログ内インラインバナーへ変更。詳細は 5節を参照） |
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
| categoryId | INTEGER（nullable） | カテゴリ（任意）（2026-07-05 追記：2026-06-22 のカテゴリ機能導入で `ALTER TABLE favorites ADD COLUMN categoryId INTEGER` により追加。新規DB作成時の `CREATE TABLE` にも含まれる。詳細は `2026-06-22-category-design.md` を参照） |

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
 ├─ タイトル「よく買うもの」＋ 右端に ×（閉じる）IconButton
 ├─ （削除直後のみ）インラインUndoバナー「削除しました」＋「元に戻す」
 ├─ 検索 TextField（虫眼鏡アイコン・入力中はクリアボタン表示）
 ├─ [全選択 / 全解除] トグルボタン  ← 検索結果（絞り込み後）が0件のときは非表示
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
 └─ 「リストに追加」FilledButton（0件選択時は disabled）
```

（2026-07-05 追記：以下の3点を反映して上図を更新した。
1) 検索ボックス（`TextField`＋クリアボタン）を一覧上部に追加（2026-06-28 `418c856`、2026-06-29 `698087b` で改良）。検索文字列によるフィルタは全選択/全解除の対象範囲にも影響する。
2) タイトルバーに ×（閉じる）`IconButton` を追加し、`Row` 構成に変更（2026-06-29 `d3d668e`）。
3) 「履歴から登録」ボタンおよび `HistorySelectDialog` は 2026-06-28 `418c856` で UI 上廃止、2026-06-29 `d9e408e` で `history_select_dialog.dart` と `item_history` テーブル自体が削除され、機能として完全撤去された。現在のアクションは「直接登録」と「リストに追加」の2つのみ。
4) スワイプ削除の Undo は SnackBar ではなくダイアログ内のインラインバナー（`Material` + `Timer` で5秒後に自動消滅）に変更されている。詳細は5節を参照。）

### 3.3 直接登録ダイアログ（`_AddFavoriteDialog`・favorites_dialog.dart 内）

```
AlertDialog タイトル「よく買うものに登録」
 content: Scrollbar（thumbVisibility: true）+ SingleChildScrollView
 ├─ 商品名（必須・ItemNameField）← 入力中に候補ドロップダウンを表示
 ├─ 税込価格（0以上・TextFormField）
 ├─ 個数（1以上・TextFormField）
 ├─ カテゴリ（任意）DropdownButtonFormField ＋「＋新規カテゴリ」IconButton
 └─ [キャンセル] [登録]
```

「登録」で `insertFavorite(name, price, quantity, categoryId: ...)` → favorites 一覧をリロード。

（2026-07-05 追記：以下を反映。
- 商品名フィールドは素の `TextFormField` から `ItemNameField` に変更され、入力中に候補名のドロップダウンを表示するようになった。候補は `DatabaseHelper.instance.getFavorites()` で取得した**既存の「よく買うもの」自体の商品名一覧**（`initState` で読み込み）であり、旧・入力履歴（item_history）由来の候補ではない。この機能は 2026-06-29 `d3d668e` で追加後、同日の履歴機能撤去コミット `d9e408e` に巻き込まれて誤って削除され、2026-07-05 `c68da52` で「既存のよく買うもの名を候補として使う」形で復元された。
- ダイアログ内容がキーボード表示時にオーバーフローしないよう `Scrollbar(thumbVisibility: true) + SingleChildScrollView` でラップされた（`d3d668e`／`f0cec05`、2026-06-29）。
- カテゴリ（任意）の `DropdownButtonFormField` と「＋新規カテゴリ」`IconButton`（`_showNewCategoryDialog` を開き `categoryProvider.notifier.addCategory()` を呼ぶ）が追加された（2026-06-22 以降のカテゴリ機能導入）。詳細は `2026-06-22-category-design.md` を参照。）

### 3.4 編集ダイアログ（`_EditFavoriteDialog`・favorites_dialog.dart 内）

```
AlertDialog タイトル「よく買うものを編集」
 ├─ 商品名（必須・TextFormField・既存値で初期化）
 ├─ 税込価格（0以上・TextFormField・既存値で初期化）
 ├─ 個数（1以上・TextFormField・既存値で初期化）
 ├─ カテゴリ（任意）DropdownButtonFormField ＋「＋新規カテゴリ」IconButton（既存値で初期化）
 └─ [キャンセル] [保存]
```

「保存」で `updateFavorite(id, name, price, quantity, categoryId: ...)` → favorites 一覧をリロード。

（2026-07-05 追記：カテゴリの `DropdownButtonFormField` と「＋新規カテゴリ」`IconButton` を追加。追加ダイアログ側よりやや遅れて 2026-06-29 `e38909d` で編集ダイアログにも実装された。現在は両ダイアログともカテゴリ選択・新規追加に対応している。）

### 3.5 履歴選択ダイアログ（`history_select_dialog.dart`）── 廃止

（2026-07-05 追記：本機能は撤去済みのため、以下は歴史的記録として残す。「履歴から登録」ボタンは 2026-06-28 `418c856` でUIから削除され、`history_select_dialog.dart` ファイル自体と `item_history` テーブル・関連メソッドは 2026-06-29 `d9e408e` で削除された。現在 `favorites_dialog.dart` にこの機能への参照は存在しない。）

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
| ~~`lib/widgets/history_select_dialog.dart`~~ | ~~`HistorySelectDialog` を定義~~（2026-07-05 追記：2026-06-29 `d9e408e` でファイル自体が削除済み。現存しない） |

### 4.2 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/database/database_helper.dart` | favorites テーブル・DB v6 マイグレーション・CRUD 5メソッド追加 |
| `lib/widgets/list_management_buttons.dart` | `onDeleteList` コールバックを削除 |
| `lib/screens/shopping_list_screen.dart` | AppBar に ♡ ボタン追加・`_OptionItem.deleteList` 追加・⋮ メニューにリスト削除追加 |
| `lib/widgets/help_dialog.dart` | リスト削除説明更新・よく買うもの項目追加 |

### 4.3 DatabaseHelper メソッド一覧

（2026-07-05 追記：`categoryId` 対応・`restoreFavorite` の追加・`favoriteNameExists` の追加を反映し、以下のシグネチャを現行コードに合わせて更新した。並べ替え関連の `reorderFavorites`／`restoreFavorite` の詳細は `2026-06-12-favorites-reorder-design.md` を参照。）

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| getFavorites | `Future<List<Map<String, dynamic>>> getFavorites()` | 全件取得（sortOrder ASC） |
| insertFavorite | `Future<void> insertFavorite(String name, int price, int quantity, {int? categoryId})` | 新規登録（sortOrder は MAX+1） |
| updateFavorite | `Future<void> updateFavorite(int id, String name, int price, int quantity, {int? categoryId})` | 既存レコードを UPDATE（位置保持） |
| deleteFavorite | `Future<void> deleteFavorite(int id)` | 1件削除 |
| favoriteNameExists | `Future<bool> favoriteNameExists(String name)` | 同名レコードの存在確認 |
| restoreFavorite | `Future<void> restoreFavorite(String name, int price, int quantity, int sortOrder, {int? categoryId})` | Undo 専用 INSERT（元の sortOrder・categoryId を保持して復元。categoryId 引数は 2026-06-29 `835622a` で追加） |
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
→ 名前・価格・個数・カテゴリ（任意）を入力して「登録」
→ insertFavorite(name, price, quantity, categoryId: ...)
→ favorites 一覧をリロード
```
（2026-07-05 追記：カテゴリ引数を追記）

### 編集

```
アイテム行をタップ
→ _EditFavoriteDialog 表示（既存値で初期化）
→ 編集して「保存」
→ updateFavorite(id, name, price, quantity, categoryId: ...)
→ favorites 一覧をリロード（位置は変わらない）
```
（2026-07-05 追記：カテゴリ引数を追記）

### 履歴から登録（廃止）

（2026-07-05 追記：本フローは撤去済み。「履歴から登録」ボタンは 2026-06-28 `418c856` でUIから削除、`HistorySelectDialog`／`item_history` テーブルは 2026-06-29 `d9e408e` で完全削除された。現在 favorites_dialog.dart のアクションは「直接登録」と「リストに追加」のみ。以下は歴史的記録。）

```
「履歴から登録」ボタンタップ
→ HistorySelectDialog 表示
→ 複数選択して「登録」
→ 選択した名前ごとに insertFavorite(name, 0, 1)
→ favorites 一覧をリロード
```

### スワイプ削除・Undo

（2026-07-05 追記：Undo の通知手段を SnackBar から下記のダイアログ内インラインバナーに訂正した。AlertDialog のモーダルバリア表示中は SnackBar をタップできないため、同日中の `850e4f5`（2026-06-12）でこの方式に変更されている。）

```
アイテムを左スワイプ
→ Dismissible が削除を検知
→ _pendingUndoFavorite に削除データ（sortOrder・categoryId 含む）を保持
→ deleteFavorite(id)
→ favorites 一覧をリロード
→ ダイアログ content 内に Material 製インラインバナー「削除しました」＋「元に戻す」を表示
   （Timer で5秒後に自動的に非表示）
→（元に戻す タップ時）restoreFavorite(name, price, quantity, sortOrder, categoryId: ...)
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
| ~~履歴 0件~~ | ~~HistorySelectDialog で「履歴がありません」表示~~（2026-07-05 追記：履歴から登録機能は撤去済みのため本ケースは現存しない） |
| Undo 後の位置 | （2026-07-05 追記：`restoreFavorite` により元の sortOrder で復元されるため、実際は元の位置に戻る。下記「MAX+1で末尾に移動」という記述は 2026-06-12 の `2026-06-12-favorites-reorder-design.md` で修正済みの古い挙動を指す） sortOrder が MAX+1 になるため末尾に移動（許容） |

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
