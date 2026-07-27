# HKL-001 買い物リストアプリ 全コード解説

## アーキテクチャ全体像

```
lib/
├── main.dart                          # エントリーポイント
├── models/
│   ├── item.dart                      # 商品データモデル
│   ├── category.dart                  # カテゴリデータモデル
│   └── shopping_list.dart             # リストデータモデル
├── database/
│   └── database_helper.dart           # SQLite永続化層（items / lists / favorites / categories）
├── providers/
│   ├── item_provider.dart             # 商品の状態管理（Riverpod）
│   ├── category_provider.dart         # カテゴリの状態管理（Riverpod）
│   └── purchase_provider.dart         # 課金状態管理（Riverpod）
├── services/
│   └── backup_service.dart            # バックアップ・インポート・リスト共有（JSONファイルI/O）
├── screens/
│   └── shopping_list_screen.dart      # メイン画面
└── widgets/
    ├── add_item_dialog.dart           # 商品追加・編集ダイアログ（連続追加対応）
    ├── ad_banner.dart                 # バナー広告
    ├── category_management_dialog.dart # カテゴリ管理ダイアログ
    ├── empty_state_view.dart          # 空リスト表示
    ├── favorites_dialog.dart          # よく買うもの管理（検索・並べ替え・カテゴリ対応）
    ├── help_dialog.dart               # 使い方ダイアログ
    ├── item_tile.dart                 # 商品リスト行
    ├── list_management_buttons.dart   # AppBarのリスト追加・複製ボタン群
    ├── list_section.dart              # カテゴリ別／未購入・購入済みセクション
    ├── list_tab_bar.dart              # タブバー
    ├── total_summary.dart             # 合計金額表示
    ├── upgrade_dialog.dart            # 課金ダイアログ
    └── fields/
        ├── item_name_field.dart       # 商品名入力（候補表示つき）
        ├── price_field.dart           # 価格入力
        ├── quantity_field.dart        # 数量入力
        └── memo_field.dart            # メモ入力
```

状態管理は **Riverpod（AsyncNotifier）**、永続化は **sqflite（SQLite）** を採用しています。加えて、バックアップ・共有機能のためにファイルI/Oを担う `services/` 層が追加され、UI・状態・データベース・外部ファイルI/Oの4層構造になっています。

なお本ドキュメントでは、過去に存在した「商品名の入力履歴（`item_history` テーブル・`upsertHistory`・`history_select_dialog.dart`）」には一切触れません。この履歴ベースのオートコンプリート機能は2026-06-29に完全に削除され、現在のコードベースには存在しません。後述する `item_name_field.dart` の候補表示（サジェスト）機能は、履歴DBを参照する別物であり、現在リストに表示されている商品名や「よく買うもの」の登録名（`candidateNames`）を元にした別の仕組みです。

---

## 1. `main.dart` — エントリーポイント

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}
```

`ensureInitialized()` でFlutterエンジンとの接続を確立してから、非同期の初期化処理を順に実行しています。`setPreferredOrientations` で縦画面固定、`MobileAds.instance.initialize()` でAdMob SDKを初期化します。

`ProviderScope` はRiverpodの必須ラッパーで、アプリ全体のプロバイダーストアを保持します。これを `MyApp` より外側に置くことで、すべてのWidgetからプロバイダーへアクセスできます。

`MyApp` ではテーマを `deepPurple` × `useMaterial3: true` で設定し、`themeMode: ThemeMode.system` によりOSのダーク/ライト設定に自動追従します。この部分は前バージョンから変更ありません。

---

## 2. `models/item.dart` — 商品データモデル

```dart
class Item {
  final String name;      // 商品名
  final int price;        // 税込単価（0以上の整数）
  final bool isChecked;   // 購入済みフラグ
  final int? id;          // DBのPRIMARY KEY（新規時はnull）
  final int createdAt;    // 作成時刻（ミリ秒）
  final int sortOrder;    // 表示順（小さいほど上）
  final int quantity;     // 数量（デフォルト1）
  final String memo;      // メモ（編集時のみ表示）
  final int listId;       // 所属するリストのID
  final int? categoryId;  // 所属カテゴリID（未分類はnull）
}
```

カテゴリ機能追加に伴い `categoryId` フィールドが増えました。`Item` は引き続き **イミュータブル**（全フィールドが `final`）で、変更は `copyWith()` で新しいインスタンスを生成する設計です。

### `copyWith` と `copyWithNullableCategory` の使い分け

```dart
Item copyWith({ ..., int? categoryId, ... }) {
  return Item(
    ...
    categoryId: categoryId ?? this.categoryId,
    ...
  );
}

// copyWith は null を「変更なし」と解釈するため、categoryId を明示的に null にするにはこちらを使う。
Item copyWithNullableCategory({required int? categoryId}) {
  return Item(
    ...
    categoryId: categoryId,
    ...
  );
}
```

通常の `copyWith` は `??` 演算子を使うため、「引数に `null` を渡す」＝「変更しない」という意味になり、**カテゴリを「なし」に戻す**操作を表現できません。この問題を避けるため、`categoryId` だけは常に引数の値をそのまま採用する `copyWithNullableCategory` を別途用意しています。実際に `add_item_dialog.dart` の編集フローでは、通常フィールドの変更を `copyWith` で行った後に `copyWithNullableCategory` を重ねて呼び、カテゴリの「なし」選択を確実に反映しています。

`toMap()` / `fromMap()` はSQLiteとのシリアライズ・デシリアライズを担い、`categoryId` もそのまま `INTEGER`（NULL許容）としてやり取りします。`isChecked` はSQLiteがbool型を持たないため `INTEGER 0/1` に変換します。

---

## 3. `models/category.dart` — カテゴリデータモデル（新規）

```dart
class Category {
  final int? id;
  final String name;
  final int sortOrder;
  final int createdAt;

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] != null ? (map['id'] as num).toInt() : null,
        name: map['name'] as String,
        sortOrder: (map['sortOrder'] as num).toInt(),
        createdAt: (map['createdAt'] as num).toInt(),
      );
}
```

`Item` や `ShoppingList` と同じ軽量な設計です。注目すべきは `fromMap` で `as int` ではなく `(map['id'] as num).toInt()` を使っている点です。これはプロジェクトルールに明記された「外部JSON・外部ファイル由来の整数値は `as int` でなく `(num).toInt()` でキャストする」を反映したもので、バックアップJSONインポート時に数値が `double` として来ても安全にパースできるようにしています（JSONの数値はDart側で `int` か `double` か厳密に区別されないため）。

---

## 4. `models/shopping_list.dart` — リストモデル

```dart
class ShoppingList {
  final int? id;
  final String name;
  final int createdAt;
}
```

変更なし。`lists` テーブルの行を表す軽量なモデルです。`copyWith()` は持たず、リスト名変更・削除はDBへの直接操作で対応しています。

---

## 5. `database/database_helper.dart` — SQLite永続化層

### シングルトンパターン（変更なし）

```dart
static final DatabaseHelper instance = DatabaseHelper._init();
static Database? _database;

