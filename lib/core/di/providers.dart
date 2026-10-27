import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/external_data/data/external_files_repository_impl.dart';
import '../../features/external_data/domain/external_files_repository.dart';
import '../../features/external_data/domain/linked_file_status.dart';
import '../../features/profiles/data/child_profile_repository_impl.dart';
import '../../features/profiles/domain/child_profile.dart';
import '../../features/profiles/domain/child_profile_repository.dart';
import '../../features/setup/data/guardian_repository_impl.dart';
import '../../features/setup/domain/guardian.dart';
import '../security/pin_hasher.dart';
import '../security/pin_lockout.dart';
import '../storage/app_database.dart';

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

final pinLockoutProvider = Provider.family<PinLockout, String>(
  (ref, scope) => PinLockout(ref.watch(sharedPreferencesProvider), scope),
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

// --- Archivos externos (modelo GGUF y base de conocimiento) ---

final externalFilesRepositoryProvider = Provider<ExternalFilesRepository>(
  (ref) => ExternalFilesRepositoryImpl(ref.watch(sharedPreferencesProvider)),
);

/// Si Android pide "Acceso a todos los archivos" y si ya esta concedido.
final allFilesAccessProvider =
    FutureProvider.autoDispose<({bool needed, bool granted})>((ref) async {
  final repo = ref.watch(externalFilesRepositoryProvider);
  return (needed: await repo.needsAllFilesAccess, granted: await repo.hasAllFilesAccess);
});

/// Estado validado de los archivos vinculados. Se invalida tras cada cambio.
final linkedFilesStatusProvider = FutureProvider<LinkedFilesStatus>(
  (ref) => ref.watch(externalFilesRepositoryProvider).check(),
);
