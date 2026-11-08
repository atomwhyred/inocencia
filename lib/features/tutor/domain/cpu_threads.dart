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

  /// Hilos a usar segun la frecuencia maxima de cada nucleo ([maxFreqsKhz], las que
  /// da `cpuinfo_max_freq`). Sin datos validos se usa la mitad de los nucleos
  /// ([coreCount]), que es lo que se hacia antes.
  static int choose(List<int> maxFreqsKhz, {required int coreCount}) {
    final freqs = maxFreqsKhz.where((f) => f > 0).toList();
    final fallback = (coreCount / 2).round();
    if (freqs.isEmpty) return fallback.clamp(minThreads, maxThreads);
    final top = freqs.reduce((a, b) => a > b ? a : b);
    final fast = freqs.where((f) => f >= top * fastShare).length;
    return fast.clamp(minThreads, maxThreads);
  }

  /// Hilos para procesar el prompt (el tiempo hasta la primera pieza). Nunca menos
  /// que [choose]; sin datos de frecuencia, los mismos que [choose].
  static int chooseBatch(List<int> maxFreqsKhz, {required int coreCount}) {
    final gen = choose(maxFreqsKhz, coreCount: coreCount);
    final freqs = maxFreqsKhz.where((f) => f > 0).toList();
    if (freqs.isEmpty) return gen;
    final top = freqs.reduce((a, b) => a > b ? a : b);
    final strong = freqs.where((f) => f >= top * fastShare || f >= batchMinKhz).length;
    return strong.clamp(gen, maxBatchThreads);
  }
}
