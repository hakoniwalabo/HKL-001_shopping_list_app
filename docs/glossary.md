# HKL-001 買い物リスト 用語の定義一覧表

作成日：2026-11-04
対象バージョン：1.4.0+14（`pubspec.yaml` の `version`）

## 凡例・出典の略記

- UI文言は正本（`lib/widgets/help_dialog.dart`、`docs/release_notes_v*.md`、設計書、実装コードの表示文字列）の表記をそのまま記載する。
- 実装名（クラス名・ウィジェット名・テーブル名）とUI表示名は区別して記載する。
- 正本で確認できなかった項目は定義欄に「要確認」と記載する。
- 出典の略記は次のとおり。
  - 設計書：`docs/spec_HKL-001_shopping_list_app_rev9.1.md`
  - ヘルプ：`lib/widgets/help_dialog.dart`
  - Rules.md：`C:\Users\gothf\.claude\00_AI-OS\Projects\HKL-001_shopping_list_app\Rules.md`
  - memory/：`C:\Users\gothf\.claude\projects\C--Users-gothf-develop-HKL-001-shopping-list-app\memory\`
- memory/ のファイルは記録時点のスナップショットであり、現状と異なる可能性がある。

---

## 1. アプリ内UI用語（ユーザーに表示される用語）

| 用語 | 読み/別表記 | 定義 | 出典 |
|---|---|---|---|
| 買い物リスト | アプリ名、AppBarタイトル | AppBarのタイトルに固定表示される文言。リスト名の既定値としても使われる。 | `lib/screens/shopping_list_screen.dart`、設計書 |
| リスト | 旧UI表記「タブ」。release_notes_v1.3.0 では「タブ（リスト）」 | 商品をまとめる単位。最大10件まで作成でき、画面上部のタブで切り替える。Rev 8.13 でUI表記を「タブ」から「リスト」に統一した。実装名は `ShoppingList`（モデル）、`TabBar`・`ListTabBar`（タブ表示）。 | `lib/widgets/help_dialog.dart`、`docs/release_notes_v1.3.0_13.md`、設計書 |
| リスト名 | リスト名変更 | 各リストの名前。リスト名（タブ）の長押しで変更する。ダイアログのタイトルは「リスト名変更」。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| リストを追加 | 「＋」ボタン、新規リスト | AppBar右上の「＋」ボタンで新しいリストを作成する。上限は10件で、超過時は「リストは最大10件まで作成できます」と表示する。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| リストを複製 | 複製ボタン | 全商品をコピーした新しいリストを作成する。チェックはリセットされる。新リスト名は「{元の名前}のコピー」で、同名があれば連番が付く。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| リストの並び替え | 並び替えモード、「並び替えを終了」（ツールチップ） | AppBar右上の並び替えボタン（≡アイコン）で並び替えモードに入り、表示されたハンドルをドラッグして順番を変更する。再度ボタンを押すと通常表示に戻る。実装名は `ListReorderBar`、保存先は `lists.sortOrder`。 | `lib/widgets/help_dialog.dart`、`lib/widgets/list_management_buttons.dart`、設計書 |
| リストを削除 | リスト削除 | AppBar右上の「⋮」→「リストを削除」。最後のリストは削除できない。削除すると商品もすべて削除される。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 商品 | アイテム | リストに登録する買い物の1件。実装名は `Item`（`items` テーブル）。 | `lib/widgets/help_dialog.dart`、`lib/models/item.dart` |
| 追加（ボタン） | FAB（画面右下） | 商品追加ダイアログを開くボタン。実装名は `FloatingActionButton.extended`。追加ダイアログ内の「追加」で続けて入力でき、終わったら「閉じる」を押す。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 商品追加／商品編集 | 追加ダイアログ、編集ダイアログ | 同一のダイアログ部品で、新規時のタイトルは「商品追加」、編集時は「商品編集」。ボタンは新規時が「閉じる」「追加」、編集時が「キャンセル」「保存」。実装名は `_AddItemDialogContent`（`showAddItemDialog`）。 | `lib/widgets/add_item_dialog.dart` |
| 商品名 | — | 商品の名前。入力欄のラベルは「商品名」。入力中は候補が表示される。 | `lib/widgets/fields/item_name_field.dart` |
| 個数 | 旧ラベル「数量」 | 商品の個数。1以上の整数。Rev 8.10 でラベルを「数量」から「個数」に統一した。 | `lib/widgets/fields/quantity_field.dart`、設計書 |
| 税込価格 | 単価 | 商品1個あたりの税込価格。0以上の整数で、0円のときはリスト表示が「-」になる。内部では税込単価として保存する（`price`）。 | `lib/widgets/fields/price_field.dart`、設計書 |
| 単価／税込合計（商品行の表示） | — | 商品行のサブタイトルに「個数: ○ / 単価: ○ / 税込合計: ○」の形式で表示される。単価が0円のときは「-」。 | `lib/widgets/item_tile.dart` |
| メモ | — | 商品に付ける補足。編集ダイアログでのみ表示・入力できる。 | `lib/widgets/fields/memo_field.dart`、設計書 |
| 未チェック | 旧UI表記「未購入」 | チェックされていない商品のセクション見出し、および合計表示の「未チェック ¥○」。Rev 8.14 で「未購入」から統一した。 | `lib/widgets/total_summary.dart`、`lib/screens/shopping_list_screen.dart`、設計書 |
| チェック済 | 旧UI表記「購入済」 | チェック済み商品のセクション見出し、および合計表示の「チェック済 ¥○」。表記は「チェック済」で、「チェック済み」ではない。Rev 8.14 で「購入済」から統一した。広告なし購入（IAP）を指す「購入済み」表記は統一の対象外。 | `lib/widgets/total_summary.dart`、`lib/screens/shopping_list_screen.dart`、設計書 |
| チェック済み関連の操作文言 | — | 表示面によって表記が異なる。ヘルプの見出しは「チェック済みにする」「チェック済みを一括削除」、一括削除ボタンは「チェック済み削除」、確認ダイアログのタイトルは「チェック済みを削除」。いずれも各面の正本の文字列に従う。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 商品を削除 | スワイプ削除 | 商品を左にスワイプして削除する。 | `lib/widgets/help_dialog.dart`、`lib/widgets/item_tile.dart` |
| 元に戻す | Undo | 削除直後のSnackBarに表示されるボタン。5秒以内に削除した商品を復元できる。一括削除にも使える。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 並び替え（商品） | ドラッグハンドル | 未チェック商品の右端のハンドルをドラッグして順番を変更する。チェック済の商品は並び替えできない。 | `lib/widgets/help_dialog.dart`、設計書 |
| 別のリストに移動 | ヘルプの見出しは「別リストへ移動」 | 商品を長押しして表示されるメニュー項目。移動先リストの選択ダイアログのタイトルは「移動先のリスト」。 | `lib/widgets/item_tile.dart`、`lib/screens/shopping_list_screen.dart`、`lib/widgets/help_dialog.dart` |
| よく買うもの | 定番商品、お気に入り（設計書・内部名は favorites） | よく買う商品を登録しておき、現在のリストへ一括追加できる機能、またはその登録商品。全リスト共通で、リストごとには持たない。 | `lib/widgets/help_dialog.dart`、設計書 |
| よく買うものに登録 | — | 商品追加ダイアログのチェック、および商品を長押ししたメニューの項目。登録済みの名前を追加するときは「既に登録されています」の確認が出る。 | `lib/widgets/add_item_dialog.dart`、`lib/widgets/item_tile.dart`、`lib/screens/shopping_list_screen.dart` |
| よく買うものから追加 | ハートボタン | AppBar右上のハートボタン（ツールチップは「よく買うものから追加」）。よく買うもの画面（`FavoritesScreen`）を開く。チェックして「リストに追加」で一括追加する。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| よく買うもの画面の操作 | 直接登録、リストに追加、全選択、全解除 | 画面下部に「直接登録」「リストに追加」ボタンがある。「全選択」ボタンは選択状況に応じて「全解除」に切り替わる。検索窓のヒントは「検索」、0件時は「まだ登録されていません」と表示する。 | `lib/screens/favorites_screen.dart` |
| 商品名の候補表示 | 候補、サジェスト、星マークの候補 | 商品名入力中に、現在のリスト内の商品名とよく買うものを候補として最大8件表示する。星マークの候補はよく買うもので、選ぶと名前・個数・価格・カテゴリが入力される。星なしの候補は名前のみ入力される。編集時はよく買うものは表示されない。 | `lib/widgets/help_dialog.dart`、設計書 |
| カテゴリ | — | 商品をまとめる分類。設定するとリストがカテゴリ別に整理される。入力欄のラベルは「カテゴリ（任意）」、新規作成ボタンのツールチップは「新規カテゴリ」。実装名は `Category`（`categories` テーブル）。 | `lib/widgets/help_dialog.dart`、`lib/widgets/add_item_dialog.dart` |
| カテゴリを管理 | — | AppBar右上の「⋮」→「カテゴリを管理」。カテゴリを作成・削除できる。 | `lib/widgets/help_dialog.dart`、`lib/widgets/category_management_dialog.dart` |
| カテゴリなし | — | カテゴリが未設定、または存在しないカテゴリを指す商品をまとめるセクション見出し。 | `lib/screens/shopping_list_screen.dart`、`lib/utils/favorites_section_helper.dart` |
| 予算 | 「予算 -」（未設定表示） | リストごとに設定する金額の目安。0円は未設定として「予算 -」と表示し、設定済みは「予算 ¥○」と表示する。表示専用で、超過警告や残額計算は行わない。実装名は `BudgetSummary`（表示）、`ShoppingList.budget`（保持）。 | `lib/widgets/budget_summary.dart`、設計書 |
| 予算を設定 | 予算入力 | 予算表示をタップすると開く入力ダイアログのタイトル。空欄のまま保存すると未設定（-表示）に戻る。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 合計表示 | 合計 | 「未チェック」と「チェック済」の税込合計を並べて表示する領域。各合計が0円のときは「-」を表示する。実装名は `TotalSummary`。 | `lib/widgets/total_summary.dart`、設計書 |
| テキストで共有 | — | AppBar右上の「⋮」→「テキストで共有」。リストの内容をテキストとして他のアプリに送る。取り込みはできない。 | `lib/widgets/help_dialog.dart`、設計書 |
| リストを共有（読み込み用） | 共有リスト | AppBar右上の「⋮」→「リストを共有（読み込み用）」。未チェック商品をJSONファイルとして送信し、受け取った側は「読み込む」から取り込む。 | `lib/widgets/help_dialog.dart`、設計書 |
| バックアップ | 「共有」「端末に保存」 | AppBar右上の「⋮」→「バックアップ」。データをJSONファイルとして書き出す。保存先を「共有」（メール・クラウドなど）か「端末に保存」から選ぶ。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 読み込む（バックアップ／共有リスト） | 読み込み、インポート | AppBar右上の「⋮」→「読み込む（バックアップ／共有リスト）」。バックアップや共有されたリストのファイルを選び、既存データに追加読み込みする。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 広告を削除 | 「広告を非表示にする」（ヘルプ見出し）、「広告なしプラン」（ダイアログタイトル） | AppBar右上の「⋮」のメニュー項目。買い切り購入で広告が非表示になる。購入済みの場合、メニュー項目は表示されない。 | `lib/widgets/help_dialog.dart`、`lib/widgets/upgrade_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| 購入を復元 | 購入の復元 | 広告なしプランのダイアログのボタン。端末を変えても購入を再適用できる。実行後に「購入の照合が完了しました」と表示する。 | `lib/widgets/upgrade_dialog.dart` |
| 使い方 | ヘルプ | AppBar右上の「⋮」にあるメニュー項目で、使い方を説明するダイアログを開く。ダイアログのタイトルも「使い方」。実装名は `HelpDialog`。 | `lib/widgets/help_dialog.dart`、`lib/screens/shopping_list_screen.dart` |
| オプション | 「⋮」メニュー | AppBar右上の「⋮」ボタンのツールチップ。リスト削除・共有・バックアップ・カテゴリ管理・広告削除・使い方を収める。 | `lib/screens/shopping_list_screen.dart` |
| 利用規約への同意 | 同意ダイアログ、「同意する」「同意しない」 | 初回起動時（利用規約の改定時を含む）に、利用規約とプライバシーポリシーへの同意確認として表示される。「同意しない」を選ぶとアプリは終了する。 | `lib/widgets/help_dialog.dart`、`lib/widgets/terms_consent_gate.dart`、`docs/release_notes_v1.4.0_14.md` |
| 空状態の案内 | — | 商品が0件のときに「＋ボタンから追加してください」と表示される。実装名は `EmptyStateView`。 | `lib/widgets/empty_state_view.dart` |

