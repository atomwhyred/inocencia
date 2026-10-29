import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/power_mode.dart';

/// Interruptor rapido del modo Bateria / Apagon para la barra superior.
class PowerToggle extends ConsumerWidget {
  const PowerToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(batterySaverProvider);
    return IconButton(
      tooltip: on ? 'Apagar el modo ahorro de batería' : 'Ahorrar batería',
      isSelected: on,
      icon: const Icon(Icons.battery_saver_outlined),
      selectedIcon: const Icon(Icons.battery_saver_rounded),
      onPressed: () => ref.read(batterySaverProvider.notifier).toggle(),
    );
  }
}

/// Aviso "te queda poca bateria" con un toque para ahorrar. Mira la bateria al
/// abrirse y cada minuto (con `batteryPollProvider`).
class PowerSuggestion extends ConsumerStatefulWidget {
  const PowerSuggestion({super.key});

  @override
  ConsumerState<PowerSuggestion> createState() => _PowerSuggestionState();
}

class _PowerSuggestionState extends ConsumerState<PowerSuggestion> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final every = ref.read(batteryPollProvider);
    if (every != null) {
      _timer = Timer.periodic(every, (_) {
        if (mounted) ref.invalidate(batteryStatusProvider);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(lowBatterySuggestionProvider)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        color: scheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.battery_alert_rounded, color: scheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Queda poca batería. ¿Ahorramos energía?',
                  style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(suggestionDismissedProvider.notifier).dismiss(),
                child: const Text('No, gracias'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                onPressed: () => ref.read(batterySaverProvider.notifier).set(true),
                child: const Text('Ahorrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
