# リスト（タブ）並び替え機能 設計書

**作成日：2026-08-01**
**対象バージョン：** spec rev9.0 の次リビジョン（rev9.1想定）に追加
**ステータス：設計承認済み・未実装**（マスターの指示により、実装計画（writing-plans）の作成はまだ行っていない。実装に進む際は改めて指示を受けること）。2026-10-21 に版数・行番号のみ補正（設計内容は変更なし）。

---

## 1. 背景・目的

### 1.1 背景

UI表記は直近のコミット（`6a0ffa1`）で「タブ」から「リスト」へ統一されたが、内部実装では複数の買い物リストを `TabBar`（`lib/widgets/list_tab_bar.dart`）で切り替える構造のまま変わっていない。

現状、リストの並び順は `lib/database/database_helper.dart` の `getLists()`（304〜310行目）で `orderBy: 'createdAt ASC'` に固定されており、ユーザーがリストの並び順を変更する手段が存在しない。

一方、商品アイテム（`items`）・よく買うもの（`favorites`）・カテゴリ（`categories`）は、いずれもテーブルに `sortOrder` カラムを持ち、`ReorderableListView` 系ウィジェットによるドラッグ並び替えが実装済みである。本設計は、この既存パターンをリスト（`lists`）にも適用し、複数リストの並び順をユーザーが変更できるようにする。

### 1.2 目的

- `lists` テーブルに `sortOrder` カラムを追加し、リストの並び順を永続化する
- AppBar に「並び替えモード」トグルを追加し、モードON時のみリストをドラッグで並び替えられるようにする
- 既存の商品・よく買うもの・カテゴリの並び替え実装パターン（DB設計・楽観的UI更新・エラーハンドリング）を踏襲し、実装の一貫性を保つ

---

## 2. アーキテクチャ

### 2.1 現状の構成

```
ShoppingListScreen（ConsumerStatefulWidget）
 └─ _ShoppingListScreenState（ローカル State）
      ├─ shoppingLists: List<ShoppingList>   ← ローカル State フィールド（Riverpod化されていない）
      ├─ _tabController: TabController?      ← shoppingLists のインデックスに対応
      ├─ currentListId: int                  ← 現在選択中のリストID
      │
      ├─ AppBar.actions
      │    └─ ListManagementButtons（「＋」「複製」ボタン）
      ├─ AppBar.bottom
      │    └─ ListTabBar（TabBarをラップ。タブ名長押しでリネーム）
      └─ body
           └─ itemProvider（Riverpod AsyncNotifier）を watch
                └─ DatabaseHelper 経由で currentListId の商品一覧を取得・表示
```

重要な前提として、本アプリはリストの一覧・並び順自体を保持する専用の Riverpod Provider を持たない。`shoppingLists` は `_ShoppingListScreenState` のローカル State フィールドであり、`loadLists()`（56〜96行目）内で DB から取得した結果を `setState` で反映している。Riverpod で管理されているのは「現在選択中リストの商品一覧」（`itemProvider`）・`categoryProvider`・`purchaseProvider` のみである。

また、本画面は `TabBarView` や `PageView` を使用しておらず、リスト間の切り替えは `TabBar` のタップ（`_handleTabChange`、485〜505行目）でのみ発生する。スワイプによるページ送りは実装されていない。

### 2.2 変更後の構成

```
ShoppingListScreen
 └─ _ShoppingListScreenState
      ├─ shoppingLists: List<ShoppingList>   ← sortOrder順で保持（変更なし、順序の意味のみ変わる）
      ├─ _isReorderMode: bool                ← 新規ローカル State
      ├─ _tabController / currentListId      ← 変更なし
      │
      ├─ AppBar.actions
      │    └─ ListManagementButtons（「＋」「複製」に加え「並び替えモード」トグルを追加）
      ├─ AppBar.bottom
      │    ├─ _isReorderMode == false → ListTabBar（既存のまま）
      │    └─ _isReorderMode == true  → ListReorderBar（新規。水平ReorderableListView）
      └─ body
           └─ 変更なし（itemProvider は currentListId にのみ依存するため、
                        AppBar.bottom の表示切り替えの影響を受けない）
```

