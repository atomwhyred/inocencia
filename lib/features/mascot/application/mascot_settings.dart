import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

/// Si el padre quiere ver a Toco en el chat. Se puede apagar en teléfonos
/// lentos o que se calientan: sin mascota el chat funciona igual.
class MascotEnabledController extends Notifier<bool> {
  static const _key = 'mascot_enabled';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final mascotEnabledProvider =
    NotifierProvider<MascotEnabledController, bool>(MascotEnabledController.new);

/// Si Toco se mueve. Las pruebas lo apagan: una animación que nunca termina
/// colgaría `pumpAndSettle`. Aun encendido, se respeta "quitar animaciones" de
/// Android (`MediaQuery.disableAnimations`).
final mascotAnimateProvider = Provider<bool>((ref) => true);
