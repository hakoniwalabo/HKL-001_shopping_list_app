# 広告なしIAP（remove_ads）失効検知 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `PurchaseNotifier.build()` を、ローカルキャッシュ（SharedPreferences の `is_ad_free`）の真偽によらず毎回 Play Store 側の実際の購入状態（`InAppPurchaseAndroidPlatformAddition.queryPastPurchases()`）を照会するように変更し、`remove_ads` 購入が返金・取り消しされた場合に次回起動時に自動的に「広告なし」状態を解除できるようにする。

**Architecture:** 判定ロジック（Play Store照会結果とキャッシュ値から採用すべき真偽値・永続化要否を決める部分）を `lib/utils/purchase_resolution.dart` に純粋関数として切り出し、`package:test` で単体テストする。`PurchaseNotifier.build()`（`lib/providers/purchase_provider.dart`）はこの純粋関数を呼び出す薄い配線コードとし、`InAppPurchase`/`InAppPurchaseAndroidPlatformAddition` そのもののモック化は行わない（理由は下記「テスト方針の判断理由」を参照）。既存の `purchase()`・`restore()`・`_onPurchaseUpdate`・購入ストリーム購読は変更しない。

**Tech Stack:** Flutter（Dart SDK `^3.11.4`）、flutter_riverpod 3.x（`AsyncNotifier`）、`in_app_purchase: ^3.3.0` ＋ `in_app_purchase_android`（0.5.x、Billing Library 8.0.0対応）、`package:test`（純粋ロジックの単体テスト、新規dev_dependency追加なし）

## Global Constraints

- Dart SDK は `^3.11.4`（pubspec.yaml）。flutter_riverpod は `^3.0.0`（3系）。ただし本プランは `PurchaseNotifier` を直接テストしない（後述）ため、Riverpod 3系特有の `ProviderContainer` テストパターンの差異は本プランの対象外
- `in_app_purchase: ^3.3.0` は `in_app_purchase_android: ^0.5.0` を推移的依存として要求し、現状 `pubspec.lock` は `0.5.2` に解決済み（Billing Library 8.0.0対応）。`InAppPurchaseAndroidPlatformAddition.queryPastPurchases()` は内部で `BillingClient.queryPurchases(ProductType.inapp)` を呼び、現在有効な購入一覧を直接返す（非推奨の `queryPurchaseHistory` 系とは別物）
- このプロジェクトはAdMob・IAPともにAndroid専用（iOS非対応）。プラットフォーム分岐は追加しない
- 検証は `flutter analyze` と `flutter test`（純粋ロジックの単体テスト）のみで行う。エミュレーター・実機での目視確認は行わず、マスターに依頼する（`Rules_Flutter_RN.md`「エミュレーターでのテストは絶対に行わない」方針）
- `PurchaseDetails.productID` の型は `String`（`in_app_purchase_platform_interface` で確認済み）。設計書の `productID == kRemoveAdsProductId` 比較はいずれも `String` 同士の比較であり型不一致の懸念はない

## テスト方針の判断理由（設計書「テスト方針」を満たす具体化）

設計書は次の3ケースの単体テストを要求している：「購入が見つかる場合→true」「購入が見つからない場合（エラーなし）→false」「クエリがエラーを返す場合→直前のキャッシュ値を維持」。これを `PurchaseNotifier`（`InAppPurchase.instance` を直接呼ぶ）に対して行おうとすると、次の技術的リスクがある。

- `InAppPurchase.instance` はプロセス内で一度だけ遅延初期化されるシングルトンで、初回アクセス時に `InAppPurchaseAndroidPlatform.registerPlatform()` が実走し、`BillingClientManager()`（実際の `MethodChannel` 経由でネイティブ Android Billing Client に接続を試みるオブジェクト）を構築する。`flutter test` 環境下（`package:test` ベース、`TestWidgetsFlutterBinding` 未初期化）でこれが発火すると、プラットフォームチャネルのハンドラが存在せず `MissingPluginException` 等が非同期に発生しうる。`InAppPurchasePlatform.instance` / `InAppPurchasePlatformAddition.instance` をテスト側で後から差し替えても、この初回登録の副作用そのものは防げない
- `InAppPurchaseAndroidPlatformAddition` は具象クラスで `BillingClientManager` を必須コンストラクタ引数に取るため、`extends` で軽量フェイクを作ることができない。`implements` で回避するには `mockito`/`mocktail` の追加が必要になり、実質的に「配線コード」をテストするために新規依存を増やすことになる

