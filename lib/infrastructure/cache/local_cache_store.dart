import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalCacheStore {
  LocalCacheStore({String folderName = 'fidel_cache'})
    : _folderName = folderName;

  final String _folderName;

  Future<Map<String, dynamic>?> readMap(String key) async {
    try {
      final file = await _fileForKey(key);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    final file = await _fileForKey(key);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final tmp = File('${file.path}.tmp');
    final payload = jsonEncode(value);
    await tmp.writeAsString(payload, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
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
