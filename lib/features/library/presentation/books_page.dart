import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/max_content_width.dart';
import '../../../core/responsive/window_size_class.dart';
import '../../auth/application/session.dart';
import '../application/library_providers.dart';
import '../domain/library_book.dart';

/// Los libros y cuadernos del grado del nino, para leerlos como libros digitales.
class BooksPage extends ConsumerWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(childBooksProvider);
    final childId = ref.watch(sessionProvider.select((s) => s.activeChildId));
    final progress = childId == null
        ? const <String, int>{}
        : ref.watch(readingProgressProvider(childId)).value ?? const <String, int>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Mis libros')),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 900,
          child: books.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('No se pudieron cargar los libros: $e')),
            data: (list) => list.isEmpty
                ? const _Empty()
                : _BookList(books: list, progress: progress, childId: childId),
          ),
        ),
      ),
    );
  }
}

class _BookList extends ConsumerWidget {
  const _BookList({required this.books, required this.progress, required this.childId});

  final List<LibraryBook> books;
  final Map<String, int> progress;
  final int? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = books.where((b) => b.available).toList();
    final missing = books.where((b) => !b.available).toList();
    final wide = !WindowSizeClass.of(context).isCompact;
    final columns = wide ? 2 : 1;

    Widget grid(List<LibraryBook> list) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final b in list)
              SizedBox(
                width: columns == 1 ? double.infinity : 420,
                child: _BookTile(
                  book: b,
                  page: progress[b.id],
                  onTap: b.available
                      ? () async {
                          await context.push('/books/${b.id}');
                          if (childId != null) ref.invalidate(readingProgressProvider(childId!));
                        }
                      : null,
                ),
              ),
          ],
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (ready.isEmpty)
          const _NoneAvailable()
        else
          grid(ready),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Aún no están en este teléfono',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Pide a un adulto que los copie desde la zona de padres.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          grid(missing),
        ],
      ],
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.page, required this.onTap});

  final LibraryBook book;
  final int? page;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = book.available;
    final fg = available ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.55);
    final subtitle = !available
        ? 'No está en este teléfono'
        : page == null
            ? '${book.pages} páginas'
            : 'Vas por la página $page de ${book.pages}';

    return Semantics(
      button: available,
      label: '${book.title}. $subtitle',
      child: ExcludeSemantics(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 64,
                    decoration: BoxDecoration(
                      color: book.isNotebook ? scheme.tertiaryContainer : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      available
                          ? (book.isNotebook ? Icons.edit_note_rounded : Icons.menu_book_rounded)
                          : Icons.download_for_offline_outlined,
                      color: book.isNotebook
                          ? scheme.onTertiaryContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg)),
                        if (available && page != null) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (page! / (book.pages == 0 ? page! : book.pages)).clamp(0.0, 1.0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (available) Icon(Icons.chevron_right_rounded, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoneAvailable extends StatelessWidget {
  const _NoneAvailable();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay libros en este teléfono.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Pide a un adulto que los copie desde la zona de padres.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'No hay libros para tu grado.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Pide a un adulto que vincule la base de libros en la zona de padres.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}
