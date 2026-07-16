# カテゴリ機能 設計書

**作成日：** 2026-06-22  
**対象アプリ：** HKL-001 買い物リストアプリ  
**基準設計書：** spec_HKL-001_shopping_list_app_rev8.4.md

---

## 1. 概要

ユーザーが自由に命名できるカスタムカテゴリを導入し、買い物リストをカテゴリごとのセクションに分けて表示する。カテゴリはアプリ全体で共通管理する。カテゴリを一切設定しなくても現行と同じように動作するため、既存ユーザーへの影響はない。

---

## 2. データ設計

### 2.1 categories テーブル（新規）

| カラム | 型 | 内容 |
|--------|----|------|
| id | INTEGER | PK（自動採番） |
| name | TEXT | カテゴリ名 |
| sortOrder | INTEGER | 並び順（表示順） |
| createdAt | INTEGER | 作成日時（UnixミリS） |

### 2.2 items テーブル（変更）

| カラム | 追加内容 |
|--------|---------|
| categoryId | INTEGER nullable、FK: categories.id。未設定時は NULL |

### 2.3 favorites テーブル（変更）

| カラム | 追加内容 |
|--------|---------|
| categoryId | INTEGER nullable、FK: categories.id。未設定時は NULL |

### 2.4 カテゴリの永続保存

カテゴリは一度作成したら categories テーブルに永続保存し、次回以降の商品登録で再利用できる。  
商品・よく買うものがゼロになっても自動削除しない。削除は「カテゴリを管理」画面から手動で行う。

### 2.5 DB バージョン

| バージョン | 変更内容 |
|-----------|---------|
| version 7 | categories テーブル追加・items に categoryId カラム追加・favorites に categoryId カラム追加 |

Migration 方針：
- `ALTER TABLE items ADD COLUMN categoryId INTEGER` で追加（NULL 許容のため再作成不要）
- `ALTER TABLE favorites ADD COLUMN categoryId INTEGER` で追加
- `CREATE TABLE categories (...)` で新規作成

---

## 3. 画面設計

### 3.1 リスト画面のセクション構造

カテゴリを導入後、未購入セクションをカテゴリ別に分割して表示する。

```
合計表示（TabBar 直下・固定）

［未購入セクション］
  🥦 野菜                   ← カテゴリヘッダー
    ☐ にんじん ¥98 ×2
    ☐ キャベツ ¥148 ×1
  🥩 肉
    ☐ 鶏もも ¥398 ×1
  📦 カテゴリなし            ← categoryId=NULL の商品
    ☐ 醤油 ¥0 ×1

［購入済みセクション］       ← カテゴリ区別なし（現行どおり）
  ☑ 牛乳 ¥198 ×2
```

**表示ルール**
- カテゴリの並び順：categories.sortOrder 昇順
- カテゴリなしは常に未購入セクションの最後に表示
- カテゴリを1件も設定していない場合：「カテゴリなし」ヘッダーを省略し、現行と同じフラットな表示にする
- 購入済みセクションはカテゴリを区別しない（現行どおり）

### 3.2 並び替え（ドラッグ）

- **セクション内のみ**ドラッグ移動可能
- セクションをまたぐ移動は不可
- カテゴリの変更は編集ダイアログから行う

### 3.3 合計表示

カテゴリ横断で全商品を対象に計算する（現行と変わらず）。

---

## 4. 商品ダイアログ設計

### 4.1 追加ダイアログ（add_item_dialog.dart）

カテゴリフィールドを追加する。

```
┌─ 商品を追加 ──────────────────┐
│ 商品名  [にんじん            ] │
│ 金額   [98                 ] │
│ 個数   [2                  ] │
│ カテゴリ（任意）               │
│         [（未選択）▼] [＋新規] │
│          [キャンセル]  [追加] │
└───────────────────────────────┘
```

- フィールドラベルは「カテゴリ（任意）」と明示する（高齢ユーザーが何を入れるか迷わないように）
- ドロップダウン：categories テーブルの全件を sortOrder 昇順で表示
- 初期値：未選択（categoryId = NULL）
- 「＋新規」タップ：名前入力の小ダイアログを表示し、作成と同時にドロップダウンで選択状態にする
- 未選択のまま追加可能（カテゴリなし扱い）

### 4.2 編集ダイアログ

追加ダイアログと同様のカテゴリフィールドを表示する。既存のカテゴリが設定済みの場合はそれを初期値とする。

### 4.3 よく買うもの ダイアログ（favorites_dialog.dart）

直接登録・編集ダイアログにも同様のカテゴリフィールドを追加する。よく買うものをリストに追加するとき、categoryId も items に引き継ぐ。

（2026-07-05 追記：カテゴリのドロップダウン自体は commit ca4fecc（2026-06-22、本設計書と同日）で `_AddFavoriteDialog`・`_EditFavoriteDialog` の両方に追加されたが、「＋新規カテゴリ」ボタン（インラインでカテゴリを作成する `IconButton`＋`_showNewCategoryDialog()`）は当初 `_AddFavoriteDialog` にのみ実装されており、`_EditFavoriteDialog` への追加は1週間後の commit e38909d（2026-06-29）まで漏れていた。現在は両ダイアログで同一UIに統一済み。）

---

## 5. DatabaseHelper 追加メソッド

| メソッド | シグネチャ | 内容 |
|---------|-----------|------|
| getCategories | `Future<List<Map<String, dynamic>>> getCategories()` | 全件取得（sortOrder ASC） |
| insertCategory | `Future<int> insertCategory(String name)` | 新規作成（sortOrder は MAX+1）、作成した id を返す |
| deleteCategory | `Future<void> deleteCategory(int id)` | 1件削除。紐付く items・favorites の categoryId は NULL にリセット |

