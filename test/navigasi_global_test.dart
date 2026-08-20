import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/navigasi_global.dart';
import 'package:sidik_calibration/models/notification_item.dart';

/// Sandi tautan `tipe:id` — satu bentuk buat dua jalur ketukan.
///
/// Muatan notifikasi lokal (yang dinyalakan Reverb) dan `data` pesan Firebase
/// dua-duanya memakai bentuk ini. Kalau dibedakan, cepat atau lambat satu jalur
/// ikut berubah dan yang lain ketinggalan — dan gejalanya cuma "ketukannya
/// nggak ngapa-ngapain", tanpa satu error pun.
void main() {
  // `GlobalKey.currentContext` nyentuh binding widget, jadi binding-nya wajib
  // ada walau test ini nggak nge-render apa pun.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bolak-balik utuh', () {
    final sandi = sandiTautan(const NotifTautan(tipe: 'calibration', id: 42));
    expect(sandi, 'calibration:42');

    final balik = bacaTautan(sandi);
    expect(balik?.tipe, 'calibration');
    expect(balik?.id, 42);
  });

  test('tanpa tautan → tanpa sandi', () {
    expect(sandiTautan(null), isNull);
  });

  /// Bentuk yang nggak dikenal SENGAJA jadi `null`, bukan ditebak. Mendarat di
  /// layar yang salah lebih buruk daripada nggak lompat sama sekali.
  test('sandi rusak nggak dipaksa jadi tujuan', () {
    expect(bacaTautan(null), isNull);
    expect(bacaTautan(''), isNull);
    expect(bacaTautan('calibration'), isNull);
    expect(bacaTautan('calibration:bukan-angka'), isNull);
    expect(bacaTautan('calibration:42:99'), isNull);
  });

  /// Navigator belum terpasang itu keadaan NYATA: pesan yang menyalakan
  /// aplikasi dari keadaan mati sampai sebelum `MaterialApp` selesai dibangun.
  /// Yang benar diam, bukan meledak.
  test('buka tautan tanpa navigator nggak meledak', () {
    expect(
      () => bukaTautanDariLuar(const NotifTautan(tipe: 'calibration', id: 1)),
      returnsNormally,
    );
    expect(() => bukaTautanDariLuar(null), returnsNormally);
  });
}
