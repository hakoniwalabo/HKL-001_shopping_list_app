# HKL-001 買い物リストアプリ 設計書

**Rev 8.6　2026年改訂**

---

## 変更履歴

| Rev | 日付 | 変更内容 |
|-----|------|---------|
| 1.0 | 2026年初期 | 初版作成 |
| 2.0 | 2026年 | quantity カラム追加（DB v2） |
| 3.0 | 2026年 | 複数リスト対応・listId カラム追加（DB v3） |
| 4.0 | 2026年 | 商品履歴補完・item_history テーブル追加（DB v4） |
| 5.0 | 2026年 | taxRate カラム削除・税込単価に統一（DB v5） |
| 6.0 | 2026年 | AdMob バナー広告・IAP 広告なし買い切り実装 |
| 7.0 | 2026年 | プライバシーポリシー追加・アイコン刷新・AdMob 本番ID設定 |
| 7.1 | 2026年 | 商品を別リストへ移動機能・ヘルプ画面更新（12項目）・versionCode=3 |
| 8.0 | 2026年 | 設計書ファイル名を v8 に変更・変更履歴セクション追加 |
| 8.1 | 2026-06-09 | リスト複製機能追加・テキスト共有機能追加（share_plus）・AppBar をオプションメニュー（⋮）に整理・ヘルプ更新（14項目）・versionCode=4 |
| 8.2 | 2026-06-12 | よく買うもの登録機能追加（favorites テーブル・DB v6）・AppBar に ♡ ボタン追加・リスト削除を ⋮ メニューへ移動・`Dismissible+ListTile+Checkbox` 採用・編集ダイアログ追加・全選択ボタン追加・スワイプ削除 Undo 追加・ヘルプ更新 |
| 8.3 | 2026-06-13 | バックアップ・機種変更引継ぎ機能追加（JSON エクスポート/インポート・file_picker・path_provider）・⋮ メニューに2項目追加・ヘルプ更新（16項目） |
| 8.4 | 2026-06-16 | アプリ同士のリスト共有機能追加（現在リストを未購入のみで共有・version:1形式流用）・バックアップ保存先に「端末に保存」追加（file_picker saveFile）・読み込みを統合し「読み込む（バックアップ／共有リスト）」へ文言変更・読み込みフィルタを FileType.any に緩和（中身で検証）・ヘルプ更新 |
| 8.5 | 2026-06-22〜29 | カテゴリ機能追加（DB v7）・よく買うものダイアログ改善（× ボタン・スクロールバー・検索窓）・restoreFavorite categoryId 修正 |
| 8.6 | 2026-06-29 | _EditFavoriteDialog にカテゴリ追加ボタン追加・restoreFavorite categoryId 追加（Undo 時カテゴリ保持）・カテゴリ削除後のアイテム消失バグ修正 |

---

## 1. システム概要

### 1.1 アプリ概要

Flutter + Riverpod + SQLite(sqflite) を使用したローカル保存型の買い物リストアプリ。

複数リスト管理、商品履歴、購入済み管理、Undo復元、並び替え、税込計算などを備える。

---

## 2. 使用技術

| 分類 | 内容 |
|------|------|
| Framework | Flutter |
| 状態管理 | flutter_riverpod |
| DB | SQLite (sqflite) |
| 言語 | Dart |
| UI | Material3 |
| 対応OS | Android |
| 広告 | google_mobile_ads ^5.2.0 (AdMob) |
| IAP | in_app_purchase ^3.2.0 |
| 購入状態永続化 | shared_preferences ^2.3.0 |
| ファイル共有 | share_plus ^10.1.4 |
| ファイル選択 | file_picker ^8.1.0 |
| 一時ファイル保存 | path_provider ^2.1.0 |

---

## 3. システム構成

```
main.dart
 └─ ShoppingListScreen
      ├─ ItemProvider (Riverpod)
      │    └─ DatabaseHelper
      │          ├─ items            ← categoryId カラム追加（DB v7）
      │          ├─ lists
      │          ├─ item_history
      │          ├─ favorites        ← categoryId カラム追加（DB v7）
      │          └─ categories       ← 新規（DB v7）
      │
      ├─ CategoryProvider (Riverpod) ← 新規
      │    └─ DatabaseHelper
      │
      ├─ PurchaseProvider (Riverpod)
      │    ├─ InAppPurchase (in_app_purchase)
      │    └─ SharedPreferences（購入状態永続化）
      │
      ├─ BackupService
      │    ├─ share_plus（バックアップ共有・リスト共有）
      │    ├─ file_picker（端末保存 saveFile・読み込み pickFiles）
      │    └─ path_provider（一時ファイル）
      │
      ├─ Item model
      ├─ ShoppingList model
      └─ Category model           ← 新規
```

---

## 4. ディレクトリ構成