Future<Database> get database async {
  if (_database != null) return _database!;
  _database = await _initDB('shopping.db');
  return _database!;
}
```

### テーブル構成（version 7）

| テーブル名 | 役割 |
|---|---|
| `items` | 買い物商品。`listId` でリストに、`categoryId` でカテゴリに紐付け |
| `lists` | 複数リストの管理 |
| `favorites` | よく買うもの（独立したマスタデータ）。`categoryId` を持つ |
| `categories` | カテゴリマスタ（`name` / `sortOrder`） |

`item_history` テーブルは存在しません（過去バージョンで廃止済み）。

### マイグレーション履歴（`_onUpgrade`）

```dart
// version 4 → 5: taxRate カラムを削除（テーブル再作成パターン）
if (oldVersion < 5) { ... }

// version < 6: favorites テーブルを追加
if (oldVersion < 6) {
  await db.execute('CREATE TABLE IF NOT EXISTS favorites (...)');
}

// version < 7: categories テーブルを追加 + items/favorites に categoryId カラムを追加
if (oldVersion < 7) {
  await db.execute('CREATE TABLE IF NOT EXISTS categories (...)');
  for (final sql in [
    'ALTER TABLE items ADD COLUMN categoryId INTEGER',
    'ALTER TABLE favorites ADD COLUMN categoryId INTEGER',
  ]) {
    try { await db.execute(sql); } catch (_) {}
  }
}
```

version 7 で追加された分岐が、カテゴリ機能のためのマイグレーションです。`CREATE TABLE IF NOT EXISTS` による冪等性、`ALTER TABLE ADD COLUMN` を `try/catch` で握りつぶす二重適用対策は、既存のマイグレーション方針をそのまま踏襲しています。カラム追加（`ADD COLUMN`）はAndroidのSQLiteでも問題なく動作するため、v4→v5のような「カラム削除」時にのみ必要だったテーブル再作成パターンはここでは不要です。

### `insertItem` と `insertItemWithId` の使い分け（変更なし）

通常追加では `map.remove('id')` でnullのIDフィールドを取り除き、DBの `AUTOINCREMENT` にIDを割り当てさせます。Undo復元では元のIDを保持したまま `ConflictAlgorithm.replace` で再挿入することで、並び順も含めて完全に元の状態を再現します。

### `normalizeAllSortOrders` — 現状「未使用」のユーティリティ

```dart
Future<void> normalizeAllSortOrders(int listId) async {
  // sortOrder を 0, 1, 2, ... の連番に振り直す
}
```

コード内には定義されていますが、現時点で `lib/` 内から呼び出している箇所はありません（`item_provider.dart` のコメントに「reorder 時のみ実施。起動時は不要」「sortOrder に gap があっても表示・reorder に影響しない」とあり、削除操作後のnormalize処理を意図的に省略した経緯がうかがえます）。将来の再利用に備えて残されている可能性があるため、削除ではなく現状維持として記載します。

### `duplicateList` — リスト複製（新規）

```dart
Future<int> duplicateList(int sourceListId, String newName) async {
  return await db.transaction((txn) async {
    final newListId = await txn.insert('lists', {...});
    final items = await txn.query('items', where: 'listId = ?', whereArgs: [sourceListId], ...);
    for (final item in items) {
      final copy = Map<String, dynamic>.from(item);
      copy.remove('id');
      copy['listId'] = newListId;
      copy['isChecked'] = 0; // 複製時はすべて未チェックにリセット
      await txn.insert('items', copy);
    }
    return newListId;
  });
}
```

新規リストを作成し、元リストの商品を丸ごとコピーします。`isChecked` を強制的に `0` にリセットするのが仕様上のポイントで、「次回の買い物用にリストを使い回す」というユースケースを想定しています。`categoryId` は `Map.from(item)` でそのままコピーされるため、カテゴリ分類も維持されます。

### `resolveListName` — リスト名の衝突解決（新規、バックアップインポートで使用）

```dart
static String resolveListName(String name, Set<String> existingNames) {
  if (!existingNames.contains(name)) return name;
  int i = 2;
  while (existingNames.contains('$name($i)')) { i++; }
  return '$name($i)';
}
```

バックアップ／共有ファイルをインポートする際、同名のリストがすでに存在する場合に `名前(2)`, `名前(3)`... と末尾に連番を付けて一意な名前を生成します。`static` メソッドなのでDBアクセスを伴わない純粋関数として単体テストしやすい設計です。

### カテゴリCRUD

```dart
Future<void> deleteCategory(int id) async {
  final db = await database;
  await db.transaction((txn) async {
    await txn.update('items', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [id]);
    await txn.update('favorites', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [id]);
    await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
  });
}
```

カテゴリを削除する際、そのカテゴリに属していた `items` / `favorites` の `categoryId` を先に `null` に戻してから `categories` 行を削除します。3つの操作を1つの `transaction` に包むことで、「商品のcategoryIdだけnullになったのにカテゴリ行が残る」ような中途半端な状態を防いでいます。SQLiteには外部キー制約による `ON DELETE SET NULL` を使っていないため、アプリケーション側で明示的に整合性を取っている点が設計上の要点です。

### `importData` — バックアップJSONのマージインポート（新規）

```dart
Future<ImportResult> importData(Map<String, dynamic> data) async {
  ...
  if (existingNames.length + incomingLists.length > 10) {
    throw const FormatException('list_limit_exceeded');
  }
  ...
  await db.transaction((txn) async {
    // ① categories: name重複はスキップし、旧ID→新IDのマップを構築
    // ② lists: name衝突は resolveListName で解決。旧ID→新IDのマップを構築
    // ③ items: listId・categoryId を新IDに差し替えて挿入
    // ④ favorites: name重複はスキップして挿入
  });
  return ImportResult(...);
}
```

インポート処理は、既存データを一切消さずに追加する「マージ」方式です。設計上の重要な点が3つあります。

**リスト10件上限のチェックがUIとDB書き込み経路の両方に存在する。** `_showAddListDialog` のUI側チェックだけでなく `importData` 冒頭でも `existingNames.length + incomingLists.length > 10` を検証しています。これはプロジェクトルールに明記された「インポート・DB書き込み経路にはUIと同等の業務ルールチェックを必ず実装する」を反映したもので、UIバリデーションだけでは迂回できる経路（他アプリからファイルを共有してインポートする経路など）を塞いでいます。

**IDのリマップ。** インポート元のJSONに含まれる `id`（`categories`・`lists`）はインポート先DBでは意味を持たないため、`categoryIdMap` / `listIdMap` で「旧ID→新ID」の対応表を作りながら挿入し、`items` / `favorites` の外部キー参照（`categoryId` / `listId`）を新IDに差し替えます。

**`createdAt` を流用せずDB側で採番し直す。**

```dart
final baseCreatedAt = ((maxCreatedAtResult.first['maxAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch) + 1;
```

`getLists()` は `orderBy: 'createdAt ASC'` で並んでいるため、バックアップ元の `createdAt` をそのまま使うとインポートしたリストが既存リストの間に割り込んで表示される可能性があります。これを避けるため、現在のDB内の最大 `createdAt` + 連番を新たに採番しています。プロジェクトルールに「インポート処理でバックアップのメタデータ（`createdAt`等）を流用せず、現在のDB最大値+連番を設定する」と明記された知見です。

---

## 6. `providers/item_provider.dart` — 商品の状態管理

構造は前バージョンからほぼ変わっていません。`AsyncNotifier<List<Item>>` を継承し、`build()` が初期状態を返します。

### 楽観的更新（Optimistic Update）は `reorderUncheckedItems` のみ

```dart
Future<void> reorderUncheckedItems(int oldIndex, int newIndex) async {
  // ...並び替え計算...
  state = AsyncData(updated);             // UIを先に更新（即時フィードバック）
  await DatabaseHelper.instance.updateSortOrders(updated);  // 後でDB書き込み
}
```

ドラッグ操作のレスポンスを優先し、DB書き込み前にstateを更新します。他の操作（`addItem`, `toggleCheck`, `moveItemToList` など）はDB書き込み→再取得→state更新の順で確実性を優先しています。この非対称な設計方針は変更ありません。

### `moveItemToList` — 別リストへの商品移動（新規）

```dart
Future<void> moveItemToList(int itemId, int targetListId) async {
  await DatabaseHelper.instance.updateItemListId(itemId, targetListId);
  final refreshed = await DatabaseHelper.instance.getItemsByListId(currentListId);
  state = AsyncData(refreshed);
}
```

商品の `listId` を書き換えて別リストへ移動させます。移動後は現在表示中のリスト（移動元）のitemsを再取得するため、移動された商品は自動的に画面から消えます。呼び出し元は `shopping_list_screen.dart` の `_showMoveToTabDialog`（商品の長押しメニューから呼ばれる）です。

### Undo対応の `deleteItemById` / `deleteCheckedItemsWithUndo` / `restoreItemWithOrder`（変更なし）

削除前にアイテムをメモリに退避して呼び出し元に返し、5秒以内にUndoされた場合は `restoreItemWithOrder` で元のIDと `sortOrder` を保った状態で復元する設計です。

---

## 7. `providers/category_provider.dart` — カテゴリの状態管理（新規）

```dart
class CategoryNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async => _fetch();

  // addCategory は作成した id を返す（ダイアログでドロップダウン選択状態にするため）。
  Future<int> addCategory(String name) async {
    final id = await DatabaseHelper.instance.insertCategory(name);
    state = AsyncData(await _fetch());
    return id;
  }

  Future<void> deleteCategory(int id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    state = AsyncData(await _fetch());
  }
}
```

`item_provider.dart` と同じ「DB書き込み→再取得→state更新」パターンです。`addCategory` が戻り値として新規カテゴリの `id` を返す点が特徴で、これは `add_item_dialog.dart` や `favorites_dialog.dart` のカテゴリドロップダウンから「新規カテゴリ」ボタンで即座にそのカテゴリを選択状態にするために使われています（`setState(() => _selectedCategoryId = id)`）。

`categoryProvider` は `shopping_list_screen.dart` のカテゴリ管理メニュー操作後や、バックアップインポート成功後（`ref.invalidate(categoryProvider)`）にも再取得がトリガーされます。

---

## 8. `providers/purchase_provider.dart` — 課金状態管理

ロジックは前バージョンから変更ありません。`build()` の3ステップ初期化（①SharedPreferencesキャッシュの即時読込 → ②購入ストリーム購読 → ③未購入時のみPlay Storeに照合）、`ref.onDispose(sub.cancel)` によるストリーム自動解放は同じです。

変更点は依存パッケージのバージョンです。`pubspec.yaml` で `in_app_purchase: ^3.3.0` を使用しており、これは Google Play Billing Library 8.0.0 に対応したバージョンです。プロジェクトルールには「外部パッケージの依存バージョン対応関係を調査する際は、WebFetchの要約結果をそのまま採用せず、GitHubのraw CHANGELOG.md等の一次情報で裏取りする」と明記されており、この対応バージョン確認時に pub.dev の要約が誤情報（Billing Library 3.0への移行、という誤った内容）を含んでいたため、GitHub raw CHANGELOGで裏取りして正しいバージョンを採用した経緯があります。コード自体（`purchase_provider.dart`）に変更はなく、パッケージ更新のみで対応が完了しています。

---

## 9. `services/backup_service.dart` — バックアップ・共有（新規）

`DatabaseHelper` を利用してJSONの構築・ファイルI/O・共有シート起動を行う、UIから独立したサービスクラスです。すべて `static` メソッドで構成されており、状態を持ちません。

### バックアップフォーマット（version 2）

```dart
static Map<String, dynamic> buildExportMap({
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> lists,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> favorites,
  required int exportedAt,
}) {
  return {
    'version': 2,
    'exportedAt': exportedAt,
    'categories': categories,
    'lists': lists,
    'items': items,
    'favorites': favorites,
  };
}
```

`version` フィールドでフォーマットのバージョンを明示しています。version 1（`categories` を含まない旧フォーマット、カテゴリ機能追加前のバックアップ）との後方互換性を保つため、`importData` 側は `version == 2` のときのみ `categories` を読み込む分岐になっています（`database_helper.dart` 参照）。

### `export()` と `saveToDevice()` — 2つの保存経路

```dart
static Future<void> export() async {
  final json = await _buildFullBackupJson();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_backupFileName()}');
  await file.writeAsString(json);
  try {
    await Share.shareXFiles([XFile(file.path)], subject: '買い物リスト バックアップ');
  } finally {
    if (await file.exists()) await file.delete();
  }
}
```

`export()` は一時ディレクトリにJSONを書き出し、OSの共有シート（メール添付・クラウドストレージへの送信など）に渡した後、`finally` で必ず一時ファイルを削除します。共有シートを閉じるタイミングは `Share.shareXFiles` の `await` が返った後になるため、削除は共有処理の完了後に行われます。

一方 `saveToDevice()` は `file_picker` の `saveFile`（AndroidではSAF: Storage Access Framework）を使い、ユーザーが選んだ保存先に直接バイト列を書き込みます。一時ファイルを経由しないため `finally` での削除処理は不要です。

### `shareList` — 未購入商品のみを共有用ファイル化

```dart
static Future<bool> shareList(int listId, String listName) async {
  ...
  final unchecked = items.where((i) => !i.isChecked).toList();
  if (unchecked.isEmpty) return false;

  final usedCategoryIds = unchecked.map((i) => i.categoryId).whereType<int>().toSet();
  final allCategories = await helper.getCategories();
  final usedCategories = allCategories.where((c) => usedCategoryIds.contains(c['id'])).toList();
  ...
}
```

「1つのリストだけを他の人に送る」機能です。バックアップ全体ではなく、共有できる商品（未購入のもの）が実際に使っている `categoryId` に対応するカテゴリのみを抽出しています（`whereType<int>()` で `categoryId == null` の商品を除外してから `Set` 化）。これにより、共有ファイルに無関係なカテゴリ定義が混入しないよう絞り込んでいます。

### `parseAndValidate` — インポート前のフォーマット検証

```dart
static Map<String, dynamic> parseAndValidate(String content) {
  late Map<String, dynamic> data;
  try {
    data = jsonDecode(content) as Map<String, dynamic>;
  } catch (_) {
    throw const FormatException('invalid_json');
  }
  if (data['version'] is! int) throw const FormatException('invalid_json');
  final version = data['version'] as int;
  if (version != 1 && version != 2) throw const FormatException('unsupported_version');
  ...
}
```

`FormatException` のメッセージ文字列（`'invalid_json'` / `'unsupported_version'` / `'list_limit_exceeded'`）はユーザー向け文言そのものではなく、内部的なエラー種別コードとして使われています。呼び出し元の `shopping_list_screen.dart` の `_importBackup` で `switch (e.message)` により日本語メッセージへ変換しており、内部エラーの詳細（`e.toString()` など）をそのままSnackBarに出さない設計です。これはプロジェクトルールの「catch節でユーザー向けメッセージを返す場合は `e.toString()` を使わず汎用文言にする」に沿った実装です。

`file_picker` の `pickFiles` は `type: FileType.any` で拡張子を限定していません。これは「共有経由で拡張子が書き換わったファイルも選べるように」というコメントの通り、他アプリ経由で受け取ったファイルの拡張子が変化していても選択できるようにするためで、中身の安全性は `parseAndValidate` のバリデーションで別途担保しています。

---

## 10. `screens/shopping_list_screen.dart` — メイン画面

アプリの中核画面です。カテゴリ・バックアップ機能の追加により、以前よりも扱う責務が大きく増えています。

### `_buildCategorySections` — カテゴリ別セクション生成

```dart
List<Widget> _buildCategorySections({
  required List<Item> unchecked,
  required List<Category> categories,
  ...
}) {
  if (categories.isEmpty) {
    return [ListSection(title: '未購入', items: unchecked, ...)];
  }

  final result = <Widget>[];
  for (final cat in categories) {
    final catItems = unchecked.where((i) => i.categoryId == cat.id).toList();
    if (catItems.isEmpty) continue;
    result.add(ListSection(title: cat.name, items: catItems, ...));
  }

  final categoryIds = categories.map((c) => c.id).toSet();
  final noCategory = unchecked.where(
    (i) => i.categoryId == null || !categoryIds.contains(i.categoryId),
  ).toList();
  if (noCategory.isNotEmpty) {
    result.add(ListSection(title: 'カテゴリなし', items: noCategory, ...));
  }
  return result;
}
```

未購入商品を「未購入」1セクションでまとめて表示する従来の挙動から、カテゴリが1件でも存在する場合はカテゴリごとにセクションを分割して表示する挙動に変わりました。設計上の要点は2つです。

**カテゴリが0件のときは従来通りの表示にフォールバックする。** カテゴリ機能を使わないユーザーには一切UIの変化がありません。

**「カテゴリなし」セクションは `categoryId == null` だけでなく `!categoryIds.contains(i.categoryId)` も条件に含める。** これは、商品が過去に割り当てられていたカテゴリが削除された場合（`categoryId` の値自体は `deleteCategory` によりDB側で `null` に更新されるため、実際には発生しにくいケース）や、インポートで解決できなかった孤立した `categoryId` を持つ商品を、UI上は確実に「カテゴリなし」に落とし込むための防御的な条件です。

### カテゴリ内reorderのグローバルインデックス変換

```dart
onReorder: (oldIndex, newIndex) async {
  final globalOld = unchecked.indexOf(catItems[oldIndex]);
  final globalNew = unchecked.indexOf(catItems[newIndex]);
  await ref.read(itemProvider.notifier).reorderUncheckedItems(globalOld, globalNew);
},
```

`ItemNotifier.reorderUncheckedItems` は「未購入リスト全体」でのインデックスを前提に実装されています。しかしカテゴリ別セクションの `ReorderableListView` はセクション内（`catItems`）のローカルなインデックスしか返しません。そこで `unchecked.indexOf(...)` を使い、カテゴリ内のローカルインデックスを未購入全体でのグローバルインデックスに変換してから呼び出しています。`Item` はイミュータブルなオブジェクトで `==` を再定義していないため、`indexOf` は参照（identity）比較で目的の要素を一意に特定できます。

### `_exportBackup` / `_importBackup` — バックアップUIフロー

```dart
Future<void> _exportBackup() async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      ...
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop('cancel'), ...),
        TextButton(onPressed: () => Navigator.of(ctx).pop('share'), ...),
        FilledButton(onPressed: () => Navigator.of(ctx).pop('device'), ...),
      ],
    ),
  );
  if (choice == null || choice == 'cancel' || !mounted) return;
  ...
}
```

保存先選択ダイアログで文字列を返す小さな状態機械として実装されています。`_importBackup` 側は成功時にリスト一覧の再読み込み（`loadLists()`）とカテゴリプロバイダーの無効化（`ref.invalidate(categoryProvider)`）を行い、インポート結果に新規リストが含まれていればそのタブへ自動的に切り替えます（`_tabController?.animateTo(newIndex)`）。

### `_duplicateCurrentList` — リスト複製時の名前衝突解決

```dart
final baseName = '${currentList.name}のコピー';
final existingNames = shoppingLists.map((e) => e.name).toSet();
String newName = baseName;
if (existingNames.contains(baseName)) {
  int i = 2;
  while (existingNames.contains('$baseName($i)')) { i++; }
  newName = '$baseName($i)';
}
```

`database_helper.dart` の `resolveListName` と同じ「衝突したら `(2)` `(3)`... を付与する」ロジックですが、こちらは画面側のローカルなリスト名（`shoppingLists`）を対象にしたその場限りの実装です。同一パターンが2箇所（DB層とUI層）に存在しており、片方だけ仕様変更するとロジックがずれるリスクがある点は留意が必要です。

### タブコントローラー管理・`_handleTabChange`（変更なし）

`loadLists` でのTabController再構築、`_isChangingTab` フラグによる二重実行防止のロジックは前バージョンから変わっていません。

### `_shareCurrentList`（テキスト共有）と `_shareListFile`（ファイル共有）の使い分け

前バージョンから存在した `_shareCurrentList`（`StringBuffer` でテキスト整形して `Share.share()` に渡す）に加え、新たに `_shareListFile` が追加されました。こちらは `BackupService.shareList` を呼び出し、リストをJSONファイルとして共有します。テキスト共有は「人が読むため」、ファイル共有は「別の端末のこのアプリに読み込ませるため」という異なる用途を持ち、AppBarのオプションメニューにも「テキストで共有」「リストを共有（読み込み用）」として別項目で提供されています。

---

## 11. `widgets/add_item_dialog.dart` — 商品追加・編集ダイアログ

構造が大きく拡張されています。従来の「追加」「編集」の単純な分岐に加え、**連続追加**・**未保存確認**・**カテゴリ選択**・**よく買うものへの同時登録**が追加されました。

### 連続追加フロー

```dart
Future<void> _submit({bool closeAfter = false}) async {
  ...
  if (item != null) {
    // 編集: 保存して即座に閉じる
  } else {
    final newItem = Item(...);
    await ref.read(itemProvider.notifier).addItem(newItem);
    ...
    if (!mounted) return;
    if (closeAfter) {
      Navigator.of(context).pop();
      return;
    }
    setState(() { _addedCount++; });
    _nameCtrl.value = TextEditingValue.empty;
    _priceCtrl.text = '0';
    _quantityCtrl.text = '1';
    _nameFocus.requestFocus();
    return;
  }
  ...
}
```

新規追加時、`closeAfter: false`（通常の「追加」ボタン押下）ではダイアログを閉じずに入力欄をクリアし、商品名フィールドに再フォーカスします。これにより連続して複数商品を素早く登録できます。`_addedCount` は「○件追加しました」という進捗表示に使われます。

### 未保存確認（`_handleClose`）

```dart
Future<void> _handleClose() async {
  if (_nameCtrl.text.trim().isEmpty) {
    Navigator.of(context).pop();
    return;
  }
  final action = await showDialog<_CloseAction>(
    ...
    actions: [
      TextButton(..., child: const Text('入力に戻る')),
      TextButton(..., child: const Text('破棄して閉じる')),
      FilledButton(..., child: const Text('追加して閉じる')),
    ],
  );
  ...
}
```

連続追加中に商品名を入力したまま「閉じる」を押した場合、入力内容を破棄していいか確認するダイアログを挟みます。`_CloseAction` という3値のenum（`cancel` / `discard` / `add`）で選択結果を受け取り、`add` の場合は `_submit(closeAfter: true)` を呼んで追加してから閉じます。名前が空欄の場合はこの確認をスキップして即座に閉じます。

### カテゴリドロップダウンと「新規カテゴリ」インライン作成

```dart
DropdownButtonFormField<int?>(
  initialValue: _selectedCategoryId,
  items: [
    const DropdownMenuItem<int?>(value: null, child: Text('なし')),
    ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
  ],
  onChanged: (v) => setState(() => _selectedCategoryId = v),
),
IconButton(
  icon: const Icon(Icons.add_circle_outline),
  onPressed: () => _showNewCategoryDialog(categories),
),
```

`DropdownButtonFormField` は `initialValue` プロパティを使用しています。これはこのプロジェクトが対象とするFlutterバージョン（3.33.0以降）で `value` が非推奨化され `initialValue` が正しいプロパティになったためで、プロジェクトルールにも明記された注意点です。カテゴリドロップダウンの隣に「＋」ボタンを配置し、ダイアログを閉じずにその場で新規カテゴリを作成→即選択できるようにしています（`categoryProvider.notifier.addCategory` が返すIDをそのまま `_selectedCategoryId` にセット）。この「新規カテゴリをインラインで追加する」UIパターンは `favorites_dialog.dart` の追加・編集ダイアログにも同一の実装が存在します（後述）。

### 「よく買うものに登録」チェックボックスと重複確認

```dart
if (_addToFavorites) {
  bool doInsert = true;
  final exists = await DatabaseHelper.instance.favoriteNameExists(name);
  if (exists && mounted) {
    doInsert = await showDialog<bool>(
      ...
      content: Text('「$name」はよく買うものに登録済みです。追加しますか？'),
      ...
    ) ?? false;
  }
  if (doInsert) {
    await DatabaseHelper.instance.insertFavorite(name, price, quantity, categoryId: _selectedCategoryId);
  }
}
```

商品追加と同時に「よく買うもの」へも登録できます。既に同名の「よく買うもの」が存在する場合は確認ダイアログを挟み、無条件の重複登録を避けています。この「重複確認ダイアログ」パターンは `shopping_list_screen.dart` の `_buildCategorySections`（`onAddToFavoritesFor`）にも、購入済みセクションの `onAddToFavorites` コールバックにも、ほぼ同一のコードとして存在します。プロジェクトルールに「`await` を含む非同期処理を修正・追加する際は、同一パターンが複数ファイルに存在しないか確認し、全箇所を同時に修正する」と明記されているのは、まさにこの重複実装を指しています。将来この確認フローの仕様を変更する場合は、最低でもこの3箇所（`add_item_dialog.dart` と `shopping_list_screen.dart` 内の2箇所）を同時に修正する必要があります。

---

## 12. `widgets/favorites_dialog.dart` — よく買うもの管理

大幅に拡張されています。検索・並べ替え・カテゴリ対応・全選択/全解除・登録済み確認が追加されました。

### 検索とフィルタリング

```dart
List<Map<String, dynamic>> get _filteredFavorites =>
    _searchText.isEmpty
        ? _favorites
        : _favorites.where((f) => (f['name'] as String)
            .toLowerCase()
            .contains(_searchText.toLowerCase())).toList();
