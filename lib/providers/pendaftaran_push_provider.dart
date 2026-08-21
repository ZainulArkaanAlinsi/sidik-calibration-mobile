import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/fcm_sumber_token_push.dart';
import '../services/pendaftaran_push.dart';
import '../services/sumber_token_push.dart';
import 'auth_provider.dart';

/// Dari mana token push diambil.
///
/// `TanpaTokenPush` bukan penambal: panel admin desktop memang nggak pernah
/// punya token push, dan di mode mock kita nggak mau nyentuh layanan Google
/// sama sekali. Di situ kabarnya sudah lewat websocket Reverb.
final sumberTokenPushProvider = Provider<SumberTokenPush>((ref) {
  if (AppConfig.useMock || !FcmSumberTokenPush.didukung) {
    return const TanpaTokenPush();
  }

  return FcmSumberTokenPush();
});

final pendaftaranPushServiceProvider = Provider<PendaftaranPush>(
  (ref) => ApiPendaftaranPush(ref.watch(apiClientProvider)),
);

/// Ngiket pendaftaran push ke daur hidup login.
///
/// Login → daftarin token perangkat ini. Token dirotasi layanan push → daftar
/// ulang. Yang belum ada di sini: pencabutan waktu logout — itu dilakukan
/// `AuthController.logout` sendiri, karena dia yang masih pegang token akun
/// sebelum dibuang. Kalau ditaruh di sini, providernya sudah keburu dibuang
/// waktu logout selesai dan tokennya nggak pernah kecabut.
final pendaftaranPushSyncProvider = Provider<void>((ref) {
  // Yang diikuti ID-nya, BUKAN seluruh `AsyncValue`-nya.
  //
  // `ref.watch(authProvider)` kena tiap kali keadaan auth bergerak sama sekali
  // — loading → data, dan tiap penyegaran `me()` yang ngasih user yang sama
  // persis. Tiap gerakan itu ngebangun ulang provider ini, dan tiap
  // pembangunan ulang ngirim POST pendaftaran lagi buat token yang SUDAH
  // terdaftar. Ketahuan 21 Agt 2026 waktu test-nya akhirnya nahan provider ini
  // tetap hidup: `didaftarkan` keisi `['fcm-lama', 'fcm-lama', 'fcm-baru']`.
  //
  // Servernya nggak rusak kena ini (pendaftarannya idempoten), tapi ini
  // panggilan jaringan berulang yang nggak ada gunanya — di HP teknisi yang
  // sinyalnya tipis di lokasi pelanggan, itu bukan hal sepele.
  //
  // Dengan `select`, providernya cuma dibangun ulang waktu yang login
  // BERGANTI ORANG — yang emang saat satu-satunya token perlu didaftarkan
  // ulang atas nama akun lain.
  final idPengguna = ref.watch(authProvider.select((s) => s.value?.id));

  if (idPengguna == null) return;

  final sumber = ref.watch(sumberTokenPushProvider);
  final layanan = ref.watch(pendaftaranPushServiceProvider);

  Future<void> daftarkan(String tokenPerangkat) async {
    final tokenAkun = await ref.read(tokenStorageProvider).read();
    if (tokenAkun == null) return;
    await layanan.daftar(tokenAkun, tokenPerangkat);
  }

  // Sekali waktu login.
  unawaited(
    Future(() async {
      final tokenPerangkat = await sumber.token();
      // `null` itu keadaan yang sah, bukan kegagalan: pengguna boleh nolak
      // izin notifikasi, dan desktop nggak punya token push sama sekali.
      if (tokenPerangkat != null) await daftarkan(tokenPerangkat);
    }),
  );

  // Lalu tiap kali layanan push merotasinya.
  //
  // Ini gampang dilewat dan diamnya total: FCM ganti token tanpa diminta
  // (aplikasi dipasang ulang, data aplikasi dihapus), dan kalau yang baru
  // nggak didaftarkan, notifikasinya berhenti masuk tanpa satu error pun. Dari
  // sisi server, token lamanya masih kelihatan sah sampai ada yang mencoba
  // mengirim ke situ.
  final langganan = sumber.tokenBerubah().listen((baru) {
    unawaited(daftarkan(baru));
  });

  ref.onDispose(langganan.cancel);
});