```
lib/
├─ main.dart
├─ database/
│   └─ database_helper.dart
├─ models/
│   ├─ item.dart
│   ├─ shopping_list.dart
│   └─ category.dart              ← 新規
├─ providers/
│   ├─ item_provider.dart
│   ├─ purchase_provider.dart
│   └─ category_provider.dart     ← 新規
├─ screens/
│   └─ shopping_list_screen.dart
├─ services/
│   └─ backup_service.dart
└─ widgets/
    ├─ add_item_dialog.dart
    ├─ ad_banner.dart
    ├─ category_management_dialog.dart ← 新規
    ├─ favorites_dialog.dart
    ├─ history_select_dialog.dart
    ├─ item_tile.dart
    ├─ list_management_buttons.dart
    ├─ list_section.dart
    ├─ list_tab_bar.dart
    ├─ total_summary.dart
    ├─ empty_state_view.dart
    ├─ upgrade_dialog.dart
    └─ fields/
        ├─ item_name_field.dart
        ├─ price_field.dart
        ├─ quantity_field.dart
        └─ memo_field.dart
```

---

## 5. 画面設計

### 5.1 メイン画面 機能一覧

| 機能 | 内容 |
|------|------|
| 商品追加 | 商品を登録 |
| 商品編集 | 既存商品編集 |
| 商品削除 | スワイプ削除 |
| Undo | 削除復元 |
| 購入済み切替 | Checkbox |
| 並び替え | ReorderableListView |
| リスト切替 | TabBar |
| リスト追加 | 新規タブ追加（上限：最大10リスト） |
| リスト削除 | タブ削除（紐付きitemsをCASCADE削除） |
| リスト名変更 | タブ長押しで名前編集 |
| 履歴補完 | Autocomplete |
| 合計表示 | 税込合計（タブ直下固定表示。未購入/購入済みを並列表示） |
| 別リストへ移動 | 商品を長押しして移動先リストを選択 |
| リスト複製 | 現在のリストを全商品コピーで複製（チェック状態リセット・同名時は連番付与） |
| テキスト共有 | リスト内容をテキスト化してOS標準共有シートで送信（読むだけ・取り込み不可） |
| リストを共有（読み込み用） | 現在のリスト1件を未購入アイテムのみで version:1 形式ファイル化し共有シートで送信。受信側は「読み込む」で取り込める |
| よく買うものから追加 | AppBar ♡ ボタンからよく買う商品を登録・管理し、選択して現在のリストに一括追加 |
| カテゴリを管理 | ⋮ メニュー→「カテゴリを管理」からカテゴリ作成・削除・使用数確認。商品追加・編集ダイアログでカテゴリを設定すると、リストがカテゴリ別セクション表示に切り替わる |
| バックアップ | 全データ（lists・items・favorites・categories）をJSONファイル化。タップ後「共有」「端末に保存」を選択（端末保存は file_picker saveFile） |
| 読み込む（バックアップ／共有リスト） | JSONファイルを選択してインポート（マージ方式・同名リストは連番付与）。バックアップ・共有リスト・端末保存ファイルのいずれも取り込み可。フィルタは FileType.any（中身で検証） |
| 広告表示 | AdMob バナー広告（画面下部固定・広告なし購入済みの場合は非表示） |
| 広告なしアップグレード | 買い切り IAP（`remove_ads`）でアプリ内広告を永久非表示 |

### 5.2 UI構成

```
Scaffold
 ├─ AppBar
 │   ├─ タイトル（「買い物リスト」固定）
 │   ├─ 追加ボタン（リスト追加）
 │   ├─ 複製ボタン（リスト複製）
 │   ├─ ♡ ボタン（よく買うものから追加・Icons.favorite_border）
 │   └─ ⋮ オプションメニュー
 │       ├─ リストを削除
 │       ├─ テキストで共有
 │       ├─ リストを共有（読み込み用）
 │       ├─ バックアップ（共有/端末保存を選択）
 │       ├─ 読み込む（バックアップ／共有リスト）
 │       ├─ カテゴリを管理                        ← 新規
 │       ├─ 広告を削除（広告なし購入済みの場合は非表示）
 │       └─ 使い方（ヘルプ）
 │       ※ リスト名変更はタブ長押しで行う。AppBar に編集ボタンは置かない。
 │
 ├─ TabBar（タブ長押しでタブ名変更）
 │
 ├─ 合計表示（TotalSummary・ListView 外・TabBar 直下に固定）
 │
 ├─ ListView
 │   ├─ カテゴリなし商品（未購入）                 ← カテゴリ別表示
 │   ├─ カテゴリAセクション（未購入）               ← カテゴリ別表示
 │   ├─ カテゴリBセクション（未購入）               ← カテゴリ別表示
 │   ├─ Divider
 │   └─ 購入済みセクション（カテゴリ混在・フラット表示）
 │
 ├─ FloatingActionButton（商品追加専用）
 │
 └─ AdBannerWidget（画面下部固定・広告なし購入済みの場合は非表示）
```

> **注:** FAB は商品追加専用。AppBar の追加/削除ボタンはリスト操作（タブ）用。
> 合計表示は TabBar 直下・ListView の外側に固定配置する。
> AdBannerWidget は Scaffold body 最下部に常駐し、`isAdFree = true` の場合は `SizedBox.shrink()` を返す。
> カテゴリが1件もない場合は従来のフラット表示。categoryId=null の商品はセクション末尾に表示。

#### カテゴリ削除時の表示ロジック

