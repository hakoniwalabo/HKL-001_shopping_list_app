# HKL-001 買い物リスト 変数の型一覧

- 作成日: 2026-11-05
- 対象バージョン: 1.4.0+14(`pubspec.yaml` の `version`)
- 対象: `lib/` 配下の主要変数(モデルのフィールド、DBテーブル定義、Providerの状態、トップレベル定数・static定数、Stateクラスの状態フィールド)
- 除外: メソッド内のローカル変数、ループ変数、`TextEditingController`/`ScrollController`/`FocusNode` 等の自明なコントローラ類(ただし画面状態の把握に必要な `TabController` は掲載)
- 表記: 「推論」は型注記がなく右辺から型が確定できるもの。「要確認」に該当する項目はなし。
- 初期値欄の「—」は初期値なし(コンストラクタ必須引数など)。

## 1. Dart型とSQLite型の対応

実コードで確認できる範囲のみ。

| Dart型 | SQLite型 | 確認できる変換箇所 | 備考 |
|---|---|---|---|
| `int` / `int?` | `INTEGER` | `item.dart` `category.dart` `shopping_list.dart` の `toMap`/`fromMap` | `id` は `INTEGER PRIMARY KEY AUTOINCREMENT` |
| `String` | `TEXT` | 同上 | |
| `bool` | `INTEGER` | `Item.toMap`(`isChecked ? 1 : 0`)、`Item.fromMap`(`map['isChecked'] == 1`) | 0/1で保存 |
| 日時(`DateTime`) | `INTEGER` | `DateTime.now().millisecondsSinceEpoch` を `createdAt` に格納 | Dart側のフィールド型は `int` |

## 2. models

### 2.1 Item(`lib/models/item.dart`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `name` | `final String` | 非null | —(required) | 商品名 | lib/models/item.dart |
| `price` | `final int` | 非null | —(required) | 税込単価 | lib/models/item.dart |
| `isChecked` | `final bool` | 非null | `false` | チェック済みか | lib/models/item.dart |
| `id` | `final int?` | null許容 | `null` | 主キー | lib/models/item.dart |
| `createdAt` | `final int` | 非null | 未指定時 `DateTime.now().millisecondsSinceEpoch` | 作成日時(エポックミリ秒) | lib/models/item.dart |
| `sortOrder` | `final int` | 非null | `0` | 並び順 | lib/models/item.dart |
| `quantity` | `final int` | 非null | `1` | 数量 | lib/models/item.dart |
| `memo` | `final String` | 非null | `''` | メモ | lib/models/item.dart |
| `listId` | `final int` | 非null | —(required) | 所属リストID | lib/models/item.dart |
| `categoryId` | `final int?` | null許容 | `null` | カテゴリID | lib/models/item.dart |

### 2.2 Category(`lib/models/category.dart`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `id` | `final int?` | null許容 | `null` | 主キー | lib/models/category.dart |
| `name` | `final String` | 非null | —(required) | カテゴリ名 | lib/models/category.dart |
| `sortOrder` | `final int` | 非null | `0` | 並び順 | lib/models/category.dart |
| `createdAt` | `final int` | 非null | 未指定時 `DateTime.now().millisecondsSinceEpoch` | 作成日時(エポックミリ秒) | lib/models/category.dart |

### 2.3 ShoppingList(`lib/models/shopping_list.dart`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `id` | `final int?` | null許容 | `null` | 主キー | lib/models/shopping_list.dart |
| `name` | `final String` | 非null | —(required) | リスト名 | lib/models/shopping_list.dart |
| `createdAt` | `final int` | 非null | 未指定時 `DateTime.now().millisecondsSinceEpoch` | 作成日時(エポックミリ秒) | lib/models/shopping_list.dart |
| `budget` | `final int` | 非null | `0` | 予算(0は未設定) | lib/models/shopping_list.dart |
| `sortOrder` | `final int` | 非null | `0` | タブの並び順 | lib/models/shopping_list.dart |

### 2.4 FavoriteSuggestion(`lib/models/favorite_suggestion.dart`)

