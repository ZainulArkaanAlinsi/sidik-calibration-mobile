import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/versi_aplikasi.dart';
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