カテゴリを削除すると、そのカテゴリに属していたアイテムは DB 上の categoryId が NULL に更新される。画面上は「カテゴリなし」セクションに移動される（`_buildCategorySections` の noCategory フィルタは `categoryId == null` または現カテゴリ一覧に存在しない ID を対象とする）。カテゴリ管理ダイアログを閉じた後に `itemProvider.changeList()` でアイテムリストを DB から再読み込みする。

---

## 6. データベース設計

### 6.1 items テーブル

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK |
| name | TEXT | 商品名 |
| price | INTEGER | 税込単価 |
| isChecked | INTEGER | 購入済み |
| createdAt | INTEGER | 作成日時 |
| sortOrder | INTEGER | 並び順（新規追加時: MAX(sortOrder)+1） |
| quantity | INTEGER | 個数 |
| memo | TEXT | メモ（編集時のみ UI に表示） |
| listId | INTEGER | 所属リスト（FK: lists.id） |
| categoryId | INTEGER | カテゴリID（FK: categories.id、NULL許可） |

### 6.2 lists テーブル

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK |
| name | TEXT | リスト名 |
| createdAt | INTEGER | 作成日時 |

### 6.3 item_history テーブル

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK |
| name | TEXT | 商品名 |
| count | INTEGER | 使用回数 |
| lastUsed | INTEGER | 最終使用日時 |

### 6.4 favorites テーブル（DB v6 追加）

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK（自動採番） |
| name | TEXT | 商品名 |
| price | INTEGER | 税込単価 |
| quantity | INTEGER | 個数（デフォルト: 1） |
| sortOrder | INTEGER | 並び順 |
| createdAt | INTEGER | 作成日時（UnixミリS） |
| categoryId | INTEGER | カテゴリID（FK: categories.id、NULL許可） |

### 6.5 categories テーブル（DB v7 新規追加）

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK（自動採番） |
| name | TEXT | カテゴリ名（UNIQUE） |
| sortOrder | INTEGER | 並び順 |
| createdAt | INTEGER | 作成日時（UnixミリS） |

---

## 7. 状態管理設計

### 7.1 ItemNotifier

Riverpod AsyncNotifier を使用。

**管理状態:** `AsyncValue<List<Item>>`

**管理内容:**

- 商品一覧
- リスト切替
- 並び替え
- Undo復元
- DB同期

### 7.2 PurchaseNotifier

Riverpod AsyncNotifier を使用。

**管理状態:** `AsyncValue<bool>`（広告なしフラグ）

**管理内容:**

- `SharedPreferences` によるキャッシュ読み書き（key: `is_ad_free`）
- `InAppPurchase.purchaseStream` 購読（購入完了を即時反映）
- 起動時の自動購入復元（`restorePurchases()`）
- 購入処理（`purchase()`）・復元処理（`restore()`）

**UI との接続:**

```dart
final isAdFree = ref.watch(purchaseProvider).maybeWhen(
  data: (v) => v,
  orElse: () => false,
);
```

### 7.3 CategoryNotifier（新規）

Riverpod AsyncNotifier を使用。

**管理状態:** `AsyncValue<List<Category>>`

**管理内容:**

- カテゴリ一覧取得
- カテゴリ追加（`addCategory()`）・削除（`deleteCategory()`）

### 7.4 状態更新フロー

```
UI操作 → ItemNotifier → state更新 → DatabaseHelper → SQLite保存

IAP購入 → PurchaseNotifier → SharedPreferences保存 → state更新 → 広告非表示
```

---

## 8. 詳細仕様書

### 8.1 商品追加機能

商品を新規登録する。

#### 入力項目（追加時と編集時で表示フィールドが異なる）

| 項目 | 型 | 追加時 | 編集時 |
|------|----|--------|--------|
| 商品名 | String | ○（必須） | ○（必須） |
| 金額（税込） | int | ○（必須） | ○（必須） |
| 個数 | int | ○（必須） | ○（必須） |
| メモ | String | 非表示（空固定） | ○（任意） |

> **設計意図:** 追加時はシンプルに「名前・税込価格・個数」のみ入力させる。メモは編集ダイアログ（タイルタップ）でのみ変更可能。

#### バリデーション

| 項目 | 条件 |
|------|------|
| 商品名 | 空禁止 |
| 金額 | 0以上の整数 |
| 個数 | 1以上の整数 |

#### 処理フロー

```
Dialog表示 → 入力チェック → Item生成 → Provider.addItem → DB保存 → 画面更新
```

#### sortOrder の設定

`addItem()` 内で `MAX(sortOrder) + 1` を採番する。

---

### 8.2 商品編集機能

既存商品を更新する。更新対象: 商品名、金額、個数、メモ。

#### 処理フロー

```
ListTileタップ → Dialog表示 → 入力変更 → updateItem() → DB更新
```

#### 履歴更新（編集時）

`add_item_dialog.dart` の編集分岐にて、**名前が変更された場合のみ** `upsertHistory(newName)` を呼び出す。

```dart
if (item != null) {
  await ref.read(itemProvider.notifier).updateItem(updatedItem);
  // 名前変更があった場合のみ履歴更新
  if (name != item.name) {
    await DatabaseHelper.instance.upsertHistory(name);
  }
}
```

