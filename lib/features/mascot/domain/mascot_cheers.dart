/// Mensajes con los que Toco anima al nino cuando lo toca. Todos prometen un
/// juego para despues de estudiar.
const mascotCheers = <String>[
  '¡Vas muy bien! Sigue así y después jugamos un ratito.',
  '¡Tú puedes! Cuando terminemos, te toca un juego.',
  '¡Qué buen trabajo! Un poquito más y jugamos juntos.',
  '¡Me encanta cómo piensas! Después tenemos un juego, ¿vale?',
  '¡Ánimo, campeón! Al terminar, jugamos.',
];

/// Mensaje numero [n] (da la vuelta al llegar al final).
String mascotCheer(int n) => mascotCheers[n % mascotCheers.length];
