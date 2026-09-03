**カテゴリ**: purchase　**元ファイル名**: remaining_tasks_purchase_revocation_2026-07-28.md

---

# 返金・取り消し検知機能（purchase-revocation-detection）残タスク一覧

作成日：2026-07-28
対象機能：remove_ads（広告なしIAP）の返金・取り消し検知機能（purchase-revocation-detection）
マージ済みコミット：`1840ed0`（main ブランチへマージ済み）

このドキュメントは、上記機能のマージ完了時点で残っているタスク・確認事項を整理したものです。設計書は `docs/superpowers/specs/2026-07-28-purchase-revocation-detection-design.md`、実装本体は `lib/providers/purchase_provider.dart`・`lib/utils/purchase_resolution.dart` を参照。

---

## 1. マスター（ユーザー）による実機確認事項

いずれも Google Play の課金基盤に依存するため、自動テストでは検証できない項目。実機・実際の Play Console 操作を伴う確認が必要。

### 1.1 返金・取り消し検知の実地確認

**背景**：本機能は、アプリ起動時に `queryPastPurchases()` で Google Play 側の実際の購入状態を照会し、過去に「広告なし」を購入していたユーザーが返金・取り消しを受けた場合に、ローカルの `is_ad_free` フラグを解除して広告表示を復活させる仕組み（`lib/providers/purchase_provider.dart` の `_queryAdFreeResolution()` および `lib/utils/purchase_resolution.dart` の `resolveAdFreeState()`）。単体テスト（`test/purchase_resolution_test.dart`）で判定ロジックの正しさは検証済みだが、Google Play Console のテスト返金機能と実機を組み合わせた end-to-end の動作確認はまだ行われていない。

**確認方法**：Google Play Console のテスト用注文からテスト返金操作を行い、対象端末でアプリを再起動する。ローカルの「広告なし」状態が解除され、広告が復活することを確認する。

### 1.2 保留（PENDING）決済の確定処理の確認

**対応状況（2026-07-28）**：マスターの環境ではコンビニ決済のテストが実施できないため、実機でのend-to-end検証は不可と判断しクローズする。判定ロジック（`pendingCompletePurchase`が true の購入を`completePurchase()`で確定する処理）自体は単体テスト・コードレビューで検証済みであり、この制約を許容したうえで対応完了として扱う。

**背景**：コンビニ払いなど支払い完了までに時間差がある決済方式では、購入が `PurchaseStatus.pending` の状態で返ってくる。実装では `queryPastPurchases()` の結果のうち `pendingCompletePurchase` が true のものを `completePurchase()` で確定させる処理を追加している（`purchase_provider.dart` 79〜83行目）。これは、未確定（unacknowledged）のまま3日以上放置すると Google Play が自動的に返金してしまう仕様への対応。この確定処理が実際のコンビニ払いフローで正しく機能するかは実機未確認。

**確認方法**：コンビニ払い等の保留決済で購入操作を行い、支払いが完了した後にアプリを再起動する。購入が正しく確定（acknowledge）され、Google Play の「3日以内に未確定の場合は自動返金」の仕様によって誤って返金されないことを確認する。

### 1.3 通常の即時購入フローのデグレ確認

**背景**：今回の変更は起動時の照会ロジック（`build()`）に手を加えたものであり、購入ボタンからの通常購入フロー自体（`purchase()`・`_onPurchaseUpdate()`）はロジック上変更していない。ただし、変更が意図せず通常フローに影響していないかは実機で確認しておきたい。

**確認方法**：購入ボタンをタップ→支払いを完了→広告が即座に非表示になることを確認する。従来通り正常に動作することを確認する。

---

## 2. フォローアップ検討事項（デグレではないが改善余地あり、ブロッカーではない）

### 2.1 `_queryAdFreeResolution()` にタイムアウトガードがない

**対応状況（2026-07-28）**：`_kQueryPastPurchasesTimeout`（10秒）を追加し、`addition.queryPastPurchases()` にタイムアウトを付与する形で対応済み。タイムアウト時は既存の `catch (_)` 節により `cached` を維持し、起動をブロックしない。

**背景**：`purchase_provider.dart` の `build()` において、`cached == false`（未購入・広告表示中）の場合は `await _queryAdFreeResolution(cached)` の完了を待ってから起動処理を返す設計になっている（37〜46行目のコメントにある通り、正規購入者を待たせないための意図的な設計）。しかし、この待機処理自体にタイムアウトが設定されていないため、Play Billing との接続がハングした場合、非購入ユーザーの起動処理がブロックされ続ける可能性がある。

**経緯**：最終ブランチレビューで指摘された点。デグレではなく、本機能（Task 2）の実装前から存在していた `restorePurchases()` 呼び出しにも同様の性質があったため、今回の実装のスコープ外として保留された。

**確認方法**：対応する場合は、`_queryAdFreeResolution()` の呼び出しに `Future.timeout()` 等でタイムアウトを設定し、タイムアウト時は `cached` を維持して起動をブロックしないようにする改修を検討する。

### 2.2 `PurchaseNotifier` 本体の単体テストが未実装

**対応状況（2026-07-28）**：調査の結果、`InAppPurchaseAndroidPlatformAddition` のモックにはプラグイン内部（`BillingClientManager`・`BillingClient`）まで踏み込んだフェイクが必要と判明したため、マスターの判断により今回は見送り。引き続き「現時点では対応必須ではない」保留事項として扱う。

