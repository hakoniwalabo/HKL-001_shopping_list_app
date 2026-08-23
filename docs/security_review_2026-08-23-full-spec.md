# セキュリティレビュー：フルスペック（アプリ全体）レビュー

**実施日**: 2026-08-23
**対象ブランチ**: `main`
**レビュー範囲**: フルスペックレビュー：`lib/`配下全27ファイル + `android/app/src/main/AndroidManifest.xml` + `pubspec.yaml` を対象。特定コミット範囲ではなく現在の`main`ブランチの全体を対象とする。

対象ファイル一覧：
`database/database_helper.dart`, `main.dart`, `models/category.dart`, `models/item.dart`, `models/shopping_list.dart`, `providers/category_provider.dart`, `providers/item_provider.dart`, `providers/purchase_provider.dart`, `screens/favorites_screen.dart`, `screens/shopping_list_screen.dart`, `services/backup_service.dart`, `utils/favorites_section_helper.dart`, `utils/purchase_resolution.dart`, `widgets/ad_banner.dart`, `widgets/add_item_dialog.dart`, `widgets/budget_summary.dart`, `widgets/category_management_dialog.dart`, `widgets/empty_state_view.dart`, `widgets/fields/item_name_field.dart`, `widgets/fields/memo_field.dart`, `widgets/fields/price_field.dart`, `widgets/fields/quantity_field.dart`, `widgets/help_dialog.dart`, `widgets/item_tile.dart`, `widgets/list_management_buttons.dart`, `widgets/list_section.dart`, `widgets/list_tab_bar.dart`, `widgets/total_summary.dart`, `widgets/upgrade_dialog.dart`

過去の差分レビュー（`docs/security_review_2026-06-13.md` 〜 `2026-07-28-favorites-fullscreen-and-pending-fixes.md`）で既に指摘・判定済みの事項は、本レビューで現在のコードを実際に読んで現状を再確認した上で扱っている（過去レポートの記述は鵜呑みにしていない）。

---

## 1. チェック観点と結果

