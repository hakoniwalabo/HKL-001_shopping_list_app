# リスト共有 ＋ バックアップ端末保存 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** アプリ同士でリスト1件を共有でき（未購入のみ）、バックアップを共有シートだけでなく端末にも保存でき、共有/端末保存/バックアップのいずれのファイルも同じ読み込み口から取り込めるようにする。

**Architecture:** 既存の `BackupService`（JSON シリアライズ）と `DatabaseHelper.importData`（マージ取り込み）を流用。新規パッケージなし。純粋ロジック（ファイル名サニタイズ・エクスポート Map 構築）は `package:test` で単体テストし、DB/UI/file_picker 依存部は `flutter analyze` ＋ エミュレーター実機確認で検証する。

**Tech Stack:** Flutter / Dart / sqflite / share_plus / file_picker / path_provider

---

## ファイル構成

| ファイル | 責務 | 変更種別 |
|---------|------|---------|
| `lib/services/backup_service.dart` | サニタイズ・Map構築（純粋）、export/saveToDevice/shareList/import | 変更 |
| `test/backup_test.dart` | 純粋ロジックの単体テスト | 変更（テスト追加） |
| `lib/screens/shopping_list_screen.dart` | バックアップ保存先ダイアログ・リスト共有メニュー・読み込みメニュー文言・確認文言 | 変更 |
| `lib/widgets/help_dialog.dart` | リスト共有・端末保存・読み込みの説明更新 | 変更 |

> `pubspec.yaml` は変更しない（新規依存なし・version 行据え置き）。

---

## Task 1: ファイル名サニタイズ（純粋関数・TDD）

**Files:**
- Modify: `lib/services/backup_service.dart`
- Test: `test/backup_test.dart`

- [ ] **Step 1: 失敗するテストを書く**

`test/backup_test.dart` の `main()` 内末尾（最後の `}` の直前）に追加：

