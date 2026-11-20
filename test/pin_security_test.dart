import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/security/pin_lockout.dart';
import 'package:inocencia/core/security/pin_strength.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PinHasher', () {
    test('verifica el PIN correcto y rechaza el incorrecto', () {
      final stored = PinHasher.hashSync('1234', iterations: 10);
      expect(PinHasher.verifySync('1234', stored), isTrue);
      expect(PinHasher.verifySync('1235', stored), isFalse);
    });

    test('la sal aleatoria produce hashes distintos para el mismo PIN', () {
      final a = PinHasher.hashSync('1234', iterations: 10);
      final b = PinHasher.hashSync('1234', iterations: 10);
      expect(a, isNot(b));
      expect(PinHasher.verifySync('1234', a), isTrue);
      expect(PinHasher.verifySync('1234', b), isTrue);
    });

    test('vector conocido PBKDF2-HMAC-SHA256 (password/salt, 1 iteracion)', () {
      final stored =
          PinHasher.hashSync('password', iterations: 1, salt: 'salt'.codeUnits);
      final derived = base64.decode(stored.split(r'$')[3]);
      final hex = derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('vector conocido PBKDF2-HMAC-SHA256 (password/salt, 2 iteraciones)', () {
      final stored =
          PinHasher.hashSync('password', iterations: 2, salt: 'salt'.codeUnits);
      final derived = base64.decode(stored.split(r'$')[3]);
      final hex = derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('registros malformados no verifican ni lanzan', () {
      expect(PinHasher.verifySync('1234', ''), isFalse);
      expect(PinHasher.verifySync('1234', 'v1\$abc\$x\$y'), isFalse);
      expect(PinHasher.verifySync('1234', 'v2\$10\$AAAA\$AAAA'), isFalse);
      expect(PinHasher.verifySync('1234', 'v1\$10\$!!!\$!!!'), isFalse);
    });

    test('hash/verify asincronos funcionan con el isolate', () async {
      const hasher = PinHasher(iterations: 10);
      final stored = await hasher.hash('987654');
      expect(await hasher.verify('987654', stored), isTrue);
      expect(await hasher.verify('000000', stored), isFalse);
    });
  });

  group('PinLockout', () {
    late SharedPreferences prefs;
    final t0 = DateTime(2026, 1, 1, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('no bloquea antes de 5 fallos', () async {
      final lock = PinLockout(prefs, 'g');
      for (var i = 0; i < 4; i++) {
        await lock.registerFailure(t0);
      }
      expect(lock.remaining(t0), isNull);
    });

    test('bloquea 30 s al 5.o fallo y expira', () async {
      final lock = PinLockout(prefs, 'g');
      for (var i = 0; i < 5; i++) {
        await lock.registerFailure(t0);
      }
      expect(lock.remaining(t0), const Duration(seconds: 30));
      expect(lock.remaining(t0.add(const Duration(seconds: 31))), isNull);
    });

    test('el bloqueo crece (60 s al 10.o fallo) y persiste entre instancias', () async {
      final lock = PinLockout(prefs, 'g');
      for (var i = 0; i < 10; i++) {
        await lock.registerFailure(t0);
      }
      expect(PinLockout(prefs, 'g').remaining(t0), const Duration(seconds: 60));
    });

    test('reset limpia el contador y los ambitos son independientes', () async {
      final lock = PinLockout(prefs, 'g');
      for (var i = 0; i < 5; i++) {
        await lock.registerFailure(t0);
      }
      expect(PinLockout(prefs, 'otro').remaining(t0), isNull);
      await lock.reset();
      expect(lock.remaining(t0), isNull);
    });

    test('adelantar la hora del teléfono no quita el bloqueo', () async {
      var up = const Duration(hours: 3);
      final lock = PinLockout(prefs, 'g', uptime: () => up);
      for (var i = 0; i < 5; i++) {
        await lock.registerFailure(t0);
      }
      // Reloj adelantado un día, pero solo han pasado 10 s desde el bloqueo.
      up += const Duration(seconds: 10);
      expect(lock.remaining(t0.add(const Duration(days: 1))), const Duration(seconds: 20));
      up += const Duration(seconds: 21);
      expect(lock.remaining(t0.add(const Duration(days: 1))), isNull);
    });

    test('atrasar la hora no alarga el bloqueo más de lo que tocaba', () async {
      final lock = PinLockout(prefs, 'g', uptime: () => const Duration(hours: 1));
      for (var i = 0; i < 5; i++) {
        await lock.registerFailure(t0);
      }
      expect(lock.remaining(t0.subtract(const Duration(days: 30))), const Duration(seconds: 30));
    });

    test('tras reiniciar el teléfono el bloqueo cuenta desde el encendido', () async {
      var up = const Duration(hours: 5);
      final lock = PinLockout(prefs, 'g', uptime: () => up);
      for (var i = 0; i < 5; i++) {
        await lock.registerFailure(t0);
      }
      up = const Duration(seconds: 12); // reinicio + reloj adelantado
      expect(lock.remaining(t0.add(const Duration(days: 1))), const Duration(seconds: 18));
    });
  });

  test('PIN débiles', () {
    for (final pin in ['0000', '1111', '1234', '4321', '0123', '123456', '987654', '1212', '4545', '2580']) {
      expect(weakPinReason(pin), isNotNull, reason: pin);
    }
    for (final pin in ['4829', '1235', '7391', '205817', '1990']) {
      expect(weakPinReason(pin), isNull, reason: pin);
    }
  });
}
