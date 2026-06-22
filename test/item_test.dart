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
      expect(updated.quantity, baseItem.quantity);
      expect(updated.id, baseItem.id);
    });

    test('isChecked のデフォルト値は false', () {
      final item = Item(
        name: 'テスト',
        price: 100,
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
  // price は税込単価として保存。合計 = sum(price × quantity)
  // --------------------------------------------------------
  group('合計計算', () {
    int total(List<Item> items) =>
        items.fold(0, (s, e) => s + e.price * e.quantity);

    test('税込合計: price × quantity', () {
      // 税込110円 × 3個 = 330円
      final item = Item(
          name: 'りんご', price: 110, quantity: 3, listId: 1);
      expect(total([item]), 330);
    });

    test('合計は price × quantity のみ', () {
      final item = Item(
          name: '商品', price: 500, quantity: 1, listId: 1);
      expect(total([item]), 500);
    });

    test('複数商品の税込合計', () {
      final items = [
        Item(name: 'A', price: 110, quantity: 2, listId: 1),
        Item(name: 'B', price: 216, quantity: 1, listId: 1),
      ];
      // (110×2) + (216×1) = 220 + 216 = 436
      expect(total(items), 436);
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
        Item(name: 'A', price: 0, quantity: 1, listId: 1, sortOrder: 0),
        Item(name: 'B', price: 0, quantity: 1, listId: 1, sortOrder: 2),
        Item(name: 'C', price: 0, quantity: 1, listId: 1, sortOrder: 1),
      ];
      final next =
          current.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      expect(next, 3);
    });
  });

  // --------------------------------------------------------
  // Item categoryId
  // --------------------------------------------------------
  group('Item categoryId', () {
    test('categoryId が null の場合 fromMap で null になる', () {
      final map = {
        'id': 1, 'name': '牛乳', 'price': 198, 'isChecked': 0,
        'createdAt': 1700000000000, 'sortOrder': 0,
        'quantity': 1, 'memo': '', 'listId': 1,
        'categoryId': null,
      };
      final item = Item.fromMap(map);
      expect(item.categoryId, isNull);
    });

    test('categoryId が設定されている場合 fromMap で値が取れる', () {
      final map = {
        'id': 1, 'name': '牛乳', 'price': 198, 'isChecked': 0,
        'createdAt': 1700000000000, 'sortOrder': 0,
        'quantity': 1, 'memo': '', 'listId': 1,
        'categoryId': 3,
      };
      final item = Item.fromMap(map);
      expect(item.categoryId, 3);
    });

    test('copyWith で categoryId を更新できる', () {
      final item = Item(name: '卵', price: 248, listId: 1, categoryId: 1);
      final updated = item.copyWith(categoryId: 2);
      expect(updated.categoryId, 2);
      expect(updated.name, '卵');
    });

    test('copyWith でカテゴリを null にクリアできる', () {
      final item = Item(name: '卵', price: 248, listId: 1, categoryId: 1);
      final cleared = item.copyWithNullableCategory(categoryId: null);
      expect(cleared.categoryId, isNull);
    });
  });
}
