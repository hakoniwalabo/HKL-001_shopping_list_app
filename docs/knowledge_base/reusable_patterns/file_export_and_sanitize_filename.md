**カテゴリ**: reusable_patterns　**由来**: lib/services/backup_service.dart（HKL-001, 基準コミット b818605）

---

# ファイルエクスポート＆ファイル名サニタイズの実装パターン

## 1. `sanitizeFileName()` — ファイル名サニタイズ関数

任意の文字列を、ファイル名として安全な文字列へ変換する純粋関数。以下の処理を行う。

- 禁止文字（`/ \ : * ? " < > |`および制御文字`\x00-\x1F`）を`_`に置換する。
- 置換後の文字列の前後にある空白・ドット・アンダースコアを除去する（Windowsではファイル名の末尾にドット・空白があると問題になりやすいため）。
- 除去した結果が空文字列になった場合はフォールバック文字列（元実装では`'list'`）を使う。
- 50文字を超える場合は先頭50文字に丸める。

買い物リストのスキーマには一切依存しない純粋関数のため、原則そのまま転記できる。

```dart
/// 文字列をファイル名として安全な文字列へ変換する。
/// 禁止文字を _ に置換し、前後の空白・ドットを除去。空になる場合は fallback（既定 'file'）。
String sanitizeFileName(String name, {String fallback = 'file'}) {
  final replaced = name.replaceAll(RegExp(r'[\/\\:*?"<>|\x00-\x1F]'), '_');
  final trimmed = replaced.replaceAll(RegExp(r'^[\s._]+|[\s._]+$'), '');
  final base = trimmed.isEmpty ? fallback : trimmed;
  return base.length > 50 ? base.substring(0, 50) : base;
}
```

※元実装（`BackupService.sanitizeFileName()`）はフォールバック文字列が`'list'`固定のstaticメソッドだが、汎用版では他ドメインでも使えるよう`fallback`を任意引数化した。ロジック本体（禁止文字の置換・トリム・50文字丸め）は完全に同一である。

## 2. `export()` / `saveToDevice()` のI/O骨格

元実装の`export()`・`saveToDevice()`は、いずれも次の流れを持つ。

1. エクスポート対象のコンテンツ文字列（JSON等）を組み立てる（この部分はドメイン依存でありコピー対象外）。
2. `export()`：`path_provider`の`getTemporaryDirectory()`で一時ディレクトリを取得し、そこにファイルを書き出す（`file.writeAsString()`）。
3. `share_plus`の`Share.shareXFiles()`で共有シートにファイルを渡す。
4. `finally`ブロックで、共有完了・キャンセルいずれの場合も一時ファイルを削除する（後始末）。
5. `saveToDevice()`：コンテンツをバイト列（`utf8.encode()`）に変換し、`file_picker`の`FilePicker.platform.saveFile()`で端末への直接保存（Androidの場合はStorage Access Framework経由）を行う。保存の成否は戻り値のパスが`null`かどうかで判定する。

この「コンテンツ文字列→一時ファイル化→共有シート／端末保存→後始末」という骨格自体は、JSONの中身（買い物リストのスキーマ）に依存しない。

## 3. 汎用化版

コンテンツ文字列とファイル名を渡すと、一時ファイル化して共有シートに渡す／端末に保存する汎用関数。買い物リスト固有のJSON構築部分（`buildExportMap()`・`_buildFullBackupJson()`）は含めていない。

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 任意のコンテンツ文字列をファイル名として安全な文字列へ変換する。
/// 禁止文字を _ に置換し、前後の空白・ドットを除去。空になる場合は fallback（既定 'file'）。
String sanitizeFileName(String name, {String fallback = 'file'}) {
  final replaced = name.replaceAll(RegExp(r'[\/\\:*?"<>|\x00-\x1F]'), '_');
  final trimmed = replaced.replaceAll(RegExp(r'^[\s._]+|[\s._]+$'), '');
  final base = trimmed.isEmpty ? fallback : trimmed;
  return base.length > 50 ? base.substring(0, 50) : base;
}

