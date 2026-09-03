**カテゴリ**: favorites　**元ファイル名**: security_review_2026-06-29-favorites-dialog.md

---

# セキュリティレビュー：よく買うものダイアログ変更

**実施日**: 2026-06-29  
**対象ブランチ**: `main`  
**レビュー範囲**: よく買うものダイアログ改善（コミット `d3d668e`）。前回レビュー済みのカテゴリ機能・リスト共有・バックアップは対象外。

---

## 1. チェック観点と結果

| 観点 | 結果 | 詳細 |
|------|------|------|
| SQLインジェクション | ✅ 問題なし | `getFavorites` は引数なしクエリ、`insertFavorite`・`updateFavorite`・`deleteFavorite`・`favoriteNameExists` はすべて `whereArgs` またはパラメータバインディングを使用。文字列結合なし |
| 入力バリデーション | ✅ 問題なし | `_AddFavoriteDialog` は `_formKey.validate()` 通過後のみ `int.parse()` を呼び出す。商品名は空欄チェックあり（`ItemNameField` の validator）、価格は `n < 0` ガード、個数は `n < 1` ガード |
| catch節情報露出 | ✅ 問題なし | `_AddFavoriteDialog`・`_EditFavoriteDialog` に catch 節なし。`reorderFavorites` の失敗は `_load()` 再ロードで対処し、エラーメッセージをユーザーに露出しない |
| リソースリーク | ✅ 問題なし | `_AddFavoriteDialogState.dispose()` で `_nameCtrl`・`_priceCtrl`・`_qtyCtrl`・`_scrollCtrl`・`_nameFocus` をすべて破棄済み |
| マウントチェック | ✅ 問題なし | `_loadCandidates()` の非同期処理後に `if (!mounted) return;` あり。登録ボタンの `onPressed` でも `if (!mounted) return;` を確認してから `Navigator.pop` を呼ぶ |
| 候補表示の安全性 | ✅ 問題なし | `_selectSuggestion` は `controller.text = suggestion` のテキスト置換のみ。候補は `getFavorites()` ローカルDB由来で外部入力を含まない。候補の評価・実行は行わない |

---

## 2. 許容したリスク（記録）

**商品名の長さ制限なし**：`ItemNameField` の validator は空欄チェックのみで最大文字数の上限がない。ローカル DB（SQLite TEXT 型）のみへの書き込みであり、他ユーザーへの影響や認証回避リスクはないため個人利用アプリとして許容範囲。前回（カテゴリ機能レビュー）と同じ判断。

**`restoreFavorite` の `categoryId` 欠落**：スワイプ削除 Undo 時、`restoreFavorite()` がカテゴリIDを引数に取らないため、カテゴリ付きお気に入りを削除→Undoするとカテゴリ情報が失われる。今回の変更で新たに導入したバグではなく、データ消失は個人DB内のみ。セキュリティリスクには該当しないが、別Issueとして積み残し。

---

## 3. 結論

対象6観点すべてで問題は検出されなかった。SQLインジェクション対策・入力バリデーション・リソース破棄・マウントチェックのいずれも適切に実装されている。新規追加の候補表示（`_loadCandidates`・`ItemNameField`）もローカルDBデータのみを参照し、外部通信や評価実行は行わない。「商品名の長さ上限なし」は前回レビューと同じ許容判断。`restoreFavorite` のカテゴリ欠落は別Issue扱い。よく買うものダイアログ変更はセキュリティ上の問題なし。リリース可。
