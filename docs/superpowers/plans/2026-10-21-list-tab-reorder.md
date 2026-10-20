# リスト（タブ）並び替え機能 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lists` テーブルに `sortOrder` を追加してリストの並び順を永続化し、AppBar の「並び替えモード」トグルで水平 `ReorderableListView` によるドラッグ並び替えを可能にする。

**Architecture:** 本プロジェクトは MVVM／Repository 層への分離を行っておらず、`ConsumerStatefulWidget`（`ShoppingListScreen`）が `DatabaseHelper`（シングルトン、Data層相当）を直接呼び、`shoppingLists` はローカル State（Riverpod Provider なし）として `setState`／`loadLists()` で同期する既存パターンを踏襲する。新規の抽象化層（Repository・ViewModel 等）は導入しない（`flutter-apply-architecture-best-practices` の推奨構成は理想だが既存コードが未採用のため、本機能単体でのリファクタは対象外＝YAGNI。2026-08-04-budget-display.md と同じ判断）。UI は `AppBar.bottom` を `ListTabBar` と新規 `ListReorderBar` で切り替えるだけで、`body`（`itemProvider`）のデータフローには触れない。

**Tech Stack:** Flutter 3.44.0（Dart SDK ^3.11.4）／ flutter_riverpod ^3.0.0 ／ sqflite ／ `package:test`（単体テスト）

**Spec:** `docs/superpowers/specs/2026-08-01-list-tab-reorder-design.md`（承認済み、2026-10-21 に版数・行番号を現行コードへ補正済み。以下「設計書」）。実装者は本計画と設計書の両方を読むこと。

## Global Constraints

- DBバージョンは 8 → 9（`lib/database/database_helper.dart` の `_initDB`、現行 38 行目）。
- `lists.sortOrder` は `INTEGER NOT NULL DEFAULT 0`。カラム追加は `ALTER TABLE ... ADD COLUMN` パターン（テーブル再作成は「カラム削除」を伴う場合のみ）。`try { ALTER } catch (_) {}` で既存カラムの場合を握り潰す（`oldVersion < 8` と同形式）。
- 並び替えコールバックは `onReorderItem` を使う（旧 `onReorder` は使わない）。`newIndex` は「削除後の挿入位置」なので `if (newIndex > oldIndex) newIndex--;` の補正は行わない。
- 既存コードの書き方に合わせ、deprecated API（`withOpacity` 等）を使わない。`DropdownButtonFormField` を使う場合は `initialValue`（本機能では使用予定なし）。
- TabBar のジェスチャー（長押しリネーム）は `Tab(child: GestureDetector)` の内側に置く現行構成を変更しない。`list_tab_bar.dart` は変更しない。
- インポート経路（`importData()`）では `sortOrder` をバックアップのメタデータから流用せず、**現在のDB最大値+連番**で採番する。外部JSON由来の整数は `as int` でなく `(num).toInt()`（本機能で新たに外部JSONの整数を読む箇所はない。DBの `MAX()` 結果は設計書どおり既存コードと同じ `as int?`）。
- catch 節でユーザー向けメッセージを返す場合は `e.toString()` を使わず汎用文言（`'並び替えの保存に失敗しました'`）にする。
- 機能追加時は必ず `lib/widgets/help_dialog.dart` も同時更新する（Task 6）。
- 生きた設計書 `docs/spec_HKL-001_shopping_list_app_rev9.0.md` を rev9.1 へ更新する。`docs/_old/` への旧版保存・本文編集・`git mv` によるリネームを**同一コミット**で行う（`updating-rev-numbered-specs` スキル手順。Task 7）。
- `versionCode`／`pubspec.yaml` の version は更新しない（Play Store 提出・機能リリースのタイミングまで更新しない確定ルール）。`Rules.md` のバージョン記載も触らない。
- テストは `package:test` によるモデル・純粋関数の単体テストのみ。`sqflite` 実DB統合テスト基盤（`sqflite_common_ffi` 等）がないため DB 系・ドラッグ操作・Widget テスト（`testWidgets`）は自動化対象外（`test/widget_test.dart` に既存の運用方針あり）。代わりに手動確認チェックリスト（Task 9）をマスターへ依頼する。
- エミュレーター／実機での動作確認は本計画のタスクに含めない（無断で起動しない）。検証は `flutter analyze` ＋ `flutter test` ＋ コードレビュー。
- コミットメッセージは日本語、末尾に `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` を付ける。push はしない。
- サブエージェントに実装を委ねる場合のプロンプトには「Flutter 3.44.0 / Dart ^3.11.4。`onReorderItem` を使用、deprecated API を使わない」を明記する（Rules.md）。ファイル編集はメインセッションから直接 Edit せず Agent（file-editor 等）への委任を先に検討し、編集後は `git status` で対象外ファイルの意図しない変更がないか確認する（Rules.md）。
- git worktree で作業する場合は、着手前に main 側の未コミットファイル（本計画書・設計書）をワークツリー側へコピー・コミットする（Rules.md）。

## Review Focus

設計書が暗に含意しながら各タスクのテストで直接は検証されない入力・失敗モード（可能性の高い順）。自動化できるものは該当タスクにテストを置き、そうでないものは Task 9 の手動確認に載せる。

