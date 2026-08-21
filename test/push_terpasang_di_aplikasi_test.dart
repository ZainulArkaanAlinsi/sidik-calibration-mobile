import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pendaftaran_push.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Pendaftaran push BENERAN kepasang di aplikasi, bukan cuma ada kodenya.
///
/// **Kenapa test ini ada, dan kenapa bentuknya begini.**
///
/// `test/pendaftaran_push_test.dart` udah nguji isi `pendaftaranPushSyncProvider`
/// sampai detail — dan semuanya hijau selama berbulan-bulan. Tapi sampai
/// 21 Agt 2026 **nggak ada satu pun berkas di `lib/` yang menyentuh provider
/// itu**; yang manggil cuma berkas test tadi. Provider Riverpod nggak jalan
/// sampai ada yang baca, jadi di aplikasi asli seluruh isinya nggak pernah
/// dieksekusi: token perangkat nggak pernah didaftarkan, dan notifikasi push
/// nggak pernah bisa sampai ke HP siapa pun.
///
/// Nggak ada yang ngeluh karena nggak ada yang bisa ngeluh — test hijau (dia
/// manggil providernya langsung), server diam (nggak ada yang minta apa-apa),
/// dan `AuthController.logout` tetap rajin MENCABUT token yang nggak pernah
/// terdaftar.
///
/// Jadi test ini sengaja **nggak** manggil providernya. Yang dipasang
/// [SidikApp] — akar aplikasi yang sebenarnya — lalu dibuktikan tokennya
/// nyampe ke server. Satu-satunya cara itu bisa hijau adalah kalau kabelnya
/// beneran nyambung di kode aplikasi.
class _SumberTetap implements SumberTokenPush {
  const _SumberTetap(this._token);

  final String _token;

  @override
  Future<String?> token() async => _token;

  @override
  Stream<String> tokenBerubah() => const Stream.empty();
}

void main() {
  testWidgets('akar aplikasi mendaftarkan token perangkat sesudah login', (
    tester,
  ) async {
    final layanan = MockPendaftaranPush();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          sumberTokenPushProvider.overrideWithValue(
            const _SumberTetap('fcm-dari-akar'),
          ),
          pendaftaranPushServiceProvider.overrideWithValue(layanan),
        ],
        child: const SidikApp(),
      ),
    );

    // `MockAuthService.me()` jeda 600 ms, dan rantai pendaftarannya sendiri
    // beberapa putaran microtask sesudah itu. Nunggu KONDISI, bukan durasi —
    // jeda tetap itu taruhan sama beban mesin, dan taruhan yang kalahnya
    // kelihatan sebagai test yang kadang merah.
    final batas = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(batas) && layanan.didaftarkan.isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      layanan.didaftarkan,
      ['fcm-dari-akar'],
      reason:
          'Token perangkat nggak nyampe ke server. Kemungkinan besar '
          '`ref.watch(pendaftaranPushSyncProvider)` ilang dari lib/app.dart — '
          'tanpa itu providernya nggak pernah jalan dan push mati diam-diam.',
    );
  });
}
