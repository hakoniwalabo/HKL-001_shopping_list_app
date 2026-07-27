# よく買うもの 全画面化・カテゴリ別表示 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 「よく買うもの」をモーダルダイアログ（`FavoritesDialog`、高さ320px制限・フラット表示）から独立画面（`FavoritesScreen`、`Navigator.push` 遷移）に変更し、カテゴリ別セクション表示（カテゴリ内のみドラッグ並べ替え可能）を追加する。

**Architecture:** `lib/screens/favorites_screen.dart` を新規作成し、`FavoritesDialog` の状態管理・UI ロジック（検索・全選択・スワイプ削除＋Undo・編集ダイアログ・並べ替え）をそのまま移植したうえで `Scaffold`／`AppBar` ベースの画面に置き換える。カテゴリ別グルーピングと「セクション内index→グローバル位置」変換は、`shopping_list_screen.dart` の `_buildCategorySections` / `item_provider.dart` の `reorderUncheckedItems` と同じ考え方を踏襲しつつ、テスト容易性のため純粋関数として `lib/utils/favorites_section_helper.dart` に切り出す（flutter-apply-architecture-best-practices スキルの「複雑なロジックはUIから分離する」方針に沿うが、本プロジェクトは Repository/ViewModel 層を持たない既存構成のため、新規レイヤーは導入せず純粋関数の切り出しに留める）。`ListSection`/`ItemTile`（Item専用）は汎用化せず、favorites 用の表示は `favorites_screen.dart` 内に閉じて実装する（設計書の決定事項）。

**Tech Stack:** Flutter（Dart SDK `^3.11.4`）、flutter_riverpod 3.x、sqflite、`package:test`（純粋ロジックの単体テスト）

## Global Constraints

- Dart SDK は `^3.11.4`（pubspec.yaml）。`DropdownButtonFormField` は Flutter 3.33.0+ で `value:` が deprecated、`initialValue:` が正しい。移植元の `favorites_dialog.dart` は既に `initialValue:` を使用しているため、そのまま踏襲し `value:` へ戻さないこと
- カテゴリ内セクションの並べ替えは、`shopping_list_screen.dart` の `_buildCategorySections`／`item_provider.dart` の `reorderUncheckedItems` が採用している「セクション内indexをグローバルリストの位置に変換してから永続化する」パターンを踏襲する
- データ層（`DatabaseHelper.getFavorites()` / `reorderFavorites()` / `insertFavorite()` / `updateFavorite()` / `deleteFavorite()` / `restoreFavorite()` / `addFavoriteItemsToList()`）は変更不要（設計書に明記）
- 機能を追加・変更・削除したときは `lib/widgets/help_dialog.dart` を同時に更新するプロジェクトルールに従う
- 検証は `flutter analyze` と `flutter test`（純粋ロジックの単体テスト含む）のみで行う。エミュレーター・実機での目視確認は行わず、マスターに依頼する（Rules_Flutter_RN.md 方針）
- `lib/widgets/favorites_dialog.dart` の削除は、新画面への移行が完了し `flutter analyze`／`flutter test` が通ってから行う

## 設計判断メモ（マスター確認済み）

計画作成時に「計画外・要確認事項」として挙げた以下の2点は、マスターへの確認により方針が確定した。

- `docs/spec_HKL-001_shopping_list_app_rev8.7.md`（`favorites_dialog.dart` の構成を詳細に記述している生きた仕様書）は、承認済み設計書の「影響ファイル一覧」には含まれていないが、実装完了後に更新する方針が決まった。Task 6 として追加済み
- 画面下部のボタン配置（「直接登録」「リストに追加」）は `Scaffold.bottomNavigationBar` にまとめる方針が決まった。`lib/widgets/favorites_dialog.dart` 354〜368行目の `AlertDialog.actions` 相当の配置を、プロジェクトルール「画面最下部に固定したい要素は `body` ではなく `Scaffold.bottomNavigationBar` に置く」（Rules_Flutter_RN.md）に従って踏襲する。Task 2 の実装方針に明記済み

---

## ファイル構成

| 操作 | パス |
|------|------|
| 新規作成 | `lib/utils/favorites_section_helper.dart` |
| 新規作成 | `test/favorites_section_helper_test.dart` |
| 新規作成 | `lib/screens/favorites_screen.dart` |
| 変更 | `lib/screens/shopping_list_screen.dart` |
| 変更 | `lib/widgets/help_dialog.dart` |
| 削除 | `lib/widgets/favorites_dialog.dart`（Task 5、動作確認後） |
| 変更 | `docs/spec_HKL-001_shopping_list_app_rev8.7.md`（Task 6、実装完了後に rev8.8 へ更新） |