このため、本プランでは **判定ロジック（Play Store照会結果 → 採用すべき真偽値・永続化要否）を純粋関数として切り出し、`InAppPurchase`/`InAppPurchaseAndroidPlatformAddition` には一切触れずに `package:test` でテストする**。設計書が要求する3ケースは、この純粋関数の `hasError`/`purchasedProductIds` 引数の組み合わせとして過不足なく再現できるため、設計書のテスト方針を実質的に満たす。`InAppPurchase.instance` 経由の実際の配線（`getPlatformAddition` の型キャストや `queryPastPurchases()` 呼び出しそのもの）はコードレビューで確認し、実機での動作確認はマスターが別途実施する。

新規 dev_dependency（`mockito`/`mocktail` 等）は追加しない。

## help_dialog.dart 更新要否の判断

プロジェクトルール「機能を追加・変更・削除したときは必ず `lib/widgets/help_dialog.dart` を同時に更新する」について検討した。`lib/widgets/help_dialog.dart` の広告関連の説明（105〜109行目、`'AppBar右上の「⋮」→「広告を削除」から買い切り購入'`）は、ユーザーが能動的に行う購入操作の説明であり、本機能（バックグラウンドでの失効検知・自動同期）はこの操作フロー自体を変更しない。失効検知後は「広告を削除」メニュー項目が自動的に再表示されるだけで、これは既存のヘルプ文言（購入導線の説明）の範囲内で説明可能な挙動であり、新しいUI操作を追加するものではない。**したがって `help_dialog.dart` の更新は不要と判断する。**

## 計画外・要確認事項（設計書の「影響ファイル」に含まれないため実施しない）

`docs/spec_HKL-001_shopping_list_app_rev8.7.md` には以下の記述があり、本実装後は正確性を欠く可能性がある。

- 278〜284行目「7.2 PurchaseNotifier」: `- 起動時の自動購入復元（restorePurchases()）` — 本実装後は `restorePurchases()` ではなく `queryPastPurchases()` による毎回照会に変わる
- 159行目: `広告なしアップグレード | 買い切り IAP（remove_ads）でアプリ内広告を永久非表示` — 「永久」という表現は返金時に解除されうる本仕様と矛盾する
- 917行目「14.3 広告なし購入（IAP）」: `購入復元 | アプリ起動時に restorePurchases() を自動実行`

これらは承認済み設計書の「影響ファイル」一覧（`lib/providers/purchase_provider.dart` とテストファイルのみ）に含まれていないため、本プランのタスクには含めない。**生きた仕様書の更新要否をマスターに確認し、必要であれば別タスクとして追加すること。**

---

## ファイル構成

| 操作 | パス |
|------|------|
| 新規作成 | `lib/utils/purchase_resolution.dart` |
| 新規作成 | `test/purchase_resolution_test.dart` |
| 変更 | `pubspec.yaml`（`in_app_purchase_android` を推移的依存から明示的な直接依存へ格上げ） |
| 変更 | `lib/providers/purchase_provider.dart` |

---

## Task 1: 判定ロジックの純粋関数 `resolveAdFreeState` を作成する

**Files:**
- Create: `lib/utils/purchase_resolution.dart`
- Create: `test/purchase_resolution_test.dart`

**Interfaces:**
- Produces: `class AdFreeResolution { final bool resolved; final bool shouldPersist; }`（`==`/`hashCode`/`toString` 実装済み、`const` コンストラクタ）
- Produces: `AdFreeResolution resolveAdFreeState({required bool cached, required List<String> purchasedProductIds, required bool hasError, required String targetProductId})`

- [ ] **Step 1: 失敗するテストを書く**

`test/purchase_resolution_test.dart` を作成する。