1. **水平 `ReorderableListView` が `AppBar.bottom` の高さ制約下で正しくレイアウトされること**（高さ未制約による例外・オーバーフロー、10件で横スクロール、長いリスト名のチップ）。設計書の `ListReorderBar` は `SizedBox` で包んでいない。レイアウト例外が出た場合は設計内容を変えずに実装者が判断せず、報告して差し戻す（Task 4 の `flutter analyze` では検出できないため Task 9 手動確認で必ず確認）。
2. **旧バックアップ（`lists[].sortOrder` キーなし）および `sortOrder` が重複・欠番のバックアップのインポート**：キーの有無にかかわらず `sortOrder` は参照せず、現在のDB最大値+連番で採番される（Task 3 のコードレビュー項目、Task 9 手動確認）。
3. **並び替えモード中のリスト追加・複製・削除・インポート**：`loadLists()` が `TabController` を再生成するため、モードを抜けた時点で `TabBar` のハイライトが `currentListId` と一致すること（Task 5 の `_toggleReorderMode` 同期、Task 9 手動確認）。
4. **リストが1件のみ／上限10件**でも並び替えモードが動作し、`ListReorderBar` が空リストで `SizedBox.shrink()` を返すこと（Task 9 手動確認）。
5. **削除により `sortOrder` に欠番が生じた後の新規追加・複製**：`MAX(sortOrder)+1` 採番のため、欠番があっても常に末尾に並ぶこと（Task 3 のコードレビュー項目）。DB更新失敗時は SnackBar＋`loadLists()` で再同期されること（Task 5 のコードレビュー項目。意図的な失敗再現が困難なため設計書 §7.3 に従いコードレビューで代替）。

---

## ファイル一覧（作成・変更対象）

| ファイル | 種別 | 内容 |
|---|---|---|
| `lib/models/shopping_list.dart` | 変更 | `sortOrder` フィールド・`toMap`/`fromMap`/`copyWith` 反映 |
| `test/shopping_list_test.dart` | 変更（**既存ファイルに追記**） | `sortOrder` のモデル単体テスト追加 |
| `lib/database/database_helper.dart` | 変更 | DB v9、`lists.sortOrder` 追加・マイグレーション、`getLists()` の orderBy 変更、`insertList()`／`duplicateList()` 採番、`updateListOrder()` 新規、`importData()` の sortOrder 採番 |
| `lib/widgets/list_reorder_bar.dart` | 新規 | 水平 `ReorderableListView.builder` による並び替えUI |
| `lib/widgets/list_management_buttons.dart` | 変更 | 並び替えトグルボタン追加 |
| `lib/screens/shopping_list_screen.dart` | 変更 | `_isReorderMode`・`_toggleReorderMode()`・`_onReorderList()`・AppBar 分岐 |
| `lib/widgets/help_dialog.dart` | 変更 | 「リストの並び替え」操作説明を追加 |
| `docs/spec_HKL-001_shopping_list_app_rev9.0.md` → `rev9.1.md` | 変更＋リネーム | 生きた設計書の更新 |
| `docs/_old/spec_HKL-001_shopping_list_app_rev9.0.md` | 新規 | 旧版アーカイブ |
| `docs/superpowers/specs/2026-08-01-list-tab-reorder-design.md` | 変更（ステータス行のみ） | 「未実装」→「実装済み」（Task 7 に含める） |
| `docs/code_explanation.md`（＋ `docs/code_explanation_beginner.md` の DB バージョン記述） | 変更 | 最新コードへの追従 |
| `lib/widgets/list_tab_bar.dart` | **変更なし** | — |

### タスク依存関係

```
Task 1 (モデル) → Task 2 (DBスキーマ) → Task 3 (DB CRUD/採番)
Task 1 ─────────────────────────────→ Task 4 (ListReorderBar)
Task 3, Task 4 → Task 5 (ボタン＋画面統合) → Task 6 (ヘルプ)
Task 1〜6 → Task 7 (設計書 rev9.1) → Task 8 (コード解説) → Task 9 (最終検証・手動確認)
```

「DB→モデル→UI→ヘルプ→ドキュメント」の大筋に従うが、`DatabaseHelper` は `ShoppingList.fromMap/toMap` に依存するため、コンパイル依存の都合でモデル（Task 1）を DB（Task 2・3）より先に行う。

---

### Task 1: `ShoppingList` モデルへの `sortOrder` 追加

**依存:** なし（最初に着手する）

**Files:**
- Modify: `lib/models/shopping_list.dart`
- Test: `test/shopping_list_test.dart`（**既に存在する**。予算機能で作成済みの `group('ShoppingList モデル', ...)` に追記する。新規作成・全面置換はしない）

**Interfaces:**
- Produces: `ShoppingList({int? id, required String name, int? createdAt, int budget = 0, int sortOrder = 0})`、`ShoppingList.sortOrder`（`int`、non-nullable）、`toMap()`（`sortOrder` キー含む）、`ShoppingList.fromMap(Map<String, dynamic>)`（`sortOrder` キー欠如・null 時は `0`）、`copyWith({int? id, String? name, int? createdAt, int? budget, int? sortOrder})`
- Task 2・3・4・5 がこれらに依存する。

- [ ] **Step 1: 失敗するテストを追記する**

`test/shopping_list_test.dart` の既存 `group` 内（既存5テストの後ろ）に次のテストを追加する。既存テストは変更しない。