```

検索文字列が空のときは全件、それ以外は部分一致（大文字小文字を無視）でフィルタします。検索中は並べ替え可能な `ReorderableListView.builder` ではなく、通常の `ListView.builder`（`_searchText.isEmpty` の分岐先）が使われる点が重要な設計判断です。フィルタされた部分集合に対して並べ替えを行うと、`sortOrder` の意味が「全件中の順位」なのか「フィルタ結果内の順位」なのか曖昧になるため、検索中は並べ替えUIそのものを提供しないことで曖昧さを回避しています。

### 全選択/全解除

```dart
bool get _allSelected =>
    _filteredFavorites.isNotEmpty &&
    _filteredFavorites.every((f) => _selectedIds.contains(f['id'] as int));

void _toggleSelectAll() {
  setState(() {
    if (_allSelected) {
      for (final f in _filteredFavorites) { _selectedIds.remove(f['id'] as int); }
    } else {
      for (final f in _filteredFavorites) { _selectedIds.add(f['id'] as int); }
    }
  });
}
```

`_allSelected` は「現在表示されている（検索フィルタ後の）項目がすべて選択済みか」を判定します。全選択/全解除ボタンは検索結果に対してのみ作用し、検索で絞り込まれていない他の項目の選択状態には影響しません。

### インラインUndoバナー（変更なし）

`AlertDialog` のモーダルバリアがSnackBarへのタップを吸収してしまうため、ダイアログ内でのUndoは `Timer(const Duration(seconds: 5), ...)` で自動消去するインラインバナーとして実装されています。これは前バージョンと同じ設計です。

### `_AddFavoriteDialog` / `_EditFavoriteDialog` — カテゴリ選択の重複実装

「よく買うもの」の新規登録・編集ダイアログにも、`add_item_dialog.dart` と同じ「カテゴリドロップダウン＋新規カテゴリのインライン追加」UIが実装されています。

```dart
Future<void> _showNewCategoryDialog(List<Category> categories) async {
  String newName = '';
  final confirmed = await showDialog<bool>(...);
  if (confirmed != true || newName.isEmpty || !mounted) return;
  final id = await ref.read(categoryProvider.notifier).addCategory(newName);
  setState(() => _selectedCategoryId = id);
}
```

このメソッドは `add_item_dialog.dart`・`_AddFavoriteDialog`・`_EditFavoriteDialog` の3箇所にほぼ同一のコードとして存在します。共通ウィジェット化されていない点は、今後リファクタリングの余地がある箇所として認識しておくべきです（ただしプロジェクトルールの「共通コンポーネントを既存の使用例を確認せずに使わない」という方針もあるため、共通化するには既存3箇所の使用パターンを慎重に確認する必要があります）。

`_AddFavoriteDialog` では商品名入力に `ItemNameField` を使用し、`candidateNames` として**既存の「よく買うもの」の名前一覧**を渡しています（後述の「候補表示機能」を参照）。これはリスト画面の商品追加で使われる `candidateNames`（現在のリスト内の商品名）とは異なるデータソースです。

---

## 13. `widgets/category_management_dialog.dart` — カテゴリ管理ダイアログ（新規）

```dart
Future<void> showCategoryManagementDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _CategoryManagementDialog(),
  );
}