---

## Task 1: カテゴリ別グルーピング・グローバル並べ替えindex算出の純粋関数を作成する

**Files:**
- Create: `lib/utils/favorites_section_helper.dart`
- Create: `test/favorites_section_helper_test.dart`

**Interfaces:**
- Produces: `class FavoriteSection { final String title; final List<Map<String, dynamic>> items; }`
- Produces: `List<FavoriteSection>? buildFavoriteSections({required List<Map<String, dynamic>> favorites, required List<Category> categories})` — カテゴリが1件もない場合は `null` を返す
- Produces: `int resolveGlobalFavoriteIndex({required List<Map<String, dynamic>> allFavorites, required List<Map<String, dynamic>> sectionItems, required int indexInSection})` — 見つからない場合は `-1`

- [ ] **Step 1: 失敗するテストを書く**

`test/favorites_section_helper_test.dart` を作成する。

```dart
import 'package:test/test.dart';
import 'package:shopping_list_app/models/category.dart';
import 'package:shopping_list_app/utils/favorites_section_helper.dart';

void main() {
  group('buildFavoriteSections', () {
    test('カテゴリが1件もない場合は null を返す（フラット表示に切り替える合図）', () {
      final favorites = [
        {'id': 1, 'name': '牛乳', 'categoryId': null},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: []);
      expect(result, isNull);
    });

    test('カテゴリごとにセクションへ分割する（sortOrder順を維持する）', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
        Category(id: 2, name: '肉', sortOrder: 1, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': 'にんじん', 'categoryId': 1},
        {'id': 2, 'name': '牛肉', 'categoryId': 2},
        {'id': 3, 'name': 'キャベツ', 'categoryId': 1},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 2);
      expect(result[0].title, '野菜');
      expect(result[0].items.map((f) => f['id']), [1, 3]);
      expect(result[1].title, '肉');
      expect(result[1].items.map((f) => f['id']), [2]);
    });

    test('categoryId が null の favorite は「カテゴリなし」セクションに最後にまとまる', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': 'にんじん', 'categoryId': 1},
        {'id': 2, 'name': '謎の商品', 'categoryId': null},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 2);
      expect(result.last.title, 'カテゴリなし');
      expect(result.last.items.single['id'], 2);
    });

    test('存在しないカテゴリIDを指す favorite も「カテゴリなし」セクションに入る', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': '削除済みカテゴリの商品', 'categoryId': 99},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 1);
      expect(result.single.title, 'カテゴリなし');
    });

    test('該当する favorite が1件もないカテゴリのセクションは生成しない', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
        Category(id: 2, name: '肉', sortOrder: 1, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': 'にんじん', 'categoryId': 1},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 1);
      expect(result.single.title, '野菜');
    });
  });

  group('resolveGlobalFavoriteIndex', () {
    test('セクション内indexから全favoritesリスト上のグローバル位置を算出する', () {
      final allFavorites = [
        {'id': 10, 'name': 'A'},
        {'id': 20, 'name': 'B'},
        {'id': 30, 'name': 'C'},
      ];
      final sectionItems = [
        {'id': 30, 'name': 'C'},
        {'id': 10, 'name': 'A'},
      ];
      expect(
        resolveGlobalFavoriteIndex(
          allFavorites: allFavorites,
          sectionItems: sectionItems,
          indexInSection: 0,
        ),
        2,
      );
      expect(
        resolveGlobalFavoriteIndex(
          allFavorites: allFavorites,
          sectionItems: sectionItems,
          indexInSection: 1,
        ),
        0,
      );
    });

    test('該当する id が全体リストに存在しない場合は -1 を返す', () {
      final allFavorites = [
        {'id': 10, 'name': 'A'},
      ];
      final sectionItems = [
        {'id': 999, 'name': 'X'},
      ];
      expect(
        resolveGlobalFavoriteIndex(
          allFavorites: allFavorites,
          sectionItems: sectionItems,
          indexInSection: 0,
        ),
        -1,
      );
    });
  });
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```
dart test test/favorites_section_helper_test.dart
```

期待出力: `Error: Could not resolve URI 'package:shopping_list_app/utils/favorites_section_helper.dart'`（またはコンパイルエラー）

- [ ] **Step 3: 実装する**

`lib/utils/favorites_section_helper.dart` を作成する。

```dart
import '../models/category.dart';

/// よく買うものの1カテゴリ分の表示セクション。
class FavoriteSection {
  final String title;
  final List<Map<String, dynamic>> items;