/// 任意のコンテンツ文字列を一時ファイル化し、共有シートに渡す。
/// 共有完了後（またはキャンセル後）に一時ファイルを削除する。
/// 渡された fileName は内部で必ず sanitizeFileName() を通してからパスを組み立てる
/// （パストラバーサル対策。`../` 等を含む文字列がそのまま渡されると、一時ディレクトリ外への
/// 書き込み・finally節での意図しない外部ファイル削除が起こりうるため）。
Future<void> exportContentToShare(
  String content,
  String fileName, {
  String? subject,
}) async {
  final safeName = sanitizeFileName(fileName);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$safeName');
  await file.writeAsString(content);

  try {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
    );
  } finally {
    if (await file.exists()) await file.delete();
  }
}

/// 任意のコンテンツ文字列を端末に保存する（file_picker saveFile / Android は SAF）。
/// 保存した場合 true、キャンセルは false を返す。
///
/// - `dialogTitle` はローカライズ対象の文字列のため既定値を持たない必須引数とした。
///   呼び出し側で必ずローカライズ済みの文字列を渡すこと。
/// - `type: FileType.custom` を固定しているため、拡張子を問わない用途で
///   `allowedExtensions` に空リストを渡すと file_picker 側で例外になる。
///   拡張子を制約しない場合は `type: FileType.any` に切り替えること。
/// - `bytes` を渡して保存が完了するのは Android/iOS の挙動であり、
///   デスクトップ（Windows/macOS/Linux）では戻り値のパスへ自前でファイル書き込みが必要になる。
Future<bool> saveContentToDevice(
  String content,
  String fileName, {
  required String dialogTitle,
  List<String> allowedExtensions = const ['json'],
}) async {
  final safeName = sanitizeFileName(fileName);
  final bytes = Uint8List.fromList(utf8.encode(content));
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: safeName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    bytes: bytes,
  );
  return path != null;
}
```

## 4. 利用方法

新プロジェクトでは、エクスポート対象のコンテンツ文字列（JSON・CSV・テキスト等、ドメインごとに組み立てたもの）とファイル名を用意し、上記関数へ渡す。`dialogTitle`は必須引数のため、呼び出し側で必ずローカライズ済みの文字列を渡す（このパターン自体は特定の言語に固定しない）。

```dart
final content = jsonEncode(myExportMap); // 新プロジェクト固有のデータ組み立て
final fileName = 'mybackup_${sanitizeFileName(entryName)}_20260903.json';

// 共有シートへ渡す場合
await exportContentToShare(content, fileName, subject: 'バックアップ');

// 端末へ直接保存する場合（ローカライズ済み文字列を dialogTitle に渡す）
final saved = await saveContentToDevice(
  content,
  fileName,
  dialogTitle: l10n.saveDestinationDialogTitle,
);
```

拡張子を問わない用途（例：任意形式のテキストファイル出力）で`saveContentToDevice()`を使う場合は、`allowedExtensions`に空リストを渡すと`type: FileType.custom`との組み合わせでfile_picker側が例外を投げる。この用途では`type: FileType.any`に切り替える改修が必要になる。

`saveContentToDevice()`は`FilePicker.platform.saveFile()`に`bytes`を渡すことで保存まで完了する実装だが、これはAndroid/iOSの挙動である。デスクトップ（Windows/macOS/Linux）では`saveFile()`の戻り値は保存先パスのみで、そのパスへ呼び出し側が自前でファイル書き込み（`File(path).writeAsBytes(bytes)`等）を行う必要がある。

`pubspec.yaml`には`file_picker`・`path_provider`・`share_plus`の3パッケージが必要。

## 5. 検証済みバージョン

本パターンはHKL-001（`pubspec.yaml`）の以下のバージョンで動作確認済み。

- `file_picker: ^8.1.0`
- `path_provider: ^2.1.0`
- `share_plus: ^10.1.4`

`share_plus`は10系後半以降、`Share.shareXFiles()`が非推奨化され`SharePlus.instance.share(ShareParams(...))`への移行が進められている。新規プロジェクトで最新版の`share_plus`を導入する場合、本パターンの`exportContentToShare()`内の`Share.shareXFiles()`呼び出しが警告または非対応になる可能性があるため、導入時に最新のCHANGELOGを確認すること。