DBテーブル `favorites` の行から作る入力候補用モデル(`const` コンストラクタ)。

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `name` | `final String` | 非null | —(required) | 商品名 | lib/models/favorite_suggestion.dart |
| `price` | `final int` | 非null | —(required)。`fromMap` では未設定時 `0` | 単価 | lib/models/favorite_suggestion.dart |
| `quantity` | `final int` | 非null | —(required)。`fromMap` では未設定時 `1` | 数量 | lib/models/favorite_suggestion.dart |
| `categoryId` | `final int?` | null許容 | `null` | カテゴリID | lib/models/favorite_suggestion.dart |
| `categoryName` | `final String?` | null許容 | `null` | 表示用カテゴリ名(DBには保存されない。`withCategoryName` で付与) | lib/models/favorite_suggestion.dart |
| `subtitle`(getter) | `String` | 非null | 算出値 | 候補の副題(`×数量`、価格が0超なら `¥価格`、カテゴリ名を全角空白で連結) | lib/models/favorite_suggestion.dart |

## 3. database(`lib/database/database_helper.dart`)

DBファイル名 `'shopping.db'`、スキーマバージョン `9`(`openDatabase` の `version` 引数、リテラル)。以下は `_createDB`(新規作成時)の定義。

### 3.1 items テーブル

| 列名 | SQLite型 | 制約 | 対応Dart型 | 意味 | 出典 |
|---|---|---|---|---|---|
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | `int?`(`Item.id`) | 主キー | lib/database/database_helper.dart |
| `name` | `TEXT` | なし(NOT NULLなし) | `String`(`Item.name`) | 商品名 | lib/database/database_helper.dart |
| `price` | `INTEGER` | なし | `int`(`Item.price`) | 税込単価 | lib/database/database_helper.dart |
| `isChecked` | `INTEGER` | なし | `bool`(`Item.isChecked`、0/1変換) | チェック済みか | lib/database/database_helper.dart |
| `createdAt` | `INTEGER` | なし | `int`(`Item.createdAt`) | 作成日時 | lib/database/database_helper.dart |
| `sortOrder` | `INTEGER` | なし | `int`(`Item.sortOrder`) | 並び順 | lib/database/database_helper.dart |
| `quantity` | `INTEGER` | なし | `int`(`Item.quantity`) | 数量 | lib/database/database_helper.dart |
| `memo` | `TEXT` | なし | `String`(`Item.memo`) | メモ | lib/database/database_helper.dart |
| `listId` | `INTEGER` | なし | `int`(`Item.listId`) | 所属リストID | lib/database/database_helper.dart |
| `categoryId` | `INTEGER` | なし | `int?`(`Item.categoryId`) | カテゴリID | lib/database/database_helper.dart |

### 3.2 lists テーブル

| 列名 | SQLite型 | 制約 | 対応Dart型 | 意味 | 出典 |
|---|---|---|---|---|---|
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | `int?`(`ShoppingList.id`) | 主キー | lib/database/database_helper.dart |
| `name` | `TEXT` | なし | `String`(`ShoppingList.name`) | リスト名 | lib/database/database_helper.dart |
| `createdAt` | `INTEGER` | なし | `int`(`ShoppingList.createdAt`) | 作成日時 | lib/database/database_helper.dart |
| `budget` | `INTEGER` | `NOT NULL DEFAULT 0` | `int`(`ShoppingList.budget`) | 予算 | lib/database/database_helper.dart |
| `sortOrder` | `INTEGER` | `NOT NULL DEFAULT 0` | `int`(`ShoppingList.sortOrder`) | 並び順 | lib/database/database_helper.dart |

### 3.3 favorites テーブル

対応する専用モデルはなく、`Map<String, dynamic>`(`getFavorites()` の戻り値)または `FavoriteSuggestion` で扱う。