  const FavoriteSection({required this.title, required this.items});
}

/// favorites をカテゴリ別セクションに分割する。
///
/// - カテゴリが1件も登録されていない場合は null を返す（呼び出し側でフラット表示に切り替える）。
/// - categoryId が null、または存在しないカテゴリIDを指す favorite は
///   「カテゴリなし」セクションとして最後にまとめる。
/// - 該当する favorite が1件もないカテゴリのセクションは生成しない。
List<FavoriteSection>? buildFavoriteSections({
  required List<Map<String, dynamic>> favorites,
  required List<Category> categories,
}) {
  if (categories.isEmpty) return null;

  final sections = <FavoriteSection>[];
  for (final cat in categories) {
    final items =
        favorites.where((f) => f['categoryId'] as int? == cat.id).toList();
    if (items.isEmpty) continue;
    sections.add(FavoriteSection(title: cat.name, items: items));
  }

  final categoryIds = categories.map((c) => c.id).toSet();
  final noCategory = favorites
      .where((f) =>
          f['categoryId'] == null ||
          !categoryIds.contains(f['categoryId'] as int?))
      .toList();
  if (noCategory.isNotEmpty) {
    sections.add(FavoriteSection(title: 'カテゴリなし', items: noCategory));
  }

  return sections;
}

