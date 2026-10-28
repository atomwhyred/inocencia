import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/mascot_atlas.dart';
import '../domain/mascot_mood.dart';
import 'mascot_pose.dart';

/// Tamano de Toco: [large] es el pajaro entero con cola y rama; [small] es la
/// version compacta (cabeza, ala, pecho y rama, sin la cola larga) para ~64 dp.
enum MascotSize { large, small }

/// Medidas por defecto de `layers.json`, para el dibujo de respaldo.
const _headPivot = Offset(274.3, 203.4);
const _wingPivot = Offset(201.4, 218.7);
const _tailPivot = Offset(180.5, 449.9);
const _eyeCenter = Offset(271.5, 125.0);
const _eyeR = 27.8;
const _eyeRInner = 21.2;
const _maxGaze = 4.9;
const _lidColor = Color(0xFF12397B);
const _beakTip = Offset(429.1, 190.2);
const _headTop = Offset(267.7, 3.5);

/// Las patas sobre la rama: centro de la respiracion.
const _feet = Offset(240, 420);

/// Colores de los adornos, sacados del tema para leerse en claro y en oscuro.
@immutable
class MascotInk {
  MascotInk.of(ColorScheme scheme)
      : ink = scheme.primary,
        accent = scheme.secondary,
        halo = scheme.surface,
        bubble = Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), scheme.surface),
        dark = scheme.brightness == Brightness.dark;

  final Color ink;
  final Color accent;
  final Color halo;
  final Color bubble;
  final bool dark;

  @override
  bool operator ==(Object other) =>
      other is MascotInk &&
      other.ink == ink &&
      other.accent == accent &&
      other.halo == halo &&
      other.bubble == bubble &&
      other.dark == dark;

  @override
  int get hashCode => Object.hash(ink, accent, halo, bubble, dark);
}

/// Dibuja a Toco: las capas del [atlas] con la pose de [mood] en el instante
/// [clock] (segundos), mas los adornos. Sin atlas, un dibujo vectorial sencillo.
class MascotPainter extends CustomPainter {
  MascotPainter({
    required this.atlas,
    required this.mood,
    required this.clock,
    required this.colors,
    this.previousMood,
    this.moodSince = -1000,
    this.size = MascotSize.large,
  }) : super(repaint: clock);

  final MascotAtlas? atlas;
  final MascotMood mood;

  /// Mood anterior, para mezclar las poses al cambiar.
  final MascotMood? previousMood;

  /// Instante (en el reloj de [clock]) del ultimo cambio de mood.
  final double moodSince;
  final ValueListenable<double> clock;
  final MascotInk colors;
  final MascotSize size;

  /// Zona del lienzo del atlas que se muestra: deja sitio a los adornos.
  static const largeFrame = Rect.fromLTRB(-10, -86, 526, 724);
  static const smallFrame = Rect.fromLTRB(60, -96, 590, 524);

  static Rect frameFor(MascotSize size) => size == MascotSize.large ? largeFrame : smallFrame;

  /// Ancho / alto del recuadro de Toco.
  static double aspectFor(MascotSize size) => frameFor(size).width / frameFor(size).height;

  // Pinturas y trazos reutilizables (nada pesado por fotograma).
  static final _image = Paint()..filterQuality = FilterQuality.medium;
  static final _fill = Paint()..isAntiAlias = true;
  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _zPath = Path()
    ..moveTo(0, 0)
    ..lineTo(1, 0)
    ..lineTo(0, 1)
    ..lineTo(1, 1);
  static final _starPath = _star();
  static final _notePath = _note(false);
  static final _doubleNotePath = _note(true);
  static final _questionPath = Path()
    ..moveTo(0.18, 0.3)
    ..cubicTo(0.18, 0.02, 0.82, 0.02, 0.82, 0.3)
    ..cubicTo(0.82, 0.48, 0.5, 0.48, 0.5, 0.68);
  static final _tearPath = Path()
    ..moveTo(0, -1)
    ..cubicTo(0.35, -0.45, 0.62, -0.1, 0.62, 0.3)
    ..arcToPoint(const Offset(-0.62, 0.3), radius: const Radius.circular(0.62))
    ..cubicTo(-0.62, -0.1, -0.35, -0.45, 0, -1)
    ..close();

  // Recortes del ojo: dependen del atlas, se crean una vez por atlas.
  static final _clips = Expando<(Path, Path)>();

