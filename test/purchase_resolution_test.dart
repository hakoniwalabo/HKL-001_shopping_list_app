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