/// カテゴリセクション内の並べ替えindex（indexInSection）を、
/// sortOrder順の全favoritesリスト（allFavorites）上でのグローバル位置に変換する。
///
/// sectionItems[indexInSection] の id を allFavorites 内で検索し、
/// 一致する要素のインデックスを返す。見つからない場合は -1 を返す。
int resolveGlobalFavoriteIndex({
  required List<Map<String, dynamic>> allFavorites,
  required List<Map<String, dynamic>> sectionItems,
  required int indexInSection,
}) {
  final targetId = sectionItems[indexInSection]['id'] as int;
  return allFavorites.indexWhere((f) => f['id'] as int == targetId);
}
```

- [ ] **Step 4: テストが通ることを確認する**

```
dart test test/favorites_section_helper_test.dart
```

期待出力: `All tests passed!`

- [ ] **Step 5: flutter analyze でエラーがないことを確認する**

```
flutter analyze lib/utils/favorites_section_helper.dart
```

期待出力: `No issues found!`

- [ ] **Step 6: コミット**

```bash
git add lib/utils/favorites_section_helper.dart test/favorites_section_helper_test.dart
git commit -m "feat: よく買うもののカテゴリ別グルーピング・グローバル並べ替えindex算出の純粋関数を追加"
```

---

## Task 2: FavoritesScreen を新規作成する

**Files:**
- Create: `lib/screens/favorites_screen.dart`

**Interfaces:**
- Consumes: `buildFavoriteSections`・`resolveGlobalFavoriteIndex`・`FavoriteSection`（Task 1 の `lib/utils/favorites_section_helper.dart`）
- Consumes: `categoryProvider`（`lib/providers/category_provider.dart`）、`itemProvider`（`lib/providers/item_provider.dart`）、`DatabaseHelper.instance`（`getFavorites`/`reorderFavorites`/`deleteFavorite`/`restoreFavorite`/`insertFavorite`/`updateFavorite`/`addFavoriteItemsToList`。いずれもシグネチャ変更なし）
- Produces: `class FavoritesScreen extends ConsumerStatefulWidget` — コンストラクタ `FavoritesScreen({required int currentListId})`。`Navigator.push<int>` で遷移し、`Navigator.pop(context, ids.length)` で追加件数を返す（Task 3 が消費する）

この画面は `lib/widgets/favorites_dialog.dart` の `FavoritesDialog`／`_AddFavoriteDialog`／`_EditFavoriteDialog` の状態管理・挙動をそのまま踏襲する。差分は次の3点のみ：
1. `AlertDialog` → `Scaffold` + `AppBar`（タイトル「よく買うもの」。戻る矢印は `Navigator.push` 遷移時に自動表示されるため明示的な閉じるボタンは不要）
2. 高さ320px制限（`ConstrainedBox(maxHeight: 320)`）を撤廃し、`Expanded` で画面いっぱいに表示
3. カテゴリが1件以上あり検索していないときは `buildFavoriteSections` でカテゴリ別セクション表示にする（セクション内のみ `ReorderableListView` で並べ替え可能）。検索中、またはカテゴリが1件もないときは現行どおりフラット表示

「直接登録」「リストに追加」ボタンは、`lib/widgets/favorites_dialog.dart` 354〜368行目の `AlertDialog.actions` に相当する位置から、画面下部の `Scaffold.bottomNavigationBar` にまとめて配置する。これはプロジェクトルール「画面最下部に固定したい要素（広告バナー等）と FAB を共存させる場合、要素は `body` ではなく `Scaffold.bottomNavigationBar` に置く」（Rules_Flutter_RN.md）を踏襲した配置方針である（ボタンの活性条件・処理内容は変更しない）。

- [ ] **Step 1: `lib/screens/favorites_screen.dart` を作成する**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../utils/favorites_section_helper.dart';
import '../widgets/fields/item_name_field.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  final int currentListId;

  const FavoritesScreen({super.key, required this.currentListId});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  List<Map<String, dynamic>> _favorites = [];
  final Set<int> _selectedIds = {};
  Map<String, dynamic>? _pendingUndoFavorite;
  Timer? _undoTimer;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = data;
      _selectedIds.removeWhere(
        (id) => !data.any((f) => f['id'] as int == id),
      );
    });
  }

  // FavoritesDialog._onReorderItem と同一。グローバルな favorites 全体リスト
  // 上の oldIndex/newIndex を受け取り、DB へ永続化する。
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

  // カテゴリセクション内の並べ替え。セクション内 index をグローバル位置に変換してから
  // _onReorderItem に渡す（shopping_list_screen.dart の _buildCategorySections /
  // item_provider.dart の reorderUncheckedItems と同じパターン）。
  Future<void> _onReorderInSection(
    List<Map<String, dynamic>> sectionItems,
    int oldIndex,
    int newIndex,
  ) async {
    final globalOld = resolveGlobalFavoriteIndex(
      allFavorites: _favorites,
      sectionItems: sectionItems,
      indexInSection: oldIndex,
    );
    final globalNew = resolveGlobalFavoriteIndex(
      allFavorites: _favorites,
      sectionItems: sectionItems,
      indexInSection: newIndex,
    );
    if (globalOld == -1 || globalNew == -1) return;
    await _onReorderItem(globalOld, globalNew);
  }

  Future<void> _addToList() async {
    final ids = _selectedIds.toList();
    await DatabaseHelper.instance.addFavoriteItemsToList(
      ids,
      widget.currentListId,
    );
    await ref.read(itemProvider.notifier).changeList(widget.currentListId);
    if (!mounted) return;
    Navigator.pop(context, ids.length);
  }

  List<Map<String, dynamic>> get _filteredFavorites =>
      _searchText.isEmpty
          ? _favorites
          : _favorites
              .where((f) => (f['name'] as String)
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()))
              .toList();

  bool get _allSelected =>
      _filteredFavorites.isNotEmpty &&
      _filteredFavorites.every((f) => _selectedIds.contains(f['id'] as int));

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        for (final f in _filteredFavorites) {
          _selectedIds.remove(f['id'] as int);
        }
      } else {
        for (final f in _filteredFavorites) {
          _selectedIds.add(f['id'] as int);
        }
      }
    });
  }

  Future<void> _deleteFavorite(Map<String, dynamic> fav) async {
    final id = fav['id'] as int;
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
  }

  Future<void> _editFavorite(Map<String, dynamic> fav) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditFavoriteDialog(
        id: fav['id'] as int,
        initialName: fav['name'] as String,
        initialPrice: fav['price'] as int,
        initialQuantity: fav['quantity'] as int,
        initialCategoryId: fav['categoryId'] as int?,
      ),
    );
    await _load();
  }

  Widget _buildTile(Map<String, dynamic> fav, {int? dragIndex}) {
    final id = fav['id'] as int;
    final name = fav['name'] as String;
    final price = fav['price'] as int;
    final qty = fav['quantity'] as int;
    final subtitle = price > 0 ? '¥$price × $qty' : '数量: $qty';
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteFavorite(fav),
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
        onTap: () => _editFavorite(fav),
        trailing: dragIndex != null
            ? ReorderableDragStartListener(
                index: dragIndex,
                child: const Icon(Icons.drag_handle),
              )
            : null,
      ),
    );
  }

  // 1セクション分（カテゴリ名見出し + ReorderableListView）を組み立てる。
  // title が null の場合は見出しを表示しない（カテゴリが1件もないときのフラット表示用）。
  Widget _buildSection(String? title, List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorderInSection(items, oldIndex, newIndex),
            itemBuilder: (_, i) => _buildTile(items[i], dragIndex: i),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_favorites.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('まだ登録されていません'),
      );
    }

    if (_searchText.isNotEmpty) {
      // 検索中はカテゴリ分けせず、フラットな絞り込みリストのみを表示する（並べ替え不可）
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _filteredFavorites.length,
        itemBuilder: (_, i) => _buildTile(_filteredFavorites[i]),
      );
    }

    final categories = ref.watch(categoryProvider).value ?? <Category>[];
    final sections =
        buildFavoriteSections(favorites: _favorites, categories: categories);

    final sectionWidgets = sections == null
        ? [_buildSection(null, _favorites)]
        : [for (final s in sections) _buildSection(s.title, s.items)];

    return ListView(
      padding: EdgeInsets.zero,
      children: sectionWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('よく買うもの'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pendingUndoFavorite != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '削除しました',
                            style:
                                TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            _undoTimer?.cancel();
                            final data = _pendingUndoFavorite!;
                            setState(() => _pendingUndoFavorite = null);
                            await DatabaseHelper.instance.restoreFavorite(
                              data['name'] as String,
                              data['price'] as int,
                              data['quantity'] as int,
                              data['sortOrder'] as int,
                              categoryId: data['categoryId'] as int?,
                            );
                            await _load();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amber,
                          ),
                          child: const Text('元に戻す'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '検索',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchText.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchText = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
            const SizedBox(height: 8),
            if (_filteredFavorites.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(
                    _allSelected ? Icons.deselect : Icons.select_all,
                  ),
                  label: Text(_allSelected ? '全解除' : '全選択'),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => _AddFavoriteDialog(onAdded: _load),
                    );
                  },
                  child: const Text('直接登録'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _addToList,
                  child: const Text('リストに追加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFavoriteDialog extends ConsumerStatefulWidget {
  final Future<void> Function() onAdded;

  const _AddFavoriteDialog({required this.onAdded});

  @override
  ConsumerState<_AddFavoriteDialog> createState() =>
      _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends ConsumerState<_AddFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '1');
  int? _selectedCategoryId;
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _nameFocus = FocusNode();
  List<String> _candidateNames = [];

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final data = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _candidateNames = data.map((f) => f['name'] as String).toList();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _scrollCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _showNewCategoryDialog(List<Category> categories) async {
    String newName = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリを追加'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
          onChanged: (v) => newName = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (confirmed != true || newName.isEmpty || !mounted) return;
    final id = await ref.read(categoryProvider.notifier).addCategory(newName);
    setState(() => _selectedCategoryId = id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).value ?? <Category>[];
    return AlertDialog(
      title: const Text('よく買うものに登録'),
      content: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemNameField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                candidateNames: _candidateNames,
              ),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '税込価格'),
                onTap: () => _priceCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _priceCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
                },
              ),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '個数'),
                onTap: () => _qtyCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _qtyCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ（任意）',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      initialValue: _selectedCategoryId,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('なし')),
                        ...categories.map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '新規カテゴリ',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _showNewCategoryDialog(categories),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await DatabaseHelper.instance.insertFavorite(
              _nameCtrl.text.trim(),
              int.parse(_priceCtrl.text),
              int.parse(_qtyCtrl.text),
              categoryId: _selectedCategoryId,
            );
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
            await widget.onAdded();
          },
          child: const Text('登録'),
        ),
      ],
    );
  }
}

class _EditFavoriteDialog extends ConsumerStatefulWidget {
  final int id;
  final String initialName;
  final int initialPrice;
  final int initialQuantity;
  final int? initialCategoryId;

  const _EditFavoriteDialog({
    required this.id,
    required this.initialName,
    required this.initialPrice,
    required this.initialQuantity,
    this.initialCategoryId,
  });

  @override
  ConsumerState<_EditFavoriteDialog> createState() =>
      _EditFavoriteDialogState();
}

class _EditFavoriteDialogState extends ConsumerState<_EditFavoriteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _priceCtrl = TextEditingController(text: widget.initialPrice.toString());
    _qtyCtrl = TextEditingController(text: widget.initialQuantity.toString());
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _showNewCategoryDialog(List<Category> categories) async {
    String newName = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリを追加'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
          onChanged: (v) => newName = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (confirmed != true || newName.isEmpty || !mounted) return;
    final id = await ref.read(categoryProvider.notifier).addCategory(newName);
    if (!mounted) return;
    setState(() => _selectedCategoryId = id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).value ?? <Category>[];
    return AlertDialog(
      title: const Text('よく買うものを編集'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '商品名'),
                onTap: () => _nameCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _nameCtrl.text.length,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
              ),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '税込価格'),
                onTap: () => _priceCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _priceCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 0) ? '0以上の整数を入力してください' : null;
                },
              ),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '個数'),
                onTap: () => _qtyCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _qtyCtrl.text.length,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1) ? '1以上の整数を入力してください' : null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ（任意）',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      initialValue: _selectedCategoryId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('なし')),
                        ...categories.map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '新規カテゴリ',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _showNewCategoryDialog(categories),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await DatabaseHelper.instance.updateFavorite(
              widget.id,
              _nameCtrl.text.trim(),
              int.parse(_priceCtrl.text),
              int.parse(_qtyCtrl.text),
              categoryId: _selectedCategoryId,
            );
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
```