| 列名 | SQLite型 | 制約 | 対応Dart型 | 意味 | 出典 |
|---|---|---|---|---|---|
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | `int`(画面側で `f['id'] as int`) | 主キー | lib/database/database_helper.dart |
| `name` | `TEXT` | `NOT NULL` | `String`(`FavoriteSuggestion.name`) | 商品名 | lib/database/database_helper.dart |
| `price` | `INTEGER` | `NOT NULL DEFAULT 0` | `int`(`FavoriteSuggestion.price`) | 単価 | lib/database/database_helper.dart |
| `quantity` | `INTEGER` | `NOT NULL DEFAULT 1` | `int`(`FavoriteSuggestion.quantity`) | 数量 | lib/database/database_helper.dart |
| `sortOrder` | `INTEGER` | `NOT NULL DEFAULT 0` | `int` | 並び順 | lib/database/database_helper.dart |
| `createdAt` | `INTEGER` | `NOT NULL` | `int` | 作成日時 | lib/database/database_helper.dart |
| `categoryId` | `INTEGER` | なし | `int?`(`FavoriteSuggestion.categoryId`) | カテゴリID | lib/database/database_helper.dart |

### 3.4 categories テーブル

| 列名 | SQLite型 | 制約 | 対応Dart型 | 意味 | 出典 |
|---|---|---|---|---|---|
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | `int?`(`Category.id`) | 主キー | lib/database/database_helper.dart |
| `name` | `TEXT` | `NOT NULL` | `String`(`Category.name`) | カテゴリ名 | lib/database/database_helper.dart |
| `sortOrder` | `INTEGER` | `NOT NULL DEFAULT 0` | `int`(`Category.sortOrder`) | 並び順 | lib/database/database_helper.dart |
| `createdAt` | `INTEGER` | `NOT NULL` | `int`(`Category.createdAt`) | 作成日時 | lib/database/database_helper.dart |

補足として、`_onUpgrade` 経由の移行では一部列の制約が `_createDB` と異なります(例: `items.quantity` は `INTEGER DEFAULT 1`、`items.listId` は `INTEGER DEFAULT 1` で追加)。

### 3.5 DatabaseHelper / ImportResult のフィールド

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `DatabaseHelper.instance` | `static final DatabaseHelper` | 非null | `DatabaseHelper._init()` | シングルトン | lib/database/database_helper.dart |
| `DatabaseHelper._database` | `static Database?` | null許容 | 未設定(null) | DB接続のキャッシュ | lib/database/database_helper.dart |
| `DatabaseHelper.database`(getter) | `Future<Database>` | 非null | 算出値 | 未接続なら `_initDB('shopping.db')` で開く | lib/database/database_helper.dart |
| `ImportResult.listCount` | `final int` | 非null | —(required) | 取り込み対象のリスト数 | lib/database/database_helper.dart |
| `ImportResult.itemCount` | `final int` | 非null | —(required) | 取り込み対象のアイテム数 | lib/database/database_helper.dart |
| `ImportResult.favoriteCount` | `final int` | 非null | —(required) | 実際に挿入したよく買うもの数 | lib/database/database_helper.dart |
| `ImportResult.firstNewListId` | `final int?` | null許容 | `null` | 取り込みで最初に作られたリストID | lib/database/database_helper.dart |