並び替えモードのON/OFFは AppBar 直下の表示ウィジェットを差し替えるだけであり、`body` 側（商品一覧表示）のデータフローには影響しない。そのため「並び替えモード中は直前に選択していたリストの中身をそのまま表示し続ける」という要件は、既存のアーキテクチャ（`itemProvider` が `currentListId` にのみ依存し `TabBar` の描画状態を参照しない）により自然に満たされる。

「並び替えモード中はタブ選択を無効化する」という要件についても、`ListTabBar`（タップで選択可能な `TabBar`）自体を描画せず `ListReorderBar` に差し替えるため、追加の無効化処理を実装せずとも達成できる。ページスワイプについては、前述の通り本画面にそもそも存在しないため対応不要。

---

## 3. コンポーネント設計

### 3.1 UI層

#### 3.1.1 `ListManagementButtons`（`lib/widgets/list_management_buttons.dart`）

既存の「リストを追加」「リストを複製」の2ボタンに加え、並び替えモードのトグルボタンを追加する。

```dart
class ListManagementButtons extends StatelessWidget {
  final VoidCallback onAddList;
  final VoidCallback onDuplicateList;
  final VoidCallback onToggleReorderMode;
  final bool isReorderMode;

  const ListManagementButtons({
    super.key,
    required this.onAddList,
    required this.onDuplicateList,
    required this.onToggleReorderMode,
    required this.isReorderMode,
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
        IconButton(
          onPressed: onToggleReorderMode,
          icon: Icon(
            Icons.reorder,
            color: isReorderMode
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          tooltip: isReorderMode ? '並び替えを終了' : 'リストを並び替え',
        ),
      ],
    );
  }
}
```

- アイコンは指定の `Icons.reorder` で固定し、`isReorderMode` の値に応じて色（テーマのプライマリカラー）とツールチップ文言のみを変える。これにより、現在モードがONかどうかを視覚的に示す。
- タブ長押し（リネーム）とはトリガーが異なるため、既存の `onLongPress: () => onRenameTab?.call(list)`（`list_tab_bar.dart` 33行目）と衝突しない。

#### 3.1.2 並び替えモードOFF時：`ListTabBar`（既存・変更なし）

`lib/widgets/list_tab_bar.dart` は変更しない。従来通り `TabBar` によるタップ選択とタブ名長押しによるリネームを提供する。

#### 3.1.3 並び替えモードON時：`ListReorderBar`（新規）

新規ファイル `lib/widgets/list_reorder_bar.dart` を追加する。`ListTabBar` と同様に `PreferredSizeWidget` を実装し、`AppBar.bottom` にそのまま差し込めるようにする。

```dart
import 'package:flutter/material.dart';

import '../models/shopping_list.dart';

class ListReorderBar extends StatelessWidget implements PreferredSizeWidget {
  final List<ShoppingList> shoppingLists;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const ListReorderBar({
    super.key,
    required this.shoppingLists,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (shoppingLists.isEmpty) {
      return const SizedBox.shrink();
    }

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      itemCount: shoppingLists.length,
      onReorderItem: (oldIndex, newIndex) =>
          onReorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final list = shoppingLists[index];
        return Padding(
          key: ValueKey(list.id),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: ReorderableDragStartListener(
            index: index,
            child: Chip(
              avatar: const Icon(Icons.drag_handle, size: 18),
              label: Text(list.name),
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
```

実装上の留意点：

