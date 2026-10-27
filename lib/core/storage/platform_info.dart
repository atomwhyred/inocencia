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
}
