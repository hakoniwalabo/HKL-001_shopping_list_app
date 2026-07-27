# よく買うもの 全画面化・カテゴリ別表示 設計書

## 背景

テスターフィードバック「よく買うものリストを全画面にして、カテゴリ別表示を有効にする」への対応。

現状、「よく買うもの」は `FavoritesDialog`（`lib/widgets/favorites_dialog.dart`）として実装されており、`AlertDialog` 内に `ConstrainedBox(maxHeight: 320)` で高さ制限されたリストを表示している。検索・全選択・ドラッグ並べ替え・スワイプ削除＋Undo・タップでの編集ダイアログ表示機能を持つ。各favoriteは `categoryId` を保持しているが、一覧表示はカテゴリ別にグルーピングされておらずフラット表示になっている。

メイン画面（`lib/screens/shopping_list_screen.dart`）は既にカテゴリごとのセクション表示（`_buildCategorySections` メソッド、`ListSection` ウィジェット）を実装済みだが、`ListSection`/`ItemTile` は `Item` モデル専用であり、favorites（`Map<String, dynamic>` ベース）とはデータモデルが異なるため、そのままの再利用はできない。

## 決定事項（ユーザー確認済み）

- 全画面化の方式：独立した画面への変更（`Navigator.push`）。フルスクリーンダイアログ形式ではない
- カテゴリ別表示：メイン画面と同じ方式（カテゴリごとにセクション分け、カテゴリなし/存在しないカテゴリは最後にまとめて表示）
- ドラッグ並べ替え：カテゴリ内だけ並べ替え可能（カテゴリをまたぐ並べ替えは不可）
- 実装アプローチ：独立した `FavoritesScreen` を新規作成する方式（既存の `ListSection`/`ItemTile` の汎用化・共通化は行わない。変更範囲を favorites 関連ファイルに限定し、安定しているメイン画面側の共有コンポーネントには手を入れない）

## 画面構成・遷移

- `lib/screens/favorites_screen.dart` を新規作成。`Scaffold` + `AppBar`（タイトル「よく買うもの」、戻る矢印で閉じる）
- `_AddFavoriteDialog` / `_EditFavoriteDialog` は既存の `favorites_dialog.dart` から新ファイルへ移動する（ダイアログとしての実装・見た目はそのまま維持し、置き場所のみ変更）
- 呼び出し元 `shopping_list_screen.dart`（`showDialog<int>(... FavoritesDialog ...)` としている箇所、778行目付近）を `Navigator.push<int>(... FavoritesScreen ...)` に変更する。戻り値（追加件数）の受け渡し方式（`Navigator.pop(context, ids.length)` → 呼び出し元でSnackBar表示）は現行を維持する

## カテゴリ別セクション表示

- `categoryProvider` からカテゴリ一覧を取得し、メイン画面の `_buildCategorySections` と同じ方針でセクション化する：カテゴリごとに該当する favorites を抽出し、見出し（カテゴリ名）+ 一覧を表示する
- `categoryId` が null、または存在しないカテゴリIDを指している favorites は「カテゴリなし」セクションとして最後に表示する
- カテゴリが1件も登録されていない場合は、現行どおりフラット表示（セクション分けなし）とする
- 検索中（`_searchText` が空でない）は、カテゴリ分けせず現行どおりフラットな絞り込みリストのみを表示する（検索結果でセクションが乱立するのを避けるため）

## 並べ替え（ドラッグ）仕様

- 各カテゴリセクション内は `ReorderableListView` により個別に並べ替え可能。カテゴリをまたぐ移動は不可とする
- 並べ替え時は、セクション内の `oldIndex`/`newIndex` から「sortOrder順の全favoritesリスト」上でのグローバル位置を算出し、既存の `DatabaseHelper.reorderFavorites(orderedIds)`（渡された順序で全件のsortOrderを振り直す仕様）へ渡す。これはメイン画面の `ItemNotifier.reorderUncheckedItems`（`lib/providers/item_provider.dart`）が採用している「セクション内indexをグローバルリストの位置に変換してから永続化する」考え方と同じである
- 「カテゴリなし」セクションも同様に、セクション内のみ並べ替え可能とする

## 既存機能の引き継ぎ

以下は画面形式の変更であり機能追加・削除ではないため、`FavoritesDialog` の挙動をそのまま `FavoritesScreen` に移植する：

- 検索窓によるフィルタリング
- 全選択／全解除ボタン
- スワイプ削除＋Undo（5秒のインラインバナー表示、`Timer` ベース）
- 商品タップでの編集ダイアログ表示
- チェックボックスでの選択→「リストに追加」ボタンでの一括追加

`ConstrainedBox(maxHeight: 320)` による高さ制限は撤廃し、画面いっぱいに `Expanded` + カテゴリセクションの縦積み表示に変更する。

## データ層の変更点

- `DatabaseHelper.getFavorites()`：変更不要（`categoryId` は既に取得済み）
- `DatabaseHelper.reorderFavorites(List<int> orderedIds)`：変更不要（呼び出し側でグローバル順序を計算してから渡す）
- 新規のDBスキーマ変更・マイグレーションは無し

## ドキュメント更新

- `lib/widgets/help_dialog.dart` の「よく買うものから追加」の説明文を、画面形式変更（全画面）とカテゴリ別表示に合わせて更新する（プロジェクトルール「機能を追加・変更・削除したときは必ず help_dialog.dart を同時に更新する」に従う）

## テスト方針

- カテゴリ別グルーピング・グローバル並べ替えindex算出のロジックのうち、純粋関数として切り出せる部分があれば単体テストを追加する
- `flutter analyze` ・全体 `flutter test` の通過を確認する
- エミュレーターでの実機目視確認は行わず、マスターに依頼する（Global.md方針）

## 影響ファイル一覧

- 新規：`lib/screens/favorites_screen.dart`
- 変更：`lib/screens/shopping_list_screen.dart`（呼び出し元）、`lib/widgets/help_dialog.dart`
- 削除：`lib/widgets/favorites_dialog.dart`（内容を新画面へ移行後に削除）
