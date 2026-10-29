import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/features/notifications/application/reminder_controller.dart';
import 'package:inocencia/features/notifications/data/notifier.dart';
import 'package:inocencia/features/notifications/data/reminder_scheduler.dart';
import 'package:inocencia/features/notifications/domain/reminder_settings.dart';
import 'package:inocencia/features/notifications/presentation/reminders_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Apunta que alarmas se programan y se cancelan, sin tocar AlarmManager.
class _FakeScheduler implements ReminderScheduler {
  final scheduled = <Reminder>[];
  final cancelled = <int>[];

  @override
  Future<void> schedule(Reminder reminder, {DateTime? now}) async {
    // Como el real: un aviso apagado cancela su alarma.
    if (!reminder.enabled) {
      cancelled.add(reminder.id);
    } else {
      scheduled.add(reminder);
    }
  }

  @override
  Future<void> cancel(int reminderId) async => cancelled.add(reminderId);
}

/// Android sin Android: todo concedido salvo que la prueba diga otra cosa.
class _FakeNotifier extends ReminderNotifier {
  bool allowed = true;
  bool exact = true;
  int permissionRequests = 0;
  int exactRequests = 0;

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> requestExact() async => exactRequests++;
}

void main() {
  late _FakeScheduler scheduler;
  late _FakeNotifier notifier;

  Future<ProviderContainer> container([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    scheduler = _FakeScheduler();
    notifier = _FakeNotifier();
    final c = ProviderContainer(overrides: [
      reminderNotifierProvider.overrideWithValue(notifier),
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      reminderSchedulerProvider.overrideWithValue(scheduler),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('ReminderController', () {
    test('arranca con un aviso activo y lo programa al reprogramar', () async {
      final c = await container();
      final ctl = c.read(reminderControllerProvider.notifier);
      expect(c.read(reminderControllerProvider), ReminderSettings.initial);
      await ctl.reschedule();
      expect(scheduler.scheduled.map((r) => r.alarmId), [7001]);
    });

    test('reprogramar programa los activos y cancela los apagados', () async {
      final c = await container({
        'reminders_v1':
            '[{"id":1,"enabled":true,"minutes":480},{"id":2,"enabled":false,"minutes":600},{"id":3,"enabled":true,"minutes":1020}]',
      });
      await c.read(reminderControllerProvider.notifier).reschedule();
      expect(scheduler.scheduled.map((r) => r.id), [1, 3]);
      expect(scheduler.cancelled, [2]);
    });

    test('añadir crea un aviso activo con id propio y programa solo ese', () async {
      final c = await container();
      final added = await c.read(reminderControllerProvider.notifier).add(17 * 60);
      expect(added!.id, 2);
      expect(added.enabled, isTrue);
      expect(c.read(reminderControllerProvider).reminders.map((r) => r.id), [1, 2]);
      expect(scheduler.scheduled.map((r) => r.alarmId), [7002]);
      // Se guardó.
      expect(c.read(reminderSettingsStoreProvider).load().reminders, hasLength(2));
    });

    test('no deja pasar del máximo de avisos', () async {
      final c = await container();
      final ctl = c.read(reminderControllerProvider.notifier);
      for (var i = 1; i < ReminderSettings.maxReminders; i++) {
        expect(await ctl.add(600 + i), isNotNull);
      }
      expect(await ctl.add(900), isNull);
      expect(c.read(reminderControllerProvider).reminders, hasLength(ReminderSettings.maxReminders));
    });

    test('apagar un aviso cancela solo su alarma y no toca los demás', () async {
      final c = await container();
      final ctl = c.read(reminderControllerProvider.notifier);
      await ctl.add(17 * 60);
      scheduler.scheduled.clear();
      await ctl.setEnabled(2, false);
      expect(scheduler.cancelled, [2]);
      expect(scheduler.scheduled, isEmpty);
      final s = c.read(reminderControllerProvider);
      expect(s.byId(1)!.enabled, isTrue);
      expect(s.byId(2)!.enabled, isFalse);
    });

    test('cambiar la hora reprograma ese aviso con la hora nueva', () async {
      final c = await container();
      await c.read(reminderControllerProvider.notifier).setMinutes(1, 19 * 60 + 30);
      expect(scheduler.scheduled.single.minutesOfDay, 19 * 60 + 30);
      expect(c.read(reminderSettingsStoreProvider).load().byId(1)!.minutesOfDay, 19 * 60 + 30);
    });

    test('quitar cancela su alarma y su id no se reutiliza', () async {
      final c = await container();
      final ctl = c.read(reminderControllerProvider.notifier);
      await ctl.add(17 * 60); // id 2
      await ctl.remove(2);
      expect(scheduler.cancelled, [2]);
      expect(c.read(reminderControllerProvider).byId(2), isNull);
      final again = await ctl.add(18 * 60);
      expect(again!.id, 3); // no hereda la alarma 7002
    });

    test('quitarlos todos deja la lista vacía y no vuelve el aviso por defecto', () async {
      final c = await container();
      final ctl = c.read(reminderControllerProvider.notifier);
      await ctl.remove(1);
      expect(c.read(reminderControllerProvider).reminders, isEmpty);
      expect(c.read(reminderSettingsStoreProvider).load().reminders, isEmpty);
    });

    test('editar un aviso que no existe no hace nada', () async {
      final c = await container();
      await c.read(reminderControllerProvider.notifier).setEnabled(99, false);
      expect(scheduler.cancelled, isEmpty);
      expect(c.read(reminderControllerProvider), ReminderSettings.initial);
    });

    test('un aviso migrado del anterior sigue con su hora y su alarma 7001', () async {
      final c = await container({'reminder_enabled': true, 'reminder_minutes': 18 * 60});
      await c.read(reminderControllerProvider.notifier).reschedule();
      expect(scheduler.scheduled.single.alarmId, 7001);
      expect(scheduler.scheduled.single.minutesOfDay, 18 * 60);
    });
  });

  group('pantalla de avisos', () {
    late AppDatabase db;

    Future<ProviderContainer> open(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      db = AppDatabase(NativeDatabase.memory());
      final c = await container(prefs);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: RemindersSection())),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    Finder switches() => find.byType(Switch);

    testWidgets('al empezar hay un aviso activo a las 08:00', (tester) async {
      final c = await open(tester);
      // Sobrescribir el db de la app para la prueba: la seccion lo lee solo al probar.
      expect(switches(), findsOneWidget);
      expect(tester.widget<Switch>(switches()).value, isTrue);
      expect(find.textContaining('8:00'), findsWidgets);
      expect(c.read(reminderControllerProvider).reminders, hasLength(1));
    });

    testWidgets('cada aviso tiene su interruptor y apagar uno no apaga el otro', (tester) async {
      final c = await open(tester);
      await c.read(reminderControllerProvider.notifier).add(17 * 60);
      await tester.pumpAndSettle();
      expect(switches(), findsNWidgets(2));

      await tester.tap(switches().last);
      await tester.pumpAndSettle();
      expect(tester.widgetList<Switch>(switches()).map((s) => s.value), [true, false]);
      expect(find.text('Desactivado'), findsOneWidget);
      expect(c.read(reminderControllerProvider).byId(1)!.enabled, isTrue);
      expect(c.read(reminderControllerProvider).byId(2)!.enabled, isFalse);
    });

    testWidgets('Añadir aviso pide la hora y crea una tarjeta más', (tester) async {
      final c = await open(tester);
      await tester.tap(find.text('Añadir aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Hora del nuevo aviso'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(switches(), findsNWidgets(2));
      final added = c.read(reminderControllerProvider).reminders.last;
      expect(added.id, 2);
      expect(added.minutesOfDay, 17 * 60); // la hora propuesta
      expect(scheduler.scheduled.map((r) => r.id), contains(2));
    });

    testWidgets('cancelar el selector de hora no crea ningún aviso', (tester) async {
      final c = await open(tester);
      await tester.tap(find.text('Añadir aviso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.read(reminderControllerProvider).reminders, hasLength(1));
    });

    testWidgets('con el máximo de avisos el botón avisa y se desactiva', (tester) async {
      final c = await open(tester);
      final ctl = c.read(reminderControllerProvider.notifier);
      for (var i = 1; i < ReminderSettings.maxReminders; i++) {
        await ctl.add(600 + i);
      }
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Máximo ${ReminderSettings.maxReminders} avisos');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('quitar un aviso pide confirmación y lo borra', (tester) async {
      final c = await open(tester);
      await c.read(reminderControllerProvider.notifier).add(17 * 60);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quitar aviso').last);
      await tester.pumpAndSettle();
      expect(find.text('¿Quitar este aviso?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(c.read(reminderControllerProvider).reminders, hasLength(2));

      await tester.tap(find.byTooltip('Quitar aviso').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
      await tester.pumpAndSettle();
      expect(c.read(reminderControllerProvider).reminders.map((r) => r.id), [1]);
      expect(scheduler.cancelled, contains(2));
    });

    testWidgets('sin avisos lo dice y se puede crear otro', (tester) async {
      final c = await open(tester);
      await c.read(reminderControllerProvider.notifier).remove(1);
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay ningún aviso'), findsOneWidget);
      expect(switches(), findsNothing);
      expect(find.text('Añadir aviso'), findsOneWidget);
    });

    testWidgets('si Android no deja notificar, avisa y ofrece pedir el permiso', (tester) async {
      final c = await open(tester);
      expect(find.text('Permitir notificaciones'), findsNothing);
      notifier.allowed = false;
      await c.read(reminderControllerProvider.notifier).add(17 * 60);
      // Al volver a la app se comprueba de nuevo.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Permitir notificaciones'), findsOneWidget);
      await tester.tap(find.text('Permitir notificaciones'));
      await tester.pumpAndSettle();
      expect(notifier.permissionRequests, greaterThan(0));
    });

    testWidgets('sin ningún aviso activo no se pide ningún permiso', (tester) async {
      final c = await open(tester);
      notifier.allowed = false;
      await c.read(reminderControllerProvider.notifier).setEnabled(1, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Permitir notificaciones'), findsNothing);
    });

    testWidgets('con un aviso activo y sin alarmas exactas lo dice', (tester) async {
      notifier = _FakeNotifier();
      final c = await open(tester);
      notifier.exact = false;
      await c.read(reminderControllerProvider.notifier).add(17 * 60);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Permitir alarmas exactas'), findsOneWidget);
    });
  });
}
