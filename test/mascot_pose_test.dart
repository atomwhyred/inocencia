import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/mascot/domain/mascot_mood.dart';
import 'package:inocencia/features/mascot/presentation/mascot_pose.dart';

final allMoods = [
  for (final a in MascotActivity.values)
    for (final e in MascotEmotion.values) MascotMood(a, e),
];

List<double> times(double from, double to, double step) =>
    [for (var t = from; t < to; t += step) t];

void expectPoseClose(MascotPose a, MascotPose b, {String? reason, double eps = 1e-6}) {
  expect(a.bodyDy, closeTo(b.bodyDy, eps), reason: reason);
  expect(a.bodyScaleY, closeTo(b.bodyScaleY, eps), reason: reason);
  expect(a.headDeg, closeTo(b.headDeg, eps), reason: reason);
  expect(a.wingDeg, closeTo(b.wingDeg, eps), reason: reason);
  expect(a.tailDeg, closeTo(b.tailDeg, eps), reason: reason);
  expect(a.gazeX, closeTo(b.gazeX, eps), reason: reason);
  expect(a.gazeY, closeTo(b.gazeY, eps), reason: reason);
  expect(a.lid, closeTo(b.lid, eps), reason: reason);
  expect(a.lidTilt, closeTo(b.lidTilt, eps), reason: reason);
  expect(a.ornaments.map((o) => o.kind).toList(), b.ornaments.map((o) => o.kind).toList(), reason: reason);
  for (var i = 0; i < a.ornaments.length; i++) {
    // La fase es ciclica: 0.9999 y 0.0001 son casi lo mismo.
    final d = (a.ornaments[i].phase - b.ornaments[i].phase).abs();
    expect(min(d, 1 - d), lessThan(1e-6), reason: reason);
    expect(a.ornaments[i].opacity, closeTo(b.ornaments[i].opacity, eps), reason: reason);
  }
}