---

### 8.3 商品削除機能

Dismissible によるスワイプ削除。Undo対応・SnackBar表示。

```
スワイプ → deleteItemById() → state更新 → DB削除 → Undo待機
```

---

### 8.4 Undo復元機能

削除済み商品を復元する。id・sortOrder・createdAt を復元。

```
SnackBar Action → restoreItemWithOrder() → insertItemWithId() → sortOrder再ソート
```

---

### 8.5 並び替え機能

未購入商品のみドラッグ移動可能。sortOrder（昇順）で表示。

```
ドラッグ → reorderUncheckedItems() → sortOrder更新 → DB保存
```

---

### 8.6 購入済み切替

Checkboxで購入済み状態を変更。

| 状態 | 表示 |
|------|------|
| false | 通常表示 |
| true | グレー + 打消し線 |

---

### 8.7 購入済み一括削除

購入済み商品を全削除する。確認Dialogあり。Undo対応（複数件）。

#### Undo仕様

- 削除した全商品リストをまとめてメモリ保持
- `restoreItemWithOrder()` を複数件対応で実装
- SnackBarのUndoボタンで一括復元

---

### 8.8 合計金額表示

`TotalSummary` ウィジェットで税込合計をタブ直下（ListView 外）に固定表示。

**配置:** `shopping_list_screen.dart` の `build()` 内で **TabBar 直下・ListView の外側**に固定配置する。スクロールに依存せず常時表示。

| 項目 | 計算式 |
|------|--------|
| 未購入合計 | `sum(price × quantity)`（isChecked=false の商品のみ） |
| 購入済合計 | `sum(price × quantity)`（isChecked=true の商品のみ） |

`price` は税込単価として保存されているため、合計計算は `price × quantity` のみ。

```dart
TotalSummary(items: items)
```

---

### 8.9 商品履歴機能

入力済み商品名を履歴保存。Autocomplete補完・頻度順表示。

#### 更新タイミング

| 操作 | 履歴の扱い |
|------|-----------|
| 商品追加時 | count++、lastUsed 更新 |
| 商品編集時（名前変更） | 新しい名前で count++、lastUsed 更新 |
| 商品削除時 | 履歴は保持（削除しない） |

#### ソート条件

```sql
ORDER BY count DESC, lastUsed DESC
```

---

### 8.10 複数リスト機能

タブごとに別リストを管理。最大10リストまで作成可能。

| 機能 | 内容 |
|------|------|
| 追加 | 新規リスト作成（上限10リスト） |
| 削除 | リスト削除 + 紐付きitems を CASCADE削除 |
| 名前変更 | タブ長押しでリネーム |
| 切替 | TabBar |
| 複製 | 現在リストの全アイテムをコピーして新規リスト作成。チェック状態は全件リセット。同名リストが存在する場合は末尾に `(2)` `(3)` を自動付与 |
| テキスト共有 | 未購入・購入済み全アイテムをテキスト整形して `Share.share()` で送信。アイテムが0件の場合は SnackBar を表示してキャンセル |

#### リスト上限チェック

`_showAddListDialog()` の冒頭で件数チェックを行い、上限超過時は SnackBar を表示して追加をブロックする。

```dart
void _showAddListDialog() {
  if (shoppingLists.length >= 10) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('リストは最大10件までです')),
    );
    return;
  }
  // ... Dialog表示処理
}
```

#### タブ長押しでリネーム

`ListTabBar` ウィジェット内でタブを `GestureDetector` でラップし、`onLongPress` で `_showRenameListDialog(list)` を呼び出す。

#### リスト削除時のデータ処理

- アプリ側で `items.listId` が一致するレコードを先に全削除
- その後 `lists` テーブルから対象リストを削除
- トランザクションで原子的に実行

---

### 8.11 よく買うもの機能

よく買う商品をあらかじめ登録しておき、ダイアログから複数選択して現在のリストに一括追加できる機能。

- よく買うリストは全リスト共通（listId に依存しない）
- 追加時に金額・個数の確認ステップなし（登録値をそのまま使用）

#### よく買うものダイアログ（`favorites_dialog.dart`）

```
AlertDialog
 ├─ タイトル「よく買うもの」
 ├─ × ボタン（右上：ダイアログを閉じる）  ← 新規
 ├─ 検索窓（TextField：商品名でリストを絞り込む）  ← 新規
 ├─ Scrollbar（thumbVisibility: true）  ← 新規
 ├─ [全選択 / 全解除] トグルボタン（favorites 0件時は非表示）
 ├─ 商品一覧
 │   ├─ 0件時：「まだ登録されていません」
 │   └─ 1件以上：
 │       Dismissible（スワイプ左→削除）＋ インライン Undo バナー
 │        └─ ListTile
 │            ├─ leading: Checkbox（タップでチェック切替）
 │            ├─ title: 商品名
 │            ├─ subtitle: ¥価格 × 個数（price=0 なら「数量: N」）・カテゴリ名
 │            └─ onTap: _EditFavoriteDialog を開く
 ├─ 「直接登録」TextButton → _AddFavoriteDialog（favorites_dialog.dart 内）
 ├─ 「履歴から登録」TextButton → HistorySelectDialog
 └─ 「リストに追加」FilledButton（0件選択時は disabled）
```

