import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/rumus.dart';
import '../services/rumus_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final rumusServiceProvider = Provider<RumusService>((ref) {
  if (AppConfig.useMock) return MockRumusService();
  return ApiRumusService(ref.watch(apiClientProvider));
});

/// Daftar rumus + versi yang lagi berlaku.
final daftarRumusProvider =
    AsyncNotifierProvider<RumusController, List<Rumus>>(RumusController.new);

class RumusController extends AsyncNotifier<List<Rumus>> {
  @override
  Future<List<Rumus>> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(rumusServiceProvider).daftar(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Terbitkan versi baru.
  ///
  /// Error-nya sengaja DILEMPAR, bukan ditelan jadi state error: pesan
  /// penolakan backend itu yang paling berguna di sini ("versi ini udah
  /// kepakai di hasil hitung", "rentangnya bentrok"), dan layarnya perlu
  /// nampilin apa adanya di dialog yang lagi kebuka — bukan ngeganti seluruh
  /// daftar jadi layar error dan bikin isian admin ilang.
  Future<VersiRumus> terbitkan(int formulaId, VersiRumusBaru isi) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(rumusServiceProvider)
        .terbitkanVersi(token, formulaId, isi);

    ref.invalidate(versiRumusProvider(formulaId));
    await muatUlang();

    return hasil;
  }

  Future<VersiRumus> ubahStatus(
    int formulaId,
    int versiId,
    StatusVersiRumus status,
  ) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(rumusServiceProvider)
        .ubahVersi(token, versiId, status: status);

    ref.invalidate(versiRumusProvider(formulaId));
    await muatUlang();

    return hasil;
  }
}

/// Riwayat versi satu rumus — terbaru dulu.
final versiRumusProvider =
    FutureProvider.family<List<VersiRumus>, int>((ref, formulaId) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  return ref.read(rumusServiceProvider).versi(token, formulaId);
});

/// "Aturan mana yang berlaku di tanggal X?"
///
/// Dipisah dari [versiRumusProvider] karena jawabannya beda: riwayat itu
/// daftar semua versi, ini SATU versi yang berlaku di satu tanggal. Yang
/// ditanya auditor yang kedua.
final versiPadaTanggalProvider = FutureProvider.family<
    VersiRumus?,
    ({int formulaId, DateTime tanggal})>((ref, arg) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  return ref
      .read(rumusServiceProvider)
      .versiPadaTanggal(token, arg.formulaId, arg.tanggal);
});
