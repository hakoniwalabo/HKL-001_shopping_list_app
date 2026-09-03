**カテゴリ**: category　**元ファイル名**: security_review_2026-06-22-category.md

---

# セキュリティレビュー：カテゴリ機能

**実施日**: 2026-06-22  
**対象ブランチ**: `main`  
**レビュー範囲**: カテゴリ機能追加（コミット `300fa8f` 〜 `890a5ee`）。前回レビュー済みのリスト共有・バックアップ端末保存は対象外。

---

## 1. チェック観点と結果

| 観点 | 結果 | 詳細 |
|------|------|------|
| SQLインジェクション | ✅ 問題なし | 全操作でパラメータバインディング使用。`getCategories` は引数なしクエリ、`insertCategory` は Map渡し `db.insert()`、`deleteCategory` は `where: 'id = ?', whereArgs: [id]`、`importData` の categories INSERT も `txn.insert()` の Map渡しで文字列結合なし |
| カテゴリ名バリデーション | ✅ 問題なし | `category_management_dialog.dart`・`add_item_dialog.dart`・`favorites_dialog.dart` いずれも `confirmed != true \|\| newName.isEmpty` のガードで空文字を弾いており、DB 挿入前に通過することはない |
| 削除トランザクション整合性 | ✅ 問題なし | `deleteCategory` は `db.transaction()` 内で items → favorites の `categoryId` を NULL 更新してから `categories` を DELETE。原子的に処理されており、存在しない id を渡した場合も `update`/`delete` は影響行数 0 で例外なし |
| parseAndValidate version:2 | ✅ 問題なし | `version == 2 && data['categories'] is! List` のとき `invalid_json` をスロー。version:1 は `categories` キー不在でも分岐しないため後方互換あり。`lists`・`items`・`favorites` の List チェックは version 共通で実施 |
| importData 業務ルール | ✅ 問題なし | (1) 重複チェック: `existingCatNames.contains(catName)` で確認し既存 id をマッピング後スキップ。(2) 孤立 categoryId: items の `oldCategoryId` が `categoryIdMap` に存在しない場合 `null` にフォールバック済み。(3) 型キャスト: `(cat['id'] as num).toInt()` を全箇所で使用、`as int` は使っていない |
| shareList 情報露出 | ✅ 問題なし | 未購入アイテムが使う categoryId のみを `allCategories` からフィルタして共有。他リストのカテゴリ・購入済みアイテムのカテゴリは含まれない |
| catch 節情報露出 | ✅ 問題なし | カテゴリ操作に catch 節なし（失敗は Riverpod の AsyncError に落ちる）。`shopping_list_screen.dart` の import catch は `FormatException` を switch で日本語メッセージに変換し、それ以外は汎用文言のみ。`e.toString()` はユーザー向けに露出していない |
| ScrollController リーク | ✅ 問題なし | `add_item_dialog.dart` の `_scrollCtrl` は `dispose()` で破棄済み。`shopping_list_screen.dart` の `_listScrollCtrl` も `dispose()` で破棄済み |

---

## 2. 許容したリスク（記録）

**カテゴリ名の長さ制限なし**：SQLite の TEXT 型にサイズ制限はなく、UI 側にも上限チェックがない。数千文字のカテゴリ名を入力・保存することは技術的に可能。ただしローカル DB のみへの書き込みであり、他ユーザーへの影響や認証回避のリスクはないため、個人利用アプリとして許容範囲。必要なら TextField に `maxLength` を追加することで対応可能。

---

## 3. 結論

対象8観点すべてで問題は検出されなかった。SQLインジェクション対策・削除トランザクションの原子性・型安全なキャスト・バックアップ検証・情報露出対策のいずれも適切に実装されている。「カテゴリ名の長さ上限なし」は唯一の軽微な許容リスクだが、個人利用の閉じた環境であるため現時点での修正は不要。カテゴリ機能はセキュリティ上の問題なし。リリース可。
