/// PIN que se adivinan primero (0000, 1234, 1212, 2580...). Con 4 cifras y bloqueo
/// creciente, adivinar un PIN al azar lleva días; uno de estos, segundos.
///
/// Devuelve el motivo para mostrarlo, o null si el PIN vale. Solo se aplica al crear
/// un PIN: los que ya existen siguen funcionando.
String? weakPinReason(String pin) {
  if (pin.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(pin)) return null;
  final d = pin.codeUnits.map((c) => c - 48).toList();
  if (d.toSet().length == 1) return 'Todas las cifras son iguales: es muy fácil de adivinar.';
  bool steps(int step) {
    for (var i = 1; i < d.length; i++) {
      if (d[i] - d[i - 1] != step) return false;
    }
    return true;
  }

  if (steps(1) || steps(-1)) return 'Es una serie seguida: es muy fácil de adivinar.';
  // Dos cifras que se repiten (1212, 4545, 121212).
  if (d.length.isEven && d.toSet().length == 2) {
    var alternates = true;
    for (var i = 2; i < d.length; i++) {
      if (d[i] != d[i - 2]) alternates = false;
    }
    if (alternates) return 'Repite dos cifras: es muy fácil de adivinar.';
  }
  const common = {'2580', '0852', '1122', '1100', '6969', '1313', '2468', '1357', '0007', '7777'};
  if (common.contains(pin)) return 'Es uno de los PIN más usados: elige otro.';
  return null;
}