- `test('toMap / fromMap ラウンドトリップ（sortOrder含む）')`：`ShoppingList(id: 1, name: '買い物リスト', createdAt: 1700000000000, budget: 5000, sortOrder: 3)` を `toMap()` → `fromMap()` し、`id`／`name`／`createdAt`／`budget`／`sortOrder`（= 3）がすべて一致する。
- `test('toMap に sortOrder キーが含まれる')`：`expect(list.toMap()['sortOrder'], 3)`。
- `test('sortOrder のデフォルト値は0')`：`ShoppingList(name: 'テストリスト', createdAt: 1700000000000).sortOrder == 0`。
- `test('fromMap で sortOrder キーが存在しない場合は0にフォールバックする')`：`{'id': 1, 'name': 'テストリスト', 'createdAt': 1700000000000}`（`budget` も無し）から復元して `sortOrder == 0` かつ `budget == 0`。
- `test('copyWith: sortOrder のみ更新すると他のフィールドは元の値を保持する')`：`sortOrder: 1, budget: 3000` のリストを `copyWith(sortOrder: 5)` → `sortOrder == 5`、`id`／`name`／`createdAt`／`budget` は元の値。
- `test('copyWith: name のみ更新すると sortOrder は元の値を保持する')`：`sortOrder: 2` のリストを `copyWith(name: '新しいリスト名')` → `sortOrder == 2`。

- [ ] **Step 2: テストを実行し、失敗することを確認する**

Run: `flutter test test/shopping_list_test.dart`
Expected: FAIL（`sortOrder` 名前付き引数・フィールドが存在しないためコンパイルエラー）

- [ ] **Step 3: `lib/models/shopping_list.dart` を実装する**

設計書 §3.2.2 のコードどおりに変更する。`final int sortOrder;` を追加し、コンストラクタに `this.sortOrder = 0`、`toMap()` に `'sortOrder': sortOrder`、`fromMap()` に `sortOrder: map['sortOrder'] ?? 0`、`copyWith()` に `int? sortOrder` と `sortOrder: sortOrder ?? this.sortOrder` を追加する。`budget` 周りは変更しない。

- [ ] **Step 4: テストを実行し、成功することを確認する**

Run: `flutter test test/shopping_list_test.dart`
Expected: PASS（既存5件＋追加6件）

- [ ] **Step 5: 全体に影響がないことを確認する**

Run: `flutter analyze` ／ `flutter test`
Expected: analyze エラーなし、既存テスト（`backup_test.dart` 等）を含め全 PASS

- [ ] **Step 6: コミット**

```bash
git add lib/models/shopping_list.dart test/shopping_list_test.dart
git commit -m "feat: ShoppingListにsortOrderフィールドを追加"
```

（コミットメッセージ末尾に `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` を付ける）

---

### Task 2: `DatabaseHelper` のスキーマ変更（DB v9・マイグレーション）

**依存:** Task 1（`ShoppingList.sortOrder`）

**Files:**
- Modify: `lib/database/database_helper.dart`（`_initDB` 38 行目、`_createDB` の lists 定義 61〜67 行目・初回INSERT 69〜72 行目、`_onUpgrade` 末尾 183〜191 行目の `oldVersion < 8` ブロックの直後）

**Interfaces:**
- Consumes: なし
- Produces: DB v9（`lists.sortOrder INTEGER NOT NULL DEFAULT 0`）。既存行は `createdAt ASC` 順に 0,1,2,… で初期化される。Task 3 が前提とする。

実DBアクセスのため自動テスト対象外（`flutter analyze` による静的検証のみ。手動確認は Task 9）。

- [ ] **Step 1: DBバージョンを 8 → 9 に上げる**

`_initDB` の `openDatabase(... version: 8 ...)` を `version: 9` にする。

- [ ] **Step 2: `_createDB` の `lists` テーブル定義に `sortOrder` を追加する**

`budget INTEGER NOT NULL DEFAULT 0` の後ろに `,\n  sortOrder INTEGER NOT NULL DEFAULT 0` を追加する（設計書 §3.2.1 のとおり）。初回インストール時のデフォルトリスト `db.insert('lists', {...})` に `'sortOrder': 0` を追加する。

- [ ] **Step 3: `_onUpgrade` に `oldVersion < 9` ブロックを追加する**

既存の `if (oldVersion < 8) { ... }` の直後（メソッド閉じ括弧の前）に、設計書 §3.2.1 のブロックを追加する。内容は次の2段階で、コードは設計書のとおり。

1. `try { await db.execute('ALTER TABLE lists ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0'); } catch (_) {}`（既存なら無視）
2. `db.query('lists', orderBy: 'createdAt ASC')` で取得した既存行に対し、`db.transaction` ＋ `batch.update('lists', {'sortOrder': i}, where: 'id = ?', whereArgs: [id])` で 0,1,2,… を設定

- [ ] **Step 4: 静的検証**

Run: `flutter analyze lib/database/database_helper.dart`
Expected: エラー・警告なし

- [ ] **Step 5: コミット**

```bash
git add lib/database/database_helper.dart
git commit -m "feat: listsテーブルにsortOrderカラムを追加しDBバージョンを9へ更新"
```

---

### Task 3: `DatabaseHelper` の CRUD・採番変更

**依存:** Task 2（`lists.sortOrder` カラムが存在すること）

