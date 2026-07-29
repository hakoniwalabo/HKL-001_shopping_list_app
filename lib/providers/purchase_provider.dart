import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/purchase_resolution.dart';

/// Play Console に登録するプロダクト ID（本番リリース前に要設定）
const kRemoveAdsProductId = 'remove_ads';
const _kPrefKey = 'is_ad_free';
const _kQueryPastPurchasesTimeout = Duration(seconds: 10);

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
    // 返金・取り消し（失効）を検知する。
    //
    // 広告が「表示される」までの遅延は許容できるが、「非表示になる」までの遅延は
    // 許容できない（正規購入者を待たせない）という業務要件のため、方向によって
    // 待ち方を変える：
    // - cached == true（現在広告なし）: 失効していれば広告が復活するまで多少
    //   遅れてもよいため、照会はバックグラウンドで行い起動表示をブロックしない
    // - cached == false（現在広告あり）: 正規購入が見つかった場合は広告を
    //   即座に消す必要があるため、照査の完了を待ってから返す
    if (cached) {
      unawaited(_refreshFromPlayStore(cached));
      return cached;
    }

    final resolution = await _queryAdFreeResolution(cached);
    if (resolution.shouldPersist) {
      await prefs.setBool(_kPrefKey, resolution.resolved);
    }
    return resolution.resolved;
  }

  /// バックグラウンドでPlay Store側の実際の購入状態を照会し、必要なら永続化する。
  Future<void> _refreshFromPlayStore(bool cached) async {
    final resolution = await _queryAdFreeResolution(cached);
    if (resolution.shouldPersist) {
      await _persist(resolution.resolved);
    }
  }

  /// Play Store 側の実際の購入状態を照会し、[resolveAdFreeState] で判定する。
  /// 見つかった購入のうち未確定（unacknowledged）のものは completePurchase() で
  /// 確定させる（未確定のまま放置すると Google Play により自動返金されるため）。
  /// `queryPastPurchases()` 自体が例外を投げた場合も通信エラーと同様に扱い、
  /// cached の値を維持する（無音で失敗させる。ユーザー向けエラー表示はしない）。
  Future<AdFreeResolution> _queryAdFreeResolution(bool cached) async {
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition
          .queryPastPurchases()
          .timeout(_kQueryPastPurchasesTimeout);
      if (response.error != null) {
        return resolveAdFreeState(
          cached: cached,
          purchasedProductIds: const [],
          hasError: true,
          targetProductId: kRemoveAdsProductId,
        );
      }

      final purchased = response.pastPurchases
          .where((p) => p.status == PurchaseStatus.purchased)
          .toList();
      for (final p in purchased) {
        if (p.productID == kRemoveAdsProductId && p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
      }

      return resolveAdFreeState(
        cached: cached,
        purchasedProductIds: purchased.map((p) => p.productID).toList(),
        hasError: false,
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
