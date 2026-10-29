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
}
