# HKL-001 買い物リストアプリ 全コード解説

## アーキテクチャ全体像

```
lib/
├── main.dart                     # エントリーポイント
├── models/
│   ├── item.dart                 # 商品データモデル
│   └── shopping_list.dart        # リストデータモデル
├── database/
│   └── database_helper.dart      # SQLite永続化層
├── providers/
│   ├── item_provider.dart        # 商品の状態管理（Riverpod）
│   └── purchase_provider.dart    # 課金状態管理（Riverpod）
├── screens/
│   └── shopping_list_screen.dart # メイン画面
└── widgets/
    ├── add_item_dialog.dart       # 商品追加・編集ダイアログ
    ├── ad_banner.dart             # バナー広告
    ├── empty_state_view.dart      # 空リスト表示
    ├── favorites_dialog.dart      # よく買うもの管理
    ├── help_dialog.dart           # 使い方ダイアログ
    ├── history_select_dialog.dart # 履歴から登録
    ├── item_tile.dart             # 商品リスト行
    ├── list_management_buttons.dart # AppBarボタン群
    ├── list_section.dart          # 未購入/購入済みセクション
    ├── list_tab_bar.dart          # タブバー
    ├── total_summary.dart         # 合計金額表示
    ├── upgrade_dialog.dart        # 課金ダイアログ
    └── fields/
        ├── item_name_field.dart   # 商品名入力（オートコンプリート）
        ├── price_field.dart       # 価格入力
        ├── quantity_field.dart    # 数量入力
        └── memo_field.dart        # メモ入力
```

状態管理は **Riverpod（AsyncNotifier）**、永続化は **sqflite（SQLite）** を採用しています。UI と状態とデータベースが明確に分離された、シンプルな三層構造です。

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

`MyApp` ではテーマを `deepPurple` × `useMaterial3: true` で設定し、`themeMode: ThemeMode.system` によりOSのダーク/ライト設定に自動追従します。

---

## 2. `models/item.dart` — 商品データモデル

アプリの中心となるデータクラスです。

```dart
class Item {
  final String name;    // 商品名
  final int price;      // 税込単価（0以上の整数）
  final bool isChecked; // 購入済みフラグ
  final int? id;        // DBのPRIMARY KEY（新規時はnull）
  final int createdAt;  // 作成時刻（ミリ秒）
  final int sortOrder;  // 表示順（小さいほど上）
  final int quantity;   // 数量（デフォルト1）
  final String memo;    // メモ（編集時のみ表示）
  final int listId;     // 所属するリストのID
}
```

設計上の重要な点として、`Item` は **イミュータブル**（全フィールドが `final`）です。変更は `copyWith()` で新しいインスタンスを生成します。これによりRiverpodの状態管理と相性が良くなり、意図しない変更によるバグを防いでいます。

`toMap()` / `fromMap()` は SQLiteとのシリアライズ・デシリアライズを担います。`isChecked` は SQLite が bool 型を持たないため `INTEGER 0/1` に変換しています。

`createdAt` はコンストラクタで `createdAt ?? DateTime.now().millisecondsSinceEpoch` とデフォルト値を設定しており、省略した場合は現在時刻が自動で入ります。

---

## 3. `models/shopping_list.dart` — リストモデル

```dart
class ShoppingList {
  final int? id;
  final String name;
  final int createdAt;
}
```

`Item` と同じ構造の軽量なモデルです。`lists` テーブルの行を表します。`toMap()` / `fromMap()` のみ実装で、`copyWith()` は持ちません（リスト名変更はDBに直接SQLで対応しているため不要）。

---

## 4. `database/database_helper.dart` — SQLite永続化層

### シングルトンパターン

```dart
static final DatabaseHelper instance = DatabaseHelper._init();
static Database? _database;

DatabaseHelper._init(); // プライベートコンストラクタ

Future<Database> get database async {
  if (_database != null) return _database!;
  _database = await _initDB('shopping.db');
  return _database!;
}
```

アプリ全体でDBインスタンスを一つだけ保持する**シングルトン**です。`get database` は遅延初期化（Lazy Initialization）になっており、初回アクセス時のみ `_initDB` を呼びます。

### テーブル構成（version 6）

| テーブル名 | 役割 |
|---|---|
| `items` | 買い物商品。`listId` でリストに紐付け |
| `item_history` | 商品名の入力履歴（オートコンプリート用） |
| `lists` | 複数リストの管理 |
| `favorites` | よく買うもの（独立したマスタデータ） |

