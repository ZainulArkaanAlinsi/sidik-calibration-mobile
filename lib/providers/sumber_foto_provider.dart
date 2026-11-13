import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigasi_global.dart';
import '../screens/calibration/kamera_pindai_screen.dart';
import '../services/kamera_pindai.dart';
import '../services/kamera_plugin.dart';
import '../services/photo_source.dart';

/// Saklar KAMERA SENDIRI — bawaan MENYALA (sejak 13 Nov 2026, keputusan
/// pemilik: dicoba langsung di aplikasi asli, tanpa APK uji terpisah).
///
/// Menyala (rilis biasa) = HP memakai layar kamera sendiri
/// ([KameraAplikasiSumberFoto]) untuk alur "Foto lembar kerja" MAUPUN "Foto
/// tabel ini" (keduanya memakai [sumberFotoProvider]); cadangan `image_picker`
/// bila kamera tidak ada atau gagal dibuka.
///
/// PERHATIAN: sebelum dibalik, layar kamera BELUM terbukti di HP nyata
/// (fokus ketuk, senter, JPEG, ambang saran per merek). Bukti HP masih harus
/// dikumpulkan; lihat komentar `camera:` di `pubspec.yaml`.
///
/// Mati darurat (kembali ke jalur lama `image_picker`, [KameraSumberFoto]):
/// bangun dengan `--dart-define=KAMERA_SENDIRI=false`, atau balikkan
/// bawaan di sini lewat PR. Dijaga `test/kamera_aplikasi_sumber_foto_test.dart`.
/// Const (compile-time), seperti `tampilkanUkurOcrAktif`: tidak bisa
/// dinyalakan dari UI.
const bool kKameraSendiri = bool.fromEnvironment(
  'KAMERA_SENDIRI',
  defaultValue: true,
);

/// Pembuka sesi kamera sendiri. Provider terpisah supaya test bisa mengganti
/// kameranya dengan tiruan (plugin `camera` tidak jalan di host).
final pabrikKontrolKameraProvider = Provider<PabrikKontrolKamera>(
  (ref) => KontrolKameraPlugin.buka,
);

/// Pilihan sumber foto menurut platform dan saklar [kKameraSendiri] — dipisah
/// dari provider supaya cabang HP (yang tak bisa dijalankan di host) dan kedua
/// keadaan saklar tetap bisa diuji.
///
/// - bukan HP → pemilih berkas;
/// - HP, [kameraSendiri] mati → `image_picker` lama ([KameraSumberFoto]);
/// - HP, [kameraSendiri] menyala → kamera sendiri (cadangannya tetap
///   `image_picker`).
SumberFoto pilihSumberFoto({
  required bool seluler,
  required bool kameraSendiri,
  required BukaLayarKamera bukaLayar,
}) {
  if (!seluler) return const BerkasSumberFoto();
  if (!kameraSendiri) return const KameraSumberFoto();

  return KameraAplikasiSumberFoto(bukaLayar: bukaLayar);
}

/// Sumber foto buat alur pindai, DIPILIH SESUAI PLATFORM.
///
/// Dulu selalu `KameraSumberFoto` tanpa syarat. Di macOS & Windows itu bikin
/// tombol foto pasti gagal: `image_picker` nggak punya implementasi kamera di
/// sana sama sekali, dan app macOS-nya juga nggak punya entitlement kamera.
/// Tombolnya kelihatan normal, ditekan, lalu error — tiap kali.
///
/// Sekarang desktop pilih BERKAS gambar ([BerkasSumberFoto]); HP tetap kamera
/// beneran lewat `image_picker` ([KameraSumberFoto]), termasuk di build
/// `USE_MOCK`, biar izin & alur ambil fotonya tetap keuji di perangkat
/// aslinya. HANYA bila [kKameraSendiri] menyala (APK uji), HP memakai KAMERA
/// SENDIRI ([KameraAplikasiSumberFoto]: senter, bingkai panduan, petunjuk
/// langsung), yang jatuh ke `image_picker` bila tak bisa dibuka — lihat
/// kelasnya.
///
/// Layar kamera dibuka lewat `navigatorKey` (satu-satunya navigator aplikasi),
/// karena [SumberFoto.ambil] sengaja tidak membawa `BuildContext`: sumber lain
/// (berkas, tiruan) tidak membutuhkannya.
///
/// Di test di-override pakai [MockSumberFoto] biar kameranya nggak kepanggil.
///
/// Berkasnya sendiri: dulu numpang di `worksheet_vision_provider.dart` — file
/// jalur AI Vision cloud, yang sekarang SUDAH dicabut. Kamera nggak boleh mati
/// gara-gara jalur lain dihapus, jadi providernya berdiri sendiri — dan itu
/// yang bikin dia selamat waktu jalur itu beneran hilang.
final sumberFotoProvider = Provider<SumberFoto>((ref) {
  return pilihSumberFoto(
    seluler: Platform.isAndroid || Platform.isIOS,
    kameraSendiri: kKameraSendiri,
    bukaLayar: ({double? rasioKertas}) => bukaKameraPindai(
      navigator: navigatorKey.currentState,
      pabrik: ref.read(pabrikKontrolKameraProvider),
      rasioKertas: rasioKertas,
    ),
  );
});
