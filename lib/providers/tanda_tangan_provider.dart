import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/tanda_tangan.dart';
import '../services/tanda_tangan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final tandaTanganServiceProvider = Provider<TandaTanganService>((ref) {
  if (AppConfig.useMock) return MockTandaTanganService();
  return ApiTandaTanganService(ref.watch(apiClientProvider));
});

/// Keadaan tanda tangan + byte gambarnya, dibungkus jadi satu.
///
/// Digabung sengaja: layar pengaturannya selalu butuh dua-duanya barengan
/// (penanda "udah ada belum" buat nentuin tombol, gambarnya buat pratinjau),
/// dan kalau dipisah jadi dua provider, layar bisa nampilin keadaan setengah —
/// tombol "Hapus" muncul sementara pratinjaunya masih kosong.
class TandaTanganState {
  const TandaTanganState({required this.info, required this.gambar});

  final TandaTanganInfo info;

  /// `null` = belum ada yang diunggah.
  final Uint8List? gambar;

  bool get ada => info.punyaTandaTangan && gambar != null;
}

final tandaTanganProvider =
    AsyncNotifierProvider<TandaTanganController, TandaTanganState>(
      TandaTanganController.new,
      retry: (retryCount, error) => null,
    );

class TandaTanganController extends AsyncNotifier<TandaTanganState> {
  @override
  Future<TandaTanganState> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final service = ref.read(tandaTanganServiceProvider);
    final info = await service.info(token);

    // Gambarnya cuma ditarik kalau backend bilang emang ada — biar akun yang
    // belum pernah unggah nggak nembak endpoint gambar sia-sia tiap buka layar.
    final gambar = info.punyaTandaTangan ? await service.gambar(token) : null;

    return TandaTanganState(info: info, gambar: gambar);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Lempar ulang error-nya, **nggak ditelan jadi state error**: layar perlu
  /// nampilin pesan `422` dari backend apa adanya (mis. alasan JPG ditolak),
  /// dan itu paling gampang lewat `try/catch` di sisi pemanggil.
  Future<void> unggah(String filePath) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(tandaTanganServiceProvider).unggah(token, filePath);
    await muatUlang();
  }

  Future<void> hapus() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(tandaTanganServiceProvider).hapus(token);
    await muatUlang();
  }

  /// Cuma posisinya yang berubah — gambarnya nggak perlu ditarik ulang, jadi
  /// state-nya ditambal di tempat biar pratinjaunya nggak kedip tiap geser.
  Future<void> setPosisi(TandaTanganPosisi posisi) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final baru = await ref
        .read(tandaTanganServiceProvider)
        .setPosisi(token, posisi);

    final sekarang = state.value;
    if (sekarang == null) return;

    state = AsyncValue.data(
      TandaTanganState(info: baru, gambar: sekarang.gambar),
    );
  }
}
