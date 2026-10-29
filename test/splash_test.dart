import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/splash_phrases.dart';
import 'package:inocencia/core/widgets/splash_gate.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.text);

  final String? text;

  @override
  Future<ByteData> load(String key) async {
    if (text == null) throw FlutterError('sin archivo');
    final bytes = Uint8List.fromList(utf8.encode(text!));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  group('SplashPhrases.parse', () {
    test('una frase por línea, sin tocar las buenas', () {
      final p = SplashPhrases.parse('Cada día aprendes algo nuevo\nPreguntar es saber un poco más');
      expect(p, ['Cada día aprendes algo nuevo', 'Preguntar es saber un poco más']);
    });

    test('ignora líneas vacías y comentarios con #', () {
      final p = SplashPhrases.parse('\n   \n# esta no sale en la pantalla\nUna frase con largo suficiente\n');
      expect(p, ['Una frase con largo suficiente']);
    });

    test('descarta lo muy corto y lo muy largo', () {
      final corta = 'a' * (SplashPhrases.minLength - 1);
      final justa = 'b' * SplashPhrases.minLength;
      final larga = 'c' * (SplashPhrases.maxLength + 1);
      final tope = 'd' * SplashPhrases.maxLength;
      expect(SplashPhrases.parse('$corta\n$justa\n$larga\n$tope'), [justa, tope]);
    });

    test('quita la coma o el punto y coma del final y los espacios', () {
      expect(SplashPhrases.parse('  Con calma y paciencia se aprende,  \nOtra frase suficientemente larga;'),
          ['Con calma y paciencia se aprende', 'Otra frase suficientemente larga']);
    });

    test('no repite frases', () {
      expect(SplashPhrases.parse('Esta frase sale una sola vez\nEsta frase sale una sola vez'), hasLength(1));
    });

    test('descarta lo que no es para niños, con o sin tildes y en mayúsculas', () {
      for (final line in [
        'Esto es una mierda de verdad',
        'ESTO ES UNA MIERDA DE VERDAD',
        'Dicen que hay droga en la calle',
        'Hay sangre en el suelo hoy',
        'Lo metieron en la cárcel injusta',
        'Lo metieron en la carcel injusta',
        'Se lo llevó la policía a la prisión',
        'Es la DEA que viene hacia aquí',
      ]) {
        expect(SplashPhrases.parse(line), isEmpty, reason: line);
      }
    });

    test('una palabra prohibida dentro de otra no descarta la línea', () {
      // "armadura" contiene "arma"; "obra" no es nada.
      expect(SplashPhrases.parse('La armadura brillaba con el sol'), hasLength(1));
      expect(SplashPhrases.parse('Aprender es una obra de cada día'), hasLength(1));
    });
  });

  group('el archivo de versos de la app', () {
    late List<String> phrases;
    late List<String> raw;

    setUpAll(() {
      final text = File('assets/frases/ninito_cubano.txt').readAsStringSync();
      raw = text.split(RegExp(r'\r?\n'));
      phrases = SplashPhrases.parse(text);
    });

    test('deja frases suficientes para variar', () {
      expect(raw.length, greaterThan(50));
      expect(phrases.length, greaterThan(20));
    });

    test('todas caben en pantalla', () {
      for (final p in phrases) {
        expect(p.length, inInclusiveRange(SplashPhrases.minLength, SplashPhrases.maxLength));
      }
    });

    test('ninguna lleva palabras vetadas', () {
      for (final p in phrases) {
        expect(SplashPhrases.parse(p), [p]); // pasa el filtro tal cual
        expect(p.toLowerCase(), isNot(contains('mierda')));
      }
    });

    test('son frases del archivo, no inventadas', () {
      final lines = raw.map((l) => l.trim().replaceAll(RegExp(r'[,;:\s]+$'), '')).toSet();
      for (final p in phrases) {
        expect(lines, contains(p));
      }
    });
  });

  group('SplashPhrases.load / pick', () {
    test('lee el archivo del paquete y lo filtra', () async {
      final p = await SplashPhrases.load(_Bundle('Una frase con largo suficiente\nesta es una mierda enorme'));
      expect(p, ['Una frase con largo suficiente']);
    });

    test('sin archivo usa las de respaldo', () async {
      expect(await SplashPhrases.load(_Bundle(null)), SplashPhrases.fallback);
    });

    test('un archivo sin ninguna frase válida usa las de respaldo', () async {
      expect(await SplashPhrases.load(_Bundle('corta\n# comentario')), SplashPhrases.fallback);
    });

    test('las frases de respaldo cumplen sus propias reglas', () {
      expect(SplashPhrases.parse(SplashPhrases.fallback.join('\n')), SplashPhrases.fallback);
    });

    test('pick es de la lista, repetible con la misma semilla y varía con otras', () {
      const list = ['uno uno uno uno uno uno', 'dos dos dos dos dos dos', 'tres tres tres tres tres'];
      expect(SplashPhrases.pick(list, Random(1)), SplashPhrases.pick(list, Random(1)));
      final seen = {for (var seed = 0; seed < 40; seed++) SplashPhrases.pick(list, Random(seed))};
      expect(seen, unorderedEquals(list));
    });

    test('pick con la lista vacía no falla', () {
      expect(SplashPhrases.pick(const [], Random(0)), SplashPhrases.fallback.first);
    });
  });

  group('SplashGate', () {
    const phrases = [
      'Primera frase de prueba larga',
      'Segunda frase de prueba larga',
      'Tercera frase de prueba larga',
    ];

    Widget app({int seed = 0}) => ProviderScope(
          key: ValueKey(seed), // un arranque nuevo por semilla
          overrides: [
            splashPhrasesProvider.overrideWithValue(phrases),
            splashRandomProvider.overrideWithValue(Random(seed)),
          ],
          child: const MaterialApp(
            home: SplashGate(child: Scaffold(body: Center(child: Text('la app')))),
          ),
        );

    testWidgets('muestra la frase elegida abajo y se retira sola', (tester) async {
      await tester.pumpWidget(app());
      final expected = SplashPhrases.pick(phrases, Random(0));
      expect(find.text('“$expected”'), findsOneWidget);
      // La app ya está debajo, cargando.
      expect(find.text('la app', skipOffstage: false), findsOneWidget);

      // La frase va en la zona inferior, centrada.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final center = tester.getCenter(find.byKey(const Key('splash_phrase')));
      expect(center.dy, greaterThan(size.height * 0.7));
      expect(center.dx, closeTo(size.width / 2, 1));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('splash_phrase')), findsNothing);
      expect(find.text('la app'), findsOneWidget);
    });

    testWidgets('dura lo previsto y no deja temporizadores pendientes', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(SplashGate.duration * 0.5);
      expect(find.byKey(const Key('splash_phrase')), findsOneWidget);
      await tester.pump(SplashGate.duration);
      await tester.pump();
      expect(find.byKey(const Key('splash_phrase')), findsNothing);
    });

    testWidgets('con otra semilla sale otra frase', (tester) async {
      final seen = <String>{};
      for (final seed in [0, 1, 2, 3, 4, 5, 6, 7]) {
        await tester.pumpWidget(app(seed: seed));
        seen.add(tester.widget<Text>(find.byKey(const Key('splash_phrase'))).data!);
        await tester.pumpAndSettle();
      }
      expect(seen.length, greaterThan(1));
    });

    testWidgets('con la lista vacía usa una frase de respaldo', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [splashPhrasesProvider.overrideWithValue(const [])],
        child: const MaterialApp(home: SplashGate(child: Scaffold())),
      ));
      expect(find.text('“${SplashPhrases.fallback.first}”'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