- **`onReorderItem` を使用する（`onReorder` は使用しない）。** 本プロジェクトでは `ReorderableListView` の並び替えコールバックとして一貫して `onReorderItem`（Flutter 3.44.0 で追加されたAPI）を採用している（`lib/widgets/list_section.dart` 65行目、`lib/screens/favorites_screen.dart` 223行目）。このAPIでは `newIndex` が「削除後の挿入位置」を表すため、旧 `onReorder` で必要だった `if (newIndex > oldIndex) newIndex--;` の補正は行わない。
- 各行の `key` には `ValueKey(list.id)` を指定する（`Reorderable*` 系ウィジェットの必須要件）。
- ドラッグハンドルは `ReorderableDragStartListener` でラップした `Icons.drag_handle` アイコンとし、既存の商品・よく買うもの並び替えのハンドルアイコンと統一する。`ReorderableDragStartListener` は長押し不要で `PointerDown` から即ドラッグを開始する（`favorites` 並び替え実装時の知見。長押しでリネームが開く `ListTabBar` とは表示自体が切り替わっているため、トリガー面での衝突はない）。
- `preferredSize` を `ListTabBar` と同じ `Size.fromHeight(kToolbarHeight)` にすることで、並び替えモードON/OFF切り替え時にAppBarの高さが変化しないようにする。

#### 3.1.4 `ShoppingListScreen`（`lib/screens/shopping_list_screen.dart`）の変更

**新規ローカル State：**

```dart
bool _isReorderMode = false;
```

**AppBar 構成の変更（`actions`：795〜798行目付近、`bottom`：921〜925行目付近）：**

```dart
actions: [
  ListManagementButtons(
    onAddList: _showAddListDialog,
    onDuplicateList: _duplicateCurrentList,
    onToggleReorderMode: _toggleReorderMode,
    isReorderMode: _isReorderMode,
  ),
  // ... 既存のハートボタン・オプションメニューはそのまま
],
bottom: _isReorderMode
    ? ListReorderBar(
        shoppingLists: shoppingLists,
        onReorder: _onReorderList,
      )
    : ListTabBar(
        shoppingLists: shoppingLists,
        tabController: _tabController,
        onRenameTab: _showRenameListDialog,
      ),
```

**トグル処理：**

```dart
void _toggleReorderMode() {
  setState(() {
    _isReorderMode = !_isReorderMode;
  });

  // 並び替えモードを終了する際、TabController のインデックスが
  // currentListId の新しい位置とズレていないか確認し、必要なら同期する。
  if (!_isReorderMode && _tabController != null) {
    final index = shoppingLists.indexWhere((e) => e.id == currentListId);
    if (index != -1 && index != _tabController!.index) {
      _tabController!.animateTo(index);
    }
  }
}
```

（この同期処理が必要な理由は §3.3「Provider/State層」で詳述する。）

**並び替え処理：**

```dart
Future<void> _onReorderList(int oldIndex, int newIndex) async {
  final reordered = [...shoppingLists];
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, moved);

  // 楽観的更新（items の並び替えと同一パターン）
  setState(() => shoppingLists = reordered);

  try {
    await DatabaseHelper.instance.updateListOrder(reordered);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('並び替えの保存に失敗しました')),
    );
    await loadLists();
  }
}
```

- ドラッグごとに `setState` でUIへ即時反映し、`updateListOrder` でDB更新も都度行う（`items` の `reorderUncheckedItems` と同じ「ドラッグの都度DB更新」パターン）。
- 失敗時のみ `favorites` の並び替え（`_onReorderItem`）と同じ「汎用エラーメッセージ表示＋ `loadLists()` によるDB実値への再同期」を行う。ドラッグ1回ごとに毎回 try/catch のオーバーヘッドは発生するが、リストの並び替え頻度は商品の並び替えに比べて低く、DB書き込み失敗時にUIとDBの状態が乖離したまま気づかれないリスクを避けることを優先する。

### 3.2 データ層

#### 3.2.1 DBスキーマ変更

`lib/database/database_helper.dart` の DB バージョンを 8 → 9 に上げる（38行目）。version 8 は先行して実装された「リスト予算表示機能」（`budget` カラム追加）で既に使用済みのため、本機能は次に空いている 9 を使用する。

