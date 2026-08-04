# リストごとの予算表示機能 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ShoppingList` に `budget`（int、デフォルト0）を追加し、DB永続化・`BudgetSummary` ウィジェット表示・タップでの予算入力ダイアログを実装する。付随して `TotalSummary`（未購入合計／購入済合計）を0円時ハイフン表示に統一する。

**Architecture:** 本プロジェクトは MVVM／Repository 層への分離は行っておらず、`ConsumerStatefulWidget`（`ShoppingListScreen`）が `DatabaseHelper`（シングルトン、Data層相当）を直接呼び出し、`setState`／`loadLists()` 再取得でローカル State を同期する既存パターンを踏襲する（`_showRenameListDialog` と同一の流れ）。新規の抽象化層（Repository・ViewModel等）は導入しない。理由：本機能は単一モデルへの1フィールド追加・既存CRUDパターンの横展開であり、既存コードベースの一貫性を優先するため（`flutter-apply-architecture-best-practices` の推奨レイヤー構成は理想だが、既存コードが未採用のため本機能単体でのリファクタは対象外＝YAGNI）。

**Tech Stack:** Flutter 3.44.0 / flutter_riverpod / sqflite / intl（`NumberFormat`）/ `package:test`（単体テスト）

## Global Constraints

- DBバージョンは 7 → 8（`lib/database/database_helper.dart`）。
- `budget` は `int` 非nullable・デフォルト0。「未設定」概念は持たず、0円＝未設定として扱う（`int?` にはしない）。
- catch節でユーザー向けメッセージを返す場合は `e.toString()` を使わず汎用文言にする（プロジェクト確定ルール）。
- 外部JSON由来の整数値は `as int` でなく `(num).toInt()` でキャストする（プロジェクト確定ルール、`Rules_Flutter_RN.md`）。
- 機能追加・変更時は必ず `lib/widgets/help_dialog.dart` も同時更新する（プロジェクト確定ルール）。
- 生きた設計書 `docs/spec_HKL-001_shopping_list_app_rev8.13.md` を rev8.14 へ更新する（`docs/_old/` への旧版保存・本文編集・`git mv` によるリネームを同一コミットで行う。`updating-rev-numbered-specs` スキル手順に従う）。
- テストは `package:test` によるモデル・純粋関数の単体テストのみ。`sqflite` の実DB統合テストは行わない。Widget テスト（`testWidgets`）はこのプロジェクトでは自動化対象外（`test/widget_test.dart` に既存の明示的な運用方針あり、下記「テスト方針の注記」参照）。
- エミュレーター／実機での動作確認は本計画のタスクに含めない。検証は `flutter analyze` ＋ `flutter test` ＋ コードレビューで行い、実機確認が必要な項目は「手動確認チェックリスト」（Task 8）としてマスターに依頼する。

### テスト方針の注記（設計書との差分）

設計書 §7.3 は `BudgetSummary` の表示ロジック（0円→「予算 -」）と `TotalSummary` の0円ハイフン表示を「ウィジェットテスト」として自動化する方針を示している。しかし本プロジェクトの `test/widget_test.dart` には次の既存の運用方針が明記されている。

```dart
// Widget tests は実機 / エミュレーターで flutter test を実行してください。
// ロジックの単体テストは test/item_test.dart にあります。

void main() {}
```

また、既存の類似機能（`item_tile.dart` の単価0円時「単価: -」表示、rev8.12で導入済み）についても、`test/` 配下に対応する自動テストは存在しない（`grep` で確認済み、該当ロジックのテストは0件）。マスターから本計画作成時に「テストは package:test によるモデル・純粋関数の単体テストのみで…（`flutter test`で実行可能な範囲のみを自動テストのタスクにしてください）」という明示的な制約が示されており、これは上記の既存運用方針と整合する。

したがって本計画では、`BudgetSummary`／`TotalSummary` の表示ロジック自体を検証する `testWidgets` ベースの自動テストは**追加しない**（設計書 §7.3 からの意図的な逸脱）。代わりに、設計書 §7.4 に列挙された手動確認項目をそのまま Task 8 の「手動確認チェックリスト」として引き継ぎ、マスターへ確認を依頼する形にする。`ShoppingList` モデルの `toMap`/`fromMap`/`copyWith`（§7.2）は `package:test` で自動化する（Task 1）。

---

## ファイル一覧（作成・変更対象）

| ファイル | 種別 | 内容 |
|---|---|---|
| `lib/models/shopping_list.dart` | 変更 | `budget` フィールド・`copyWith` 追加 |
| `test/shopping_list_test.dart` | 新規 | `ShoppingList` モデルの単体テスト |
| `lib/database/database_helper.dart` | 変更 | DBバージョン8、`budget` カラム追加・マイグレーション、`updateListBudget()`、`importData()` の `budget` キャスト対応 |
| `lib/widgets/budget_summary.dart` | 新規 | `BudgetSummary` ウィジェット |
| `lib/widgets/total_summary.dart` | 変更 | 0円時ハイフン表示（§8付随変更） |
| `lib/screens/shopping_list_screen.dart` | 変更 | `_BudgetInputDialog`・`_showBudgetInputDialog()` 追加、`BudgetSummary` 配置 |
| `lib/widgets/help_dialog.dart` | 変更 | 予算設定の操作説明を追加 |
| `docs/spec_HKL-001_shopping_list_app_rev8.13.md` → `rev8.14.md` | 変更＋リネーム | 生きた設計書の更新 |
| `docs/_old/spec_HKL-001_shopping_list_app_rev8.13.md` | 新規 | 旧版アーカイブ |