#### _EditFavoriteDialog（価格・個数編集ダイアログ）

タイルをタップすると _EditFavoriteDialog が開き、商品名・価格・個数を編集できる。カテゴリドロップダウン（既存カテゴリから選択）と「＋」ボタン（新規カテゴリ追加）を含む。「＋」ボタンをタップすると新規カテゴリ名を入力するダイアログが開き、作成後すぐにドロップダウンへ反映される。

#### DatabaseHelper 追加メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| getFavorites | `Future<List<Map<String, dynamic>>> getFavorites()` | 全件取得（sortOrder ASC） |
| insertFavorite | `Future<void> insertFavorite(String name, int price, int quantity, {int? categoryId})` | 新規登録（sortOrder は MAX+1） |
| restoreFavorite | `Future<void> restoreFavorite(String name, int price, int quantity, int sortOrder, {int? categoryId})` | Undo 用の INSERT（元の sortOrder 指定・categoryId 保持） |
| updateFavorite | `Future<void> updateFavorite(int id, String name, int price, int quantity)` | 既存レコードを UPDATE（位置保持） |
| deleteFavorite | `Future<void> deleteFavorite(int id)` | 1件削除 |
| addFavoriteItemsToList | `Future<void> addFavoriteItemsToList(List<int> favoriteIds, int listId)` | 選択した favorites を items に一括 INSERT（トランザクション） |
| getCategories | `Future<List<Map<String, dynamic>>> getCategories()` | 全件取得（sortOrder ASC） |
| insertCategory | `Future<int> insertCategory(String name)` | 新規登録・ID を返す |
| deleteCategory | `Future<void> deleteCategory(int id)` | 1件削除（関連 items・favorites の categoryId を NULL に更新） |
| getCategoryUsageCount | `Future<int> getCategoryUsageCount(int id)` | カテゴリを使用しているアイテム数を返す |

---

### 8.12 バックアップ・リスト共有・機種変更引継ぎ機能

lists・items・favorites・categories の全データ（または現在リスト1件）を JSON ファイルとしてエクスポートし、別端末・別ユーザーでインポートする。機種変更時のデータ引継ぎと、アプリ同士のリスト受け渡しを同一基盤で実現する。

- item_history はバックアップ対象外
- インポートは**マージ方式**（既存データを残して追加）
- 同名リストは末尾に `(2)` `(3)` と連番付与
- リスト共有・バックアップ・端末保存ファイルはすべて同一の version:2 形式・同一の `import()` 経路で読み込める
- 読み込みのファイル選択は `FileType.any`（拡張子不問）。中身を `parseAndValidate` で検証するため、共有経由で拡張子が書き換わったファイルも取り込める

#### リスト共有（読み込み用）

現在表示中のリスト1件を version:2 形式（`lists`=1件・`items`=未購入のみ・`favorites`=空・`categories`=関連カテゴリ）で書き出し共有シートに渡す。

- **購入済（isChecked=1）アイテムは含めない**（未購入のものだけを送る）
- 共有できる商品が0件の場合は SnackBar「共有できる商品がありません」を表示してキャンセル
- ファイル名: `shoppinglist_<リスト名>_YYYYMMDD.json`（リスト名はファイル名禁止文字をサニタイズ・空なら `list`）
- 受信側は専用メニューを設けず、既存「読み込む（バックアップ／共有リスト）」で取り込む

#### バックアップ保存先の選択

「バックアップ」タップ時に保存先を選択するダイアログを表示する。

- 「共有」 … `BackupService.export()`（共有シート・従来どおり）
- 「端末に保存」 … `BackupService.saveToDevice()`（`FilePicker.platform.saveFile` で保存先選択 → 直接書き込み。Android は SAF のため追加権限不要）
- 端末保存の成否は SnackBar で通知（失敗時は `e.toString()` を使わず汎用文言）

#### バックアップファイル形式（version:2）

ファイル名: `shopping_backup_YYYYMMDD_HHmmss.json`

```json
{
  "version": 2,
  "exportedAt": 1718236800000,
  "categories": [
    { "id": 1, "name": "食品", "sortOrder": 0, "createdAt": 1700000000000 }
  ],
  "lists": [{ "id": 1, "name": "買い物リスト", "createdAt": 1700000000000 }],
  "items": [
    { "id": 1, "name": "牛乳", "price": 198, "isChecked": 0,
      "createdAt": 1700000001000, "sortOrder": 0, "quantity": 2, "memo": "", "listId": 1,
      "categoryId": 1 }
  ],
  "favorites": [
    { "id": 1, "name": "卵", "price": 248, "quantity": 1, "sortOrder": 0,
      "createdAt": 1700000002000, "categoryId": 1 }
  ]
}
```

> `lists.id` / `items.listId` はバックアップ内でのみ有効な仮 ID。インポート時に DB の実際の新 ID にマッピングし直す。

#### エクスポート処理フロー

