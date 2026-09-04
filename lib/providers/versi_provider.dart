import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/versi_aplikasi.dart';
import '../services/penyiap_update.dart';
import '../services/versi_service.dart';
import 'auth_provider.dart';

final versiServiceProvider = Provider<VersiService>((ref) {
  if (AppConfig.useMock) return MockVersiService();

  return ApiVersiService(ref.watch(apiClientProvider));
});

/// Versi + build yang terpasang di HP ini, mis. `1.0.58 (build 58)`.
///
/// Ditampilkan di layar Profil supaya pertanyaan "punyaku yang mana" bisa
/// dijawab dari HP-nya sendiri. Sebelum ini satu-satunya penanda versi ada di
/// catatan rilis App Distribution — yang cuma kelihatan sebelum dipasang,
/// bukan sesudah.
final versiTerpasangProvider = FutureProvider<String>((ref) async {
  final layanan = ref.watch(versiServiceProvider);
  final versi = await layanan.versiTerpasang();
  final build = await layanan.buildTerpasang();

  return build.trim().isEmpty ? versi : '$versi (build $build)';
});

/// Pemutakhiran yang tersedia, atau `null` kalau sudah paling baru / belum
/// bisa dicek.
///
/// **Tidak pernah melempar.** Pemeriksaan ini jalan waktu aplikasi dibuka, dan
/// teknisi di lapangan sering tanpa sinyal — kegagalan mengecek versi bukan
/// keadaan yang perlu ditampilkan, apalagi bikin layar error. Jawabannya cukup
/// "belum tahu", yang bentuknya sama dengan "sudah paling baru": null.
final updateTersediaProvider = FutureProvider<VersiAplikasi?>((ref) async {
  final layanan = ref.watch(versiServiceProvider);

  final VersiAplikasi? terbaru;
  final String terpasang;
  try {
    terbaru = await layanan.versiTerbaru();
    if (terbaru == null) return null;

    terpasang = await layanan.versiTerpasang();
  } catch (_) {
    return null;
  }

  // Perbandingan ANGKA per ruas, bukan teks — `1.4.9` lawan `1.4.12` terbaca
  // terbalik kalau dibandingkan sebagai huruf, dan salahnya diam.
  return terbaru.lebihBaruDari(terpasang) ? terbaru : null;
});

final penyiapUpdateProvider = Provider<PenyiapUpdate>((ref) {
  return PenyiapUpdateAsli();
});

/// Sudah ada APK siap pasang, jadi menekan tombol langsung membuka pemasang
/// tanpa menunggu unduhan.
///
/// Provider ini yang MEMULAI unduhan latar. Dibaca sekali waktu banner
/// digambar; kalau kondisinya pas (ada pemutakhiran + jaringan tak-berbayar),
/// 68 MB-nya diambil diam-diam tanpa banner, tanpa progres, tanpa apa pun yang
/// mengganggu layar. Yang teknisi lihat cuma hasilnya: "siap dipasang".
///
/// Di jaringan seluler ini pulang `false` tanpa mengunduh — dan bannernya jatuh
/// ke tombol "Pasang (68 MB)" yang lama, lengkap dengan ukurannya. Kuota orang
/// bukan milik kita.
final updateSiapProvider = FutureProvider<bool>((ref) async {
  final rilis = await ref.watch(updateTersediaProvider.future);
  if (rilis == null) return false;

  final penyiap = ref.watch(penyiapUpdateProvider);

  try {
    if (await penyiap.apkSiap(rilis.versi) != null) return true;

    return await penyiap.siapkan(rilis);
  } catch (_) {
    return false;
  }
});

/// Pengiriman kalibrasi sedang ditahan karena ada rilis WAJIB yang menunggu.
///
/// ## Keputusan 4 Sep 2026 — yang ditahan pengirimannya, BUKAN layarnya
///
/// Pertanyaannya lama terbuka di `banner_update.dart`: rilis wajib seharusnya
/// juga memblokir layar isian kalibrasi, atau tidak. Jawabannya: **tidak** —
/// yang diblokir cuma langkah kirimnya, dan "Simpan Draft" tetap jalan.
///
/// Yang menentukan itu definisi `wajib` di modelnya sendiri: *"bentuk payload
/// berubah dan versi lama diam-diam mengirim data yang salah."* Jadi yang
/// berbahaya bukan teknisi mengetik — yang berbahaya angka salah masuk jalur
/// approval lalu tercetak di sertifikat terakreditasi. Menahan pengetikannya
/// tidak menutup apa pun dan justru mengambil satu-satunya cara teknisi
/// menyelamatkan pekerjaannya.
///
/// Draft memang lahir dari versi yang sama dan bisa ikut cacat. Bedanya:
/// **draft itu ruang tunggu, bukan dokumen.** Dia bisa dibuka, diperiksa dan
/// dikirim ulang dari versi yang sudah benar. Sesi yang terlanjur masuk
/// approval bisa jadi sertifikat. Yang ditahan langkah yang tidak bisa ditarik
/// balik, bukan pekerjaannya — pola yang sama dengan penjagaan lain di repo
/// ini.
///
/// Yang TETAP tidak dilakukan, dan alasannya tidak berubah sejak
/// `banner_update.dart` menuliskannya: mengunci aplikasi. Teknisi di lokasi
/// pelanggan tanpa sinyal cukup untuk 68 MB harus tetap bisa mencatat.
///
/// **Dibaca dari `.value`, jadi "belum tahu" = tidak menahan.** Itu disengaja.
/// Pemeriksaan versi gagal diam-diam waktu tidak ada sinyal, dan menahan
/// pengiriman karena TIDAK TAHU akan menghukum justru teknisi yang paling tidak
/// bisa memperbaiki keadaannya.
final kirimTertahanRilisWajibProvider = Provider<bool>((ref) {
  return ref.watch(updateTersediaProvider).value?.wajib ?? false;
});
