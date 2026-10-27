import 'package:equatable/equatable.dart';

import '../../../core/utils/school_grade_calculator.dart';

/// Perfil de un nino.
class ChildProfile extends Equatable {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.birthDate,
    this.gradeOverride,
    this.pinLength,
  });

  final int id;
  final String name;

  /// `emoji:<caracter>` o `photo:<ruta absoluta>`.
  final String avatar;
  final DateTime birthDate;
  final int? gradeOverride;

  /// Longitud del PIN del nino; null si no tiene PIN.
  final int? pinLength;

  bool get hasPin => pinLength != null;

  /// Grado efectivo: el fijado por el padre o el calculado desde la fecha.
  int gradeAt(DateTime now) =>
      gradeOverride ??
      const SchoolGradeCalculator().gradeFor(birthDate, now: now);

  @override
  List<Object?> get props => [id, name, avatar, birthDate, gradeOverride, pinLength];
}

/// Datos para crear o editar un perfil.
class ChildProfileInput {
  const ChildProfileInput({
    required this.name,
    required this.avatar,
    required this.birthDate,
    this.gradeOverride,
  });

  final String name;
  final String avatar;
  final DateTime birthDate;
  final int? gradeOverride;
}

/// Que hacer con el PIN del nino al guardar.
sealed class ChildPinChange {
  const ChildPinChange();
}

class KeepChildPin extends ChildPinChange {
  const KeepChildPin();
}

class RemoveChildPin extends ChildPinChange {
  const RemoveChildPin();
}

class SetChildPin extends ChildPinChange {
  const SetChildPin(this.pin);
  final String pin;
}