class _CategoryManagementDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).value ?? [];
    return AlertDialog(
      ...
      content: ListView.builder(
        shrinkWrap: true,
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          return ListTile(
            title: Text(cat.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(categoryProvider.notifier).deleteCategory(cat.id!);
              },
            ),
          );
        },
      ),
      ...
    );
  }
}
```

`ConsumerWidget`（`StatefulWidget` ではなく）として実装されているのが特徴です。ダイアログ自身が独自のローカル状態を持たず、表示内容がすべて `categoryProvider` の監視結果に依存するため、`StatelessWidget` に相当する `ConsumerWidget` で十分という判断です。カテゴリの削除は確認ダイアログを挟まずに即実行されます（商品側の `categoryId` はDB層のトランザクションで自動的に `null` に戻るため、データが失われるわけではなく「未分類」に戻るだけであることが、確認省略の設計根拠と考えられます）。

トップレベル関数 `showCategoryManagementDialog` としてラップして公開している点は、`add_item_dialog.dart` の `showAddItemDialog` と同じ「呼び出し側から `showDialog` の詳細を隠蔽する」パターンです。

---

## 14. `widgets/item_tile.dart` — 商品リスト行

`Dismissible` によるスワイプ削除の実装（`key` に `isChecked` を含める設計）は変更ありませんが、長押し時の挙動が変わりました。

### 長押しメニューのボトムシート化

```dart
onLongPress: (onMoveToTab == null && onAddToFavorites == null)
    ? null
    : () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onMoveToTab != null)
                ListTile(title: const Text('別タブに移動'), onTap: () => Navigator.pop(context, 'move')),
              if (onAddToFavorites != null)
                ListTile(title: const Text('よく買うものに登録'), onTap: () => Navigator.pop(context, 'favorite')),
              ListTile(title: const Text('キャンセル'), onTap: () => Navigator.pop(context)),
            ],
          ),
        );
        if (result == 'move') onMoveToTab?.call();
        if (result == 'favorite') onAddToFavorites?.call();
      },
