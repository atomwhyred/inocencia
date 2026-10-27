import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../domain/linked_file_status.dart';
import '../domain/model_recommendation.dart';
import 'path_browser_page.dart';

final _storageFoldersProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(externalFilesRepositoryProvider).appStorageDirs(),
);

enum _Kind { model, knowledge }

/// Seccion "Archivos" del panel: estado del modelo GGUF y de la base de
/// conocimiento, y vinculacion manual por ruta.
class FilesSection extends ConsumerWidget {
  const FilesSection({super.key});

  static const _modelExt = ['.gguf'];
  static const _knowledgeExt = ['.db', '.sqlite', '.sqlite3'];

  Future<void> _store(WidgetRef ref, _Kind kind, String? path) async {
    final repo = ref.read(externalFilesRepositoryProvider);
    if (kind == _Kind.model) {
      await repo.setModelPath(path);
    } else {
      await repo.setKnowledgePath(path);
    }
    ref.invalidate(linkedFilesStatusProvider);
  }

  Future<void> _browse(BuildContext context, WidgetRef ref, _Kind kind) async {
    final path = await context.push<String>(
      '/admin/browse',
      extra: BrowseRequest(
        title: kind == _Kind.model ? 'Elegir modelo (.gguf)' : 'Elegir libros (.db)',
        extensions: kind == _Kind.model ? _modelExt : _knowledgeExt,
      ),
    );
    if (path != null) await _store(ref, kind, path);
  }

  Future<void> _detect(BuildContext context, WidgetRef ref, _Kind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final found = await ref.read(externalFilesRepositoryProvider).discover(
          extensions: kind == _Kind.model ? _modelExt : _knowledgeExt,
        );
    if (!context.mounted) return;
    if (found.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se encontró ningún archivo en las carpetas de la app.')),
      );
      return;
    }
    var chosen = found.first;
    if (found.length > 1) {
      final picked = await showDialog<DiscoveredFile>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Archivos encontrados'),
          children: [
            for (final f in found)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, f),
                child: Text('${p.basename(f.path)}  ·  ${formatBytes(f.sizeBytes)}'),
              ),
          ],
        ),
      );
      if (picked == null) return;
      chosen = picked;
    }
    await _store(ref, kind, chosen.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(linkedFilesStatusProvider);
    final folders = ref.watch(_storageFoldersProvider).value ?? const <String>[];
    final access = ref.watch(allFilesAccessProvider).value;
    final ram = ref.watch(deviceRamProvider).value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Archivos de la inteligencia artificial',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'El modelo y los libros no vienen en la app: se copian al teléfono '
          '(por USB, tarjeta SD o una app de transferencia) y se vinculan aquí.',
        ),
        const SizedBox(height: 16),
        _FolderCard(folders: folders),
        const SizedBox(height: 12),
        if (access != null && access.needed && !access.granted)
          _AccessCard(
            // Abre los ajustes de Android; al volver a la app se vuelve a comprobar.
            onRequest: () =>
                ref.read(externalFilesRepositoryProvider).requestAllFilesAccess(),
          ),
        const SizedBox(height: 12),
        status.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('No se pudo comprobar el estado: $e'),
          data: (s) => Column(
            children: [
              if (ram != null) ModelAdviceCard(ramBytes: ram, linkedPath: s.model.path),
              if (ram != null) const SizedBox(height: 12),
              _FileCard(
                icon: Icons.psychology_alt_rounded,
                title: 'Modelo de IA (GGUF)',
                status: s.model,
                onBrowse: () => _browse(context, ref, _Kind.model),
                onDetect: () => _detect(context, ref, _Kind.model),
                onUnlink: () => _store(ref, _Kind.model, null),
              ),
              const SizedBox(height: 12),
              _FileCard(
                icon: Icons.menu_book_rounded,
                title: 'Libros de texto (base de datos)',
                status: s.knowledge,
                details: _knowledgeDetails(s.knowledge),
                onBrowse: () => _browse(context, ref, _Kind.knowledge),
                onDetect: () => _detect(context, ref, _Kind.knowledge),
                onUnlink: () => _store(ref, _Kind.knowledge, null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              ref.invalidate(linkedFilesStatusProvider);
              ref.invalidate(allFilesAccessProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Comprobar de nuevo'),
          ),
        ),
      ],
    );
  }

  String? _knowledgeDetails(KnowledgeDbStatus k) {
    if (!k.isReady) return null;
    final grades = k.grades.map(SchoolGradeCalculator.label).join(', ');
    return '${k.chunkCount} fragmentos · $grades\n${k.subjects.join(', ')}';
  }
}

