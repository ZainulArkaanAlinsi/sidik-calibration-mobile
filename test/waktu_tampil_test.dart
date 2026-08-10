import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sidik_calibration/core/utils/waktu_tampil.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';

/// Jam di daftar antrean/riwayat/alur/arsip/folder.
///
/// Dikeluhkan 10 Agt 2026: beberapa sesi masuk di HARI yang sama cuma
/// kelihatan sebagai `10 Agt 2026` berulang-ulang, jadi nggak ada cara tahu
/// mana kiriman terbaru — padahal urutan itu yang nentuin mana yang diperiksa
/// duluan.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('format waktu', () {
    test('hari ini & kemarin diringkas, sisanya pakai tanggal penuh', () {
      final sekarang = DateTime(2026, 8, 10, 15, 30);

      String f(DateTime w) => waktuRelatif(
        w,
        'id',
        hariIni: 'Hari ini',
        kemarin: 'Kemarin',
        sekarang: sekarang,
      );

      expect(f(DateTime(2026, 8, 10, 9, 14)), 'Hari ini · 09.14');
      expect(f(DateTime(2026, 8, 9, 16, 5)), 'Kemarin · 16.05');
      // `Agu`, bukan `Agt` — singkatan bulan dari locale `id` bawaan intl.
      expect(f(DateTime(2026, 8, 8, 16, 5)), '8 Agu 2026 · 16.05');
    });

    /// Dibandingin per HARI KALENDER, bukan selisih 24 jam. Jam 23.50 dan
    /// 00.10 cuma beda 20 menit tapi beda hari — dan orang mikirnya per hari.
    test('beda 20 menit yang melewati tengah malam tetap dihitung kemarin', () {
      expect(
        waktuRelatif(
          DateTime(2026, 8, 9, 23, 50),
          'id',
          hariIni: 'Hari ini',
          kemarin: 'Kemarin',
          sekarang: DateTime(2026, 8, 10, 0, 10),
        ),
        'Kemarin · 23.50',
      );
    });

    /// Yang dijaga: dua item di hari yang sama BEDA tampilannya. Itu seluruh
    /// alasan fitur ini ada.
    test('dua kiriman di hari yang sama nggak lagi kembar', () {
      final sekarang = DateTime(2026, 8, 10, 17, 0);

      String f(DateTime w) => waktuRelatif(
        w,
        'id',
        hariIni: 'Hari ini',
        kemarin: 'Kemarin',
        sekarang: sekarang,
      );

      expect(f(DateTime(2026, 8, 10, 9, 14)),
          isNot(f(DateTime(2026, 8, 10, 14, 2))));
    });
  });

  group('waktu mana yang dipakai per status', () {
    CalibrationHistoryItem item(
      CalibrationStatus status, {
      DateTime? dikirim,
      DateTime? diperiksa,
      DateTime? diubah,
    }) => CalibrationHistoryItem(
      id: 1,
      namaAlat: 'pH Meter',
      namaTeknisi: 'Dimas',
      tanggalKalibrasi: DateTime(2026, 8, 10),
      status: status,
      dikirimPada: dikirim,
      diperiksaPada: diperiksa,
      diubahPada: diubah,
    );

    test('sesi yang udah diperiksa dinilai dari waktu diperiksa', () {
      final s = item(
        CalibrationStatus.disetujui,
        dikirim: DateTime(2026, 8, 10, 9),
        diperiksa: DateTime(2026, 8, 10, 14),
      );

      expect(s.waktuTerakhir, DateTime(2026, 8, 10, 14));
    });

    test('yang masih nunggu dinilai dari waktu dikirim', () {
      final s = item(
        CalibrationStatus.menungguApproval,
        dikirim: DateTime(2026, 8, 10, 9),
        diubah: DateTime(2026, 8, 10, 11),
      );

      expect(s.waktuTerakhir, DateTime(2026, 8, 10, 9));
    });

    /// Draft belum pernah dikirim — satu-satunya jejaknya waktu terakhir
    /// diubah. Tanpa fallback ini barisnya nggak nunjukin jam sama sekali.
    test('draft jatuh ke waktu terakhir diubah', () {
      final s = item(
        CalibrationStatus.draft,
        diubah: DateTime(2026, 8, 10, 11),
      );

      expect(s.waktuTerakhir, DateTime(2026, 8, 10, 11));
    });

    /// Backend lama nggak ngirim satu pun field ini. Layar mesti diam, bukan
    /// nampilin epoch atau jam karangan.
    test('backend tanpa timestamp → null, bukan tanggal karangan', () {
      expect(item(CalibrationStatus.menungguApproval).waktuTerakhir, isNull);
    });
  });

  group('parsing dari JSON', () {
    test('UTC dari backend dijadiin waktu lokal', () {
      final s = CalibrationHistoryItem.fromJson({
        'id': 1,
        'equipment': {'nama_alat': 'pH Meter'},
        'teknisi': {'nama': 'Dimas'},
        'tanggal_kalibrasi': '2026-08-10',
        'status': 'menunggu_approval',
        'submitted_at': '2026-08-10T02:14:00.000000Z',
      });

      // Nilai instannya sama; yang penting `isUtc` false supaya `DateFormat`
      // nyetak jam setempat, bukan mundur 7 jam di Jakarta.
      expect(s.dikirimPada!.isUtc, isFalse);
      expect(
        s.dikirimPada!.toUtc(),
        DateTime.utc(2026, 8, 10, 2, 14),
      );
    });

    test('field yang belum ada di respons lama nggak bikin parsing meledak', () {
      final s = CalibrationHistoryItem.fromJson({
        'id': 1,
        'equipment': {'nama_alat': 'pH Meter'},
        'teknisi': {'nama': 'Dimas'},
        'tanggal_kalibrasi': '2026-08-10',
        'status': 'menunggu_approval',
      });

      expect(s.dikirimPada, isNull);
      expect(s.diperiksaPada, isNull);
      expect(s.waktuTerakhir, isNull);
    });
  });
}
