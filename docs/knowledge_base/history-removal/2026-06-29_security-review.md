**カテゴリ**: history-removal　**元ファイル名**: security_review_2026-06-29-history-removal.md

---

# セキュリティレビュー：履歴機能削除

**実施日**: 2026-06-29
**対象ブランチ**: `main`
**レビュー範囲**: 未コミットの変更（履歴・オートコンプリート機能削除）。前回レビュー済みのカテゴリバグ修正（コミット `fcc4ea5` まで）は対象外。

---

## 1. チェック観点と結果

| 観点 | 結果 | 詳細 |
|------|------|------|
| SQLインジェクション | ✅ 問題なし | `item_history` テーブルの `upsertHistory` / `getHistoryNames` が削除されたことでリスク自体が除去された。残存するすべての DB 操作は `whereArgs` / Map 渡しのパラメータバインディングを使用 |
| リソースリーク | ✅ 問題なし | `item_name_field.dart` で `_internalFocusNode?.dispose()` が正しく実装されている（外部注入ノードは呼び出し側管理）。`favorites_dialog.dart` の `_loadCandidates` 削除後も `dispose()` で全コントローラー・`FocusNode` を破棄済み |
| マウントチェック | ✅ 修正済み | `add_item_dialog.dart` の `_showNewCategoryDialog()` で `addCategory()` 後の `if (!mounted) return;` が欠落。本レビューで発見し同セッション内で修正済み |
| 情報露出 | ✅ 問題なし | `history_select_dialog.dart` 削除により `getHistoryNames()` 経由で UI に履歴が露出する経路がなくなった |

---

## 2. 許容したリスク（記録）

なし

---

## 3. 結論

履歴機能削除の変更（8ファイル）について4観点をチェックした。マウントチェック漏れを1件発見し、同セッション内で修正済み。その他の観点は問題なし。リリース可。
