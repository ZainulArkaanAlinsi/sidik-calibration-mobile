import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/parse_list.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/user.dart';

/// Dua cast keras yang bikin baris HILANG DIAM-DIAM (BUG-007 & BUG-022).
///
/// ## Kenapa dua-duanya di satu berkas
///
/// Bentuknya beda, mekanisme gagalnya sama persis — dan mekanisme itu yang
/// bikin keduanya tidak pernah ketahuan:
///
/// 1. `as X` yang keras melempar `TypeError`.
/// 2. `parseListAman` menelannya (`catch (_)` — memang sengaja, supaya satu
///    record cacat tidak mengosongkan seluruh layar).
/// 3. Barisnya raib dari daftar. Tanpa error, tanpa log, tanpa layar merah.
///
/// Nomor 2 itu jaring pengaman yang benar. Yang salah, dua cast di bawah ini
/// mengubahnya jadi tempat sampah: data yang sebetulnya bisa dibaca justru
/// dibuang lewat pintu yang disiapkan buat data yang memang rusak.
void main() {
  group('BUG-007 · employee_id boleh null di DB', () {
    /// `employee_id` `nullable` sejak migrasi 2026_07_14_110000 (sengaja, buat
    /// baris lama), dan `UserResource` meneruskannya apa adanya tanpa `?? ''`.
    /// `as String` di Dart tidak menerima `null`.
    Map<String, dynamic> akun({Object? employeeId}) => {
      'id': 7,
      'nama': 'Budi Santoso',
      'email': 'budi@pt-sidik.com',
      'employee_id': employeeId,
      'role': 'teknisi',
      'status': 'aktif',
      'organization_id': 1,
    };

    test('akun tanpa employee_id tetap ke-parse, bukan melempar', () {
      final user = User.fromJson(akun());

      expect(user.employeeId, '');
      expect(user.nama, 'Budi Santoso');
    });

    /// Inti bug-nya, dan bagian yang paling penting: bukan cuma "tidak
    /// melempar", tapi **barisnya tetap ada di daftar**.
    ///
    /// Sebelum diperbaiki, akun seperti ini hilang dari layar admin `/users`
    /// tanpa jejak — dan admin tidak bisa approve atau reset password akun
    /// yang tidak pernah dia lihat.
    test('akun tanpa employee_id nggak ilang dari daftar admin', () {
      final daftar = parseListAman<User>([
        akun(employeeId: 'SDK-0001'),
        akun(), // yang ini dulu dilewat diam-diam
        akun(employeeId: 'SDK-0003'),
      ], User.fromJson);

      expect(
        daftar,
        hasLength(3),
        reason: 'Akun tanpa employee_id ilang dari daftar tanpa satu pun error.',
      );
      expect(daftar.map((u) => u.employeeId), ['SDK-0001', '', 'SDK-0003']);
    });

    test('employee_id yang ada tetap kebaca apa adanya', () {
      expect(User.fromJson(akun(employeeId: 'SDK-0042')).employeeId, 'SDK-0042');
    });

    /// JANGAN kebablasan: cast lain di `User.fromJson` tetap keras.
    ///
    /// `nama`, `email` dan `role` memang tidak boleh kosong — respons tanpa
    /// ketiganya itu respons rusak, dan barisnya memang layak dilewat. Yang
    /// dilonggarkan cuma kolom yang DB-nya sendiri bilang boleh null.
    test('respons yang beneran rusak tetap dilewat', () {
      final rusak = Map<String, dynamic>.from(akun())..remove('nama');

      expect(parseListAman<User>([rusak], User.fromJson), isEmpty);
    });
  });

  group('BUG-022 · titik_ukur bisa datang sebagai String', () {
    Map<String, dynamic> baris({required Object? titikUkur}) => {
      'id': 11,
      'titik_ke': 1,
      'titik_ukur': titikUkur,
      'pembacaan_ke': 1,
      'pembacaan': 50.02,
      'input_source': 'manual',
      'is_verified': true,
    };

    /// Perlindungan yang dijanjikan komentarnya sendiri, tapi tidak pernah
    /// jalan:
    ///
    /// ```dart
    /// (json['titik_ukur'] as num?)?.toDouble()
    ///     ?? double.tryParse('${json['titik_ukur']}') ?? 0
    /// ```
    ///
    /// `as num?` cuma lolos buat `null` atau `num`. Begitu nilainya String,
    /// ekspresi PERTAMA sudah melempar — jadi baris `tryParse` di bawahnya
    /// tidak pernah tercapai.
    test('String ke-parse jadi angka, bukan melempar', () {
      expect(RawMeasurement.fromJson(baris(titikUkur: '50.00000000')).titikUkur, 50.0);
    });

    test('angka tetap kebaca seperti sebelumnya', () {
      expect(RawMeasurement.fromJson(baris(titikUkur: 6.9889072)).titikUkur, 6.9889072);
      expect(RawMeasurement.fromJson(baris(titikUkur: 7)).titikUkur, 7.0);
    });

    test('null jatuh ke 0, sama seperti sebelumnya', () {
      expect(RawMeasurement.fromJson(baris(titikUkur: null)).titikUkur, 0);
    });

    /// Yang tidak bisa dibaca sebagai angka tetap 0 — bukan melempar, karena
    /// melempar berarti seluruh barisnya raib lewat `parseListAman`.
    test('teks yang bukan angka jatuh ke 0, bukan bikin barisnya ilang', () {
      final daftar = parseListAman<RawMeasurement>([
        baris(titikUkur: 'entah'),
      ], RawMeasurement.fromJson);

      expect(daftar, hasLength(1));
      expect(daftar.single.titikUkur, 0);
    });

    /// Yang paling penting: barisnya SAMPAI ke layar.
    ///
    /// Assert "tidak melempar" saja belum menangkap bug-nya — yang dulu
    /// terjadi memang bukan crash, tapi baris yang menghilang dari tabel.
    test('baris String nggak ilang dari daftar pembacaan mentah', () {
      final daftar = parseListAman<RawMeasurement>([
        baris(titikUkur: 50.0),
        baris(titikUkur: '50.00000000'),
        baris(titikUkur: 60.0),
      ], RawMeasurement.fromJson);

      expect(daftar, hasLength(3));
      expect(daftar.map((r) => r.titikUkur), [50.0, 50.0, 60.0]);
    });
  });
}
