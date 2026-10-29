import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/tutor/domain/cpu_threads.dart';

void main() {
  group('CpuThreads.choose', () {
    test('Pixel 6 (2 X1 + 2 A76 + 4 A55) usa los 4 nucleos grandes', () {
      const freqs = [1803000, 1803000, 1803000, 1803000, 2253000, 2253000, 2802000, 2802000];
      expect(CpuThreads.choose(freqs, coreCount: 8), 4);
    });

    test('Dimensity 9500 (1 + 3 + 4 rapidos) cuenta los nucleos de mas de 70 % de la maxima', () {
      const freqs = [2700000, 2700000, 2700000, 2700000, 3500000, 3500000, 3500000, 4210000];
      expect(CpuThreads.choose(freqs, coreCount: 8), 4);
    });

    test('un chip con 6 pequenos y 2 grandes usa solo los grandes', () {
      const freqs = [1800000, 1800000, 1800000, 1800000, 1800000, 1800000, 2800000, 2800000];
      expect(CpuThreads.choose(freqs, coreCount: 8), 2);
    });

    test('nunca pasa de 6 ni baja de 2', () {
      expect(CpuThreads.choose(List.filled(8, 3000000), coreCount: 8), 6);
      expect(CpuThreads.choose(const [3000000, 1000000, 1000000], coreCount: 3), 2);
    });

    test('sin datos usa la mitad de los nucleos, como antes', () {
      expect(CpuThreads.choose(const [], coreCount: 8), 4);
      expect(CpuThreads.choose(const [0, 0], coreCount: 12), 6);
      expect(CpuThreads.choose(const [], coreCount: 2), 2);
    });
  });
}