### マイグレーション戦略

`_onUpgrade` が旧バージョンDBを新バージョンに移行します。注目すべき点が2つあります。

**`CREATE TABLE IF NOT EXISTS` による冪等性：** テーブル追加は何度実行しても安全なよう `IF NOT EXISTS` を付けています。

**`taxRate` カラム削除（v4→v5）のテーブル再作成パターン：**

```dart
if (oldVersion < 5) {
  await db.execute('CREATE TABLE items_new(...)');
  await db.execute('INSERT INTO items_new(...) SELECT ... FROM items');
  await db.execute('DROP TABLE items');
  await db.execute('ALTER TABLE items_new RENAME TO items');
}
```

Android の SQLite は `ALTER TABLE DROP COLUMN` に対応していないため、新テーブル作成→データコピー→旧テーブル削除→リネームの4ステップで実現しています。これはプロジェクトルールにも明記された重要な知見です。

### `insertItem` と `insertItemWithId` の使い分け

```dart
// 通常追加: IDを取り除いてAutoIncrementに任せる
Future<int> insertItem(Item item) async {
  final map = item.toMap();
  map.remove('id'); // ←ここ重要
  return await db.insert('items', map);
}

// Undo用復元: 元のIDを指定して完全復元
Future<void> insertItemWithId(Item item) async {
  await db.insert('items', item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
}
```

通常追加では `map.remove('id')` でnullのIDフィールドを取り除き、DBの `AUTOINCREMENT` にIDを割り当てさせます。Undo復元では元のIDを保持したまま `ConflictAlgorithm.replace` で再挿入することで、並び順も含めて完全に元の状態を再現します。

### `updateSortOrders` — バッチトランザクション

```dart
Future<void> updateSortOrders(List<Item> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (final item in items) {
      batch.update('items', {'sortOrder': item.sortOrder},
          where: 'id = ?', whereArgs: [item.id]);
    }
    await batch.commit(noResult: true);
  });
}
```

並び替え時に複数行の `sortOrder` を一括更新します。`transaction` + `batch` で全更新をアトミックに実行し、途中失敗でも部分更新にならないようにしています。`noResult: true` は戻り値を受け取らないことでメモリを節約します。

### `reorderFavorites`

`favorites` テーブルの並び順更新。`orderedIds`（新しい順のID配列）を受け取り、インデックス順に `sortOrder` を 0, 1, 2, … と更新します。

### `addFavoriteItemsToList`

```dart
int nextOrder = ((maxResult.first['maxOrder'] as int?) ?? -1) + 1;
for (final favId in favoriteIds) { ... nextOrder++ }
```

既存アイテムの末尾から連番で `sortOrder` を割り当てながら、よく買うものを現在のリストにコピーします。全操作を1つのトランザクションで包み、追加途中でエラーが起きても中途半端な状態にならない設計です。

---

## 5. `providers/item_provider.dart` — 商品の状態管理

### AsyncNotifier

```dart
class ItemNotifier extends AsyncNotifier<List<Item>> {
  int currentListId = 1;

  @override
  Future<List<Item>> build() async {
    return DatabaseHelper.instance.getItemsByListId(currentListId);
  }
}
```

Riverpod 3.x の `AsyncNotifier<T>` を継承しています。`build()` が初期状態を返すファクトリメソッドです。状態は `AsyncValue<List<Item>>` 型で、`AsyncLoading` / `AsyncData` / `AsyncError` の3状態を自動管理します。

### 楽観的更新（Optimistic Update）

`reorderUncheckedItems` では、DBへの書き込み完了を待たずに先にUIを更新しています。

```dart
Future<void> reorderUncheckedItems(int oldIndex, int newIndex) async {
  // ...並び替え計算...
  state = AsyncData(updated);             // UIを先に更新（即時フィードバック）
  await DatabaseHelper.instance.updateSortOrders(updated);  // 後でDB書き込み
}
```

ドラッグ操作のレスポンスが重要なため、この操作だけ楽観的更新を採用しています。他の操作（`addItem`, `toggleCheck` など）はDB書き込み→再取得→state更新の順で確実性を優先しています。

### `onReorderItem` の仕様と `newIndex` 補正不要の理由

