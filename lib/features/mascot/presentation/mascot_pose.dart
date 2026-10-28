import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/mascot_mood.dart';

/// Adornos que acompanan a Toco segun lo que hace.
enum MascotOrnamentKind {
  /// "Z z" que suben al dormir.
  sleepZ,

  /// Burbuja de pensamiento con puntos que aparecen.
  thoughtBubble,

  /// Notas musicales que salen del pico al hablar.
  musicNotes,

  /// Estrellitas de celebracion (happy).
  stars,

  /// Gotita que resbala por la mejilla (sad).
  tear,

  /// Signo de interrogacion amable (concerned).
  question,

  /// Ondas que llegan hacia Toco: esta escuchando (listening).
  listen,
}

/// Un adorno visible: [phase] es su ciclo (0..1, se repite) y [opacity] cuanto
/// se ve (0..1).
@immutable
class MascotOrnament {
  const MascotOrnament(this.kind, this.phase, [this.opacity = 1]);

  final MascotOrnamentKind kind;
  final double phase;
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is MascotOrnament && other.kind == kind && other.phase == phase && other.opacity == opacity;

  @override
  int get hashCode => Object.hash(kind, phase, opacity);

  @override
  String toString() => 'MascotOrnament($kind, ${phase.toStringAsFixed(3)}, ${opacity.toStringAsFixed(3)})';
}

/// Una pose de Toco en un instante. Distancias en pixeles del lienzo del atlas
/// (437 x 720) y giros en grados (positivo = sentido horario, como
/// `Canvas.rotate`). Todos los valores vienen ya acotados.
@immutable
class MascotPose {
  const MascotPose({
    this.bodyDy = 0,
    this.bodyScaleY = 1,
    this.headDeg = 0,
    this.wingDeg = 0,
    this.tailDeg = 0,
    this.gazeX = 0,
    this.gazeY = 0,
    this.lid = 0,
    this.lidTilt = 0,
    this.ornaments = const [],
  });

  static const maxHeadDeg = 8.0;
  static const maxWingDeg = 8.0;
  static const maxTailDeg = 10.0;

  /// Rebote maximo del cuerpo, en pixeles del lienzo (negativo = arriba).
  static const maxBodyDy = 12.0;

  /// Respiracion: estiramiento vertical maximo alrededor de las patas.
  static const maxBreath = 0.03;

  /// Todos los movimientos se repiten cada [period] segundos (mismo `age`).
  static const period = 24.0;

  /// Desplazamiento vertical de todo el pajaro (con la rama).
  final double bodyDy;

  /// Escala vertical alrededor de las patas (respiracion, 1 = reposo).
  final double bodyScaleY;

  final double headDeg;
  final double wingDeg;
  final double tailDeg;

  /// Mirada, -1..1 (x: izquierda/derecha, y: arriba/abajo).
  final double gazeX;
  final double gazeY;

  /// Parpado: 0 abierto, 1 cerrado.
  final double lid;

  /// Inclinacion del borde del parpado, -1..1. Negativo baja el lado de atras
  /// (gesto triste o preocupado); positivo, el de delante.
  final double lidTilt;

  final List<MascotOrnament> ornaments;

  /// El adorno de tipo [kind], o `null` si no se muestra.
  MascotOrnament? ornament(MascotOrnamentKind kind) {
    for (final o in ornaments) {
      if (o.kind == kind) return o;
    }
    return null;
  }