```dart
return await openDatabase(
  path,
  version: 9,
  onCreate: _createDB,
  onUpgrade: _onUpgrade,
);
```

`_createDB` 内の `lists` テーブル定義（60〜67行目）に `sortOrder` カラムを追加する。なお、`budget` カラムは前述の予算表示機能により既に追加済みであり、そのまま残す。

```dart
await db.execute('''
CREATE TABLE lists(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  createdAt INTEGER,
  budget INTEGER NOT NULL DEFAULT 0,
  sortOrder INTEGER NOT NULL DEFAULT 0
)
''');
```

初回インストール時のデフォルトリスト作成（69〜72行目）にも `sortOrder: 0` を設定する。

```dart
await db.insert('lists', {
  'name': '買い物リスト',
  'createdAt': DateTime.now().millisecondsSinceEpoch,
  'sortOrder': 0,
});
```

`_onUpgrade`（96〜192行目）に、既存の `oldVersion < 8`（予算表示機能の `budget` カラム追加、183〜191行目）ブロックに続けて `oldVersion < 9` のマイグレーションブロックを追加する。カラム追加は `favorites`/`items` の既存カラム追加と同様に `ALTER TABLE ... ADD COLUMN` パターン（テーブル再作成は不要。再作成が必要なのは「カラム削除」を伴う場合のみ、というプロジェクト確定ルールに従う）。追加後、既存行には現在の `createdAt ASC` 順に基づく連番（0, 1, 2, …）を初期セットする。

```dart
if (oldVersion < 9) {
  try {
    await db.execute(
      'ALTER TABLE lists ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0',
    );
  } catch (_) {
    // カラムが既に存在する場合は無視
  }

  final existingRows = await db.query('lists', orderBy: 'createdAt ASC');
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (int i = 0; i < existingRows.length; i++) {
      batch.update(
        'lists',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [existingRows[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  });
}
```

#### 3.2.2 `ShoppingList` モデル（`lib/models/shopping_list.dart`）

`Item`／`Category` モデルの実装パターン（`sortOrder` フィールド＋`copyWith`）に合わせて拡張する。

```dart
class ShoppingList {
  final int? id;
  final String name;
  final int createdAt;
  final int budget;
  final int sortOrder;

  ShoppingList({
    this.id,
    required this.name,
    int? createdAt,
    this.budget = 0,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'budget': budget,
      'sortOrder': sortOrder,
    };
  }

  factory ShoppingList.fromMap(Map<String, dynamic> map) {
    return ShoppingList(
      id: map['id'],
      name: map['name'],
      createdAt: map['createdAt'],
      budget: map['budget'] ?? 0,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  ShoppingList copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? budget,
    int? sortOrder,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      budget: budget ?? this.budget,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
```

`budget` フィールドは先行して実装された「リスト予算表示機能」により既に追加済みであり、本設計による変更点は `sortOrder` フィールドおよびその `toMap`/`fromMap`/`copyWith` への反映のみである。

`fromMap` は `map['sortOrder'] ?? 0` としてnullを許容する。これは、マイグレーション未実施の環境（理論上は起こらないが `_onUpgrade` の実行順序に依存しない防御的実装として）を考慮したものであり、`Item.fromMap` が `quantity`/`memo` に対して行っている `?? 1` / `?? ''` と同じ考え方である。

#### 3.2.3 `DatabaseHelper` のCRUDメソッド変更

**`getLists()`（304〜310行目）：** `orderBy` を `createdAt ASC` から `sortOrder ASC` に変更する。

```dart
Future<List<ShoppingList>> getLists() async {
  final db = await database;

  final result = await db.query('lists', orderBy: 'sortOrder ASC');

  return result.map((e) => ShoppingList.fromMap(e)).toList();
}
```