---

### Task 1: `ShoppingList` モデルへの `budget` フィールド・`copyWith` 追加

**依存:** なし（最初に着手する）

**Files:**
- Modify: `lib/models/shopping_list.dart`
- Test: `test/shopping_list_test.dart`（新規）

**Interfaces:**
- Produces: `ShoppingList({int? id, required String name, int? createdAt, int budget = 0})`、`ShoppingList.budget`（`int`、non-nullable）、`ShoppingList.copyWith({int? id, String? name, int? createdAt, int? budget})`、`ShoppingList.toMap()`（`budget` キー含む）、`ShoppingList.fromMap(Map<String, dynamic>)`（`budget` キー欠如時は `0` にフォールバック）
- 後続タスク（Task 2, 5）はこれらのシグネチャに依存する。

- [ ] **Step 1: 失敗するテストを書く**

`test/shopping_list_test.dart` を新規作成する。

```dart
import 'package:test/test.dart';
import 'package:shopping_list_app/models/shopping_list.dart';

void main() {
  group('ShoppingList モデル', () {
    test('toMap / fromMap ラウンドトリップ（budget含む）', () {
      final list = ShoppingList(
        id: 1,
        name: '買い物リスト',
        createdAt: 1700000000000,
        budget: 5000,
      );
      final map = list.toMap();
      final restored = ShoppingList.fromMap(map);

      expect(restored.id, list.id);
      expect(restored.name, list.name);
      expect(restored.createdAt, list.createdAt);
      expect(restored.budget, list.budget);
    });

    test('budget のデフォルト値は0', () {
      final list = ShoppingList(name: 'テストリスト', createdAt: 1700000000000);
      expect(list.budget, 0);
    });

    test('fromMap で budget キーが存在しない場合は0にフォールバックする', () {
      final map = {
        'id': 1,
        'name': 'テストリスト',
        'createdAt': 1700000000000,
      };
      final restored = ShoppingList.fromMap(map);
      expect(restored.budget, 0);
    });

    test('copyWith: budget のみ更新すると他のフィールドは元の値を保持する', () {
      final list = ShoppingList(
        id: 1,
        name: '買い物リスト',
        createdAt: 1700000000000,
        budget: 3000,
      );
      final updated = list.copyWith(budget: 8000);

      expect(updated.budget, 8000);
      expect(updated.id, list.id);
      expect(updated.name, list.name);
      expect(updated.createdAt, list.createdAt);
    });

    test('copyWith: name のみ更新すると budget は元の値を保持する', () {
      final list = ShoppingList(
        id: 1,
        name: '買い物リスト',
        createdAt: 1700000000000,
        budget: 3000,
      );
      final updated = list.copyWith(name: '新しいリスト名');

      expect(updated.name, '新しいリスト名');
      expect(updated.budget, 3000);
      expect(updated.id, list.id);
      expect(updated.createdAt, list.createdAt);
    });
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

Run: `flutter test test/shopping_list_test.dart`
Expected: コンパイルエラーで FAIL（`ShoppingList` に `budget` 名前付き引数・`copyWith` が存在しないため）

- [ ] **Step 3: 最小限の実装を書く**

`lib/models/shopping_list.dart` を以下の内容で全面置換する。

```dart
class ShoppingList {
  final int? id;
  final String name;
  final int createdAt;
  final int budget;

  ShoppingList({
    this.id,
    required this.name,
    int? createdAt,
    this.budget = 0,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'budget': budget,
    };
  }

  factory ShoppingList.fromMap(Map<String, dynamic> map) {
    return ShoppingList(
      id: map['id'],
      name: map['name'],
      createdAt: map['createdAt'],
      budget: map['budget'] ?? 0,
    );
  }

  ShoppingList copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? budget,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      budget: budget ?? this.budget,
    );
  }
}
```

- [ ] **Step 4: テストを実行し、成功することを確認する**

Run: `flutter test test/shopping_list_test.dart`
Expected: PASS（5件すべて）

- [ ] **Step 5: 既存のテスト全体に影響がないことを確認する**

Run: `flutter test`
Expected: 既存テスト（`item_test.dart`／`category_test.dart`／`backup_test.dart`／`favorites_section_helper_test.dart`／`purchase_resolution_test.dart`）を含めすべて PASS

- [ ] **Step 6: コミット**

```bash
git add lib/models/shopping_list.dart test/shopping_list_test.dart
git commit -m "feat: ShoppingListにbudgetフィールドとcopyWithを追加"
```

---

### Task 2: `DatabaseHelper` のDBバージョン8対応

**依存:** Task 1（`ShoppingList.fromMap`/`toMap` に `budget` が存在すること。`DatabaseHelper.getLists()` は内部で `ShoppingList.fromMap` を使うため）

**Files:**
- Modify: `lib/database/database_helper.dart`

**Interfaces:**
- Consumes: `ShoppingList`（Task 1、`toMap`/`fromMap` に `budget` を含む）
- Produces: `DatabaseHelper.instance.updateListBudget(int listId, int budget) -> Future<void>`（Task 5 が呼び出す）

このタスクは `sqflite` の実DBアクセスを伴うため、Global Constraints記載の通り自動テストの対象外とする（`flutter analyze` による静的検証のみ）。手動確認項目は Task 8 にまとめる。

- [ ] **Step 1: DBバージョンを7から8へ上げる**

`lib/database/database_helper.dart` の `_initDB` を変更する。

現在の内容（36〜42行目付近）:

```dart
    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
