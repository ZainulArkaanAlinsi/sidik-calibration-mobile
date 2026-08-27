import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/category_service.dart';

/// `punyaToleransi` di `MockCategoryService` harus sama dengan jawaban server.
///
/// ## Kenapa test ini ada
///
/// Jawaban sebenarnya lahir di server, dari `CalibrationProfileRegistry` —
/// mobile nggak bisa nanya ke situ, dan **itu justru masalahnya**: mock ini
/// salinan tulis tangan, dan salinan tulis tangan ketinggalan tanpa bunyi.
/// Waktu tabel ini pertama diisi, `DO Meter` dan `Gas Detector` kelewat: di
/// build `USE_MOCK=true` dua alat itu masih maksa teknisi ngisi toleransi yang
/// masternya nggak punya.
///
/// Jadi tabel di bawah ini yang dipatok, dan tiap nama alat di mock wajib ada
/// di sini. Nambah baris kemampuan baru tanpa mikirin vonisnya bakal MERAH,
/// bukan lolos diam-diam.
///
/// **Cara memperbarui** kalau registry di backend berubah:
/// ```
/// php artisan tinker --execute='
///   $r = app(\App\Services\Calibration\CalibrationProfileRegistry::class);
///   foreach (["pH Meter", ...] as $n) {
///     echo $n." => ".($r->untukNamaAlat($n)->punyaToleransi() ? "true" : "false")."\n";
///   }'
/// ```
void main() {
  /// Diadu ke `CalibrationProfileRegistry` di
  /// `sidik-calibration-api`, 27 Agt 2026.
  ///
  /// `false` = masternya berhenti di `Correction` + `U95%` tanpa batas
  /// keberterimaan. 15 dari 20 profil begitu, dan `CalibrationValidator`
  /// sengaja melewatinya — jadi mewajibkan toleransi di situ menyuruh teknisi
  /// mengarang kriteria kelulusan.
  const vonis = <String, bool>{
    // Divonis PASS/FAIL — toleransinya beneran penentu.
    'Jangka Sorong': true,
    'Micrometer': true,
    'pH Meter': true,
    'Turbidimeter': true,
    'Chlorin Meter': true,
    'Refractometer': true,
    'Viscometer': true,

    // Nggak divonis — masternya berhenti di U95%.
    'Conductivity Meter': false,
    'Spectrophotometer': false,
    'DO Meter': false,
    'Gas Detector': false,
    'Temperature Indicator tanpa Sensor': false,
    'Temperatur Indikator dengan Sensor': false,
    'Oven': false,
    'Bath': false,
    'Inkubator': false,
    'Furnace': false,
    'Refrigerator': false,
    'Thermocouple': false,
    'Termometer Gelas': false,
    'Thermohygrometer': false,
  };

  const kategori = [
    'panjang',
    'instrumen-analitik',
    'suhu-dan-kelembapan',
    'massa',
    'tekanan',
  ];

  test('tiap baris kemampuan di mock vonisnya sama dengan server', () async {
    final layanan = MockCategoryService();
    final terlihat = <String>{};

    for (final kode in kategori) {
      final detail = await layanan.detail('mock-token-1', kode);
      for (final k in detail.kemampuan) {
        terlihat.add(k.namaAlat);

        expect(
          vonis.containsKey(k.namaAlat),
          isTrue,
          reason:
              'Baris kemampuan "${k.namaAlat}" ada di mock tapi nggak ada di '
              'tabel vonis test ini. Tanya dulu ke registry backend alat ini '
              'divonis PASS/FAIL apa nggak, lalu tambahin ke tabelnya — jangan '
              'dibiarin ngikut bawaan `true`.',
        );

        expect(
          k.punyaToleransi,
          vonis[k.namaAlat],
          reason:
              '"${k.namaAlat}": mock bilang punyaToleransi=${k.punyaToleransi}, '
              'server bilang ${vonis[k.namaAlat]}. Bedanya kelihatan di build '
              'USE_MOCK: form Tambah Alat minta angka yang beda dari yang '
              'diminta server.',
        );
      }
    }

    // Arah sebaliknya: nama yang dipatok tapi hilang dari mock berarti kartunya
    // nggak nongol di picker sama sekali — persis yang dulu kejadian di
    // Viscometer, Spectrophotometer, dan ketiga alat suhu.
    expect(
      vonis.keys.toSet().difference(terlihat),
      isEmpty,
      reason: 'nama alat ini dipatok test tapi nggak ada di mock',
    );
  });

  test('tiga alat suhu baru bawa `profil` sendiri di mock', () async {
    // Kartunya nongol itu belum cukup. Penentu lembar di picker-nya
    // `kemampuan.profil ?? profilLembarKerjaUntuk(namaAlat)`, dan penebak
    // dari nama (`_profilKhusus`) NGGAK kenal ketiga nama ini. Tanpa `profil`
    // di baris mock-nya, di build USE_MOCK yang kebuka form GENERIK — bukan
    // lembar suhunya. Kelihatan jadi, padahal nggak.
    const wajib = {
      'Thermocouple': 'thermocouple',
      'Termometer Gelas': 'thermometer_glass',
      'Thermohygrometer': 'thermohygro',
    };

    final detail = await MockCategoryService()
        .detail('mock-token-1', 'suhu-dan-kelembapan');

    for (final entri in wajib.entries) {
      final baris = detail.kemampuan.where((k) => k.namaAlat == entri.key);

      expect(baris, isNotEmpty, reason: '${entri.key} nggak ada di mock');
      for (final k in baris) {
        expect(
          k.profil,
          entri.value,
          reason:
              '${entri.key} harus bawa profil "${entri.value}" — kalau null, '
              'picker jatuh ke penebak nama yang nggak kenal alat ini, dan '
              'yang kebuka form generik',
        );
      }
    }
  });
}