**`insertList()`（312〜316行目）：** `favorites`/`categories` の新規追加と同じ「`SELECT MAX(sortOrder) as maxOrder` → `maxOrder + 1`」パターンでsortOrderを採番する。呼び出し元（`_showAddListDialog`）が渡す `ShoppingList(name: name)` の `sortOrder`（デフォルト0）は使用せず、DB側で採番し直す。

```dart
Future<int> insertList(ShoppingList list) async {
  final db = await database;

  final result = await db.rawQuery(
    'SELECT MAX(sortOrder) as maxOrder FROM lists',
  );
  final maxOrder = (result.first['maxOrder'] as int?) ?? -1;

  final map = list.toMap()
    ..remove('id')
    ..['sortOrder'] = maxOrder + 1;

  return await db.insert('lists', map);
}
```

**`updateListOrder()`（新規）：** 並び替え確定用。`items` の並び替え保存（`updateSortOrders`、257〜274行目）と同じ、トランザクション＋バッチ更新のパターンを踏襲する。

```dart
Future<void> updateListOrder(List<ShoppingList> lists) async {
  final db = await database;

  await db.transaction((txn) async {
    final batch = txn.batch();

    for (int i = 0; i < lists.length; i++) {
      batch.update(
        'lists',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [lists[i].id],
      );
    }

    await batch.commit(noResult: true);
  });
}
```

**`duplicateList()`（361〜389行目）：** 現状は `sortOrder` を設定せずに `INSERT` しているため、このままでは複製されたリストが常に `sortOrder=0`（デフォルト値）となり、既存リストの先頭に割り込んでしまう。新規リスト作成と同様に `MAX(sortOrder) + 1` を採番するよう修正する。

```dart
Future<int> duplicateList(int sourceListId, String newName) async {
  final db = await database;

  return await db.transaction((txn) async {
    final maxOrderResult = await txn.rawQuery(
      'SELECT MAX(sortOrder) as maxOrder FROM lists',
    );
    final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? -1;

    final newListId = await txn.insert('lists', {
      'name': newName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'sortOrder': maxOrder + 1,
    });

    // 元リストのアイテムを取得してコピー（既存ロジックのまま）
    final items = await txn.query(
      'items',
      where: 'listId = ?',
      whereArgs: [sourceListId],
      orderBy: 'sortOrder ASC',
    );

    for (final item in items) {
      final copy = Map<String, dynamic>.from(item);
      copy.remove('id');
      copy['listId'] = newListId;
      copy['isChecked'] = 0;
      await txn.insert('items', copy);
    }

    return newListId;
  });
}
```

**`importData()`（561〜722行目）内の `lists` INSERT（629〜651行目付近）：** 既存の確定ルール「インポート処理でバックアップのメタデータ（`createdAt` 等）を流用せず、現在のDB最大値+連番を設定する」を `sortOrder` にも適用する。`createdAt` について既に行っている「既存リスト中の最大値+連番」と同じ考え方で、`sortOrder` も現在のDB最大値+連番を採番する。これにより、インポートされたリストの並び順がバックアップ時の `sortOrder` 値に引きずられて既存リストと衝突する（同じ `sortOrder` を持つ行が複数できる）事態を防ぐ。なお `budget` は先行して実装された予算表示機能により既に `(list['budget'] as num?)?.toInt() ?? 0` として採用済みであり、この扱いは変更しない。

```dart
// lists INSERT
// 既存リスト中の最大 createdAt を取得して、インポートリストが必ず右端に並ぶようにする
final maxCreatedAtResult = await txn.rawQuery(
  'SELECT MAX(createdAt) as maxAt FROM lists',
);
final baseCreatedAt =
    ((maxCreatedAtResult.first['maxAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch) + 1;

final maxSortOrderResult = await txn.rawQuery(
  'SELECT MAX(sortOrder) as maxOrder FROM lists',
);
int nextListSortOrder =
    ((maxSortOrderResult.first['maxOrder'] as int?) ?? -1) + 1;

int listInsertIndex = 0;

for (final list in incomingLists) {
  final oldId = (list['id'] as num).toInt();
  final resolvedName =
      resolveListName(list['name'] as String, existingNames);
  existingNames.add(resolvedName);

  final newId = await txn.insert('lists', {
    'name': resolvedName,
    'createdAt': baseCreatedAt + listInsertIndex,
    'budget': (list['budget'] as num?)?.toInt() ?? 0,
    'sortOrder': nextListSortOrder++,
  });
  listInsertIndex++;
  listIdMap[oldId] = newId;
}
```