---

## 6. カテゴリ管理画面

### 6.1 アクセス方法

⋮ メニューに「カテゴリを管理」を追加する。

```
⋮ オプションメニュー
  ├─ リストを削除
  ├─ テキストで共有
  ├─ リストを共有（読み込み用）
  ├─ バックアップ
  ├─ 読み込む（バックアップ／共有リスト）
  ├─ カテゴリを管理          ← 新規追加
  ├─ 広告を削除（購入済みの場合は非表示）
  └─ 使い方（ヘルプ）
```

### 6.2 画面構成

```
AlertDialog「カテゴリを管理」
  ├─ カテゴリ一覧（0件時：「まだカテゴリがありません」）
  │   └─ ListTile × カテゴリ件数
  │       ├─ title: カテゴリ名
  │       ├─ subtitle: 使用中の商品数（items + favorites の合計件数）
  │       └─ trailing: 削除アイコン（🗑）タップ → 確認なしで即削除
  ├─ 「＋ カテゴリを追加」TextButton
  └─ 「閉じる」TextButton
```

### 6.3 削除時の動作

- 対象カテゴリを categories テーブルから削除する
- 紐付く items.categoryId・favorites.categoryId を NULL にリセット（カテゴリなし扱いに変わる）
- トランザクションで原子的に実行
- 削除後にリスト画面の表示を即時更新する

---

## 8. バックアップ形式

カテゴリ追加に伴い `version:2` に更新する。

```json
{
  "version": 2,
  "exportedAt": 1718236800000,
  "categories": [
    { "id": 1, "name": "野菜", "sortOrder": 0, "createdAt": 1700000000000 }
  ],
  "lists": [...],
  "items": [
    { "id": 1, "name": "にんじん", "categoryId": 1, ... }
  ],
  "favorites": [
    { "id": 1, "name": "卵", "categoryId": null, ... }
  ]
}
```

### version:1 との互換性

- version:1 のバックアップ読み込み時：categoryId を NULL として扱う（既存動作を維持）
- `parseAndValidate` で version フィールドを確認し、1 または 2 を受け入れる

### リスト共有（スナップショット）

version:2 形式で出力する。categories には、共有対象アイテムが使用しているカテゴリのみを含める。

### インポート時のカテゴリ処理（2026-07-05 追記：`importData()` の実装詳細が未記載だったため補足）

- 取り込む categories は `name` で既存カテゴリと重複チェックする。同名カテゴリが既に存在する場合は新規作成せず、既存の id を使う
- 重複しないカテゴリのみ新規 INSERT する。sortOrder は既存カテゴリの `MAX(sortOrder)+1` から連番で採番する
- 上記の対応関係から旧id→新id の `categoryIdMap` を作成し、取り込む items・favorites の categoryId をこのマップで新idに置き換えてから INSERT する（マッピングが無い＝対応するカテゴリが取り込まれなかった場合は categoryId を null にする）

---

## 9. 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `database/database_helper.dart` | categories テーブル追加・DB v7 migration・getCategories / insertCategory / deleteCategory 追加・importData の version:2 対応 |
| `models/item.dart` | categoryId フィールド追加（int? nullable） |
| `models/category.dart` | 新規作成（Category モデル） |
| `providers/item_provider.dart` | カテゴリ別セクション分け用のデータ整形処理追加 |
| `providers/category_provider.dart` | 新規作成（`CategoryNotifier`／`categoryProvider`。`AsyncNotifier<List<Category>>` で categories を保持し、`addCategory()` は作成した id を返してダイアログの選択状態に反映する）（2026-07-05 追記：本ファイルの初版で列挙漏れがあったため追加。commit 9305005 で本設計書と同日に実装済み） |
| `screens/shopping_list_screen.dart` | 未購入セクションをカテゴリ別に分割表示 |
| `widgets/add_item_dialog.dart` | カテゴリ選択フィールド・新規カテゴリ作成ダイアログ追加 |
| `widgets/category_management_dialog.dart` | 新規作成（カテゴリ管理ダイアログ） |
| `widgets/favorites_dialog.dart` | カテゴリ選択フィールド追加・追加時に categoryId を引き継ぐ処理 |
| `services/backup_service.dart` | version:2 対応・categories のシリアライズ・デシリアライズ |

---

## 10. 既存データへの影響

- 既存の items・favorites はすべて `categoryId = NULL`（カテゴリなし）として扱われる
- 既存ユーザーはカテゴリを設定しなければ従来と同じ表示のまま使い続けられる

---

## 11. スコープ外（今回対応しない）

- カテゴリの並び替え（手動 reorder）
- カテゴリへのアイコン・色付け
- カテゴリ単位でのフィルタリング表示
- セクションをまたぐドラッグ移動
- カテゴリ別小計の表示
- リスト別カテゴリ管理

## 12. 将来課題

| 課題 | 背景 |
|------|------|
| ⋮ メニューの整理 | カテゴリ管理追加により8項目になる。項目が増え続けた場合に設定画面への集約を検討 |
| カテゴリ別小計 | 費用管理・節約目的ユーザー（テスター05・09）のニーズ。合計表示の拡張として将来検討 |
| リスト別カテゴリ | 業務用・家庭用を完全分離したいユーザー（テスター08）のニーズ。全体共通の現設計では業務カテゴリが家庭用に混入する |

---

*作成：2026-06-22　ブレインストーミングセッションより*
