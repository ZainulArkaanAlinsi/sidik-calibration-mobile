import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Sapuan registry sisi HP: **tiap** profil server punya bentuk mock-nya
/// sendiri, atau terdaftar sebagai utang berikut alasannya.
///
/// ## Kenapa test ini ada
///
/// Sisi server punya `SemuaProfilLembarKerjaTest` yang menyapu registry, jadi
/// profil ke-29 ikut teruji tanpa ada yang perlu ingat. Sisi HP nggak punya
/// padanannya — dan akibatnya sudah terukur: **tujuh** profil diam-diam
/// memajang lembar pH tiga titik buffer di mode mock, tanpa satu pun error.
///
/// Itu bukan bug produksi (mode mock cuma hidup di build `USE_MOCK=true`).
/// Yang bikin dia mahal: bug yang lolos ke `main` sudah TIGA kali lolos justru
/// karena bentuk mock-nya nggak ada, jadi nggak ada satu pun test yang pernah
/// menyuapkan bentuk aslinya ke parser —
///
///  - **TIDS**: `titik_ukur: null` bikin barisnya jadi `[]`;
///  - **Timbangan**: lima cacat sekaligus, termasuk 39 kotak yang read-only
///    tanpa sadar dan kunci baris yang bentrok antar tabel;
///  - **Micrometer**: tiga cacat server yang lolos 3.128 test backend, karena
///    test backend memakai payload yang ditulis backend sendiri.
///
/// ## Kenapa daftarnya dari JSON, bukan diketik di sini
///
/// Daftar yang diketik tangan SELALU ketinggalan, dan repo ini sudah mencatat
/// lima kejadiannya (template OCR 7→17, `EquipmentFactory`, komentar "lembar
/// tanpa vonis", tabel vonis mock, `CetakLembarKerjaOcrTest`).
/// `kode_profil.json` digenerate dari `CalibrationProfileRegistry` server
/// (`docs/skrip/gen-kode-profil-mobile.php`), jadi alat ke-29 masuk ke sini
/// tanpa ada yang perlu ingat menambahkannya.
///
/// ## Yang diuji PERILAKU, bukan teks
///
/// Test ini nggak membaca `switch`-nya. Dia MEMANGGIL mock-nya untuk tiap kode
/// dan membandingkan judul lembar yang balik ke judul lembar pH. Cocok = kode
/// itu jatuh ke cabang bawaan. Membaca sumbernya pakai regex bakal lulus untuk
/// cabang yang ADA tapi memulangkan bentuk yang salah.
void main() {
  /// Utang yang SUDAH ada waktu penjaga ini dipasang — bukan izin permanen.
  ///
  /// Tiap entri wajib menyebut AKIBATNYA kalau dibiarkan, bukan cuma "belum
  /// dibuat". Daftar yang isinya alasan kosong berubah jadi tempat sampah, dan
  /// penjaga yang daftarnya penuh berhenti menjaga apa pun.
  const tanpaBentukMock = <String, String>{
    'autoclave':
        'Lembar Autoklaf TIGA bagian (Sebaran Suhu, Kinerja, Tekanan) yang '
        'bentuknya beda satu sama lain; dipaksa ke bentuk pH, ketiganya hilang.',
    'conductivity_meter':
        'Satu-satunya lembar instrumen analitik yang belum punya bentuk mock, '
        'padahal dia DIVONIS PASS/FAIL — vonisnya nggak pernah teruji di HP.',
    // Kelima Enclosure paling berbahaya di daftar ini: lembarnya GRID
    // (9 termokopel x 5 set point), dan bentuk pH tiga titik buffer nggak punya
    // satu pun kotak yang cocok. Yang kegambar lembar yang sama sekali lain,
    // dan nggak ada error di mana pun.
    'oven':
        'Lembar GRID 9 termokopel x set point; bentuk pH tiga titik buffer '
        'nggak punya satu pun kotak yang cocok.',
    'furnace':
        'Lembar GRID, sama seperti Oven — bentuk pH nggak punya kotaknya.',
    'bath': 'Lembar GRID, sama seperti Oven — bentuk pH nggak punya kotaknya.',
    'inkubator':
        'Lembar GRID, sama seperti Oven — bentuk pH nggak punya kotaknya.',
    'refrigerator':
        'Lembar GRID, sama seperti Oven — bentuk pH nggak punya kotaknya.',
  };

  late List<Map<String, dynamic>> profil;
  late String judulPh;

  setUpAll(() async {
    final berkas = File('test/fixtures/kode_profil.json');

    expect(
      berkas.existsSync(),
      isTrue,
      reason:
          'test/fixtures/kode_profil.json nggak ada. Digenerate dari repo API: '
          'php docs/skrip/gen-kode-profil-mobile.php',
    );

    final isi = jsonDecode(berkas.readAsStringSync()) as Map<String, dynamic>;
    profil = (isi['profil'] as List).cast<Map<String, dynamic>>();

    final ph = await MockLembarKerjaService().ambilBentuk(
      't',
      profil: 'ph_meter',
    );
    judulPh = ph.judul;
  });

  test('daftar profilnya nggak menyusut diam-diam', () {
    // Penjaga lantai. Berkas fixture yang gagal digenerate (atau ter-truncate)
    // bikin sapuan di bawah memeriksa nol profil dan tetap HIJAU — persis cara
    // test sapuan gagal tanpa bersuara.
    expect(
      profil.length,
      greaterThanOrEqualTo(28),
      reason:
          'Registry server punya 28 profil waktu penjaga ini dipasang. Kalau '
          'sekarang lebih sedikit, fixture-nya basi atau gagal digenerate — '
          'bukan profilnya yang dihapus.',
    );
  });

  test('tiap profil server punya bentuk mock-nya sendiri', () async {
    final jatuhKePh = <String>[];

    for (final p in profil) {
      final kode = p['kode'] as String;

      // pH itu cabang BAWAAN-nya sendiri — dia memang harus memulangkan pH.
      if (kode == 'ph_meter') continue;

      final bentuk = await MockLembarKerjaService().ambilBentuk(
        't',
        profil: kode,
      );

      if (bentuk.judul == judulPh) jatuhKePh.add(kode);
    }

    final belumTerdaftar = jatuhKePh
        .where((k) => !tanpaBentukMock.containsKey(k))
        .toList();

    expect(
      belumTerdaftar,
      isEmpty,
      reason:
          'Profil berikut jatuh ke lembar pH di mode mock tanpa terdaftar di '
          'tanpaBentukMock: $belumTerdaftar.\n'
          'Yang kegambar bukan error — cuma lembar yang SALAH, dan itu bentuk '
          'kegagalan yang paling mahal di proyek ini.\n'
          'Bikin bentuk mock-nya (lihat contoh_lembar_kerja_*.dart), atau '
          'daftarkan di tanpaBentukMock berikut AKIBATNYA kalau dibiarkan.',
    );
  });

  test('daftar utang nggak menyimpan entri yang sudah lunas', () async {
    final sudahPunyaBentuk = <String>[];

    for (final kode in tanpaBentukMock.keys) {
      final bentuk = await MockLembarKerjaService().ambilBentuk(
        't',
        profil: kode,
      );

      if (bentuk.judul != judulPh) sudahPunyaBentuk.add(kode);
    }

    // Arah SEBALIKNYA, dan ini yang bikin daftarnya nggak jadi tempat sampah:
    // entri yang bentuk mock-nya sudah dibuat harus DICABUT. Dibiarkan, daftar
    // utang ini pelan-pelan berubah jadi daftar pengecualian permanen yang
    // nggak ada yang berani sentuh — persis yang terjadi pada tabel vonis mock
    // dan komentar "lembar tanpa vonis".
    expect(
      sudahPunyaBentuk,
      isEmpty,
      reason:
          'Profil berikut SUDAH punya bentuk mock tapi masih terdaftar sebagai '
          'utang: $sudahPunyaBentuk. Cabut dari tanpaBentukMock.',
    );
  });

  test('tiap entri utang menyebut alasannya, bukan cuma nama', () {
    for (final e in tanpaBentukMock.entries) {
      expect(
        e.value.length,
        greaterThan(30),
        reason:
            'Alasan utang `${e.key}` terlalu pendek. Tiap entri wajib menyebut '
            'AKIBATNYA kalau dibiarkan — daftar yang isinya "belum dibuat" '
            'berubah jadi tempat sampah, dan penjaga yang daftarnya penuh '
            'berhenti menjaga apa pun.',
      );
    }
  });
}