> **注意（Dart SDK `^3.11.4` / Flutter 3.33.0+）:** 上記の `DropdownButtonFormField<int?>` は `initialValue:` を使用している（`value:` は deprecated）。移植時に誤って `value:` に戻さないこと。

- [ ] **Step 2: flutter analyze でエラーがないことを確認する**

```
flutter analyze lib/screens/favorites_screen.dart
```

期待出力: `No issues found!`（この時点では `favorites_screen.dart` はまだどこからも呼ばれていないため `unused_element` 等の警告が出ないことを確認する。`FavoritesScreen` はパブリッククラスなので警告対象にはならない）

- [ ] **Step 3: コミット**

```bash
git add lib/screens/favorites_screen.dart
git commit -m "feat: よく買うものの全画面版 FavoritesScreen を新規作成（カテゴリ別セクション表示対応）"
```

---

## Task 3: shopping_list_screen.dart の呼び出し元を Navigator.push に変更する

**Files:**
- Modify: `lib/screens/shopping_list_screen.dart`

**Interfaces:**
- Consumes: `FavoritesScreen`（Task 2 で作成、コンストラクタ `FavoritesScreen({required int currentListId})`）

- [ ] **Step 1: import を差し替える**

`lib/screens/shopping_list_screen.dart` 21行目の import を変更する。

