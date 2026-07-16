# HKL-001 リスト共有 ＋ バックアップ端末保存 設計書

**作成日**: 2026-06-16

---

## 1. 概要

2つの機能を追加する。いずれも既存の JSON シリアライズ基盤（`BackupService` / `DatabaseHelper.importData`）を流用し、追加コードを最小化する。新規パッケージは不要。

1. **アプリ同士のリスト共有** — 現在のリスト1件を「読み込み用ファイル」として共有シートで送り、受信側は既存の読み込み機能で取り込む。
2. **バックアップの端末保存** — バックアップを共有シートだけでなく、端末ストレージにも保存できるようにする。

あわせて、共有シート経由で運ばれたファイルの拡張子が書き換わっても読み込めるよう、読み込みのファイル選択フィルタを緩める。

---

## 2. 要件まとめ

| 項目 | 内容 |
|------|------|
| リスト共有の単位 | 現在表示中のリスト1件 |
| リスト共有のファイル形式 | 既存バックアップ形式（`lists`=1件・`items`=該当商品・`favorites`=空。2026-07-05 追記：2026-06-22 のカテゴリ機能追加以降は version:2、使用カテゴリのみの `categories` を含む） |
| 共有時の購入済アイテム | **含めない（除外）** — 未購入のものだけを送る |
| 受信（取り込み）方法 | 既存の読み込み機能に統合（別メニューを増やさない） |
| バックアップ保存先 | タップ後にダイアログで「共有」「端末に保存」を選択 |
| 端末保存の方法 | `file_picker` の `saveFile`（Android は SAF で保存先選択） |
| 読み込み対象 | 端末保存ファイル・共有受信ファイル・バックアップファイルすべて（同一の `import()` 経路） |
| 読み込みフィルタ | `FileType.any`（拡張子不問）＋中身で妥当性判定 |
| UI 配置 | ⋮ オプションメニュー |
| バージョンアップ | Play Console アップ報告まで凍結（`pubspec.yaml` の version 行は変更しない） |

---

## 3. アーキテクチャ

### 3.1 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/services/backup_service.dart` | シリアライズ共通化・`saveToDevice()`・`shareList()` 追加・`import()` のフィルタ緩和 |
| `lib/screens/shopping_list_screen.dart` | メニューに「リストを共有（読み込み用）」追加・「バックアップ」を選択ダイアログ化・読み込みメニューの文言変更・確認ダイアログ文言追加 |
| `lib/widgets/help_dialog.dart` | リスト共有・端末保存の説明を反映（Rules 必須） |

> 新規パッケージ追加なし（`share_plus` / `file_picker` / `path_provider` は既存）。`pubspec.yaml` は変更しない。

### 3.2 依存関係

```
shopping_list_screen.dart
  └─ BackupService
       ├─ DatabaseHelper（DB 読み書き）
       ├─ share_plus（共有シート：export / shareList）
       ├─ file_picker（端末保存：saveFile / 読み込み：pickFiles）
       └─ path_provider（共有用一時ファイル）
```

---

## 4. ファイル形式

### 4.1 リスト共有ファイル

既存バックアップ形式をそのまま使う（受信側の `importData` を無改修で流用するため）。

- `lists` … 共有対象の1リストのみ
- `items` … そのリストの**未購入（isChecked=0）アイテムのみ**
- `favorites` … 空配列 `[]`
- `categories` … 共有されるアイテムが実際に使用しているカテゴリのみ（2026-07-05 追記：下記参照）

```json
{
  "version": 2,
  "exportedAt": 1718500000000,
  "categories": [
    { "id": 3, "name": "食品", "sortOrder": 0, "createdAt": 1700000003000 }
  ],
  "lists": [
    { "id": 1, "name": "週末の買い物", "createdAt": 1700000000000 }
  ],
  "items": [
    {
      "id": 10, "name": "牛乳", "price": 198, "isChecked": 0,
      "createdAt": 1700000001000, "sortOrder": 0,
      "quantity": 2, "memo": "", "listId": 1, "categoryId": 3
    }
  ],
  "favorites": []
}
```

（2026-07-05 追記：本設計書作成時点（2026-06-16）では version:1・`categories` 無しの形式だったが、2026-06-22 のカテゴリ機能追加（commit `3faa0a1`・`ca4fecc`）で `shareList()` も共有アイテムの `categoryId` から使用カテゴリを集めて `categories` に含めるようになり、リスト共有ファイルも version:2 となった。カテゴリ機能自体の詳細は `2026-06-22-category-design.md` を参照）

