import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';

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
}