変更前:
```dart
import '../widgets/favorites_dialog.dart';
```

変更後:
```dart
import 'favorites_screen.dart';
```

- [ ] **Step 2: 呼び出し箇所を `showDialog` から `Navigator.push` に変更する**

`lib/screens/shopping_list_screen.dart` の 774〜791行目付近（ハートアイコンの `IconButton`）を変更する。

変更前:
```dart
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'よく買うものから追加',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final count = await showDialog<int>(
                context: context,
                builder: (_) =>
                    FavoritesDialog(currentListId: currentListId),
              );
              if (!mounted) return;
              if (count != null && count > 0) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$count件追加しました')),
                );
              }
            },
          ),
```

変更後:
```dart
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'よく買うものから追加',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final count = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FavoritesScreen(currentListId: currentListId),
                ),
              );
              if (!mounted) return;
              if (count != null && count > 0) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$count件追加しました')),
                );
              }
            },
          ),
```

戻り値の受け渡し方式（`Navigator.pop(context, ids.length)` → 呼び出し元でSnackBar表示）は変更しない。

- [ ] **Step 3: flutter analyze でエラーがないことを確認する**

```
flutter analyze lib/screens/shopping_list_screen.dart lib/screens/favorites_screen.dart
```

期待出力: `No issues found!`

- [ ] **Step 4: flutter test で全体テストが通ることを確認する**

```
flutter test
```

期待出力: 全件 PASS（既存の `test/category_test.dart`・`test/item_test.dart`・`test/backup_test.dart`・Task 1 の `test/favorites_section_helper_test.dart` を含む）

- [ ] **Step 5: コミット**

```bash
git add lib/screens/shopping_list_screen.dart
git commit -m "feat: よく買うものをダイアログから全画面（FavoritesScreen）遷移に変更"
```

---

## Task 4: help_dialog.dart の「よく買うものから追加」説明を更新する

**Files:**
- Modify: `lib/widgets/help_dialog.dart:74-78`

プロジェクトルール「機能を追加・変更・削除したときは必ず `help_dialog.dart` を同時に更新する」に従い、全画面化・カテゴリ別表示・カテゴリ内並べ替えの説明を追記する。

- [ ] **Step 1: `_HelpItem` の description を更新する**

変更前（`lib/widgets/help_dialog.dart` 74〜78行目）:
```dart
            _HelpItem(
              icon: Icons.favorite_border,
              label: 'よく買うものから追加',
              description: 'AppBar右上のハートボタンから定番商品を登録・管理できます。チェックして「リストに追加」を押すと一括追加されます。商品をタップすると価格・個数を編集できます。検索窓で商品名を絞り込むことができます',
            ),
```

