import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/utils/school_grade_calculator.dart';

void main() {
  const calc = SchoolGradeCalculator();

  group('gradeFor', () {
    test('curso que empieza en septiembre: en octubre cuenta el anio actual', () {
      final now = DateTime(2026, 10, 27);
      expect(calc.gradeFor(DateTime(2015, 3, 10), now: now), 6); // 11 anos
      expect(calc.gradeFor(DateTime(2018, 6, 1), now: now), 3); // 8 anos
    });

    test('antes de septiembre cuenta el curso del anio anterior', () {
      final now = DateTime(2026, 3, 1); // curso 2025-26
      expect(calc.gradeFor(DateTime(2019, 2, 1), now: now), 1); // 6 anos al 1/09/2025
    });

    test('el limite es el 1 de septiembre', () {
      final now = DateTime(2026, 10, 1);
      expect(calc.gradeFor(DateTime(2020, 9, 1), now: now), 1); // 6 justos
      expect(calc.gradeFor(DateTime(2020, 9, 2), now: now), 0); // 5 anos
    });

    test('se acota a preescolar (0) y 12', () {
      final now = DateTime(2026, 10, 27);
      expect(calc.gradeFor(DateTime(2025, 1, 1), now: now), 0);
      expect(calc.gradeFor(DateTime(1990, 1, 1), now: now), 12);
    });
  });

  test('etiquetas legibles', () {
    expect(SchoolGradeCalculator.label(0), 'Preescolar');
    expect(SchoolGradeCalculator.label(1), '1.er grado');
    expect(SchoolGradeCalculator.label(5), '5.º grado');
  });
}