## 4. providers

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `ItemNotifier.currentListId` | `int` | 非null | `1` | 表示中のリストID | lib/providers/item_provider.dart |
| `ItemNotifier.state` | `AsyncValue<List<Item>>`(`AsyncNotifier<List<Item>>` 由来) | 非null | `build()` で `getItemsByListId(currentListId)` | 表示中リストのアイテム | lib/providers/item_provider.dart |
| `itemProvider` | `final AsyncNotifierProvider<ItemNotifier, List<Item>>`(推論) | 非null | `AsyncNotifierProvider(ItemNotifier.new)` | アイテムProvider | lib/providers/item_provider.dart |
| `CategoryNotifier.state` | `AsyncValue<List<Category>>`(`AsyncNotifier<List<Category>>` 由来) | 非null | `build()` で `_fetch()` | カテゴリ一覧 | lib/providers/category_provider.dart |
| `categoryProvider` | `final AsyncNotifierProvider<CategoryNotifier, List<Category>>`(推論) | 非null | `AsyncNotifierProvider(CategoryNotifier.new)` | カテゴリProvider | lib/providers/category_provider.dart |
| `PurchaseNotifier.state` | `AsyncValue<bool>`(`AsyncNotifier<bool>` 由来) | 非null | `build()` の戻り値(広告なし状態) | 広告なし購入済みか | lib/providers/purchase_provider.dart |
| `purchaseProvider` | `final AsyncNotifierProvider<PurchaseNotifier, bool>`(推論) | 非null | `AsyncNotifierProvider(PurchaseNotifier.new)` | 購入Provider | lib/providers/purchase_provider.dart |
| `kRemoveAdsProductId` | `const String`(推論) | 非null | `'remove_ads'` | 広告削除商品のプロダクトID | lib/providers/purchase_provider.dart |
| `_kPrefKey` | `const String`(推論) | 非null | `'is_ad_free'` | 広告なし状態の SharedPreferences キー(値は `bool`) | lib/providers/purchase_provider.dart |
| `_kQueryPastPurchasesTimeout` | `const Duration`(推論) | 非null | `Duration(seconds: 10)` | 購入履歴照会のタイムアウト | lib/providers/purchase_provider.dart |

## 5. services / utils

### 5.1 BackupService(`lib/services/backup_service.dart`)

`BackupService` にフィールド・定数はありません。バックアップJSONのキーのうち、コードで型が確認できるものを示します。

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `'version'`(`buildExportMap` のキー) | `int` | 非null | `2` | エクスポート形式バージョン(インポートは `1` と `2` を許可) | lib/services/backup_service.dart |
| `exportedAt`(`buildExportMap` の引数) | `int`(required) | 非null | 呼び出し時 `DateTime.now().millisecondsSinceEpoch` | エクスポート日時 | lib/services/backup_service.dart |
| `categories` / `lists` / `items` / `favorites`(同引数) | `List<Map<String, dynamic>>`(required) | 非null | — | 各テーブルのエクスポート行 | lib/services/backup_service.dart |

### 5.2 legal_urls(`lib/utils/legal_urls.dart`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `kTermsOfServiceUrl` | `const String` | 非null | `'https://hakoniwalabo.github.io/shopping_list_app/terms_of_service.html'` | 利用規約URL | lib/utils/legal_urls.dart |
| `kPrivacyPolicyUrl` | `const String` | 非null | `'https://hakoniwalabo.github.io/privacy_policy.html'` | プライバシーポリシーURL | lib/utils/legal_urls.dart |
| `kTermsVersion` | `const int` | 非null | `1` | 現在の利用規約バージョン(再同意が必要なときに上げる) | lib/utils/legal_urls.dart |
| `kAcceptedTermsVersionKey` | `const String` | 非null | `'accepted_terms_version'` | 同意済みバージョンの SharedPreferences キー(値は `int`) | lib/utils/legal_urls.dart |

### 5.3 purchase_resolution(`lib/utils/purchase_resolution.dart`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `AdFreeResolution.resolved` | `final bool` | 非null | —(required) | 採用すべき広告なし状態 | lib/utils/purchase_resolution.dart |
| `AdFreeResolution.shouldPersist` | `final bool` | 非null | —(required) | 永続化すべきか | lib/utils/purchase_resolution.dart |

### 5.4 favorites_section_helper(`lib/utils/favorites_section_helper.dart`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `FavoriteSection.title` | `final String` | 非null | —(required) | セクション見出し | lib/utils/favorites_section_helper.dart |
| `FavoriteSection.items` | `final List<Map<String, dynamic>>` | 非null | —(required) | セクションに属する favorites 行 | lib/utils/favorites_section_helper.dart |

`terms_consent.dart` は関数 `needsTermsConsent(int? acceptedVersion, int currentVersion)` のみで、フィールド・定数はありません。

## 6. widgets