### 3.3 Provider／State層

#### 3.3.1 現状の architecture 上の制約

前述の通り、`shoppingLists` を保持する専用の Riverpod Provider は存在しない。したがって、確定ルール「State フィールドを更新するメソッドでは、対応する Provider も必ず同期して更新すること」を字義通り適用する対象（Riverpod Provider）は本機能には存在しない。ただし、このルールの本質的な意図（＝ある状態を更新したときに、それと連動する別の状態を更新し忘れない）に該当する箇所が2点あるため、明記する。

#### 3.3.2 同期が必要な箇所（1）：`_tabController` のインデックスと `currentListId`

`_tabController` は `shoppingLists` の**インデックス**に基づいてどのタブが選択中かを管理しており、`TabController` オブジェクト自体は `loadLists()`（リストの追加・削除・リネーム・インポート時）でのみ再生成される。並び替え操作では `_tabController` を再生成しないため、並び替えモードをOFFにして `ListTabBar` の表示に戻した際、`_tabController.index` が `currentListId` の新しい位置とズレたままになる可能性がある。

このズレを防ぐため、`_toggleReorderMode()` でモードをOFFにするタイミングで、`shoppingLists.indexWhere((e) => e.id == currentListId)` を再計算し、`_tabController.index` と食い違っていれば `_tabController.animateTo(...)` で補正する（§3.1.4 参照）。この考え方は `loadLists()` 内で行っている `currentIndex` の算出ロジック（66〜79行目）と同じである。

なお、並び替えモード中は `ListTabBar` 自体を描画しないため、ドラッグ中に `_handleTabChange`（`TabController` の `indexIsChanging` リスナー）が誤発火することはない。

#### 3.3.3 同期が必要な箇所（2）：`shoppingLists`（State）と DB（`lists.sortOrder`）

`_onReorderList` 内で `setState(() => shoppingLists = reordered)` により画面表示（State）を先行更新し、続けて `DatabaseHelper.instance.updateListOrder(reordered)` でDBを更新する。DB更新が失敗した場合は `loadLists()` を呼び直し、DBの実値でStateを上書きすることで、StateとDBの内容を必ず一致させる（§3.1.4・§4 参照）。

---

## 4. 検討した代替案

| 案 | 内容 | 不採用理由 |
|---|---|---|
| 専用の「リスト管理」画面 | 設定画面等を新設し、そこで `ReorderableListView` により並び替える | インライン（メイン画面上）でのドラッグ並び替えを優先し、画面遷移を挟まない体験を選択したため |
| タブ長押しの継続でドラッグ開始 | タブを長押しし、指を動かさなければ従来通りリネームダイアログを開く。動かせばドラッグ開始とみなす | 長押し開始時点でリネームとドラッグのどちらの意図か判定するのが煩雑になり誤操作を招きやすいため、長押し以外の明示的なトリガー（トグルボタン）を選択した |
| `TabBar` 内に常時ハンドルアイコンを表示しそれをドラッグ | `Tab` の中に小さいドラッグハンドルアイコンを常設し、それだけをドラッグ可能にする | `TabBar` の内部レイアウト（`Tab` のサイズ計算・インジケーター描画）への依存が強く、Flutterのバージョンアップ等で壊れやすい。並び替えモードボタンによる明示的な切り替えの方が実装・保守ともに安全なため |
| `TabBar` を常時 `ReorderableListView` に差し替えたままにする | 並び替えモードという概念を設けず、常時ドラッグ可能な表示にする | 通常時のタブ選択操作（タップ）とドラッグ操作が常に競合するリスクがあるほか、既存の `TabBar` の見た目・挙動（インジケーター等）を通常時にも失うことになるため、モード切り替え方式を選択した |

