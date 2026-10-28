import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/mascot/domain/mascot_mood.dart';
import 'package:inocencia/features/tutor/application/tutor_controller.dart';
import 'package:inocencia/features/tutor/domain/tutor_prompt.dart';

TutorMessage tutor(String text, {bool streaming = false}) =>
    TutorMessage(fromUser: false, text: text, streaming: streaming);
TutorMessage child(String text) => TutorMessage(fromUser: true, text: text);

TutorState ready(List<TutorMessage> messages) =>
    TutorState(status: TutorStatus.ready, messages: messages);

void main() {
  group('verdictOf', () {
    test('reconoce una valoración positiva en la primera frase', () {
      for (final t in [
        '¡Muy bien! Ahora dime: ¿qué es un sustantivo?',
        '¡Correcto! El sustantivo nombra cosas.',
        'Exacto, es un adjetivo. ¿Y este?',
        '¡Excelente respuesta!',
        '¡Eso es! Sigamos.',
        'Así es. ¿Por qué crees?',
        '¡Perfecto!',
        '¡Felicidades, lo lograste!',
        'Tienes razón.',
        '¡Buen trabajo! ¿Y el plural?',
      ]) {
        expect(verdictOf(t), Verdict.positive, reason: t);
      }
    });

    test('reconoce que el niño casi acierta o falla', () {
      for (final t in [
        'Casi. Fíjate en el libro: ¿qué dice?',
        'Casi, pero no del todo. ¿Qué es un verbo?',
        'No exactamente. Mira otra vez.',
        'No es correcto, pero vas bien.',
        'Ojo, eso no es así. ¿Lo pensamos?',
        'Todavía no. Te doy una pista.',
        'Uy, casi lo tienes.',
        'Incorrecto, repasemos.',
      ]) {
        expect(verdictOf(t), Verdict.negative, reason: t);
      }
    });

    test('lo negativo gana a lo positivo ("no es correcto" contiene "correcto")', () {
      expect(verdictOf('No es correcto, pero buen intento.'), Verdict.negative);
      expect(verdictOf('No exactamente, ¡muy bien por intentarlo!'), Verdict.negative);
    });

    test('ante la duda no hay veredicto', () {
      for (final t in [
        '',
        'Veamos qué dice el libro. ¿Qué es un sustantivo?',
        'Los sustantivos nombran personas, animales y cosas. ¿Puedes dar un ejemplo?',
        'Bien, empecemos por lo básico.',
        'Anímate, te doy una pista: piensa en la palabra casa.',
      ]) {
        expect(verdictOf(t), isNull, reason: t);
      }
    });

    test('solo mira la primera frase', () {
      expect(verdictOf('Veamos. ¡Muy bien!'), isNull);
      expect(verdictOf('Las plantas fabrican su alimento. Casi nadie lo sabe.'), isNull);
    });

    test('no distingue mayúsculas ni tildes ni signos de apertura', () {
      expect(verdictOf('¡MUY BIEN!'), Verdict.positive);
      expect(verdictOf('Eso ES correcto'), Verdict.positive);
      expect(verdictOf('¡Fantástico!'), Verdict.positive);
    });
  });

  group('moodFor: actividad', () {
    test('cargando el modelo duerme', () {
      expect(moodFor(const TutorState()).activity, MascotActivity.sleeping);
      expect(moodFor(const TutorState(status: TutorStatus.loading)).activity, MascotActivity.sleeping);
    });

    test('sin archivos o con error está triste', () {
      expect(moodFor(const TutorState(status: TutorStatus.needsFiles)).activity, MascotActivity.sad);
      expect(moodFor(const TutorState(status: TutorStatus.error)).activity, MascotActivity.sad);
    });

    test('listo y sin mensajes saluda (idle)', () {
      expect(moodFor(ready(const [])), const MascotMood(MascotActivity.idle));
    });

    test('piensa hasta que llega la primera palabra y luego habla', () {
      expect(moodFor(ready([child('hola'), tutor('', streaming: true)])).activity, MascotActivity.thinking);
      expect(moodFor(ready([child('hola'), tutor('Los', streaming: true)])).activity, MascotActivity.talking);
    });

    test('al terminar de hablar queda quieta; con "replying" y una pregunta, escucha', () {
      final done = ready([child('qué es'), tutor('Es un nombre. ¿Puedes dar un ejemplo?')]);
      expect(moodFor(done).activity, MascotActivity.idle);
      expect(moodFor(done, replying: true).activity, MascotActivity.listening);
    });

    test('replying sin pregunta final no escucha', () {
      final done = ready([child('qué es'), tutor('Es un nombre.')]);
      expect(moodFor(done, replying: true).activity, MascotActivity.idle);
    });

    test('un mensaje de error o sin resultados es triste', () {
      expect(moodFor(ready([child('x'), tutor(TutorPrompt.noResults(6, ['Español']))])).activity,
          MascotActivity.sad);
      expect(moodFor(ready([child('x'), tutor(TutorPrompt.errorText)])).activity, MascotActivity.sad);
      expect(moodFor(ready([child('x'), tutor(TutorPrompt.emptyAnswerText)])).activity, MascotActivity.sad);
    });

    test('el aviso de error mientras aún se genera no entristece', () {
      expect(moodFor(ready([child('x'), tutor(TutorPrompt.errorText, streaming: true)])).activity,
          MascotActivity.talking);
    });
  });

  group('moodFor: emoción tras la respuesta del niño', () {
    final q = tutor('Los sustantivos nombran cosas. ¿Cuál es un sustantivo: casa o correr?');

    test('contesta bien: contenta', () {
      final m = moodFor(ready([child('hola'), q, child('casa'), tutor('¡Muy bien! ¿Y un adjetivo?')]));
      expect(m, const MascotMood(MascotActivity.idle, MascotEmotion.happy));
    });

    test('contesta mal: preocupada, sin regañar', () {
      final m = moodFor(ready([child('hola'), q, child('correr'), tutor('Casi. Mira el libro. ¿Qué nombra?')]));
      expect(m.emotion, MascotEmotion.concerned);
    });

    test('se nota ya mientras habla', () {
      final m = moodFor(ready([child('hola'), q, child('casa'), tutor('¡Muy bi', streaming: true)]));
      // Aun no hay una frase valorable: neutral, pero ya habla.
      expect(m, const MascotMood(MascotActivity.talking));
      final m2 = moodFor(ready([child('hola'), q, child('casa'), tutor('¡Muy bien! Ahora', streaming: true)]));
      expect(m2, const MascotMood(MascotActivity.talking, MascotEmotion.happy));
    });

    test('si el niño pregunta en vez de contestar, no hay emoción aunque el tutor diga "muy bien"', () {
      final m = moodFor(ready([
        child('hola'),
        q,
        child('¿qué es un verbo?'),
        tutor('¡Muy buena pregunta! Un verbo es una acción. ¿Cuál es?'),
      ]));
      expect(m.emotion, MascotEmotion.neutral);
    });

    test('un "no sé" se contesta con una pista: neutral', () {
      final m = moodFor(ready([child('hola'), q, child('no sé'), tutor('Tranquilo, te doy una pista. ¿Qué es casa?')]));
      expect(m.emotion, MascotEmotion.neutral);
    });

    test('la primera respuesta del tutor (no hay pregunta previa) es neutral', () {
      final m = moodFor(ready([child('hola'), tutor('¡Muy bien! ¿Empezamos?')]));
      expect(m.emotion, MascotEmotion.neutral);
    });

    test('al empezar a escuchar la siguiente respuesta, la emoción se quita', () {
      final msgs = [child('hola'), q, child('casa'), tutor('¡Muy bien! ¿Y un adjetivo?')];
      expect(moodFor(ready(msgs), replying: true), const MascotMood(MascotActivity.listening));
    });
  });
}