```

以前は長押し＝別リストへの移動、という単一の操作でしたが、「よく買うものへの登録」がここに統合されたため、長押しで `showModalBottomSheet` を開いて操作を選択させる方式に変わりました。`onMoveToTab` / `onAddToFavorites` はどちらも `null` を許容する `VoidCallback?` で、コールバックが渡されなかった項目（例えば購入済みセクションでは移動元・移動先の概念が薄いため）はボトムシートの選択肢から自動的に除外されます。両方 `null` の場合は `onLongPress` 自体が `null` になり、長押しジェスチャーが無効化されます。

---

## 15. `widgets/list_section.dart` — セクション

```dart
ReorderableListView(
  buildDefaultDragHandles: false,  // デフォルトハンドルを無効化
  physics: const NeverScrollableScrollPhysics(),  // 親のListViewにスクロールを委譲
  onReorderItem: (oldIndex, newIndex) async { ... },
  children: [for (int i = 0; i < items.length; i++) ItemTile(...)],
)
```

コアロジックは変更ありませんが、`onMoveToTab` / `onAddToFavorites` の2つのコールバックを `ItemTile` に橋渡しするパラメータが追加されています。`ListSection` はカテゴリ別セクションと未分類セクション、購入済みセクションのいずれの表示にも使い回される汎用コンポーネントとして、`title` にカテゴリ名や「未購入」「カテゴリなし」「購入済」を渡すことで表示を切り替えます。

---

## 16. `widgets/list_tab_bar.dart` — タブバー（変更なし）

```dart
Tab(
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPress: () => onRenameTab?.call(list),
    child: Text(list.name),
  ),
)
```

`GestureDetector` を `Tab` の**内側**に配置する設計は変更ありません。外側に置くと `TabBar` が各タブに被せる `InkWell` とジェスチャーアリーナで競合し、長押しが動作しなくなります（プロジェクトルールに明記されている既知の落とし穴）。

---

## 17. `widgets/list_management_buttons.dart` — リスト追加・複製ボタン（新規）

```dart
class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onDuplicateList;

  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: onAddList, icon: const Icon(Icons.add), tooltip: 'リストを追加'),
        IconButton(onPressed: onDuplicateList, icon: const Icon(Icons.copy_outlined), tooltip: 'リストを複製'),
      ],
    );
  }
}
```

AppBarの `actions` に並ぶボタン群のうち「追加」「複製」の2つを1つのWidgetに切り出したものです。単純な `StatelessWidget` で、コールバックを2つ受け取るだけの薄いラッパーですが、`shopping_list_screen.dart` のbuildメソッドの見通しを良くする目的で分離されています。

---

## 18. `widgets/fields/item_name_field.dart` — 商品名入力と候補表示

**重要な注意：** このWidgetは過去に存在した「入力履歴（`item_history` テーブル）ベースのオートコンプリート」とは別物です。履歴ベースの機能は2026-06-29に完全に削除されており、現在の `ItemNameField` は呼び出し元から渡された `candidateNames`（現在のリスト内の商品名、または「よく買うもの」の登録名）を候補として表示するだけの、DBに依存しないシンプルな実装です。

```dart
void _updateSuggestions(String text) {
  // 空欄（フォーカス取得直後・連続追加でのクリア直後）では候補を出さない。
  // 入力文字がある場合のみ履歴を絞り込んで表示する。
  if (text.isEmpty) {
    setState(() => _suggestions = []);
    return;
  }
  final filtered = widget.candidateNames
      .where((n) => n.toLowerCase().contains(text.toLowerCase()))
      .toList();
  setState(() => _suggestions = filtered.take(8).toList());
}
```

**空文字時は候補を表示しない** のが仕様上の要点です。前バージョン（履歴ベース時代）は空文字フォーカス時に全履歴を表示していましたが、`add_item_dialog.dart` の連続追加フロー（追加後に入力欄をクリアして即座に再フォーカスする）と組み合わせると、クリア直後に大量の候補リストが価格・数量欄の上に覆いかぶさってしまう問題がありました。プロジェクトルールに明記された「連続入力UIで入力欄をクリアして再フォーカスする設計では、サジェスト/オートコンプリートは『空文字時は非表示・入力時のみ表示』を既定とする」という知見がこの実装に反映されています。

`candidateNames` は呼び出し元ごとに異なるデータソースが渡されます。

| 呼び出し元 | `candidateNames` の中身 |
|---|---|
| `shopping_list_screen.dart` → `showAddItemDialog` | 現在表示中のリストに含まれる商品名（`itemAsync` から `map((i) => i.name)`） |
| `favorites_dialog.dart` の `_AddFavoriteDialog` | 既存の「よく買うもの」の登録名一覧 |

このように候補の母集団は「今使っている画面の文脈」に応じて切り替わりますが、`ItemNameField` 自体は候補の出所を意識しない汎用コンポーネントとして設計されています。

---

## 19. `widgets/fields/price_field.dart` / `quantity_field.dart` / `memo_field.dart` — 入力フィールド群

いずれも `StatelessWidget` で `TextFormField` を薄くラップしただけの単純なコンポーネントです。

```dart
// price_field.dart / quantity_field.dart 共通のパターン
TextFormField(
  controller: controller,
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
  ...
)
```

`inputFormatters: [FilteringTextInputFormatter.digitsOnly]` でソフトキーボードの入力段階から数字以外を弾いています。`onTap` でタップ時に全選択状態にする実装は、初期値（`0` や `1`）を毎回手動で消さずに上書き入力できるようにするための細かなUX配慮です。`PriceField` には0以上の整数であることを検証する `validator` がありますが、`QuantityField` には数値以外の文字を防ぐ `inputFormatters` はあるものの `validator` は実装されていません（数量の下限チェックは呼び出し元、たとえば `favorites_dialog.dart` の `_AddFavoriteDialog` のフォームで別途 `1以上の整数を入力してください` という検証が行われています）。`MemoField` は `maxLines: 3` の複数行テキストで、バリデーションを持ちません（空でも許可）。

---

## 20. `widgets/ad_banner.dart` — アダプティブバナー広告（変更なし）

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (_ad == null) { _loadAd(); }
}
```

