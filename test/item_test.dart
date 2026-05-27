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
  // 合計計算（設計書 §8.8）
  // price は税込単価として保存:
  //   税込合計 = price × quantity
  //   税別合計 = price × quantity / (1 + taxRate)
  // --------------------------------------------------------
  group('合計計算', () {
    // TotalSummary と同じ計算式
    double taxIncluded(Item item) => item.price * item.quantity.toDouble();
    double taxExcluded(Item item) =>
        item.price * item.quantity / (1 + item.taxRate);

    test('税込: price × quantity（price は税込単価）', () {
      // 税込110円 × 3個 = 330円
      final item = Item(
          name: 'りんご', price: 110, taxRate: 0.10, quantity: 3, listId: 1);
      expect(taxIncluded(item), 330.0);
    });

    test('税別: price × quantity / (1 + taxRate)', () {
      // 税込110円 ÷ 1.10 × 3個 = 300円
      final item = Item(
          name: 'りんご', price: 110, taxRate: 0.10, quantity: 3, listId: 1);
      expect(taxExcluded(item), closeTo(300.0, 0.01));
    });

    test('taxRate 0.08（軽減税率）の税別計算', () {
      // 税込216円 ÷ 1.08 × 2個 = 400円
      final item = Item(
          name: '牛乳', price: 216, taxRate: 0.08, quantity: 2, listId: 1);
      expect(taxExcluded(item), closeTo(400.0, 0.01));
    });

    test('taxRate 0（追加時デフォルト）のとき税込 = 税別', () {
      // 追加時は taxRate=0.0 固定なので tax-in = tax-ex
      final item = Item(
          name: '無税品', price: 500, taxRate: 0.0, quantity: 1, listId: 1);
      expect(taxIncluded(item), taxExcluded(item));
    });

    test('複数商品の税込合計', () {
      final items = [
        Item(name: 'A', price: 110, taxRate: 0.10, quantity: 2, listId: 1),
        Item(name: 'B', price: 216, taxRate: 0.08, quantity: 1, listId: 1),
      ];
      final total =
          items.fold<double>(0, (sum, e) => sum + e.price * e.quantity);
      // (110×2) + (216×1) = 220 + 216 = 436
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
