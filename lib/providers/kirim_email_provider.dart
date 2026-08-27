import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/kirim_email.dart';
import '../services/kirim_email_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final kirimEmailServiceProvider = Provider<KirimEmailService>((ref) {
  if (AppConfig.useMock) return MockKirimEmailService();
  return ApiKirimEmailService(ref.watch(apiClientProvider));
});

/// Riwayat percobaan kirim, di-key per sertifikat.
///
/// `FutureProvider.family` + [ref.invalidate], ngikutin pola yang udah dipakai
/// `folderListProvider` & `customerLookupProvider` — bukan notifier, karena
/// yang perlu disimpen cuma hasil ambilnya.
final riwayatEmailProvider =
    FutureProvider.family<List<PercobaanEmail>, int>((ref, certificateId) async {
      // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
      ref.watch(authProvider);

      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref.read(kirimEmailServiceProvider).riwayat(token, certificateId);
    });

/// Kirim sertifikat, lalu segarkan riwayatnya.
///
/// Riwayatnya di-invalidate **di `finally`**, jadi tetap jalan walaupun
/// kirimnya gagal. Itu bukan kelalaian: percobaan yang gagal TETAP tercatat
/// backend, dan kalau riwayatnya nggak disegarkan, admin lihat daftar lama
/// yang bikin dia ngira nggak terjadi apa-apa.
///
/// Errornya **dilempar ulang**, bukan ditelan — layar perlu nampilin pesan
/// server apa adanya (mis. `502` gagal kirim).
/// Baliknya `peringatan` server (`null` = beneran terkirim) — lihat
/// [KirimEmailService.kirim].
Future<String?> kirimSertifikatLewatEmail(
  WidgetRef ref, {
  required int certificateId,
  required KirimEmailPermintaan isi,
}) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  try {
    return await ref
        .read(kirimEmailServiceProvider)
        .kirim(token, certificateId, isi);
  } finally {
    ref.invalidate(riwayatEmailProvider(certificateId));
  }
}

/// Catat pengiriman lewat WhatsApp & ambil teks siap-tempelnya.
///
/// Riwayatnya di-invalidate sesudahnya, sama kayak jalur email — kiriman WA
/// muncul di daftar yang sama, jadi "sertifikat ini udah dikirim ke siapa aja"
/// bisa dijawab dari satu tempat.
Future<HasilCatatWhatsapp> catatKirimWhatsapp(
  WidgetRef ref, {
  required int certificateId,
  required List<String> ke,
  FormatKirim format = FormatKirim.tautan,
}) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  final hasil = await ref
      .read(kirimEmailServiceProvider)
      .catatWhatsapp(token, certificateId, ke: ke, format: format);

  ref.invalidate(riwayatEmailProvider(certificateId));

  return hasil;
}