**Files:**
- Modify: `lib/database/database_helper.dart`（`getLists()` 304〜310 行目、`insertList()` 312〜316 行目、`duplicateList()` 361〜389 行目、`importData()` 内 lists INSERT 629〜651 行目、新規メソッド `updateListOrder` は `updateListBudget`（349〜358 行目）の直後に置く）

**Interfaces:**
- Consumes: `ShoppingList.toMap()`（Task 1）
- Produces: `DatabaseHelper.instance.updateListOrder(List<ShoppingList> lists) -> Future<void>`（Task 5 が呼ぶ）。`getLists()` は `sortOrder ASC` 順で返す（`loadLists()`・`BackupService` が依存）。

**影響範囲（Grep 済み）:** `getLists()` の呼び出し元は `lib/screens/shopping_list_screen.dart:57`（`loadLists`）、`lib/services/backup_service.dart:43,106`（エクスポート／リスト共有）のみ。`insertList()` の呼び出し元は `shopping_list_screen.dart:124`（`ShoppingList(name: name)`、`sortOrder` はデフォルト0を渡すが DB 側で採番し直すため問題なし）のみ。`'lists'` への INSERT は `_createDB`／`_onUpgrade`（初回リスト）／`insertList`／`duplicateList`／`importData` の5箇所で、本タスクで `insertList`・`duplicateList`・`importData` を `sortOrder` 採番対応にする（他2箇所は Task 2 でカバー）。

実DBアクセスのため自動テスト対象外。

- [ ] **Step 1: `getLists()` の `orderBy` を `'sortOrder ASC'` に変更する**（設計書 §3.2.3）

- [ ] **Step 2: `insertList(ShoppingList list)` を採番対応にする**

`SELECT MAX(sortOrder) as maxOrder FROM lists` → `(result.first['maxOrder'] as int?) ?? -1`。`list.toMap()..remove('id')..['sortOrder'] = maxOrder + 1` を insert する。戻り値は従来どおり `Future<int>`。呼び出し元が渡す `sortOrder` は無視される。

- [ ] **Step 3: `duplicateList()` のトランザクション内で採番する**

`txn.rawQuery('SELECT MAX(sortOrder) as maxOrder FROM lists')` で最大値を取り、新リストの insert マップに `'sortOrder': maxOrder + 1` を追加する。元リストの items コピー処理は変更しない。

- [ ] **Step 4: `updateListOrder(List<ShoppingList> lists)` を新規追加する**

`updateSortOrders`（257〜274 行目）と同形式のトランザクション＋バッチで、`lists[i].id` の行に `{'sortOrder': i}` を設定する（設計書 §3.2.3 のコードどおり）。

- [ ] **Step 5: `importData()` の lists INSERT を `sortOrder` 採番対応にする**

`maxCreatedAtResult` 取得の直後に `SELECT MAX(sortOrder) as maxOrder FROM lists` を取得し、`int nextListSortOrder = ((... as int?) ?? -1) + 1;` を用意する。ループ内の `txn.insert('lists', {...})` に `'sortOrder': nextListSortOrder++` を追加する。`budget` の `(list['budget'] as num?)?.toInt() ?? 0` と `createdAt` の既存ロジックは変更しない。バックアップ内の `list['sortOrder']` は**読まない**（確定ルール）。

- [ ] **Step 6: 静的検証と既存テスト**

Run: `flutter analyze lib/database/database_helper.dart` → エラー・警告なし
Run: `flutter test` → 全 PASS（`backup_test.dart` の `resolveListName` 等に影響なし）

- [ ] **Step 7: コードレビュー確認（自動テスト不可の代替）**

次を目視確認する：(a) `importData` が `list['sortOrder']` を参照していない、(b) `insertList`／`duplicateList` が欠番があっても `MAX+1` で末尾に追加する、(c) `catch` 節に `e.toString()` を追加していない。

- [ ] **Step 8: コミット**

```bash
git add lib/database/database_helper.dart
git commit -m "feat: リストのsortOrder順取得・採番・updateListOrderを追加しインポート時も再採番"
```

---

### Task 4: `ListReorderBar` ウィジェット新規作成

**依存:** Task 1（`ShoppingList`）。Task 2・3 とは独立して着手可能。

**Files:**
- Create: `lib/widgets/list_reorder_bar.dart`

**Interfaces:**
- Produces: `ListReorderBar({super.key, required List<ShoppingList> shoppingLists, required Future<void> Function(int oldIndex, int newIndex) onReorder})`（`PreferredSizeWidget`、`preferredSize` は `Size.fromHeight(kToolbarHeight)`）。Task 5 が `AppBar.bottom` に渡す。

自動テストは追加しない（Widget テストは対象外、Global Constraints 参照）。

- [ ] **Step 1: ウィジェットを新規作成する**

設計書 §3.1.3 のコードどおりに `lib/widgets/list_reorder_bar.dart` を作成する。固定すべき点：

- `shoppingLists.isEmpty` のとき `SizedBox.shrink()` を返す。
- `ReorderableListView.builder(scrollDirection: Axis.horizontal, buildDefaultDragHandles: false, itemCount: shoppingLists.length, onReorderItem: (oldIndex, newIndex) => onReorder(oldIndex, newIndex), ...)`（`onReorder` は使わない、index 補正をしない）。
- 各行は `Padding(key: ValueKey(list.id), padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8))` ＞ `ReorderableDragStartListener(index: index, child: Chip(avatar: Icon(Icons.drag_handle, size: 18), label: Text(list.name)))`。
- `preferredSize` は `ListTabBar` と同じ `Size.fromHeight(kToolbarHeight)`。

