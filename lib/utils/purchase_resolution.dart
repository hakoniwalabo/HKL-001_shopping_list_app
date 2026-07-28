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
