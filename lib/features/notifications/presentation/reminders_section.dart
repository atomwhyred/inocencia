import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../application/reminder_controller.dart';
import '../data/reminder_runner.dart';
import '../domain/reminder_settings.dart';

/// Seccion "Avisos" del panel: avisos diarios que invitan al nino a estudiar.
/// Cada aviso tiene su hora y su propio interruptor.
class RemindersSection extends ConsumerStatefulWidget {
  const RemindersSection({super.key});

  @override
  ConsumerState<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<RemindersSection>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool? _exactOk;
  bool? _notificationsOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver de los ajustes de Android, comprobar si ya se concedieron los permisos.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifier = ref.read(reminderNotifierProvider);
    final exact = await notifier.canScheduleExact();
    final notifications = await notifier.notificationsAllowed();
    if (mounted) {
      setState(() {
        _exactOk = exact;
        _notificationsOk = notifications;
      });
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  ReminderController get _controller => ref.read(reminderControllerProvider.notifier);

  Future<void> _toggle(Reminder r, bool on) async {
    setState(() => _busy = true);
    try {
      final notifier = ref.read(reminderNotifierProvider);
      if (on && !await notifier.requestPermission()) {
        _snack('Sin permiso de notificaciones no se pueden enviar avisos. '
            'Actívalo en los ajustes de Android.');
        return;
      }
      await _controller.setEnabled(r.id, on);
      if (on && !await notifier.canScheduleExact()) {
        // Abre los ajustes de Android; al volver se vuelve a comprobar.
        await notifier.requestExact();
      }
      await _checkPermissions();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _pickMinutes(int initial, String help) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      helpText: help,
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _changeTime(Reminder r) async {
    final minutes = await _pickMinutes(r.minutesOfDay, 'Hora del aviso');
    if (minutes != null) await _controller.setMinutes(r.id, minutes);
  }

  Future<void> _add(ReminderSettings s) async {
    // Se propone una hora de la tarde: el primer aviso suele ser el de la manana.
    final minutes = await _pickMinutes(s.reminders.isEmpty ? Reminder.defaultMinutes : 17 * 60, 'Hora del nuevo aviso');
    if (minutes == null) return;
    if (!await ref.read(reminderNotifierProvider).requestPermission()) {
      _snack('Sin permiso de notificaciones no se pueden enviar avisos. '
          'Actívalo en los ajustes de Android.');
    }
    await _controller.add(minutes);
    await _checkPermissions();
  }

  Future<void> _remove(Reminder r) async {
    final time = TimeOfDay(hour: r.hour, minute: r.minute).format(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar este aviso?'),
        content: Text('Dejará de sonar el aviso de las $time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok == true) await _controller.remove(r.id);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      if (!await ref.read(reminderNotifierProvider).requestPermission()) {
        _snack('Sin permiso de notificaciones no se pueden enviar avisos.');
        return;
      }
      final status = await runReminder(
        ref.read(reminderSettingsStoreProvider),
        ref.read(appDatabaseProvider),
        force: true,
      );
      ref.read(reminderLastRunProvider.notifier).set(status);
      await _checkPermissions();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(reminderControllerProvider);
    final lastRun = ref.watch(reminderLastRunProvider);
    final now = ref.read(clockProvider)();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Avisos diarios', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Notificaciones amables, a las horas que elijas, que invitan a tus '
          'hijos a estudiar con su tutor. Puedes tener varios y apagar cada uno por '
          'separado. Funcionan sin internet.',
        ),
        const SizedBox(height: 16),
        if (s.anyEnabled && _notificationsOk == false) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Android no deja que inocencIA envíe notificaciones, así que los '
                    'avisos no se verán.',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(reminderNotifierProvider).requestPermission();
                      await _checkPermissions();
                    },
                    child: const Text('Permitir notificaciones'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (s.reminders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay ningún aviso. Pulsa “Añadir aviso” para crear uno.'),
            ),
          ),
        for (final r in s.reminders) ...[
          _ReminderCard(
            reminder: r,
            now: now,
            busy: _busy,
            onToggle: (on) => _toggle(r, on),
            onChangeTime: () => _changeTime(r),
            onRemove: () => _remove(r),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: !s.canAdd || _busy ? null : () => _add(s),
            icon: const Icon(Icons.add_alarm_rounded),
            label: Text(s.canAdd ? 'Añadir aviso' : 'Máximo ${ReminderSettings.maxReminders} avisos'),
          ),
        ),
        if (s.anyEnabled && _exactOk == false) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Android no permite “alarmas exactas” a esta app, así que los avisos '
                    'pueden retrasarse unos minutos.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(reminderNotifierProvider).requestExact();
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
          Text('Último aviso: $lastRun', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Text(
          'Si tu teléfono ahorra batería de forma agresiva (Xiaomi, Samsung…), '
          'desactiva la optimización de batería para inocencIA o los avisos '
          'podrían no llegar.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Un aviso: su hora y su interruptor, y cambiar la hora o quitarlo.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.now,
    required this.busy,
    required this.onToggle,
    required this.onChangeTime,
    required this.onRemove,
  });

  final Reminder reminder;
  final DateTime now;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChangeTime;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final time = TimeOfDay(hour: r.hour, minute: r.minute).format(context);
    final next = nextDailyRun(minutesOfDay: r.minutesOfDay, now: now);
    final nextDay = DateUtils.isSameDay(next, now) ? 'hoy' : 'mañana';
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(time, style: Theme.of(context).textTheme.headlineSmall),
            subtitle: Text(r.enabled ? 'Próximo aviso: $nextDay a las $time' : 'Desactivado'),
            value: r.enabled,
            onChanged: busy ? null : onToggle,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onChangeTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Cambiar hora'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Quitar aviso',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