- [ ] **Step 2: 静的検証**

Run: `flutter analyze lib/widgets/list_reorder_bar.dart`
Expected: エラー・警告なし（`onReorderItem` が Flutter 3.44.0 に存在するため警告なし。`lib/widgets/list_section.dart` 65 行目と同じ使い方）

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/list_reorder_bar.dart
git commit -m "feat: ListReorderBarウィジェットを新規追加"
```

---

### Task 5: `ListManagementButtons` と `ShoppingListScreen` の統合

**依存:** Task 3（`updateListOrder`、`sortOrder` 順の `getLists()`）、Task 4（`ListReorderBar`）

`ListManagementButtons` に必須引数を追加すると呼び出し元（`ShoppingListScreen`）がコンパイルエラーになるため、両者を1タスク・1コミットで変更する。

**Files:**
- Modify: `lib/widgets/list_management_buttons.dart`
- Modify: `lib/screens/shopping_list_screen.dart`（import 群 9〜28 行目、State フィールド 37〜47 行目、`_showRenameListDialog` 444 行目付近、`_handleTabChange` 485 行目、`AppBar.actions` 794〜798 行目、`AppBar.bottom` 921〜925 行目）

**Interfaces:**
- Consumes: `ListReorderBar`（Task 4）、`DatabaseHelper.instance.updateListOrder(List<ShoppingList>)`（Task 3）
- Produces: `ListManagementButtons({required VoidCallback onAddList, required VoidCallback onDuplicateList, required VoidCallback onToggleReorderMode, required bool isReorderMode})`、`_ShoppingListScreenState._isReorderMode`、`_toggleReorderMode()`、`_onReorderList(int, int)`

**影響範囲（Grep 済み）:** `ListManagementButtons` の使用箇所は `shopping_list_screen.dart:795` の1箇所のみ。`ListTabBar` は 921 行目の1箇所のみ（本タスクで分岐の片側に残す）。

- [ ] **Step 1: `ListManagementButtons` にトグルボタンを追加する**

設計書 §3.1.1 のとおり、`onToggleReorderMode`（`VoidCallback`）・`isReorderMode`（`bool`）を必須引数に追加し、「複製」ボタンの後ろに3つ目の `IconButton` を置く。アイコンは `Icons.reorder` 固定、`isReorderMode` のとき `Theme.of(context).colorScheme.primary` で着色、tooltip は `isReorderMode ? '並び替えを終了' : 'リストを並び替え'`。

- [ ] **Step 2: `ShoppingListScreen` に import と State を追加する**

`import '../widgets/list_reorder_bar.dart';` を `list_management_buttons.dart` の import の近くに追加し、State フィールドに `bool _isReorderMode = false;` を追加する。

- [ ] **Step 3: `_toggleReorderMode()` を追加する**

設計書 §3.1.4 のコードどおり（`setState` でトグル → モードを OFF にしたとき `shoppingLists.indexWhere((e) => e.id == currentListId)` と `_tabController!.index` が食い違えば `_tabController!.animateTo(index)`）。配置は `_showRenameListDialog` の近く。

- [ ] **Step 4: `_onReorderList(int oldIndex, int newIndex)` を追加する**

設計書 §3.1.4 のコードどおり、`Future<void>` で次の順に実装する。

1. `[...shoppingLists]` をコピーして `removeAt(oldIndex)` → `insert(newIndex, moved)`（index 補正なし）
2. `setState(() => shoppingLists = reordered)`（楽観的更新）
3. `try { await DatabaseHelper.instance.updateListOrder(reordered); } catch (_) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('並び替えの保存に失敗しました'))); await loadLists(); }`（`e.toString()` は使わない）

- [ ] **Step 5: AppBar の `actions` と `bottom` を変更する**

`ListManagementButtons(...)` に `onToggleReorderMode: _toggleReorderMode`、`isReorderMode: _isReorderMode` を渡す。`bottom:` は `_isReorderMode ? ListReorderBar(shoppingLists: shoppingLists, onReorder: _onReorderList) : ListTabBar(shoppingLists: shoppingLists, tabController: _tabController, onRenameTab: _showRenameListDialog)` に変更する（設計書 §3.1.4）。`ListTabBar` 側のコードは変更しない。`body` は変更しない。

- [ ] **Step 6: 静的検証とテスト**

Run: `flutter analyze` ／ `flutter test`
Expected: エラーなし／全 PASS

- [ ] **Step 7: コードレビュー確認**

次を目視確認する：(a) `onReorderItem` 以外の並び替えコールバック・`withOpacity` 等の deprecated API を使っていない、(b) `_toggleReorderMode` が `_tabController != null` を確認している、(c) `catch` 節が汎用文言のみ、(d) `list_tab_bar.dart` に差分がない（`git diff --stat` で確認）。

- [ ] **Step 8: コミット**

```bash
git add lib/widgets/list_management_buttons.dart lib/screens/shopping_list_screen.dart
git commit -m "feat: AppBarにリスト並び替えモードを追加しListReorderBarと統合"
```

---

### Task 6: `help_dialog.dart` の更新

**依存:** Task 5（機能が実装済みであること）

**Files:**
- Modify: `lib/widgets/help_dialog.dart`（「リストを追加」の項目 49〜53 行目と「リストを削除」の項目 54〜58 行目の間）

**Interfaces:** なし（表示文言のみ）

- [ ] **Step 1: `_HelpItem` を挿入する**

「リストを追加」（`Icons.playlist_add`）と「リストを削除」（`Icons.delete_outline`）の間に、設計書 §6 のとおり次を追加する。周囲の `_HelpItem` の書式（`const` の有無・インデント）に揃える。

- `icon: Icons.reorder`
- `label: 'リストの並び替え'`
- `description`：`'AppBar右上の並び替えボタン（≡アイコン）をタップすると並び替えモードになります\n表示されたハンドルをドラッグして順番を変更できます。再度ボタンを押すと通常表示に戻ります'`（2026-10-21 マスター指示によりアイコン表記を実際の Icons.reorder に合わせて ⇅ から ≡ へ補正済み）

- [ ] **Step 2: 静的検証**

Run: `flutter analyze lib/widgets/help_dialog.dart`
Expected: エラー・警告なし

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/help_dialog.dart
git commit -m "docs: ヘルプにリストの並び替えの操作説明を追加"
```

