import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pendaftaran_push.dart';
import '../services/sumber_token_push.dart';
import 'auth_provider.dart';

/// Dari mana token push diambil.
///
/// Sekarang selalu kosong — Firebase belum dipasang, dan panel desktop memang
/// nggak pernah punya token push. Waktu `firebase_messaging` masuk, yang
/// ditukar cuma baris ini.
final sumberTokenPushProvider = Provider<SumberTokenPush>(
  (ref) => const TanpaTokenPush(),
);

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
  final user = ref.watch(authProvider).value;

  if (user == null) return;

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
