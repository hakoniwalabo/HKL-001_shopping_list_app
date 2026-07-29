# 広告なしIAP（remove_ads）の失効検知 設計書

作成日：2026-07-28
対象プロジェクト：HKL-001買い物リストアプリ

## 背景・課題

- `lib/providers/purchase_provider.dart` の `PurchaseNotifier.build()` は、ローカルキャッシュ（SharedPreferences の `is_ad_free`）が `false` のときだけ Play Store に `restorePurchases()` で再照会し、`true` になった後は二度と Play Store 側の状態を確認しない
- そのため、Play Console側で該当ユーザーの `remove_ads` 購入が返金・取り消しされても、アプリ側は永久に「広告なし」のままになる
- 現状、いったん広告なしになると `lib/screens/shopping_list_screen.dart` の「⋮」メニューから「広告を削除」項目自体が非表示になる（`if (!isAdFree)` 分岐）ため、ユーザーが手動で購入状態を再確認する導線も存在しない
- 2026-07-28、Google Play Consoleでのライセンステスト購入検証中に本問題が判明した。テスト用の返金操作をしても、アプリ側の表示が元に戻らないことを確認した

## 目的

- テスト時の利便性だけでなく、実際のユーザーが正規に返金を受けた場合にも「広告なし」状態を自動的に解除できるようにする（本番でも有効な仕様変更）

## 対象範囲外（Non-goals）

- リアルタイム（即時）検知は対象外。検知は次回アプリ起動時でよい（サーバー・Realtime Developer Notifications 等のバックエンド新設はこのアプリの規模には過剰投資のため見送る）
- iOS対応は対象外（このプロジェクトはAdMob・IAPともにAndroid専用。Rules.mdに既存の前提として明記済み）

## 設計

### 使用API

- `in_app_purchase_android`（バージョン0.5.2、Billing Library 8.0.0対応）の `InAppPurchaseAndroidPlatformAddition.queryPastPurchases()` を使用する
- このAPIは内部で `BillingClient.queryPurchases(ProductType.inapp)` を呼び、現在有効な購入一覧を直接返す（過去に問題となった非推奨の `queryPurchaseHistory` 系とは別物であり、影響を受けない）
- 戻り値 `QueryPurchaseDetailsResponse` は `pastPurchases`（現在有効な購入のリスト）と `error`（`IAPError?`）を持つ

### 判定ロジック（`PurchaseNotifier.build()` を変更）

1. `cached`（SharedPreferencesの値）の真偽によらず、毎回 `InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases()` を呼び、Play Store側の実際の購入状態を照会する。ただし、待ち方は`cached`の値によって非対称にする（広告が「表示される」までの遅延は許容できるが、「非表示になる」までの遅延は許容できない＝正規購入者を待たせないという業務要件のため）
   - `cached == true`（現在広告なし）：失効していれば広告が復活するまで多少遅れてもよいため、照会はバックグラウンドで実行し（`unawaited`）、起動処理（`build()`の戻り値）はブロックしない
   - `cached == false`（現在広告あり）：正規購入が見つかった場合は広告を即座に消す必要があるため、照会の完了を待ってから結果を返す
2. `queryPastPurchases()` の呼び出しには10秒のタイムアウト（`_kQueryPastPurchasesTimeout`）を設定する。最終ブランチレビューでの指摘を受けて追加対応したもので、タイムアウトが発生した場合も通信エラーと同様に扱い `cached` の値を維持する
3. `response.error` が非nullの場合（オフライン等の通信エラー） → 何もせず `cached` の値をそのまま採用する（安全側に倒し、正規購入者の広告非表示状態を誤って解除しない）
4. `response.error` がnullの場合、見つかった購入（`PurchaseStatus.purchased`）のうち `productID == kRemoveAdsProductId` かつ未確定（`pendingCompletePurchase == true`）のものは `completePurchase()` で確定させる。コンビニ払いなど支払い完了までに時間差がある決済方式では購入が保留（pending）状態で返ってくることがあり、未確定のまま3日以上放置するとGoogle Playが自動的に返金してしまう仕様があるため、これを防ぐための処理である
5. `response.error` がnullで、`pastPurchases` に `productID == kRemoveAdsProductId` かつ有効な購入が含まれる場合 → `true` を採用しSharedPreferencesへ保存
6. `response.error` がnullで、上記が含まれない場合 → `false` を採用しSharedPreferencesへ保存（広告が復活する）
7. 既存の手動購入フロー（`purchase()`）・手動復元ボタン（`restore()`、`upgrade_dialog.dart`の「購入を復元」）はそのまま維持し、変更しない

### エラーハンドリング

- `queryPastPurchases()` 自体が例外を投げた場合も、通信エラーと同様に扱い `cached` の値を維持する（try-catchで握りつぶし、ユーザー向けエラー表示はしない。バックグラウンドの整合性チェックのため無音でよい）

### テスト方針

- 当初は `InAppPurchase`/`InAppPurchaseAndroidPlatformAddition` をモック化して `PurchaseNotifier`（Riverpodの `AsyncNotifier`）本体を直接検証する方針を想定していたが、`InAppPurchase.instance` への初回アクセスがネイティブのBillingClientチャネル接続を実際に発火させてしまう技術的リスクが判明したため、実装段階で以下の方針に転換した
- 判定ロジックを `resolveAdFreeState()`（`lib/utils/purchase_resolution.dart`）という純粋関数に切り出し、これを対象に単体テストを追加する（`test/purchase_resolution_test.dart`、5ケース）
  - エラーなし・対象商品が `pastPurchases` に含まれる場合 → `true` を採用し、永続化する
  - エラーなし・対象商品が含まれない場合 → `false` を採用し、永続化する（返金・取り消しの検知）
  - エラーあり・`cached` が `true` の場合 → `cached` を維持し、永続化しない
  - エラーあり・`cached` が `false` の場合 → `cached` を維持し、永続化しない
  - 対象と異なる `productID` の購入しかない場合 → `false` を採用する
- `PurchaseNotifier` 本体（`build()`・結線部分）を対象にした統合的な単体テストは、上記と同じ技術的リスクにより今回は未実装。`docs/remaining_tasks_purchase_revocation_2026-07-28.md` の「2.2」に保留事項として記載済み
- 既存の `flutter analyze` ・ `flutter test` がクリーンであることを確認する

### 影響ファイル

- `lib/providers/purchase_provider.dart`（主な変更対象）
- `lib/utils/purchase_resolution.dart`（新規、判定ロジックの純粋関数）
- `test/purchase_resolution_test.dart`（新規、上記のテスト）
