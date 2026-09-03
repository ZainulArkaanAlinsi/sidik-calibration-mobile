import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/equipment.dart';
import '../services/equipment_service.dart';
import 'auth_provider.dart';
import 'penjaga_urutan_muat.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// Live sejak 14 Jul (`docs/kontrak-api.md` §3) — sama endpoint yang dipakai
/// [EquipmentLookupService], versi penuh buat layar CRUD Alat.
final equipmentServiceProvider = Provider<EquipmentService>((ref) {
  if (AppConfig.useMock) return MockEquipmentService();
  return ApiEquipmentService(ref.watch(apiClientProvider));
});

/// Beda sama [CustomerController]: daftar alat bisa panjang & dipaginasi
/// beneran di backend (bukan "kirim semua sekaligus" kayak customer/standar),
/// jadi state-nya nyimpen halaman terakhir + `bisaMuatLagi` buat tombol
/// "muat lebih banyak" di layar.
final equipmentProvider =
    AsyncNotifierProvider<EquipmentController, List<Equipment>>(
      EquipmentController.new,
      retry: (retryCount, error) => null,
    );

/// Fetch mandiri buat ringkasan di Dashboard (kartu "Total Alat" /
/// "Jatuh Tempo") — sengaja BUKAN [equipmentProvider]: itu state punya tab
/// "Alat" di bottom nav, kalau dipakai bareng, filter dari kartu Dashboard
/// bakal ikut ngubah apa yang keliatan di tab (bug halus yang sempet
/// kejadian). Family di-key sama `status` biar tiap filter independen.
final deviceOverviewProvider = FutureProvider.family<List<Equipment>, String?>(
  (ref, status) async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(equipmentServiceProvider)
        .daftar(token, status: status, page: 1);
    return hasil.items;
  },
);

class EquipmentController extends AsyncNotifier<List<Equipment>>
    with PenjagaUrutanMuat<List<Equipment>> {
  String _search = '';
  String? _kategori;
  String? _status;
  int _page = 1;
  int _lastPage = 1;

  bool get bisaMuatLagi => _page < _lastPage;

  @override
  Future<List<Equipment>> build() async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    _page = 1;
    final hasil = await ref
        .read(equipmentServiceProvider)
        .daftar(
          token,
          search: _search,
          kategori: _kategori,
          status: _status,
          page: 1,
        );
    _lastPage = hasil.lastPage;
    return hasil.items;
  }

  Future<void> cari(String query) async {
    _search = query;
    await muatDenganPenjaga(build);
  }

  Future<void> filter({String? kategori, String? status}) async {
    _kategori = kategori;
    _status = status;
    await muatDenganPenjaga(build);
  }

  Future<void> muatUlang() async {
    await muatDenganPenjaga(build);
  }

  /// Nambahin halaman berikutnya ke daftar yang udah ada — bukan
  /// `muatUlang()`, biar scroll position teknisi nggak keloncat ke atas.
  Future<void> muatLebihBanyak() async {
    final sebelum = state.value;
    if (sebelum == null || !bisaMuatLagi) return;

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final hasil = await ref
        .read(equipmentServiceProvider)
        .daftar(
          token,
          search: _search,
          kategori: _kategori,
          status: _status,
          page: _page + 1,
        );
    _page += 1;
    _lastPage = hasil.lastPage;
    state = AsyncValue.data([...sebelum, ...hasil.items]);
  }

  /// Balikin alat yang BARU TERSIMPAN, berikut `id` dari server.
  ///
  /// Dulu `void`, dan hasil `simpan()` dibuang — padahal layanan sudah lama
  /// memulangkannya. Yang membuka form alat DARI lembar kerja butuh alat itu
  /// langsung kepilih; tanpa nilai baliknya dia mesti mencarinya lagi di
  /// dropdown yang baru saja dia isi.
  ///
  /// Null cuma kalau tokennya nggak ada — dan di keadaan itu memang nggak ada
  /// yang tersimpan.
  Future<Equipment?> tambah(Equipment data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return null;

    final tersimpan = await ref.read(equipmentServiceProvider).simpan(token, data);
    await muatUlang();

    return tersimpan;
  }

  /// Sama seperti [tambah]: alat hasil simpanan dipulangkan, bukan dibuang.
  Future<Equipment?> ubah(Equipment data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return null;

    final tersimpan = await ref.read(equipmentServiceProvider).ubah(token, data);
    await muatUlang();

    return tersimpan;
  }

  /// Ngelempar `AuthException` apa adanya kalau backend nolak (mis. alat
  /// masih ada riwayat kalibrasi) — layar yang nampilin pesannya.
  Future<void> hapus(int id) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(equipmentServiceProvider).hapus(token, id);
    await muatUlang();
  }
}
