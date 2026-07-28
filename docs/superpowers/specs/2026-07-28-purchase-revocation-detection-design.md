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

1. `cached`（SharedPreferencesの値）の真偽によらず、毎回 `InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases()` を呼ぶ
2. `response.error` が非nullの場合（オフライン等の通信エラー） → 何もせず `cached` の値をそのまま採用する（安全側に倒し、正規購入者の広告非表示状態を誤って解除しない）
3. `response.error` がnullで、`pastPurchases` に `productID == kRemoveAdsProductId` かつ有効な購入が含まれる場合 → `true` を採用しSharedPreferencesへ保存
4. `response.error` がnullで、上記が含まれない場合 → `false` を採用しSharedPreferencesへ保存（広告が復活する）
5. 既存の手動購入フロー（`purchase()`）・手動復元ボタン（`restore()`、`upgrade_dialog.dart`の「購入を復元」）はそのまま維持し、変更しない

### エラーハンドリング

- `queryPastPurchases()` 自体が例外を投げた場合も、通信エラーと同様に扱い `cached` の値を維持する（try-catchで握りつぶし、ユーザー向けエラー表示はしない。バックグラウンドの整合性チェックのため無音でよい）

### テスト方針

- `PurchaseNotifier` のロジックを検証する単体テストを追加する（`flutter test`）
- Riverpodの `AsyncNotifier` を対象に、`InAppPurchase`/`InAppPurchaseAndroidPlatformAddition` をモック化し、以下のケースを検証する：
  - 購入が見つかる場合 → `true`
  - 購入が見つからない場合（エラーなし） → `false`
  - クエリがエラーを返す場合 → 直前のキャッシュ値を維持
- 既存の `flutter analyze` ・ `flutter test` がクリーンであることを確認する

### 影響ファイル

- `lib/providers/purchase_provider.dart`（主な変更対象）
- テストファイル（新規追加、既存のテスト構成に合わせる）
