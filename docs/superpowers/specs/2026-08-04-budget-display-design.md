# リスト予算表示機能 設計書

**作成日：2026-08-04**
**対象バージョン：** spec rev8.13 の次リビジョン（rev8.14想定）に追加
**ステータス：設計承認済み**

---

## 1. 背景・目的

### 1.1 背景

現状、`lib/widgets/total_summary.dart`（`TotalSummary` ウィジェット）は、選択中リストの「未購入合計」「購入済合計」を `lib/screens/shopping_list_screen.dart` のタブ直下（`body` の `Column` 内、911〜915行目付近）に表示している。

一方、`ShoppingList` モデル（`lib/models/shopping_list.dart`）は現状 `id`／`name`／`createdAt` の3フィールドのみを持ち、DBの `lists` テーブル（`lib/database/database_helper.dart` の `_createDB`、60〜66行目）にも予算に相当するカラムは存在しない。ユーザーがリストごとに「今回はいくらまで買うか」という目安を設定・確認する手段は現状ない。

### 1.2 目的

- `ShoppingList` に予算フィールドを追加し、リストごとに予算額を設定・永続化できるようにする
- `TotalSummary`（未購入合計）の直上に予算額を表示する行を追加し、予算と未購入合計を並べて見比べられるようにする
- スコープは「予算額と未購入合計を並べて見える比較表示のみ」とし、超過警告・残額計算・色分け等は行わない（YAGNI。マスターが明示的に不要と判断したため）

なお、本設計書は §8 として、予算機能とは独立した表示ルール統一（`TotalSummary` の0円ハイフン表示化）についても付随的に扱う。詳細は §8 を参照。

---

## 2. アーキテクチャ

### 2.1 現状の構成

```
ShoppingListScreen（ConsumerStatefulWidget）
 └─ _ShoppingListScreenState
      ├─ shoppingLists: List<ShoppingList>   ← ローカル State（loadLists()でDBから取得）
      ├─ currentListId: int                  ← 現在選択中のリストID
      │
      ├─ AppBar.bottom
      │    └─ ListTabBar
      └─ body（itemAsync.when の data コールバック内）
           └─ Column
                ├─ TotalSummary（未購入合計／購入済合計）
                ├─ Divider
                └─ Expanded（商品一覧）
```

`ShoppingList` は `id`／`name`／`createdAt` のみを持ち、リストごとの数値的な付加情報（予算等）を保持する仕組みは存在しない。

### 2.2 変更後の構成

```
ShoppingListScreen
 └─ _ShoppingListScreenState
      ├─ shoppingLists: List<ShoppingList>   ← 各要素が budget を保持（変更なし、フィールド追加のみ）
      ├─ currentListId: int                  ← 変更なし
      │
      ├─ AppBar.bottom
      │    └─ ListTabBar（変更なし）
      └─ body（itemAsync.when の data コールバック内）
           └─ Column
                ├─ BudgetSummary（新規・予算額表示。タップで _BudgetInputDialog を開く）
                ├─ TotalSummary（変更：0円時「-」表示に対応。§8参照）
                ├─ Divider
                └─ Expanded（商品一覧）
```

`BudgetSummary` は現在選択中リスト（`shoppingLists.firstWhere((e) => e.id == currentListId, ...)`）の `budget` を表示するだけであり、`itemProvider`（商品一覧）のデータフローには影響しない。予算値の更新は `DatabaseHelper` 経由でDBを更新後、既存の `loadLists()` を呼び直して `shoppingLists`（State）に反映する、というリスト名変更（`_showRenameListDialog`）と同一の流れを踏襲する。

---

## 3. コンポーネント設計

### 3.1 データ層

#### 3.1.1 DBスキーマ変更

`lib/database/database_helper.dart` のDBバージョンを 7 → 8 に上げる（38行目）。

```dart
return await openDatabase(
  path,
  version: 8,
  onCreate: _createDB,
  onUpgrade: _onUpgrade,
);
```

