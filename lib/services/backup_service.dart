import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

class BackupService {
  /// リスト名をファイル名として安全な文字列へ変換する。
  /// 禁止文字を _ に置換し、前後の空白・ドットを除去。空になる場合は 'list'。
  static String sanitizeFileName(String name) {
    final replaced = name.replaceAll(RegExp(r'[\/\\:*?"<>|\x00-\x1F]'), '_');
    final trimmed = replaced.replaceAll(RegExp(r'^[\s._]+|[\s._]+$'), '');
    final base = trimmed.isEmpty ? 'list' : trimmed;
    return base.length > 50 ? base.substring(0, 50) : base;
  }

  /// version:1 エクスポート Map を構築する（純粋関数）。
  static Map<String, dynamic> buildExportMap({
    required List<Map<String, dynamic>> lists,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> favorites,
    required int exportedAt,
  }) {
    return {
      'version': 1,
      'exportedAt': exportedAt,
      'lists': lists,
      'items': items,
      'favorites': favorites,
    };
  }

  /// 全データを version:1 JSON 文字列に変換する。
  static Future<String> _buildFullBackupJson() async {
    final helper = DatabaseHelper.instance;
    final lists = await helper.getLists();

    final allItems = <Map<String, dynamic>>[];
    for (final list in lists) {
      final items = await helper.getItemsByListId(list.id!);
      allItems.addAll(items.map((i) => i.toMap()));
    }
    final favorites = await helper.getFavorites();

    final map = buildExportMap(
      lists: lists.map((l) => l.toMap()).toList(),
      items: allItems,
      favorites: favorites,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
    );
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// バックアップ用のファイル名を生成する。
  static String _backupFileName() {
    final now = DateTime.now();
    return 'shopping_backup_'
        '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.json';
  }

  /// 全データを JSON ファイルとして共有シートに渡す
  static Future<void> export() async {
    final json = await _buildFullBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_backupFileName()}');
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
