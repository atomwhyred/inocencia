import '../constants.dart';

/// Calcula el grado escolar a partir de la fecha de nacimiento.
///
/// El curso empieza en septiembre: el grado es la edad cumplida al 1 de
/// septiembre del curso en vigor menos 5 (6 anos -> 1.er grado). 0 es
/// preescolar. El padre puede sustituir el resultado manualmente.
class SchoolGradeCalculator {
  const SchoolGradeCalculator();

  /// Anio en que empieza el curso que contiene [now].
  int schoolYearStart(DateTime now) => now.month >= 9 ? now.year : now.year - 1;

  int gradeFor(DateTime birthDate, {required DateTime now}) {
    final start = schoolYearStart(now);
    var age = start - birthDate.year;
    // Aun no habia cumplido anos el 1 de septiembre.
    if (birthDate.month > 9 || (birthDate.month == 9 && birthDate.day > 1)) {
      age -= 1;
    }
    return (age - 5).clamp(minSchoolGrade, maxSchoolGrade);
  }

  /// Etiqueta legible: "Preescolar", "1.er grado", "5.º grado"...
  static String label(int grade) {
    if (grade <= 0) return 'Preescolar';
    if (grade == 1) return '1.er grado';
    return '$grade.º grado';
  }
}
