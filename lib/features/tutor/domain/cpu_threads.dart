/// Cuantos hilos de CPU conviene dar al modelo.
///
/// Los moviles mezclan nucleos grandes y pequenos y llama.cpp reparte el trabajo a
/// partes iguales: si un hilo cae en un nucleo pequeno, todos esperan por el. Por eso
/// se cuentan solo los nucleos rapidos (frecuencia cercana a la maxima del chip).
class CpuThreads {
  const CpuThreads._();

  static const minThreads = 2;
  static const maxThreads = 6;

  /// Un nucleo cuenta como rapido si llega al menos a esta parte de la frecuencia maxima.
  static const fastShare = 0.7;

  /// Para procesar el prompt (calculo puro, no limitado por la memoria) se admiten
  /// tambien los nucleos medianos fuertes: los de 2,7 GHz de un Dimensity 9500 suman.
  /// Los pequenos (Cortex-A55 y similares, ~1,8 GHz en un Snapdragon 860 o un Tensor)
  /// frenarian al conjunto. Se mide en GHz y no en proporcion porque en el Pixel 6
  /// los pequenos llegan al 64 % de la maxima, igual que los medianos del Dimensity.
  static const batchMinKhz = 2200000;
  static const maxBatchThreads = 8;

  /// Nucleos que el prompt deja libres para el sistema.
  static const freeCores = 2;

  /// Chip sin nucleos pequenos (todos llegan a [batchMinKhz]), como el Dimensity 9500.
  /// Ahi no hay nucleo lento que absorba la interfaz y Android: en el Xiaomi 17T Pro,
  /// con 4 hilos al escribir (todos los rapidos) caia a 0,2 tokens/s y con 3 iba a
  /// 9,8-12,7. Se deja un nucleo rapido libre.
  static bool _allBig(List<int> freqs) =>
      freqs.isNotEmpty && freqs.every((f) => f >= batchMinKhz);

  /// Hilos a usar segun la frecuencia maxima de cada nucleo ([maxFreqsKhz], las que
  /// da `cpuinfo_max_freq`). Sin datos validos se usa la mitad de los nucleos
  /// ([coreCount]), que es lo que se hacia antes.
  static int choose(List<int> maxFreqsKhz, {required int coreCount}) {
    final freqs = maxFreqsKhz.where((f) => f > 0).toList();
    final fallback = (coreCount / 2).round();
    if (freqs.isEmpty) return fallback.clamp(minThreads, maxThreads);
    final top = freqs.reduce((a, b) => a > b ? a : b);
    final fast = freqs.where((f) => f >= top * fastShare).length;
    return (_allBig(freqs) ? fast - 1 : fast).clamp(minThreads, maxThreads);
  }

  /// Hilos para procesar el prompt (el tiempo hasta la primera pieza). Nunca menos
  /// que [choose]; sin datos de frecuencia, los mismos que [choose].
  static int chooseBatch(List<int> maxFreqsKhz, {required int coreCount}) {
    final gen = choose(maxFreqsKhz, coreCount: coreCount);
    final freqs = maxFreqsKhz.where((f) => f > 0).toList();
    if (freqs.isEmpty) return gen;
    final top = freqs.reduce((a, b) => a > b ? a : b);
    final strong = freqs.where((f) => f >= top * fastShare || f >= batchMinKhz).length;
    // Nunca todos los nucleos: si no queda ninguno libre para Android y la interfaz,
    // basta con que un hilo espere para que esperen todos (el Dimensity 9500 no tiene
    // nucleos pequenos que hagan de colchon).
    var cap = (coreCount - freeCores).clamp(gen, maxBatchThreads);
    // Sin nucleos pequenos, un hilo mas que al escribir: en el 17T Pro el prompt iba
    // igual o mejor con 4 (12,6-19,7 tokens/s) que con 6 y peor con 8.
    if (_allBig(freqs) && cap > gen + 1) cap = gen + 1;
    return strong.clamp(gen, cap);
  }
}
