import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/arsip_draf.dart';
import '../services/arsip_draf_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';
import 'super_admin_provider.dart' show DaftarBerhalaman;

/// Provider arsip draf lembar kerja. Disaring per akun
/// (`ref.watch(authProvider)`) seperti semua data lab (skill scope-akun).
final arsipDrafServiceProvider = Provider<ArsipDrafService>((ref) {
  if (AppConfig.useMock) return MockArsipDrafService();
  return ApiArsipDrafService(ref.watch(apiClientProvider));
});

/// Daftar draf yang diarsipkan (admin/super admin), dengan cari dan paginasi.
final arsipDrafProvider =
    AsyncNotifierProvider<ArsipDrafController, DaftarBerhalaman<DrafArsipan>>(
      ArsipDrafController.new,
      retry: (retryCount, error) => null,
    );

class ArsipDrafController extends AsyncNotifier<DaftarBerhalaman<DrafArsipan>>
    with PenjagaUrutanMuat<DaftarBerhalaman<DrafArsipan>> {
  String _cari = '';

  String get cari => _cari;

  @override
  Future<DaftarBerhalaman<DrafArsipan>> build() async {
    // Daftarkan build ini sebagai permintaan terbaru SEBELUM apa pun (lihat
    // `OrderKelolaController.build`).
    mulaiPermintaan();
    ref.watch(authProvider);
    _cari = '';
    return _muat(1);
  }

  Future<DaftarBerhalaman<DrafArsipan>> _muat(int halaman) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(arsipDrafServiceProvider)
        .daftar(token, cari: _cari, halaman: halaman);
    return DaftarBerhalaman(
      items: hasil.items,
      halaman: hasil.halaman,
      halamanTerakhir: hasil.halamanTerakhir,
    );
  }

  Future<void> cariKata(String kata) async {
    _cari = kata;
    await muatDenganPenjaga(() => _muat(1));
  }

  /// Dipanggil sesudah SETIAP aksi sukses: daftar diambil ulang dari server.
  Future<void> muatUlang() => muatDenganPenjaga(() => _muat(1));

  Future<void> muatLebihBanyak() async {
    final sekarang = state.value;
    if (sekarang == null || !sekarang.adaLagi) return;

    final nomor = mulaiPermintaan();
    final hasil = await AsyncValue.guard(() => _muat(sekarang.halaman + 1));
    if (!masihTerbaru(nomor)) return;

    // Galat "muat lebih banyak" tidak boleh menimpa daftar yang sudah ada.
    final tambahan = hasil.value;
    if (tambahan == null) return;
    state = AsyncData(
      DaftarBerhalaman(
        items: [...sekarang.items, ...tambahan.items],
        halaman: tambahan.halaman,
        halamanTerakhir: tambahan.halamanTerakhir,
      ),
    );
  }
}