### 6.1 ad_banner.dart(`_AdBannerWidgetState`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `_kBannerAdUnitId` | `const String`(推論) | 非null | `'ca-app-pub-8553865418303420/4001353550'` | バナー広告ユニットID | lib/widgets/ad_banner.dart |
| `_ad` | `BannerAd?` | null許容 | `null` | 読み込んだバナー広告 | lib/widgets/ad_banner.dart |
| `_loaded` | `bool` | 非null | `false` | 広告読み込み完了か | lib/widgets/ad_banner.dart |

### 6.2 add_item_dialog.dart(`_AddItemDialogContent` / `_AddItemDialogContentState`)

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `_AddItemDialogContent.currentListId` | `final int` | 非null | —(required) | 追加先リストID | lib/widgets/add_item_dialog.dart |
| `_AddItemDialogContent.candidateNames` | `final List<String>` | 非null | —(required) | 名前入力の履歴候補 | lib/widgets/add_item_dialog.dart |
| `_AddItemDialogContent.item` | `final Item?` | null許容 | `null` | 編集対象(nullなら新規追加) | lib/widgets/add_item_dialog.dart |
| `_CloseAction`(enum) | `enum` | — | `cancel, discard, add` | 閉じる際の選択肢 | lib/widgets/add_item_dialog.dart |
| `_formKey` | `final GlobalKey<FormState>`(推論) | 非null | `GlobalKey<FormState>()` | フォーム検証用キー | lib/widgets/add_item_dialog.dart |
| `_addedCount` | `int` | 非null | `0` | 連続追加した件数 | lib/widgets/add_item_dialog.dart |
| `_selectedCategoryId` | `int?` | null許容 | `null`(`initState` で `item?.categoryId`) | 選択中のカテゴリID | lib/widgets/add_item_dialog.dart |
| `_addToFavorites` | `bool` | 非null | `false` | よく買うものにも追加するか | lib/widgets/add_item_dialog.dart |
| `_categoryFromFavorite` | `bool` | 非null | `false` | カテゴリがよく買うものから設定されたか | lib/widgets/add_item_dialog.dart |
| `_favorites` | `List<FavoriteSuggestion>` | 非null | `[]` | 名前入力のよく買うもの候補 | lib/widgets/add_item_dialog.dart |

### 6.3 fields/item_name_field.dart

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `_maxSuggestions` | `const int` | 非null | `8` | 候補の最大合計件数 | lib/widgets/fields/item_name_field.dart |
| `_maxFavoriteSuggestions` | `const int` | 非null | `5` | よく買うもの候補の最大件数 | lib/widgets/fields/item_name_field.dart |
| `NameSuggestion.name` | `final String` | 非null | —(位置引数) | 候補の文字列 | lib/widgets/fields/item_name_field.dart |
| `NameSuggestion.favorite` | `final FavoriteSuggestion?` | null許容 | `null`(任意の位置引数) | 由来のよく買うもの(履歴由来ならnull) | lib/widgets/fields/item_name_field.dart |
| `ItemNameField.controller` | `final TextEditingController` | 非null | —(required) | 入力コントローラ | lib/widgets/fields/item_name_field.dart |
| `ItemNameField.focusNode` | `final FocusNode?` | null許容 | `null` | 外部から渡すフォーカス | lib/widgets/fields/item_name_field.dart |
| `ItemNameField.candidateNames` | `final List<String>` | 非null | —(required) | 履歴候補 | lib/widgets/fields/item_name_field.dart |
| `ItemNameField.favoriteSuggestions` | `final List<FavoriteSuggestion>` | 非null | `const []` | よく買うもの候補 | lib/widgets/fields/item_name_field.dart |
| `ItemNameField.onFavoriteSelected` | `final ValueChanged<FavoriteSuggestion>?` | null許容 | `null` | 候補選択時のコールバック | lib/widgets/fields/item_name_field.dart |
| `_internalFocusNode` | `FocusNode?` | null許容 | `null`(外部指定がなければ `initState` で生成) | 内部用フォーカス | lib/widgets/fields/item_name_field.dart |
| `_suggestions` | `List<NameSuggestion>` | 非null | `[]` | 表示中の候補 | lib/widgets/fields/item_name_field.dart |