| 観点 | 結果 | 詳細 |
|------|------|------|
| SQLインジェクション | ✅ 問題なし | `database_helper.dart` 全メソッド（items/lists/favorites/categories のCRUD、`importData`、`duplicateList`、`reorderFavorites`等）を確認。すべて `where: '... = ?', whereArgs: [...]` またはMap渡しの `db.insert`/`db.update` を使用し、文字列結合によるSQL構築は皆無。`rawQuery` は `SELECT MAX(...) FROM ...`（固定文字列）または `whereArgs` 併用のみ |
| 入力バリデーション | ⚠️ 既知の軽微な差異（新規指摘なし） | `ItemNameField`（空欄チェック）・`PriceField`（0以上）は全画面で一貫してvalidatorあり。`QuantityField`（`add_item_dialog.dart`で使用）にのみvalidatorが無く、`favorites_screen.dart`内の個数フィールド（1以上必須）と非対称。これは2026-06-13レビューで確信度8/10として検討されFP判定9/10で不採用（コード品質問題としてセキュリティ対象外と判断）済みの事項であり、現在のコードも当時と同じ状態（`lib/widgets/fields/quantity_field.dart`にvalidator無し、`_submit()`で`int.tryParse(...) ?? 1`によりnull/空欄は1にフォールバックするが、"0"は0のまま許容）。外部攻撃者が悪用できる経路はなくローカル単一ユーザーのデータ整合性の問題に留まるため、今回も新規のセキュリティ指摘とはしない |
| 業務ルール一貫性 | ✅ 問題なし | `importData`はUI側と同じ上限チェック（リスト10件・`list_limit_exceeded`）、リスト名/カテゴリ名/よく買うもの名の重複解決ロジックを一貫して適用。`categoryId`の付け替え（`categoryIdMap`）、孤立`listId`のスキップも実装済み |
| catch節情報露出 | ✅ 問題なし | 全catch節を確認（`shopping_list_screen.dart`の`_exportBackup`/`_importBackup`、`purchase_provider.dart`の`purchase()`、`favorites_screen.dart`の`_onReorderItem`等）。いずれも固定の日本語メッセージのみを表示し、`e.toString()`や例外オブジェクトの内容をユーザー向けメッセージに含めている箇所は無し（`lib/`全体を`e.toString()`で検索し該当なしを確認） |
| リソースリーク | ✅ 問題なし | `TextEditingController`・`FocusNode`・`ScrollController`・`Timer`・`TabController`をすべての生成箇所で確認。`favorites_screen.dart`（`_searchCtrl`/`_bodyScrollCtrl`/`_undoTimer`、`_AddFavoriteDialogState`の各コントローラ・`_nameFocus`）、`add_item_dialog.dart`（4コントローラ・`_nameFocus`・`_scrollCtrl`）、`shopping_list_screen.dart`（`_tabController`・`_listScrollCtrl`）、`item_name_field.dart`（内部生成`FocusNode`のみ破棄・外部注入分は呼び出し側が破棄する所有権分離）はすべて`dispose()`で解放済み。`purchase_provider.dart`の`purchaseStream`購読は`ref.onDispose(sub.cancel)`で解放。`ad_banner.dart`の`BannerAd`も`dispose()`で解放済み |
| マウントチェック | ✅ 問題なし | 非同期DB書き込み・ダイアログ表示後にcontextやsetStateを使う箇所すべてに`if (!mounted) return;`または`if (!context.mounted) return;`を確認。`favorites_screen.dart`の`_AddFavoriteDialogState`/`_EditFavoriteDialogState`の`_showNewCategoryDialog()`（2026-07-28レビューで修正された箇所）も引き続き実装されていることを再確認済み |
| 型キャスト安全性 | ✅ 問題なし | `database_helper.dart`の`importData`（外部JSONバックアップ由来のデータを扱う唯一の経路）は`(cat['id'] as num).toInt()`・`(list['id'] as num).toInt()`・`(item['listId'] as num).toInt()`・`(item['categoryId'] as num).toInt()`など、外部由来の数値はすべて`num.toInt()`パターンでキャストしており`as int`直接キャストは使用していない。`as int?`が使われている箇所（410, 479, 532, 603, 681行目）はいずれもローカルSQLiteの`SELECT MAX(...)`集計結果であり外部JSON由来ではない。`data['version'] as int?`（569行目）は`backup_service.dart`の`parseAndValidate()`で`data['version'] is! int`を事前検証済みのため安全 |
| 情報露出 | ✅ 問題なし | `backup_service.dart`の`shareList()`は対象1リストの未チェックアイテムのみ、かつそのアイテムが使用しているカテゴリのみを抽出して共有（他リスト・チェック済みアイテム・`favorites`・購入状態は含まない）。`_shareCurrentList()`（テキスト共有）も同様に選択中リストの内容のみ。フルバックアップ（`export()`/`saveToDevice()`）は全データを含むが、これはユーザーが明示的に選択した「バックアップ」操作であり意図した挙動 |

---

## 2. 追加確認事項（フルスペックレビュー固有）

### ハードコードされたシークレット・APIキー

`lib/`配下および`android/app/src/main/`配下を`api_key`/`secret`/`password`/`token`等のパターンで検索したが該当なし。

検出された識別子は以下の2件のみで、いずれもAdMobの「広告枠を識別するための公開ID」であり、認証情報・シークレットには該当しない（2026-06-13レビューでの判定を踏襲）：

- `android/app/src/main/AndroidManifest.xml:36` — `com.google.android.gms.ads.APPLICATION_ID` = `ca-app-pub-8553865418303420~5738093167`
- `lib/widgets/ad_banner.dart:4` — `_kBannerAdUnitId` = `ca-app-pub-8553865418303420/4001353550`

Google Play Billing・`in_app_purchase`関連のプロダクトID（`kRemoveAdsProductId = 'remove_ads'`）もPlay Console側で管理される公開識別子であり、シークレットではない。

### AndroidManifest.xmlの権限

宣言されている権限は`android.permission.INTERNET`のみ（広告表示・Play Billing通信に必須）。`queries`ブロックはFlutterエンジン標準の`PROCESS_TEXT`インテント処理用で、追加のパーミッションは要求しない。ストレージ系権限（`READ/WRITE_EXTERNAL_STORAGE`等）は宣言されておらず、バックアップの保存・読み込みは`file_picker`のSAF（Storage Access Framework）経由でユーザーが選択した場所のみにアクセスする設計と一致している。過剰な権限要求は無し。