```

変更後:

```dart
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
```

- [ ] **Step 2: `_createDB` の `lists` テーブル定義に `budget` カラムを追加する**

現在の内容（60〜66行目付近）:

```dart
    await db.execute('''
CREATE TABLE lists(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  createdAt INTEGER
)
''');
```

変更後:

```dart
    await db.execute('''
CREATE TABLE lists(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  createdAt INTEGER,
  budget INTEGER NOT NULL DEFAULT 0
)
''');
```

直後の初回リストINSERT（68〜71行目付近）は変更不要（`budget` カラムのDBデフォルト値0が自動適用されるため）。

- [ ] **Step 3: `_onUpgrade` に `oldVersion < 8` のマイグレーションを追加する**

`_onUpgrade` メソッド内、`if (oldVersion < 7) { ... }` ブロック（既存の最後のバージョン分岐）の直後・メソッドの閉じ括弧の直前に追加する。

現在の該当箇所（163〜181行目付近、末尾）:

```dart
    if (oldVersion < 7) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
      for (final sql in [
        'ALTER TABLE items ADD COLUMN categoryId INTEGER',
        'ALTER TABLE favorites ADD COLUMN categoryId INTEGER',
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }
  }
```

変更後（`if (oldVersion < 8)` ブロックを追加）:

```dart
    if (oldVersion < 7) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
      for (final sql in [
        'ALTER TABLE items ADD COLUMN categoryId INTEGER',
        'ALTER TABLE favorites ADD COLUMN categoryId INTEGER',
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE lists ADD COLUMN budget INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // カラムが既に存在する場合は無視
      }
    }
  }
