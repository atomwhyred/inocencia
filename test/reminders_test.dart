import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/notifications/data/reminder_settings_store.dart';
import 'package:inocencia/features/notifications/data/reminder_texts.dart';
import 'package:inocencia/features/notifications/domain/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('nextDailyRun', () {
    const eight = 8 * 60;

    test('si la hora de hoy aun no paso, es hoy', () {
      expect(
        nextDailyRun(minutesOfDay: eight, now: DateTime(2026, 10, 27, 7, 59)),
        DateTime(2026, 10, 27, 8),
      );
    });

    test('si ya paso, es manana', () {
      expect(
        nextDailyRun(minutesOfDay: eight, now: DateTime(2026, 10, 27, 8, 1)),
        DateTime(2026, 10, 28, 8),
      );
    });

    test('exactamente a la hora cuenta como pasada (estrictamente posterior)', () {
      expect(
        nextDailyRun(minutesOfDay: eight, now: DateTime(2026, 10, 27, 8)),
        DateTime(2026, 10, 28, 8),
      );
    });

    test('cruza el fin de mes y de anio', () {
      expect(
        nextDailyRun(minutesOfDay: eight, now: DateTime(2026, 12, 31, 9)),
        DateTime(2027, 1, 1, 8),
      );
    });

    test('respeta los minutos', () {
      expect(
        nextDailyRun(minutesOfDay: 17 * 60 + 30, now: DateTime(2026, 3, 1, 12)),
        DateTime(2026, 3, 1, 17, 30),
      );
    });
  });

  group('Reminder y ReminderSettings', () {
    test('el aviso 1 conserva la alarma 7001 del aviso unico anterior', () {
      expect(const Reminder(id: 1).alarmId, 7001);
      expect(const Reminder(id: 3).alarmId, 7003);
      expect(Reminder.idFromAlarm(7001), 1);
      expect(Reminder.idFromAlarm(7003), 3);
    });

    test('el id 7000 es el del aviso de prueba, no de ningun aviso', () {
      expect(Reminder.idFromAlarm(7000), isNull);
      expect(Reminder.idFromAlarm(12), isNull);
    });

    test('por defecto hay un aviso activo a las 08:00', () {
      const s = ReminderSettings.initial;
      expect(s.reminders, hasLength(1));
      expect(s.reminders.single.enabled, isTrue);
      expect((s.reminders.single.hour, s.reminders.single.minute), (8, 0));
      expect(s.anyEnabled, isTrue);
    });

    test('tope de avisos', () {
      var s = ReminderSettings.initial;
      expect(s.canAdd, isTrue);
      for (var id = 2; id <= ReminderSettings.maxReminders; id++) {
        s = s.added(Reminder(id: id));
      }
      expect(s.reminders, hasLength(ReminderSettings.maxReminders));
      expect(s.canAdd, isFalse);
    });

    test('el id nuevo es mayor que cualquiera usado, aunque ese aviso se borrara', () {
      var s = ReminderSettings.initial.added(const Reminder(id: 2)).added(const Reminder(id: 3));
      s = s.without(3);
      expect(s.nextId(3), 4); // el 3 ya se uso: no se reutiliza su alarma
      expect(s.nextId(1), 3);
    });

    test('replace y without solo tocan su aviso', () {
      final s = ReminderSettings.initial.added(const Reminder(id: 2, minutesOfDay: 600));
      final off = s.replace(const Reminder(id: 2, enabled: false, minutesOfDay: 600));
      expect(off.byId(1)!.enabled, isTrue);
      expect(off.byId(2)!.enabled, isFalse);
      expect(off.without(1).reminders.map((r) => r.id), [2]);
    });

    test('toJson y fromJson se corresponden; un dato roto da null', () {
      const r = Reminder(id: 4, enabled: false, minutesOfDay: 17 * 60 + 5);
      expect(Reminder.fromJson(r.toJson()), r);
      expect(Reminder.fromJson({'id': 0, 'enabled': true, 'minutes': 480}), isNull);
      expect(Reminder.fromJson({'id': 1, 'enabled': true, 'minutes': 2000}), isNull);
      expect(Reminder.fromJson({'id': 1, 'enabled': 'si', 'minutes': 480}), isNull);
      expect(Reminder.fromJson('hola'), isNull);
    });
  });

  group('reminderToRun: que aviso suena cuando salta una alarma', () {
    final settings = ReminderSettings([
      const Reminder(id: 1),
      const Reminder(id: 2, enabled: false, minutesOfDay: 600),
      const Reminder(id: 5, minutesOfDay: 1020),
    ]);

    test('suena el aviso activo de esa alarma', () {
      expect(reminderToRun(settings, 7001)!.id, 1);
      expect(reminderToRun(settings, 7005)!.minutesOfDay, 1020);
    });

    test('un aviso apagado no suena', () {
      expect(reminderToRun(settings, 7002), isNull);
    });

    test('un aviso borrado desde que se programo la alarma no suena', () {
      expect(reminderToRun(settings, 7003), isNull);
    });

    test('la alarma de prueba no es de ningun aviso', () {
      expect(reminderToRun(settings, 7000), isNull);
    });
  });

  group('ReminderSettingsStore', () {
    Future<ReminderSettingsStore> store(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return ReminderSettingsStore(await SharedPreferences.getInstance());
    }

    test('instalacion nueva: un aviso activo a las 08:00', () async {
      final s = (await store({})).load();
      expect(s, ReminderSettings.initial);
    });

    test('guarda y recarga la lista y el ultimo resultado', () async {
      final st = await store({});
      final saved = ReminderSettings([
        const Reminder(id: 1, minutesOfDay: 18 * 60 + 15),
        const Reminder(id: 3, enabled: false, minutesOfDay: 7 * 60),
      ]);
      await st.save(saved);
      await st.recordRun('Aviso enviado');
      final again = ReminderSettingsStore(await SharedPreferences.getInstance());
      expect(again.load(), saved);
      expect(again.lastRun, 'Aviso enviado');
    });

    test('migra el aviso unico anterior como aviso 1, con su hora y su estado', () async {
      final s = (await store({'reminder_enabled': true, 'reminder_minutes': 18 * 60 + 15})).load();
      expect(s.reminders, [const Reminder(id: 1, minutesOfDay: 18 * 60 + 15)]);
    });

    test('migra tambien un aviso unico que estaba apagado', () async {
      final s = (await store({'reminder_enabled': false, 'reminder_minutes': 600})).load();
      expect(s.reminders, [const Reminder(id: 1, enabled: false, minutesOfDay: 600)]);
      expect(s.anyEnabled, isFalse);
    });

    test('una vez guardada la lista, las claves antiguas ya no cuentan', () async {
      final st = await store({'reminder_enabled': true, 'reminder_minutes': 600});
      await st.save(ReminderSettings.initial.replace(const Reminder(id: 1, enabled: false)));
      expect(st.load().reminders.single.enabled, isFalse);
    });

    test('un JSON roto vuelve al aviso por defecto', () async {
      final s = (await store({'reminders_v1': 'esto no es json'})).load();
      expect(s, ReminderSettings.initial);
    });

    test('se ignoran los avisos con datos rotos pero no los demas', () async {
      final s = (await store({
        'reminders_v1':
            '[{"id":1,"enabled":true,"minutes":480},{"id":2,"enabled":true,"minutes":99999},"x"]',
      })).load();
      expect(s.reminders.map((r) => r.id), [1]);
    });

    test('recuerda el mayor id usado aunque se borre ese aviso', () async {
      final st = await store({});
      await st.save(ReminderSettings.initial.added(const Reminder(id: 2)).added(const Reminder(id: 3)));
      expect(st.lastId, 3);
      await st.save(st.load().without(3));
      expect(st.lastId, 3);
      expect(st.load().nextId(st.lastId), 4);
    });
  });

  group('reminderText', () {
    test('incluye el nombre del nino', () {
      for (var seed = 0; seed < 20; seed++) {
        final t = reminderText(childName: 'Leo', random: Random(seed));
        expect('${t.title} ${t.body}', contains('Leo'));
        expect('${t.title} ${t.body}', isNot(contains('{name}')));
      }
    });

    test('sin nombre usa un texto general sin marcadores', () {
      for (var seed = 0; seed < 20; seed++) {
        final t = reminderText(random: Random(seed));
        expect('${t.title} ${t.body}', isNot(contains('{')));
      }
      final blank = reminderText(childName: '  ');
      expect(blank.title, isNot(contains('  ')));
    });
  });
}
