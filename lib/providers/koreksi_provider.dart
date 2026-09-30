import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/koreksi_pelanggan.dart';
import '../services/koreksi_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'pengendalian_provider.dart' show Saringan;
import 'penjaga_urutan_muat.dart';

/// Koreksi dari pelanggan, sisi lab (§42 backend).
///
/// Semua provider `ref.watch(authProvider)`: ganti akun → data lab sebelumnya
/// tidak ikut (aturan `sidik-fe-scope-akun`).

final koreksiServiceProvider = Provider<KoreksiService>((ref) {
  if (AppConfig.useMock) return MockKoreksiService();
  return ApiKoreksiService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Tab status antrean. `menunggu` dulu: itu pekerjaan yang ditunggu.
///
/// Di provider sendiri (bukan field controller) karena `realtimeSyncProvider`
/// meng-invalidate antreannya tiap ada sinyal — lihat [Saringan].
final statusKoreksiProvider = NotifierProvider<Saringan<String>, String>(
  () => Saringan(SaringanKoreksi.menunggu),
);

final antreanKoreksiProvider =
    AsyncNotifierProvider<AntreanKoreksiController, HalamanKoreksi>(
      AntreanKoreksiController.new,
      retry: (retryCount, error) => null,
    );

class AntreanKoreksiController extends AsyncNotifier<HalamanKoreksi>
    with PenjagaUrutanMuat<HalamanKoreksi> {
  @override
  Future<HalamanKoreksi> build() async {
    ref.watch(authProvider);
    final status = ref.read(statusKoreksiProvider);
    return ref
        .read(koreksiServiceProvider)
        .daftar(await _token(ref), status: status);
  }

  Future<void> saring(String status) async {
    ref.read(statusKoreksiProvider.notifier).setel(status);
    await muatDenganPenjaga(build);
  }

  Future<void> muatUlang() => muatDenganPenjaga(build);
}

/// Angka badge menu (`meta.jumlah.menunggu`) — terlepas dari tab yang sedang
/// terbuka. Gagal → 0 (tanpa badge): angka dekorasi tidak boleh menjatuhkan
/// menu yang menampungnya.
final jumlahKoreksiMenungguProvider = FutureProvider<int>((ref) async {
  ref.watch(authProvider);
  try {
    final h = await ref
        .read(koreksiServiceProvider)
        .daftar(await _token(ref), status: SaringanKoreksi.menunggu, perPage: 1);
    return h.jumlahMenunggu;
  } catch (_) {
    return 0;
  }
}, retry: (retryCount, error) => null);

/// Detail satu koreksi. `autoDispose`: dibuka sesekali.
final detailKoreksiProvider = FutureProvider.autoDispose.family<Koreksi, int>((
  ref,
  id,
) async {
  ref.watch(authProvider);
  return ref.read(koreksiServiceProvider).detail(await _token(ref), id);
}, retry: (retryCount, error) => null);

/// Byte foto pelat nama (`GET /foto-pelanggan/{id}`), ditarik dengan header
/// yang sama seperti panggilan API lain — `Image.network` tidak membawa token.
/// `null` = foto tidak ditemukan.
final fotoPelangganProvider = FutureProvider.autoDispose
    .family<Uint8List?, int>((ref, id) async {
      ref.watch(authProvider);
      return ref.read(koreksiServiceProvider).foto(await _token(ref), id);
    }, retry: (retryCount, error) => null);

/// Aksi tulis. Sesudah berhasil, antrean, badge, dan detail ditarik ulang —
/// dan untuk koreksi sertifikat yang diterima, sertifikat (revisi baru lahir)
/// ikut basi: ditangani pemanggil lewat `sertifikatAksiProvider`/realtime.
final koreksiAksiProvider = Provider<KoreksiAksi>(KoreksiAksi.new);

class KoreksiAksi {
  KoreksiAksi(this._ref);

  final Ref _ref;

  void _segarkan(int id) {
    _ref
      ..invalidate(antreanKoreksiProvider)
      ..invalidate(jumlahKoreksiMenungguProvider)
      ..invalidate(detailKoreksiProvider(id));
  }

  Future<Koreksi> terima(
    int id, {
    String? tanggapan,
    Map<String, String>? perubahan,
    String? alasan,
  }) async {
    final hasil = await _ref
        .read(koreksiServiceProvider)
        .terima(
          await _token(_ref),
          id,
          tanggapan: tanggapan,
          perubahan: perubahan,
          alasan: alasan,
        );
    _segarkan(id);
    return hasil;
  }

  Future<Koreksi> tolak(int id, String tanggapan) async {
    final hasil = await _ref
        .read(koreksiServiceProvider)
        .tolak(await _token(_ref), id, tanggapan);
    _segarkan(id);
    return hasil;
  }

  /// Dipakai pemanggil yang menangkap galat status ("sudah diputus admin
  /// lain"): tarik ulang supaya layar menunjukkan keadaan sebenarnya.
  void segarkan(int id) => _segarkan(id);
}
