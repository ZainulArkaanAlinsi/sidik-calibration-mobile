import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/category.dart';
import '../services/kategori_kelola_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';

/// Provider kelola Kategori alat. Disaring per akun (`ref.watch(authProvider)`)
/// seperti semua data lab (skill scope-akun).
final kategoriKelolaServiceProvider = Provider<KategoriKelolaService>((ref) {
  if (AppConfig.useMock) return MockKategoriKelolaService();
  return ApiKategoriKelolaService(ref.watch(apiClientProvider));
});

/// Semua kategori lab TERMASUK yang nonaktif (`?termasuk_nonaktif=1`, hanya
/// berlaku untuk admin & super admin di server), diurut nama. Daftarnya kecil
/// dan tidak dipaginasi server.
final kategoriKelolaProvider =
    AsyncNotifierProvider<KategoriKelolaController, List<Category>>(
      KategoriKelolaController.new,
      retry: (retryCount, error) => null,
    );

class KategoriKelolaController extends AsyncNotifier<List<Category>>
    with PenjagaUrutanMuat<List<Category>> {
  @override
  Future<List<Category>> build() async {
    mulaiPermintaan();
    ref.watch(authProvider);
    return _muat();
  }

  Future<List<Category>> _muat() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return ref.read(kategoriKelolaServiceProvider).daftar(token);
  }

  /// Dipanggil sesudah SETIAP aksi sukses: daftar diambil ulang dari server
  /// (hitungan pemakai, status, dan kode milik server), bukan ditambal lokal.
  Future<void> muatUlang() => muatDenganPenjaga(_muat);
}
