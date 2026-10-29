/// Lo que esta pasando con la lectura en voz alta.
enum SpeechStatus {
  idle,
  speaking,
  paused,

  /// El telefono no tiene una voz en espanol instalada.
  unavailable,
}

/// Voz del dispositivo (motor de sintesis de Android), sin internet. Lee una
/// frase cada vez: asi se puede pausar y seguir desde la frase en que se paro.
abstract class SpeechService {
  /// Deja lista una voz en espanol. `false` si el telefono no tiene ninguna.
  Future<bool> prepare();

  /// Lee [sentence]. Termina con `true` si la leyo entera y con `false` si se
  /// paro antes o hubo un error.
  Future<bool> speak(String sentence);

  Future<void> stop();

  Future<void> dispose();
}