```

- [ ] **Step 4: `updateListBudget()` を追加する**

`updateListName()`（327〜336行目付近）の直後に追加する。

現在の該当箇所:

```dart
  Future<void> updateListName(int listId, String newName) async {
    final db = await database;

    await db.update(
      'lists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }
```

変更後（メソッドを追加）:

```dart
  Future<void> updateListName(int listId, String newName) async {
    final db = await database;

    await db.update(
      'lists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  Future<void> updateListBudget(int listId, int budget) async {
    final db = await database;

    await db.update(
      'lists',
      {'budget': budget},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }
```

- [ ] **Step 5: `importData()` の `lists` INSERT に `budget` キャストを追加する**

`importData()` 内、`// lists INSERT` コメント以下のループ（607〜628行目付近）を変更する。

現在の内容:

```dart
      for (final list in incomingLists) {
        final oldId = (list['id'] as num).toInt();
        final resolvedName =
            resolveListName(list['name'] as String, existingNames);
        existingNames.add(resolvedName);

        final newId = await txn.insert('lists', {
          'name': resolvedName,
          'createdAt': baseCreatedAt + listInsertIndex,
        });
        listInsertIndex++;
        listIdMap[oldId] = newId;
      }
```

変更後:

```dart
      for (final list in incomingLists) {
        final oldId = (list['id'] as num).toInt();
        final resolvedName =
            resolveListName(list['name'] as String, existingNames);
        existingNames.add(resolvedName);

        final newId = await txn.insert('lists', {
          'name': resolvedName,
          'createdAt': baseCreatedAt + listInsertIndex,
          'budget': (list['budget'] as num?)?.toInt() ?? 0,
        });
        listInsertIndex++;
        listIdMap[oldId] = newId;
      }
```

これにより、`budget` フィールド導入前にエクスポートされた旧バックアップファイル（`budget` キーが存在しない）をインポートしても `0`（未設定扱い）にフォールバックし、例外にならない。

- [ ] **Step 6: 静的検証を行う**

Run: `flutter analyze lib/database/database_helper.dart`
Expected: エラー・警告なし

- [ ] **Step 7: 既存の単体テストに影響がないことを確認する**

Run: `flutter test`
Expected: すべて PASS（`database_helper.dart` は実DBアクセスのため直接のテスト対象ではないが、`backup_test.dart` 等が `DatabaseHelper` の静的メソッド・純粋ロジックを間接的に使っていないか確認する）

- [ ] **Step 8: コミット**

```bash
git add lib/database/database_helper.dart
git commit -m "feat: listsテーブルにbudgetカラムを追加しDBバージョンを8へ更新"
```

---

### Task 3: `BudgetSummary` ウィジェット新規作成

**依存:** なし（Task 1・2と並行して着手可能）

**Files:**
- Create: `lib/widgets/budget_summary.dart`

**Interfaces:**
- Produces: `BudgetSummary({required int budget, required VoidCallback onTap})`（Task 5 が `ShoppingListScreen` から使用する）

自動テストは追加しない（本計画冒頭「テスト方針の注記」を参照。`item_tile.dart` の同種の0円ハイフン表示ロジックにも既存の自動テストが無く、既存踏襲のため）。

- [ ] **Step 1: ウィジェットを新規作成する**

`lib/widgets/budget_summary.dart` を新規作成する。

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// リストごとの予算表示ウィジェット（TotalSummary直上・独立した1行）
///
/// budget が0円のときは「未設定」として扱い、「予算 -」と表示する。
class BudgetSummary extends StatelessWidget {
  final int budget;
  final VoidCallback onTap;

  const BudgetSummary({
    super.key,
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final text = budget == 0 ? '予算 -' : '予算 ¥${fmt.format(budget)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 静的検証を行う**

Run: `flutter analyze lib/widgets/budget_summary.dart`
Expected: エラー・警告なし

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/budget_summary.dart
git commit -m "feat: BudgetSummaryウィジェットを新規追加"
```

---

### Task 4: `TotalSummary` の0円ハイフン表示対応（付随変更・設計書§8）

**依存:** なし（Task 1・2・3と並行して着手可能）

**Files:**
- Modify: `lib/widgets/total_summary.dart`

**Interfaces:**
- `TotalSummary({required List<Item> items})` のシグネチャは変更なし。表示テキストのフォーマットのみ変更する。

DBスキーマ・モデルへの影響はない表示ロジックのみの変更。自動テストは追加しない（本計画冒頭「テスト方針の注記」を参照）。

- [ ] **Step 1: `build()` を0円ハイフン表示に対応させる**

`lib/widgets/total_summary.dart` を以下の内容で全面置換する。

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/item.dart';

/// 税込合計の表示ウィジェット（タブ直下固定）
///
/// price は税込単価として保存されているため、合計 = sum(price × quantity)。
/// 未購入合計／購入済合計が0円のときは「未購入 -」「購入済 -」と表示する。
class TotalSummary extends StatelessWidget {
  final List<Item> items;

  const TotalSummary({super.key, required this.items});

  static int _sum(List<Item> items) =>
      items.fold(0, (s, e) => s + e.price * e.quantity);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final unchecked = items.where((e) => !e.isChecked).toList();
    final checked = items.where((e) => e.isChecked).toList();

    final uncheckedSum = _sum(unchecked);
    final checkedSum = _sum(checked);
    final uncheckedText =
        uncheckedSum > 0 ? '未購入 ¥${fmt.format(uncheckedSum)}' : '未購入 -';
    final checkedText =
        checkedSum > 0 ? '購入済 ¥${fmt.format(checkedSum)}' : '購入済 -';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            uncheckedText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            checkedText,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 静的検証を行う**

Run: `flutter analyze lib/widgets/total_summary.dart`
Expected: エラー・警告なし

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/total_summary.dart
git commit -m "fix: TotalSummaryの未購入合計/購入済合計を0円時ハイフン表示に統一"
```

---

### Task 5: `ShoppingListScreen` への統合（`BudgetSummary` 配置・予算入力ダイアログ）

**依存:** Task 1（`ShoppingList.budget`）、Task 2（`DatabaseHelper.updateListBudget`）、Task 3（`BudgetSummary`）。Task 4 は同一UI領域の変更のため先に完了しておくことを推奨するが、コード上の直接依存はない。

**Files:**
- Modify: `lib/screens/shopping_list_screen.dart`

**Interfaces:**
- Consumes: `ShoppingList.budget`（Task 1）、`DatabaseHelper.instance.updateListBudget(int, int)`（Task 2）、`BudgetSummary({required int budget, required VoidCallback onTap})`（Task 3）
- Produces: `_ShoppingListScreenState._showBudgetInputDialog(ShoppingList list) -> Future<void>`、`_BudgetInputDialog`（同ファイル内プライベートクラス）

**影響範囲の確認：** `shopping_list_screen.dart` の `_SingleFieldDialog` はテキスト入力専用で「空欄なら送信しない」仕様のため予算入力には流用できない（新規に `_BudgetInputDialog` を追加する。既存の `_SingleFieldDialog`／`_SingleFieldDialogState` は変更しない）。

- [ ] **Step 1: 必要なimportを追加する**

`lib/screens/shopping_list_screen.dart` の先頭import群を変更する。

現在の内容（1〜6行目付近）:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share;
```

変更後:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share;
```

次に、`import '../widgets/help_dialog.dart';` の直後に `BudgetSummary` のimportを追加する。

現在の内容（22〜24行目付近）:

```dart
import '../widgets/help_dialog.dart';
import '../widgets/total_summary.dart';
import '../widgets/upgrade_dialog.dart';
```

変更後:

```dart
import '../widgets/budget_summary.dart';
import '../widgets/help_dialog.dart';
import '../widgets/total_summary.dart';
import '../widgets/upgrade_dialog.dart';
```

- [ ] **Step 2: `_showBudgetInputDialog()` メソッドを追加する**

`_showRenameListDialog()`（442〜458行目付近）の直後に追加する。

現在の該当箇所:

```dart
  Future<void> _showRenameListDialog(ShoppingList list) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SingleFieldDialog(
        title: 'リスト名変更',
        labelText: 'リスト名',
        initialText: list.name,
        submitLabel: '変更',
        onSubmit: (newName) async {
          await DatabaseHelper.instance.updateListName(list.id!, newName);
          await loadLists();
          if (!mounted) return;
          setState(() {});
        },
      ),
    );
  }
```

変更後（メソッドを追加）:

```dart
  Future<void> _showRenameListDialog(ShoppingList list) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SingleFieldDialog(
        title: 'リスト名変更',
        labelText: 'リスト名',
        initialText: list.name,
        submitLabel: '変更',
        onSubmit: (newName) async {
          await DatabaseHelper.instance.updateListName(list.id!, newName);
          await loadLists();
          if (!mounted) return;
          setState(() {});
        },
      ),
    );
  }

  Future<void> _showBudgetInputDialog(ShoppingList list) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _BudgetInputDialog(
        initialBudget: list.budget,
        onSubmit: (newBudget) async {
          try {
            await DatabaseHelper.instance.updateListBudget(list.id!, newBudget);
            await loadLists();
            if (!mounted) return;
            setState(() {});
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('予算の保存に失敗しました')),
            );
            await loadLists();
          }
        },
      ),
    );
  }
```

`list.id!` は `_showRenameListDialog` と同じ前提（`shoppingLists` はDBから取得済みの `ShoppingList` のみを保持するため `id` は常に確定済み）に基づく。

- [ ] **Step 3: `body` 内、`TotalSummary` の直前に `BudgetSummary` を配置する**

現在の該当箇所（909〜916行目付近）:

```dart
          return Column(
            children: [
              // 合計表示（タブ直下・設計書 §5.2 / §8.8）
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TotalSummary(items: items),
              ),
              const Divider(height: 1),
```

変更後:

```dart
          return Column(
            children: [
              // 予算表示（TotalSummary直上・設計書 docs/superpowers/specs/2026-08-04-budget-display-design.md §3.2.2）
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: BudgetSummary(
                  budget: shoppingLists
                      .firstWhere(
                        (e) => e.id == currentListId,
                        orElse: () => ShoppingList(name: '買い物リスト'),
                      )
                      .budget,
                  onTap: () => _showBudgetInputDialog(
                    shoppingLists.firstWhere(
                      (e) => e.id == currentListId,
                      orElse: () => ShoppingList(name: '買い物リスト'),
                    ),
                  ),
                ),
              ),
              // 合計表示（タブ直下・設計書 §5.2 / §8.8）
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TotalSummary(items: items),
              ),
              const Divider(height: 1),
```

- [ ] **Step 4: `_BudgetInputDialog` を追加する**

ファイル末尾、`_SingleFieldDialogState` クラスの直後（既存ファイルの最終行）に追加する。

現在のファイル末尾:

```dart
class _SingleFieldDialogState extends State<_SingleFieldDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      actionsOverflowDirection: VerticalDirection.down,
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.labelText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context);
            await widget.onSubmit(value);
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
```

変更後（`_BudgetInputDialog` を追記）:

```dart
class _SingleFieldDialogState extends State<_SingleFieldDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      actionsOverflowDirection: VerticalDirection.down,
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.labelText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context);
            await widget.onSubmit(value);
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class _BudgetInputDialog extends StatefulWidget {
  final int initialBudget;
  final Future<void> Function(int budget) onSubmit;

  const _BudgetInputDialog({
    required this.initialBudget,
    required this.onSubmit,
  });

  @override
  State<_BudgetInputDialog> createState() => _BudgetInputDialogState();
}

class _BudgetInputDialogState extends State<_BudgetInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // budget == 0（未設定）のときは空文字、それ以外は現在値を初期表示する
    _controller = TextEditingController(
      text: widget.initialBudget == 0 ? '' : '${widget.initialBudget}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('予算を設定'),
      actionsOverflowDirection: VerticalDirection.down,
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: '予算'),
          onTap: () => _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
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
            // 空欄は0（未設定）として保存する（_SingleFieldDialogとの相違点）
            final budget = int.tryParse(_controller.text) ?? 0;
            Navigator.pop(context);
            await widget.onSubmit(budget);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: 静的検証を行う**

Run: `flutter analyze lib/screens/shopping_list_screen.dart`
Expected: エラー・警告なし

- [ ] **Step 6: 既存の単体テストに影響がないことを確認する**

Run: `flutter test`
Expected: すべて PASS

- [ ] **Step 7: コミット**

```bash
git add lib/screens/shopping_list_screen.dart
git commit -m "feat: BudgetSummaryをTotalSummary直上に配置し予算入力ダイアログを追加"
```

---

### Task 6: `help_dialog.dart` の更新

**依存:** なし（Task 5と並行して着手可能。ただし説明文はTask 5の実装内容と一致させること）

**Files:**
- Modify: `lib/widgets/help_dialog.dart`

- [ ] **Step 1: 「リストを削除」の直後に予算設定の説明を追加する**

現在の該当箇所（49〜63行目付近）:

```dart
            _HelpItem(
              icon: Icons.playlist_add,
              label: 'リストを追加',
              description: 'AppBar右上の「＋」ボタン（最大10件）',
            ),
            _HelpItem(
              icon: Icons.delete_outline,
              label: 'リストを削除',
              description: 'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）',
            ),
            _HelpItem(
              icon: Icons.drive_file_move_outline,
              label: '別リストへ移動',
              description: '商品を長押しするとメニューが表示されます\n「別のリストに移動」で移動先リストを選択、「よく買うものに登録」でよく買うものに追加できます',
            ),
```

変更後:

```dart
            _HelpItem(
              icon: Icons.playlist_add,
              label: 'リストを追加',
              description: 'AppBar右上の「＋」ボタン（最大10件）',
            ),
            _HelpItem(
              icon: Icons.delete_outline,
              label: 'リストを削除',
              description: 'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）',
            ),
            _HelpItem(
              icon: Icons.savings_outlined,
              label: 'リストの予算を設定',
              description:
                  '合計表示の上の「予算 -」（または金額）をタップすると入力欄が開きます\n'
                  '空欄のまま保存すると未設定（-表示）に戻ります',
            ),
            _HelpItem(
              icon: Icons.drive_file_move_outline,
              label: '別リストへ移動',
              description: '商品を長押しするとメニューが表示されます\n「別のリストに移動」で移動先リストを選択、「よく買うものに登録」でよく買うものに追加できます',
            ),
```

- [ ] **Step 2: 静的検証を行う**

Run: `flutter analyze lib/widgets/help_dialog.dart`
Expected: エラー・警告なし

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/help_dialog.dart
git commit -m "docs: ヘルプ画面にリスト予算設定の説明を追加"
```

---

### Task 7: 生きた設計書 rev8.13 → rev8.14 への更新

**依存:** Task 1〜6（実装内容を正しく反映するため、実装完了後に着手する）

**Files:**
- Create: `docs/_old/spec_HKL-001_shopping_list_app_rev8.13.md`（旧版アーカイブ）
- Modify → Rename: `docs/spec_HKL-001_shopping_list_app_rev8.13.md` → `docs/spec_HKL-001_shopping_list_app_rev8.14.md`

`updating-rev-numbered-specs` スキルの手順に従う。本文編集とリネームは同一コミットに含める。

- [ ] **Step 1: 旧版を `docs/_old/` へコピー保存する**

```bash
cp "docs/spec_HKL-001_shopping_list_app_rev8.13.md" "docs/_old/spec_HKL-001_shopping_list_app_rev8.13.md"
```

- [ ] **Step 2: 冒頭のRev表記を更新する**

現在の内容（3行目）:

```markdown
**Rev 8.13　2026年改訂**
```

変更後:

```markdown
**Rev 8.14　2026年改訂**
```

- [ ] **Step 3: 変更履歴テーブルに新しい行を追加する**

現在の該当箇所（32行目、テーブル最終行）:

```markdown
| 8.13 | 2026-08-01    | UI表記の「タブ」を「リスト」に統一（タブ名変更ダイアログ・別リストへ移動メニュー・ヘルプ文言）。設計書内の対応する記述も同様に更新（`TabBar`/`TabController` 等のウィジェット名は変更なし）                                                         |     |
```

直後に追加:

```markdown
| 8.14 | 2026-08-04    | リストごとの予算表示機能を追加（`ShoppingList` に `budget` フィールド追加・`lists` テーブルに `budget` カラム追加（DB v8）・`BudgetSummary` ウィジェット新規追加・`TotalSummary` 直上に配置・タップで予算入力ダイアログを開き設定）。付随変更として `TotalSummary`（未購入合計／購入済合計）を0円時ハイフン表示に統一（`item_tile.dart` の単価0円時ハイフン表示と統一）                                                         |     |
```

- [ ] **Step 4: §6.2 lists テーブルに `budget` 行を追加する**

現在の該当箇所（230〜237行目付近）:

```markdown
### 6.2 lists テーブル

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK |
| name | TEXT | リスト名 |
| createdAt | INTEGER | 作成日時 |
```

変更後:

```markdown
### 6.2 lists テーブル

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK |
| name | TEXT | リスト名 |
| createdAt | INTEGER | 作成日時 |
| budget | INTEGER | 予算額（NOT NULL DEFAULT 0。DB v8追加。0円＝未設定として扱う） |
```

- [ ] **Step 5: §4 ディレクトリ構成に `budget_summary.dart` を追加する**

現在の該当箇所（116〜127行目付近）:

```markdown
└─ widgets/
    ├─ add_item_dialog.dart
    ├─ ad_banner.dart
    ├─ category_management_dialog.dart
    ├─ help_dialog.dart
    ├─ item_tile.dart
    ├─ list_management_buttons.dart
    ├─ list_section.dart
    ├─ list_tab_bar.dart
    ├─ total_summary.dart
    ├─ empty_state_view.dart
    ├─ upgrade_dialog.dart
    └─ fields/
```

変更後:

```markdown
└─ widgets/
    ├─ add_item_dialog.dart
    ├─ ad_banner.dart
    ├─ budget_summary.dart           ← 新規
    ├─ category_management_dialog.dart
    ├─ help_dialog.dart
    ├─ item_tile.dart
    ├─ list_management_buttons.dart
    ├─ list_section.dart
    ├─ list_tab_bar.dart
    ├─ total_summary.dart
    ├─ empty_state_view.dart
    ├─ upgrade_dialog.dart
    └─ fields/
```

- [ ] **Step 6: §5.1 機能一覧に予算表示の行を追加し、合計表示の説明を更新する**

現在の該当箇所（154行目）:

```markdown
| 合計表示 | 税込合計（タブ直下固定表示。未購入/購入済みを並列表示） |
```

変更後（行を追加）:

```markdown
| リストごとの予算表示 | リストごとに予算額を設定・表示（TotalSummary直上に固定表示。タップで入力ダイアログを開く。0円＝未設定として「予算 -」表示） |
| 合計表示 | 税込合計（タブ直下固定表示。未購入/購入済みを並列表示。それぞれ0円のときは「未購入 -」「購入済 -」と表示） |
```

- [ ] **Step 7: §5.2 UI構成のASCII図に予算表示を追加する**

現在の該当箇所（186〜189行目付近）:

```markdown
 ├─ TabBar（長押しでリスト名変更）
 │
 ├─ 合計表示（TotalSummary・ListView 外・TabBar 直下に固定）
 │
```

変更後:

```markdown
 ├─ TabBar（長押しでリスト名変更）
 │
 ├─ 予算表示（BudgetSummary・TotalSummary直上・タップで入力ダイアログ）  ← 新規
 │
 ├─ 合計表示（TotalSummary・ListView 外・TabBar 直下に固定）
 │
```

- [ ] **Step 8: §8.12 の直後に新セクション「8.13 リストごとの予算表示機能」を追加する**

現在の該当箇所（708〜716行目付近、§8.12末尾から§9直前）:

```markdown
#### DatabaseHelper 追加メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| importData | `Future<ImportResult> importData(Map<String, dynamic> data)` | lists・items・favorites・categories をマージ INSERT |
| resolveListName | `static String resolveListName(String name, Set<String> existingNames)` | 衝突時に連番付与した名前を返す（テスト可能） |

---

## 9. クラス設計
```

変更後（新セクションを挿入）:

```markdown
#### DatabaseHelper 追加メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| importData | `Future<ImportResult> importData(Map<String, dynamic> data)` | lists・items・favorites・categories をマージ INSERT |
| resolveListName | `static String resolveListName(String name, Set<String> existingNames)` | 衝突時に連番付与した名前を返す（テスト可能） |

---

### 8.13 リストごとの予算表示機能

リストごとに「今回はいくらまで買うか」という目安を設定・確認できる。予算額と未購入合計を並べて見比べられるようにする表示専用の機能で、超過警告・残額計算・色分けは行わない（スコープ外・意図的なYAGNI）。

- `ShoppingList.budget`（`int`、DB上は `lists.budget INTEGER NOT NULL DEFAULT 0`）にリストごとの予算額を保持する。`0` は「未設定」として扱い、`null` は使用しない
- `BudgetSummary` ウィジェットが `TotalSummary`（未購入/購入済合計）の直上に独立した1行として表示される。`budget == 0` のとき「予算 -」、それ以外は「予算 ¥{カンマ区切り}」と表示する
- `BudgetSummary` をタップすると予算入力ダイアログ（`_BudgetInputDialog`）が開く。数値のみ入力可（`FilteringTextInputFormatter.digitsOnly`）。空欄のまま保存すると `0`（未設定）に戻る
- 保存操作は `DatabaseHelper.updateListBudget(listId, budget)` → `loadLists()` で再同期、というリスト名変更（`_showRenameListDialog`）と同一の流れを踏襲する。保存失敗時は汎用文言のSnackBar「予算の保存に失敗しました」を表示し、`loadLists()` でDBの実値に再同期する
- バックアップ（JSONエクスポート/インポート）は `toMap()`/`fromMap()` 経由のため `budget` も自動的にバックアップ対象になる。旧バージョン（`budget` キーを含まない）のバックアップをインポートした場合は `0`（未設定）にフォールバックする

---

## 9. クラス設計
```

- [ ] **Step 9: §9.2 ShoppingList のメソッド一覧に `copyWith()` を追加する**

現在の該当箇所（740〜745行目付近）:

```markdown
### 9.2 ShoppingList（リスト情報モデル）

| メソッド | 内容 |
|----------|------|
| toMap() | DB保存 |
| fromMap() | DB読込 |
```

変更後:

```markdown
### 9.2 ShoppingList（リスト情報モデル）

| メソッド | 内容 |
|----------|------|
| toMap() | DB保存 |
| fromMap() | DB読込 |
| copyWith() | 部分更新（budget含む） |
```

- [ ] **Step 10: §10 DBバージョン管理に version 8 の行を追加する**

現在の該当箇所（810〜820行目付近）:

```markdown
## 10. DBバージョン管理

| バージョン | 変更内容 |
|-----------|---------|
| version 1 | 初期構成 |
| version 2 | quantity カラム追加 |
| version 3 | listId カラム追加 |
| version 4 | item_history テーブル追加・Migration 改善（※ 2026-06-29 に item_history 関連コード・テーブル作成処理を削除。既存インストールで作成済みの `item_history` テーブル自体は残存するが、アプリからは一切参照しない） |
| version 5 | taxRate カラム削除（テーブル再作成によるマイグレーション） |
| version 6 | favorites テーブル追加 |
| version 7 | categories テーブル追加・items/favorites に categoryId カラム追加 |
```

変更後:

```markdown
## 10. DBバージョン管理

| バージョン | 変更内容 |
|-----------|---------|
| version 1 | 初期構成 |
| version 2 | quantity カラム追加 |
| version 3 | listId カラム追加 |
| version 4 | item_history テーブル追加・Migration 改善（※ 2026-06-29 に item_history 関連コード・テーブル作成処理を削除。既存インストールで作成済みの `item_history` テーブル自体は残存するが、アプリからは一切参照しない） |
| version 5 | taxRate カラム削除（テーブル再作成によるマイグレーション） |
| version 6 | favorites テーブル追加 |
| version 7 | categories テーブル追加・items/favorites に categoryId カラム追加 |
| version 8 | lists に budget カラム追加（NOT NULL DEFAULT 0） |
```

- [ ] **Step 11: §8.12 バックアップファイル形式のJSON例に `budget` を反映する**

現在の該当箇所（627行目付近）:

```json
  "lists": [{ "id": 1, "name": "買い物リスト", "createdAt": 1700000000000 }],
```

変更後:

```json
  "lists": [{ "id": 1, "name": "買い物リスト", "createdAt": 1700000000000, "budget": 0 }],
```

- [ ] **Step 12: ファイル名をリネームする**

```bash
git mv "docs/spec_HKL-001_shopping_list_app_rev8.13.md" "docs/spec_HKL-001_shopping_list_app_rev8.14.md"
```

- [ ] **Step 13: 古いリビジョンへの自己言及が残っていないか確認する**

Run: `grep -n "rev8\.13\|Rev 8\.13" "docs/spec_HKL-001_shopping_list_app_rev8.14.md"`
Expected: マッチなし（変更履歴テーブル内の過去リビジョン行としての「8.13」は問題ない。「rev8.13」というファイル名自己言及・「Rev 8.13」という冒頭表記が残っていないことを確認する）

- [ ] **Step 14: コミット**

```bash
git add "docs/_old/spec_HKL-001_shopping_list_app_rev8.13.md" "docs/spec_HKL-001_shopping_list_app_rev8.14.md"
git commit -m "docs: 設計書をrev8.14へ更新（リスト予算表示機能・TotalSummary0円ハイフン表示を反映）"
```

---

### Task 8: 最終検証・手動確認チェックリスト

**依存:** Task 1〜7すべて完了後

**Files:** なし（検証のみ）

- [ ] **Step 1: 静的解析を実行する**

Run: `flutter analyze`
Expected: エラーなし

- [ ] **Step 2: 全自動テストを実行する**

Run: `flutter test`
Expected: すべて PASS（`test/shopping_list_test.dart` を含む）

- [ ] **Step 3: 手動確認チェックリストをマスターに依頼する**

以下は `sqflite` の実DBアクセス・実機UIを伴うため自動化対象外（設計書 §7.4 準拠）。マスターに実機での確認を依頼する。

```
- [ ] アプリを再起動しても、設定した予算が保持されていること
- [ ] 複数リストを切り替えたとき、BudgetSummary に表示される金額が切り替え先リストの予算に正しく更新されること
- [ ] 予算未設定（0円）のリストで「予算 -」と表示されること、入力欄を空欄のまま保存すると「予算 -」に戻ること
- [ ] バックアップのエクスポート→インポートで、予算値が保持されること
- [ ] 旧バージョン（budgetキーを含まない）のバックアップファイルをインポートした場合、例外にならず予算が0（未設定）として取り込まれること
- [ ] 未購入合計・購入済合計がともに0円のリストで「未購入 -」「購入済 -」と表示されること（TotalSummary側の付随変更）
- [ ] 既存DB（version 7以前）を持つ端末でアプリを起動し、budgetカラムが自動追加され例外が発生しないこと（マイグレーション確認）
```

- [ ] **Step 4: 完了報告**

Task 1〜7のコミットハッシュ・`flutter analyze`/`flutter test` の結果・手動確認チェックリストの依頼をまとめてマスターへ報告する。

---

## Self-Review 記録

**1. Spec coverage:**
- §3.1.1 DBスキーマ変更 → Task 2 Step 1-3
- §3.1.2 ShoppingListモデル → Task 1
- §3.1.3 DatabaseHelper CRUD（updateListBudget・importData） → Task 2 Step 4-5
- §3.2.1 BudgetSummary → Task 3
- §3.2.2 ShoppingListScreen変更（配置・ダイアログ起動・_BudgetInputDialog） → Task 5
- §5 エラーハンドリング → Task 5 Step 2（try/catch・汎用文言）
- §6 その他プロジェクトルール（ヘルプ更新・生きた設計書更新・importDataキャストルール） → Task 6・Task 7・Task 2 Step 5
- §7.2 自動テスト（モデル層） → Task 1
- §7.3 ウィジェットテスト → 意図的に対象外化し「テスト方針の注記」で明示（Task冒頭）
- §7.4 手動確認項目 → Task 8 Step 3
- §8 TotalSummary0円ハイフン表示 → Task 4
- 全て対応済み。ギャップなし。

**2. Placeholder scan:** 「TBD」「後で実装」「適切なエラーハンドリングを追加」等のプレースホルダーは含まれていない。全コードブロックは実際に貼り付け可能な完全なコードとして記載した。

**3. Type consistency:** `ShoppingList(int? id, String name, int? createdAt, int budget = 0)` → `copyWith({int? id, String? name, int? createdAt, int? budget})` → `DatabaseHelper.updateListBudget(int listId, int budget)` → `BudgetSummary({required int budget, required VoidCallback onTap})` → `_BudgetInputDialog({required int initialBudget, required Future<void> Function(int budget) onSubmit})` の型・シグネチャはTask 1〜5を通して一貫している。`ShoppingList.id` が `int?` であるため `_showBudgetInputDialog` 内では既存の `_showRenameListDialog` と同じ `list.id!` パターンを使用しており、齟齬はない。