### pubspec.yaml依存パッケージ

`flutter_riverpod ^3.0.0`、`sqflite ^2.3.0`、`google_mobile_ads ^5.2.0`、`in_app_purchase ^3.3.0`/`in_app_purchase_android ^0.5.0`、`shared_preferences ^2.3.0`、`share_plus ^10.1.4`、`file_picker ^8.1.0`、`path_provider ^2.1.0`、`intl ^0.19.0`のいずれもpub.dev上でメンテナンスが継続している標準的なパッケージで、バージョン指定に既知の重大な問題は見当たらない（深いCVE調査は範囲外）。`in_app_purchase_android`はBilling Library 8.0.0対応済み（2026-07-28レビューで確認済み、期限8/31に対して余裕あり）。git依存や出所不明なパッケージの追加は無い。

---

## 3. 許容したリスク（記録・過去レビューからの再確認含む）

**`is_ad_free`のSharedPreferences平文保存**：`purchase_provider.dart`は広告削除フラグをSharedPreferences（平文XML）にキャッシュする。root化端末では理論上直接書き換えて広告非表示を無料で有効化できるが、`cached == false`の場合は必ずPlay Store照会を待ってから返す設計であり、正規購入者の保護は担保されている。Play Integrity API導入は個人アプリ規模では過剰投資と判断し、2026-06-14レビューから継続して許容。

**`QuantityField`のバリデーション欠如**：`lib/widgets/fields/quantity_field.dart`には個数の下限チェックが無く、`add_item_dialog.dart`経由で個数0が保存され得る（`favorites_screen.dart`内の個数フィールドとは非対称）。2026-06-13レビューで確信度8/10として検討され、外部から悪用できる経路がなくローカル単一ユーザーの整合性問題に留まるためFP判定9/10で不採用（コード品質改善候補としてセキュリティ対象外）と判定済み。現在のコードも同一状態であることを確認し、同じ判断を維持する。

**商品名・カテゴリ名の長さ制限なし**：`ItemNameField`・カテゴリ名入力とも空欄チェックのみで文字数上限が無い。ローカルSQLite（TEXT型）のみへの書き込みで他ユーザーへの影響や認証回避リスクは無いため、2026-06-22／2026-06-29レビューから継続して許容。

**共有ファイル（`shareList`）へのメモ内容の含有**：未チェックアイテムの`toMap()`には`memo`フィールドが含まれ、リスト共有時にメモ内容も送信される。2026-06-13レビューで確信度3/10として検討され、共有は本人が明示的に選択したリスト内容の一部であり外部流出経路ではないため不採用と判定済み。現在のコードも同一の設計であることを確認し、同じ判断を維持する。

**共有ファイル・バックアップファイルの平文JSON**：暗号化されていないが、「他者と共有する」「端末に保存する」機能の性質上意図された動作であり、購入状態（`is_ad_free`）等の機微情報は含まれない設計で最小化済み（2026-06-16レビューから継続）。

---

## 4. 結論

`lib/`配下全27ファイル、`AndroidManifest.xml`、`pubspec.yaml`を対象にフルスペックレビューを実施した。SQLインジェクション・業務ルール一貫性・catch節情報露出・リソースリーク・マウントチェック・型キャスト安全性・情報露出の7観点は問題なし。入力バリデーションについては`QuantityField`のバリデーション欠如という既知の軽微な差異があるが、2026-06-13レビューで外部攻撃経路が無いことを理由にセキュリティ対象外（コード品質問題）と判定済みであり、現状のコードもその判定を覆す変化は無いため新規指摘としては扱わない。

ハードコードされたシークレット・APIキーは検出されず、AdMob識別子はいずれも公開情報の範囲。AndroidManifest.xmlの権限は`INTERNET`のみで過不足なし。pubspec.yamlの依存パッケージも標準的でバージョン指定に懸念は無い。

**総合判定：問題なし（リリース可）**。今回の全体レビューで新規に修正が必要なセキュリティ上の指摘事項は無く、既存の許容リスク（SharedPreferences平文保存・QuantityFieldバリデーション欠如・商品名等の文字数無制限・共有ファイルのメモ含有・平文JSON共有）はいずれも過去レビューでの判断を踏襲する。
