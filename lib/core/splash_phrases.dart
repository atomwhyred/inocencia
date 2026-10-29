import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Las frases de la pantalla de bienvenida. Salen del archivo de versos
/// `assets/frases/ninito_cubano.txt` (un verso por linea) y se elige una al azar
/// cada vez que se abre la app.
///
/// El archivo se puede editar: se ignoran las lineas vacias y las que empiezan por
/// `#`. Como la app es para ninos, tambien se descartan las lineas demasiado cortas
/// o largas para el espacio de la pantalla y las que llevan palabras que no
/// corresponden a una app infantil ([_blocked]).
class SplashPhrases {
  const SplashPhrases._();

  static const assetPath = 'assets/frases/ninito_cubano.txt';

  /// Entre estos largos cabe en una o dos lineas bajo el logo.
  static const minLength = 20;
  static const maxLength = 70;

  /// Si el archivo falta o no deja ninguna frase valida.
  static const fallback = [
    'Cada día aprendes algo nuevo.',
    'Preguntar es el primer paso para saber.',
    'Con calma y paciencia, todo se aprende.',
    'Equivocarse también es aprender.',
    'Hoy es un buen día para descubrir algo.',
  ];

  /// Palabras (sin tildes, en minusculas) que descartan una linea.
  static const _blocked = [
    // Vulgaridades.
    'mierda', 'coño', 'cono', 'joder', 'puta', 'puto', 'putas', 'carajo', 'cojones', 'cojon',
    'pinga', 'culo', 'cabron', 'maricon', 'verga', 'chingar', 'coñazo', 'gilipollas',
    // Drogas y alcohol.
    'droga', 'drogas', 'cocaina', 'marihuana', 'dea', 'crack', 'heroina', 'porro', 'borracho',
    // Violencia y armas.
    'matar', 'mato', 'muerte', 'muerto', 'muertos', 'sangre', 'arma', 'armas', 'bala', 'balas',
    'pistola', 'cuchillo', 'asesino', 'asesinar', 'violar', 'violencia',
    // Sexo.
    'sexo', 'sexual', 'prostituta', 'prostitucion', 'desnudo',
    // Carcel.
    'carcel', 'preso', 'presos', 'prision',
  ];

  static final _blockedWords = RegExp('\\b(${_blocked.join('|')})\\b');

  /// Las frases validas de [text] (un verso por linea).
  static List<String> parse(String text) {
    final result = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim().replaceAll(RegExp(r'[,;:\s]+$'), '');
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.length < minLength || line.length > maxLength) continue;
      if (_blockedWords.hasMatch(_plain(line))) continue;
      if (!result.contains(line)) result.add(line);
    }
    return result;
  }

  /// Lee y filtra el archivo de frases; si no hay ninguna valida, [fallback].
  static Future<List<String>> load(AssetBundle bundle) async {
    try {
      final phrases = parse(await bundle.loadString(assetPath));
      return phrases.isEmpty ? fallback : phrases;
    } catch (_) {
      return fallback;
    }
  }

  static String pick(List<String> phrases, Random random) =>
      phrases.isEmpty ? fallback.first : phrases[random.nextInt(phrases.length)];

  static String _plain(String s) {
    const from = 'áéíóúüÁÉÍÓÚÜ';
    const to = 'aeiouuaeiouu';
    final buf = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final c = String.fromCharCode(r);
      final i = from.indexOf(c);
      buf.write(i >= 0 ? to[i] : c);
    }
    return buf.toString();
  }
}

/// Las frases disponibles. `main` lo sobrescribe con las del archivo; en las
/// pruebas son las de respaldo (nada asincrono que esperar).
final splashPhrasesProvider = Provider<List<String>>((ref) => SplashPhrases.fallback);

/// Azar de la frase (inyectable para fijarlo en las pruebas).
final splashRandomProvider = Provider<Random>((ref) => Random());
