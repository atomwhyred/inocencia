import 'dart:math';

/// Textos amables para el aviso; se elige uno al azar para que no sea siempre
/// el mismo. `{name}` se sustituye por el nombre del nino.
const _withName = [
  ('¡Hola, {name}! 👋', 'Tu tutor te está esperando. ¿Aprendemos algo nuevo hoy?'),
  ('¡Buenos días, {name}! ☀️', 'Es un buen momento para estudiar un ratito con tu tutor.'),
  ('{name}, ¡a explorar! 🚀', 'Hoy hay cosas nuevas por descubrir. ¡Ven a verlas!'),
  ('¿Listo, {name}? ✨', 'Un ratito de estudio y te sentirás genial. ¡Tu tutor te espera!'),
  ('¡Eh, {name}! 🌟', 'Tu tutor tiene preguntas muy divertidas para ti.'),
  ('Hora de aprender, {name} 📚', 'Con calma y a tu ritmo. ¡Vamos a empezar!'),
];

const _generic = [
  ('¡Hola! 👋', 'Tu tutor te está esperando. ¿Aprendemos algo nuevo hoy?'),
  ('¡Buenos días! ☀️', 'Es un buen momento para estudiar un ratito con tu tutor.'),
  ('¡A explorar! 🚀', 'Hoy hay cosas nuevas por descubrir. ¡Ven a verlas!'),
  ('Hora de aprender 📚', 'Con calma y a tu ritmo. ¡Vamos a empezar!'),
];

/// Titulo y cuerpo del aviso. Sin [childName] usa un texto general.
({String title, String body}) reminderText({String? childName, Random? random}) {
  final r = random ?? Random();
  final name = childName?.trim();
  if (name == null || name.isEmpty) {
    final (title, body) = _generic[r.nextInt(_generic.length)];
    return (title: title, body: body);
  }
  final (title, body) = _withName[r.nextInt(_withName.length)];
  return (title: title.replaceAll('{name}', name), body: body.replaceAll('{name}', name));
}