```
⋮ メニュー →「バックアップ」タップ
→ 保存先選択ダイアログ（「共有」「端末に保存」「キャンセル」）
    ├─「共有」    → BackupService.export()
    │                → DB から lists・items・favorites・categories を全取得
    │                → JSON 生成 → getTemporaryDirectory() に保存
    │                → Share.shareXFiles([XFile(path)]) で共有シート表示
    └─「端末に保存」→ BackupService.saveToDevice()
                     → JSON 生成（utf8 bytes）
                     → FilePicker.platform.saveFile(...) で保存先選択・書き込み
                     → SnackBar「端末に保存しました」（キャンセル時は何もしない）

⋮ メニュー →「リストを共有（読み込み用）」タップ
→ BackupService.shareList(listId, listName)
    → 対象リストと未購入アイテムのみを version:2 形式（favorites=[]）で生成
    → 一時ファイルに保存 → Share.shareXFiles で共有シート表示 → 後始末で削除
    → 未購入0件なら共有せず SnackBar「共有できる商品がありません」
```

#### インポート処理フロー

```
⋮ メニュー →「読み込む（バックアップ／共有リスト）」タップ
→ 確認ダイアログ
   「既存のデータは残したまま、ファイルのデータが追加されます。
     共有されたリストもここから読み込めます。よろしいですか？」
→ BackupService.import()
    → FilePicker でファイル選択（FileType.any・拡張子不問）
    → JSON パース・バリデーション（version・必須キー確認）
    → DatabaseHelper.importData(data) でマージ INSERT
        → categories: 同名が既存の場合はスキップ → INSERT → 旧ID→新ID マップ作成
        → lists: 同名に連番付与 → INSERT → 旧ID→新ID マップ作成
        → items: listId・categoryId を新 ID に差し替えて INSERT
        → favorites: MAX(sortOrder)+1 から採番して INSERT（共有リストは空のため追加なし）
→ SnackBar「Xリスト・Y件の商品・Z件のよく買うものを追加しました」
```

#### エラーハンドリング

| ケース | 対応 |
|--------|------|
| 共有対象リストが空（未購入0件） | SnackBar「共有できる商品がありません」（共有しない） |
| ファイル選択キャンセル | 何もしない |
| 端末保存キャンセル | 何もしない |
| 端末保存失敗 | SnackBar「保存に失敗しました」（`e.toString()` は使わない） |
| JSON パース失敗・中身不正 | SnackBar「読み込めないファイルです」 |
| version 不一致 | SnackBar「対応していないバックアップ形式です」 |
| version:1 バックアップ | categories を空として処理（後方互換） |
| 10件上限超過 | SnackBar「リストが上限（10件）に達しているため読み込めません」 |
| DB 書き込み失敗 | SnackBar「読み込みに失敗しました」 |

#### BackupService メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| _serialize | `static Future<String> _serialize({int? onlyListId, bool excludeChecked = false})` | 全データ（または指定リストのみ）を version:2 JSON 文字列化。共通化のための内部メソッド |
| export | `static Future<void> export()` | 全データを JSON ファイルとして共有シートに渡す |
| saveToDevice | `static Future<bool> saveToDevice()` | 全データを端末に保存（saveFile）。保存=true・キャンセル=false |
| shareList | `static Future<bool> shareList(int listId, String listName)` | 指定リストを未購入のみで共有シートに渡す。共有商品0件なら false |
| import | `static Future<ImportResult?> import()` | ファイル選択（FileType.any）→マージINSERT。キャンセル時は null |
| parseAndValidate | `static Map<String, dynamic> parseAndValidate(String content)` | JSON パースとバリデーション（テスト可能） |

#### DatabaseHelper 追加メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| importData | `Future<ImportResult> importData(Map<String, dynamic> data)` | lists・items・favorites・categories をマージ INSERT |
| resolveListName | `static String resolveListName(String name, Set<String> existingNames)` | 衝突時に連番付与した名前を返す（テスト可能） |

---

## 9. クラス設計

### 9.1 Item（商品データモデル）

| フィールド | 型 | 内容 |
|-----------|-----|------|
| name | String | 商品名 |
| price | int | 税込単価 |
| isChecked | bool | 購入済み（デフォルト: false） |
| id | int? | PK（自動採番） |
| createdAt | int | 作成日時（UnixミリS） |
| sortOrder | int | 並び順（デフォルト: 0） |
| quantity | int | 個数（デフォルト: 1） |
| memo | String | メモ（デフォルト: 空文字） |
| listId | int | 所属リスト |
| categoryId | int? | カテゴリID（NULL許可） |

| メソッド | 内容 |
|----------|------|
| toMap() | DB保存 |
| fromMap() | DB読込 |
| copyWith() | 部分更新 |

### 9.2 ShoppingList（リスト情報モデル）

| メソッド | 内容 |
|----------|------|
| toMap() | DB保存 |
| fromMap() | DB読込 |

### 9.3 DatabaseHelper（SQLite操作管理）

- CRUD
- DB生成・Migration
- History管理
- Favorites管理
- Categories管理
- リスト削除時のCASCADE処理（トランザクション）
- バックアップ用 importData()・resolveListName()

