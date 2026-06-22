import 'package:test/test.dart';
import 'package:shopping_list_app/models/category.dart';

void main() {
  group('Category.fromMap / toMap', () {
    test('fromMap が各フィールドを正しく変換する', () {
      final map = {
        'id': 1,
        'name': '野菜',
        'sortOrder': 0,
        'createdAt': 1700000000000,
      };
      final cat = Category.fromMap(map);
      expect(cat.id, 1);
      expect(cat.name, '野菜');
      expect(cat.sortOrder, 0);
      expect(cat.createdAt, 1700000000000);
    });

    test('toMap が id を含む Map を返す', () {
      final cat = Category(id: 2, name: '肉', sortOrder: 1, createdAt: 1700000001000);
      final map = cat.toMap();
      expect(map['id'], 2);
      expect(map['name'], '肉');
      expect(map['sortOrder'], 1);
    });

    test('id が null の場合も toMap が動作する', () {
      final cat = Category(name: '日用品', sortOrder: 2, createdAt: 1700000002000);
      final map = cat.toMap();
      expect(map['id'], isNull);
      expect(map['name'], '日用品');
    });
  });
}
