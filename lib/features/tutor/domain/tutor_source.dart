import 'package:equatable/equatable.dart';

import '../../knowledge/domain/knowledge_chunk.dart';

/// Libro y pagina en los que se apoya una respuesta del tutor. [page] cuenta
/// desde 1 sobre el PDF (igual que `chunks.page`), asi que sirve para abrir el
/// libro en esa pagina.
class TutorSource extends Equatable {
  const TutorSource({required this.subject, this.book, this.page});

  factory TutorSource.fromChunk(KnowledgeChunk c) =>
      TutorSource(subject: c.subject, book: c.book, page: c.page);

  factory TutorSource.fromJson(Map<String, Object?> json) => TutorSource(
        subject: json['subject'] as String? ?? '',
        book: json['book'] as String?,
        page: json['page'] as int?,
      );

  final String subject;
  final String? book;
  final int? page;

  /// "Español · 4to_esp_II · pág. 60".
  String get label => [
        subject,
        ?book,
        if (page != null) 'pág. $page',
      ].join(' · ');

  Map<String, Object?> toJson() => {
        'subject': subject,
        'book': ?book,
        'page': ?page,
      };

  @override
  List<Object?> get props => [subject, book, page];
}