`_createDB` 内の `lists` テーブル定義（60〜66行目）に `budget` カラムを追加する。

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

`budget` は `NOT NULL DEFAULT 0` とし、「予算未設定」という概念は持たない。0円＝未設定として扱う（詳細は §4「検討した代替案」参照）。カラムのデフォルト値が0であるため、初回インストール時のデフォルトリスト作成（68〜71行目）は変更不要（`budget` を明示指定しなくてもDB側のデフォルトで0になる）。

`_onUpgrade` に `oldVersion < 8` のマイグレーションブロックを追加する。カラム追加は既存の `quantity`／`memo`／`listId` カラム追加（115〜125行目）と同じ「`ALTER TABLE ... ADD COLUMN` を try/catch で保護し、既存なら無視する」パターンを踏襲する。

```dart
if (oldVersion < 8) {
  try {
    await db.execute(
      'ALTER TABLE lists ADD COLUMN budget INTEGER NOT NULL DEFAULT 0',
    );
  } catch (_) {
    // カラムが既に存在する場合は無視
  }
}
```

#### 3.1.2 `ShoppingList` モデル（`lib/models/shopping_list.dart`）

`budget` フィールド（`int`、non-nullable、デフォルト0）を追加する。あわせて、他モデル（`Item`／`Category`）と同様の `copyWith` を新規に追加する（現状 `ShoppingList` に `copyWith` は存在しない）。

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

`fromMap` は `map['budget'] ?? 0` としてnullを許容する。これはマイグレーション未実施の環境を考慮した防御的実装であり、`Item.fromMap` の `quantity`／`memo` に対する `?? 1`／`?? ''`、および `sortOrder` 系フィールドで採用されている `?? 0` と同じ考え方である。

バックアップ（`lib/services/backup_service.dart`、JSONエクスポート／インポート）のエクスポート処理は `toMap()` を経由するため、`budget` は変更なしで自然にエクスポート対象になる。

#### 3.1.3 `DatabaseHelper` のCRUDメソッド変更

**`updateListBudget()`（新規）：** `updateListName()`（327〜336行目）と全く同じ実装パターンで追加する。

```dart
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

**`importData()`（539〜687行目）内の `lists` INSERT（607〜628行目付近）：** インポートされるJSON由来の `budget` を取り込む。プロジェクトの確定ルール「外部JSON由来の整数値は `as int` でなく `(num).toInt()` でキャストする」に従い、`null` の可能性（旧バージョンのバックアップファイルに `budget` キー自体が存在しないケース）も考慮して以下のようにキャストする。

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

これにより、`budget` フィールド導入前にエクスポートされた旧バックアップファイル（`budget` キーが存在しない）をインポートしても、`0`（未設定扱い）にフォールバックし例外にならない。

### 3.2 UI層

#### 3.2.1 `BudgetSummary`（新規・`lib/widgets/budget_summary.dart`）

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

- `budget == 0` のとき「予算 -」、それ以外は「予算 ¥{カンマ区切り金額}」（`NumberFormat('#,###')`。`TotalSummary` と同じ書式）とする。
- レイアウトは `TotalSummary` の `Row`（`spaceBetween` で2項目を左右に配置）とは異なり、左寄せの独立した1行とする（`mainAxisSize: MainAxisSize.min` の `Row` で文字列とアイコンのみをまとめる）。
- タップ可能であることを伝えるため `InkWell` でラップし、末尾に小さめの `Icon(Icons.edit, size: 14)` を添えてタップのアフォーダンスとする。

#### 3.2.2 `ShoppingListScreen`（`lib/screens/shopping_list_screen.dart`）の変更

**配置（body内、`TotalSummary` の直前・911〜915行目付近）：**

```dart
return Column(
  children: [
    // 予算表示（TotalSummary直上）
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
    // ...（以下、既存の商品一覧表示、変更なし）
  ],
);
```

現在選択中リストの取得は、`_shareCurrentList()`（137〜140行目）等の既存箇所と同じ `shoppingLists.firstWhere((e) => e.id == currentListId, orElse: () => ShoppingList(name: '買い物リスト'))` パターンをそのまま用いる。

**予算入力ダイアログの起動処理（新規メソッド）：**

既存の `_SingleFieldDialog`（1056〜1119行目）はテキスト入力用であり、「空欄なら送信しない」仕様（`_SingleFieldDialogState` の `FilledButton.onPressed` 内、`if (value.isEmpty) return;`）のため、そのままでは流用できない（本機能では「空欄で保存＝0として保存」という挙動が必要）。数値入力については `lib/widgets/fields/price_field.dart`（`TextInputType.number` ＋ `FilteringTextInputFormatter.digitsOnly` ＋ 0以上のvalidator、というパターン）を参考にしつつ、ラベルが「税込価格」固定のため直接の流用はできない。同様の作りで、予算専用の新規プライベートウィジェット `_BudgetInputDialog` を `_SingleFieldDialog` と同格（同一ファイル内）に追加する。

```dart
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