---

### Task 7: 生きた設計書 rev9.0 → rev9.1 への更新

**依存:** Task 1〜6（実装内容を正しく反映するため、実装完了後に着手する）

**Files:**
- Create: `docs/_old/spec_HKL-001_shopping_list_app_rev9.0.md`（旧版アーカイブ）
- Modify → Rename: `docs/spec_HKL-001_shopping_list_app_rev9.0.md` → `docs/spec_HKL-001_shopping_list_app_rev9.1.md`
- Modify: `docs/superpowers/specs/2026-08-01-list-tab-reorder-design.md`（5 行目のステータス表記のみ）

`updating-rev-numbered-specs` スキルの手順に従う。**本文編集とリネームは同一コミット**。設計書内の「リスト」「タブ」表記は、ユーザー向け機能説明は「リスト」、実装名（`TabBar`／`ListTabBar`／`TabController`）は据え置く（Rules.md の用語統一基準）。

- [ ] **Step 1: 旧版を `docs/_old/` へコピーする**

```bash
cp "docs/spec_HKL-001_shopping_list_app_rev9.0.md" "docs/_old/spec_HKL-001_shopping_list_app_rev9.0.md"
```

- [ ] **Step 2: リネームする**

```bash
git mv "docs/spec_HKL-001_shopping_list_app_rev9.0.md" "docs/spec_HKL-001_shopping_list_app_rev9.1.md"
```

- [ ] **Step 3: 本文を更新する（`rev9.1.md`）**

更新対象節（現行 rev9.0 の行番号は目安。Grep で再確認してから編集する）：

1. 3 行目 `**Rev 9.0　2026年改訂**` → `**Rev 9.1　2026年改訂**`
2. 変更履歴テーブル（35 行目の 9.0 行の直後）に `9.1 | 2026-10-21` 以降の実施日 | リスト並び替え機能の追加（`lists.sortOrder`・DB v9・`ListReorderBar`・並び替えモード・`getLists()` の sortOrder 順化・`insertList`/`duplicateList`/`importData` の採番）を 1 行追加（日付は実際のコミット日）
3. §4 ディレクトリ構成（widgets/ の `list_section.dart` の近く）に `list_reorder_bar.dart  ← 新規` を追加
4. §5.1 機能一覧に「リストの並び替え」行を追加（AppBar の並び替えボタンで並び替えモードに入りドラッグで変更）。「リスト切替 | TabBar」行は据え置く
5. §5.2 UI構成の AppBar に「並び替えボタン（並び替えモードのトグル）」を追加し、`TabBar` の行に「並び替えモード中は `ListReorderBar` に切り替わる」旨を追記
6. §6.2 lists テーブルに `sortOrder | INTEGER | 表示順（NOT NULL DEFAULT 0。DB v9追加。小さいほど左）` を追加
7. §8.10 複数リスト機能：表に「並び替え」行を追加し、`#### 並び替えモード` 小節（設計書 §2.2・§3.1・§3.3 の要点：`_isReorderMode`、`AppBar.bottom` の差し替え、`onReorderItem`、楽観的更新＋失敗時 `loadLists()` 再同期、モード終了時の `TabController` 同期）を追加。「起動時のリスト選択」の記述 `data.first.id`（`createdAt` が最も古い＝一番左）を **`sortOrder` が最小＝一番左** に修正
8. §8.12 バックアップ形式：`lists` の JSON 例に `"sortOrder": 0` を追加し（`toMap()` 経由で出力されるため）、インポート処理フローの lists 行に「`sortOrder` は現在のDB最大値+連番で再採番（バックアップ内の値は使わない）」を追記
9. §9.2 ShoppingList：フィールドに `sortOrder` を含む旨と `copyWith()` の説明（budget・sortOrder 含む）を更新。§9.3 DatabaseHelper に `updateListOrder()` を追記
10. §10 DBバージョン管理：`| version 9 | lists に sortOrder カラム追加（NOT NULL DEFAULT 0。既存行は createdAt 昇順で 0,1,2,… を初期セット） |` を追加
11. §11 sortOrder 採番ルール：lists の行を追加（`insertList()`／`duplicateList()`／`importData()` は `MAX(sortOrder)+1`（import は連番）、並び替え時は `updateListOrder()` で全件再採番）
12. §16 現在の特徴まとめに「リストの並び替え（並び替えモード）」を追加

