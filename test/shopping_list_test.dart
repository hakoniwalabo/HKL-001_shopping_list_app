import 'package:test/test.dart';
import 'package:shopping_list_app/models/shopping_list.dart';

void main() {
  group('ShoppingList モデル', () {
    test('toMap / fromMap ラウンドトリップ（budget含む）', () {
      final list = ShoppingList(
        id: 1,
        name: '買い物リスト',
        createdAt: 1700000000000,
        budget: 5000,
      );
      final map = list.toMap();
      final restored = ShoppingList.fromMap(map);

      expect(restored.id, list.id);
      expect(restored.name, list.name);
      expect(restored.createdAt, list.createdAt);
      expect(restored.budget, list.budget);
    });

    test('budget のデフォルト値は0', () {
      final list = ShoppingList(name: 'テストリスト', createdAt: 1700000000000);
      expect(list.budget, 0);
    });

    test('fromMap で budget キーが存在しない場合は0にフォールバックする', () {
      final map = {
        'id': 1,
        'name': 'テストリスト',
        'createdAt': 1700000000000,
      };
      final restored = ShoppingList.fromMap(map);
      expect(restored.budget, 0);
    });

    test('copyWith: budget のみ更新すると他のフィールドは元の値を保持する', () {
      final list = ShoppingList(
        id: 1,
        name: '買い物リスト',
        createdAt: 1700000000000,
        budget: 3000,
      );
      final updated = list.copyWith(budget: 8000);

      expect(updated.budget, 8000);
      expect(updated.id, list.id);
      expect(updated.name, list.name);
      expect(updated.createdAt, list.createdAt);
    });

    test('copyWith: name のみ更新すると budget は元の値を保持する', () {
      final list = ShoppingList(
        id: 1,
        name: '買い物リスト',
        createdAt: 1700000000000,
        budget: 3000,
      );
      final updated = list.copyWith(name: '新しいリスト名');

      expect(updated.name, '新しいリスト名');
      expect(updated.budget, 3000);
      expect(updated.id, list.id);
      expect(updated.createdAt, list.createdAt);
    });
  });
}
