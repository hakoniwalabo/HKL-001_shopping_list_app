# セキュリティレビュー：カテゴリバグ修正・編集ダイアログ改善

**実施日**: 2026-06-29  
**対象ブランチ**: `main`  
**レビュー範囲**: コミット `835622a`〜`fcc4ea5`（restoreFavorite categoryId 追加・_EditFavoriteDialog カテゴリ追加ボタン・カテゴリ削除後のアイテム消失バグ修正）。前回レビュー済みのよく買うものダイアログ改善（コミット `d3d668e` まで）は対象外。

---

## 1. チェック観点と結果

| 観点 | 結果 | 詳細 |
|------|------|------|
| SQLインジェクション | ✅ 問題なし | `restoreFavorite`（categoryId 追加）・`deleteCategory`（items/favorites の categoryId を NULL 更新）はすべて `whereArgs` / Map渡しのパラメータバインディングを使用。文字列結合なし |
| 入力バリデーション | ✅ 問題なし | `_EditFavoriteDialog._showNewCategoryDialog()` の `newName.isEmpty` チェックで空カテゴリ名を防止。確認後のみ `addCategory()` を呼び出す |
| 業務ルール一貫性 | ✅ 問題なし | `deleteCategory()` はトランザクション内で items・favorites の `categoryId` を NULL 更新してからカテゴリを削除。DB 整合性が保たれる |
| マウントチェック | ✅ 修正済み | `_EditFavoriteDialogState._showNewCategoryDialog()` の `await addCategory()` 後に `if (!mounted) return;` が欠落していた。本レビューで発見し同セッション内で修正済み |
| リソースリーク | ✅ 問題なし | `_EditFavoriteDialogState.dispose()` で `_nameCtrl`・`_priceCtrl`・`_qtyCtrl` を破棄済み。今回の変更で新たな Controller / FocusNode の追加なし |

---

## 2. 許容したリスク（記録）

**商品名の長さ制限なし**：前回レビューと同じ判断。ローカル DB（SQLite TEXT 型）のみへの書き込みであり、他ユーザーへの影響や認証回避リスクはないため個人利用アプリとして許容範囲。

---

## 3. 結論

対象5観点すべてで問題は検出されなかった（マウントチェックは本レビューで発見・同セッション内で修正済み）。カテゴリ削除処理はトランザクション保護・パラメータバインディングにより安全。`restoreFavorite` のカテゴリID追加・`_EditFavoriteDialog` の新規カテゴリ追加はいずれも適切に実装されている。リリース可。
