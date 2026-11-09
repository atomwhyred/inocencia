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

/// Mira la bateria al abrirse y cada minuto (con `batteryPollProvider`) mientras
/// [child] esta en pantalla. El aviso lo pinta [LowBatteryMessage] donde toque.
class BatteryWatcher extends ConsumerStatefulWidget {
  const BatteryWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BatteryWatcher> createState() => _BatteryWatcherState();
}

class _BatteryWatcherState extends ConsumerState<BatteryWatcher> {
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
  Widget build(BuildContext context) => widget.child;
}

/// Lo que dice Toco con poca bateria: la pregunta y, debajo, los dos botones.
/// Sin fondo propio: va dentro del globo de Toco (inicio) o de una burbuja del
/// tutor (chat). Solo se pinta si `lowBatterySuggestionProvider` lo pide.
class LowBatteryMessage extends ConsumerWidget {
  const LowBatteryMessage({super.key, this.center = false});

  static const text = 'Queda poca batería. ¿Ahorramos energía?';

  /// Texto y botones centrados (globo del inicio) o a la izquierda (chat).
  final bool center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.battery_alert_rounded, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  textAlign: center ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: center ? WrapAlignment.center : WrapAlignment.start,
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: () => ref.read(suggestionDismissedProvider.notifier).dismiss(),
                child: const Text('No, gracias'),
              ),
              FilledButton.icon(
                onPressed: () => ref.read(batterySaverProvider.notifier).set(true),
                icon: const Icon(Icons.battery_saver_rounded),
                label: const Text('Ahorrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
