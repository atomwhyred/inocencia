import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/utils/format_bytes.dart';

/// Que archivo se busca.
class BrowseRequest {
  const BrowseRequest({
    required this.title,
    required this.extensions,
    this.pickFolder = false,
  });

  final String title;
  final List<String> extensions;

  /// Se elige la carpeta abierta (boton "Usar esta carpeta"), no un archivo; los
  /// archivos con la extension se muestran solo para reconocer la carpeta.
  final bool pickFolder;
}

/// Explorador de rutas sencillo: se navega por carpetas y se elige un archivo
/// con la extension pedida. Devuelve la ruta con `context.pop(path)`.
///
/// No copia nada: el modelo y los libros pesan GB y se usan donde estan.
class PathBrowserPage extends ConsumerStatefulWidget {
  const PathBrowserPage({super.key, required this.request});

  final BrowseRequest request;

  @override
  ConsumerState<PathBrowserPage> createState() => _PathBrowserPageState();
}

class _PathBrowserPageState extends ConsumerState<PathBrowserPage> {
  List<String> _roots = const [];
  String? _current;
  List<FileSystemEntity> _entries = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final roots = await ref.read(externalFilesRepositoryProvider).browseRoots();
    if (!mounted) return;
    _roots = roots;
    if (roots.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No hay carpetas disponibles.';
      });
      return;
    }
    await _open(roots.first);
  }

  Future<void> _open(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await Directory(path).list(followLinks: false).toList();
      final dirs = <FileSystemEntity>[];
      final files = <FileSystemEntity>[];
      for (final e in all) {
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue;
        if (e is Directory) {
          dirs.add(e);
        } else if (e is File &&
            widget.request.extensions.contains(p.extension(name).toLowerCase())) {
          files.add(e);
        }
      }
      int byName(FileSystemEntity a, FileSystemEntity b) =>
          p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      dirs.sort(byName);
      files.sort(byName);
      if (!mounted) return;
      setState(() {
        _current = path;
        _entries = [...dirs, ...files];
        _loading = false;
      });
    } on FileSystemException {
      if (!mounted) return;
      setState(() {
        _current = path;
        _entries = const [];
        _loading = false;
        _error = 'No se puede abrir esta carpeta. Puede que falte el permiso de '
            '“Acceso a todos los archivos”.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Scaffold(
      appBar: AppBar(title: Text(widget.request.title)),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 720,
          child: Column(
            children: [
              if (_roots.length > 1)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      for (final r in _roots)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.sd_storage_rounded, size: 18),
                            label: Text(_rootLabel(r)),
                            onPressed: () => _open(r),
                          ),
                        ),
                    ],
                  ),
                ),
              if (current != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_upward_rounded),
                  title: Text(
                    current,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  subtitle: const Text('Subir un nivel'),
                  enabled: current != '/' && p.dirname(current) != current,
                  onTap: () => _open(p.dirname(current)),
                ),
              const Divider(height: 1),
              Expanded(child: _body()),
              if (widget.request.pickFolder && current != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.pop(current),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        'Usar esta carpeta (${_entries.whereType<File>().length} PDF)',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _rootLabel(String path) {
    if (path.contains('/Android/data/')) {
      return path.startsWith('/storage/emulated/0') ? 'Carpeta de la app' : 'Carpeta de la app (SD)';
    }
    return path == '/storage/emulated/0' ? 'Almacenamiento' : p.basename(path);
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No hay carpetas ni archivos ${widget.request.extensions.join(' / ')} aquí.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (_, i) {
        final e = _entries[i];
        final name = p.basename(e.path);
        if (e is Directory) {
          return ListTile(
            leading: const Icon(Icons.folder_rounded),
            title: Text(name),
            onTap: () => _open(e.path),
          );
        }
        final size = (e as File).lengthSync();
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(name),
          subtitle: Text(formatBytes(size)),
          enabled: !widget.request.pickFolder,
          onTap: () => context.pop(e.path),
        );
      },
    );
  }
}