---

## 2. データ・実装用語（DB・モデル・Provider等）

DBはSQLite（sqflite）で、ファイル名は `shopping.db`、スキーマバージョンは9（出典：`lib/database/database_helper.dart`）。

| 用語 | 読み/別表記 | 定義 | 出典 |
|---|---|---|---|
| Item／items | UI表示名「商品」 | 商品のモデルとテーブル。項目は name、price（税込単価）、isChecked、createdAt、sortOrder、quantity（個数）、memo、listId、categoryId。 | `lib/models/item.dart`、設計書 6.1・9.1 |
| ShoppingList／lists | UI表示名「リスト」 | リストのモデルとテーブル。項目は id、name、createdAt、budget（予算）、sortOrder（表示順）。 | `lib/models/shopping_list.dart`、設計書 6.2 |
| favorites | UI表示名「よく買うもの」 | よく買うものを保存するテーブル。項目は name、price、quantity、sortOrder、createdAt、categoryId。対応するモデルクラスは存在せず、`Map<String, dynamic>` で扱われる。 | 設計書 6.3、`lib/utils/favorites_section_helper.dart` |
| Category／categories | UI表示名「カテゴリ」 | カテゴリのモデルとテーブル。項目は id、name（UNIQUE）、sortOrder、createdAt。DB v7 で追加。 | `lib/models/category.dart`、設計書 6.4 |
| FavoriteSuggestion | UI表示名は星マークの候補 | 商品名の候補表示で使う、よく買うもの由来の候補データ。name、price、quantity、categoryId、categoryName を持つ。subtitle は「×個数　¥価格　カテゴリ名」の形式。 | `lib/models/favorite_suggestion.dart` |
| NameSuggestion／buildNameSuggestions() | UI表示名「商品名の候補表示」 | NameSuggestion は候補1件を表す型で、よく買うもの由来の場合に FavoriteSuggestion を保持する。buildNameSuggestions() はよく買うもの（最大5件）を先に、残り枠に履歴を並べて合計最大8件を返す。 | `lib/widgets/fields/item_name_field.dart` |
| candidateNames | 履歴候補 | 現在表示中のリスト内の商品名一覧。商品名の候補表示の履歴側の元データで、DBには保存しない。 | 設計書 8.9 |
| item_history | 旧・履歴DB方式 | 旧方式の履歴テーブル。2026-06-29 に関連コードを削除済みで、既存インストールにテーブルが残っていてもアプリは参照しない。 | 設計書 6章の注記・10章 |
| price | UI表示名「税込価格」「単価」 | 税込単価を整数で保持する項目。合計は price × quantity。 | `lib/models/item.dart`、設計書 8.8 |
| quantity | UI表示名「個数」 | 個数。1以上の整数で、インポート時は不正値を1へ補正する。 | 設計書 8.1・8.12 |
| isChecked | UI表示名「チェック済」「未チェック」 | チェック済みかを表す項目。DBでは 0/1、モデルでは bool。 | `lib/models/item.dart` |
| sortOrder | UI表示名なし（並び順） | 並び順を保持する項目。items・favorites・categories は並び順、lists は表示順（小さいほど左）。新規追加時は MAX+1、並び替え時は再採番する。 | 設計書 6章・11章 |
| listId | — | 商品が所属するリストの ID（`items.listId`、外部キー）。 | `lib/models/item.dart`、設計書 6.1 |
| categoryId | — | 商品・よく買うものが所属するカテゴリの ID。NULL 可。カテゴリ削除時は NULL に更新される。 | `lib/models/item.dart`、設計書 6.1・8.11 |
| budget | UI表示名「予算」 | リストごとの予算額。0は未設定として扱い、null は使わない。DB v8 で追加。 | `lib/models/shopping_list.dart`、設計書 8.13 |
| DatabaseHelper | — | SQLite 操作を担うシングルトン（`DatabaseHelper.instance`）。CRUD、マイグレーション、お気に入り・カテゴリ管理、`importData()` などを持つ。 | `lib/database/database_helper.dart`、設計書 9.3 |
| DBバージョン | スキーマバージョン | 現在は 9。v6 で favorites、v7 で categories と categoryId、v8 で budget、v9 で lists.sortOrder を追加した。 | `lib/database/database_helper.dart`、設計書 10章 |
| ItemNotifier／itemProvider | UI対応は商品一覧 | 商品一覧・リスト切替・並び替え・Undo・DB同期を管理する Riverpod の AsyncNotifier。状態は `AsyncValue<List<Item>>`。 | `lib/providers/item_provider.dart`、設計書 7.1 |
| CategoryNotifier／categoryProvider | UI対応はカテゴリ | カテゴリ一覧の取得・追加・削除を管理する AsyncNotifier。 | `lib/providers/category_provider.dart`、設計書 7.3 |
| PurchaseNotifier／purchaseProvider | UI対応は広告の表示・非表示 | 広告なしフラグ（`AsyncValue<bool>`）を管理する AsyncNotifier。キャッシュの読み書き、購入ストリームの購読、起動時の購入状態照会、`purchase()`・`restore()` を担う。 | `lib/providers/purchase_provider.dart`、設計書 7.2 |
| kRemoveAdsProductId | 商品ID `remove_ads` | 広告なし買い切り商品のプロダクトID。Play Console に登録する ID と一致させる。 | `lib/providers/purchase_provider.dart`、設計書 14.3 |
| is_ad_free | 広告なしフラグ | 広告なし状態のキャッシュを保存する SharedPreferences のキー。 | `lib/providers/purchase_provider.dart`、設計書 14.3 |
| isAdFree | — | 画面側で「広告なし」かを判定する変数。true のとき広告と「広告を削除」メニューを非表示にする。`--dart-define=HIDE_ADS` でも true になる。 | `lib/screens/shopping_list_screen.dart` |
| AdFreeResolution／resolveAdFreeState() | 広告なし判定 | Play Store の照会結果とキャッシュから、採用する広告なし状態と永続化要否を決める純粋関数とその結果型。通信エラー時はキャッシュを維持し永続化しない。 | `lib/utils/purchase_resolution.dart` |
| AdBannerWidget | バナー広告 | アダプティブバナーを読み込み・表示・破棄するウィジェット。`Scaffold.bottomNavigationBar` に `SafeArea` でラップして置く。読み込み前・失敗時は何も表示しない。 | `lib/widgets/ad_banner.dart`、設計書 5.2 |
| ShoppingListScreen | メイン画面 | メイン画面。AppBar、タブ、予算表示、合計表示、商品リスト、FAB、広告を組み立てる。 | `lib/screens/shopping_list_screen.dart` |
| FavoritesScreen | よく買うもの画面 | よく買うものを管理する全画面。`Navigator.push` で遷移し、追加件数を `pop` の結果で返す。旧 `FavoritesDialog` を Rev 8.8 で統合した。 | `lib/screens/favorites_screen.dart`、設計書 8.11 |
| _AddFavoriteDialog／_EditFavoriteDialog | 「よく買うものに登録」「よく買うものを編集」 | よく買うもの画面内の直接登録ダイアログと編集ダイアログ。商品追加ダイアログと同じ項目が別々に実装されている。 | `lib/screens/favorites_screen.dart`、Rules.md |
| FavoriteSection／buildFavoriteSections() | カテゴリ別セクション | よく買うものをカテゴリ別セクションに分割するヘルパー。カテゴリが1件もないときは null を返す。 | `lib/utils/favorites_section_helper.dart` |
| ListSection／ItemTile | リストの見出しと商品行 | ListSection はセクション見出し付きの商品一覧、ItemTile は Dismissible と ListTile による商品1行。 | `lib/widgets/list_section.dart`、`lib/widgets/item_tile.dart` |
| ListTabBar／ListReorderBar／ListManagementButtons | タブ、並び替えバー、AppBar のリスト操作ボタン | ListTabBar はリストのタブ（長押しで名前変更）。ListReorderBar は並び替えモード中に AppBar.bottom と差し替わる水平バー。ListManagementButtons は追加・複製・並び替えの3ボタン。 | `lib/widgets/list_tab_bar.dart`、`lib/widgets/list_reorder_bar.dart`、`lib/widgets/list_management_buttons.dart` |
| BackupService | — | バックアップ・リスト共有・読み込みを担うサービス。`export()`、`saveToDevice()`、`shareList()`、`import()`、`parseAndValidate()` を持つ。 | `lib/services/backup_service.dart`、設計書 9.6 |
| ImportResult／firstNewListId | — | インポート結果（listCount、itemCount、favoriteCount、firstNewListId）。firstNewListId は新規作成された先頭リストの ID で、読み込み後の自動切り替えに使う。 | `lib/database/database_helper.dart`、設計書 9.7 |
| バックアップファイル形式（version:2） | JSON、`shopping_backup_YYYYMMDD_HHmmss.json` | lists・items・favorites・categories を含む JSON 形式。version:1 は categories を空として読み込める。 | 設計書 8.12 |
| マージ方式 | — | インポート時に既存データを残して追加する方式。同名リストは連番を付け、createdAt と sortOrder は現在の DB 最大値＋連番で再採番する。 | 設計書 8.12、Rules.md |
| kTermsVersion | 利用規約バージョン | 現在の利用規約バージョンを表す定数（現在は 1）。規約を改定して再同意が必要なときに値を上げる。 | `lib/utils/legal_urls.dart`、Rules.md |
| kAcceptedTermsVersionKey | `accepted_terms_version` | 同意済みバージョンを保存する SharedPreferences のキー。 | `lib/utils/legal_urls.dart` |
| kTermsOfServiceUrl／kPrivacyPolicyUrl | — | 利用規約とプライバシーポリシーの公開ページ URL の定数。 | `lib/utils/legal_urls.dart` |
| needsTermsConsent() | — | 同意が必要かを判定する純粋関数。未保存、または保存済みバージョンが現在より古いとき true。 | `lib/utils/terms_consent.dart` |
| TermsConsentGate／利用規約同意ゲート | 同意ゲート | 初回描画後に同意状況を確認し、未同意なら同意ダイアログを表示するラッパー。`main.dart` でメイン画面を包む。ダイアログ内部の実装名は `_TermsConsentDialog`。 | `lib/widgets/terms_consent_gate.dart`、`lib/main.dart` |
| HelpDialog | UI表示名「使い方」 | ヘルプ画面のウィジェット。機能の追加・変更・削除時は同時に更新するルール。 | `lib/widgets/help_dialog.dart`、Rules.md |
| UpgradeDialog | UI表示名「広告なしプラン」 | 広告なしの購入・復元を行うダイアログ。 | `lib/widgets/upgrade_dialog.dart` |
| BudgetSummary／_BudgetInputDialog | UI表示名「予算」「予算を設定」 | 予算表示ウィジェットと予算入力ダイアログ。 | `lib/widgets/budget_summary.dart`、`lib/screens/shopping_list_screen.dart` |
| TotalSummary | UI表示名「合計表示」 | 未チェック合計とチェック済合計を表示するウィジェット。 | `lib/widgets/total_summary.dart` |
| SAF | 端末に保存の保存先選択 | 設計書は、端末保存（file_picker の saveFile）が Android の SAF 経由で、追加権限が不要であると記載している。SAF の正式名称・仕様は要確認。 | 設計書 8.12、`docs/knowledge_base/backup/2026-07-29_navigation-back-button.md` |

