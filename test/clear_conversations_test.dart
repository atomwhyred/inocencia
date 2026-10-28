import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/security/pin_hasher.dart';
import 'package:inocencia/core/storage/app_database.dart';
import 'package:inocencia/core/theme/app_theme.dart';
import 'package:inocencia/features/profiles/data/child_profile_repository_impl.dart';
import 'package:inocencia/features/profiles/domain/child_profile.dart';
import 'package:inocencia/features/profiles/presentation/profile_form.dart';
import 'package:inocencia/features/tutor/data/tutor_history_repository_impl.dart';
import 'package:inocencia/features/tutor/domain/tutor_history_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('el padre borra las conversaciones de un niño sin tocar las del otro', (tester) async {
    await initializeDateFormatting('es');
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final db = AppDatabase(NativeDatabase.memory());
    final profiles = ChildProfileRepositoryImpl(db, const PinHasher(iterations: 10));
    final history = TutorHistoryRepositoryImpl(db);
    final leo = await profiles.create(
        ChildProfileInput(name: 'Leo', avatar: 'emoji:🦊', birthDate: DateTime(2015, 3, 1)));
    final ana = await profiles.create(
        ChildProfileInput(name: 'Ana', avatar: 'emoji:🐱', birthDate: DateTime(2014, 3, 1)));
    await history.add(leo, const StoredTutorMessage(fromUser: true, text: 'hola'));
    await history.add(leo, const StoredTutorMessage(fromUser: false, text: '¿Qué quieres aprender?'));
    await history.add(ana, const StoredTutorMessage(fromUser: true, text: 'de Ana'));

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: ProfileForm(childId: leo, onDone: () {})),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Conversaciones con el tutor'), findsOneWidget);
    expect(find.text('2 mensajes guardados.'), findsOneWidget);

    // Cancelar no borra nada.
    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(2 mensajes)'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await history.count(leo), 2);

    // Confirmar borra solo las de Leo.
    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(find.text('No hay conversaciones guardadas.'), findsOneWidget);
    expect(find.text('Conversaciones borradas.'), findsOneWidget);
    expect(await history.count(leo), 0);
    expect(await history.count(ana), 1);
    // Sin conversaciones, el botón queda desactivado.
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Borrar')).onPressed, isNull);
  });
}