`initState` ではなく `didChangeDependencies` で `MediaQuery` を使った広告読み込みを行う設計は変更ありません。固定サイズ（`AdSize.banner`）ではなく画面幅に応じたアダプティブバナーを使用しています。

---

## 21. `widgets/upgrade_dialog.dart` — 課金ダイアログ（変更なし）

```dart
FilledButton.icon(
  onPressed: () async {
    Navigator.pop(context);  // 先にダイアログを閉じてからPlayシートを表示
    final error = await ref.read(purchaseProvider.notifier).purchase();
    ...
  },
)
```

`Navigator.pop` をPlay Storeシート表示より前に呼ぶ設計は変更ありません。

---

## 22. `widgets/empty_state_view.dart` / `total_summary.dart`

`empty_state_view.dart` はリストが空の場合に表示される `StatelessWidget` で変更ありません。`total_summary.dart` は未購入・購入済みそれぞれの合計金額を表示するコンポーネントで、`price × quantity` の合計を `fold` で計算するロジックも変更ありません。カテゴリ別セクション表示の追加後も、合計金額はカテゴリを横断した「未購入全体」「購入済全体」のまま据え置かれています（カテゴリごとの小計は現状実装されていません）。

---

## 23. `widgets/help_dialog.dart` — 使い方ダイアログ