```dart
// onReorderItem は removal 後の挿入インデックスを返すため、
// onReorder と異なり newIndex-- の補正は不要
final movedItem = unchecked.removeAt(oldIndex);
unchecked.insert(newIndex, movedItem);
```

Flutter 3.44.0 から追加された `onReorderItem` は `ReorderableListView` の旧 `onReorder` と異なり、要素を取り除いた後のインデックスを返すため、`if (newIndex > oldIndex) newIndex--` の補正が不要です。

### Undo対応の `deleteItemById`

```dart
Future<Item?> deleteItemById(int id) async {
  // 削除前にアイテムを取得してUndoのために返す
  Item? deletedItem = current.firstWhere(...);
  await DatabaseHelper.instance.deleteItem(id);
  ...
  return deletedItem;
}
```

削除する前にデータをメモリに退避しておき、呼び出し元（画面）にそのまま返します。画面側で5秒間保持し、Undoが押されたら `restoreItemWithOrder` で元のIDと `sortOrder` を保った状態で復元します。

---

## 6. `providers/purchase_provider.dart` — 課金状態管理

### 起動時の3ステップ初期化

```dart
Future<bool> build() async {
  // ①SharedPreferencesからキャッシュを即時読み込み
  final cached = prefs.getBool(_kPrefKey) ?? false;

  // ②購入ストリームを購読（dispose時にキャンセル）
  final sub = InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdate);
  ref.onDispose(sub.cancel);

  // ③キャッシュがfalseのときだけPlay Storeで照合
  if (!cached) {
    await InAppPurchase.instance.restorePurchases();
  }

  return cached;
}
```

起動速度と正確性のバランスを取った設計です。キャッシュがあれば即 `true` を返して広告を非表示にし（快速起動）、未購入の場合のみPlay Storeに問い合わせます。購入完了はストリーム経由で非同期に受け取り、`_persist` で SharedPreferences に保存してから `state` を更新します。

`ref.onDispose(sub.cancel)` でプロバイダーが破棄されるタイミングでストリーム購読を自動キャンセルします（メモリリーク防止）。

---

## 7. `screens/shopping_list_screen.dart` — メイン画面（809行）

アプリの中核で、ほぼすべての操作フローがここに集約されています。

### ミックスイン `TickerProviderStateMixin`

```dart
class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen>
    with TickerProviderStateMixin {
```

`TabController` のアニメーションに必要な `vsync` を提供するためにミックスインしています。`ConsumerState` はRiverpodのプロバイダーを `ref` 経由で読める状態クラスです。

### `loadLists` — タブコントローラー再構築

リスト一覧が変わるたびに `TabController` を作り直します。

```dart
oldController?.removeListener(_handleTabChange);
oldController?.dispose();
_tabController = TabController(length: data.length, vsync: this, initialIndex: ...);
_tabController?.addListener(_handleTabChange);
```

古いコントローラーのリスナーを外してから `dispose` し、新しいものを生成してリスナーを再登録します。メモリリークを防ぐために `dispose` 前の `removeListener` が重要です。

### `_handleTabChange` — タブ切り替えの競合防止

```dart
Future<void> _handleTabChange() async {
  if (_isChangingTab) return;         // 再入防止
  if (_tabController!.indexIsChanging) return;  // アニメーション中は無視
  _isChangingTab = true;
  try {
    await changeList(selectedList.id!);
  } finally {
    _isChangingTab = false;
  }
}
```

`TabController` のリスナーは複数回発火することがあるため、`_isChangingTab` フラグと `indexIsChanging` チェックで二重実行を防いでいます。`try/finally` でフラグを確実にリセットします。

### 広告非表示の判定

```dart
const kHideAds = bool.fromEnvironment('HIDE_ADS');
final isAdFree = kHideAds || ref.watch(purchaseProvider).maybeWhen(
  data: (v) => v,
  orElse: () => false,
);
```

`bool.fromEnvironment('HIDE_ADS')` はビルド時の環境変数で、開発時に `--dart-define=HIDE_ADS=true` を渡すと広告を完全に非表示にできます。`purchaseProvider` が未ロード（`AsyncLoading`）の間は `orElse: () => false` で広告を表示します。

### `_shareCurrentList` — テキスト共有

