import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/heart_rate_summary.dart';

void main() {
  group('summarizeHeartRate', () {
    test('空 → null', () {
      expect(summarizeHeartRate(const []), isNull);
    });

    test('1 標本 → 平均・最小・最大が同値', () {
      final s = summarizeHeartRate(const [70])!;
      expect(s.average, 70);
      expect(s.min, 70);
      expect(s.max, 70);
    });

    test('複数 → 平均は四捨五入', () {
      final a = summarizeHeartRate(const [60, 61])!;
      expect(a.average, 61);
      expect(a.min, 60);
      expect(a.max, 61);
      expect(summarizeHeartRate(const [60, 60, 61])!.average, 60);
    });

    test('小数の標本も扱える', () {
      final s = summarizeHeartRate(const [72.4])!;
      expect(s.average, 72);
      expect(s.min, 72);
      expect(s.max, 72);
    });
  });
}
