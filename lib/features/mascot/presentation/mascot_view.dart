import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/mascot_atlas.dart';
import '../application/mascot_settings.dart';
import '../domain/mascot_mood.dart';
import 'mascot_painter.dart';
import 'mascot_pose.dart';

export 'mascot_painter.dart' show MascotSize;

/// Toco, la mascota del tutor, en el estado [mood]. Mide [height] de alto y
/// `height * MascotPainter.aspectFor(size)` de ancho.
///
/// Anima con un unico [Ticker] a ~30 fps como mucho (sin `setState` por
/// fotograma). Si las animaciones estan apagadas (ajuste de la app o de
/// Android) pinta un fotograma fijo y no crea ningun Ticker.
class MascotView extends ConsumerStatefulWidget {
  const MascotView({
    super.key,
    required this.mood,
    this.height = 160,
    this.size = MascotSize.large,
  });

  final MascotMood mood;
  final double height;
  final MascotSize size;

  /// Texto para lectores de pantalla.
  static String semanticsLabel(MascotMood mood) {
    final doing = switch (mood.activity) {
      MascotActivity.sleeping => 'se está despertando',
      MascotActivity.idle => 'está listo',
      MascotActivity.thinking => 'está pensando',
      MascotActivity.talking => 'está hablando',
      MascotActivity.listening => 'te está escuchando',
      MascotActivity.sad => 'está un poco triste',
    };
    final feeling = switch (mood.emotion) {
      MascotEmotion.neutral => '',
      MascotEmotion.happy => ' y está contento',
      MascotEmotion.concerned => ' y te anima a intentarlo otra vez',
    };
    return 'Toco, tu tutor, $doing$feeling';
  }

  @override
  ConsumerState<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends ConsumerState<MascotView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _frame = 1 / 30;

  final _clock = ValueNotifier<double>(mascotStillTime);
  Ticker? _ticker;

  /// Tiempo acumulado antes del ultimo arranque del Ticker (t es monotono).
  double _base = 0;
  bool _animating = false;
  bool _foreground = true;

  MascotMood? _previousMood;
  double _moodSince = mascotStillTime - 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
  }

  @override
  void didUpdateWidget(MascotView old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      if (_animating) {
        _previousMood = old.mood;
        _moodSince = _clock.value;
      } else {
        _previousMood = null;
        _moodSince = _clock.value - 1.0;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (fg == _foreground) return;
    _foreground = fg;
    _sync(_animating);
  }

  void _onTick(Duration elapsed) {
    final t = _base + elapsed.inMicroseconds / 1e6;
    if (t - _clock.value >= _frame - 0.002) _clock.value = t;
  }

  /// Arranca o para el Ticker segun haga falta animar.
  void _sync(bool animate) {
    _animating = animate;
    final run = animate && _foreground;
    final ticker = _ticker;
    if (run) {
      if (ticker == null) {
        // Empieza justo despues del fotograma fijo para no dar saltos.
        _base = _clock.value;
        _ticker = createTicker(_onTick)..start();
      } else if (!ticker.isActive) {
        _base = _clock.value;
        ticker.start();
      }
    } else if (ticker != null && ticker.isActive) {
      ticker.stop();
      if (!animate) {
        // Sin animacion: queda un fotograma "bonito" (no a mitad de parpadeo).
        const p = MascotPose.period;
        _clock.value = (_clock.value / p).ceilToDouble() * p + mascotStillTime;
        _previousMood = null;
        _moodSince = _clock.value - 1.0;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atlas = switch (ref.watch(mascotAtlasProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final animate = ref.watch(mascotAnimateProvider) && !MediaQuery.disableAnimationsOf(context);
    _sync(animate);

    final aspect = MascotPainter.aspectFor(widget.size);
    return Semantics(
      label: MascotView.semanticsLabel(widget.mood),
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: widget.height,
        width: widget.height * aspect,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: MascotPainter(
              atlas: atlas,
              mood: widget.mood,
              previousMood: _animating ? _previousMood : null,
              moodSince: _moodSince,
              clock: _clock,
              colors: MascotInk.of(Theme.of(context).colorScheme),
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}
