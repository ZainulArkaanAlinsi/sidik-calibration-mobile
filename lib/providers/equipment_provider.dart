import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/equipment.dart';
import '../services/equipment_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// Live sejak 14 Jul (`docs/kontrak-api.md` §3) — sama endpoint yang dipakai
/// [EquipmentLookupService], versi penuh buat layar CRUD Alat.
final equipmentServiceProvider = Provider<EquipmentService>(
  (ref) => ApiEquipmentService(ref.watch(apiClientProvider)),
);

/// Beda sama [CustomerController]: daftar alat bisa panjang & dipaginasi
/// beneran di backend (bukan "kirim semua sekaligus" kayak customer/standar),
/// jadi state-nya nyimpen halaman terakhir + `bisaMuatLagi` buat tombol
/// "muat lebih banyak" di layar.
final equipmentProvider =
    AsyncNotifierProvider<EquipmentController, List<Equipment>>(
      EquipmentController.new,
      retry: (retryCount, error) => null,
    );

class EquipmentController extends AsyncNotifier<List<Equipment>> {
  String _search = '';
  String? _kategori;
  String? _status;
  int _page = 1;
  int _lastPage = 1;

  bool get bisaMuatLagi => _page < _lastPage;

  @override
  Future<List<Equipment>> build() async {
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> filter({String? kategori, String? status}) async {
    _kategori = kategori;
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
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

  Future<void> tambah(Equipment data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(equipmentServiceProvider).simpan(token, data);
    await muatUlang();
  }

  Future<void> ubah(Equipment data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(equipmentServiceProvider).ubah(token, data);
    await muatUlang();
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