### 6.4 terms_consent_gate.dart

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `TermsConsentGate.child` | `final Widget` | 非null | —(required) | 同意後に表示する子ウィジェット | lib/widgets/terms_consent_gate.dart |
| `_termsTap` | `late final TapGestureRecognizer` | 非null | `initState` で生成 | 利用規約リンクのタップ検出 | lib/widgets/terms_consent_gate.dart |
| `_privacyTap` | `late final TapGestureRecognizer` | 非null | `initState` で生成 | プライバシーポリシーリンクのタップ検出 | lib/widgets/terms_consent_gate.dart |

### 6.5 表示用ウィジェットのプロパティ

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `ListSection.title` | `final String` | 非null | —(required) | セクション見出し | lib/widgets/list_section.dart |
| `ListSection.items` | `final List<Item>` | 非null | —(required) | 表示アイテム | lib/widgets/list_section.dart |
| `ListSection.reorderable` | `final bool` | 非null | —(required) | 並べ替え可能か | lib/widgets/list_section.dart |
| `ListSection.numberFormat` | `final NumberFormat` | 非null | —(required) | 金額書式 | lib/widgets/list_section.dart |
| `ListSection.onReorder` | `final Future<void> Function(int oldIndex, int newIndex)?` | null許容 | `null` | 並べ替え時コールバック | lib/widgets/list_section.dart |
| `ListSection.onToggleCheck` | `final Future<void> Function(Item item)` | 非null | —(required) | チェック切替 | lib/widgets/list_section.dart |
| `ListSection.onDelete` | `final Future<void> Function(Item item)` | 非null | —(required) | 削除 | lib/widgets/list_section.dart |
| `ListSection.onTap` | `final VoidCallback Function(Item item)` | 非null | —(required) | タップ | lib/widgets/list_section.dart |
| `ListSection.onMoveToTab` | `final VoidCallback Function(Item item)?` | null許容 | `null` | 別タブへ移動 | lib/widgets/list_section.dart |
| `ListSection.onAddToFavorites` | `final VoidCallback? Function(Item item)?` | null許容 | `null` | よく買うものへ追加 | lib/widgets/list_section.dart |
| `ItemTile.item` | `final Item` | 非null | —(required) | 表示対象 | lib/widgets/item_tile.dart |
| `ItemTile.reorderIndex` | `final int?` | null許容 | `null` | 並べ替えハンドルのindex | lib/widgets/item_tile.dart |
| `ItemTile.numberFormat` | `final NumberFormat` | 非null | —(required) | 金額書式 | lib/widgets/item_tile.dart |
| `ItemTile.onTap` | `final VoidCallback` | 非null | —(required) | タップ | lib/widgets/item_tile.dart |
| `ItemTile.onDismissed` | `final Future<void> Function()` | 非null | —(required) | スワイプ削除 | lib/widgets/item_tile.dart |
| `ItemTile.onToggleCheck` | `final Future<void> Function(bool?)` | 非null | —(required) | チェック切替 | lib/widgets/item_tile.dart |
| `ItemTile.onMoveToTab` | `final VoidCallback?` | null許容 | `null` | 別タブへ移動 | lib/widgets/item_tile.dart |
| `ItemTile.onAddToFavorites` | `final VoidCallback?` | null許容 | `null` | よく買うものへ追加 | lib/widgets/item_tile.dart |
| `ListManagementButtons.onAddList` | `final VoidCallback` | 非null | —(required) | リスト追加 | lib/widgets/list_management_buttons.dart |
| `ListManagementButtons.onDuplicateList` | `final VoidCallback` | 非null | —(required) | リスト複製 | lib/widgets/list_management_buttons.dart |
| `ListManagementButtons.onToggleReorderMode` | `final VoidCallback` | 非null | —(required) | 並べ替えモード切替 | lib/widgets/list_management_buttons.dart |
| `ListManagementButtons.isReorderMode` | `final bool` | 非null | —(required) | 並べ替えモード中か | lib/widgets/list_management_buttons.dart |
| `ListTabBar.shoppingLists` | `final List<ShoppingList>` | 非null | —(required) | タブに表示するリスト | lib/widgets/list_tab_bar.dart |
| `ListTabBar.tabController` | `final TabController?` | null許容 | —(required、null可) | タブ制御 | lib/widgets/list_tab_bar.dart |
| `ListTabBar.onRenameTab` | `final void Function(ShoppingList)?` | null許容 | `null` | タブ名変更 | lib/widgets/list_tab_bar.dart |
| `ListReorderBar.shoppingLists` | `final List<ShoppingList>` | 非null | —(required) | 並べ替え対象のリスト | lib/widgets/list_reorder_bar.dart |
| `ListReorderBar.onReorder` | `final Future<void> Function(int oldIndex, int newIndex)` | 非null | —(required) | 並べ替え確定 | lib/widgets/list_reorder_bar.dart |
| `TotalSummary.items` | `final List<Item>` | 非null | —(required) | 合計対象のアイテム | lib/widgets/total_summary.dart |
| `BudgetSummary.budget` | `final int` | 非null | —(required) | 表示する予算(0は「予算 -」) | lib/widgets/budget_summary.dart |
| `BudgetSummary.onTap` | `final VoidCallback` | 非null | —(required) | タップ(予算入力) | lib/widgets/budget_summary.dart |

