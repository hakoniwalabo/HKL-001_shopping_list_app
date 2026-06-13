import 'package:test/test.dart';
import 'package:shopping_list_app/database/database_helper.dart';
import 'package:shopping_list_app/services/backup_service.dart';

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

  group('BackupService.parseAndValidate', () {
    test('正常なJSONをパースして返す', () {
      const json =
          '{"version":1,"exportedAt":1234,"lists":[],"items":[],"favorites":[]}';
      final result = BackupService.parseAndValidate(json);
      expect(result['version'], 1);
    });

    test('不正なJSONでFormatExceptionを投げる', () {
      expect(
        () => BackupService.parseAndValidate('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('version が 1 以外で unsupported_version を投げる', () {
      const json =
          '{"version":2,"exportedAt":1234,"lists":[],"items":[],"favorites":[]}';
      expect(
        () => BackupService.parseAndValidate(json),
        throwsA(predicate<FormatException>(
          (e) => e.message == 'unsupported_version',
        )),
      );
    });

    test('必須キーが欠けると invalid_json を投げる', () {
      const json = '{"version":1,"exportedAt":1234,"lists":[]}';
      expect(
        () => BackupService.parseAndValidate(json),
        throwsA(predicate<FormatException>(
          (e) => e.message == 'invalid_json',
        )),
      );
    });
  });
}