**背景**：設計書（`docs/superpowers/specs/2026-07-28-purchase-revocation-detection-design.md`）では、`InAppPurchase`・`InAppPurchaseAndroidPlatformAddition` をモック化して `PurchaseNotifier`（`AsyncNotifier`）本体を検証する単体テスト（3ケース）が想定されていた。

**経緯**：実装計画の段階で、`InAppPurchase.instance` への初回アクセスがネイティブの BillingClient チャネル接続を実際に発火させてしまう技術的リスクがあることが判明したため、これに代えて判定ロジック部分を純粋関数として切り出し（`lib/utils/purchase_resolution.dart` の `resolveAdFreeState()`）、そのロジックを対象にした単体テスト（`test/purchase_resolution_test.dart`、5ケース）で代替する判断がなされた。この方針転換はマスターにも計画提示時に共有済み。

**確認方法**：`PurchaseNotifier` 本体（`build()`・`_queryAdFreeResolution()`・`_onPurchaseUpdate()` などの結線部分）の統合的な検証が必要になった場合は、モックの導入方法（例：`InAppPurchasePlatform` の差し替え）を別途検討する。現時点では対応必須ではない。

---

## 3. ドキュメント整合性の確認（今回の実装計画のスコープ外として意図的に対象外にした事項）

### 3.1 `docs/spec_HKL-001_shopping_list_app_rev8.7.md` の記述更新

**対応状況（2026-07-28）**：`spec_HKL-001_shopping_list_app_rev8.7.md` を `rev8.8.md` へ `git mv` でリネームし、284行目・917行目の記述を「`queryPastPurchases()` による毎回照会方式」に更新済み（コミット `b43c69f`）。あわせて、本文のRev表記が8.8になっているのにファイル名が8.7のままだったリネーム漏れ自体もマスターの指摘で発覚し、修正した。

**背景**：今回の実装により、起動時の購入状態確認の方式が「`restorePurchases()` による自動復元」から「`queryPastPurchases()` による毎回の状態照会」に変更された。`restorePurchases()` は現在、AppBar の「購入を復元」ボタンに対応する `restore()` からのみ手動で呼ばれる（`purchase_provider.dart` 146〜150行目）。設計書と実装は最新化済みだが、仕様書 rev8.7 の該当箇所は未更新のまま残っている。

以下の2箇所が実際の実装と食い違っている。

- 284行目：「起動時の自動購入復元（`restorePurchases()`）」
- 917行目：「購入復元 \| アプリ起動時に `restorePurchases()` を自動実行」

なお、159行目・896行目にあった「永久非表示」という表現は既に別コミットで修正済みであり対象外。763行目の `restore()` の説明自体は現行実装と一致しており変更不要。

**確認方法**：上記2箇所を、「毎回起動時に `queryPastPurchases()` で購入状態を照会し、返金・取り消しがあれば広告表示を復活させる」旨の記述に更新する。仕様書の更新自体は本タスクのスコープ外としたため、別途対応が必要。

### 3.2 Google Play Console の商品説明文の修正状況

**対応状況（2026-07-28）**：マスターがGoogle Play Consoleで商品説明文を「購入すると、アプリ内の広告が非表示になります。」に修正済みであることを、Play Consoleの実際の画面（スクリーンショット、最終更新日時2026年7月28日）で確認した。`docs/iap_remove_ads_registration_2026-07-28.md` の提案文言と完全一致しており、「永久に」の表現も削除されている。

**背景**：Google Play Console 側の商品説明文が「購入すると、アプリ内の広告が永久に非表示になります。」となっており、返金・取り消し検知機能の導入後は実態と異なる表現になっている（返金・取り消しがあれば広告は復活するため「永久」ではない）。この文言修正はマスターへ依頼済みだが、実施状況は本ドキュメント作成時点で未確認。

**確認方法**：Google Play Console の商品詳細ページで、実際に文言が修正されているかを確認する。`docs/iap_remove_ads_registration_2026-07-28.md` の提案文言（「購入すると、アプリ内の広告が非表示になります。」）と一致しているかもあわせて確認する。

---

## 4. 開発環境の残骸

### 4.1 `.claude\worktrees\purchase-revocation-detection` ディレクトリ

**対応状況（2026-07-28）**：削除を再試行したところ、`rm -rf` で正常に削除できた（以前ロックしていたプロセスは解消済みだったと推測される）。`.claude\worktrees\` 配下からディレクトリは消滅している。

**背景**：SDD（仕様駆動開発）での実装完了後、この worktree ディレクトリを OS レベルのファイルロック（`Device or resource busy`）により自動削除できなかった。git 側のワークツリー登録自体は解除済みのため git 操作上の実害はない。

**確認方法**：`git worktree list` では既にこのワークツリーは登録から外れていることを確認済み（git操作上の実害なし）。一方、`C:\Users\gothf\develop\HKL-001_shopping_list_app\.claude\worktrees\purchase-revocation-detection` ディレクトリ自体は物理的にまだ存在しており、`rm -rf` を試みても `Device or resource busy` で削除できない状態が継続している（何らかのプロセスがファイルハンドルを保持している可能性がある）。関連プロセス（エディタ・ターミナル・アンチウイルスのスキャン等）を終了させたうえで、エクスプローラー等から手動削除することが望ましい。