---

## 5. エラーハンドリング

- `DatabaseHelper.instance.updateListOrder()` の呼び出しは `try/catch` で保護する。`catch` 節では確定ルール「catch 節でユーザー向けメッセージを返す場合は `e.toString()` を使わず汎用文言にする」に従い、`e.toString()` を使わず `'並び替えの保存に失敗しました'` のような汎用文言を `SnackBar` で表示する（既存の `_exportBackup()` の `catch (_) { ... '保存に失敗しました' }` と同じパターン）。
- DB更新失敗時は `loadLists()` を呼び直し、State（`shoppingLists`・`_tabController`）をDBの実値に再同期する。これにより、ドラッグ操作の楽観的更新によってUI上の並び順とDB上の並び順が乖離したまま残ることを防ぐ。
- `updateListOrder` に渡す `lists[i].id` が `null`（未保存のリスト）になるケースは、`shoppingLists` が常にDBから取得済みの `ShoppingList`（`id` 確定済み）のみを保持するため発生しない。

---

## 6. その他のプロジェクトルール順守事項

- **ヘルプ更新（確定ルール：機能追加・変更時は必ず `lib/widgets/help_dialog.dart` も同時更新する）：** 既存の「リストを追加」（`Icons.playlist_add`、49〜53行目）と「リストを削除」（`Icons.delete_outline`、54〜58行目）の間に、並び替えモードの操作説明を追加する。

  ```dart
  _HelpItem(
    icon: Icons.reorder,
    label: 'リストの並び替え',
    description:
        'AppBar右上の並び替えボタン（⇅アイコン）をタップすると並び替えモードになります\n'
        '表示されたハンドルをドラッグして順番を変更できます。再度ボタンを押すと通常表示に戻ります',
  ),
  ```

- **生きた設計書の更新：** `docs/spec_HKL-001_shopping_list_app_rev9.0.md` を rev9.1 へ更新する。`updating-rev-numbered-specs` スキルの手順に従い、以下を同一コミットで行う。
  1. 現行の `docs/spec_HKL-001_shopping_list_app_rev9.0.md` を `docs/_old/spec_HKL-001_shopping_list_app_rev9.0.md` へコピーして保存する
  2. 本文（変更履歴テーブルへの追記、冒頭「Rev 9.0」→「Rev 9.1」表記の更新、システム構成図・DBスキーマ節等の該当箇所の更新）を編集する
  3. `git mv docs/spec_HKL-001_shopping_list_app_rev9.0.md docs/spec_HKL-001_shopping_list_app_rev9.1.md` でファイル名をリネームする（内容編集と同一コミットに含める）
  4. リネーム後、ファイル内に「rev9.0」「Rev 9.0」等、古いリビジョンへの自己言及が残っていないか grep で確認する

- **インポート処理の確定ルール順守：** `importData()` での `lists` 復元時、`sortOrder` をバックアップのメタデータから流用せず、現在のDB最大値+連番で設定する（§3.2.3参照）。既存の `createdAt` に対する扱いと同じ考え方である。

---

## 7. テスト方針

### 7.1 現状のテスト基盤に関する制約

本プロジェクトの `test/` 配下（`item_test.dart`・`category_test.dart`・`backup_test.dart` 等）は `package:test` によるモデル・純粋関数の単体テストのみで構成されており、`sqflite` の実DBインスタンスに対する統合テスト（`sqflite_common_ffi` 等の導入）は行っていない。例えば `DatabaseHelper.resolveListName`（`backup_test.dart`）のように、**副作用のない静的メソッド／純粋ロジックのみ**がテスト対象になっている。

