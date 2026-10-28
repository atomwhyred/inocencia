import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una capa de Toco: su imagen y donde va en el lienzo comun.
class MascotLayer {
  const MascotLayer(this.image, this.offset);

  final ui.Image image;

  /// Esquina superior izquierda, en pixeles del lienzo.
  final ui.Offset offset;
}

/// El ojo: el parpado se dibuja como un circulo de [lidColor] y radio [r]
/// sobre el centro; la pupila (capa `eye`) se desplaza hasta [maxGaze] y se
/// recorta al circulo interior [rInner].
class MascotEye {
  const MascotEye({
    required this.center,
    required this.r,
    required this.rInner,
    required this.maxGaze,
    required this.lidColor,
  });

  final ui.Offset center;
  final double r;
  final double rInner;
  final double maxGaze;
  final ui.Color lidColor;
}

/// Las capas de `assets/mascot/` ya decodificadas, mas las medidas de
/// `layers.json` (pivotes de giro, ojo y puntos de anclaje de los adornos).
/// Todo en pixeles del lienzo de [canvas].
class MascotAtlas {
  const MascotAtlas({
    required this.canvas,
    required this.order,
    required this.layers,
    required this.headPivot,
    required this.wingPivot,
    required this.tailPivot,
    required this.eye,
    required this.beakTip,
    required this.headTop,
    required this.tailTip,
  });

  final ui.Size canvas;

  /// Orden de dibujo, de atras hacia delante.
  final List<String> order;
  final Map<String, MascotLayer> layers;

  /// Centros de giro de cabeza (cuello), ala (hombro) y cola (arranque).
  final ui.Offset headPivot;
  final ui.Offset wingPivot;
  final ui.Offset tailPivot;
  final MascotEye eye;

  /// Puntos donde van las notas musicales (pico), la burbuja de pensamiento y
  /// las Z (sobre la cabeza) y la punta de la cola.
  final ui.Offset beakTip;
  final ui.Offset headTop;
  final ui.Offset tailTip;

  static const folder = 'assets/mascot';

  /// Lee `layers.json` y decodifica las capas.
  static Future<MascotAtlas> load(AssetBundle bundle) async {
    final json = jsonDecode(await bundle.loadString('$folder/layers.json')) as Map<String, dynamic>;
    ui.Offset point(Object? v) {
      final l = v! as List<dynamic>;
      return ui.Offset((l[0] as num).toDouble(), (l[1] as num).toDouble());
    }

    final layers = <String, MascotLayer>{};
    for (final l in (json['layers'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final data = await bundle.load('$folder/${l['file']}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      layers[l['name'] as String] = MascotLayer(
        frame.image,
        ui.Offset((l['x'] as num).toDouble(), (l['y'] as num).toDouble()),
      );
    }

    final canvas = (json['canvas'] as List<dynamic>).cast<num>();
    final pivots = json['pivots'] as Map<String, dynamic>;
    final anchors = json['anchors'] as Map<String, dynamic>;
    final eye = json['eye'] as Map<String, dynamic>;
    return MascotAtlas(
      canvas: ui.Size(canvas[0].toDouble(), canvas[1].toDouble()),
      order: (json['order'] as List<dynamic>).cast<String>(),
      layers: layers,
      headPivot: point(pivots['head']),
      wingPivot: point(pivots['wing']),
      tailPivot: point(pivots['tail']),
      eye: MascotEye(
        center: ui.Offset((eye['cx'] as num).toDouble(), (eye['cy'] as num).toDouble()),
        r: (eye['r'] as num).toDouble(),
        rInner: (eye['r_inner'] as num).toDouble(),
        maxGaze: (eye['max_gaze'] as num).toDouble(),
        lidColor: ui.Color(0xFF000000 | int.parse((eye['lid_color'] as String).substring(1), radix: 16)),
      ),
      beakTip: point(anchors['beak_tip']),
      headTop: point(anchors['head_top']),
      tailTip: point(anchors['tail_tip']),
    );
  }

  void dispose() {
    for (final l in layers.values) {
      l.image.dispose();
    }
  }
}

/// Las capas de Toco, decodificadas una vez. Es `null` si no se pueden leer
/// (el chat usa entonces un dibujo sencillo y sigue funcionando).
final mascotAtlasProvider = FutureProvider<MascotAtlas?>((ref) async {
  try {
    final atlas = await MascotAtlas.load(rootBundle);
    ref.onDispose(atlas.dispose);
    return atlas;
  } catch (_) {
    return null;
  }
});
