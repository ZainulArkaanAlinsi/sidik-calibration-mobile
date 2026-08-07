import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';

/// **Bug asli:** Alur Kerja membuka lembar kerja tanpa mengoper `profil`, jadi
/// jatuh ke default `ph_meter`. Melanjutkan draft / mbenerin lembar Chlorine
/// atau Turbidimeter yang dikembalikan admin bakal ngambil formulir pH.
///
/// Yang bikin ini nggak berhenti di salah tampilan: tombol foto tabel ngirim
/// `nominal` & `satuan` dari titik yang kebentuk di layar sebagai petunjuk ke
/// AI Vision. Formulir pH di atas lembar chlorine berarti AI dikasih tahu
/// "harap 3 kolom di 4/7/10,01" buat foto yang isinya 2 kolom 1,74/1,83 —
/// angkanya mendarat di sel yang salah, dan di lapangan kebaca sebagai
/// "kameranya meleset".
///
/// Sesi baru lewat Instrument Picker nggak pernah kena: di sana profilnya
/// diturunkan dari nama alat. Yang bocor cuma jalur LANJUTAN.
void main() {
  test('nama alat dipetakan ke profil lembar kerjanya', () {
    // Nama-nama ini diambil dari `equipment.nama_alat` di DB dev, bukan karangan.
    expect(profilLembarKerjaUntuk('Chlorine Meter'), 'chlorine_meter');
    expect(profilLembarKerjaUntuk('Turbidimeter'), 'turbidimeter');
    expect(profilLembarKerjaUntuk('pH Meter'), 'ph_meter');
    expect(profilLembarKerjaUntuk('Refractometer'), 'refractometer');

    // Alat tanpa lembar khusus → null, dan pemanggil yang jatuh ke `ph_meter`.
    // "pH Meter Bench" sengaja diuji: dia NGGAK cocok persis, dan itu memang
    // perilaku yang diinginkan sekarang — tapi nunjukin kenapa alat yang
    // dinamai "Turbidimeter HACH 2100Q" bakal ikut jatuh ke pH.
    expect(profilLembarKerjaUntuk('pH Meter Bench'), isNull);
    expect(profilLembarKerjaUntuk('Jangka Sorong Mitutoyo'), isNull);
  });

  // CELAH YANG DISADARI: test end-to-end yang beneran nge-tap "Buka lembar
  // kerja" di Alur Kerja belum ada. Panel tahapannya baru kebuka sesudah sesi
  // dipilih lewat MasterDetailPane, dan itu nggak berhasil digerakkan dari
  // widget test dalam waktu wajar. Jadi yang dikunci di sini BARU pemetaannya,
  // bukan pemanggilannya — kalau ada yang menghapus argumen `profil` di
  // `alur_kerja_screen.dart`, test ini TIDAK akan merah.
  //
  // Kalau kamu nambahin test itu nanti: yang mesti dibuktikan cuma satu, yaitu
  // `ambilBentuk` dipanggil dengan `chlorine_meter` (bukan `ph_meter`) waktu
  // sesi Chlorine dibuka dari Alur Kerja.

  /// Tiap alat yang punya lembar kerja sendiri WAJIB kelihatan di picker.
  ///
  /// **Ini nutup celah yang bikin Refractometer nggak kepakai sama sekali.**
  /// Pemetaan nama→profil di atas hijau sejak awal, dan seluruh test lembar
  /// kerja juga hijau — tapi mereka semua manggil `LembarKerjaScreen(profil:
  /// 'refractometer')` LANGSUNG. Pintu masuk yang beneran dipakai teknisi
  /// (Kategori → Instrumen Analitik → pilih alat) narik daftarnya dari
  /// [MockCategoryService], dan di situ Refractometer nggak pernah didaftarin.
  /// Hasilnya: 435 test hijau, tapi di HP picker-nya cuma nampilin empat alat
  /// lama dan lembar Refractometer nggak bisa dibuka lewat jalur mana pun.
  /// Ketahuan 7 Agt 2026, dan cuma karena app-nya beneran dijalanin.
  ///
  /// Sengaja diuji lewat nama alat, bukan jumlah kartu: yang penting tiap
  /// profil punya jalan masuk, bukan ada berapa baris CMC di baliknya.
  ///
  /// Diuji SATU ARAH doang — "punya lembar kerja ⇒ ada di picker". Arah
  /// sebaliknya sengaja tidak dijamin: Conductivity Meter ada di picker tanpa
  /// lembar sendiri, dan itu benar. Dia lanjut ke form kalibrasi generik, sama
  /// kayak alat lain yang belum punya formulir khusus.
  test('tiap alat yang punya lembar kerja muncul di picker', () async {
    final analitik = await MockCategoryService().detail(
      'token-test',
      'instrumen-analitik',
    );
    final namaAlat = analitik.kemampuan.map((k) => k.namaAlat).toSet();

    for (final nama in ['pH Meter', 'Turbidimeter', 'Chlorin Meter', 'Refractometer']) {
      expect(
        namaAlat,
        contains(nama),
        reason: '"$nama" punya lembar kerja tapi nggak muncul di picker',
      );
      expect(profilLembarKerjaUntuk(nama), isNotNull);
    }
  });
}
