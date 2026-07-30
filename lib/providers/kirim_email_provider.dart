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
Future<void> kirimSertifikatLewatEmail(
  WidgetRef ref, {
  required int certificateId,
  required KirimEmailPermintaan isi,
}) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  try {
    await ref.read(kirimEmailServiceProvider).kirim(token, certificateId, isi);
  } finally {
    ref.invalidate(riwayatEmailProvider(certificateId));
  }
}
