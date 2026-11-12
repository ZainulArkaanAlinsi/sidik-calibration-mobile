import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/logo_organisasi.dart';
import '../services/logo_organisasi_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final logoOrganisasiServiceProvider = Provider<LogoOrganisasiService>((ref) {
  if (AppConfig.useMock) return MockLogoOrganisasiService();
  return ApiLogoOrganisasiService(ref.watch(apiClientProvider));
});

final logoOrganisasiProvider =
    AsyncNotifierProvider<LogoOrganisasiController, LogoOrganisasi>(
      LogoOrganisasiController.new,
      retry: (retryCount, error) => null,
    );

class LogoOrganisasiController extends AsyncNotifier<LogoOrganisasi> {
  @override
  Future<LogoOrganisasi> build() async {
    // Ikut akun yang login: ganti akun → logo lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(logoOrganisasiServiceProvider).ambil(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Lempar ulang galatnya, **tidak ditelan jadi state error**: layar perlu
  /// menampilkan pesan `422` server apa adanya (format/ukuran ditolak).
  Future<void> unggah(String filePath) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final baru = await ref
        .read(logoOrganisasiServiceProvider)
        .unggah(token, filePath);
    state = AsyncValue.data(baru);
  }

  Future<void> hapus() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    await ref.read(logoOrganisasiServiceProvider).hapus(token);
    state = const AsyncValue.data(LogoOrganisasi());
  }
}