そのため、`updateListOrder`／`getLists()` のような実際のDBアクセスを伴うメソッドは、現状のテスト基盤では直接の自動テスト対象にできない。この点を踏まえ、以下の方針でテストを設計する。

### 7.2 自動テスト（モデル層）

`test/shopping_list_test.dart`（新規）を追加し、`ShoppingList` モデルの `toMap`/`fromMap`/`copyWith` を `item_test.dart` の `Item モデル` テストと同じ構成でテストする。

- `toMap` / `fromMap` ラウンドトリップ（`sortOrder` を含む）
- `copyWith`：指定フィールドのみ更新され、他は元の値を保持すること
- `fromMap` で `sortOrder` キーが存在しない場合に `0` にフォールバックすること（マイグレーション未実施環境を想定した防御的実装の検証）

### 7.3 自動テストの限界と補完方針

- `updateListOrder`／`getLists()`（sortOrder順で返ること）・`insertList`／`duplicateList`（採番ロジック）・`importData`（sortOrder再採番）については、実DBを伴うため既存基盤では単体テスト化しない。将来的に `sqflite_common_ffi` 等でDB統合テストの基盤を整備する場合は、`favorites`/`categories` の採番ロジック（`SELECT MAX(sortOrder)+1`）と合わせて対象に加えることを検討する。
- ドラッグ操作そのもの（`ReorderableListView` のジェスチャー）は、過去の `favorites` 並び替え実装時の知見（Feedback.md記載）として「エミュレーターの Flutter ドラッグテストは ADB では再現できない」ことが確認されている。そのため、本機能についても実機・エミュレーターでの手動テストで動作確認する。
- 手動テストで確認する項目：
  - 並び替えモードON/OFFの切り替えでAppBar高さが変化しないこと
  - ドラッグでリストの並び順を変更後、アプリを再起動しても順序が保持されること（DB永続化の確認）
  - 並び替えモード中に商品一覧（body）の表示が変化しないこと（直前に選択していたリストの中身が表示され続けること）
  - 並び替えモードをOFFにした直後、`TabBar` のハイライトが `currentListId` のタブと一致すること（§3.3.2のズレ補正の確認）
  - リストが1件のみの場合・10件（上限）の場合でも並び替えモードが問題なく動作すること
  - DB更新失敗を意図的に発生させにくいため、この項目のみコードレビューでの `try/catch` ロジック確認に代える

---

## 8. 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `lib/database/database_helper.dart` | DBバージョン 8→9、`lists` テーブルへ `sortOrder` カラム追加、`_onUpgrade` にマイグレーション追加、`getLists()` の `orderBy` 変更、`insertList()`／`duplicateList()` の採番ロジック追加、`updateListOrder()` 新規追加、`importData()` の `lists` INSERT に `sortOrder` 採番を追加 |
| `lib/models/shopping_list.dart` | `sortOrder` フィールド・`toMap`/`fromMap`/`copyWith` 追加 |
| `lib/widgets/list_management_buttons.dart` | 並び替えモードトグルボタン（`onToggleReorderMode`・`isReorderMode`）を追加 |
| `lib/widgets/list_reorder_bar.dart` | 新規追加（水平 `ReorderableListView.builder` によるリスト並び替えUI） |
| `lib/widgets/list_tab_bar.dart` | 変更なし |
| `lib/screens/shopping_list_screen.dart` | `_isReorderMode` State追加、`_toggleReorderMode()`／`_onReorderList()` 追加、AppBar構成の分岐追加 |
| `lib/widgets/help_dialog.dart` | 「リストの並び替え」操作説明を追加 |
| `docs/spec_HKL-001_shopping_list_app_rev9.0.md` | rev9.1へ更新・リネーム（`docs/spec_HKL-001_shopping_list_app_rev9.1.md`）、旧版を `docs/_old/` へ保存 |
| `test/shopping_list_test.dart` | 新規追加（`ShoppingList` モデルの単体テスト） |