### 9.4 ItemNotifier（状態管理）

- 商品取得・追加・更新・削除
- Undo（単件・複数件対応）
- 並び替え・リスト切替

### 9.5 PurchaseNotifier（購入状態管理）

| メソッド | 内容 |
|----------|------|
| `build()` | キャッシュ読込・purchaseStream 購読・購入復元 |
| `purchase()` | IAP 購入処理。失敗時はエラーメッセージを返す（`String?`） |
| `restore()` | 購入復元処理（`restorePurchases`） |

### 9.6 BackupService（バックアップ・リスト共有管理）

| メソッド | 内容 |
|----------|------|
| `_serialize()` | 全データ／指定リストを version:2 JSON 文字列化（共通化） |
| `export()` | 全データを JSON ファイルとして共有シートに渡す |
| `saveToDevice()` | 全データを端末に保存（file_picker saveFile・SAF） |
| `shareList()` | 指定リストを未購入のみで共有シートに渡す |
| `import()` | ファイル選択（FileType.any）→バリデーション→マージINSERT |
| `parseAndValidate()` | JSON文字列のパースとバリデーション |

### 9.7 ImportResult（インポート結果モデル）

| フィールド | 型 | 内容 |
|-----------|-----|------|
| listCount | int | インポートしたリスト数 |
| itemCount | int | インポートした商品数 |
| favoriteCount | int | インポートしたよく買うもの数 |

### 9.8 Category（カテゴリデータモデル）← 新規

| フィールド | 型 | 内容 |
|-----------|-----|------|
| id | int? | PK（自動採番） |
| name | String | カテゴリ名 |
| sortOrder | int | 並び順 |
| createdAt | int | 作成日時（UnixミリS） |

| メソッド | 内容 |
|----------|------|
| toMap() | DB保存 |
| fromMap() | DB読込 |

### 9.9 CategoryNotifier（カテゴリ状態管理）← 新規

- カテゴリ一覧取得・追加・削除

---

## 10. DBバージョン管理

| バージョン | 変更内容 |
|-----------|---------|
| version 1 | 初期構成 |
| version 2 | quantity カラム追加 |
| version 3 | listId カラム追加 |
| version 4 | item_history テーブル追加・Migration 改善 |
| version 5 | taxRate カラム削除（テーブル再作成によるマイグレーション） |
| version 6 | favorites テーブル追加 |
| version 7 | categories テーブル追加・items/favorites に categoryId カラム追加 |

---

## 11. sortOrder 採番ルール

| タイミング | 採番ルール |
|-----------|-----------|
| 新規商品追加時 | `addItem()` 内で `MAX(sortOrder) + 1` をセット |
| Undo復元時 | 元の sortOrder を復元し、必要に応じて再ソート |
| 並び替え時 | ReorderableListView の操作結果を全件再採番 |

---

## 12. エラー対策

#### mountedチェック

非同期後の context 使用対策。

```dart
if (!mounted) return;
```

#### null安全

`?.` および `??` を利用。

#### バリデーション

`TextFormField validator` にて入力制御。

---

## 13. リリースチェックリスト

### Phase 1 — コード完成度

| # | 作業 | 場所 | 優先度 | 状態 |
|---|------|------|--------|------|
| 1-1 | 履歴更新・上限10件・合計表示の実装 | 各ファイル | 🔴 必須 | ✅ 済 |
| 1-2 | `sortOrder: DateTime.now().millisecondsSinceEpoch` を削除（`addItem()` 内で上書きされており冗長） | `widgets/add_item_dialog.dart` | 🟡 推奨 | ✅ 済 |

### Phase 2 — テスト

| # | 作業 | 内容 | 優先度 | 状態 |
|---|------|------|--------|------|
| 2-1 | ボイラープレートテストの削除または修正 | `widget_test.dart` を空にするか実アプリ向けに書き直す | 🔴 必須 | ✅ 済 |
| 2-2 | 主要ロジックの単体テスト | `item_test.dart`（純粋Dartテスト）: Itemモデル4件・合計計算3件・sortOrder採番2件、計9件 (`dart test`) | ⬜ 任意 | ✅ 済 |
| 2-3 | 実機通しテスト | 検証機種: **AQUOS sense9**（全機能手動確認済み） | ⬜ 任意 | ✅ 済 |

### Phase 3 — Android リリース設定

