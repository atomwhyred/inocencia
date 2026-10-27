import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../application/reminder_controller.dart';
import '../data/notifier.dart';
import '../data/reminder_runner.dart';
import '../domain/reminder_settings.dart';

/// Seccion "Avisos" del panel: aviso diario que invita al nino a estudiar.
class RemindersSection extends ConsumerStatefulWidget {
  const RemindersSection({super.key});

  @override
  ConsumerState<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<RemindersSection>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool? _exactOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExact();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver de los ajustes de Android, comprobar si ya se concedio el permiso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkExact();
  }

  Future<void> _checkExact() async {
    final ok = await ReminderNotifier().canScheduleExact();
    if (mounted) setState(() => _exactOk = ok);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      final notifier = ReminderNotifier();
      if (on && !await notifier.requestPermission()) {
        _snack('Sin permiso de notificaciones no se pueden enviar avisos. '
            'Actívalo en los ajustes de Android.');
        return;
      }
      await ref.read(reminderControllerProvider.notifier).setEnabled(on);
      if (on && !await notifier.canScheduleExact()) {
        // Abre los ajustes de Android; al volver se vuelve a comprobar.
        await notifier.requestExact();
      }
      await _checkExact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime(ReminderSettings s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
      helpText: 'Hora del aviso diario',
    );
    if (picked == null) return;
    await ref
        .read(reminderControllerProvider.notifier)
        .setMinutes(picked.hour * 60 + picked.minute);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      if (!await ReminderNotifier().requestPermission()) {
        _snack('Sin permiso de notificaciones no se pueden enviar avisos.');
        return;
      }
      final status = await runReminder(
        ref.read(reminderSettingsStoreProvider),
        ref.read(appDatabaseProvider),
        force: true,
      );
      ref.read(reminderLastRunProvider.notifier).set(status);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(reminderControllerProvider);
    final lastRun = ref.watch(reminderLastRunProvider);
    final time = TimeOfDay(hour: s.hour, minute: s.minute).format(context);
    final next = nextDailyRun(
      minutesOfDay: s.minutesOfDay,
      now: ref.read(clockProvider)(),
    );
    final nextDay = DateUtils.isSameDay(next, ref.read(clockProvider)()) ? 'hoy' : 'mañana';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Aviso diario', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Una notificación amable, cada día a la hora que elijas, invita a tus '
          'hijos a estudiar con su tutor. Funciona sin internet.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Activar aviso diario'),
                subtitle: Text(s.enabled ? 'Próximo aviso: $nextDay a las $time' : 'Desactivado'),
                value: s.enabled,
                onChanged: _busy ? null : _toggle,
              ),
              ListTile(
                enabled: s.enabled,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Hora del aviso'),
                trailing: Text(time, style: Theme.of(context).textTheme.titleMedium),
                onTap: s.enabled ? () => _pickTime(s) : null,
              ),
            ],
          ),
        ),
        if (s.enabled && _exactOk == false) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Android no permite “alarmas exactas” a esta app, así que el aviso '
                    'puede retrasarse unos minutos.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      await ReminderNotifier().requestExact();
                    },
                    child: const Text('Permitir alarmas exactas'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _test,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Enviar aviso de prueba'),
          ),
        ),
        if (lastRun != null) ...[
          const SizedBox(height: 12),
          Text('Último aviso: $lastRun', style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Text(
          'Si tu teléfono ahorra batería de forma agresiva (Xiaomi, Samsung…), '
          'desactiva la optimización de batería para inocencIA o los avisos '
          'podrían no llegar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
