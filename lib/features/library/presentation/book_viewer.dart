import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

/// Lo que el lector necesita del visor de PDF. Existe para poder sustituir
/// PDFium en las pruebas de widgets (que no pueden cargar la biblioteca nativa);
/// la app usa [PdfBookViewerFactory].
abstract class BookViewerController {
  bool get isReady;
  int get pageCount;

  /// Lleva el visor a la pagina [page] (desde 1).
  Future<void> goToPage(int page);
}

class BookViewerRequest {
  const BookViewerRequest({
    required this.path,
    required this.initialPage,
    required this.controller,
    required this.onPageChanged,
    required this.background,
  });

  final String path;
  final int initialPage;
  final BookViewerController controller;
  final ValueChanged<int?> onPageChanged;
  final Color background;
}

abstract class BookViewerFactory {
  BookViewerController createController();
  Widget build(BuildContext context, BookViewerRequest request);
}

final bookViewerFactoryProvider =
    Provider<BookViewerFactory>((ref) => const PdfBookViewerFactory());

/// Visor real, con `pdfrx` (PDFium).
class PdfBookViewerFactory implements BookViewerFactory {
  const PdfBookViewerFactory();

  @override
  BookViewerController createController() => _PdfController();

  @override
  Widget build(BuildContext context, BookViewerRequest request) {
    final controller = request.controller as _PdfController;
    return PdfViewer.file(
      request.path,
      controller: controller.pdf,
      initialPageNumber: request.initialPage,
      params: PdfViewerParams(
        backgroundColor: request.background,
        margin: 12,
        onPageChanged: request.onPageChanged,
        loadingBannerBuilder: (context, _, _) => const Center(child: CircularProgressIndicator()),
        errorBannerBuilder: (context, error, stack, ref) => BookViewerError(error: error),
      ),
    );
  }
}

class _PdfController implements BookViewerController {
  final pdf = PdfViewerController();

  @override
  bool get isReady => pdf.isReady;

  @override
  int get pageCount => pdf.pageCount;

  @override
  Future<void> goToPage(int page) => pdf.goToPage(pageNumber: page);
}

/// El archivo no se pudo abrir (copia incompleta o dañada).
class BookViewerError extends StatelessWidget {
  const BookViewerError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text('No se pudo abrir el libro.',
                  style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'Puede que el archivo esté incompleto. Pide a un adulto que lo copie de nuevo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}
