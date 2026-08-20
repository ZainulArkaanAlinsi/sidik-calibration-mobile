import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// DO Meter (alat ke-9) — jalur generik, tanpa layar khusus.
///
/// Angka acuannya disalin dari master `Master Olah Data_DO Meter.xlsm`, sesi
/// `0566-CAL-624`. BUKAN dihitung ulang di sini: mobile nggak menghitung
/// apa pun, dan menyalin rumusnya ke Dart cuma bikin dua sumber kebenaran yang
/// cepat atau lambat berbeda.
///
/// Yang dijaga di sini justru hal-hal yang gampang salah kalau ditebak dari
/// kertasnya, dan salahnya nggak keluar sebagai error — cuma angka yang salah
/// di dokumen terakreditasi.
void main() {
  final service = MockLembarKerjaService();

  Future<LembarKerja> bentuk() =>
      service.ambilBentuk('mock-token-1', profil: 'do_meter');

  test('nama alatnya diarahkan ke profil do_meter', () {
    expect(profilLembarKerjaUntuk('DO Meter'), 'do_meter');
    // Sebagian data alat pelanggan nulisnya tanpa spasi.
    expect(profilLembarKerjaUntuk('DOMeter'), 'do_meter');
  });

  test('bentuk yang balik bukan lembar pH Meter', () async {
    final b = await bentuk();

    expect(b.judul, 'Calibration Worksheet - DO Meter');
    expect(b.kodeDokumen, 'SIDIK-FM-CAL-0532_Rev.2');
    expect(b.kodeMetode, 'SIDIK-IK-CAL-0530_Rev.2');
    expect(b.satuan, 'mg/L');
  });

  /// Kertasnya mencetak "Zero Oxygen Std. 0.0 mg/l", tapi itu larutan buat
  /// MENOL-KAN alat sebelum diukur — bukan titik kalibrasinya. Titik yang
  /// dilaporkan & terakreditasi 8,77 mg/L. Pola yang sama dengan Chlorine,
  /// yang kertasnya nyetak 0,4/4 tapi titiknya 1,74/1,83.
  test('satu titik 8,77 mg/L — bukan 0,00 yang tercetak di kertas', () async {
    final b = await bentuk();

    expect(b.larutanStandar, [8.77]);

    for (final t in b.bagian.expand((s) => s.tabel)) {
      expect(t.baris.map((r) => r.titikUkur), [8.77]);
      expect(t.baris.map((r) => r.label), ['8,77']);
    }
  });

  test('dua tahap, kolom mg/L + suhu larutan, lima Repeat', () async {
    final tabel = (await bentuk()).bagian.expand((s) => s.tabel).toList();

    expect(tabel.map((t) => t.tahap), [
      'sebelum_adjustment',
      'sesudah_adjustment',
    ]);

    for (final t in tabel) {
      // Nilai acuan larutan diinterpolasi di suhu terukur, jadi suhunya ikut
      // per pembacaan — bukan sekali per lembar.
      expect(t.kolom.map((k) => k.kode), ['pembacaan', 'suhu']);
      expect(t.pengulangan, [1, 2, 3, 4, 5]);
    }
  });

  /// Di kertas DO Meter, kotak centang TH-2/6/7/4 ada di blok hasil — beda
  /// dari pH & Chlorine yang menaruhnya di identitas alat.
  test('thermohygro ada di bagian hasil, bukan identitas alat', () async {
    final b = await bentuk();

    final hasil = b.bagian.firstWhere((s) => s.kode == 'hasil');
    final identitas = b.bagian.firstWhere((s) => s.kode == 'identitas_alat');

    expect(
      hasil.field.map((f) => f.kode),
      contains('thermohygro_standard_id'),
    );
    expect(
      identitas.field.map((f) => f.kode),
      isNot(contains('thermohygro_standard_id')),
    );
  });

  /// Seluruh perhitungan %O2 di master rusak (`#DIV/0!` / `#REF!`) — di
  /// `SERTIFIKAT`, sel U95 %O2 pun `#REF!`. Backend cuma mengolah mg/L, sama
  /// dengan yang benar-benar tercetak di sertifikat.
  test('nggak ada kolom %O2 di lembar kerjanya', () async {
    final b = await bentuk();

    final semuaKolom = [
      for (final t in b.bagian.expand((s) => s.tabel))
        for (final k in t.kolom) '${k.kode} ${k.label} ${k.satuan}',
    ];

    expect(semuaKolom.where((k) => k.contains('%O2')), isEmpty);
  });

  /// Tanpa baris CMC, kartunya nggak muncul di picker walau profilnya sudah
  /// dikenal — dan lembar kerjanya nggak bisa dibuka lewat jalur mana pun.
  test('kartunya muncul di picker lewat baris CMC', () async {
    final detail = await MockCategoryService().detail(
      'mock-token-1',
      'instrumen-analitik',
    );

    final doMeter = detail.kemampuan.where((k) => k.namaAlat == 'DO Meter');

    expect(doMeter, isNotEmpty);
    // U95 dilaporkan di master 0,16 mg/L — CMC yang menang atas U hitung
    // (0,148) lewat `MAX(U, CMC)`.
    expect(doMeter.first.ketidakpastianTerbaik, 0.16);
    expect(doMeter.first.satuan, 'mg/L');
  });
}
