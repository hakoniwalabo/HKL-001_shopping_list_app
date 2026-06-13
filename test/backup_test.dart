import 'package:test/test.dart';
import 'package:shopping_list_app/database/database_helper.dart';

void main() {
  group('DatabaseHelper.resolveListName', () {
    test('重複しない名前はそのまま返す', () {
      final names = <String>{'リストA', 'リストB'};
      expect(DatabaseHelper.resolveListName('リストC', names), 'リストC');
    });

    test('重複する名前に(2)を付与', () {
      final names = <String>{'買い物リスト'};
      expect(DatabaseHelper.resolveListName('買い物リスト', names), '買い物リスト(2)');
    });

    test('(2)も重複する場合は(3)を付与', () {
      final names = <String>{'買い物リスト', '買い物リスト(2)'};
      expect(DatabaseHelper.resolveListName('買い物リスト', names), '買い物リスト(3)');
    });

    test('空のセットでは名前をそのまま返す', () {
      expect(DatabaseHelper.resolveListName('買い物リスト', {}), '買い物リスト');
    });
  });
}