この流れは `_showRenameListDialog`（442〜458行目）と同じ「ダイアログのコールバックで `DatabaseHelper` 更新 → `loadLists()` → `setState`」パターンである。ただし `_showRenameListDialog` にはtry/catchが無いのに対し、本機能ではエラーハンドリング（§5参照）を追加している。

**`_BudgetInputDialog`（新規・`_SingleFieldDialog` の直後に追加）：**

```dart
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

- `_SingleFieldDialog` との最大の相違点は、送信ボタン押下時に空欄チェックで早期returnせず、`int.tryParse(_controller.text) ?? 0` により空欄を0として扱う点である。
- `FilteringTextInputFormatter.digitsOnly` により負数・小数の入力自体を防いでいるため、`PriceField` のような0以上のvalidatorは必須ではないが、防御的に `int.tryParse(...) ?? 0` で非数値混入時も0にフォールバックする。

---

## 4. 検討した代替案

| 案 | 内容 | 不採用理由 |
|---|---|---|
| `budget` をnullable intとし「未設定」と「0円」を区別する | `int? budget` として、`null` を「未設定」、`0` を「予算0円で買わない」として区別する | マスター判断により不採用。nullとdefault(0)の二重管理はユーザーの混乱を招くため、0への統一の方が分かりやすい |
| `SharedPreferences` に `listId` をキーとして予算を保存する | DBを変更せず、端末ローカルのキー・バリューストアに保存する | バックアップ（JSONエクスポート／インポート）に含まれず、機種変更・再インストール時に消失するため不採用。DBカラム化により `toMap`／`fromMap` 経由で自然にバックアップ対象になる案（本設計）を採用した |
| 予算と未購入合計を1行にまとめて表示する（例：「予算 ¥10,000　未購入 ¥7,000」） | `TotalSummary` と同じ `Row`（`spaceBetween`）の中に予算も含めて1行で表示する | マスターが「独立した1行（予算のみ）」を選択したため不採用。`BudgetSummary` を別ウィジェット・別行として分離した |

なお、`BudgetSummary`（0円→「予算 -」）と `TotalSummary`（変更後：0円→「未購入 -」「購入済 -」、§8参照）は、いずれも「0円＝ハイフン表示」という共通ルールに統一されており、既存の `item_tile.dart`（単価0円時「単価: -」「税込合計: -」、rev8.12で導入済み）と合わせて、アプリ全体で金額0円の表示ルールが一貫している。

---

## 5. エラーハンドリング

- `DatabaseHelper.instance.updateListBudget()` の呼び出しは `try/catch` で保護する（§3.2.2参照）。プロジェクトの確定ルール「catch節でユーザー向けメッセージを返す場合は `e.toString()` を使わず汎用文言にする」に従い、`e.toString()` を使わず `'予算の保存に失敗しました'` という汎用文言を `SnackBar` で表示する（`_onReorderList` と同じパターン）。
- 保存失敗時は `loadLists()` を呼び直し、`shoppingLists`（State）をDBの実値に再同期する。これにより、UI上に表示されたままの予算値とDB上の実値が乖離した状態を防ぐ。
- `updateListBudget` に渡す `list.id` が `null` になるケースは、`shoppingLists` が常にDBから取得済みの `ShoppingList`（`id` 確定済み）のみを保持するため発生しない（`_showRenameListDialog` の `list.id!` と同じ前提）。

---

## 6. その他のプロジェクトルール順守事項

- **ヘルプ更新（確定ルール：機能追加・変更時は必ず `lib/widgets/help_dialog.dart` も同時更新する）：** 既存の「リストを追加」（`Icons.playlist_add`）と「リストを削除」（`Icons.delete_outline`）の並びの近くに、予算表示・設定方法の説明項目を追加する。

  ```dart
  _HelpItem(
    icon: Icons.savings_outlined,
    label: 'リストの予算を設定',
    description:
        '合計表示の上の「予算 -」（または金額）をタップすると入力欄が開きます\n'
        '空欄のまま保存すると未設定（-表示）に戻ります',
  ),
  ```

- **生きた設計書の更新：** `docs/spec_HKL-001_shopping_list_app_rev8.13.md` を rev8.14 へ更新する。`updating-rev-numbered-specs` スキルの手順に従い、以下を同一コミットで行う。
  1. 現行の `docs/spec_HKL-001_shopping_list_app_rev8.13.md` を `docs/_old/spec_HKL-001_shopping_list_app_rev8.13.md` へコピーして保存する
  2. 本文（変更履歴テーブルへの追記、冒頭「Rev 8.13」→「Rev 8.14」表記の更新、DBスキーマ節・UI節等の該当箇所の更新）を編集する
  3. `git mv docs/spec_HKL-001_shopping_list_app_rev8.13.md docs/spec_HKL-001_shopping_list_app_rev8.14.md` でファイル名をリネームする（内容編集と同一コミットに含める）
  4. リネーム後、ファイル内に「rev8.13」「Rev 8.13」等、古いリビジョンへの自己言及が残っていないか grep で確認する

- **インポート処理の確定ルール順守：** `importData()` での `lists` 復元時、外部JSON由来の整数値は `as int` でなく `(num).toInt()` でキャストする（§3.1.3参照）。

---

## 7. テスト方針

### 7.1 現状のテスト基盤に関する制約

本プロジェクトの `test/` 配下は `package:test` によるモデル・純粋関数の単体テストのみで構成されており、`sqflite` の実DBインスタンスに対する統合テストは行っていない。そのため、`updateListBudget()` のような実際のDBアクセスを伴うメソッドは、現状のテスト基盤では直接の自動テスト対象にできない。

### 7.2 自動テスト（モデル層）

`test/shopping_list_test.dart`（既存であれば追記、無ければ新規）に、`item_test.dart` の `Item` モデルテストと同じ構成で `ShoppingList` モデルのテストを追加する。

- `toMap` / `fromMap` ラウンドトリップ（`budget` を含む）
- `copyWith`：`budget` を含む各フィールドについて、指定フィールドのみ更新され他は元の値を保持すること
- `fromMap` で `budget` キーが存在しない場合に `0` にフォールバックすること（マイグレーション未実施環境を想定した防御的実装の検証）

### 7.3 ウィジェットテスト

`BudgetSummary` の表示ロジック（`budget == 0` のとき「予算 -」、非0のとき「予算 ¥{カンマ区切り}」）をウィジェットテストで検証する。

### 7.4 自動テストの限界と手動確認項目

`updateListBudget`／`importData` の `budget` キャスト処理については、実DBを伴うため既存基盤では単体テスト化しない。以下を手動確認項目とする。

- アプリを再起動しても、設定した予算が保持されていること
- 複数リストを切り替えたとき、`BudgetSummary` に表示される金額が切り替え先リストの予算に正しく更新されること
- 予算未設定（0円）のリストで「予算 -」と表示されること、入力欄を空欄のまま保存すると「予算 -」に戻ること
- バックアップのエクスポート→インポートで、予算値が保持されること
- 旧バージョン（`budget` キーを含まない）のバックアップファイルをインポートした場合、例外にならず予算が0（未設定）として取り込まれること

---

## 8. 表示ルール統一：`TotalSummary` の0円ハイフン表示（付随変更）

本節は予算機能本体とは独立した、既存パターンの横展開である。DBスキーマ・モデルへの影響はない。

### 8.1 背景

`BudgetSummary`（§3.2.1）は「予算0円＝未設定」として「予算 -」と表示する。一方、既存の `lib/widgets/item_tile.dart` は、rev8.12にて単価0円時に「単価: -」「税込合計: -」と表示する仕様を既に導入済みである（34〜35行目、`item.price > 0 ? '¥${numberFormat.format(item.price)}' : '-'`）。

これに対し、`lib/widgets/total_summary.dart`（`TotalSummary`）は現状、未購入合計・購入済合計が0円であっても `_sum()` の結果をそのまま `fmt.format()` で文字列化しているだけであり、「未購入 ¥0」「購入済 ¥0」とそのまま表示される。マスターより、この2箇所（未購入合計・購入済合計）についても、`item_tile.dart` および今回新設する `BudgetSummary` と同じ「0円→ハイフン表示」ルールに揃えたいとの指示があった。

### 8.2 変更内容

`lib/widgets/total_summary.dart` の `build()` 内で、`_sum(unchecked)`／`_sum(checked)` がそれぞれ0のとき、対応する `Text` の文字列を「未購入 -」「購入済 -」に切り替える。

```dart
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
```

- 条件式は `item_tile.dart` の `item.price > 0 ? ... : '-'` と同じ「`> 0` で判定し、0（および負値が万一発生した場合を含む0以下）はハイフン表示にする」考え方を踏襲する。
- この変更により、`BudgetSummary`（予算）・`TotalSummary`（未購入合計／購入済合計）・`item_tile.dart`（単価／税込合計）の3箇所すべてで「0円＝ハイフン表示」というルールがアプリ全体で統一される。
- DBスキーマ・`ShoppingList`／`Item` モデルへの変更は伴わない。表示ロジックのみの軽微な条件分岐追加である。
- ウィジェットテストの対象に追加する（§7.3の対象に、`TotalSummary` の0円時ハイフン表示ケースを含める）。

---

## 9. 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `lib/database/database_helper.dart` | DBバージョン 7→8、`lists` テーブルへ `budget` カラム追加、`_onUpgrade` にマイグレーション追加、`updateListBudget()` 新規追加、`importData()` の `lists` INSERT に `budget` キャスト対応を追加 |
| `lib/models/shopping_list.dart` | `budget` フィールド・`copyWith` 追加、`toMap`/`fromMap` に `budget` を追加 |
| `lib/widgets/budget_summary.dart` | 新規追加（`BudgetSummary` ウィジェット） |
| `lib/screens/shopping_list_screen.dart` | `_BudgetInputDialog` 追加、`_showBudgetInputDialog()` 追加、body内 `TotalSummary` 直前への `BudgetSummary` 配置 |
| `lib/widgets/total_summary.dart` | 未購入合計／購入済合計が0円のとき「未購入 -」「購入済 -」と表示するよう変更（§8、予算機能とは独立した表示ルール統一） |
| `lib/widgets/help_dialog.dart` | 「リストの予算を設定」の操作説明を追加 |
| `docs/spec_HKL-001_shopping_list_app_rev8.13.md` | rev8.14へ更新・リネーム（`docs/spec_HKL-001_shopping_list_app_rev8.14.md`）、旧版を `docs/_old/` へ保存 |
| `test/shopping_list_test.dart` | 新規追加または追記（`ShoppingList` モデルの単体テスト） |
