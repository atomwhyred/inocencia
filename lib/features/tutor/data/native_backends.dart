import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Carga la variante de CPU de llama.cpp que mejor encaja con este telefono.
///
/// En Android `libggml` se compila con varias variantes (`libggml-cpu-android_*`:
/// armv8.0 base, dotprod, fp16, i8mm, SVE...). Cada una puntua en funcion de las
/// instrucciones que la CPU anuncia y ggml carga la de mayor puntuacion, de modo
/// que un mismo APK es seguro en un Cortex-A53 y rapido en un Tensor reciente.
/// `llama_cpp_dart` no hace esta llamada, y sin ella no hay ningun backend.
class NativeBackends {
  const NativeBackends._();

  static bool _loaded = false;

  /// `libggml-cpu-*.so` que trae la app y lo que llama.cpp ve de la CPU tras
  /// cargar la mejor variante (para el diagnostico de la zona de padres).
  static List<String> variants = const [];
  static String? cpuFeatures;

  /// Si se cargo la variante compatible (sin SVE/SME) en lugar de la mejor.
  static bool compat = false;

  /// Variantes sin SVE ni SME, de la mejor a la mas basica. Para chips en los que
  /// las rutas SVE/SME de ggml vayan mas lentas que NEON (sospecha en el Dimensity 9500).
  static const compatVariants = [
    'libggml-cpu-android_armv8.6_1.so',
    'libggml-cpu-android_armv8.2_2.so',
    'libggml-cpu-android_armv8.2_1.so',
  ];

  /// Idempotente (la variante queda fijada hasta reiniciar la app). [libraryDir]
  /// es la `nativeLibraryDir` de Android; fuera de Android (o sin variantes) no
  /// hace nada. Con [compat] carga la mejor de [compatVariants] que exista.
  static void loadCpuVariant(String? libraryDir, {bool compat = false}) {
    if (_loaded || libraryDir == null || !Platform.isAndroid) return;
    final dir = libraryDir.toNativeUtf8();
    try {
      final ggml = DynamicLibrary.open('libggml.so');
      final forced = compat ? _loadCompat(ggml, libraryDir) : null;
      if (forced == null) {
        final loadAll = ggml
            .lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>(
              'ggml_backend_load_all_from_path',
            );
        loadAll(dir);
      }
      NativeBackends.compat = forced != null;
      _loaded = true;
      variants =
          Directory(libraryDir)
              .listSync()
              .map((f) => f.path.split('/').last)
              .where((n) => n.startsWith('libggml-cpu'))
              .toList()
            ..sort();
      debugPrint('[tutor] variantes de CPU en la app: $variants');
      cpuFeatures = _systemInfo();
      debugPrint('[tutor] CPU segun llama.cpp: $cpuFeatures');
    } catch (e) {
      cpuFeatures = 'ERROR al cargar las variantes: $e';
      debugPrint(
        '[tutor] AVISO: no se pudieron cargar las variantes de CPU ($e); '
        'el tutor ira mas lento',
      );
    } finally {
      malloc.free(dir);
    }
  }

  /// Registra una variante concreta con `ggml_backend_load`. Devuelve su nombre,
  /// o null si no hay ninguna compatible (entonces se cargan todas como siempre).
  static String? _loadCompat(DynamicLibrary ggml, String libraryDir) {
    final load = ggml.lookupFunction<Pointer<Void> Function(Pointer<Utf8>), Pointer<Void> Function(Pointer<Utf8>)>(
      'ggml_backend_load',
    );
    for (final name in compatVariants) {
      final path = '$libraryDir/$name';
      if (!File(path).existsSync()) continue;
      final p = path.toNativeUtf8();
      try {
        if (load(p) != nullptr) {
          debugPrint('[tutor] CPU en modo compatible: $name');
          return name;
        }
      } finally {
        malloc.free(p);
      }
    }
    return null;
  }

  /// Funciones de CPU que llama.cpp ve ahora (NEON, SVE, i8mm...): dice que
  /// variante se cargo de verdad.
  static String _systemInfo() {
    try {
      final info = DynamicLibrary.open('libllama.so')
          .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
            'llama_print_system_info',
          );
      return info().toDartString().trim();
    } catch (e) {
      return 'no disponible ($e)';
    }
  }
}
