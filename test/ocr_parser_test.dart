import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/ocr_service.dart';

/// Parser angka hasil scan layar pH meter.
///
/// Diuji terpisah dari ML Kit **dengan sengaja**: bagian yang paling gampang
/// salah itu bukan pengenalan hurufnya (itu urusan ML Kit), tapi keputusan
/// "dari sekian angka di layar, yang mana pH-nya". Kalau ini salah, teknisi
/// dapat angka ngawur yang kelihatan meyakinkan — jauh lebih bahaya daripada
/// OCR yang terang-terangan gagal.
void main() {
  group('milih angka pH', () {
    test('layar pH + suhu → pH yang diambil, suhu nggak ketuker', () {
      // Layar Mettler Toledo nampilin dua angka sekaligus.
      final hasil = PhOcrParser.pilih('4.01 pH\n22.2 °C', perkiraan: 4.0092);

      expect(hasil, isNotNull);
      expect(hasil!.nilai, 4.01);
      expect(
        hasil.suhu,
        22.2,
        reason: 'suhu di luar skala pH, harus masuk kolomnya sendiri',
      );
    });

    test('koma dianggap desimal, bukan pemisah ribuan', () {
      // Layar & worksheet di sini pakai format Indonesia.
      final hasil = PhOcrParser.pilih('7,04 pH', perkiraan: 6.9885);

      expect(hasil?.nilai, 7.04);
    });

    test('buffer 10: suhu 22,2 nggak kepilih walau lebih dulu muncul', () {
      // Urutan di layar nggak selalu pH duluan. Kalau parser cuma ambil angka
      // pertama, buffer 10 bakal keisi 22,2.
      final hasil = PhOcrParser.pilih('22,2 C  9,94 pH', perkiraan: 9.9778);

      expect(hasil?.nilai, 9.94);
      expect(hasil?.suhu, 22.2);
    });

    test('pembacaan menyimpang tetap diloloskan — itu justru temuannya', () {
      // Alat rusak baca 9,61 di buffer 10. Parser NGGAK boleh buang ini:
      // sebaran jelek itu yang bikin MAX STDEV 0,144 di worksheet asli.
      final hasil = PhOcrParser.pilih('9,61 pH', perkiraan: 9.9778);

      expect(hasil?.nilai, 9.61);
    });

    test('angka kejauhan dari buffer → null, bukan diisi ngawur', () {
      // Kefoto layar yang salah. Lebih baik ngaku nggak kebaca daripada ngisi
      // angka yang keburu ke-approve.
      final hasil = PhOcrParser.pilih('1,20 pH', perkiraan: 9.9778);

      expect(hasil, isNull);
    });

    test('teks tanpa angka → null', () {
      expect(PhOcrParser.pilih('READY', perkiraan: 4.0), isNull);
      expect(PhOcrParser.pilih('', perkiraan: 4.0), isNull);
    });

    test('cuma ada angka di luar skala pH → null', () {
      // Yang kefoto cuma bagian suhunya.
      expect(PhOcrParser.pilih('22,2 °C', perkiraan: 7.0), isNull);
    });
  });

  group('keyakinan', () {
    test('makin nempel ke nilai buffer, makin tinggi', () {
      final pas = PhOcrParser.pilih('4,01 pH', perkiraan: 4.01)!;
      final meleset = PhOcrParser.pilih('4,60 pH', perkiraan: 4.01)!;

      expect(pas.keyakinan, greaterThan(meleset.keyakinan));
      expect(pas.keyakinan, closeTo(1.0, 0.01));
    });

    test('tanpa perkiraan buffer, keyakinannya ditandai rendah', () {
      final hasil = PhOcrParser.pilih('7,00 pH')!;

      expect(
        hasil.keyakinan,
        lessThan(0.5),
        reason: 'nggak ada dasar buat mastiin, teknisi harus ngecek',
      );
    });
  });

  test('teks mentah disimpan apa adanya buat bukti', () {
    const layar = '4,01 pH  22,2 °C  ATC';
    final hasil = PhOcrParser.pilih(layar, perkiraan: 4.0092)!;

    // Dikirim ke backend sebagai `ocr_raw_text` — kalau ada sengketa angka,
    // ini yang dibuka.
    expect(hasil.teksMentah, layar);
  });
}
