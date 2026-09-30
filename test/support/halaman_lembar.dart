import 'package:flutter_test/flutter_test.dart';

/// Balik lembar kerja sampai halaman terakhir.
///
/// Sejak 26 Sep 2026 server membelah SEMUA lembar jadi dua halaman —
/// persiapan (identitas, pemilik, standar, lokasi) | pengukuran (tabel, grid,
/// kondisi lingkungan, penutup) — lewat `CalibrationProfile::susunDuaHalaman`.
/// Test yang memeriksa tabel, grid, atau tombol kirim harus membalik halaman
/// dulu; di layar sempit (< 1100) halaman 2 memang belum digambar.
///
/// Aman dipanggil di lembar satu halaman: tombolnya tidak ada, jadi tidak ada
/// yang ditekan.
Future<void> keHalamanAkhir(WidgetTester tester) async {
  final lanjut = find.text('Lanjut ke halaman berikutnya');
  while (lanjut.evaluate().isNotEmpty) {
    await tester.tap(lanjut);
    await tester.pumpAndSettle();
  }
}