変更後:
```dart
            _HelpItem(
              icon: Icons.favorite_border,
              label: 'よく買うものから追加',
              description: 'AppBar右上のハートボタンから、定番商品を管理する画面が開きます（カテゴリ別に一覧表示されます）。チェックして「リストに追加」を押すと一括追加されます。商品をタップすると価格・個数・カテゴリを編集できます。検索窓で商品名を絞り込むことができ、各カテゴリ内はドラッグで並べ替えできます',
            ),
```

- [ ] **Step 2: flutter analyze でエラーがないことを確認する**

```
flutter analyze lib/widgets/help_dialog.dart
```

期待出力: `No issues found!`

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/help_dialog.dart
git commit -m "docs: ヘルプの「よく買うものから追加」説明を全画面・カテゴリ別表示に更新"
```

---

## Task 5: favorites_dialog.dart を削除する

**Files:**
- Delete: `lib/widgets/favorites_dialog.dart`

**影響範囲の確認（Grep 済み）:**

`favorites_dialog.dart` / `FavoritesDialog` を参照している実装ファイルは以下の2件のみ（Task 2・3 で対応済み）。

- `lib/widgets/favorites_dialog.dart`（削除対象そのもの）
- `lib/screens/shopping_list_screen.dart`（Task 3 で `favorites_screen.dart` の import・`FavoritesScreen` 呼び出しに置き換え済み）

`test/widget_test.dart` はスタブ（`void main() {}`）のみで `FavoritesDialog` を参照していない。他に一致するのは `docs/` 配下の設計書・仕様書・レビュー記録のみで、コードからの参照はない（`docs/spec_HKL-001_shopping_list_app_rev8.7.md` は生きた仕様書であり、本タスクでは削除せず参照が残るが、Task 6 で rev8.8 への更新を行う）。

- [ ] **Step 1: Task 2・3 のコミットが完了し、`flutter analyze`／`flutter test` が通っていることを確認する（再掲）**

```
flutter analyze
flutter test
```

期待出力: どちらも 0 エラー・全件 PASS

- [ ] **Step 2: `lib/widgets/favorites_dialog.dart` を削除する**

```bash
git rm lib/widgets/favorites_dialog.dart
```

- [ ] **Step 3: 参照が残っていないことを確認する**

```
grep -rn "favorites_dialog\|FavoritesDialog" lib/
```

期待出力: 一致なし（何も出力されない）

- [ ] **Step 4: flutter analyze・flutter test で最終確認する**

```
flutter analyze
flutter test
```

期待出力: どちらも 0 エラー・全件 PASS

- [ ] **Step 5: コミット**

```bash
git commit -m "chore: 全画面移行が完了した favorites_dialog.dart を削除"
```

---

## Task 6: 生きた仕様書 rev8.7 を rev8.8 に更新する

**Files:**
- Modify: `docs/spec_HKL-001_shopping_list_app_rev8.7.md`

Task 1〜5 の実装完了後に実施する。`FavoritesDialog`（モーダルダイアログ・高さ320px制限・フラット表示）を前提に書かれている記述を、`FavoritesScreen`（全画面・`Navigator.push` 遷移・カテゴリ別セクション表示）の実態に合わせて更新する。ファイル名は変更しない（プロジェクトの命名規則上、rev番号は「変更履歴に新しい行を追加する」運用であり、ファイル名のリネームは対象外。要リネームであればマスターに確認する）。

- [ ] **Step 1: タイトル行・変更履歴に rev8.8 を追加する**

`docs/spec_HKL-001_shopping_list_app_rev8.7.md` 3行目を変更する。

変更前:
```
**Rev 8.7　2026年改訂**
```

変更後:
```
**Rev 8.8　2026年改訂**
```

変更履歴テーブル（9〜26行目）の最終行の直後に1行追加する。日付は実装完了日（コミット日）を記入する。

```
| 8.8 | 2026-XX-XX | よく買うものを全画面表示に変更（`FavoritesDialog` → `FavoritesScreen`、AppBar+`Navigator.push` 遷移）・カテゴリ別セクション表示に対応（カテゴリ内のみドラッグ並べ替え可能、検索中・カテゴリ未登録時は従来どおりフラット表示）・`favorites_dialog.dart` を `favorites_screen.dart` へ統合し前者を削除・ヘルプ更新 |
```

- [ ] **Step 2: ディレクトリ構成（4章）を更新する**

90〜124行目付近のディレクトリ構成から `favorites_dialog.dart` を `widgets/` から削除し、`screens/` 配下に `favorites_screen.dart` を追加する。

変更前:
```
├─ screens/
│   └─ shopping_list_screen.dart
├─ services/
│   └─ backup_service.dart
└─ widgets/
    ├─ add_item_dialog.dart
    ├─ ad_banner.dart
    ├─ category_management_dialog.dart ← 新規
    ├─ favorites_dialog.dart
    ├─ help_dialog.dart
