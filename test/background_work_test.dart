import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/storage/background_work.dart';

class _FakeWork implements TutorWorkPlatform {
  _FakeWork({this.allowStart = true});
  final bool allowStart;
  int starts = 0;
  final stops = <bool>[];

  @override
  Future<bool> start() async {
    starts++;
    return allowStart;
  }

  @override
  Future<void> stop({required bool notifyDone}) async => stops.add(notifyDone);
}

void main() {
  test('un trabajo arranca y para el servicio tras el margen', () {
    fakeAsync((async) {
      final p = _FakeWork();
      final w = BackgroundWork(platform: p, isForeground: () => true);
      w.begin();
      async.flushMicrotasks();
      expect((p.starts, w.running), (1, true));
      w.end();
      async.elapse(const Duration(seconds: 3));
      expect(p.stops, isEmpty, reason: 'aún dentro del margen');
      async.elapse(const Duration(seconds: 2));
      expect(p.stops, [false], reason: 'app en pantalla: sin aviso de "ya terminó"');
      expect(w.running, isFalse);
    });
  });

  test('trabajos encadenados (quiz, tarjetas) no rearrancan el servicio', () {
    fakeAsync((async) {
      final p = _FakeWork();
      final w = BackgroundWork(platform: p, isForeground: () => false);
      for (var i = 0; i < 3; i++) {
        w.begin();
        async.flushMicrotasks();
        w.end();
        async.elapse(const Duration(seconds: 1));
      }
      expect(p.starts, 1);
      expect(p.stops, isEmpty);
      async.elapse(const Duration(seconds: 5));
      expect(p.stops, [true], reason: 'app fuera de la pantalla: avisa al terminar');
    });
  });

  test('trabajos solapados: para al terminar el último', () {
    fakeAsync((async) {
      final p = _FakeWork();
      final w = BackgroundWork(platform: p, isForeground: () => true);
      w.begin();
      w.begin();
      async.flushMicrotasks();
      w.end();
      async.elapse(const Duration(seconds: 10));
      expect(p.stops, isEmpty);
      w.end(produced: false);
      async.elapse(const Duration(seconds: 10));
      expect(p.stops, [false]);
      w.end(); // de más: se ignora
      async.elapse(const Duration(seconds: 10));
      expect(p.stops, [false]);
    });
  });

  test('si Android no deja arrancarlo, no intenta pararlo', () {
    fakeAsync((async) {
      final p = _FakeWork(allowStart: false);
      final w = BackgroundWork(platform: p, isForeground: () => false);
      w.begin();
      async.flushMicrotasks();
      expect(w.running, isFalse);
      w.end();
      async.elapse(const Duration(seconds: 10));
      expect(p.stops, isEmpty);
    });
  });
}
