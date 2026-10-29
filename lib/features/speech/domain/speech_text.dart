/// Prepara el texto del tutor para leerlo en voz alta.
class SpeechText {
  const SpeechText._();

  /// Un trozo no pasa de esto: el motor de voz se atraganta con parrafos enormes.
  static const maxSentence = 220;

  static final _markdown = RegExp(r'[*#_`~>|]+');
  static final _bullet = RegExp(r'^\s*[-•·]\s+', multiLine: true);
  static final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
    unicode: true,
  );
  static final _spaces = RegExp(r'[ \t]+');
  static final _cut = RegExp(r'(?<=[.!?…:;])\s+|\n+');

  /// Sin marcas de formato, vinetas ni emojis, que el motor leeria como "asterisco".
  static String clean(String text) => text
      .replaceAll(_bullet, '')
      .replaceAll(_markdown, '')
      .replaceAll(_emoji, '')
      .replaceAll(_spaces, ' ')
      .replaceAll(RegExp(r' ?\n ?'), '\n')
      .trim();

  /// Frases para leer una a una (las muy largas se parten por palabras).
  static List<String> sentences(String text) {
    final out = <String>[];
    for (final part in clean(text).split(_cut)) {
      final s = part.trim();
      if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(s)) continue;
      if (s.length <= maxSentence) {
        out.add(s);
        continue;
      }
      var line = StringBuffer();
      for (final word in s.split(' ')) {
        if (line.length + word.length + 1 > maxSentence && line.isNotEmpty) {
          out.add(line.toString().trim());
          line = StringBuffer();
        }
        line.write('$word ');
      }
      if (line.isNotEmpty) out.add(line.toString().trim());
    }
    return out;
  }
}