```dart
buf.writeln('【${currentList.name}】');
for (final item in unchecked) {
  final qty = item.quantity > 1 ? ' ×${item.quantity}' : '';
  final price = item.price > 0 ? '  ¥${fmt.format(item.price * item.quantity)}' : '';
  buf.writeln('□ ${item.name}$qty$price$memo');
}
```

リストをテキスト形式に整形して `Share.share()` に渡します。数量が1の場合は表示省略、価格が0の場合も省略するなど、不要な情報を出力しない配慮があります。

### `_SingleFieldDialog` — 汎用1フィールドダイアログ

リスト追加・リネームで共用される内部Widgetです。`onSubmit` コールバックを受け取る設計により、同じUIで異なる処理を実行できます。

---

## 8. `widgets/favorites_dialog.dart` — よく買うもの（472行）

### インラインUndoバナー

```dart
if (_pendingUndoFavorite != null)
  Material(
    color: Colors.grey[850],
    child: Row(
      children: [
        Text('削除しました', ...),
        TextButton(
          onPressed: () async {
            _undoTimer?.cancel();
            await DatabaseHelper.instance.restoreFavorite(...);
          },
          ...
        ),
      ],
    ),
  ),
```

`AlertDialog` のモーダルバリアが `SnackBar` へのタップを吸収してしまうため、ダイアログ内でのUndoはSnackBarではなくダイアログ内インラインバナーで実装されています。`Timer(const Duration(seconds: 5), ...)` で5秒後に自動消去します。

### `onReorderItem` による並び替え

```dart
Future<void> _onReorderItem(int oldIndex, int newIndex) async {
  final list = [..._favorites];
  final item = list.removeAt(oldIndex);
  list.insert(newIndex, item);
  setState(() => _favorites = list);  // 楽観的更新
  try {
    await DatabaseHelper.instance.reorderFavorites(
      list.map((f) => f['id'] as int).toList(),
    );
  } catch (_) {
    await _load();  // 失敗時はDBから再取得してロールバック
  }
}
```

楽観的更新後、DB書き込みが失敗した場合は `_load()` でロールバックします。

### `ConstrainedBox` + `shrinkWrap` の組み合わせ

```dart
ConstrainedBox(
  constraints: const BoxConstraints(maxHeight: 320),
  child: ReorderableListView.builder(
    shrinkWrap: true,
    ...
  ),
)
```

`AlertDialog` 内の `ReorderableListView` は高さが無制限になると画面外にはみ出すため、`maxHeight: 320` で上限を設けています。`content` に `SizedBox(width: double.maxFinite)` を置くことで横幅の縮小を防いでいます。

---

## 9. `widgets/item_tile.dart` — 商品リスト行

```dart
Dismissible(
  key: ValueKey('${item.id}_${item.isChecked}'),
  direction: DismissDirection.endToStart,
  ...
  child: ListTile(
    leading: Checkbox(...),
    onLongPress: onMoveToTab,    // 別リストへ移動
    trailing: reorderIndex != null
        ? ReorderableDragStartListener(index: reorderIndex!, child: Icon(...))
        : null,                  // 購入済みはハンドル非表示
  ),
)
```

`Dismissible` の `key` に `isChecked` を含めることで、チェック状態が変わったときに `Dismissible` ウィジェットが再生成されます（スワイプ中にチェック状態が変わっても表示が正しくリセットされます）。

`reorderIndex` が `null` の場合（購入済みセクション）はドラッグハンドルを表示しません。未購入セクションのみ並び替え可能という仕様を、`trailing` の出し分けで表現しています。

---

## 10. `widgets/list_section.dart` — セクション

```dart
if (reorderable)
  ReorderableListView(
    buildDefaultDragHandles: false,  // デフォルトハンドルを無効化
    physics: const NeverScrollableScrollPhysics(),  // 親のListViewにスクロールを委譲
    onReorderItem: (oldIndex, newIndex) async { ... },
    children: [for (int i = 0; i < items.length; i++) ItemTile(...)],
  )
else
  ...items.map((item) => ItemTile(...)),
```

`buildDefaultDragHandles: false` で自動生成されるハンドルを無効にし、`ItemTile` 内の `ReorderableDragStartListener` を使って明示的にハンドルの位置を制御しています。`NeverScrollableScrollPhysics` で `ReorderableListView` 自身のスクロールを無効化し、外側の `ListView` にスクロールを委譲しています。

---

## 11. `widgets/list_tab_bar.dart` — タブバー

