import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de PIN con PBKDF2-HMAC-SHA256 y sal aleatoria.
///
/// Formato guardado: `v1$iteraciones$sal(base64)$hash(base64)`.
/// Un PIN de 4 digitos es una barrera domestica, no seguridad fuerte.
class PinHasher {
  const PinHasher({this.iterations = 20000});

  final int iterations;

  static const _saltLength = 16;

  /// Genera el registro para guardar. Se calcula en un isolate.
  Future<String> hash(String pin) {
    final iters = iterations;
    return Isolate.run(() => hashSync(pin, iterations: iters));
  }

  Future<bool> verify(String pin, String stored) =>
      Isolate.run(() => verifySync(pin, stored));

  static String hashSync(String pin, {required int iterations, List<int>? salt}) {
    final s = salt ?? _randomSalt();
    final derived = _pbkdf2(utf8.encode(pin), s, iterations);
    return 'v1\$$iterations\$${base64.encode(s)}\$${base64.encode(derived)}';
  }

  static bool verifySync(String pin, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'v1') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    try {
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = _pbkdf2(utf8.encode(pin), salt, iterations);
      return _constantTimeEquals(expected, actual);
    } on FormatException {
      return false;
    }
  }

  static List<int> _randomSalt() {
    final rng = Random.secure();
    return List<int>.generate(_saltLength, (_) => rng.nextInt(256));
  }

  /// PBKDF2 con un unico bloque de 32 bytes (longitud de SHA-256).
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