```dart
import 'package:test/test.dart';
import 'package:shopping_list_app/utils/purchase_resolution.dart';

void main() {
  group('resolveAdFreeState', () {
    const productId = 'remove_ads';

    test('エラーなし・対象商品が pastPurchases に含まれる場合は true を採用し、永続化する', () {
      final result = resolveAdFreeState(
        cached: false,
        purchasedProductIds: const [productId],
        hasError: false,
        targetProductId: productId,
      );
      expect(
        result,
        const AdFreeResolution(resolved: true, shouldPersist: true),
      );
    });

    test(
      'エラーなし・対象商品が pastPurchases に含まれない場合は false を採用し、'
      '永続化する（返金・取り消しの検知）',
      () {
        final result = resolveAdFreeState(
          cached: true,
          purchasedProductIds: const [],
          hasError: false,
          targetProductId: productId,
        );
        expect(
          result,
          const AdFreeResolution(resolved: false, shouldPersist: true),
        );
      },
    );

    test('エラーあり・cached が true の場合は cached を維持し、永続化しない', () {
      final result = resolveAdFreeState(
        cached: true,
        purchasedProductIds: const [],
        hasError: true,
        targetProductId: productId,
      );
      expect(
        result,
        const AdFreeResolution(resolved: true, shouldPersist: false),
      );
    });

    test('エラーあり・cached が false の場合も cached を維持し、永続化しない', () {
      final result = resolveAdFreeState(
        cached: false,
        purchasedProductIds: const [productId],
        hasError: true,
        targetProductId: productId,
      );
      expect(
        result,
        const AdFreeResolution(resolved: false, shouldPersist: false),
      );
    });

    test('対象と異なる productID の購入しかない場合は false を採用する', () {
      final result = resolveAdFreeState(
        cached: true,
        purchasedProductIds: const ['other_product'],
        hasError: false,
        targetProductId: productId,
      );
      expect(
        result,
        const AdFreeResolution(resolved: false, shouldPersist: true),
      );
    });
  });
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```
flutter test test/purchase_resolution_test.dart
```

期待出力: `Error: Could not resolve URI 'package:shopping_list_app/utils/purchase_resolution.dart'`（またはコンパイルエラー）

- [ ] **Step 3: 実装する**

`lib/utils/purchase_resolution.dart` を作成する。

```dart
/// 「広告なし」状態を判定した結果。
///
/// [resolved] は実際に採用すべき値。[shouldPersist] が true の場合のみ
/// 呼び出し側は SharedPreferences（key: `is_ad_free`）へ保存する。
class AdFreeResolution {
  final bool resolved;
  final bool shouldPersist;

  const AdFreeResolution({
    required this.resolved,
    required this.shouldPersist,
  });

  @override
  bool operator ==(Object other) =>
      other is AdFreeResolution &&
      other.resolved == resolved &&
      other.shouldPersist == shouldPersist;

  @override
  int get hashCode => Object.hash(resolved, shouldPersist);

  @override
  String toString() =>
      'AdFreeResolution(resolved: $resolved, shouldPersist: $shouldPersist)';
}

/// Play Store への照会結果（[purchasedProductIds]・[hasError]）とローカル
/// キャッシュ（[cached]）から、採用すべき「広告なし」状態を判定する純粋関数。
///
/// 判定ロジック（設計書
/// `docs/superpowers/specs/2026-07-28-purchase-revocation-detection-design.md`
/// の判定ロジック2〜4に対応）:
/// - [hasError] が true（通信エラー・例外時）→ [cached] をそのまま採用し、
///   永続化しない（安全側に倒し、正規購入者の広告非表示状態を誤って解除しない）
/// - [hasError] が false かつ [purchasedProductIds] に [targetProductId] が
///   含まれる → true を採用し、永続化する
/// - [hasError] が false かつ含まれない → false を採用し、永続化する
///   （返金・取り消しにより広告が復活するケース）
AdFreeResolution resolveAdFreeState({
  required bool cached,
  required List<String> purchasedProductIds,
  required bool hasError,
  required String targetProductId,
}) {
  if (hasError) {
    return AdFreeResolution(resolved: cached, shouldPersist: false);
  }
  final hasTargetPurchase = purchasedProductIds.contains(targetProductId);
  return AdFreeResolution(resolved: hasTargetPurchase, shouldPersist: true);
}
```

- [ ] **Step 4: テストが通ることを確認する**

```
flutter test test/purchase_resolution_test.dart
```

期待出力: 全件 PASS

- [ ] **Step 5: flutter analyze でエラーがないことを確認する**

```
flutter analyze lib/utils/purchase_resolution.dart test/purchase_resolution_test.dart
```

期待出力: `No issues found!`

- [ ] **Step 6: コミット**

```bash
git add lib/utils/purchase_resolution.dart test/purchase_resolution_test.dart
git commit -m "feat: 広告なし状態の判定ロジックを純粋関数 resolveAdFreeState として切り出し"
```

---

## Task 2: `PurchaseNotifier.build()` を Play Store 毎回照会方式に変更する

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/providers/purchase_provider.dart`

