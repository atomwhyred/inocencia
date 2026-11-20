import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';

/// Si un modelo o una base de libros es uno de los que se publican (canal, GitHub).
enum FileIntegrity {
  /// Coincide byte a byte con un archivo publicado.
  official,

  /// No coincide: puede ser otra versión, otro modelo o un archivo modificado.
  unknown,
}

/// Un archivo publicado: `assets/official/official_files.json` (lo genera
/// `tools/official_files.py`).
class OfficialFile {
  const OfficialFile({required this.name, required this.size, required this.sha256});

  final String name;
  final int size;
  final String sha256;

  static List<OfficialFile> parse(String json) {
    final root = jsonDecode(json) as Map<String, Object?>;
    return [
      for (final e in root['files']! as List)
        OfficialFile(
          name: (e as Map)['name'] as String,
          size: e['size'] as int,
          sha256: (e['sha256'] as String).toLowerCase(),
        ),
    ];
  }
}

/// Comprueba archivos contra la lista oficial. Primero el tamaño (instantáneo): solo si
/// coincide con alguno publicado se calcula el SHA-256, en otro isolate porque un
/// modelo pesa GB. El resultado se guarda por ruta, tamaño y fecha para no repetirlo.
class FileIntegrityChecker {
  FileIntegrityChecker(this._prefs, this._official, {this.hasher = sha256OfFile});

  final SharedPreferences _prefs;
  final List<OfficialFile> _official;
  final Future<String> Function(String path) hasher;

  static const _prefix = 'sha256_cache:';

  Future<FileIntegrity> check(String path) async {
    final file = File(path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return FileIntegrity.unknown;
    final candidates = _official.where((o) => o.size == stat.size).toList();
    if (candidates.isEmpty) return FileIntegrity.unknown;

    final stamp = '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
    final key = '$_prefix$path';
    final cached = _prefs.getString(key);
    String? hash;
    if (cached != null && cached.startsWith('$stamp:')) {
      hash = cached.substring(stamp.length + 1);
    } else {
      hash = await hasher(path);
      await _prefs.setString(key, '$stamp:$hash');
    }
    return candidates.any((o) => o.sha256 == hash) ? FileIntegrity.official : FileIntegrity.unknown;
  }
}

/// SHA-256 de un archivo grande, leído por bloques en otro isolate.
Future<String> sha256OfFile(String path) => Isolate.run(() async {
  final out = _DigestSink();
  final input = sha256.startChunkedConversion(out);
  await for (final chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  return out.value!.toString();
});

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

final officialFilesProvider = FutureProvider<List<OfficialFile>>((ref) async {
  try {
    return OfficialFile.parse(await rootBundle.loadString('assets/official/official_files.json'));
  } catch (_) {
    return const [];
  }
});

/// Resultado para una ruta vinculada (se recalcula si cambia la ruta).
final fileIntegrityProvider = FutureProvider.autoDispose.family<FileIntegrity, String>((
  ref,
  path,
) async {
  final official = await ref.watch(officialFilesProvider.future);
  return FileIntegrityChecker(ref.watch(sharedPreferencesProvider), official).check(path);
});
