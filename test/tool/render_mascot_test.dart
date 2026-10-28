// Herramienta para revisar el diseno de Toco sin movil. Solo hace algo con
// MASCOT_RENDER_DIR definido:
//   MASCOT_RENDER_DIR=/ruta flutter test test/tool/render_mascot_test.dart
// Escribe un PNG por estado, instante, tema y tamano:
//   <actividad>_<emocion>_<large|small>_<claro|oscuro>_t<ms>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/theme/app_theme.dart';
import 'package:inocencia/features/mascot/application/mascot_atlas.dart';
import 'package:inocencia/features/mascot/domain/mascot_mood.dart';
import 'package:inocencia/features/mascot/presentation/mascot_painter.dart';

final _dir = Platform.environment['MASCOT_RENDER_DIR'];

const _moods = [
  MascotMood(MascotActivity.sleeping),
  MascotMood(MascotActivity.idle),
  MascotMood(MascotActivity.thinking),
  MascotMood(MascotActivity.talking),
  MascotMood(MascotActivity.listening),
  MascotMood(MascotActivity.sad),
  MascotMood(MascotActivity.idle, MascotEmotion.happy),
  MascotMood(MascotActivity.idle, MascotEmotion.concerned),
  MascotMood(MascotActivity.talking, MascotEmotion.happy),
  MascotMood(MascotActivity.talking, MascotEmotion.concerned),
];

/// Instantes (s) de cada fila; `age` = t para ver la celebracion.
final _times = (Platform.environment['MASCOT_RENDER_TIMES'] ?? '0.4,1.1,1.6,2.3')
    .split(',')
    .map(double.parse)
    .toList();

void main() {
  testWidgets('render de Toco a PNG', skip: _dir == null, (tester) async {
    final out = Directory(_dir!)..createSync(recursive: true);
    final atlas = (await tester.runAsync(() => MascotAtlas.load(rootBundle)))!;
    final noAtlas = Platform.environment['MASCOT_RENDER_FALLBACK'] == '1';
    const heights = {MascotSize.large: 220.0, MascotSize.small: 64.0};
    final clock = ValueNotifier<double>(0);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final dark in [false, true]) {
      final scheme = dark ? AppTheme.darkScheme : AppTheme.lightScheme;
      for (final size in MascotSize.values) {
        final h = heights[size]!;
        final w = h * MascotPainter.aspectFor(size);
        for (final mood in _moods) {
          for (final t in _times) {
            clock.value = t;
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                      color: scheme.surface,
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: CustomPaint(
                          painter: MascotPainter(
                            atlas: noAtlas ? null : atlas,
                            mood: mood,
                            clock: clock,
                            moodSince: 0,
                            colors: MascotInk.of(scheme),
                            size: size,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final bytes = await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 3);
              final data = await image.toByteData(format: ui.ImageByteFormat.png);
              image.dispose();
              return data!.buffer.asUint8List();
            });
            final name = '${mood.activity.name}_${mood.emotion.name}_${size.name}_'
                '${dark ? 'oscuro' : 'claro'}_t${(t * 1000).round()}.png';
            File('${out.path}/$name').writeAsBytesSync(bytes!);
          }
        }
      }
    }
    atlas.dispose();
  });
}