**Interfaces:**
- Consumes: `AdFreeResolution`・`resolveAdFreeState`（Task 1、`lib/utils/purchase_resolution.dart`）
- Consumes: `InAppPurchaseAndroidPlatformAddition.queryPastPurchases()` → `Future<QueryPurchaseDetailsResponse>`（`pastPurchases: List<GooglePlayPurchaseDetails>` ※`PurchaseDetails` を継承、`error: IAPError?`）（`package:in_app_purchase_android`）

- [ ] **Step 1: `pubspec.yaml` の `dependencies` に `in_app_purchase_android` を明示的に追加する**

`in_app_purchase_android` は現状 `in_app_purchase` 経由の推移的依存（`pubspec.lock` で `dependency: transitive`、解決済みバージョン `0.5.2`）だが、`lib/providers/purchase_provider.dart` から `InAppPurchaseAndroidPlatformAddition` 型を直接 import するため、直接依存として明示する。明示しないと `analysis_options.yaml` が include する `flutter_lints`（`package:lints/core.yaml` 由来）の `depend_on_referenced_packages` lint に抵触し `flutter analyze` が警告を出す。

変更前（`pubspec.yaml` 37〜38行目）:
```yaml
  google_mobile_ads: ^5.2.0
  in_app_purchase: ^3.3.0
```

変更後:
```yaml
  google_mobile_ads: ^5.2.0
  in_app_purchase: ^3.3.0
  in_app_purchase_android: ^0.5.0
```

`in_app_purchase: ^3.3.0` は `in_app_purchase_android: ^0.5.0` を要求しており、`pubspec.lock` は既に `0.5.2` に解決済みのため、このバージョン制約追加によって解決バージョンが変わることはない。

- [ ] **Step 2: `flutter pub get` を実行する**

```
flutter pub get
```

期待結果: `pubspec.lock` の `in_app_purchase_android` エントリが `dependency: transitive` から `dependency: "direct main"` に変わる（バージョンは `0.5.2` のまま変わらない）。

- [ ] **Step 3: `lib/providers/purchase_provider.dart` を変更する**

ファイル全体を以下に置き換える。

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/purchase_resolution.dart';

/// Play Console に登録するプロダクト ID（本番リリース前に要設定）
const kRemoveAdsProductId = 'remove_ads';
const _kPrefKey = 'is_ad_free';

class PurchaseNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // ① SharedPreferences からキャッシュを即時読み込み
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_kPrefKey) ?? false;

    // ② 購入ストリームを購読（dispose 時にキャンセル）
    final sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
    );
    ref.onDispose(sub.cancel);

    // ③〜⑤ cached の真偽によらず毎回 Play Store 側の実際の購入状態を照会し、
    // 返金・取り消し（失効）を検知する。通信エラー・例外時は cached を維持する
    // （安全側に倒し、正規購入者の広告非表示状態を誤って解除しない）。
    final resolution = await _queryAdFreeResolution(cached);
    if (resolution.shouldPersist) {
      await prefs.setBool(_kPrefKey, resolution.resolved);
    }
    return resolution.resolved;
  }

  /// Play Store 側の実際の購入状態を照会し、[resolveAdFreeState] で判定する。
  /// `queryPastPurchases()` 自体が例外を投げた場合も通信エラーと同様に扱い、
  /// cached の値を維持する（無音で失敗させる。ユーザー向けエラー表示はしない）。
  Future<AdFreeResolution> _queryAdFreeResolution(bool cached) async {
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      return resolveAdFreeState(
        cached: cached,
        purchasedProductIds: response.pastPurchases
            .map((p) => p.productID)
            .toList(),
        hasError: response.error != null,
        targetProductId: kRemoveAdsProductId,
      );
    } catch (_) {
      return resolveAdFreeState(
        cached: cached,
        purchasedProductIds: const [],
        hasError: true,
        targetProductId: kRemoveAdsProductId,
      );
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != kRemoveAdsProductId) continue;
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _persist(true);
        if (p.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(p);
        }
      }
    }
  }

  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, value);
    state = AsyncData(value);
  }

  /// 購入フロー。エラーメッセージを返す（null = 正常にシート表示）
  Future<String?> purchase() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) return 'Google Play に接続できません';

      final response = await InAppPurchase.instance.queryProductDetails({
        kRemoveAdsProductId,
      });

      if (response.error != null) return response.error!.message;
      if (response.productDetails.isEmpty) {
        return '商品情報を取得できませんでした\n（Play Console でのプロダクト登録を確認してください）';
      }

      final param = PurchaseParam(
        productDetails: response.productDetails.first,
      );
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      return null; // 結果はストリームで受け取る
    } catch (e) {
      return '購入処理に失敗しました。しばらくしてから再試行してください。';
    }
  }

  /// 購入の復元（端末変更後など）
  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }
}

