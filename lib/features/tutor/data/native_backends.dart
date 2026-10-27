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

  /// Idempotente. [libraryDir] es la `nativeLibraryDir` de Android; fuera de
  /// Android (o sin variantes) no hace nada.
  static void loadCpuVariant(String? libraryDir) {
    if (_loaded || libraryDir == null || !Platform.isAndroid) return;
    final dir = libraryDir.toNativeUtf8();
    try {
      final loadAll = DynamicLibrary.open('libggml.so').lookupFunction<
          Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>('ggml_backend_load_all_from_path');
      loadAll(dir);
      _loaded = true;
    } catch (e) {
      debugPrint('[tutor] no se pudieron cargar las variantes de CPU: $e');
    } finally {
      malloc.free(dir);
    }
  }
}