/// Consejo sobre que modelo usar segun la RAM del telefono.
class ModelAdviceCard extends StatelessWidget {
  const ModelAdviceCard({super.key, required this.ramBytes, this.linkedPath});

  final int ramBytes;
  final String? linkedPath;

  /// En GB decimales, como los anuncia el sitio de descarga (Hugging Face).
  static String _downloadSize(ModelOption m) =>
      '${(m.sizeBytes / 1e9).toStringAsFixed(1).replaceAll('.', ',')} GB';

  @override
  Widget build(BuildContext context) {
    final recommended = ModelRecommendation.forRam(ramBytes);
    final linked = ModelRecommendation.identify(linkedPath);
    final other = ModelRecommendation.all.firstWhere((m) => m != recommended);
    final theme = Theme.of(context);
    final ramGb = (ramBytes / (1024 * 1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_rounded, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Modelo recomendado para este teléfono',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Este teléfono tiene $ramGb GB de memoria RAM.'),
                  if (ModelRecommendation.isLowRam(ramBytes))
                    const Text(
                      'Es poca memoria: la IA puede ir muy lenta o cerrarse.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${recommended.name} (${_downloadSize(recommended)})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(recommended.summary),
                  SelectableText(
                    recommended.fileName,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alternativa: ${other.name} (${_downloadSize(other)}). ${other.summary}',
                  ),
                  if (linked != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      linked == recommended
                          ? 'Ya tienes vinculado el modelo recomendado.'
                          : 'Tienes vinculado ${linked.name}.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folders});

  final List<String> folders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.usb_rounded),
                const SizedBox(width: 8),
                Text('Carpeta para copiar los archivos',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Copia el modelo y los libros en una de estas carpetas '
                '(no necesita permisos):'),
            const SizedBox(height: 8),
            if (folders.isEmpty)
              const Text('No hay carpetas disponibles.')
            else
              for (final f in folders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(f, style: const TextStyle(fontFamily: 'monospace')),
                ),
            const SizedBox(height: 4),
            Text(
              'Si desinstalas la app, esta carpeta se borra con ella.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para buscar archivos fuera de la carpeta de la app (por ejemplo en '
              'Descargas o en la tarjeta SD) Android pide el permiso '
              '“Acceso a todos los archivos”.',
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onRequest,
              child: const Text('Conceder permiso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.onBrowse,
    required this.onDetect,
    required this.onUnlink,
    this.details,
  });

  final IconData icon;
  final String title;
  final LinkedFileStatus status;
  final String? details;
  final VoidCallback onBrowse;
  final VoidCallback onDetect;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, chipIcon) = switch (status.state) {
      LinkState.ready => ('Listo', Colors.green, Icons.check_circle_rounded),
      LinkState.notLinked => ('Sin vincular', scheme.outline, Icons.link_off_rounded),
      LinkState.missing => ('No encontrado', scheme.error, Icons.error_outline_rounded),
      LinkState.invalid => ('No válido', scheme.error, Icons.error_outline_rounded),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                Icon(chipIcon, color: color, size: 20),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            if (status.path != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                status.path!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            if (status.sizeBytes != null)
              Text('Tamaño: ${formatBytes(status.sizeBytes!)}'),
            if (details != null) Text(details!),
            if (status.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(status.message!, style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Buscar'),
                ),
                OutlinedButton.icon(
                  onPressed: onDetect,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Detectar'),
                ),
                if (status.state != LinkState.notLinked)
                  TextButton(onPressed: onUnlink, child: const Text('Quitar vínculo')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
