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

  group('ReminderSettingsStore', () {
    test('por defecto desactivado a las 08:00', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReminderSettingsStore(await SharedPreferences.getInstance());
      final s = store.load();
      expect(s.enabled, isFalse);
      expect((s.hour, s.minute), (8, 0));
    });

    test('guarda y recarga ajustes y ultimo resultado', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReminderSettingsStore(await SharedPreferences.getInstance());
      await store.save(const ReminderSettings(enabled: true, minutesOfDay: 18 * 60 + 15));
      await store.recordRun('Aviso enviado');
      final again = ReminderSettingsStore(await SharedPreferences.getInstance());
      expect(again.load(), const ReminderSettings(enabled: true, minutesOfDay: 18 * 60 + 15));
      expect(again.lastRun, 'Aviso enviado');
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
