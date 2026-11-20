import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/external_data/data/external_files_repository_impl.dart';
import '../../features/external_data/data/file_exporter_impl.dart';
import '../../features/external_data/domain/external_files_repository.dart';
import '../../features/external_data/domain/file_exporter.dart';
import '../../features/external_data/domain/linked_file_status.dart';
import '../../features/library/data/library_repository_impl.dart';
import '../../features/library/data/reading_progress_repository_impl.dart';
import '../../features/library/domain/library_repository.dart';
import '../../features/library/domain/reading_progress_repository.dart';
import '../../features/profiles/data/child_profile_repository_impl.dart';
import '../../features/profiles/domain/child_profile.dart';
import '../../features/profiles/domain/child_profile_repository.dart';
import '../../features/setup/data/guardian_repository_impl.dart';
import '../../features/setup/domain/guardian.dart';
import '../../features/tutor/data/tutor_history_repository_impl.dart';
import '../../features/tutor/domain/tutor_history_repository.dart';
import '../security/pin_hasher.dart';
import '../security/pin_lockout.dart';
import '../storage/app_database.dart';
import '../storage/platform_info.dart';

/// Se sobrescribe en `main()` con la instancia ya cargada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider sin sobrescribir'),
);

/// Reloj inyectable (las pruebas lo fijan).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final pinHasherProvider = Provider<PinHasher>((ref) => const PinHasher());

/// Tiempo desde que se encendió el teléfono (monótono: no cambia al tocar la hora).
/// `main` fija el punto de partida con Android; sin él, cuenta desde que abrió la app.
final uptimeProvider = Provider<Duration Function()>((ref) {
  final sinceStart = Stopwatch()..start();
  return () => sinceStart.elapsed;
});

final pinLockoutProvider = Provider.family<PinLockout, String>(
  (ref, scope) => PinLockout(
    ref.watch(sharedPreferencesProvider),
    scope,
    uptime: ref.watch(uptimeProvider),
  ),
);

// --- Padre/madre ---

final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(pinHasherProvider),
  ),
);

final guardianProvider = StreamProvider<Guardian?>(
  (ref) => ref.watch(guardianRepositoryProvider).watch(),
);

// --- Perfiles infantiles ---

final childProfileRepositoryProvider = Provider<ChildProfileRepository>(
  (ref) => ChildProfileRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(pinHasherProvider),
  ),
);

final childProfilesProvider = StreamProvider<List<ChildProfile>>(
  (ref) => ref.watch(childProfileRepositoryProvider).watchAll(),
);

// --- Conversaciones del tutor ---

final tutorHistoryRepositoryProvider = Provider<TutorHistoryRepository>(
  (ref) => TutorHistoryRepositoryImpl(ref.watch(appDatabaseProvider)),
);

// --- Libros para leer ---

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepositoryImpl(ref.watch(externalFilesRepositoryProvider)),
);

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>(
  (ref) => ReadingProgressRepositoryImpl(ref.watch(appDatabaseProvider)),
);

// --- Archivos externos (modelo GGUF y base de conocimiento) ---

final externalFilesRepositoryProvider = Provider<ExternalFilesRepository>(
  (ref) => ExternalFilesRepositoryImpl(ref.watch(sharedPreferencesProvider)),
);

/// Pasa a otros dispositivos el modelo, la base y los libros (compartir o copiar).
final fileExporterProvider = Provider<FileExporter>((ref) => FileExporterImpl());

/// Si Android pide "Acceso a todos los archivos" y si ya esta concedido.
final allFilesAccessProvider =
    FutureProvider.autoDispose<({bool needed, bool granted})>((ref) async {
  final repo = ref.watch(externalFilesRepositoryProvider);
  return (needed: await repo.needsAllFilesAccess, granted: await repo.hasAllFilesAccess);
});

/// RAM total del telefono (null si no se conoce): decide el modelo recomendado.
final deviceRamProvider = FutureProvider<int?>(
  (ref) => const PlatformInfo().totalRamBytes(),
);

/// Estado validado de los archivos vinculados. Se invalida tras cada cambio.
final linkedFilesStatusProvider = FutureProvider<LinkedFilesStatus>(
  (ref) => ref.watch(externalFilesRepositoryProvider).check(),
);
