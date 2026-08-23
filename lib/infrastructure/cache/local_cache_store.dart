import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';

class LocalCacheStore {
  LocalCacheStore({String folderName = 'fidel_cache'})
    : _folderName = folderName;

  final String _folderName;

  Future<Map<String, dynamic>?> readMap(String key) async {
    File? file;
    try {
      file = await _fileForKey(key);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } on FormatException catch (e, st) {
      AppLog.warn(
        'Quarantining corrupt cache file for "$key"',
        error: e,
        stackTrace: st,
      );
      try {
        await file?.delete();
      } catch (_) {}
      return null;
    } catch (e, st) {
      AppLog.warn('Cache read failed for "$key"', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    try {
      final file = await _fileForKey(key);
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      // Unique tmp name so concurrent writers cannot clobber each other's
      // staging file.
      final tmp = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      final payload = jsonEncode(value);
      await tmp.writeAsString(payload, flush: true);
      try {
        await tmp.rename(file.path);
      } on FileSystemException {
        // Some platforms (notably Windows) refuse to rename onto an
        // existing file. Copy-overwrite keeps the previous payload intact
        // if we crash mid-way, unlike delete-then-rename.
        await tmp.copy(file.path);
        await tmp.delete();
      }
    } catch (e, st) {
      AppLog.warn('Cache write failed for "$key"', error: e, stackTrace: st);
    }
  }

  Future<File> _fileForKey(String key) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(_join(dir.path, _folderName));
    final fileName = '${_sanitizeKey(key)}.json';
    return File(_join(folder.path, fileName));
  }

  String _join(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    final sep = Platform.pathSeparator;
    if (a.endsWith(sep)) return '$a$b';
    return '$a$sep$b';
  }

  String _sanitizeKey(String key) {
    final normalized = key.trim().toLowerCase();
    final buf = StringBuffer();
    for (final codeUnit in normalized.codeUnits) {
      final c = String.fromCharCode(codeUnit);
      final isAlphaNum =
          (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 97 && codeUnit <= 122);
      buf.write(isAlphaNum ? c : '_');
    }
    return buf.toString();
  }
}