```

変更後:
```
├─ screens/
│   ├─ shopping_list_screen.dart
│   └─ favorites_screen.dart      ← 新規（旧 favorites_dialog.dart を統合）
├─ services/
│   └─ backup_service.dart
└─ widgets/
    ├─ add_item_dialog.dart
    ├─ ad_banner.dart
    ├─ category_management_dialog.dart
    ├─ help_dialog.dart
```

- [ ] **Step 3: 8.11 よく買うもの機能の節を更新する**

533〜553行目付近の見出しと図を更新する。

変更前:
```
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
 └─ 「リストに追加」FilledButton（0件選択時は disabled）
```
```

変更後:
```
#### よく買うもの画面（`favorites_screen.dart`）

AppBar 右上のハートボタンから `Navigator.push` で遷移する独立画面（モーダルダイアログではない）。戻る矢印で閉じ、`Navigator.pop(context, 追加件数)` で呼び出し元へ結果を返す。

```
Scaffold
 ├─ AppBar（タイトル「よく買うもの」・戻る矢印で閉じる）
 ├─ body
 │   ├─ 検索窓（TextField：商品名でリストを絞り込む）
 │   ├─ [全選択 / 全解除] トグルボタン（favorites 0件時は非表示）
 │   └─ 商品一覧（Expanded）
 │       ├─ 0件時：「まだ登録されていません」
 │       ├─ 検索中：カテゴリ分けせずフラットな絞り込みリスト（並べ替え不可）
 │       ├─ カテゴリ未登録：フラット表示（従来どおり、ReorderableListView で並べ替え可能）
 │       └─ カテゴリ1件以上・非検索時：カテゴリ別セクション表示
 │           （カテゴリごとに見出し＋ReorderableListView。カテゴリ内のみ並べ替え可能。
 │            categoryId が null／存在しないカテゴリを指す商品は「カテゴリなし」として最後に表示）
 │       各行：Dismissible（スワイプ左→削除）＋ インライン Undo バナー
 │        └─ ListTile
 │            ├─ leading: Checkbox（タップでチェック切替）
 │            ├─ title: 商品名
 │            ├─ subtitle: ¥価格 × 個数（price=0 なら「数量: N」）
 │            └─ onTap: _EditFavoriteDialog を開く
 └─ bottomNavigationBar
     ├─ 「直接登録」OutlinedButton → _AddFavoriteDialog（favorites_screen.dart 内）
     └─ 「リストに追加」FilledButton（0件選択時は disabled）
```
```

- [ ] **Step 4: DatabaseHelper 追加メソッドの表（559行目以降）に変更がないことを確認する**

`getFavorites`／`insertFavorite`／`updateFavorite`／`deleteFavorite`／`reorderFavorites`／`restoreFavorite`／`addFavoriteItemsToList` はシグネチャ変更なし（データ層は無変更）。表の記載はそのまま維持する。

- [ ] **Step 5: 文書内の他の `favorites_dialog.dart` 参照を検索し、`favorites_screen.dart` に置き換える**

```
grep -n "favorites_dialog" docs/spec_HKL-001_shopping_list_app_rev8.7.md
```

ヒットした箇所を文脈に応じて `favorites_screen.dart` に置き換える（Step 2・3 で対応済みの箇所以外に残っていないか確認する）。

- [ ] **Step 6: コミット**

このタスクはドキュメントのみの変更のため `flutter analyze`／`flutter test` の実行は不要。

```bash
git add docs/spec_HKL-001_shopping_list_app_rev8.7.md
git commit -m "docs: 生きた仕様書を rev8.8 に更新（よく買うもの全画面化・カテゴリ別表示を反映）"
```

---

## 完了確認

- [ ] `flutter analyze` がエラー0件
- [ ] `flutter test` が全件 PASS（`test/favorites_section_helper_test.dart` を含む）
- [ ] `lib/widgets/favorites_dialog.dart` が削除され、参照が残っていない
- [ ] `docs/spec_HKL-001_shopping_list_app_rev8.7.md` が rev8.8 相当の内容に更新されている（Task 6）
- [ ] エミュレーター／実機での目視確認はマスターが別途実施する（本プランには含めない）

---

*作成：2026-07-27　設計書 `docs/superpowers/specs/2026-07-27-favorites-fullscreen-category-design.md`（コミット b9b773d）をもとに作成*
