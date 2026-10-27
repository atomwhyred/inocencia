import 'package:equatable/equatable.dart';

/// Padre/madre administrador de la app.
class Guardian extends Equatable {
  const Guardian({required this.id, required this.name, required this.pinLength});

  final int id;
  final String name;
  final int pinLength;

  @override
  List<Object?> get props => [id, name, pinLength];
}

abstract class GuardianRepository {
  /// Emite null mientras no exista administrador (primer arranque).
  Stream<Guardian?> watch();
  Future<void> create({required String name, required String pin});
  Future<bool> verifyPin(String pin);
}