  @override
  void paint(Canvas canvas, Size box) {
    final frame = frameFor(size);
    final s = math.min(box.width / frame.width, box.height / frame.height);
    if (s <= 0) return;
    final t = clock.value;
    final pose = poseBetween(previousMood, mood, t, t - moodSince);

    canvas.save();
    canvas.translate((box.width - frame.width * s) / 2, (box.height - frame.height * s) / 2);
    canvas.scale(s);
    canvas.translate(-frame.left, -frame.top);
    canvas.clipRect(frame);
    final a = atlas;
    if (a != null) {
      _paintAtlas(canvas, a, pose);
    } else {
      paintFallback(canvas, pose);
    }
    _paintOrnaments(canvas, pose, a);
    canvas.restore();
  }

  // ---------------------------------------------------------------- capas

  void _bodyTransform(Canvas canvas, MascotPose pose) {
    final sx = 1 - (pose.bodyScaleY - 1) * 0.5;
    canvas.translate(_feet.dx, _feet.dy + pose.bodyDy);
    canvas.scale(sx, pose.bodyScaleY);
    canvas.translate(-_feet.dx, -_feet.dy);
  }

  static void _rotateAbout(Canvas canvas, Offset pivot, double deg) {
    if (deg == 0) return;
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(deg * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  void _paintAtlas(Canvas canvas, MascotAtlas a, MascotPose pose) {
    canvas.save();
    _bodyTransform(canvas, pose);
    for (final name in a.order) {
      final layer = a.layers[name];
      if (layer == null) continue;
      switch (name) {
        case 'tail':
          if (size == MascotSize.small) continue;
          canvas.save();
          _rotateAbout(canvas, a.tailPivot, pose.tailDeg);
          canvas.drawImage(layer.image, layer.offset, _image);
          canvas.restore();
        case 'wing':
          canvas.save();
          _rotateAbout(canvas, a.wingPivot, pose.wingDeg);
          canvas.drawImage(layer.image, layer.offset, _image);
          canvas.restore();
        case 'head':
          canvas.save();
          _rotateAbout(canvas, a.headPivot, pose.headDeg);
          canvas.drawImage(layer.image, layer.offset, _image);
          _paintAtlasEye(canvas, a, pose);
          _paintTear(canvas, pose, a.eye.center, a.eye.r);
          canvas.restore();
        case 'eye':
          break; // va con la cabeza
        default:
          canvas.drawImage(layer.image, layer.offset, _image);
      }
    }
    canvas.restore();
  }

  void _paintAtlasEye(Canvas canvas, MascotAtlas a, MascotPose pose) {
    final eye = a.eye;
    final clips = _clips[a] ??= (
      Path()..addOval(Rect.fromCircle(center: eye.center, radius: eye.rInner)),
      Path()..addOval(Rect.fromCircle(center: eye.center, radius: eye.r)),
    );
    final pupil = a.layers['eye'];
    if (pupil != null && pose.lid < 0.98) {
      canvas.save();
      canvas.clipPath(clips.$1);
      canvas.drawImage(
        pupil.image,
        pupil.offset + Offset(pose.gazeX * eye.maxGaze, pose.gazeY * eye.maxGaze),
        _image,
      );
      canvas.restore();
    }
    _paintLid(canvas, pose.lid, pose.lidTilt, eye.center, eye.r, eye.lidColor, clips.$2);
  }

  /// Parpado que baja desde arriba como un disco de [color]; casi cerrado,
  /// una pestana curva para que "dormido" se lea aun en pequeno.
  void _paintLid(Canvas canvas, double lid, double tilt, Offset c, double r, Color color, Path disc) {
    if (lid <= 0.01) return;
    canvas.save();
    canvas.clipPath(disc);
    _fill.color = color;
    // El borde gira sobre su punto medio: [tilt] negativo baja el lado de atras.
    final edge = c.dy - r + 2 * r * lid;
    canvas.translate(c.dx, edge);
    canvas.rotate(tilt * 0.38 * (1 - lid));
    canvas.drawRect(Rect.fromLTRB(-2 * r, -3 * r, 2 * r, 0), _fill);
    canvas.restore();
    if (lid > 0.7) {
      final k = ((lid - 0.7) / 0.3).clamp(0.0, 1.0);
      _stroke
        ..color = const Color(0xFFAFC6F2).withValues(alpha: k)
        ..strokeWidth = r * 0.17;
      final lash = Path()
        ..moveTo(c.dx - r * 0.72, c.dy + r * 0.02)
        ..quadraticBezierTo(c.dx, c.dy + r * 0.62, c.dx + r * 0.72, c.dy + r * 0.02);
      canvas.drawPath(lash, _stroke);
    }
  }

  // ------------------------------------------------------------ respaldo

  static final _fbOutline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF0B1B45);
  /// Borde blanco de pegatina, como el dibujo original (se lee en oscuro).
  static final _fbSticker = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 20
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFFFFFFFF);
  static final _fbEyeDisc = Path()..addOval(Rect.fromCircle(center: _eyeCenter, radius: _eyeR));
  static final _fbEyeInner = Path()..addOval(Rect.fromCircle(center: _eyeCenter, radius: _eyeRInner));
  static final _fbTail = Path()
    ..moveTo(150, 430)
    ..lineTo(232, 445)
    ..lineTo(132, 690)
    ..lineTo(104, 714)
    ..lineTo(92, 684)
    ..lineTo(60, 700)
    ..lineTo(70, 660)
    ..close();
  static final _fbBody = Path()..addOval(Rect.fromCenter(center: const Offset(250, 330), width: 270, height: 330));
  static final _fbBelly = Path()
    ..moveTo(130, 400)
    ..quadraticBezierTo(250, 440, 375, 380)
    ..quadraticBezierTo(330, 500, 230, 515)
    ..quadraticBezierTo(170, 480, 130, 400)
    ..close();
  static final _fbWing = Path()
    ..moveTo(200, 205)
    ..cubicTo(80, 220, 80, 400, 120, 470)
    ..cubicTo(170, 420, 240, 330, 200, 205)
    ..close();
  static final _fbBranch = RRect.fromRectAndRadius(const Rect.fromLTRB(110, 400, 420, 438), const Radius.circular(19));
  static final _fbHead = Path()
    ..addOval(Rect.fromCenter(center: const Offset(275, 115), width: 270, height: 220));
  static final _fbThroat = Path()
    ..moveTo(200, 196)
    ..quadraticBezierTo(250, 160, 330, 168)
    ..quadraticBezierTo(390, 172, 400, 190)
    ..quadraticBezierTo(380, 240, 290, 250)
    ..quadraticBezierTo(220, 245, 200, 196)
    ..close();
  static final _fbBeak = Path()
    ..moveTo(372, 140)
    ..quadraticBezierTo(410, 150, 432, 190)
    ..quadraticBezierTo(400, 200, 372, 198)
    ..close();

