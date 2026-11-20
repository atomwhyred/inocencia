/// Texto sin mayusculas, tildes ni signos, para comparar lo que escribe el
/// modelo con lo que dice el libro.
String plainText(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunaeiouun';
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    buf.write(i >= 0 ? to[i] : c);
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r' +'), ' ')
      .trim();
}

/// `true` si el texto depende de algo que el nino no tiene delante (una pagina,
/// un recuadro, un dibujo...): no sirve para una pregunta o una tarjeta suelta.
bool dependsOnBookLayout(String text) =>
    RegExp(r'\b(pagina|recuadro|ejercicio|imagen|dibujo|figura|texto)\b').hasMatch(plainText(text));

/// Desactiva los marcadores de control del formato de chat (`<|im_start|>`,
/// `<|im_end|>`, `<|endoftext|>`...). llama.cpp convierte ese texto en tokens de
/// control reales, así que un fragmento de libro, lo que escribe el niño o una
/// respuesta guardada podrían cerrar su turno y abrir uno de "system" con otras
/// órdenes. Con un espacio en medio el modelo lo lee como texto normal.
String neutralizeChatMarkup(String s) =>
    s.contains('<|') || s.contains('|>') ? s.replaceAll('<|', '< |').replaceAll('|>', '| >') : s;