`ItemNameField` 以外の入力フィールド(`PriceField` `QuantityField` `MemoField`)は `TextEditingController controller` のみを持つため掲載を省略しています。`EmptyStateView` `HelpDialog` `UpgradeDialog` の状態フィールドはありません(`_HelpItem` は `IconData icon`、`String label`、`String description` を持つ表示専用のプロパティ)。

## 7. screens

### 7.1 shopping_list_screen.dart

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `_pendingUndoItems` | `List<Item>?` | null許容 | `null` | 削除Undo用に保持するアイテム | lib/screens/shopping_list_screen.dart |
| `shoppingLists` | `List<ShoppingList>` | 非null | `[]` | タブに並ぶリスト一覧 | lib/screens/shopping_list_screen.dart |
| `_tabController` | `TabController?` | null許容 | `null` | タブ制御(リスト0件時は null) | lib/screens/shopping_list_screen.dart |
| `_listScrollCtrl` | `final ScrollController`(推論) | 非null | `ScrollController()` | 一覧のスクロール制御 | lib/screens/shopping_list_screen.dart |
| `currentListId` | `int` | 非null | `-1` | 表示中のリストID | lib/screens/shopping_list_screen.dart |
| `_isChangingTab` | `bool` | 非null | `false` | タブ切替処理中フラグ | lib/screens/shopping_list_screen.dart |
| `_isReorderMode` | `bool` | 非null | `false` | リスト並べ替えモード中か | lib/screens/shopping_list_screen.dart |
| `numberFormat` | `final NumberFormat`(推論) | 非null | `NumberFormat('#,###')` | 金額の桁区切り書式 | lib/screens/shopping_list_screen.dart |
| `kHideAds`(`build` 内) | `const bool`(推論) | 非null | `bool.fromEnvironment('HIDE_ADS')`(ビルド時の `--dart-define`。未指定時 `false`) | 広告非表示ビルドの切替(ローカル定数だが挙動を左右するため掲載) | lib/screens/shopping_list_screen.dart |
| `_OptionItem`(enum) | `enum` | — | `share, shareListFile, upgrade, help, deleteList, backup, importBackup, categories` | オプションメニューの項目 | lib/screens/shopping_list_screen.dart |
| `_SingleFieldDialog.title` | `final String` | 非null | —(required) | ダイアログ見出し | lib/screens/shopping_list_screen.dart |
| `_SingleFieldDialog.labelText` | `final String` | 非null | —(required) | 入力欄ラベル | lib/screens/shopping_list_screen.dart |
| `_SingleFieldDialog.initialText` | `final String?` | null許容 | `null`(表示時は `?? ''`) | 入力欄の初期値 | lib/screens/shopping_list_screen.dart |
| `_SingleFieldDialog.submitLabel` | `final String` | 非null | —(required) | 決定ボタンの文言 | lib/screens/shopping_list_screen.dart |
| `_SingleFieldDialog.onSubmit` | `final Future<void> Function(String value)` | 非null | —(required) | 決定時コールバック | lib/screens/shopping_list_screen.dart |
| `_BudgetInputDialog.initialBudget` | `final int` | 非null | —(required) | 予算入力の初期値 | lib/screens/shopping_list_screen.dart |
| `_BudgetInputDialog.onSubmit` | `final Future<void> Function(int budget)` | 非null | —(required) | 決定時コールバック | lib/screens/shopping_list_screen.dart |