  /// Mezcla de [a] a [b] (u = 0..1). Los adornos que solo estan en uno se
  /// desvanecen.
  static MascotPose lerp(MascotPose a, MascotPose b, double u) {
    if (u <= 0) return a;
    if (u >= 1) return b;
    double l(double x, double y) => x + (y - x) * u;
    final ornaments = <MascotOrnament>[];
    for (final kind in MascotOrnamentKind.values) {
      final oa = a.ornament(kind);
      final ob = b.ornament(kind);
      if (oa == null && ob == null) continue;
      final opacity = l(oa?.opacity ?? 0, ob?.opacity ?? 0);
      if (opacity <= 0.001) continue;
      ornaments.add(MascotOrnament(kind, (ob ?? oa)!.phase, opacity));
    }
    return MascotPose(
      bodyDy: l(a.bodyDy, b.bodyDy),
      bodyScaleY: l(a.bodyScaleY, b.bodyScaleY),
      headDeg: l(a.headDeg, b.headDeg),
      wingDeg: l(a.wingDeg, b.wingDeg),
      tailDeg: l(a.tailDeg, b.tailDeg),
      gazeX: l(a.gazeX, b.gazeX),
      gazeY: l(a.gazeY, b.gazeY),
      lid: l(a.lid, b.lid),
      lidTilt: l(a.lidTilt, b.lidTilt),
      ornaments: ornaments,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MascotPose &&
      other.bodyDy == bodyDy &&
      other.bodyScaleY == bodyScaleY &&
      other.headDeg == headDeg &&
      other.wingDeg == wingDeg &&
      other.tailDeg == tailDeg &&
      other.gazeX == gazeX &&
      other.gazeY == gazeY &&
      other.lid == lid &&
      other.lidTilt == lidTilt &&
      listEquals(other.ornaments, ornaments);

  @override
  int get hashCode =>
      Object.hash(bodyDy, bodyScaleY, headDeg, wingDeg, tailDeg, gazeX, gazeY, lid, lidTilt, Object.hashAll(ornaments));

  @override
  String toString() => 'MascotPose(dy ${bodyDy.toStringAsFixed(2)}, sy ${bodyScaleY.toStringAsFixed(3)}, '
      'head ${headDeg.toStringAsFixed(2)}, wing ${wingDeg.toStringAsFixed(2)}, tail ${tailDeg.toStringAsFixed(2)}, '
      'gaze (${gazeX.toStringAsFixed(2)}, ${gazeY.toStringAsFixed(2)}), lid ${lid.toStringAsFixed(2)}/${lidTilt.toStringAsFixed(2)}, $ornaments)';
}

/// Duracion de la mezcla entre la pose anterior y la nueva al cambiar de mood.
const mascotBlendSeconds = 0.45;

/// Instante "bonito" para el fotograma fijo (sin animacion): ojos abiertos y
/// adornos a medio camino.
const mascotStillTime = 1.6;

/// Intensidad de la celebracion de `happy` segun [age]: plena los primeros
/// 2 s y se apaga suavemente hasta los 4 s.
double happyCelebration(double age) {
  if (age <= 2.0) return 1;
  if (age >= 4.0) return 0;
  return 0.5 + 0.5 * math.cos(math.pi * (age - 2.0) / 2.0);
}

/// Cuanto se ve el signo de interrogacion de `concerned`: claro unos segundos
/// y luego discreto (nunca insiste).
double concernedQuestion(double age) {
  if (age <= 4.0) return 1;
  if (age >= 6.0) return 0.35;
  return 0.35 + 0.65 * (0.5 + 0.5 * math.cos(math.pi * (age - 4.0) / 2.0));
}

/// Pose de Toco para [mood] en el instante [t] (segundos, monotono), con
/// [age] segundos desde el ultimo cambio de mood. Funcion pura y determinista.
MascotPose poseFor(MascotMood mood, double t, {double age = 99}) {
  var dy = 0.0;
  var sy = 1.0;
  var head = 0.0;
  var wing = 0.0;
  var tail = 0.0;
  var gx = 0.0;
  var gy = 0.0;
  var lid = 0.0;
  var tilt = 0.0;
  final ornaments = <MascotOrnament>[];

  switch (mood.activity) {
    case MascotActivity.sleeping:
      // Respiracion lenta y honda; la cabeza caida sube y baja con ella.
      final b = _wave(t, 4);
      sy = 1 + 0.014 * b;
      dy = -1.2 * b;
      head = 6.5 + 0.8 * b;
      wing = 0.8 * b;
      tail = -1.0 + 1.2 * _wave(t, 4, 0.15);
      gy = 0.6;
      lid = 1;
      ornaments.add(MascotOrnament(MascotOrnamentKind.sleepZ, _phase(t, 3)));
    case MascotActivity.idle:
      final b = _wave(t, 3);
      sy = 1 + 0.010 * b;
      dy = -1.0 * b;
      head = 1.2 * _wave(t, 6, 0.2) + 0.6 * _wave(t, 4);
      wing = 0.8 * b;
      tail = 2.5 * _wave(t, 4, 0.1);
      final (wx, wy) = _wander(t);
      gx = wx;
      gy = wy;
      lid = _blink(t);
    case MascotActivity.thinking:
      // Mira arriba, hacia la burbuja, con la cabeza alzada y pensativa.
      final b = _wave(t, 3);
      sy = 1 + 0.008 * b;
      dy = -0.8 * b;
      head = -4.5 + 1.5 * _wave(t, 4);
      wing = 0.6 * b;
      tail = 1.5 * _wave(t, 6);
      gx = 0.55 + 0.25 * _wave(t, 6, 0.3);
      gy = -0.85;
      lid = _blink(t);
      ornaments.add(MascotOrnament(MascotOrnamentKind.thoughtBubble, _phase(t, 2.4)));
    case MascotActivity.talking:
      // Cabeceo ritmico: el pico no se abre, la cabeza "canta".
      final nod = _wave(t, 0.75);
      final b = _wave(t, 3);
      sy = 1 + 0.008 * b + 0.004 * nod;
      dy = -0.8 * b - 1.0 * nod;
      head = 2.0 + 3.5 * nod;
      wing = 1.2 * _wave(t, 1.5);
      tail = 2.0 * _wave(t, 1.5, 0.25);
      gx = 0.3 + 0.15 * _wave(t, 6);
      gy = 0.1;
      lid = _blink(t);
      ornaments.add(MascotOrnament(MascotOrnamentKind.musicNotes, _phase(t, 1.5)));
    case MascotActivity.listening:
      // Cabeza inclinada y ojos atentos hacia abajo (donde escribe el nino);
      // cada tanto asiente un poquito, como "te escucho".
      final b = _wave(t, 3);
      sy = 1 + 0.008 * b;
      dy = -0.8 * b;
      head = -5.0 + 0.8 * _wave(t, 4) + 2.2 * _bump(t % 6.0, 1.2);
      wing = 0.6 * b;
      tail = 1.5 * _wave(t, 4);
      gx = 0.4 + 0.1 * _wave(t, 8);
      gy = 0.45 + 0.1 * _wave(t, 6);
      lid = _blink(t, attentive: true);
      ornaments.add(MascotOrnament(MascotOrnamentKind.listen, _phase(t, 2)));
    case MascotActivity.sad:
      // Cabeza y cola caidas, mirada al suelo, parpados algo bajos; suave.
      final b = _wave(t, 4);
      sy = 0.992 + 0.006 * b;
      dy = 2.5 - 0.6 * b;
      head = 6.0 + 0.6 * b;
      wing = -2.0 + 0.5 * b;
      tail = -6.0 + 0.8 * _wave(t, 6);
      gx = 0.15;
      gy = 0.9;
      lid = math.max(0.3, _blink(t));
      tilt = -1;
      ornaments.add(MascotOrnament(MascotOrnamentKind.tear, _phase(t, 4), 0.9));
  }

  switch (mood.emotion) {
    case MascotEmotion.neutral:
      break;
    case MascotEmotion.happy:
      final c = happyCelebration(age);
      if (mood.activity != MascotActivity.sleeping) {
        // Saltitos y aleteo mientras dura la celebracion; despues queda un
        // balanceo alegre de cola.
        final hop = _wave(t, 0.5).abs();
        dy -= 9.0 * c * hop;
        sy += 0.012 * c * (hop - 0.5);
        wing += 7.0 * c * (0.5 + 0.5 * _wave(t, 0.3));
        tail += 4.0 * c * _wave(t, 0.5) + 1.5 * (1 - c) * _wave(t, 2);
        head -= 2.0 * c;
        if (mood.activity == MascotActivity.idle) gx = gx * (1 - c) + 0.2 * c;
        if (mood.activity != MascotActivity.sad) lid *= 1 - c;
      }
      if (c > 0) ornaments.add(MascotOrnament(MascotOrnamentKind.stars, _phase(t, 1.2), c));
    case MascotEmotion.concerned:
      // Animo, no regano: cabeza ladeada que asiente despacio y mirada que
      // baja un poco, con un "?" amable.
      if (mood.activity != MascotActivity.sleeping) {
        head += 3.0 + 1.5 * _wave(t, 3);
        gy += 0.35;
        lid = math.max(lid, 0.16);
        tilt = math.min(tilt, -0.7);
      }
      ornaments.add(MascotOrnament(MascotOrnamentKind.question, _phase(t, 3), concernedQuestion(age)));
  }

  return MascotPose(
    bodyDy: _clamp(dy, MascotPose.maxBodyDy),
    bodyScaleY: 1 + _clamp(sy - 1, MascotPose.maxBreath),
    headDeg: _clamp(head, MascotPose.maxHeadDeg),
    wingDeg: _clamp(wing, MascotPose.maxWingDeg),
    tailDeg: _clamp(tail, MascotPose.maxTailDeg),
    gazeX: _clamp(gx, 1),
    gazeY: _clamp(gy, 1),
    lid: lid.clamp(0.0, 1.0),
    lidTilt: _clamp(tilt, 1),
    ornaments: List.unmodifiable(ornaments),
  );
}

/// Pose al cambiar de [from] a [to]: los primeros [mascotBlendSeconds] mezcla
/// las dos para que no haya saltos. Sin [from], igual que [poseFor].
MascotPose poseBetween(MascotMood? from, MascotMood to, double t, double age) {
  final target = poseFor(to, t, age: age);
  if (from == null || from == to || age >= mascotBlendSeconds) return target;
  final u = _smooth((age / mascotBlendSeconds).clamp(0.0, 1.0));
  return MascotPose.lerp(poseFor(from, t, age: 99), target, u);
}

double _clamp(double v, double m) => v.clamp(-m, m);

/// Seno de periodo [p] segundos (todos dividen a [MascotPose.period]).
double _wave(double t, double p, [double phase = 0]) => math.sin(2 * math.pi * (t / p + phase));

/// Fase 0..1 de un ciclo de [p] segundos.
double _phase(double t, double p) {
  final x = t / p;
  return x - x.floorToDouble();
}

double _smooth(double x) => x * x * (3 - 2 * x);

/// Pulso suave de 0 a 1 y vuelta a 0 en [dur] segundos.
double _bump(double x, double dur) {
  if (x <= 0 || x >= dur) return 0;
  final s = math.sin(math.pi * x / dur);
  return s * s;
}

/// Pseudoaleatorio determinista 0..1.
double _hash(int k) {
  final x = math.sin(k * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Parpadeo ocasional: uno por tramo de 4 s en un momento distinto de cada
/// tramo (a veces doble). Atento: solo en la mitad de los tramos.
double _blink(double t, {bool attentive = false}) {
  const seg = 4.0;
  final k = (t / seg).floor();
  final local = t - k * seg;
  final i = k % 6;
  if (attentive && i.isOdd) return 0;
  final at = 0.9 + _hash(i) * 2.2;
  var lid = _blinkCurve(local - at);
  if (_hash(i + 11) > 0.7) lid = math.max(lid, _blinkCurve(local - at - 0.34));
  return lid;
}

double _blinkCurve(double x) {
  const dur = 0.22;
  if (x <= 0 || x >= dur) return 0;
  return math.pow(math.sin(math.pi * x / dur), 0.6).toDouble();
}

/// Mirada que vaga: cada 3 s busca otro punto y llega con suavidad.
(double, double) _wander(double t) {
  const seg = 3.0;
  final k = (t / seg).floor();
  final local = t - k * seg;
  final i = k % 8;
  final j = (k - 1) % 8;
  (double, double) target(int n) => ((_hash(n + 40) * 2 - 1) * 0.75, (_hash(n + 70) * 2 - 1) * 0.45);
  final a = target(j);
  final b = target(i);
  final u = _smooth((local / 0.45).clamp(0.0, 1.0));
  return (a.$1 + (b.$1 - a.$1) * u, a.$2 + (b.$2 - a.$2) * u);
}
