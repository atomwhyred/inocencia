/// Convierte la pregunta de un nino en una consulta FTS5.
///
/// El tokenizador de la base ignora mayusculas y tildes, asi que aqui solo hay
/// que quitar palabras vacias y acortar cada termino (un "stemming" muy
/// simple) para que "adjetivos" encuentre "adjetivo".
library;

const _stopwords = <String>{
  // articulos, preposiciones, pronombres y conjunciones
  'el',
  'la',
  'los',
  'las',
  'un',
  'una',
  'unos',
  'unas',
  'lo',
  'al',
  'del',
  'de',
  'en', 'y', 'o', 'u', 'e', 'a', 'ante', 'con', 'por', 'para', 'sin', 'sobre',
  'entre', 'hasta', 'desde', 'hacia', 'segun', 'que', 'se', 'su', 'sus', 'mi',
  'mis', 'tu', 'tus', 'me', 'te', 'le', 'les', 'nos', 'yo', 'ella',
  'ellos', 'ellas', 'nosotros', 'este', 'esta', 'esto', 'estos', 'estas', 'ese',
  'esa', 'eso', 'esos', 'esas', 'aquel', 'aquella', 'otro', 'otra', 'otros',
  'otras', 'mas', 'muy', 'pero', 'como', 'si', 'no', 'ni', 'ya', 'tambien',
  'tan', 'tanto', 'todo', 'todos', 'toda', 'todas', 'algo', 'alguno', 'algun',
  'nada', 'cada', 'mucho', 'muchos', 'poco', 'pocos',
  // interrogativos
  'cual', 'cuales', 'cuando', 'donde', 'quien', 'quienes', 'cuanto', 'cuantos',
  'cuanta', 'cuantas', 'porque',
  // verbos muy comunes
  'es', 'son', 'soy', 'eres', 'ser', 'estan', 'estar', 'hay', 'tiene',
  'tienen', 'tener', 'hace', 'hacen', 'hacer', 'puede', 'pueden', 'poder',
  'puedes', 'quiero', 'quieres', 'saber', 'sabes', 'sabe', 'significa',
  // peticiones tipicas de un nino al tutor
  'dime', 'dimelo', 'explica', 'explicame', 'explicar', 'ayuda', 'ayudame',
  'ayudar', 'cuentame', 'ensename', 'ensenar', 'hola', 'gracias', 'favor',
  'porfa', 'quisiera', 'necesito', 'entiendo', 'entender', 'ejemplo',
  'ejemplos', 'tema', 'pregunta', 'respuesta',
};

final _word = RegExp(r'[a-záéíóúüñ0-9]+');

String _fold(String s) => s
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u');

/// Terminos utiles de [text], sin repetidos y por orden de aparicion.
List<String> keyTerms(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final m in _word.allMatches(text.toLowerCase())) {
    final w = m.group(0)!;
    final plain = _fold(w);
    if (w.length < 3 || _stopwords.contains(plain)) continue;
    if (RegExp(r'^\d+$').hasMatch(w)) continue; // numeros sueltos: solo ruido
    if (seen.add(plain)) out.add(w);
  }
  return out;
}

/// Acorta el termino para que coincida con sus variantes (plural, genero...).
/// Devuelve el fragmento de FTS5 ya entrecomillado.
String _term(String w) {
  final cut = w.length >= 6
      ? w.length - 2
      : w.length >= 4
      ? w.length - 1
      : 0;
  if (cut == 0) return '"$w"';
  final stem = w.substring(0, cut < 4 ? 4 : cut);
  return '"$stem"*';
}

/// Consulta FTS5 que exige **todos** los terminos (los [maxTerms] mas largos,
/// que suelen ser los mas especificos). Vacia si no hay terminos utiles.
String ftsAllQuery(String question, {int maxTerms = 4}) {
  final terms = _longest(keyTerms(question), maxTerms);
  return terms.map(_term).join(' AND ');
}

/// Consulta FTS5 que acepta **cualquiera** de los terminos (rescate cuando la
/// consulta estricta no encuentra nada suficiente).
String ftsAnyQuery(String question, {int maxTerms = 6}) {
  final terms = _longest(keyTerms(question), maxTerms);
  return terms.map(_term).join(' OR ');
}

List<String> _longest(List<String> terms, int max) {
  if (terms.length <= max) return terms;
  final byLength = [...terms]..sort((a, b) => b.length.compareTo(a.length));
  final keep = byLength.take(max).toSet();
  return terms.where(keep.contains).toList(); // conserva el orden original
}
