import 'package:test/test.dart';
import 'package:shopping_list_app/models/item.dart';

void main() {
  // --------------------------------------------------------
  // Item モデル
  // --------------------------------------------------------
  group('Item モデル', () {
    final baseItem = Item(
      id: 1,
      name: '牛乳',
      price: 200,
      taxRate: 0.08,
      quantity: 2,
      memo: 'メモ',
      listId: 1,
      sortOrder: 0,
    );

    test('toMap / fromMap ラウンドトリップ', () {
      final map = baseItem.toMap();
      final restored = Item.fromMap(map);

      expect(restored.id, baseItem.id);
      expect(restored.name, baseItem.name);
      expect(restored.price, baseItem.price);
      expect(restored.taxRate, baseItem.taxRate);
      expect(restored.quantity, baseItem.quantity);
      expect(restored.memo, baseItem.memo);
      expect(restored.listId, baseItem.listId);
      expect(restored.isChecked, baseItem.isChecked);
    });

    test('copyWith: 指定フィールドのみ更新される', () {
      final updated = baseItem.copyWith(name: '豆乳', price: 300);

      expect(updated.name, '豆乳');
      expect(updated.price, 300);
      // 変更していないフィールドは元の値を保持
      expect(updated.taxRate, baseItem.taxRate);
      expect(updated.quantity, baseItem.quantity);
      expect(updated.id, baseItem.id);
    });

    test('isChecked のデフォルト値は false', () {
      final item = Item(
        name: 'テスト',
        price: 100,
        taxRate: 0.10,
        quantity: 1,
        listId: 1,
      );
      expect(item.isChecked, false);
    });

    test('isChecked が toMap / fromMap で正しく変換される', () {
      final checked = baseItem.copyWith(isChecked: true);
      expect(checked.toMap()['isChecked'], 1);
      expect(Item.fromMap(checked.toMap()).isChecked, true);

      final unchecked = baseItem.copyWith(isChecked: false);
      expect(unchecked.toMap()['isChecked'], 0);
      expect(Item.fromMap(unchecked.toMap()).isChecked, false);
    });
  });

  // --------------------------------------------------------
  // 合計計算（設計書 §8.8 の計算式を検証）
  // --------------------------------------------------------
  group('合計計算', () {
    double taxIncluded(Item item) =>
        item.price * item.quantity * (1 + item.taxRate);

    int taxExcluded(Item item) => item.price * item.quantity;

    test('税込: price × quantity × (1 + taxRate)', () {
      final item = Item(
          name: 'りんご', price: 100, taxRate: 0.10, quantity: 3, listId: 1);
      // 100 × 3 × 1.10 = 330.0
      expect(taxIncluded(item), 330.0);
    });

    test('税別: price × quantity', () {
      final item = Item(
          name: 'りんご', price: 100, taxRate: 0.10, quantity: 3, listId: 1);
      // 100 × 3 = 300
      expect(taxExcluded(item), 300);
    });

    test('taxRate 0.08 (軽減税率) の税込計算', () {
      final item = Item(
          name: '牛乳', price: 200, taxRate: 0.08, quantity: 2, listId: 1);
      // 200 × 2 × 1.08 = 432.0
      expect(taxIncluded(item), closeTo(432.0, 0.01));
    });

    test('税率 0 のとき税込 = 税別', () {
      final item = Item(
          name: '無税品', price: 500, taxRate: 0.0, quantity: 1, listId: 1);
      expect(taxIncluded(item), taxExcluded(item).toDouble());
    });

    test('複数商品の合計', () {
      final items = [
        Item(name: 'A', price: 100, taxRate: 0.10, quantity: 2, listId: 1),
        Item(name: 'B', price: 200, taxRate: 0.08, quantity: 1, listId: 1),
      ];
      final total = items.fold<double>(
        0,
        (sum, e) => sum + e.price * e.quantity * (1 + e.taxRate),
      );
      // (100×2×1.10) + (200×1×1.08) = 220 + 216 = 436.0
      expect(total, closeTo(436.0, 0.01));
    });
  });

  // --------------------------------------------------------
  // sortOrder 採番ルール（設計書 §12）
  // --------------------------------------------------------
  group('sortOrder 採番', () {
    test('リストが空のとき sortOrder は 0 から始まる', () {
      final List<Item> current = [];
      final next = current.isEmpty
          ? 0
          : current.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) +
                1;
      expect(next, 0);
    });

    test('既存アイテムがある場合は MAX(sortOrder) + 1', () {
      final current = [
        Item(name: 'A', price: 0, taxRate: 0, quantity: 1, listId: 1,
            sortOrder: 0),
        Item(name: 'B', price: 0, taxRate: 0, quantity: 1, listId: 1,
            sortOrder: 2),
        Item(name: 'C', price: 0, taxRate: 0, quantity: 1, listId: 1,
            sortOrder: 1),
      ];
      final next =
          current.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      expect(next, 3);
    });
  });
}