  /// Dibujo vectorial sencillo de Toco (azul, blanco y rojo) para cuando el
  /// atlas aun no cargo o no se pudo leer. Responde a la misma pose.
  void paintFallback(Canvas canvas, MascotPose pose) {
    canvas.save();
    _bodyTransform(canvas, pose);
    if (size == MascotSize.large) {
      canvas.save();
      _rotateAbout(canvas, _tailPivot, pose.tailDeg);
      canvas.drawPath(_fbTail, _fbSticker);
      _fill.color = const Color(0xFFF2F5FF);
      canvas.drawPath(_fbTail, _fill);
      canvas.drawPath(_fbTail, _fbOutline);
      canvas.restore();
    }
    canvas.drawPath(_fbBody, _fbSticker);
    _fill.color = const Color(0xFFF4F6FF);
    canvas.drawPath(_fbBody, _fill);
    _fill.color = const Color(0xFFDC241F);
    canvas.drawPath(_fbBelly, _fill);
    canvas.drawPath(_fbBody, _fbOutline);
    canvas.save();
    _rotateAbout(canvas, _wingPivot, pose.wingDeg);
    _fill.color = const Color(0xFF2E7D6B);
    canvas.drawPath(_fbWing, _fill);
    canvas.drawPath(_fbWing, _fbOutline);
    canvas.restore();
    canvas.save();
    _rotateAbout(canvas, const Offset(270, 419), -7);
    _fill.color = const Color(0xFF7A4A24);
    canvas.drawRRect(_fbBranch, _fill);
    canvas.drawRRect(_fbBranch, _fbOutline);
    canvas.restore();

    canvas.save();
    _rotateAbout(canvas, _headPivot, pose.headDeg);
    canvas.drawPath(_fbHead, _fbSticker);
    canvas.drawPath(_fbBeak, _fbSticker);
    _fill.color = const Color(0xFF2456B8);
    canvas.drawPath(_fbHead, _fill);
    canvas.drawPath(_fbHead, _fbOutline);
    // Garganta blanca que se funde con el pecho.
    _fill.color = const Color(0xFFF4F6FF);
    canvas.drawPath(_fbThroat, _fill);
    _fill.color = const Color(0xFFDC241F);
    canvas.drawPath(_fbBeak, _fill);
    canvas.drawPath(_fbBeak, _fbOutline);
    _fill.color = const Color(0xFFE2E6EF);
    canvas.drawPath(_fbEyeDisc, _fill);
    if (pose.lid < 0.98) {
      canvas.save();
      canvas.clipPath(_fbEyeInner);
      final p = _eyeCenter + Offset(pose.gazeX * _maxGaze, pose.gazeY * _maxGaze + 2);
      _fill.color = const Color(0xFF0B1B45);
      canvas.drawCircle(p, 17, _fill);
      _fill.color = Colors.white;
      canvas.drawCircle(p + const Offset(-5, -6), 5.5, _fill);
      canvas.restore();
    }
    _paintLid(canvas, pose.lid, pose.lidTilt, _eyeCenter, _eyeR, _lidColor, _fbEyeDisc);
    _paintTear(canvas, pose, _eyeCenter, _eyeR);
    canvas.restore();
    canvas.restore();
  }

