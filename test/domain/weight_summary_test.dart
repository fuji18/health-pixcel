import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/weight_summary.dart';

void main() {
  final t0 = DateTime(2026, 10, 6, 8);
  group('pickLatestWeight', () {
    test('空 → null', () {
      expect(pickLatestWeight(const []), isNull);
    });

    test('1 件 → その値(double)', () {
      final v = pickLatestWeight([(at: t0, kg: 65.3)]);
      expect(v, 65.3);
      expect(v, isA<double>());
    });

    test('複数 → 時刻が最も新しいもの(列挙順が時刻順でなくても)', () {
      final v = pickLatestWeight([
        (at: t0.add(const Duration(hours: 2)), kg: 66.0),
        (at: t0, kg: 65.0),
        (at: t0.add(const Duration(hours: 1)), kg: 65.5),
      ]);
      expect(v, 66.0);
    });

    test('同時刻 → 列挙順で後のもの', () {
      final v = pickLatestWeight([(at: t0, kg: 65.0), (at: t0, kg: 64.0)]);
      expect(v, 64.0);
    });

    test('int の kg → double', () {
      final v = pickLatestWeight([(at: t0, kg: 65)]);
      expect(v, 65.0);
      expect(v, isA<double>());
    });
  });
}