```dart
  group('BackupService.sanitizeFileName', () {
    test('通常の名前はそのまま返す', () {
      expect(BackupService.sanitizeFileName('週末の買い物'), '週末の買い物');
    });

    test('ファイル名禁止文字を _ に置換する', () {
      expect(BackupService.sanitizeFileName('a/b:c*d?e"f<g>h|i\\j'),
          'a_b_c_d_e_f_g_h_i_j');
    });

    test('前後の空白とドットを除去する', () {
      expect(BackupService.sanitizeFileName('  .買い物.  '), '買い物');
    });

    test('空または禁止文字のみの場合は list を返す', () {
      expect(BackupService.sanitizeFileName('   '), 'list');
      expect(BackupService.sanitizeFileName('///'), 'list');
    });

    test('50文字を超える場合は切り詰める', () {
      final long = 'あ' * 60;
      expect(BackupService.sanitizeFileName(long).length, 50);
    });
  });
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `flutter test test/backup_test.dart`
Expected: FAIL（`sanitizeFileName` が未定義でコンパイルエラー）

- [ ] **Step 3: 最小実装を書く**

`lib/services/backup_service.dart` の `class BackupService {` 直後（既存メソッドの前）に追加：

```dart
  /// リスト名をファイル名として安全な文字列へ変換する。
  /// 禁止文字を _ に置換し、前後の空白・ドットを除去。空になる場合は 'list'。
  static String sanitizeFileName(String name) {
    final replaced = name.replaceAll(RegExp(r'[\/\\:*?"<>|\x00-\x1F]'), '_');
    final trimmed = replaced.replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
    final base = trimmed.isEmpty ? 'list' : trimmed;
    return base.length > 50 ? base.substring(0, 50) : base;
  }
```

- [ ] **Step 4: テストを実行して成功を確認**

Run: `flutter test test/backup_test.dart`
Expected: PASS（全テスト緑）

- [ ] **Step 5: コミット**

```bash
git add lib/services/backup_service.dart test/backup_test.dart
git commit -m "feat: ファイル名サニタイズ関数を追加（リスト共有のファイル名用）"
```

---

## Task 2: エクスポート Map 構築（純粋関数・TDD）

**Files:**
- Modify: `lib/services/backup_service.dart`
- Test: `test/backup_test.dart`

- [ ] **Step 1: 失敗するテストを書く**

`test/backup_test.dart` の `main()` 内末尾に追加：

```dart
  group('BackupService.buildExportMap', () {
    test('version と各セクションを格納する', () {
      final map = BackupService.buildExportMap(
        lists: [{'id': 1, 'name': 'A', 'createdAt': 100}],
        items: [{'id': 1, 'name': '牛乳', 'listId': 1}],
        favorites: [],
        exportedAt: 12345,
      );
      expect(map['version'], 1);
      expect(map['exportedAt'], 12345);
      expect((map['lists'] as List).length, 1);
      expect((map['items'] as List).length, 1);
      expect((map['favorites'] as List).isEmpty, true);
    });
  });
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run: `flutter test test/backup_test.dart`
Expected: FAIL（`buildExportMap` 未定義）

- [ ] **Step 3: 最小実装を書く**

`lib/services/backup_service.dart` の `sanitizeFileName` の直後に追加：

```dart
  /// version:1 エクスポート Map を構築する（純粋関数）。
  static Map<String, dynamic> buildExportMap({
    required List<Map<String, dynamic>> lists,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> favorites,
    required int exportedAt,
  }) {
    return {
      'version': 1,
      'exportedAt': exportedAt,
      'lists': lists,
      'items': items,
      'favorites': favorites,
    };
  }
```

- [ ] **Step 4: テストを実行して成功を確認**

Run: `flutter test test/backup_test.dart`
Expected: PASS

- [ ] **Step 5: コミット**

```bash
git add lib/services/backup_service.dart test/backup_test.dart
git commit -m "feat: エクスポートMap構築の純粋関数を追加"
```

---

## Task 3: export() を共通化リファクタ ＋ 全データJSON生成ヘルパー

**Files:**
- Modify: `lib/services/backup_service.dart`

- [ ] **Step 1: 全データJSON生成ヘルパーを追加し export() を書き換える**

`lib/services/backup_service.dart` の既存 `export()` メソッド全体を、以下に置き換える：

```dart
  /// 全データを version:1 JSON 文字列に変換する。
  static Future<String> _buildFullBackupJson() async {
    final helper = DatabaseHelper.instance;
    final lists = await helper.getLists();

    final allItems = <Map<String, dynamic>>[];
    for (final list in lists) {
      final items = await helper.getItemsByListId(list.id!);
      allItems.addAll(items.map((i) => i.toMap()));
    }
    final favorites = await helper.getFavorites();

    final map = buildExportMap(
      lists: lists.map((l) => l.toMap()).toList(),
      items: allItems,
      favorites: favorites,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
    );
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// バックアップ用のファイル名を生成する。
  static String _backupFileName() {
    final now = DateTime.now();
    return 'shopping_backup_'
        '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.json';
  }

  /// 全データを JSON ファイルとして共有シートに渡す
  static Future<void> export() async {
    final json = await _buildFullBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_backupFileName()}');
    await file.writeAsString(json);

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '買い物リスト バックアップ',
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
```

- [ ] **Step 2: 静的解析でエラーがないことを確認**

Run: `flutter analyze lib/services/backup_service.dart`
Expected: No issues found（`File`・`getTemporaryDirectory`・`JsonEncoder` は既存 import 済み）

- [ ] **Step 3: 既存テストが壊れていないことを確認**

Run: `flutter test test/backup_test.dart`
Expected: PASS（純粋関数テストは影響なし）

- [ ] **Step 4: コミット**

```bash
git add lib/services/backup_service.dart
git commit -m "refactor: export() を JSON生成ヘルパーで共通化"
```

---

## Task 4: saveToDevice()（端末保存）

**Files:**
- Modify: `lib/services/backup_service.dart`

- [ ] **Step 1: dart:typed_data の import を追加**

`lib/services/backup_service.dart` の先頭 import 群の `import 'dart:convert';` の直後に追加：

```dart
import 'dart:typed_data';
```

- [ ] **Step 2: saveToDevice() を実装**

`export()` メソッドの直後に追加：

```dart
  /// 全データを端末に保存する（file_picker saveFile / Android は SAF）。
  /// 保存した場合 true、キャンセルは false を返す。
  static Future<bool> saveToDevice() async {
    final json = await _buildFullBackupJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'バックアップの保存先を選択',
      fileName: _backupFileName(),
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return path != null;
  }
```

- [ ] **Step 3: 静的解析を確認**

Run: `flutter analyze lib/services/backup_service.dart`
Expected: No issues found

- [ ] **Step 4: コミット**

```bash
git add lib/services/backup_service.dart
git commit -m "feat: バックアップを端末に保存する saveToDevice() を追加"
```

---

## Task 5: shareList()（リスト共有・未購入のみ）

**Files:**
- Modify: `lib/services/backup_service.dart`

- [ ] **Step 1: shareList() を実装**

`saveToDevice()` の直後に追加：

```dart
  /// 指定リスト1件を未購入アイテムのみで共有シートに渡す。
  /// 共有できる商品が無い場合は false を返す。
  static Future<bool> shareList(int listId, String listName) async {
    final helper = DatabaseHelper.instance;
    final lists = await helper.getLists();
    final target = lists.where((l) => l.id == listId).toList();
    if (target.isEmpty) return false;

    final items = await helper.getItemsByListId(listId);
    final unchecked = items.where((i) => !i.isChecked).toList();
    if (unchecked.isEmpty) return false;

    final map = buildExportMap(
      lists: [target.first.toMap()],
      items: unchecked.map((i) => i.toMap()).toList(),
      favorites: const [],
      exportedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final json = const JsonEncoder.withIndent('  ').convert(map);

    final now = DateTime.now();
    final fileName = 'shoppinglist_${sanitizeFileName(listName)}_'
        '${now.year}${_pad(now.month)}${_pad(now.day)}.json';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'リスト「$listName」を共有',
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
    return true;
  }
```

- [ ] **Step 2: 静的解析を確認**

Run: `flutter analyze lib/services/backup_service.dart`
Expected: No issues found

- [ ] **Step 3: コミット**

```bash
git add lib/services/backup_service.dart
git commit -m "feat: リスト1件を未購入のみで共有する shareList() を追加"
```

---

## Task 6: import() の選択フィルタを FileType.any に緩和

**Files:**
- Modify: `lib/services/backup_service.dart`

- [ ] **Step 1: pickFiles のフィルタを変更**

`import()` メソッド内の以下を：

```dart
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
```

次に置き換える：

```dart
    // 共有経由で拡張子が書き換わったファイルも選べるよう拡張子を限定しない。
    // 中身は parseAndValidate で検証するため安全性は変わらない。
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
```

- [ ] **Step 2: 静的解析を確認**

Run: `flutter analyze lib/services/backup_service.dart`
Expected: No issues found

- [ ] **Step 3: 既存テストが緑のままか確認**

Run: `flutter test test/backup_test.dart`
Expected: PASS

- [ ] **Step 4: コミット**

```bash
git add lib/services/backup_service.dart
git commit -m "feat: 読み込みファイル選択を FileType.any に緩和（中身で検証）"
```

---

## Task 7: バックアップ保存先の選択ダイアログ

**Files:**
- Modify: `lib/screens/shopping_list_screen.dart`

- [ ] **Step 1: 既存 _exportBackup() を保存先選択フローに置き換える**

`lib/screens/shopping_list_screen.dart` の既存 `_exportBackup()` メソッド全体を以下に置き換える：

```dart
  Future<void> _exportBackup() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('バックアップ'),
        content: const Text('保存先を選んでください'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('share'),
            child: const Text('共有'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('device'),
            child: const Text('端末に保存'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel' || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'share') {
        await BackupService.export();
      } else {
        final saved = await BackupService.saveToDevice();
        if (!mounted) return;
        if (saved) {
          messenger.showSnackBar(
            const SnackBar(content: Text('端末に保存しました')),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('保存に失敗しました')),
      );
    }
  }
```

- [ ] **Step 2: 静的解析を確認**

Run: `flutter analyze lib/screens/shopping_list_screen.dart`
Expected: No issues found（`BackupService` は既存 import 済み）

- [ ] **Step 3: コミット**

```bash
git add lib/screens/shopping_list_screen.dart
git commit -m "feat: バックアップに保存先選択ダイアログ（共有/端末保存）を追加"
```

---

## Task 8: 「リストを共有（読み込み用）」メニューとハンドラ

**Files:**
- Modify: `lib/screens/shopping_list_screen.dart`

- [ ] **Step 1: enum に shareListFile を追加**

`lib/screens/shopping_list_screen.dart` 末尾付近の以下を：

```dart
enum _OptionItem { share, upgrade, help, deleteList, backup, importBackup }
```

次に置き換える：

```dart
enum _OptionItem { share, shareListFile, upgrade, help, deleteList, backup, importBackup }
```

- [ ] **Step 2: リスト共有ハンドラを追加**

`_shareCurrentList()` メソッドの直後に追加：

```dart
  /// 現在のリストを未購入のみで「読み込み用ファイル」として共有する
  Future<void> _shareListFile() async {
    final currentList = shoppingLists.firstWhere(
      (e) => e.id == currentListId,
      orElse: () => ShoppingList(name: '買い物リスト'),
    );
    final messenger = ScaffoldMessenger.of(context);
    final shared =
        await BackupService.shareList(currentListId, currentList.name);
    if (!mounted) return;
    if (!shared) {
      messenger.showSnackBar(
        const SnackBar(content: Text('共有できる商品がありません')),
      );
    }
  }
```

- [ ] **Step 3: onSelected の switch に分岐を追加**

`PopupMenuButton` の `onSelected` 内 `switch (item)` の `case _OptionItem.share:` ブロックの直後に追加：

```dart
                case _OptionItem.shareListFile:
                  _shareListFile();
```

- [ ] **Step 4: メニュー項目を追加**

`itemBuilder` 内、「テキストで共有」の `PopupMenuItem`（`value: _OptionItem.share`）の直後に追加：

```dart
              const PopupMenuItem(
                value: _OptionItem.shareListFile,
                child: ListTile(
                  leading: Icon(Icons.send_outlined),
                  title: Text('リストを共有（読み込み用）'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
```

- [ ] **Step 5: 静的解析を確認**

Run: `flutter analyze lib/screens/shopping_list_screen.dart`
Expected: No issues found

- [ ] **Step 6: コミット**

```bash
git add lib/screens/shopping_list_screen.dart
git commit -m "feat: リストを共有（読み込み用）メニューを追加"
```

---

## Task 9: 読み込みメニューの文言変更 ＋ 確認ダイアログ追記

**Files:**
- Modify: `lib/screens/shopping_list_screen.dart`

- [ ] **Step 1: 読み込みメニューのラベルを変更**

`itemBuilder` 内の以下を：

```dart
                  title: Text('バックアップデータを読み込む'),
```

次に置き換える：

```dart
                  title: Text('読み込む（バックアップ／共有リスト）'),
```

- [ ] **Step 2: 確認ダイアログの本文を変更**

`_importBackup()` 内の `AlertDialog` の以下を：

```dart
        content: const Text(
          '既存のデータは残したまま、バックアップのデータが追加されます。よろしいですか？',
        ),
```

次に置き換える：

```dart
        content: const Text(
          '既存のデータは残したまま、ファイルのデータが追加されます。\n'
          '共有されたリストもここから読み込めます。よろしいですか？',
        ),
```

- [ ] **Step 3: 静的解析を確認**

Run: `flutter analyze lib/screens/shopping_list_screen.dart`
Expected: No issues found

- [ ] **Step 4: コミット**

```bash
git add lib/screens/shopping_list_screen.dart
git commit -m "feat: 読み込みメニュー・確認文言を共有リスト対応に変更"
```

---

## Task 10: ヘルプダイアログの更新

**Files:**
- Modify: `lib/widgets/help_dialog.dart`

- [ ] **Step 1: 共有・読み込み関連の _HelpItem を更新／追加**

`lib/widgets/help_dialog.dart` を開き、既存の `children` リスト内の項目を次のとおり調整する。

(a) 「テキストで共有」系の項目があればその直後、無ければ「よく買うもの」項目の直後に、次の `_HelpItem` を追加：

```dart
            _HelpItem(
              icon: Icons.send_outlined,
              title: 'リストを共有',
              description: 'メニューの「リストを共有（読み込み用）」で、表示中のリストを'
                  'ファイルとして送れます。受け取った相手は「読み込む」から取り込めます。'
                  '（まだ購入していない商品のみ送られます）',
            ),
```

(b) 既存の「バックアップ」を説明する `_HelpItem` の `description` を次に置き換える：

```dart
              description: '「バックアップ」から、全データの「共有」または「端末に保存」を選べます。',
```

(c) 既存の「バックアップデータを読み込む」を説明する `_HelpItem` の `title` と `description` を次に置き換える：

```dart
              title: '読み込む',
              description: 'バックアップファイルや、共有されたリストファイルを選んで、'
                  '既存のデータに追加読み込みします。',
```

> 既存の `_HelpItem` の正確な文言が上記と一致しない場合は、`icon`/`title`/`description` の3フィールドを持つ該当項目を見つけて意味が通るよう差し替えること。新規追加は (a) のみ。

- [ ] **Step 2: 静的解析を確認**

Run: `flutter analyze lib/widgets/help_dialog.dart`
Expected: No issues found

- [ ] **Step 3: コミット**

```bash
git add lib/widgets/help_dialog.dart
git commit -m "docs: ヘルプにリスト共有・端末保存・読み込み統合を反映"
```

---

## Task 11: 全体解析 ＋ エミュレーター実機確認

**Files:** （変更なし・検証のみ）

- [ ] **Step 1: プロジェクト全体の静的解析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: 全テスト実行**

Run: `flutter test`
Expected: All tests passed

- [ ] **Step 3: デバッグビルド ＆ エミュレーター起動**

```bash
flutter build apk --debug --dart-define=HIDE_ADS=true
```
エミュレーター常駐起動（Global ルール準拠）：
`Start-Process emulator.exe -ArgumentList '-avd','Pixel_9'`

- [ ] **Step 4: 手動確認シナリオ（スクショは `adb shell screencap -p /sdcard/x.png` → `adb pull`）**

確認項目：
1. ⋮ →「リストを共有（読み込み用）」→ 共有シートが開く（未購入ありのリスト）
2. 全アイテム購入済みのリストで同操作 → SnackBar「共有できる商品がありません」
3. ⋮ →「バックアップ」→ ダイアログ「共有／端末に保存／キャンセル」表示
4. 「端末に保存」→ 保存先選択 → 保存後 SnackBar「端末に保存しました」
5. ⋮ →「読み込む（バックアップ／共有リスト）」→ 確認文言に「共有されたリストもここから読み込めます」が出る
6. 端末保存したファイルを 5 で選択 → 「Xリスト・Y件…を追加しました」。共有リストファイルも同様に取り込め、購入済が未購入で入る
7. ⋮ →「使い方」→ リスト共有・読み込みの説明が更新されている

- [ ] **Step 5: 確認結果に問題なければ完了（必要なら最終コミット）**

```bash
git status
```

---

## Task 12: リリース前セキュリティレビュー（Rules 準拠）

**Files:**
- Create: `docs/security_review_2026-06-16-list-share.md`（または実施日）

- [ ] **Step 1: 新規/変更経路のセキュリティ観点を確認**

チェック項目（Rules「リリース」準拠）：
- `saveToDevice` / `shareList` が他フォルダへ不正アクセスしないか（getTemporaryDirectory / SAF 範囲内か）
- 共有ファイルに意図しない個人情報が含まれないか（favorites 空・未購入のみ）
- `import()` の `FileType.any` 緩和後も `parseAndValidate` で不正ファイルを確実に弾くか
- catch 節がユーザーに `e.toString()` を出していないか

- [ ] **Step 2: 結果を docs に保存してコミット**

```bash
git add docs/security_review_2026-06-16-list-share.md
git commit -m "docs: リスト共有・端末保存のセキュリティレビュー結果を追加"
```

---

## Self-Review チェック結果

- **Spec カバレッジ**：リスト共有（未購入のみ・サニタイズ名）=Task5/8、端末保存=Task4/7、読み込み統合・文言=Task6/9、フィルタ緩和=Task6、ヘルプ=Task10、エラー文言（共有0件・保存失敗）=Task7/8。設計書 8.12 の各項目に対応タスクあり。
- **プレースホルダ**：なし（各ステップに実コードまたは実コマンドを記載）。
- **型整合**：`buildExportMap`（Task2）の引数名（lists/items/favorites/exportedAt）を Task3/5 で一致使用。`shareList(int, String)`（Task5）を Task8 のハンドラで同シグネチャ呼び出し。`_OptionItem.shareListFile`（Task8 で追加）を switch/itemBuilder で一致使用。
