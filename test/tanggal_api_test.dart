import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/tanggal_api.dart';
import 'package:sidik_calibration/models/calibration_draft.dart';
import 'package:sidik_calibration/models/organization.dart';
import 'package:sidik_calibration/models/standard.dart';

void main() {
  group('tanggalApi', () {
    test('tanggal keluar apa adanya, nggak mundur sehari', () {
      // Ini bug yang diperbaiki. Sebelumnya `toUtc().toIso8601String()` bikin
      // 30 Mei yang dipilih teknisi di Jakarta (UTC+7) kekirim sebagai
      // "2026-05-29T17:00:00.000Z", dan kolom `date` di backend nyimpen 29 Mei.
      expect(tanggalApi(DateTime(2026, 5, 30)), '2026-05-30');
    });

    test('tengah malam persis nggak geser', () {
      // Titik paling rawan: 00:00 lokal itu yang paling gampang kelempar ke
      // hari sebelumnya waktu dikonversi ke UTC dari zona timur.
      expect(tanggalApi(DateTime(2026, 1, 1, 0, 0)), '2026-01-01');
    });

    test('menjelang tengah malam tetap hari yang sama', () {
      expect(tanggalApi(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });

    test('bulan & hari satu digit dipadding', () {
      expect(tanggalApi(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('tahun kabisat', () {
      expect(tanggalApi(DateTime(2028, 2, 29)), '2028-02-29');
    });
  });

  group('yang beneran dikirim ke API', () {
    test('sesi kalibrasi: tanggal_kalibrasi & tanggal_terima polos', () {
      final draft = CalibrationDraft(
        equipmentId: 12,
        kategori: 'ph',
        standardId: 3,
        tanggalKalibrasi: DateTime(2026, 5, 30),
        tanggalTerima: DateTime(2026, 5, 28),
        clientRequestId: 'uuid-tes',
        measurements: const [],
      );

      final json = draft.toJson();

      expect(json['tanggal_kalibrasi'], '2026-05-30');
      expect(json['tanggal_terima'], '2026-05-28');
      // Nggak boleh ada jejak jam/zona sama sekali — kolomnya `date`.
      expect('${json['tanggal_kalibrasi']}', isNot(contains('T')));
      expect('${json['tanggal_kalibrasi']}', isNot(contains('Z')));
    });

    test('organisasi: tanggal akreditasi polos', () {
      final org = Organization(
        nama: 'PT Sidik',
        alamat: 'Bandung',
        telepon: '022',
        email: 'a@b.c',
        noAkreditasi: 'LK-285-IDN',
        akreditasiMulai: DateTime(2024, 10, 28),
        akreditasiBerakhir: DateTime(2029, 10, 27),
      );

      final json = org.toJson();

      // Akreditasi yang mundur sehari bisa bikin sertifikat kelihatan terbit
      // di luar masa berlaku waktu diaudit.
      expect(json['akreditasi_mulai'], '2024-10-28');
      expect(json['akreditasi_berakhir'], '2029-10-27');
    });

    test('standar acuan: berlaku_sampai polos', () {
      final standar = Standard(
        id: 1,
        nama: 'Gauge Block',
        merk: 'Mitutoyo',
        serialNumber: 'SN-001',
        masihBerlaku: true,
        ketidakpastian: 0.02,
        satuanKetidakpastian: 'mm',
        faktorCakupan: 2,
        berlakuSampai: DateTime(2027, 1, 1),
      );

      expect(standar.toJson()['berlaku_sampai'], '2027-01-01');
    });
  });
}