  // ------------------------------------------------------------- adornos

  /// [p] (en el lienzo) tal como queda tras girar la cabeza y mover el cuerpo.
  Offset _headPoint(Offset p, Offset pivot, MascotPose pose) {
    final r = pose.headDeg * math.pi / 180;
    final d = p - pivot;
    final q = pivot + Offset(d.dx * math.cos(r) - d.dy * math.sin(r), d.dx * math.sin(r) + d.dy * math.cos(r));
    final sx = 1 - (pose.bodyScaleY - 1) * 0.5;
    return Offset(_feet.dx + (q.dx - _feet.dx) * sx, _feet.dy + (q.dy - _feet.dy) * pose.bodyScaleY + pose.bodyDy);
  }

  double get _k => size == MascotSize.small ? 1.45 : 1.0;

  void _paintOrnaments(Canvas canvas, MascotPose pose, MascotAtlas? a) {
    if (pose.ornaments.isEmpty) return;
    final pivot = a?.headPivot ?? _headPivot;
    final beak = _headPoint(a?.beakTip ?? _beakTip, pivot, pose);
    final top = _headPoint(a?.headTop ?? _headTop, pivot, pose);
    for (final o in pose.ornaments) {
      switch (o.kind) {
        case MascotOrnamentKind.sleepZ:
          _paintZ(canvas, top, o);
        case MascotOrnamentKind.thoughtBubble:
          _paintBubble(canvas, top, o);
        case MascotOrnamentKind.musicNotes:
          _paintNotes(canvas, beak, o);
        case MascotOrnamentKind.stars:
          _paintStars(canvas, top, o);
        case MascotOrnamentKind.question:
          _paintQuestion(canvas, top, o);
        case MascotOrnamentKind.listen:
          _paintListen(canvas, beak, o);
        case MascotOrnamentKind.tear:
          break; // va dentro de la cabeza
      }
    }
  }

  /// Dibuja [path] (en unidades) con un halo del color de fondo para que se
  /// lea sobre el pajaro y sobre el fondo.
  void _strokeWithHalo(Canvas canvas, Path path, Color color, double width, double alpha) {
    _stroke
      ..color = colors.halo.withValues(alpha: alpha * 0.9)
      ..strokeWidth = width * 2.1;
    canvas.drawPath(path, _stroke);
    _stroke
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = width;
    canvas.drawPath(path, _stroke);
  }

  void _fillWithHalo(Canvas canvas, Path path, Color color, double halo, double alpha) {
    _stroke
      ..color = colors.halo.withValues(alpha: alpha * 0.9)
      ..strokeWidth = halo;
    canvas.drawPath(path, _stroke);
    _fill.color = color.withValues(alpha: alpha);
    canvas.drawPath(path, _fill);
  }

  static double _fade(double u, [double inEnd = 0.15, double outStart = 0.7]) {
    if (u < inEnd) return u / inEnd;
    if (u > outStart) return (1 - (u - outStart) / (1 - outStart)).clamp(0.0, 1.0);
    return 1;
  }

