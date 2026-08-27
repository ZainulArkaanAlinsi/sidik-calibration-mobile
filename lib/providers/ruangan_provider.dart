import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/ruangan.dart';
import '../services/ruangan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final ruanganServiceProvider = Provider<RuanganService>((ref) {
  if (AppConfig.useMock) return MockRuanganService();
  return ApiRuanganService(ref.watch(apiClientProvider));
});

final daftarRuanganProvider =
    AsyncNotifierProvider<RuanganController, List<Ruangan>>(
      RuanganController.new,
    );

class RuanganController extends AsyncNotifier<List<Ruangan>> {
  @override
  Future<List<Ruangan>> build() async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(ruanganServiceProvider).daftarRuangan(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Error DILEMPAR, bukan ditelan jadi state error: pesan penolakan backend
  /// ("kode ruangan udah dipakai", "suhu_min > suhu_max") itu yang berguna, dan
  /// layarnya perlu nampilinnya di form yang lagi kebuka — bukan ngeganti
  /// seluruh daftar jadi layar error dan bikin isian admin ilang.
  Future<void> simpan(Ruangan data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final svc = ref.read(ruanganServiceProvider);
    data.id == 0
        ? await svc.simpanRuangan(token, data)
        : await svc.ubahRuangan(token, data);

    await muatUlang();
  }

  Future<void> hapus(int id) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    await ref.read(ruanganServiceProvider).hapusRuangan(token, id);
    await muatUlang();
  }
}

final daftarMetodeProvider =
    AsyncNotifierProvider<MetodeController, List<MetodeKalibrasi>>(
      MetodeController.new,
    );

class MetodeController extends AsyncNotifier<List<MetodeKalibrasi>> {
  @override
  Future<List<MetodeKalibrasi>> build() async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(ruanganServiceProvider).daftarMetode(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  Future<void> simpan(MetodeKalibrasi data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final svc = ref.read(ruanganServiceProvider);
    data.id == 0
        ? await svc.simpanMetode(token, data)
        : await svc.ubahMetode(token, data);

    await muatUlang();
  }

  Future<void> hapus(int id) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    await ref.read(ruanganServiceProvider).hapusMetode(token, id);
    await muatUlang();
  }
}
