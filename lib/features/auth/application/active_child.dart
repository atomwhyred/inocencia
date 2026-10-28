import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../profiles/domain/child_profile.dart';
import 'session.dart';

/// El perfil del nino que esta usando la app (null si no hay ninguno elegido o
/// aun se cargan los perfiles).
final activeChildProvider = Provider<ChildProfile?>((ref) {
  final id = ref.watch(sessionProvider.select((s) => s.activeChildId));
  if (id == null) return null;
  return ref.watch(childProfilesProvider).value?.where((c) => c.id == id).firstOrNull;
});

/// Su grado hoy (segun la fecha de nacimiento, o el que fijo el padre).
final activeGradeProvider = Provider<int?>((ref) {
  final child = ref.watch(activeChildProvider);
  return child?.gradeAt(ref.read(clockProvider)());
});
