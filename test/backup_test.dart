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

  group('DatabaseHelper.normalizeImportedPrice', () {
    test('正の整数はそのまま返す', () {
      expect(DatabaseHelper.normalizeImportedPrice(150), 150);
    });

    test('0は0を返す', () {
      expect(DatabaseHelper.normalizeImportedPrice(0), 0);
    });

    test('負数は0にする', () {
      expect(DatabaseHelper.normalizeImportedPrice(-100), 0);
    });

    test('nullは0にする', () {
      expect(DatabaseHelper.normalizeImportedPrice(null), 0);
    });

    test('文字列は0にする', () {
      expect(DatabaseHelper.normalizeImportedPrice('abc'), 0);
      expect(DatabaseHelper.normalizeImportedPrice('100'), 0);
    });

    test('小数は切り捨てる', () {
      expect(DatabaseHelper.normalizeImportedPrice(99.9), 99);
      expect(DatabaseHelper.normalizeImportedPrice(100.0), 100);
    });

    test('NaN・無限大は0にする', () {
      expect(DatabaseHelper.normalizeImportedPrice(double.nan), 0);
      expect(DatabaseHelper.normalizeImportedPrice(double.infinity), 0);
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

    test('version が 1 でも 2 でもない整数で unsupported_version を投げる', () {
      const json =
          '{"version":3,"exportedAt":1234,"lists":[],"items":[],"favorites":[]}';
      expect(
        () => BackupService.parseAndValidate(json),
        throwsA(predicate<FormatException>(
          (e) => e.message == 'unsupported_version',
        )),
      );
    });

    test('version が文字列の場合は invalid_json を投げる', () {
      const json =
          '{"version":"1","exportedAt":1234,"lists":[],"items":[],"favorites":[]}';
      expect(
        () => BackupService.parseAndValidate(json),
        throwsA(predicate<FormatException>(
          (e) => e.message == 'invalid_json',
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

  group('BackupService.parseAndValidate version:2', () {
    test('version:2 の正常な JSON をパースして返す', () {
      const json =
          '{"version":2,"exportedAt":1234,"categories":[],"lists":[],"items":[],"favorites":[]}';
      final result = BackupService.parseAndValidate(json);
      expect(result['version'], 2);
      expect(result['categories'], isA<List>());
    });

    test('version:1 は引き続き受け入れる（後方互換）', () {
      const json =
          '{"version":1,"exportedAt":1234,"lists":[],"items":[],"favorites":[]}';
      final result = BackupService.parseAndValidate(json);
      expect(result['version'], 1);
    });

    test('version:3 は unsupported_version を投げる', () {
      const json =
          '{"version":3,"exportedAt":1234,"categories":[],"lists":[],"items":[],"favorites":[]}';
      expect(
        () => BackupService.parseAndValidate(json),
        throwsA(predicate<FormatException>(
          (e) => e.message == 'unsupported_version',
        )),
      );
    });

    test('version:2 で categories キーが欠けると invalid_json を投げる', () {
      const json =
          '{"version":2,"exportedAt":1234,"lists":[],"items":[],"favorites":[]}';
      expect(
        () => BackupService.parseAndValidate(json),
        throwsA(predicate<FormatException>(
          (e) => e.message == 'invalid_json',
        )),
      );
    });
  });

  group('BackupService.sanitizeFileName', () {
    test('通常の名前はそのまま返す', () {
      expect(BackupService.sanitizeFileName('週末の買い物'), '週末の買い物');
    });

    test('ファイル名禁止文字を _ に置換する', () {
      expect(BackupService.sanitizeFileName('a/b:c*d?e"f<g>h|i\\j'),
          'a_b_c_d_e_f_g_h_i_j');
    });

    test('前後の空白とドットを除去する', () {
      expect(BackupService.sanitizeFileName('  .買い物.  '), '買い物');
    });

    test('空または禁止文字のみの場合は list を返す', () {
      expect(BackupService.sanitizeFileName('   '), 'list');
      expect(BackupService.sanitizeFileName('///'), 'list');
    });

    test('50文字を超える場合は切り詰める', () {
      final long = 'あ' * 60;
      expect(BackupService.sanitizeFileName(long).length, 50);
    });
  });

  group('BackupService.buildExportMap', () {
    test('version:2 と各セクションを格納する', () {
      final map = BackupService.buildExportMap(
        categories: [{'id': 1, 'name': '野菜', 'sortOrder': 0, 'createdAt': 100}],
        lists: [{'id': 1, 'name': 'A', 'createdAt': 100}],
        items: [{'id': 1, 'name': '牛乳', 'listId': 1}],
        favorites: [],
        exportedAt: 12345,
      );
      expect(map['version'], 2);
      expect(map['exportedAt'], 12345);
      expect((map['categories'] as List).length, 1);
      expect((map['lists'] as List).length, 1);
      expect((map['items'] as List).length, 1);
      expect((map['favorites'] as List).isEmpty, true);
    });
  });
}