**ファイル名**: `shoppinglist_<リスト名>_YYYYMMDD.json`
（リスト名はファイル名に使えない文字をサニタイズ。空になる場合は `list` を代替）

### 4.2 バックアップファイル

既存どおり（全 lists・items・favorites を含む）。ファイル名も既存どおり `shopping_backup_YYYYMMDD_HHmmss.json`。

---

## 5. 処理フロー

### 5.1 リストを共有（読み込み用・新規）

```
⋮ メニュー →「リストを共有（読み込み用）」タップ
→ BackupService.shareList(listId)
    → 対象リストと、その未購入アイテムのみを取得
    → version:2 形式（favorites=[]、使用カテゴリのみの categories を含む）で JSON 文字列を生成（2026-07-05 追記：2026-06-22 のカテゴリ機能追加で version:1→2 に変更。詳細は 4.1 節参照）
    → getTemporaryDirectory() に shoppinglist_<名>_YYYYMMDD.json として保存
    → Share.shareXFiles([XFile(path)]) で共有シート表示
    → 後始末で一時ファイル削除
→ 完了（共有シートは OS 側で処理）
```

- リストが空（未購入アイテム0件）の場合は共有せず SnackBar「共有できる商品がありません」を表示。

### 5.2 バックアップ（保存先選択・変更）

```
⋮ メニュー →「バックアップ」タップ
→ 選択ダイアログ（「共有」「端末に保存」「キャンセル」）
    ├─「共有」    → BackupService.export()      （現状どおり共有シート）
    └─「端末に保存」→ BackupService.saveToDevice()
           → 全データを JSON 文字列に生成
           → FilePicker.platform.saveFile(
                 fileName: 'shopping_backup_...json',
                 bytes: <utf8 bytes>,
                 type: FileType.custom, allowedExtensions: ['json'])
           → ユーザーが保存先を選択 → 端末に書き込み
           → 成功: SnackBar「端末に保存しました」 / キャンセル: 何もしない
```

### 5.3 読み込む（バックアップ／共有リスト・統合）

```
⋮ メニュー →「読み込む（バックアップ／共有リスト）」タップ
→ 確認ダイアログ
   「既存のデータは残したまま、ファイルのデータが追加されます。
     共有されたリストもここから読み込めます。よろしいですか？」
→ BackupService.import()
    → FilePicker でファイル選択（FileType.any・拡張子不問）
    → ファイル読み込み・JSON パース
    → parseAndValidate（version・必須キー存在確認）
    → DatabaseHelper.importData(data) でマージ INSERT
        → lists: 同名は連番付与（resolveListName）→ 旧ID→新ID マップ
          （createdAt はバックアップの値を使わず、既存リストの MAX(createdAt)+1 から採番し直す）
        → items: listId を新 ID に差し替えて INSERT
        → favorites: MAX(sortOrder)+1 から採番（リスト共有ファイルは空なので追加なし）
        → 既存リスト数＋インポート後のリスト数が10件を超える場合は中断（6節参照）
    → loadLists() → ref.invalidate(categoryProvider) → 新規追加された最初のリストへ自動タブ切り替え
      （見つからない場合は現在のリストのまま再読込）
→ SnackBar「Xリスト・Y件の商品・Z件のよく買うものを追加しました」
```

（2026-07-05 追記：本フローはバックアップ・共有リストいずれのファイルでも同一の `BackupService.import()` / `DatabaseHelper.importData()` 経路を通るため、`2026-06-13-backup-design.md` の 5.2 節で追記した「10件上限チェック」「favorites の name 重複スキップ」「categoryProvider 再取得＋新規リストへの自動タブ切り替え」（commit `db0ff87`・`64c0b6a`・`020c8d3`）は本機能のリスト共有ファイル読み込みにもそのまま適用される。詳細な挙動はそちらを参照）

---

## 6. エラーハンドリング

| ケース | 対応 |
|--------|------|
| 共有対象リストが空 | SnackBar「共有できる商品がありません」（共有しない） |
| ファイル選択キャンセル | 何もしない（静かに終了） |
| 端末保存キャンセル | 何もしない |
| 端末保存失敗 | SnackBar「保存に失敗しました」（`e.toString()` は使わない） |
| JSON パース失敗・中身不正 | SnackBar「読み込めないファイルです」 |
| version 不一致 | SnackBar「対応していないバックアップ形式です」 |
| 10件上限超過 | SnackBar「リストが上限（10件）に達しているため読み込めません」 |
| DB 書き込み失敗 | SnackBar「読み込みに失敗しました」 |

> 拡張子フィルタを `FileType.any` に緩めるため、無関係なファイルを選んでも `parseAndValidate` が「読み込めないファイルです」で安全に弾く。

