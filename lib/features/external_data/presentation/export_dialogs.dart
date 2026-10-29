import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../../library/application/book_export.dart';
import '../domain/file_exporter.dart';
import 'path_browser_page.dart';

/// Abre el menu de compartir de Android con estos archivos.
Future<void> shareItems(
  BuildContext context,
  WidgetRef ref,
  List<ExportItem> items, {
  String? title,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(fileExporterProvider).share(items, title: title);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el menú de compartir. ¿Sigue el archivo en el teléfono?')),
    );
  }
}

/// Pide una carpeta de destino y copia los archivos con una barra de progreso.
Future<void> copyItems(BuildContext context, WidgetRef ref, List<ExportItem> items) async {
  final messenger = ScaffoldMessenger.of(context);
  final dest = await context.push<String>(
    '/admin/browse',
    extra: const BrowseRequest(
      title: 'Elegir la carpeta de destino',
      extensions: ['.gguf', '.db', '.pdf'],
      pickFolder: true,
    ),
  );
  if (dest == null || !context.mounted) return;
  final result = await showDialog<CopyResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CopyDialog(items: items, destDir: dest),
  );
  if (result == null) return;
  final text = result.error != null
      ? result.error!
      : result.cancelled
          ? 'Copia cancelada. No queda ningún archivo a medias.'
          : result.copied == 1
              ? 'Se copió 1 archivo a $dest.'
              : 'Se copiaron ${result.copied} archivos a $dest.';
  messenger.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 6)));
}

/// Copia en segundo plano mientras muestra el avance. Se cierra solo al acabar,
/// con el [CopyResult]; "Cancelar" para la copia y borra lo que lleve a medias.
class CopyDialog extends ConsumerStatefulWidget {
  const CopyDialog({super.key, required this.items, required this.destDir});

  final List<ExportItem> items;
  final String destDir;

  @override
  ConsumerState<CopyDialog> createState() => _CopyDialogState();
}

class _CopyDialogState extends ConsumerState<CopyDialog> {
  final _progress = ValueNotifier<CopyProgress?>(null);
  final _cancel = CopyCancel();
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_run);
  }

  Future<void> _run() async {
    final result = await ref.read(fileExporterProvider).copy(
          widget.items,
          widget.destDir,
          onProgress: (p) => _progress.value = p,
          cancel: _cancel,
        );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Copiando archivos'),
        content: ValueListenableBuilder<CopyProgress?>(
          valueListenable: _progress,
          builder: (_, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: p?.fraction),
              const SizedBox(height: 12),
              if (p == null)
                const Text('Preparando…')
              else ...[
                Text('Archivo ${p.fileIndex} de ${p.fileCount}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(p.fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${formatBytes(p.doneBytes)} de ${formatBytes(p.totalBytes)}'),
              ],
              const SizedBox(height: 8),
              Text('Destino: ${widget.destDir}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _cancelling
                ? null
                : () {
                    setState(() => _cancelling = true);
                    _cancel.cancel();
                  },
            child: Text(_cancelling ? 'Cancelando…' : 'Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// Elige que libros pasar a otro dispositivo: por grado, con el tamano de cada uno.
/// Devuelve los archivos elegidos (sin repetir) o `null` si se cancela.
Future<List<ExportItem>?> pickBooksToExport(BuildContext context, {required String action}) {
  return showDialog<List<ExportItem>>(
    context: context,
    builder: (_) => BooksExportDialog(action: action),
  );
}

class BooksExportDialog extends ConsumerStatefulWidget {
  const BooksExportDialog({super.key, required this.action});

  /// Verbo del boton: "Compartir" o "Copiar".
  final String action;

  @override
  ConsumerState<BooksExportDialog> createState() => _BooksExportDialogState();
}

class _BooksExportDialogState extends ConsumerState<BooksExportDialog> {
  /// `null` = todavia sin tocar: se marcan todos los grados.
  Set<int>? _picked;

  @override
  Widget build(BuildContext context) {
    final exports = ref.watch(gradeExportsProvider);
    return AlertDialog(
      title: Text('${widget.action} libros'),
      content: SizedBox(
        width: 420,
        child: exports.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('No se pudo leer la lista de libros: $e'),
          data: (all) {
            if (all.isEmpty) {
              return const Text('Todavía no hay libros PDF en este teléfono.');
            }
            final picked = _picked ?? {for (final g in all) g.grade};
            final chosen = exportItemsFor(all, picked);
            final bytes = chosen.fold<int>(0, (sum, i) => sum + i.sizeBytes);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Todos los grados', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: picked.length == all.length,
                    onChanged: (v) => setState(
                      () => _picked = v == true ? {for (final g in all) g.grade} : <int>{},
                    ),
                  ),
                  const Divider(height: 1),
                  for (final g in all)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(SchoolGradeCalculator.label(g.grade)),
                      subtitle: Text('${g.count} ${g.count == 1 ? 'libro' : 'libros'} · ${formatBytes(g.bytes)}'),
                      value: picked.contains(g.grade),
                      onChanged: (v) => setState(() {
                        final next = {...picked};
                        v == true ? next.add(g.grade) : next.remove(g.grade);
                        _picked = next;
                      }),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    chosen.isEmpty
                        ? 'No hay ningún grado elegido.'
                        : '${chosen.length} ${chosen.length == 1 ? 'archivo' : 'archivos'} · ${formatBytes(bytes)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: exports.value == null
              ? null
              : () {
                  final all = exports.value!;
                  final items = exportItemsFor(all, _picked ?? {for (final g in all) g.grade});
                  if (items.isEmpty) return;
                  Navigator.pop(context, items);
                },
          child: Text(widget.action),
        ),
      ],
    );
  }
}
