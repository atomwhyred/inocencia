import 'dart:async';
import 'dart:convert';

/// Todo lo que llega por la red en el juego viene de otro teléfono (o de cualquiera en
/// el mismo Wi-Fi): se limita y se limpia antes de usarlo o mostrárselo a un niño.
class NetSanitize {
  const NetSanitize._();

  /// Línea máxima de un mensaje. El estado de la partida con 6 jugadores y sus miniaturas
  /// ronda los 150 KB; más que eso es basura o un ataque.
  static const maxLineChars = 256 * 1024;

  /// Miniatura de foto de 96 px en PNG (unos 15-25 KB) en base64, con margen.
  static const maxImageAvatarChars = 48 * 1024;

  static const defaultAvatar = 'emoji:🙂';

  /// Texto corto para mostrar: sin caracteres de control y con [max] caracteres como
  /// mucho (contados por runas, para no partir un emoji por la mitad).
  static String text(Object? value, int max, {String fallback = ''}) {
    if (value is! String) return fallback;
    final clean = value
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2066-\u2069]'), ' ')
        .trim();
    final runes = clean.runes;
    final cut = runes.length <= max ? clean : String.fromCharCodes(runes.take(max)).trim();
    return cut.isEmpty ? fallback : cut;
  }

  /// Avatar que se acepta de la red: un emoji o una miniatura `img:` pequeña. Nunca
  /// `photo:<ruta>`, que haría pintar un archivo de ESTE teléfono.
  static String avatar(Object? value) {
    if (value is! String) return defaultAvatar;
    if (value.startsWith('emoji:')) {
      final e = value.substring(6);
      return e.isNotEmpty && e.runes.length <= 8 ? value : defaultAvatar;
    }
    if (value.startsWith('img:') &&
        value.length <= maxImageAvatarChars &&
        RegExp(r'^img:[A-Za-z0-9+/]+=*$').hasMatch(value) &&
        _isSmallPng(value.substring(4))) {
      return value;
    }
    return defaultAvatar;
  }

  /// Lado máximo de una miniatura (la app envía 96 px).
  static const maxImageSide = 256;

  /// PNG cuya cabecera dice que mide como mucho [maxImageSide] de lado: una imagen de
  /// 20000×20000 cabe en pocos KB comprimida y tumbaría la app al decodificarla.
  static bool _isSmallPng(String b64) {
    try {
      final bytes = base64Decode(b64);
      const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      if (bytes.length < 24) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      int be(int o) => (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
      final w = be(16), h = be(20);
      return w > 0 && h > 0 && w <= maxImageSide && h <= maxImageSide;
    } catch (_) {
      return false;
    }
  }

  /// Entero en un rango, o [fallback] si no es un entero.
  static int intIn(Object? value, int min, int max, int fallback) =>
      value is int ? value.clamp(min, max) : fallback;
}

/// Como [LineSplitter], pero corta la conexión (con un error) si una línea pasa de
/// [maxChars]: sin esto, quien envía megas sin salto de línea llena la memoria.
class BoundedLineSplitter extends StreamTransformerBase<String, String> {
  const BoundedLineSplitter([this.maxChars = NetSanitize.maxLineChars]);

  final int maxChars;

  @override
  Stream<String> bind(Stream<String> stream) {
    final buffer = StringBuffer();
    return stream.transform(
      StreamTransformer<String, String>.fromHandlers(
        handleData: (chunk, sink) {
          var start = 0;
          while (true) {
            final nl = chunk.indexOf('\n', start);
            if (nl < 0) break;
            buffer.write(chunk.substring(start, nl));
            if (buffer.length > maxChars) {
              buffer.clear();
              sink.addError(const FormatException('Mensaje demasiado largo'));
              sink.close();
              return;
            }
            var line = buffer.toString();
            if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
            buffer.clear();
            sink.add(line);
            start = nl + 1;
          }
          buffer.write(chunk.substring(start));
          if (buffer.length > maxChars) {
            buffer.clear();
            sink.addError(const FormatException('Mensaje demasiado largo'));
            sink.close();
          }
        },
        handleDone: (sink) {
          if (buffer.isNotEmpty) sink.add(buffer.toString());
          buffer.clear();
          sink.close();
        },
      ),
    );
  }
}

/// Decodifica UTF-8 y parte en líneas con tope (para los sockets del juego).
Stream<String> boundedLines(Stream<List<int>> bytes) => bytes
    .transform(const Utf8Decoder(allowMalformed: true))
    .transform(const BoundedLineSplitter());
