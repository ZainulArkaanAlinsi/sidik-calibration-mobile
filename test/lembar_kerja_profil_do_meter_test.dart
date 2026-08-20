import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Profil `do_meter` harus dapat lembar DO METER, bukan lembar pH Meter.
///
/// `MockLembarKerjaService.ambilBentuk` mencocokkan profil lewat `switch`, dan
/// cabang yang nggak dikenal SENGAJA jatuh ke pH — itu janji kontraknya
/// (`docs/kontrak-api.md` §4). Kegagalan yang mau dicegah di sini sama persis
/// kayak yang kejadian di Viscometer: picker udah kenal namanya dan kartunya
/// nongol, tapi `switch`-nya ketinggalan, jadi di mode offline tap kartu DO
/// Meter kebuka formulir pH Meter — titik & tabelnya alat lain, tanpa satu pun
/// error.
void main() {
  final service = MockLembarKerjaService();

  Future<LembarKerja> bentukUntuk(String profil) =>
      service.ambilBentuk('mock-token-1', profil: profil);

  test('picker mengarahkan nama alatnya ke profil do_meter', () {
    expect(profilLembarKerjaUntuk('DO Meter'), 'do_meter');
    // Nama alat pelanggan yang bermerek tetap ketemu lembarnya.
    expect(profilLembarKerjaUntuk('DO Meter Mettler Toledo'), 'do_meter');
  });

  test('kartunya beneran muncul di picker offline', () async {
    final detail = await MockCategoryService().detail(
      'mock-token-1',
      'instrumen-analitik',
    );

    final doMeter =
        detail.kemampuan.where((k) => k.namaAlat == 'DO Meter').toList();

    expect(doMeter, hasLength(1), reason: 'Tanpa baris CMC, kartunya nggak nongol.');
    expect(doMeter.first.rangeMin, 8.77);
    expect(doMeter.first.ketidakpastianTerbaik, 0.16);
  });

  test('bentuk yang balik bukan lembar pH Meter', () async {
    final bentuk = await bentukUntuk('do_meter');

    expect(bentuk.judul, 'Calibration Worksheet - DO Meter');
    expect(bentuk.kodeDokumen, 'SIDIK-FM-CAL-0532_Rev.2');
    expect(bentuk.satuan, 'mg/L');
  });

  /// Titiknya 8,77 — BUKAN 0,00 yang tercetak di kertas Rev.2. "Zero Oxygen
  /// Std. 0.0 mg/l" di form itu larutan penol alat, bukan titik kalibrasi.
  /// Kalau ada yang "mbenerin" ini ngikut kertasnya, test ini yang teriak.
  test('satu titik 8,77 — bukan 0,00 yang tercetak di kertas', () async {
    final bentuk = await bentukUntuk('do_meter');
    final tabel = bentuk.bagian.expand((b) => b.tabel).toList();

    expect(tabel.map((t) => t.tahap), [
      'sebelum_adjustment',
      'sesudah_adjustment',
    ]);

    for (final t in tabel) {
      expect(t.baris.map((b) => b.titikUkur), [8.77]);
      expect(t.baris.map((b) => b.label), ['8,77']);
      // Tiap Repeat punya dua sub-kolom — pembacaan mg/L DAN suhu larutannya.
      expect(t.kolom.map((k) => k.kode), ['pembacaan', 'suhu']);
      expect(t.pengulangan, [1, 2, 3, 4, 5]);
    }
  });

  /// Thermohygro DO Meter ada di blok CALIBRATION RESULT (kotak centang
  /// TH-2/6/7/4 di kertas), bukan di EQUIPMENT IDENTITY kayak lembar
  /// pH/Chlorine. Bentuk mock harus ikut kertasnya, bukan ikut tetangganya.
  test('thermohygro ada di blok hasil, ikut kertasnya', () async {
    final bentuk = await bentukUntuk('do_meter');

    final hasil = bentuk.bagian.firstWhere((b) => b.kode == 'hasil');
    expect(
      hasil.field.map((f) => f.kode),
      contains('thermohygro_standard_id'),
    );

    final identitas = bentuk.bagian.firstWhere((b) => b.kode == 'identitas_alat');
    expect(
      identitas.field.map((f) => f.kode),
      isNot(contains('thermohygro_standard_id')),
    );
  });
}
