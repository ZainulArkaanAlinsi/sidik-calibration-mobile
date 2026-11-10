import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';

/// Token Studio: server menjawab `role: 'studio'` (satu pemilik, K-50-12).
/// Dulu `UserRole.fromApi` menjatuhkannya ke `viewer` — Studio berlabel
/// "Viewer", simulasi dan alur data acuan tertutup untuk pemiliknya.
void main() {
  group('Izin.fromJson — role studio', () {
    test("'studio' = hak penuh pemilik (superAdmin), BUKAN viewer", () {
      final izin = Izin.fromJson({
        'data': {
          'role': 'studio',
          'boleh': ['workbook.lihat', 'data-acuan.lihat'],
          'batasan': <String, dynamic>{},
        },
      });
      expect(izin.role, UserRole.superAdmin);
      expect(izin.role, isNot(UserRole.viewer));
    });

    test('role lab tetap seperti semula', () {
      for (final (api, harap) in [
        ('admin', UserRole.admin),
        ('teknisi', UserRole.teknisi),
        ('super_admin', UserRole.superAdmin),
        ('viewer', UserRole.viewer),
        ('asing', UserRole.viewer),
      ]) {
        expect(
          Izin.fromJson({'data': {'role': api, 'boleh': <String>[]}}).role,
          harap,
          reason: api,
        );
      }
    });

    test('role kosong tetap null', () {
      expect(Izin.fromJson({'data': {'boleh': <String>[]}}).role, isNull);
    });
  });
}