```dart
Tab(
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPress: () => onRenameTab?.call(list),
    child: Text(list.name),
  ),
)
```

`GestureDetector` を `Tab` の**内側**に配置しているのが重要です。外側に置くと `TabBar` が各タブに被せる `InkWell` とジェスチャーアリーナで競合し、長押しが動作しなくなります（プロジェクトルールに明記されている既知の落とし穴）。

`PreferredSizeWidget` を `implements` することで、`AppBar.bottom` にそのまま渡せます。

---

## 12. `widgets/add_item_dialog.dart` — 商品追加・編集ダイアログ

### 追加と編集の分岐

```dart
if (item != null) {
  // 編集: copyWithで変更差分だけ更新
  final updatedItem = item.copyWith(name: name, price: price, ...);
  await ref.read(itemProvider.notifier).updateItem(updatedItem);
  if (name != item.name) { upsertHistory(name); }  // 名前変更時のみ履歴更新
} else {
  // 追加: 新規Itemを生成
  await ref.read(itemProvider.notifier).addItem(newItem);
  await upsertHistory(name);
}
```

`item` パラメータの有無で追加/編集を判定します。編集時はメモフィールドが表示されますが追加時は表示されません。`isEdit` フラグを `final isEdit = widget.item != null` と1か所で計算しておきUIの切り替えに使っています。

---

## 13. `widgets/fields/item_name_field.dart` — オートコンプリート

```dart
void _onFocusChange() {
  if (_focusNode.hasFocus) {
    _updateSuggestions(widget.controller.text);
  } else {
    setState(() => _suggestions = []);  // フォーカスを外したら候補を消す
  }
}

void _updateSuggestions(String text) {
  final filtered = text.isEmpty
      ? widget.historyNames          // 空文字なら全履歴を表示
      : widget.historyNames.where((n) => n.toLowerCase().contains(text.toLowerCase())).toList();
  setState(() => _suggestions = filtered.take(8).toList());  // 最大8件
}
```

`FocusNode` のリスナーでフォーカスの有無を監視し、候補リストの表示・非表示を制御します。入力のたびに `_updateSuggestions` を呼んで候補をフィルタリングします。大文字・小文字を区別しない部分一致検索で、表示は最大8件に絞っています。

---

## 14. `widgets/ad_banner.dart` — アダプティブバナー広告

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (_ad == null) { _loadAd(); }
}

Future<void> _loadAd() async {
  final width = MediaQuery.of(context).size.width.truncate();
  final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
  ...
}
```

`initState` ではなく `didChangeDependencies` で広告を読み込んでいます。これは `MediaQuery` を使うために `context` が必要で、`context` に依存するものは `initState` ではなく `didChangeDependencies` 以降で使うべきというFlutterの規約に従っています（プロジェクトルールに明記）。

固定サイズ（`AdSize.banner`）ではなく、画面幅に応じてサイズが決まる**アダプティブバナー**を使っています。

---

## 15. `widgets/upgrade_dialog.dart` — 課金ダイアログ

```dart
FilledButton.icon(
  onPressed: () async {
    Navigator.pop(context);  // 先にダイアログを閉じてからPlayシートを表示
    final error = await ref.read(purchaseProvider.notifier).purchase();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  },
)
```

`Navigator.pop` をPlay Storeシート表示より**前**に呼んでいます。ダイアログとPlay Storeシートが重なると表示が崩れるためです。購入結果は `purchaseProvider` のストリームが自動的に受け取るため、ここでは `purchase()` からのエラーのみをSnackBarで表示します。

---

## 16. `widgets/history_select_dialog.dart` — 履歴から登録

```dart
LimitedBox(
  maxHeight: 320,
  child: ListView.builder(shrinkWrap: true, ...),
)
```

`CheckboxListTile` を並べたシンプルな複数選択ダイアログです。`onRegister` コールバックで選択した名前リストを親に返します。

---

## データフロー全体像

```
ユーザー操作
  ↓
ShoppingListScreen（UI・イベントハンドリング）
  ↓
ItemNotifier.addItem / toggleCheck / reorderUncheckedItems など
  ↓
DatabaseHelper.insertItem / updateItem など（SQLite読み書き）
  ↓
state = AsyncData(refreshed) でUI再描画
```

基本的にすべての操作がこのフローを辿ります。楽観的更新（`reorderUncheckedItems`）だけが DB書き込み前に state を更新する例外です。