final purchaseProvider = AsyncNotifierProvider<PurchaseNotifier, bool>(
  PurchaseNotifier.new,
);
```

変更点は次の3つのみ（設計書「判定ロジック」1〜5、「エラーハンドリング」に対応）:
1. `import '../utils/purchase_resolution.dart';` を追加
2. `build()` 内の「③ キャッシュが false のときだけ Play Store で照合」ブロック（`if (!cached) { ... isAvailable/restorePurchases ... }`）を削除し、`_queryAdFreeResolution(cached)` を毎回呼び出す処理に置き換え
3. `_queryAdFreeResolution` メソッドを新規追加（`getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases()` を呼び、結果を `resolveAdFreeState` に渡す。例外時は `hasError: true` として同じ関数に委譲）

`_onPurchaseUpdate`・`_persist`・`purchase()`・`restore()`・`purchaseProvider` の定義は既存のまま変更しない（設計書「判定ロジック5」）。

- [ ] **Step 4: flutter analyze でエラーがないことを確認する**

```
flutter analyze lib/providers/purchase_provider.dart
```

期待出力: `No issues found!`

- [ ] **Step 5: プロジェクト全体で flutter analyze ・ flutter test がクリーンであることを確認する**

```
flutter analyze
flutter test
```

期待出力: どちらも 0 エラー・全件 PASS（`test/purchase_resolution_test.dart` を含む既存の `test/category_test.dart`・`test/item_test.dart`・`test/backup_test.dart`・`test/favorites_section_helper_test.dart`・`test/widget_test.dart` すべて）

- [ ] **Step 6: コミット**

```bash
git add pubspec.yaml pubspec.lock lib/providers/purchase_provider.dart
git commit -m "fix: 起動時に毎回Play Store側の購入状態を照会し、remove_adsの返金・取り消しを検知して広告なし状態を自動解除"
```

---

## 完了確認

- [ ] `flutter analyze` がエラー0件
- [ ] `flutter test` が全件 PASS（`test/purchase_resolution_test.dart` を含む）
- [ ] `lib/providers/purchase_provider.dart` の `purchase()`・`restore()`・`_onPurchaseUpdate` が変更されていない（設計書「判定ロジック5」）
- [ ] `pubspec.yaml`／`pubspec.lock` の `in_app_purchase_android` 解決バージョンが `0.5.2` のまま変わっていない
- [ ] `help_dialog.dart` は本プランの判断により更新しない（上記「help_dialog.dart 更新要否の判断」を参照）
- [ ] `docs/spec_HKL-001_shopping_list_app_rev8.7.md` の更新要否をマスターに確認する（上記「計画外・要確認事項」を参照。本プランのタスクには含めない）
- [ ] エミュレーター／実機での返金シナリオ確認（Google Play Console でのテスト返金操作 → 再起動 → 広告なし解除確認）はマスターが別途実施する（本プランには含めない）

---

*作成：2026-07-28　設計書 `docs/superpowers/specs/2026-07-28-purchase-revocation-detection-design.md`（ユーザー承認済み）をもとに作成*
