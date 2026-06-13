import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

class BackupService {
  /// 全データを JSON ファイルとして共有シートに渡す
  static Future<void> export() async {
    final helper = DatabaseHelper.instance;
    final lists = await helper.getLists();

    final allItems = <Map<String, dynamic>>[];
    for (final list in lists) {
      final items = await helper.getItemsByListId(list.id!);
      allItems.addAll(items.map((i) => i.toMap()));
    }

    final favorites = await helper.getFavorites();

    final now = DateTime.now();
    final data = {
      'version': 1,
      'exportedAt': now.millisecondsSinceEpoch,
      'lists': lists.map((l) => l.toMap()).toList(),
      'items': allItems,
      'favorites': favorites,
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final fileName = 'shopping_backup_'
        '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '買い物リスト バックアップ',
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// ファイルを選択してマージインポート。キャンセル時は null を返す。
  /// FormatException: 'invalid_json' または 'unsupported_version' を投げる可能性あり
  static Future<ImportResult?> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    final data = parseAndValidate(content);
    return await DatabaseHelper.instance.importData(data);
  }

  /// JSON 文字列をパースしてバリデーション済み Map を返す。
  /// 不正な場合は FormatException を投げる。
  static Map<String, dynamic> parseAndValidate(String content) {
    late Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('invalid_json');
    }
    if (data['version'] is! int) {
      throw const FormatException('invalid_json');
    }
    if (data['version'] != 1) {
      throw const FormatException('unsupported_version');
    }
    if (data['lists'] is! List ||
        data['items'] is! List ||
        data['favorites'] is! List) {
      throw const FormatException('invalid_json');
    }
    return data;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
