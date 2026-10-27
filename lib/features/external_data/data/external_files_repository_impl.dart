import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/platform_info.dart';
import '../domain/external_files_repository.dart';
import '../domain/linked_file_status.dart';
import 'external_file_validator.dart';

class ExternalFilesRepositoryImpl implements ExternalFilesRepository {
  ExternalFilesRepositoryImpl(
    this._prefs, [
    this._validator = const ExternalFileValidator(),
    this._platform = const PlatformInfo(),
  ]);

  final SharedPreferences _prefs;
  final ExternalFileValidator _validator;
  final PlatformInfo _platform;

  static const _modelKey = 'external_model_path';
  static const _knowledgeKey = 'external_knowledge_path';

  @override
  String? get modelPath => _prefs.getString(_modelKey);

  @override
  String? get knowledgePath => _prefs.getString(_knowledgeKey);

  @override
  Future<void> setModelPath(String? path) => _set(_modelKey, path);

  @override
  Future<void> setKnowledgePath(String? path) => _set(_knowledgeKey, path);

  Future<void> _set(String key, String? path) async {
    if (path == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, path);
    }
  }

  @override
  Future<LinkedFilesStatus> check() async {
    final results = await Future.wait([
      _validator.validateModel(modelPath),
      _validator.validateKnowledge(knowledgePath),
    ]);
    return LinkedFilesStatus(
      model: results[0],
      knowledge: results[1] as KnowledgeDbStatus,
    );
  }

  @override
  Future<List<String>> appStorageDirs() async {
    if (!Platform.isAndroid) {
      final dir = await getApplicationSupportDirectory();
      return [dir.path];
    }
    // Una por volumen: memoria interna y tarjeta SD. No piden permisos.
    final dirs = await getExternalStorageDirectories() ?? const <Directory>[];
    return [for (final d in dirs) d.path];
  }

  @override
  Future<List<DiscoveredFile>> discover({required List<String> extensions}) async {
    final found = <DiscoveredFile>[];
    for (final root in await appStorageDirs()) {
      try {
        await for (final e in Directory(root).list(followLinks: false)) {
          if (e is! File) continue;
          if (extensions.contains(p.extension(e.path).toLowerCase())) {
            found.add(DiscoveredFile(path: e.path, sizeBytes: await e.length()));
          }
        }
      } on FileSystemException {
        // Volumen no disponible (SD extraida): se ignora.
      }
    }
    found.sort((a, b) => a.path.compareTo(b.path));
    return found;
  }

  @override
  Future<List<String>> browseRoots() async {
    final roots = <String>[...await appStorageDirs()];
    if (Platform.isAndroid) {
      final sdk = await _platform.androidSdkInt();
      // Fuera de las carpetas de la app solo se puede listar en Android 11+
      // con "Acceso a todos los archivos".
      if (sdk >= 30 && await hasAllFilesAccess) {
        roots.add('/storage/emulated/0');
        try {
          await for (final e in Directory('/storage').list()) {
            final name = p.basename(e.path);
            if (e is Directory && name != 'emulated' && name != 'self') {
              roots.add(e.path);
            }
          }
        } on FileSystemException {
          // Sin acceso a /storage.
        }
      }
    }
    return roots;
  }

  @override
  Future<bool> get needsAllFilesAccess async =>
      Platform.isAndroid && await _platform.androidSdkInt() >= 30;

  @override
  Future<bool> get hasAllFilesAccess async {
    if (!await needsAllFilesAccess) return true;
    return _platform.hasAllFilesAccess();
  }

  @override
  Future<void> requestAllFilesAccess() async {
    if (!await needsAllFilesAccess) return;
    await _platform.requestAllFilesAccess();
  }
}
