# HKL-001 セキュリティチェック レポート

**実施日：** 2026-06-14  
**対象：** HKL-001 買い物リストアプリ（Flutter）  
**対象バージョン：** versionCode 4（version 1.0.1+4）  
**対象コミット：** `f5e5f16`  
**チェックスコープ：** バックアップ機能追加（rev8.3）後の全ファイル

---

## チェック項目と結果

### 1. 挙動が不明確な関数・変数

| 箇所 | 内容 | 対応 |
|------|------|------|
| `database_helper.dart:582` | `itemCount: incomingItems.length` がスキップ分も含む（`listIdMap` に存在しない `listId` のアイテムは挿入をスキップするが件数には計上される） | 許容（件数差は軽微） |
| `shopping_list_screen.dart:40` | `currentListId = 1` の初期値ハードコード。`loadLists()` の `exists` チェックで実害は防いでいる | 許容 |

---

### 2. デバイスの他フォルダへのアクセス

**問題なし。** アプリが触れるファイルシステム領域はすべてアプリサンドボックス内に限定されています。

| アクセス先 | 内容 | 判定 |
|------------|------|------|
| `getTemporaryDirectory()` | アプリ専用キャッシュ領域（`/data/data/<pkg>/cache/`）。エクスポート一時ファイルの書き出し先 | ✅ 安全 |
| `getDatabasesPath()` | sqflite 標準のアプリ専用 DB ディレクトリ | ✅ 安全 |
| `FilePicker.platform.pickFiles()` | SAF（Storage Access Framework）経由。ユーザーが明示的に選択したファイルのみ読み取り | ✅ 安全 |

**AndroidManifest.xml 確認：**  
`INTERNET` のみ宣言。`READ_EXTERNAL_STORAGE`・`WRITE_EXTERNAL_STORAGE`・`MANAGE_EXTERNAL_STORAGE` の宣言なし。✅

---

### 3. デバイスの脆弱性リスク

#### [許容] `is_ad_free` の SharedPreferences 保存

- **ファイル：** `purchase_provider.dart:9,16`
- **内容：** 広告削除フラグを SharedPreferences（平文 XML）に保存している。root 化端末では `/data/data/<pkg>/shared_prefs/` を直接書き換えることで広告削除を無料で有効化できる。
- **緩和措置：** `cached = false` のときのみ `restorePurchases()` で Play Store 照合が走る。`cached = true` に書き換えるとこの照合がスキップされる。
- **判断：** 完全な対策には Play Integrity API が必要。個人アプリ規模では過剰投資のため **現状許容**。

#### [クリーン] SQLインジェクション

全クエリが `where: 'col = ?', whereArgs: [...]` のプレースホルダー経由。`rawQuery` にもユーザー入力の直接埋め込みなし。✅

#### [クリーン] ネットワーク通信

カスタム HTTP 通信なし。AdMob SDK・`in_app_purchase` SDK に委譲。証明書検証バイパス・`HttpClient` 直接操作なし。✅

---

### 4. その他のセキュリティ懸念

| 項目 | 修正前 | 修正後 | コミット |
|------|--------|--------|---------|
| DB エラー内容の UI 露出 | `Text('Error: $error')` | `Text('データの読み込みに失敗しました')` | `f5e5f16` |
| 購入例外メッセージの UI 露出 | `return e.toString()` | 汎用メッセージ返却 | `f5e5f16` |

---

## 今回修正した問題（バックアップ機能レビュー由来）

| コミット | 問題 | 修正内容 |
|---------|------|---------|
| `db0ff87` | [C-1] インポート経路に 10 件上限チェックがない | `importData` に `list_limit_exceeded` チェック追加 |
| `db0ff87` | [C-2] favorites の重複インポート防止がない | name 一致でスキップするロジック追加 |
| `db0ff87` | [M-1] `version` が String・null のとき誤った例外を返す | `is! int` チェックを先行させて `invalid_json` を返す |
| `db0ff87` | [M-2] `list['id'] as int` が float 値で TypeError | `(num).toInt()` に変更 |
| `43674a5` | [M-2] `item['listId'] as int` も同様 | `(num).toInt()` に変更 |

---

## 総評

**重大なセキュリティ脆弱性は確認されませんでした。**

SQLインジェクション対策・ファイルシステム隔離・パーミッション最小化はすべて適切に実装されています。バックアップ機能追加に伴う入力バリデーション強化（上限チェック・重複防止・型安全化）も完了しています。

許容事項として記録した `is_ad_free` の SharedPreferences 保管については、将来的に Play Integrity API を導入する場合の候補として管理します。