---

## 3. 開発・運用用語（リリース、Play Console、課金、審査まわり）

| 用語 | 読み/別表記 | 定義 | 出典 |
|---|---|---|---|
| versionName／versionCode | `pubspec.yaml` の `version: 1.4.0+14` | `+` の前が versionName、後ろが versionCode。現在は 1.4.0 と 14。versionCode は Play Store 提出・機能リリースのタイミングまで更新しない。提出時は pubspec.yaml と Rules.md の両方を更新する。 | `pubspec.yaml`、Rules.md、memory/feedback_version_management.md |
| AAB | App Bundle、`flutter build appbundle --release` | Play Store 用のリリースビルド成果物。ビルド前に現在の versionCode が Play Console にアップ済みかを確認する。 | 設計書 13章 Phase 4、Rules.md |
| リリースノート | — | `docs/release_notes_v{バージョン}_{versionCode}.md` に日本語（ja-JP）と英語（en-US）で記載する。見た目に変化のない内部変更を含めるかは確認し、原則除外する。 | `docs/release_notes_v1.4.0_14.md`、Rules.md |
| 設計書（rev） | 仕様書、Rev | `docs/spec_HKL-001_shopping_list_app_rev{番号}.md`。最新は rev9.1。リビジョン更新時は本文のRev表記とファイル名のリネームを同一コミットで行う。旧版は `docs/_old/` に置く。 | 設計書、Rules.md |
| セキュリティレビュー | — | リリース前に実施する差分レビュー。結果を `docs/knowledge_base/general/YYYY-MM-DD_*.md` に保存し、README の索引表へ1行追加する。 | Rules.md、`docs/knowledge_base/README.md` |
| ナレッジベース | knowledge_base | 調査レポート・セキュリティレビュー・手動チェック記録を機能・画面単位で整理した `docs/knowledge_base/`。索引は日付降順。 | `docs/knowledge_base/README.md` |
| テスターフィードバック | Feedback.md | テスターからの指摘を記録するログ。審査提出文書に「対応実績」を書くときは、Feedback.md と git log で裏付けが取れる事実のみを使う。 | Rules.md、memory/feedback_treat_requests_as_tester_feedback.md |
| Google Play Console | Play Console | アプリの公開・テスト・課金商品・審査を管理する Google の管理画面。本プロジェクトでは IAP 商品登録、テストトラック、Production Access 申請に使う。 | 設計書 13章、Rules.md |
| 内部テストトラック | — | Play Console のテストトラックの一つ。トラックごとに最新リリースが独立しているため、製品版・クローズドテストと別に更新が必要。 | memory/project_hkl001_billing_library_production_access_schedule.md |
| クローズドテスト | クローズドテストトラック | Play Console のテストトラックの一つ。本プロジェクトでは、テスター登録用のGoogleグループ経由でopt-inしたテスターに配布する。正式な定義は要確認。 | 設計書 13章 Phase 4、memory/project_hkl001_production_access_optin_tracking.md |
| Production Access | 製品版へのアクセス申請 | 製品版の公開前に必要な審査。テスターのエンゲージメント要件を含む。同一文言のリジェクトが続く場合は、公式の一次情報で要件の詳細を裏取りする。審査の経過は memory/ に記録がある。 | Rules.md、memory/project_hkl001_billing_library_production_access_schedule.md |
| opt-in | opt-in人数 | クローズドテストにテスターが参加登録すること。Play Console の人数表示は12人が上限のため、実人数はテスター用Googleグループのメンバー数で把握する。 | memory/project_hkl001_production_access_optin_tracking.md |
| 製品版 | 本番公開 | Play Store で一般に公開されるリリース。公開対象国は日本のみ。versionCode 14（1.4.0+14）は2026-10-29に公開済み。 | memory/project_hkl001_versioncode_status.md、memory/project_hkl001_billing_library_production_access_schedule.md |
| Billing Library | Google Play Billing Library | Google Play の課金ライブラリ。8.0.0以降への対応期限は2026-08-31で、`in_app_purchase_android 0.5.2` が8.0.0相当として対応済みと記録されている。ポリシーステータスの警告は内部テストトラックの古いバージョンが原因だった。 | memory/project_hkl001_billing_library_production_access_schedule.md |
| IAP | アプリ内課金、in_app_purchase | 本アプリでは `in_app_purchase` パッケージによる広告なしの買い切り購入。商品IDは `remove_ads`。 | 設計書 14.3 |
| 買い切り | non-consumable、管理対象商品 | 一度購入すると広告が非表示になる商品の種別。`remove_ads` は管理対象商品（non-consumable）として登録する。 | 設計書 13章 Phase 3・14.3 |
| 返金・取り消し検知 | purchase-revocation-detection | 起動時に毎回 `queryPastPurchases()` で購入状態を照会し、返金・取り消しがあれば広告表示を復活させる仕組み。広告を「消す」方向の遅延は不可、「復活させる」方向の遅延は許容する。 | 設計書 7.2、`lib/providers/purchase_provider.dart`、Rules.md |
| 未確定購入の自動返金 | unacknowledged、`completePurchase()` | 未確定（unacknowledged）の購入を3日以上放置すると Google Play が自動返金する仕様。アプリは `pendingCompletePurchase` が true の購入を `completePurchase()` で確定させる。 | `docs/knowledge_base/purchase/2026-07-28_remaining-tasks-revocation.md`、`lib/providers/purchase_provider.dart` |
| 権利を削除 | Remove entitlement | Play Console の「注文の管理」で買い切り商品を返金する際のチェックボックス。付けないと購入が「所有済み」のまま残り、広告なし状態が解除されない。後から権利だけを取り消す公式手段は用意されていない（2026-08時点の記録）。IAPのテスト返金では事前に案内する。 | Rules.md、memory/project_hkl001_playconsole_refund_entitlement.md |
| AdMob | — | Google の広告サービス。バナー広告を `google_mobile_ads` で表示する。本番リリース前に `AndroidManifest.xml` と `ad_banner.dart` の両方をテストIDから本番IDに差し替える。 | 設計書 14.2 |
| アダプティブバナー | アンカー付きアダプティブバナー | 画面幅に応じた高さのバナー広告。`getCurrentOrientationAnchoredAdaptiveBannerAdSize` で実装するルール。 | Rules.md、`docs/knowledge_base/reusable_patterns/admob_adaptive_banner.md` |
| app-ads.txt | — | ドメイン直下に置く必要があるファイル。GitHub Pages ではプロジェクトページではなくユーザーページ（`{user}.github.io` の専用リポジトリ）で公開する。ファイルの用途そのものは要確認。 | Rules.md |
| Data Safety | Data Safety 申告 | AdMob・IAP を含むアプリのリリース準備に、プライバシーポリシー URL とあわせて必ず含める申告。申告項目の内容や Google 側の仕様は要確認。 | Rules.md、`docs/knowledge_base/general/2026-10-29_v1.4.0-release-security-review.md` |
| プライバシーポリシー | — | アプリ内の同意ダイアログからリンクされる公開ページ。リリースには URL を必ず含める。 | Rules.md、`lib/utils/legal_urls.dart` |
| 利用規約の改定と再同意 | — | 規約側の更新とアプリ内の `kTermsVersion` 更新をセットで行う。定数を上げ忘れると既存ユーザーに再同意が求められない。 | Rules.md |
| 申請フォームドラフトの非保存方針 | 公開前ドラフト | Play Console 申請フォーム・審査関連文書・ブログ告知ドラフトなど、外部提出前・公開前の下書きは GitHub に保存せず、作成と同時に `.gitignore` へ登録する。 | Rules.md、memory/feedback_no_github_for_prerelease_drafts.md |
| git filter-repo | 履歴からの完全削除 | コミット済みのファイルを履歴から完全に消すための手段。実行前に `git bundle create --all` でバックアップを取り、「今後のみ除外」か「履歴からも完全削除」かを確認する。 | Rules.md、memory/project_hkl001_git_history_rewrite_2026-08-24.md |
| JDK17固定 | `org.gradle.java.home` | `flutter run` がJDK25とGradle8.14の非互換で失敗した際の対処。`~/.gradle/gradle.properties` で JDK17 を固定する。 | memory/project_hkl001_jdk_gradle_pin.md |
