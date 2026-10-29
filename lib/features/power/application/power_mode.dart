import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/battery_plus_info.dart';
import '../domain/battery_info.dart';

/// Modo "Bateria / Apagon": tema negro puro, sin animaciones y un modelo que
/// usa menos hilos. Lo activa el nino o el padre con un toque; nunca se activa solo.
class BatterySaverController extends Notifier<bool> {
  static const _key = 'battery_saver';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }

  Future<void> toggle() => set(!state);
}

final batterySaverProvider = NotifierProvider<BatterySaverController, bool>(
  BatterySaverController.new,
);

final batteryInfoProvider = Provider<BatteryInfo>((ref) => BatteryPlusInfo());

/// Cada cuanto se mira la bateria mientras hay una pantalla del nino abierta.
/// `null` en las pruebas: un `Timer` periodico quedaria pendiente.
final batteryPollProvider = Provider<Duration?>((ref) => const Duration(minutes: 1));

/// Ultima lectura de la bateria; se refresca con `ref.invalidate`.
final batteryStatusProvider = FutureProvider.autoDispose<BatteryStatus?>(
  (ref) => ref.watch(batteryInfoProvider).read(),
);

/// El nino/padre dijo "no, gracias": no se vuelve a sugerir hasta reiniciar la app.
class SuggestionDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final suggestionDismissedProvider = NotifierProvider<SuggestionDismissed, bool>(
  SuggestionDismissed.new,
);

/// Hay que sugerir el modo ahorro: bateria baja, modo apagado y aun no descartado.
final lowBatterySuggestionProvider = Provider.autoDispose<bool>((ref) {
  if (ref.watch(batterySaverProvider) || ref.watch(suggestionDismissedProvider)) return false;
  return ref.watch(batteryStatusProvider).value?.shouldSave ?? false;
});
