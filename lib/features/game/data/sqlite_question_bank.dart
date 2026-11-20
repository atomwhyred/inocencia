import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../../core/storage/untrusted_db.dart';

import '../../quiz/domain/quiz.dart';
import '../domain/game_question.dart';

/// Lee la tabla opcional `game_questions` del `knowledge.db` (solo lectura). La
/// genera `tools/question_bank/build_question_bank.py`; las bases antiguas no la
/// tienen y entonces solo se juega con las tarjetas del nino.
class SqliteQuestionBank implements QuestionBank {
  SqliteQuestionBank.open(String path)
    : _db = openUntrustedDb(path) {
    _available = _db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'game_questions'",
        )
        .isNotEmpty;
  }

  final Database _db;
  late final bool _available;

  @override
  bool get available => _available;

  @override
  List<GameQuestion> forGrade(
    int grade, {
    required int count,
    required Random random,
  }) {
    if (!_available || count <= 0) return const [];
    final rows = _db.select(
      'SELECT subject, book, page, question, a, b, c, correct FROM game_questions WHERE grade = ?',
      [grade],
    );
    final out = <GameQuestion>[
      for (final r in rows)
        GameQuestion(
          quiz: QuizQuestion(
            text: r['question'] as String,
            options: [r['a'] as String, r['b'] as String, r['c'] as String],
            correct: r['correct'] as int,
          ),
          source: [
            r['subject'],
            r['book'],
            if (r['page'] != null) 'pág. ${r['page']}',
          ].whereType<Object>().join(' · '),
        ),
    ]..shuffle(random);
    return out.take(count).toList();
  }

  @override
  void close() => _db.close();
}