### 7.2 favorites_screen.dart

| 変数名 | 型 | null許容 | 初期値/定数値 | 意味 | 出典 |
|---|---|---|---|---|---|
| `FavoritesScreen.currentListId` | `final int` | 非null | —(required) | 追加先のリストID | lib/screens/favorites_screen.dart |
| `_favorites` | `List<Map<String, dynamic>>` | 非null | `[]` | よく買うもの全件(sortOrder順) | lib/screens/favorites_screen.dart |
| `_selectedIds` | `final Set<int>`(推論) | 非null | `{}` | 選択中のよく買うものID | lib/screens/favorites_screen.dart |
| `_pendingUndoFavorite` | `Map<String, dynamic>?` | null許容 | `null` | 削除Undo用に保持する行 | lib/screens/favorites_screen.dart |
| `_undoTimer` | `Timer?` | null許容 | `null` | Undo受付のタイマー | lib/screens/favorites_screen.dart |
| `_searchText` | `String` | 非null | `''` | 検索文字列 | lib/screens/favorites_screen.dart |
| `_filteredFavorites`(getter) | `List<Map<String, dynamic>>` | 非null | 算出値 | 検索で絞り込んだ一覧 | lib/screens/favorites_screen.dart |
| `_allSelected`(getter) | `bool` | 非null | 算出値 | 絞り込み結果が全選択か | lib/screens/favorites_screen.dart |
| `_AddFavoriteDialog.onAdded` | `final Future<void> Function()` | 非null | —(required) | 追加後コールバック | lib/screens/favorites_screen.dart |
| `_AddFavoriteDialogState._formKey` | `final GlobalKey<FormState>`(推論) | 非null | `GlobalKey<FormState>()` | フォーム検証用キー | lib/screens/favorites_screen.dart |
| `_AddFavoriteDialogState._selectedCategoryId` | `int?` | null許容 | `null` | 選択中のカテゴリID | lib/screens/favorites_screen.dart |
| `_AddFavoriteDialogState._candidateNames` | `List<String>` | 非null | `[]` | 名前入力の候補(既存のよく買うもの名) | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialog.id` | `final int` | 非null | —(required) | 編集対象ID | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialog.initialName` | `final String` | 非null | —(required) | 名前の初期値 | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialog.initialPrice` | `final int` | 非null | —(required) | 単価の初期値 | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialog.initialQuantity` | `final int` | 非null | —(required) | 数量の初期値 | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialog.initialCategoryId` | `final int?` | null許容 | `null` | カテゴリの初期値 | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialogState._formKey` | `final GlobalKey<FormState>`(推論) | 非null | `GlobalKey<FormState>()` | フォーム検証用キー | lib/screens/favorites_screen.dart |
| `_EditFavoriteDialogState._selectedCategoryId` | `late int?` | null許容 | `initState` で `widget.initialCategoryId` | 選択中のカテゴリID | lib/screens/favorites_screen.dart |

## 8. main.dart

トップレベル変数・定数はありません。`MyApp` のフィールドもありません(`home` に `TermsConsentGate(child: ShoppingListScreen())` を渡す構成)。
