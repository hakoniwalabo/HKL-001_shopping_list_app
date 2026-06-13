# HKL-001 バックアップ・機種変更引継ぎ機能 設計書

**作成日**: 2026-06-13

---

## 1. 概要

SQLite に保存されているデータを JSON ファイルとしてエクスポートし、Android 共有シートで送受信できるようにする。新しい端末でそのファイルを読み込むと、既存データを残したままマージ追加される。

---

## 2. 要件まとめ

| 項目 | 内容 |
|------|------|
| バックアップ対象 | lists・items・favorites（item_history は除外） |
| エクスポート方法 | Android 共有シート（`Share.shareXFiles()`） |
| インポート方法 | file_picker でファイル選択 |
| 復元時の挙動 | マージ（既存データを残して追加） |
| 同名リストの衝突 | 末尾に連番付与（例：「買い物リスト(2)」） |
| UI 配置 | ⋮ オプションメニュー |
| バージョンアップ | Play Console アップ報告まで凍結 |

---

## 3. アーキテクチャ

### 3.1 新規ファイル

| ファイル | 役割 |
|---------|------|
| `lib/services/backup_service.dart` | エクスポート・インポートのビジネスロジック |

### 3.2 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/database/database_helper.dart` | `importData()` メソッド追加 |
| `lib/screens/shopping_list_screen.dart` | ⋮ メニューに2項目追加・ハンドラ実装 |
| `lib/widgets/help_dialog.dart` | バックアップ関連の `_HelpItem` 2件追加 |
| `pubspec.yaml` | `file_picker` 追加 |

### 3.3 依存関係

```
shopping_list_screen.dart
  └─ BackupService
       ├─ DatabaseHelper（DB 読み書き）
       ├─ share_plus（既存・エクスポート用）
       ├─ file_picker（新規・インポート用）
       └─ path_provider（一時ファイル保存・既存）
```

> `pubspec.yaml` への追記は `file_picker` と `path_provider`（一時ファイル保存用）の2パッケージ。

---

## 4. バックアップファイル形式

**ファイル名**: `shopping_backup_YYYYMMDD_HHmmss.json`

```json
{
  "version": 1,
  "exportedAt": 1718236800000,
  "lists": [
    { "id": 1, "name": "買い物リスト", "createdAt": 1700000000000 }
  ],
  "items": [
    {
      "id": 1, "name": "牛乳", "price": 198, "isChecked": 0,
      "createdAt": 1700000001000, "sortOrder": 0,
      "quantity": 2, "memo": "", "listId": 1
    }
  ],
  "favorites": [
    {
      "id": 1, "name": "卵", "price": 248, "quantity": 1,
      "sortOrder": 0, "createdAt": 1700000002000
    }
  ]
}
```

**設計意図:**
- `version` フィールドで将来のフォーマット変更に対応
- `lists.id` / `items.listId` はバックアップ内でのみ有効な仮 ID。インポート時に DB の実際の新 ID にマッピングし直す

---

## 5. 処理フロー

### 5.1 エクスポート（バックアップ）

```
⋮ メニュー →「バックアップ」タップ
→ BackupService.export()
    → DB から lists・items・favorites を全取得
    → JSON 文字列を生成
    → getTemporaryDirectory() に shopping_backup_YYYYMMDD_HHmmss.json として保存
    → Share.shareXFiles([XFile(path)]) で共有シート表示
→ 完了（共有シートは OS 側で処理）
```

### 5.2 インポート（バックアップデータを読み込む）

```
⋮ メニュー →「バックアップデータを読み込む」タップ
→ 確認ダイアログ「既存データは残したまま追加されます。よろしいですか？」
→ BackupService.import()
    → FilePicker でファイル選択（.json フィルタ）
    → ファイル読み込み・JSON パース
    → バリデーション（version・必須キー存在確認）
    → DatabaseHelper.importData(data) でマージ INSERT
        → lists: 同名リストに連番付与（「リスト名 (2)」）→ INSERT → 旧ID→新ID マップ作成
        → items: listId を新 ID に差し替えて INSERT（sortOrder はそのまま）
        → favorites: 現在の MAX(sortOrder)+1 から採番して INSERT
→ SnackBar「Xリスト・Y件の商品・Z件のよく買うものを追加しました」
```

---

## 6. エラーハンドリング

| ケース | 対応 |
|--------|------|
| ファイル選択キャンセル | 何もしない（静かに終了） |
| JSON パース失敗 | SnackBar「読み込めないファイルです」 |
| version 不一致（version ≠ 1） | SnackBar「対応していないバックアップ形式です」 |
| DB 書き込み失敗 | SnackBar「読み込みに失敗しました」 |

---

## 7. UI 変更

### 7.1 ⋮ オプションメニュー

```
リストを削除
テキストで共有
バックアップ                    ← 新規追加
バックアップデータを読み込む     ← 新規追加
広告を削除（条件付き）
使い方
```

### 7.2 ヘルプダイアログ（`help_dialog.dart`）

追加する `_HelpItem` 2件：

| タイトル | 説明 |
|---------|------|
| バックアップ | データを JSON ファイルとして書き出し、メール・クラウドで保存できます |
| バックアップデータを読み込む | バックアップファイルを選択して、既存データに追加読み込みします |

---

## 8. `BackupService` クラス設計

```dart
class BackupService {
  // 全データを JSON ファイルとして共有シートに渡す
  static Future<void> export() async { ... }

  // ファイルを選択してマージ import。結果を返す
  static Future<ImportResult?> import() async { ... }
}

class ImportResult {
  final int listCount;
  final int itemCount;
  final int favoriteCount;
}
```

---

## 9. `DatabaseHelper.importData()` 設計

```dart
Future<ImportResult> importData(Map<String, dynamic> data) async {
  // 1. lists INSERT + 旧ID→新ID マップ作成
  //    同名リストは連番付与（duplicateList と同じロジック）
  // 2. items INSERT（listId をマップで差し替え）
  // 3. favorites INSERT（sortOrder を MAX+1 から採番）
  // 4. ImportResult を返す
}
```

---

## 10. 同名リスト連番付与ロジック

既存の `duplicateList()` で採用している方式と統一する。

```
既存リスト名一覧を取得
→ 追加しようとするリスト名が重複する場合:
    "リスト名(2)" → "リスト名(3)" → ... と空き番号を探す
→ 重複しない番号で INSERT
```

> shopping_list_screen.dart の複製ロジックと同じパターン（`'$baseName($i)'`）を使う。