新機能追加のたびに `_HelpItem` を追加・更新する運用ルールがあり（プロジェクトルール「機能を追加・変更・削除したときは必ず `lib/widgets/help_dialog.dart` を同時に更新する」）、現在は以下の項目が並んでいます：商品の追加（連続入力対応）・編集・削除・購入済み一括削除・並び替え・リスト名変更・リスト追加・リスト削除・別リストへ移動、商品名の候補表示、リストの複製、よく買うものからの追加、テキストで共有、リストを共有（読み込み用）、バックアップ、読み込み（バックアップ／共有リスト）、カテゴリを管理、広告を非表示にする。

過去に存在した「履歴から登録」（`history_select_dialog.dart` に対応する項目）は、機能自体の削除に伴い `_HelpItem` からも取り除かれています。

---

## データフロー全体像

```
ユーザー操作
  ↓
ShoppingListScreen（UI・イベントハンドリング）
  ↓
ItemNotifier.addItem / toggleCheck / reorderUncheckedItems / moveItemToList など
CategoryNotifier.addCategory / deleteCategory
  ↓
DatabaseHelper.insertItem / updateItem / insertCategory / importData など（SQLite読み書き）
  ↓
state = AsyncData(refreshed) でUI再描画
```

バックアップ・共有機能だけは異なる経路を通ります。

```
ユーザー操作（バックアップ／共有）
  ↓
ShoppingListScreen._exportBackup / _importBackup / _shareListFile
  ↓
BackupService（JSON構築・ファイルI/O・共有シート起動）
  ↓
DatabaseHelper.importData（インポート時のみ、トランザクションでマージ）
  ↓
loadLists() / ref.invalidate(categoryProvider) で画面を再構築
```

楽観的更新（`reorderUncheckedItems`）だけが DB書き込み前に state を更新する例外である点は変わりません。