---

## 7. UI 変更

### 7.1 ⋮ オプションメニュー

```
リストを削除
テキストで共有
リストを共有（読み込み用）        ← 新規追加
バックアップ                      ← 押すと保存先選択ダイアログ（変更）
読み込む（バックアップ／共有リスト） ← 文言変更（旧「バックアップデータを読み込む」）
広告を削除（条件付き）
使い方
```

- 「テキストで共有」＝読むだけのテキスト（既存・変更なし）
- 「リストを共有（読み込み用）」＝アプリで取り込めるファイル（新規）

### 7.2 バックアップ保存先ダイアログ

```
タイトル: バックアップ
本文:     保存先を選んでください
[共有]  [端末に保存]            （アクション。キャンセルは「閉じる」/バリア外タップ）
```

### 7.3 ヘルプダイアログ（`help_dialog.dart`）

| タイトル | 説明（要旨） |
|---------|-------------|
| リストを共有 | 「リストを共有（読み込み用）」で、表示中のリストをファイルとして送れます。受け取った相手は「読み込む」から取り込めます（未購入の商品のみ送られます） |
| バックアップ | 「バックアップ」から、共有または端末への保存を選べます |
| 読み込む | バックアップファイルや共有されたリストファイルを選んで、既存データに追加読み込みします |

> 既存のバックアップ系 `_HelpItem` は本変更に合わせて文言を更新する。

---

## 8. `BackupService` クラス設計

```dart
class BackupService {
  /// エクスポート Map（version:2 形式）を組み立てる純粋関数。
  /// categories / lists / items / favorites を呼び出し側が用意し、
  /// export() / saveToDevice() / shareList() の全てがこれを呼ぶ。
  static Map<String, dynamic> buildExportMap({
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> lists,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> favorites,
    required int exportedAt,
  });

  /// 全データ（categories・lists・items・favorites）を DB から取得し、
  /// buildExportMap() で version:2 JSON 文字列に変換する（private）。
  static Future<String> _buildFullBackupJson();

  /// 全データを共有シートに渡す（既存）。内部で _buildFullBackupJson() を使う。
  static Future<void> export();

  /// 全データを端末に保存する（file_picker saveFile / SAF）。
  /// 内部で _buildFullBackupJson() を使う。保存した場合 true、キャンセルは false。
  static Future<bool> saveToDevice();

  /// 指定リスト1件・未購入アイテムのみ・そのアイテムが使用しているカテゴリのみを集めて
  /// buildExportMap(favorites: const []) で JSON 化し、共有シートに渡す。
  /// 共有できる商品が無い場合は false を返す。
  static Future<bool> shareList(int listId, String listName);

  /// ファイルを選択してマージ import（FileType.any・中身で検証）。
  static Future<ImportResult?> import();

  /// JSON 文字列の検証（既存・変更なし）。
  static Map<String, dynamic> parseAndValidate(String content);
}
```

- （2026-07-05 追記：当初案では private な `_serialize({onlyListId, excludeChecked})` に一本化する設計だったが、実装では commit `27b11b0` で public かつ純粋関数の `buildExportMap()` を切り出し、DB 取得を担う `_buildFullBackupJson()`（`export()` / `saveToDevice()` が使用）と、`shareList()` 内で対象リスト・未購入アイテム・使用カテゴリのみを個別に集めて `buildExportMap()` を直接呼ぶ経路とに分かれる形へ commit `83ab4ce` でリファクタリングされた。両 commit とも本設計書と同日 2026-06-16 のため、後日のドリフトではなく実装時点での設計変更に当たる）
- `export()` / `saveToDevice()` は `_buildFullBackupJson()` 経由で全データを、`shareList()` は自前で集めた対象リストのデータのみを、それぞれ `buildExportMap()` に渡す。

---

## 9. ファイル名サニタイズ

リスト名をファイル名に使うため、OS で問題となる文字を除去・置換する。

```
許可しない文字（/ \ : * ? " < > | と制御文字）を _ に置換
→ 前後の空白・ドットをトリム
→ 結果が空なら "list" を使う
→ 長すぎる場合は適度に切り詰める
```

---

## 10. 設計上の注意・非対象（YAGNI）

- **双方向リアルタイム同期は対象外**（バックエンド不要のローカルアプリ方針を維持）。
- **QR コード共有は対象外**（今回はファイル共有のみ）。
- リスト共有ファイルもバックアップファイルも形式が同一のため、読み込み口は1つに統合する（入口を分けない）。
- インポート経路にも UI と同等の業務ルールチェック（10件上限）が `importData` に実装済みであることを前提とする（Rules 準拠）。
