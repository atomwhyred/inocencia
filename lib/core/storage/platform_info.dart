import 'dart:io';

import 'package:flutter/services.dart';

/// Datos y permisos de la plataforma que Dart no expone directamente
/// (implementado en `StorageBridge.kt`).
class PlatformInfo {
  const PlatformInfo();

  static const _channel = MethodChannel('com.inocencia.app/storage');

  /// Nivel de API de Android (29 = Android 10). Fuera de Android devuelve un
  /// valor alto: no hay restricciones de almacenamiento por alcance.
  Future<int> androidSdkInt() async {
    if (!Platform.isAndroid) return 99;
    try {
      return await _channel.invokeMethod<int>('sdkInt') ?? 29;
    } on PlatformException {
      return 29;
    } on MissingPluginException {
      return 29;
    }
  }

  /// Memoria RAM total del equipo en bytes (null si no se puede saber).
  Future<int?> totalRamBytes() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('totalRamBytes');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Carpeta donde Android extrae las `.so` de la app (null fuera de Android).
  Future<String?> nativeLibraryDir() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('nativeLibraryDir');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Estado termico de Android: 0 normal, 1 leve, 2 moderado, 3 grave, 4 critico,
  /// 5 emergencia, 6 apagado. Null fuera de Android o antes de Android 10.
  Future<int?> thermalStatus() async {
    if (!Platform.isAndroid) return null;
    try {
      final s = await _channel.invokeMethod<int>('thermalStatus');
      return s == null || s < 0 ? null : s;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Milisegundos desde que se encendió el teléfono (`SystemClock.elapsedRealtime`).
  /// Null fuera de Android.
  Future<int?> elapsedRealtimeMs() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('elapsedRealtime');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Arranca el servicio en primer plano del tutor (ver `TutorWorkService.kt`).
  /// `false` si Android no lo deja (app ya en segundo plano) o fuera de Android.
  Future<bool> startTutorWork() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('startTutorWork') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Para el servicio; con [notifyDone] deja el aviso "Toco ya terminó".
  Future<void> stopTutorWork({bool notifyDone = false}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopTutorWork', {'notifyDone': notifyDone});
    } on PlatformException {
      // sin efecto
    } on MissingPluginException {
      // sin efecto
    }
  }

  /// Quita el aviso "Toco ya terminó" (al volver a la app).
  Future<void> clearTutorDone() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearTutorDone');
    } on PlatformException {
      // sin efecto
    } on MissingPluginException {
      // sin efecto
    }
  }

  /// Mantiene la pantalla encendida (durante la prueba de velocidad).
  Future<void> keepScreenOn(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('keepScreenOn', {'on': on});
    } on PlatformException {
      // sin efecto
    } on MissingPluginException {
      // sin efecto
    }
  }

  /// "Acceso a todos los archivos" (Android 11+). True si no hace falta.
  Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre los ajustes de Android para conceder el permiso. El resultado se
  /// comprueba al volver a la app con [hasAllFilesAccess].
  Future<void> requestAllFilesAccess() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestAllFilesAccess');
    } on PlatformException {
      // Sin pantalla de ajustes disponible: no hay nada mas que hacer.
    } on MissingPluginException {
      // Plataforma sin puente nativo.
    }
  }

  /// Espacio libre, en bytes, del volumen que contiene [path] (null si no se sabe).
  Future<int?> freeBytes(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('freeBytes', {'path': path});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Abre el menu de compartir de Android con estos archivos, sin copiarlos.
  /// `false` si no hay nada que compartir o la plataforma no lo permite.
  Future<bool> shareFiles(List<String> paths, {String? title}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('shareFiles', {'paths': paths, 'title': title}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