- [ ] **Step 4: 古いリビジョンへの自己言及が残っていないか確認する**

Run: `grep -n "rev9.0\|Rev 9.0\|9\.0" docs/spec_HKL-001_shopping_list_app_rev9.1.md`
Expected: 変更履歴の 9.0 行および §8.9 の歴史的記述（「Rev 9.0 で追加した『よく買うもの候補』」）など**過去リビジョンの履歴としての言及のみ**が残り、現行リビジョンの自己言及は残っていない。

- [ ] **Step 5: 承認済み設計書のステータス行を更新する**

`docs/superpowers/specs/2026-08-01-list-tab-reorder-design.md` の 5 行目「設計承認済み・未実装…」を「実装済み」である旨に改める（設計内容は変更しない）。

- [ ] **Step 6: 差分の範囲確認とコミット**

Run: `git status`（想定外のファイルが含まれていないこと）

```bash
git add "docs/_old/spec_HKL-001_shopping_list_app_rev9.0.md" "docs/spec_HKL-001_shopping_list_app_rev9.1.md" docs/superpowers/specs/2026-08-01-list-tab-reorder-design.md
git commit -m "docs: 設計書をrev9.1へ更新（リスト並び替え機能を反映）"
```

---

### Task 8: `docs/code_explanation.md` の更新

**依存:** Task 1〜6（実装完了後。Task 7 と並行可）

**Files:**
- Modify: `docs/code_explanation.md`
- Modify: `docs/code_explanation_beginner.md`（345 行目「DBバージョンは現在 **8** です」の記述と、`lists` の CREATE TABLE（362 行目付近）のみ。他は触らない）

小規模な追従更新のため、調査専用エージェントを挟まず `git diff <Task 1 の直前>..HEAD -- lib` を根拠に実コードで裏取りしながら更新する。

- [ ] **Step 1: `code_explanation.md` を更新する**

対象節（行番号は目安）：

1. アーキテクチャ全体像（12 行目 `shopping_list.dart` 注記に `sortOrder` 追記、`widgets/` ツリー（35〜37 行目付近）に `list_reorder_bar.dart  # 並び替えモード用の水平並び替えバー` を追加、`list_management_buttons.dart` の説明を「追加・複製・並び替えトグル」に更新）
2. §4 `models/shopping_list.dart`（140 行目〜）：`sortOrder` フィールドと `copyWith`／`fromMap` の `?? 0` フォールバックを追記
3. §5 `database/database_helper.dart`（164 行目〜）：`lists` テーブル説明（184 行目付近）に `sortOrder`、`version < 9` マイグレーション（ALTER＋createdAt 順の初期連番）、`getLists()` の `sortOrder ASC`、`insertList`／`duplicateList` の `MAX+1` 採番、新規 `updateListOrder`、`importData` の `sortOrder` 採番を追記。**349 行目付近の「`getLists()` は `orderBy: 'createdAt ASC'`…」の説明は事実と異なるため書き換える**（並び順は `sortOrder`、インポートのリストは `createdAt` 連番に加え `sortOrder` 連番で末尾に並ぶ）
4. §11 `screens/shopping_list_screen.dart`（575 行目〜）：`_isReorderMode`、`_toggleReorderMode`（`TabController` 同期）、`_onReorderList`（楽観的更新＋失敗時再同期）、`AppBar.bottom` の分岐を追記
5. §18 `list_tab_bar.dart`（1060 行目〜）：変更なしだが、並び替えモード中は描画されない旨を一言追記
6. §19 `list_management_buttons.dart`（1076 行目〜）：見出し・コード抜粋・説明を3ボタン構成に更新
7. §19 と §20 の間に `widgets/list_reorder_bar.dart` の節を追加し、以降の節番号とデータフロー節の参照があれば整合させる
8. 「データフロー全体像」（1286 行目〜）に並び替えのフロー（`ListReorderBar` → `_onReorderList` → `updateListOrder`）を追記

- [ ] **Step 2: `code_explanation_beginner.md` を最小限更新する**

DBバージョン記述を 9 に更新し、「リスト並び替えを追加した際に 8 から 9 へ上がり、`lists` に `sortOrder` が追加された」旨を追記する。`lists` の CREATE TABLE 例に `sortOrder` 列を足す。

- [ ] **Step 3: ナレッジベース影響確認（コミット前）**

`lib/widgets/ad_banner.dart`・`lib/services/backup_service.dart` は本機能で変更していないため、`docs/knowledge_base/reusable_patterns/` の更新は**不要**であることを `git diff --stat` で確認する。`docs/knowledge_base/` に新規文書は追加しない（手動確認結果の記録が必要になった場合のみ、マスター確認の上 `list-reorder/` を新設して索引に追記する）。

- [ ] **Step 4: 差分の範囲確認とコミット**

Run: `git status`（`docs/code_explanation*.md` 以外に変更がないこと）

```bash
git add docs/code_explanation.md docs/code_explanation_beginner.md
git commit -m "docs: リスト並び替え機能に合わせてコード解説を更新"
```

---

