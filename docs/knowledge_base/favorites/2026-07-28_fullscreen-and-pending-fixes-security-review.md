**カテゴリ**: favorites　**元ファイル名**: security_review_2026-07-28-favorites-fullscreen-and-pending-fixes.md

---

# セキュリティレビュー：よく買うもの全画面化・カテゴリ別表示ほか積み残し修正

**実施日**: 2026-07-28
**対象ブランチ**: `main`
**レビュー範囲**: バックアップ読み込み関連修正・AdMob広告アカウント切り替え・商品名の入力候補表示機能の復元・Google Play Billing Library 8.0.0 対応・よく買うもの全画面化＆カテゴリ別表示（コミット `d9e408e` 〜 `b523788`）。前回レビュー済みの機能（履歴機能削除・カテゴリ機能・よく買うものダイアログの基本仕様等）は対象外。

---

## 1. チェック観点と結果

| 観点 | 結果 | 詳細 |
|------|------|------|
| SQLインジェクション | ✅ 問題なし | `database_helper.dart` の変更（`importData` の `createdAt` 採番・`firstNewListId` 追加）はすべて `whereArgs` / `db.insert` の Map 渡しのみで、文字列結合によるSQL構築は無し。新規追加の `rawQuery('SELECT MAX(createdAt) as maxAt FROM lists')` も引数を取らない固定文字列 |
| 入力バリデーション | ✅ 問題なし | `favorites_screen.dart` の `_AddFavoriteDialog`／`_EditFavoriteDialog` は `_formKey.validate()` 通過後のみ `int.parse()` を呼ぶ。商品名は空欄チェックあり、価格は `n < 0`、個数は `n < 1` のガードを維持（旧 `favorites_dialog.dart` から変更なし） |
| 業務ルール一貫性 | ✅ 問題なし | インポート経路（`importData`）はリスト数上限10件チェック（`list_limit_exceeded`）を維持したまま `createdAt` 採番ロジックのみ追加。UI側のバリデーションとインポート側の業務ルール（上限・名前重複解決）に齟齬なし |
| catch節情報露出 | ✅ 問題なし | `shopping_list_screen.dart` の `_importBackup` は `FormatException` を個別メッセージに変換し、汎用 `catch (_)` も固定文字列「読み込みに失敗しました」のみ。`e.toString()` の直接表示は無し。`favorites_screen.dart` の `_onReorderItem` の `catch (_)` も同様にメッセージ非表示で `_load()` にフォールバックするのみ |
| リソースリーク | ⚠️ 発見・修正済み | `favorites_screen.dart` の `_AddFavoriteDialogState`／`_FavoritesScreenState` とも `dispose()` で `TextEditingController`・`ScrollController`・`FocusNode`・`Timer` を正しく破棄。`item_name_field.dart` も `_focusNode.addListener` に対応する `removeListener` を `dispose()` に追加済みで漏れなし（本項目自体は問題なしだが、下記マウントチェックの修正と合わせて確認） |
| マウントチェック | ⚠️ 発見・修正済み | `favorites_screen.dart` の `_AddFavoriteDialogState._showNewCategoryDialog()` で `addCategory()`（非同期DB書き込み）後に `if (!mounted) return;` が欠落し、`setState` が無条件に呼ばれていた。同ファイル内の `_EditFavoriteDialogState._showNewCategoryDialog()` には同チェックがあり実装が非対称だった。旧 `favorites_dialog.dart`（`d9e408e` 時点）から存在していた既存バグで、全画面化に伴う移植時にも引き継がれ前回レビューでも見落とされていたため、本レビューで発見し同セッション内で修正済み（`lib/screens/favorites_screen.dart` 461〜463行目に `if (!mounted) return;` を追加） |
| 型キャスト安全性 | ✅ 問題なし | `favorites_section_helper.dart` の `buildFavoriteSections`／`resolveGlobalFavoriteIndex` はローカルDB（sqflite `favorites`／`categories` テーブル、INTEGER PRIMARY KEY）由来の `Map<String, dynamic>` のみを扱い、`as int`／`as int?` キャストの対象は外部JSONではない。`database_helper.dart` の `importData` は既存どおり `(item['categoryId'] as num).toInt()` 等 `num.toInt()` パターンを維持し、新規追加分（`createdAt` 採番・`firstNewListId`）にも外部JSON数値への直接 `as int` キャストは追加されていない |
| 情報露出 | ✅ 問題なし | `候補表示` 機能（`item_name_field.dart` の商品名サジェスト）は現在のリストの商品名（`itemAsync` のローカル状態）またはよく買うものの商品名（ローカルDB）のみを候補とし、外部通信・他リスト・他ユーザーのデータを含まない。`favorites_screen.dart` の検索・全画面表示もローカルDBの `favorites`／`categories` のみを表示し、共有・エクスポート経路には影響しない |

該当なしとして除外した観点：AdMob広告ID切り替え（`ad_banner.dart`／`AndroidManifest.xml`）は定数文字列の差し替えのみでSQLインジェクション・入力バリデーション等とは無関係。Google Play Billing Library 8.0.0 対応は `pubspec.yaml`／`pubspec.lock` のバージョン指定変更のみでアプリ内コードの変更が無いため、上記全観点で該当箇所なし。

---

## 2. 許容したリスク（記録）

**商品名の長さ制限なし**：`ItemNameField` の validator は空欄チェックのみで最大文字数の上限がない。ローカル DB（SQLite TEXT型）のみへの書き込みであり、他ユーザーへの影響や認証回避リスクはないため個人利用アプリとして許容範囲。前回（よく買うものダイアログレビュー）と同じ判断で変更なし。

**`restoreFavorite` の `categoryId` 欠落は無し（再確認）**：前回レビューで指摘した `restoreFavorite` の `categoryId` 欠落は、現在の `database_helper.dart`（484〜500行目）で既に `categoryId` パラメータが実装され、`favorites_screen.dart` の Undo 処理（309〜315行目）でも渡されていることを確認。解消済みのため今回は問題なし。

---

## 3. 結論

対象5トピック（バックアップ読み込み修正、AdMob広告アカウント切り替え、商品名の入力候補表示復元、Billing Library更新、よく買うもの全画面化・カテゴリ別表示）について7観点をチェックした。SQLインジェクション・入力バリデーション・業務ルール一貫性・catch節情報露出・型キャスト安全性・情報露出の6観点は問題なし。リソースリーク・マウントチェックの2観点について、`favorites_screen.dart` の `_AddFavoriteDialogState._showNewCategoryDialog()` に既存バグ（`addCategory()` 後のマウントチェック漏れ）を発見し、同セッション内で修正済み（`_EditFavoriteDialogState` と同じパターンに統一）。このバグは今回の変更範囲で新規に埋め込まれたものではなく、`d9e408e` 以前から存在し全画面化時に移植されたものだが、対象ファイルの現状確認により検出・是正した。他に許容外のリスクは検出されず、リリース可。
