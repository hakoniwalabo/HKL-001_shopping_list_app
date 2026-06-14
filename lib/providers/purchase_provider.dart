import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // ③ キャッシュが false のときだけ Play Store で照合
    if (!cached) {
      try {
        final available = await InAppPurchase.instance.isAvailable();
        if (available) await InAppPurchase.instance.restorePurchases();
      } catch (_) {}
    }

    return cached;
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

      final response = await InAppPurchase.instance
          .queryProductDetails({kRemoveAdsProductId});

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
