import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Profil `viscometer` harus dapat lembar VISCOMETER, bukan lembar pH Meter.
///
/// `MockLembarKerjaService.ambilBentuk` mencocokkan profil lewat `switch`, dan
/// cabang yang nggak dikenal SENGAJA jatuh ke pH — itu janji kontraknya
/// (`docs/kontrak-api.md` §4). Waktu alat ke-7 disambungin, picker udah kenal
/// nama `Viscometer` dan `MockCategoryService` udah punya tiga baris CMC-nya,
/// jadi kartunya nongol dan bisa ditap — tapi `switch`-nya nggak ikut nambah.
/// Hasilnya di mode offline: tap kartu Viscometer, kebuka formulir pH Meter,
/// titik & tabelnya alat lain, dan nggak ada satu pun yang error.
///
/// Yang diuji di sini bukan "cabangnya ada" tapi bentuk yang balik beneran
/// punya ciri Viscometer — dua tahap adjustment dan Spindle per titik.
void main() {
  final service = MockLembarKerjaService();

  Future<LembarKerja> bentukUntuk(String profil) =>
      service.ambilBentuk('mock-token-1', profil: profil);

  test('picker mengarahkan nama alatnya ke profil viscometer', () {
    expect(profilLembarKerjaUntuk('Viscometer'), 'viscometer');
  });

  test('bentuk yang balik bukan lembar pH Meter', () async {
    final bentuk = await bentukUntuk('viscometer');

    expect(bentuk.judul, 'Calibration Worksheet - Viscometer');
    expect(bentuk.kodeDokumen, 'SIDIK-FM-CAL-0524_Rev.3');
    expect(bentuk.kodeMetode, 'SIDIK-IK-CAL-0517_Rev.3');
    expect(bentuk.satuan, 'cP');
  });

  test('dua tabel: Before & After Adjustment, tiga titik, lima Repeat', () async {
    final bentuk = await bentukUntuk('viscometer');
    final tabel = bentuk.bagian.expand((b) => b.tabel).toList();

    expect(tabel.map((t) => t.tahap), ['sebelum_adjustment', 'sesudah_adjustment']);

    for (final t in tabel) {
      // Nilai sertifikat larutan, BUKAN label bulat yang tercetak di kertas.
      expect(t.baris.map((b) => b.titikUkur), [99.65, 1018, 59003]);
      expect(t.baris.map((b) => b.label), ['100', '1000', '60000']);
      // Tiap Repeat punya dua sub-kolom — pembacaan DAN suhu larutannya.
      expect(t.kolom.map((k) => k.kode), ['pembacaan', 'suhu']);
      expect(t.pengulangan, [1, 2, 3, 4, 5]);
    }
  });

  test('Spindle & RPM per titik, bukan sekali per lembar', () async {
    final bentuk = await bentukUntuk('viscometer');
    final kode = bentuk.bagian
        .expand((b) => b.field)
        .map((f) => f.kode)
        .toList();

    for (var i = 1; i <= 3; i++) {
      expect(kode, contains('spesifikasi_alat.spindle_titik_$i'));
      expect(kode, contains('spesifikasi_alat.rpm_titik_$i'));
      expect(kode, contains('spesifikasi_alat.resolusi_titik_$i'));
    }
  });

  test('Spindle & Model bentuknya daftar pilihan, bukan isian bebas', () async {
    final bentuk = await bentukUntuk('viscometer');
    final field = bentuk.bagian.expand((b) => b.field);

    final spindle = field.firstWhere(
      (f) => f.kode == 'spesifikasi_alat.spindle_titik_1',
    );
    final model = field.firstWhere(
      (f) => f.kode == 'spesifikasi_alat.model_viscometer',
    );

    // SMC-nya beda 400x antar spindle — satu salah ketik nggeser Fullscale
    // ratusan kali, jadi kodenya dipilih dari daftar.
    expect(spindle.tipe, TipeField.pilihan);
    expect(spindle.pilihan.map((p) => p.nilai), contains('HA7'));
    expect(model.tipe, TipeField.pilihan);

    // Dua-duanya `spesifikasi_alat.*`, jadi nilainya masuk payload lewat
    // `kunciSpesifikasi` dan butuh kotak teks di `LembarKerjaState`.
    expect(spindle.spesifikasiAlat, isTrue);
    expect(model.spesifikasiAlat, isTrue);
  });

  test('profil yang nggak dikenal tetap jatuh ke pH, sesuai kontrak', () async {
    final bentuk = await bentukUntuk('alat_yang_belum_ada');
    expect(bentuk.judul, 'Calibration Worksheet - pH Meter');
  });
}