### Task 9: 最終検証・手動確認チェックリスト

**依存:** Task 1〜8 すべて完了後

**Files:** なし（検証のみ）

- [ ] **Step 1: 静的解析**

Run: `flutter analyze`
Expected: エラーなし

- [ ] **Step 2: 全自動テスト**

Run: `flutter test`
Expected: 全 PASS（`test/shopping_list_test.dart` の追加6件を含む）

- [ ] **Step 3: 変更範囲の最終確認**

Run: `git diff --stat <実装開始前のコミット>..HEAD`
Expected: ファイル一覧表のファイルのみ。`lib/widgets/list_tab_bar.dart`・`pubspec.yaml`・`lib/services/backup_service.dart` に差分がないこと。

- [ ] **Step 4: 手動確認チェックリストをマスターに依頼する**

sqflite 実DB・実機UI・ドラッグ操作を伴い自動化対象外のため、マスターの実機確認を依頼する（エミュレーターは無断起動しない。ADB ではドラッグ操作を再現できない）。

```
- [ ] 並び替えモードON/OFFの切り替えで AppBar の高さが変化しないこと
- [ ] 並び替えモードONで水平チップ列が例外・オーバーフローなく表示されること（Review Focus 1）
- [ ] ドラッグでリストの並び順を変更後、アプリを再起動しても順序が保持されること
- [ ] 並び替えモード中に商品一覧（body）の表示が変化しないこと（直前に選択していたリストの中身が表示され続ける）
- [ ] 並び替えモードをOFFにした直後、TabBar のハイライトが currentListId のタブと一致すること
- [ ] リストが1件のみの場合・10件（上限）の場合でも並び替えモードが問題なく動作すること
- [ ] 並び替え後に新規リストを追加／複製すると、右端（末尾）に追加されること
- [ ] 並び替えモード中にリストの追加・複製・削除・インポートを行っても、モードOFF後に TabBar の選択がずれないこと
- [ ] 並び替え後のバックアップ→インポートで、取り込まれたリストが既存リストの右側（末尾）に並ぶこと
- [ ] sortOrder キーを含まない旧バックアップをインポートしても例外にならず、リストが末尾に追加されること
- [ ] 既存DB（version 8）を持つ端末で起動し、sortOrder カラムが自動追加され、既存リストの並び順が従来の作成順のままであること（マイグレーション確認）
- [ ] ヘルプ画面に「リストの並び替え」が「リストを追加」と「リストを削除」の間に表示されること
- [ ] DB更新失敗時の SnackBar／再同期は意図的に再現困難なため、_onReorderList の try/catch ロジックのコードレビューで代替（設計書 §7.3）
```

- [ ] **Step 5: 完了報告**

Task 1〜8 のコミットハッシュ、`flutter analyze`／`flutter test` の結果、手動確認チェックリストの依頼をまとめてマスターへ報告する。versionCode は更新していないこと、push していないことを明記する。

---

## Self-Review 記録

**1. Spec coverage:**
- §3.1.1 `ListManagementButtons` → Task 5 Step 1
- §3.1.2 `ListTabBar` 変更なし → Task 5 Step 7(d)・Task 9 Step 3
- §3.1.3 `ListReorderBar` → Task 4
- §3.1.4 `ShoppingListScreen`（State・AppBar 分岐・トグル・並び替え処理） → Task 5 Step 2〜5
- §3.2.1 DBスキーマ（v9・`_createDB`・初回INSERT・`_onUpgrade`） → Task 2
- §3.2.2 モデル → Task 1
- §3.2.3 CRUD（`getLists`・`insertList`・`updateListOrder`・`duplicateList`・`importData`） → Task 3
- §3.3 Provider/State 同期（TabController 同期・State と DB 同期） → Task 5 Step 3・4
- §5 エラーハンドリング → Task 5 Step 4・7
- §6 ヘルプ更新／生きた設計書更新／インポート確定ルール → Task 6／Task 7／Task 3 Step 5
- §7.2 自動テスト（モデル層） → Task 1。§7.3 DB・ドラッグは自動化対象外 → Global Constraints／Task 9 Step 4
- §8 変更ファイル一覧 → ファイル一覧表と一致（`list_tab_bar.dart` 変更なし）
- 追加（設計書外の周辺更新）：`docs/code_explanation.md`（Task 8）、設計書ステータス行（Task 7 Step 5）

**2. Step scan:** 「TBD」「適切に処理」等の内容のないステップなし。コード本文は設計書 §3 のコード例を参照するステップではファイル・行・固定すべき値を明記した。

**3. Type consistency:** `ShoppingList(…, int sortOrder = 0)`（Task 1）→ `updateListOrder(List<ShoppingList>) -> Future<void>`（Task 3）→ `ListReorderBar.onReorder: Future<void> Function(int, int)`（Task 4）→ `_onReorderList(int, int) -> Future<void>`（Task 5）→ `ListManagementButtons(onToggleReorderMode: VoidCallback, isReorderMode: bool)`（Task 5）で一貫。

**4. Review Focus:** 5項目を冒頭に列挙し、各項目の検証先（Task 3 Step 7・Task 5 Step 7・Task 9 Step 4）を明記した。

**5. Proportion:** 設計書のコード例を再掲せず、ファイル・シグネチャ・固定値と設計書節番号で指示する形にして計画の長さを抑えた。
