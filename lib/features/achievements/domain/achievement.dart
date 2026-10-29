import 'package:flutter/material.dart';

/// Una medalla del catalogo (fijo, en el codigo).
class Achievement {
  const Achievement({
    required this.code,
    required this.title,
    required this.hint,
    required this.icon,
  });

  final String code;
  final String title;

  /// Como se gana (se muestra tambien en las que aun no se tienen).
  final String hint;
  final IconData icon;
}

/// Contadores guardados por nino; de ellos salen las medallas.
class Counters {
  const Counters._();

  static const topics = 'topics';
  static const quizzes = 'quizzes';
  static const correct = 'correct';
  static const streak = 'streak';
  static const lastDay = 'last_day';
}

class Medals {
  const Medals._();

  static const firstTopic = Achievement(
    code: 'first_topic',
    title: 'Primer tema',
    hint: 'Aprende tu primer tema con el tutor',
    icon: Icons.auto_stories_rounded,
  );
  static const firstQuiz = Achievement(
    code: 'first_quiz',
    title: 'Primer quiz',
    hint: 'Termina tu primer quiz',
    icon: Icons.quiz_rounded,
  );
  static const correct5 = Achievement(
    code: 'correct_5',
    title: '5 aciertos',
    hint: 'Acierta 5 preguntas de los quizzes',
    icon: Icons.star_rounded,
  );
  static const correct20 = Achievement(
    code: 'correct_20',
    title: 'Sabio',
    hint: 'Acierta 20 preguntas de los quizzes',
    icon: Icons.emoji_events_rounded,
  );
  static const perfectQuiz = Achievement(
    code: 'perfect_quiz',
    title: 'Quiz perfecto',
    hint: 'Acierta todas las preguntas de un quiz',
    icon: Icons.workspace_premium_rounded,
  );
  static const sessionDone = Achievement(
    code: 'session_done',
    title: 'Sesión completada',
    hint: 'Estudia un bloque entero hasta el descanso',
    icon: Icons.timer_rounded,
  );
  static const streak3 = Achievement(
    code: 'streak_3',
    title: 'Tres días seguidos',
    hint: 'Estudia tres días seguidos',
    icon: Icons.local_fire_department_rounded,
  );

  static const all = [
    firstTopic,
    firstQuiz,
    correct5,
    perfectQuiz,
    sessionDone,
    streak3,
    correct20,
  ];

  static Achievement? byCode(String code) {
    for (final a in all) {
      if (a.code == code) return a;
    }
    return null;
  }
}

/// Lo que un nino lleva ganado.
class ChildProgress {
  const ChildProgress({this.earned = const {}, this.stars = 0});

  /// Codigo de la medalla -> cuando se gano.
  final Map<String, DateTime> earned;

  /// Una estrella por cada pregunta de quiz acertada.
  final int stars;
}