| # | 作業 | 現状 | 対応内容 | 優先度 | 状態 |
|---|------|------|----------|--------|------|
| 3-1 | applicationId 変更 | `jp.hakoniwalabo.shoppinglist` | 変更済み | 🔴 必須 | ✅ 済 |
| 3-2 | アプリ名を日本語に | `strings.xml` + `android:label="@string/app_name"` | 「買い物リスト」に設定済み | 🔴 必須 | ✅ 済 |
| 3-3 | リリース署名設定 | `upload-keystore.jks` + `key.properties` 設定済み | `build.gradle.kts` の signingConfig release ブロック設定済み | 🔴 必須 | ✅ 済 |
| 3-4 | アイコン差し替え | `flutter_launcher_icons` 0.14.4 で生成済み | `assets/icon/icon.png` (1024px) → 全 mipmap + adaptive icon (anydpi-v26) | 🟡 推奨 | ✅ 済 |
| 3-5 | minSdk / targetSdk 確認 | `minSdk = 21`（Android 5.0、Material3 最低要件） | `build.gradle.kts` に明示設定済み | ⬜ 任意 | ✅ 済 |
| 3-6 | `pubspec.yaml` の `version` 更新 | `1.0.1+4` | versionName=1.0.1 / versionCode=4 | ⬜ 任意 | ✅ 済 |
| 3-7 | AdMob 本番 ID 差し替え | 本番 ID 設定済み | admob.google.com でアプリ登録済み → `AndroidManifest.xml` / `ad_banner.dart` 更新済み | 🔴 必須 | ✅ 済 |
| 3-8 | Google Play Console で IAP 商品登録 | 登録済み | 管理対象商品（non-consumable）・商品ID: `remove_ads`・価格設定・有効化済み | 🔴 必須 | ✅ 済 |

### Phase 4 — ビルド・配布

| # | 作業 | 内容 | 優先度 | 状態 |
|---|------|------|--------|------|
| 4-1 | `flutter analyze` 全体確認 | エラー0件を確認 | 🔴 必須 | ✅ 済 |
| 4-2 | リリースビルド | `flutter build appbundle --release`（Play Store用）| 🔴 必須 | ✅ 済 |
| 4-3 | Play Store 公開 | Google Play Console クローズドテスト提出中 | 🔴 必須 | 🔄 進行中 |

---

## 14. 広告・収益化

### 14.1 概要

| 機能 | 実装ファイル | 内容 |
|------|-------------|------|
| バナー広告 | `widgets/ad_banner.dart` | 画面下部固定。購入済みの場合は非表示 |
| 広告なし購入 | `providers/purchase_provider.dart` | 買い切り IAP。購入後は広告が永久非表示 |
| アップグレードUI | `widgets/upgrade_dialog.dart` | AppBar の ★ ボタンから起動 |

### 14.2 AdMob バナー広告

| 設定項目 | テスト値 | 本番値 |
|---------|---------|--------|
| App ID（AndroidManifest.xml） | `ca-app-pub-3940256099942544~3347511713` | admob.google.com で取得 |
| Ad Unit ID（ad_banner.dart） | `ca-app-pub-3940256099942544/6300978111` | admob.google.com で取得 |
| サイズ | `AdSize.banner` | — |
| 表示位置 | Scaffold body 最下部 | — |

> ⚠️ **本番リリース前に必ず** `AndroidManifest.xml` と `ad_banner.dart` の両方をテスト ID から本番 ID に差し替えること。

### 14.3 広告なし購入（IAP）

| 設定項目 | 内容 |
|---------|------|
| 商品ID | `remove_ads` |
| 種別 | 買い切り（non-consumable） |
| 購入状態の永続化 | `SharedPreferences`（key: `is_ad_free`） |
| 購入復元 | アプリ起動時に `restorePurchases()` を自動実行 |
| 未購入時の表示 | AppBar に ★（`Icons.star_outline`）ボタンを表示 |

> ⚠️ **本番リリース前に** Google Play Console で商品ID `remove_ads` の管理対象商品（non-consumable）を登録・有効化すること。

### 14.4 使用パッケージ

| パッケージ | バージョン | 用途 |
|-----------|-----------|------|
| `google_mobile_ads` | ^5.2.0 | バナー広告表示 |
| `in_app_purchase` | ^3.2.0 | IAP 購入処理 |
| `shared_preferences` | ^2.3.0 | 購入状態の永続化 |

---

## 15. 今後の拡張候補

| 優先度 | 機能 | 内容 |
|--------|------|------|
| — | Firebase同期 | クラウド保存 |
| — | 画像添付 | 商品写真 |
| — | 通知 | 買い忘れ防止 |
| — | 検索 | 商品検索 |
| — | CSV出力 | データ共有 |
| — | Widget | ホーム画面追加 |
| — | WearOS | スマートウォッチ対応 |
| — | 共有 | 家族共同編集 |

---

## 16. 現在の特徴まとめ

- ローカルDB完結・高速動作
- Riverpod 状態管理（ItemNotifier / PurchaseNotifier / CategoryNotifier）
- Undo 復元対応（単件・複数件）
- 複数リスト対応（最大10リスト）
- 商品を別リストへ移動
- 商品履歴補完（Autocomplete）
- よく買うもの登録・一括追加・検索（絞り込み表示）
- カテゴリ管理（作成・削除）とカテゴリ別セクション表示
- バックアップ・機種変更引継ぎ（JSONエクスポート/インポート・共有/端末保存）
- アプリ同士のリスト共有（未購入のみ・version:2形式・読み込み統合）
- Material3 UI
- 並び替え対応
- 税込単価保存（price = 税込）・合計 = sum(price × quantity)
- 購入済み管理
- リスト削除時 CASCADE 処理
- AdMob バナー広告（画面下部固定・本番ID）
- 広告なし買い切りアップグレード（IAP: `remove_ads`）
- ヘルプ画面
