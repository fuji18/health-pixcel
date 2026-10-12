import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/domain/models/health_status.dart';

void main() {
  group('HealthPermissions', () {
    test('順序違いの集合は等しく hashCode も一致する', () {
      const a = HealthPermissions({HealthMetric.steps, HealthMetric.sleep});
      const b = HealthPermissions({HealthMetric.sleep, HealthMetric.steps});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('要素が違えば等しくない', () {
      const a = HealthPermissions({HealthMetric.steps});
      const b = HealthPermissions({HealthMetric.sleep});
      const c = HealthPermissions({HealthMetric.steps, HealthMetric.sleep});
      expect(a == b, isFalse);
      expect(a == c, isFalse);
    });

    test('isGranted / noneGranted', () {
      const p = HealthPermissions({HealthMetric.heartRate});
      expect(p.isGranted(HealthMetric.heartRate), isTrue);
      expect(p.isGranted(HealthMetric.steps), isFalse);
      expect(p.noneGranted, isFalse);
      expect(const HealthPermissions({}).noneGranted, isTrue);
    });
  });
}
