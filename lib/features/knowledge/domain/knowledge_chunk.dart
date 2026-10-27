import 'package:equatable/equatable.dart';

/// Fragmento de un libro de texto recuperado de la base de conocimiento.
class KnowledgeChunk extends Equatable {
  const KnowledgeChunk({
    required this.id,
    required this.grade,
    required this.subject,
    required this.book,
    required this.text,
    this.chapter,
    this.page,
  });

  final int id;
  final int grade;
  final String subject;
  final String? book;
  final String? chapter;
  final int? page;
  final String text;

  @override
  List<Object?> get props => [id, grade, subject, book, chapter, page, text];
}

abstract class KnowledgeRepository {
  /// Busca fragmentos relevantes para [question] **solo del grado indicado**
  /// (y de [subject] si se da), de mas a menos relevante.
  Future<List<KnowledgeChunk>> search(
    String question, {
    required int grade,
    String? subject,
    int limit = 3,
  });

  /// Asignaturas que tienen contenido para [grade].
  Future<List<String>> subjectsForGrade(int grade);

  Future<void> close();
}