void main() {
  test('todos los valores quedan acotados', () {
    for (final mood in allMoods) {
      for (final age in [0.0, 0.3, 1.0, 3.0, 5.0, 99.0]) {
        for (final t in times(0, 48, 0.037)) {
          final p = poseFor(mood, t, age: age);
          final why = '$mood t=$t age=$age $p';
          expect(p.headDeg.abs(), lessThanOrEqualTo(MascotPose.maxHeadDeg), reason: why);
          expect(p.wingDeg.abs(), lessThanOrEqualTo(MascotPose.maxWingDeg), reason: why);
          expect(p.tailDeg.abs(), lessThanOrEqualTo(MascotPose.maxTailDeg), reason: why);
          expect(p.bodyDy.abs(), lessThanOrEqualTo(MascotPose.maxBodyDy), reason: why);
          expect((p.bodyScaleY - 1).abs(), lessThanOrEqualTo(MascotPose.maxBreath), reason: why);
          expect(p.gazeX.abs(), lessThanOrEqualTo(1), reason: why);
          expect(p.gazeY.abs(), lessThanOrEqualTo(1), reason: why);
          expect(p.lid, inInclusiveRange(0, 1), reason: why);
          expect(p.lidTilt.abs(), lessThanOrEqualTo(1), reason: why);
          for (final o in p.ornaments) {
            expect(o.phase, inInclusiveRange(0, 1), reason: why);
            expect(o.opacity, inInclusiveRange(0, 1), reason: why);
          }
        }
      }
    }
  });

  test('se repite cada MascotPose.period segundos', () {
    for (final mood in allMoods) {
      for (final t in times(0.013, 30, 0.41)) {
        expectPoseClose(
          poseFor(mood, t),
          poseFor(mood, t + MascotPose.period),
          reason: '$mood t=$t',
          eps: 1e-5,
        );
      }
    }
  });

  test('es determinista', () {
    for (final mood in allMoods) {
      for (final t in [0.0, 1.234, 7.5, 1000.25]) {
        expect(poseFor(mood, t, age: 1.5), poseFor(mood, t, age: 1.5));
      }
    }
  });

  test('el cabeceo ritmico es solo al hablar', () {
    // Cuanto cambia la cabeza en medio cabeceo (0.375 s).
    double nod(MascotMood mood) {
      var m = 0.0;
      for (final t in times(0, 24, 0.05)) {
        final d = (poseFor(mood, t).headDeg - poseFor(mood, t + 0.375).headDeg).abs();
        m = max(m, d);
      }
      return m;
    }

    for (final mood in allMoods) {
      if (mood.activity == MascotActivity.talking) {
        expect(nod(mood), greaterThan(5), reason: '$mood');
      } else {
        expect(nod(mood), lessThan(3.5), reason: '$mood');
      }
    }
  });

  test('cada actividad muestra su adorno', () {
    MascotOrnamentKind? main(MascotActivity a) =>
        poseFor(MascotMood(a), 1).ornaments.map((o) => o.kind).firstOrNull;
    expect(main(MascotActivity.sleeping), MascotOrnamentKind.sleepZ);
    expect(main(MascotActivity.idle), isNull);
    expect(main(MascotActivity.thinking), MascotOrnamentKind.thoughtBubble);
    expect(main(MascotActivity.talking), MascotOrnamentKind.musicNotes);
    expect(main(MascotActivity.listening), MascotOrnamentKind.listen);
    expect(main(MascotActivity.sad), MascotOrnamentKind.tear);
    for (final t in times(0, 24, 0.1)) {
      for (final mood in allMoods) {
        final notes = poseFor(mood, t).ornament(MascotOrnamentKind.musicNotes) != null;
        expect(notes, mood.activity == MascotActivity.talking);
      }
    }
  });

  test('parpadea de vez en cuando, y duerme con los ojos cerrados', () {
    for (final mood in [
      const MascotMood(MascotActivity.idle),
      const MascotMood(MascotActivity.thinking),
      const MascotMood(MascotActivity.talking),
    ]) {
      var closed = 0;
      var blinks = 0;
      var wasClosed = false;
      const step = 0.01;
      final ts = times(0, 24, step);
      for (final t in ts) {
        final c = poseFor(mood, t).lid > 0.5;
        if (c) closed++;
        if (c && !wasClosed) blinks++;
        wasClosed = c;
      }
      // Entre 4 y 12 parpadeos cada 24 s, y casi siempre con los ojos abiertos.
      expect(blinks, inInclusiveRange(4, 12), reason: '$mood');
      expect(closed / ts.length, inExclusiveRange(0.002, 0.08), reason: '$mood');
    }
    for (final t in times(0, 24, 0.1)) {
      expect(poseFor(const MascotMood(MascotActivity.sleeping), t).lid, 1);
    }
  });

  test('el fotograma fijo tiene los ojos abiertos (salvo dormido o triste)', () {
    for (final mood in allMoods) {
      final p = poseFor(mood, mascotStillTime, age: 1);
      switch (mood.activity) {
        case MascotActivity.sleeping:
          expect(p.lid, 1);
        case MascotActivity.sad:
          expect(p.lid, lessThan(0.5));
        default:
          expect(p.lid, lessThan(0.2), reason: '$mood');
      }
    }
  });

  test('la celebracion de happy se apaga a los ~4 s', () {
    const happy = MascotMood(MascotActivity.idle, MascotEmotion.happy);
    double flap(double age) {
      final ws = [for (final t in times(0, 1.2, 0.02)) poseFor(happy, t, age: age).wingDeg];
      return ws.reduce(max) - ws.reduce(min);
    }

    expect(poseFor(happy, 1, age: 0.5).ornament(MascotOrnamentKind.stars)?.opacity, 1);
    expect(poseFor(happy, 1, age: 5).ornament(MascotOrnamentKind.stars), isNull);
    expect(flap(0.5), greaterThan(5));
    expect(flap(6), lessThan(2.5));
    var last = 2.0;
    for (final a in times(0, 6, 0.05)) {
      final c = happyCelebration(a);
      expect(c, lessThanOrEqualTo(last));
      last = c;
    }
    expect(happyCelebration(4.0), 0);
  });

  test('concerned anima sin insistir: "?" que se vuelve discreto', () {
    const concerned = MascotMood(MascotActivity.idle, MascotEmotion.concerned);
    expect(poseFor(concerned, 1, age: 1).ornament(MascotOrnamentKind.question)?.opacity, 1);
    final later = poseFor(concerned, 1, age: 30).ornament(MascotOrnamentKind.question)!.opacity;
    expect(later, inExclusiveRange(0, 0.5));
    // Mirada algo baja y cabeza ladeada respecto a neutral.
    final n = poseFor(const MascotMood(MascotActivity.idle), 1);
    final c = poseFor(concerned, 1);
    expect(c.gazeY, greaterThan(n.gazeY));
    expect(c.headDeg, greaterThan(n.headDeg));
  });

  test('triste: cabeza y mirada abajo, cola caida', () {
    final p = poseFor(const MascotMood(MascotActivity.sad), 2);
    expect(p.headDeg, greaterThan(4));
    expect(p.gazeY, greaterThan(0.5));
    expect(p.tailDeg, lessThan(-3));
  });

  test('al cambiar de mood mezcla las poses sin saltos', () {
    const a = MascotMood(MascotActivity.sleeping);
    const b = MascotMood(MascotActivity.thinking);
    const t = 5.0;
    expectPoseClose(poseBetween(a, b, t, 0), poseFor(a, t), eps: 1e-9);
    expect(poseBetween(a, b, t, mascotBlendSeconds), poseFor(b, t, age: mascotBlendSeconds));
    final mid = poseBetween(a, b, t, mascotBlendSeconds / 2);
    expect(mid.headDeg, inExclusiveRange(poseFor(b, t).headDeg, poseFor(a, t).headDeg));
    expect(poseBetween(null, b, t, 0), poseFor(b, t, age: 0));
  });
}