  void _paintZ(Canvas canvas, Offset top, MascotOrnament o) {
    // Suben en diagonal desde la coronilla, creciendo y apagandose.
    final small = size == MascotSize.small;
    final start = top + (small ? const Offset(95, 10) : const Offset(70, 40));
    final travel = small ? const Offset(150, -60) : const Offset(105, -88);
    final n = small ? 2 : 3;
    for (var i = 0; i < n; i++) {
      final u = (o.phase + i / n) % 1.0;
      final alpha = _fade(u, 0.2, 0.65) * o.opacity;
      if (alpha <= 0.01) continue;
      final z = (small ? 46 + 30 * u : 20 + 24 * u);
      final p = start + travel * u + Offset(0, 6 * math.sin(u * 2 * math.pi));
      canvas.save();
      canvas.translate(p.dx - z / 2, p.dy - z / 2);
      canvas.rotate(-0.12);
      canvas.scale(z);
      _strokeWithHalo(canvas, _zPath, colors.ink, 0.2, alpha);
      canvas.restore();
    }
  }

  void _paintBubble(Canvas canvas, Offset top, MascotOrnament o) {
    final k = _k;
    final bob = 4 * math.sin(o.phase * 2 * math.pi);
    final w = 150.0 * k;
    final h = 92.0 * k;
    final c = top + Offset(150 + (k - 1) * 70, -22 - (k - 1) * 28 + bob);
    final alpha = o.opacity;
    _stroke
      ..color = colors.ink.withValues(alpha: alpha)
      ..strokeWidth = 6 * k;
    _fill.color = colors.bubble.withValues(alpha: alpha);
    // Burbujitas que salen de la cabeza.
    final trail = [(top + Offset(98, 30), 8.0), (top + Offset(118, 10 - (k - 1) * 10), 12.0)];
    for (final (p, r) in trail) {
      canvas.drawCircle(p, r * k, _fill);
      canvas.drawCircle(p, r * k, _stroke);
    }
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));
    canvas.drawRRect(rr, _fill);
    canvas.drawRRect(rr, _stroke);
    // Puntos que aparecen uno a uno y se quedan un momento.
    final shown = o.phase * 4.0;
    for (var i = 0; i < 3; i++) {
      final pop = (shown - i).clamp(0.0, 1.0);
      if (pop <= 0) continue;
      final grow = pop < 0.5 ? 0.6 + 0.8 * pop : 1.0;
      _fill.color = colors.ink.withValues(alpha: alpha);
      canvas.drawCircle(c + Offset((i - 1) * w * 0.26, 0), 10 * k * grow, _fill);
    }
  }

  void _paintNotes(Canvas canvas, Offset beak, MascotOrnament o) {
    final k = _k;
    for (var i = 0; i < 2; i++) {
      final u = (o.phase + i / 2) % 1.0;
      final alpha = _fade(u, 0.15, 0.6) * o.opacity;
      if (alpha <= 0.01) continue;
      final z = (40 + 14 * u) * k;
      final sway = 14 * math.sin(u * 2 * math.pi + i);
      final p = beak + Offset(4 + u * 36 + sway, -24 - u * 130 * k);
      canvas.save();
      canvas.translate(p.dx, p.dy - z);
      canvas.rotate(0.22 * math.sin(u * 2 * math.pi + i * 2));
      canvas.scale(z);
      _fillWithHalo(canvas, i.isEven ? _notePath : _doubleNotePath, colors.accent, 0.16, alpha);
      canvas.restore();
    }
  }

  static const _starSpots = [
    (Offset(-150, 50), 30.0, 0.0),
    (Offset(-60, -58), 24.0, 0.3),
    (Offset(140, -50), 32.0, 0.55),
    (Offset(-205, 175), 22.0, 0.8),
  ];

  void _paintStars(Canvas canvas, Offset top, MascotOrnament o) {
    final k = _k;
    final spots = size == MascotSize.small ? _starSpots.sublist(0, 3) : _starSpots;
    for (final (d, r, ph) in spots) {
      final w = math.sin(2 * math.pi * (o.phase + ph));
      // Titilan por tamano (no por transparencia: apagadas se ven sucias).
      // Al apagarse la celebracion se encogen en vez de volverse grises.
      final scale = (0.72 + 0.28 * w) * (0.35 + 0.65 * o.opacity);
      final alpha = (o.opacity * 3).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(top.dx + d.dx * (size == MascotSize.small ? 0.85 : 1), top.dy + d.dy);
      canvas.rotate(0.3 * w);
      canvas.scale(r * k * scale);
      _fillWithHalo(canvas, _starPath, const Color(0xFFFFC53D), 0.28, alpha);
      _stroke
        ..color = const Color(0xFFD98A00).withValues(alpha: alpha)
        ..strokeWidth = 0.1;
      canvas.drawPath(_starPath, _stroke);
      canvas.restore();
    }
  }

  void _paintQuestion(Canvas canvas, Offset top, MascotOrnament o) {
    final k = _k;
    final z = 66.0 * k;
    final bob = 6 * math.sin(o.phase * 2 * math.pi);
    final p = top + Offset(-95 - (k - 1) * 40, -78 - (k - 1) * 10 + bob);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(-0.15 + 0.06 * math.sin(o.phase * 2 * math.pi));
    canvas.scale(z);
    _strokeWithHalo(canvas, _questionPath, colors.ink, 0.15, o.opacity);
    _fill.color = colors.halo.withValues(alpha: o.opacity * 0.9);
    canvas.drawCircle(const Offset(0.5, 0.9), 0.15, _fill);
    _fill.color = colors.ink.withValues(alpha: o.opacity);
    canvas.drawCircle(const Offset(0.5, 0.9), 0.09, _fill);
    canvas.restore();
  }

  /// Ondas en arco delante del pico que se acercan a Toco: "te escucho".
  void _paintListen(Canvas canvas, Offset beak, MascotOrnament o) {
    final k = _k;
    final c = beak + Offset(-8, -6 * k);
    for (var i = 0; i < 2; i++) {
      final u = (o.phase + i / 2) % 1.0;
      final alpha = _fade(1 - u, 0.25, 0.75) * o.opacity;
      if (alpha <= 0.01) continue;
      final r = (40 + 70 * (1 - u)) * k;
      _stroke
        ..color = colors.ink.withValues(alpha: alpha * 0.85)
        ..strokeWidth = 7 * k;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -0.55, 1.1, false, _stroke);
    }
  }

  /// Gotita que se forma bajo el ojo y resbala por la mejilla.
  void _paintTear(Canvas canvas, MascotPose pose, Offset eye, double r) {
    final o = pose.ornament(MascotOrnamentKind.tear);
    if (o == null) return;
    final u = o.phase;
    if (u > 0.85) return;
    final grow = (u / 0.25).clamp(0.0, 1.0);
    final slide = u < 0.3 ? 0.0 : (u - 0.3) / 0.55;
    final alpha = (u < 0.65 ? 1.0 : 1 - (u - 0.65) / 0.2) * o.opacity;
    final z = (7 + 9 * grow) * _k;
    final p = eye + Offset(-r * 0.15 - slide * 6, r * 0.95 + z * 0.7 + slide * 55);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(z);
    _stroke
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
      ..strokeWidth = 0.32;
    canvas.drawPath(_tearPath, _stroke);
    _fill.color = const Color(0xFF6FC4FF).withValues(alpha: alpha);
    canvas.drawPath(_tearPath, _fill);
    _fill.color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9);
    canvas.drawCircle(const Offset(-0.2, 0.15), 0.18, _fill);
    canvas.restore();
  }

  static Path _star() {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 1.0 : 0.46;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = r * math.cos(a);
      final y = r * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  /// Nota en un cuadro de 1 x 1 (cabeza abajo a la izquierda).
  static Path _note(bool beamed) {
    final p = Path();
    if (!beamed) {
      p.addOval(Rect.fromCenter(center: const Offset(0.3, 0.84), width: 0.46, height: 0.32));
      p.addRect(const Rect.fromLTRB(0.44, 0.06, 0.55, 0.82));
      p.moveTo(0.44, 0.0);
      p.cubicTo(0.6, 0.12, 0.92, 0.2, 0.8, 0.55);
      p.cubicTo(0.8, 0.32, 0.65, 0.3, 0.55, 0.28);
      p.close();
    } else {
      p.addOval(Rect.fromCenter(center: const Offset(0.18, 0.86), width: 0.36, height: 0.26));
      p.addOval(Rect.fromCenter(center: const Offset(0.78, 0.76), width: 0.36, height: 0.26));
      p.addRect(const Rect.fromLTRB(0.28, 0.12, 0.36, 0.84));
      p.addRect(const Rect.fromLTRB(0.88, 0.02, 0.96, 0.74));
      p.moveTo(0.28, 0.12);
      p.lineTo(0.96, 0.0);
      p.lineTo(0.96, 0.18);
      p.lineTo(0.28, 0.3);
      p.close();
    }
    return p;
  }

  @override
  bool shouldRepaint(MascotPainter old) =>
      old.atlas != atlas ||
      old.mood != mood ||
      old.previousMood != previousMood ||
      old.moodSince != moodSince ||
      old.clock != clock ||
      old.colors != colors ||
      old.size != size;
}
