import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/equipment.dart';
import '../services/category_service.dart';
import '../services/customer_service.dart';
import '../services/equipment_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final equipmentServiceProvider = Provider<EquipmentService>((ref) {
  if (AppConfig.useMock) return MockEquipmentService();
  return ApiEquipmentService(ref.watch(apiClientProvider));
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  if (AppConfig.useMock) return const MockCategoryService();
  return ApiCategoryService(ref.watch(apiClientProvider));
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  if (AppConfig.useMock) return const MockCustomerService();
  return ApiCustomerService(ref.watch(apiClientProvider));
});

/// Dropdown kategori — jarang berubah, cukup `FutureProvider` biasa (bukan
/// `AsyncNotifier`, nggak butuh `muatUlang`).
final categoriesProvider = FutureProvider<List<CalibrationCategory>>((
  ref,
) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) return const [];
  return ref.read(categoryServiceProvider).daftar(token);
});

/// Daftar pelanggan buat dropdown di form Alat — **admin-only** (kontrak API
/// §8), jadi cuma dipanggil dari layar form waktu user-nya admin. Nggak pakai
/// search-as-you-type di v1 ini, ambil semua sekaligus.
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) return const [];
  return ref.read(customerServiceProvider).cari(token);
});

/// Daftar Alat + filter yang lagi aktif, dibundel jadi satu biar UI (search
/// bar, chip kategori/status) bisa nampilin state-nya sendiri tanpa provider
/// terpisah.
class EquipmentListState {
  const EquipmentListState({
    required this.items,
    this.search = '',
    this.kategori,
    this.status,
  });

  final List<Equipment> items;
  final String search;
  final String? kategori;
  final String? status;

  /// Belum ada alat sama sekali (bukan sekadar "nggak ketemu" gara-gara
  /// filter) — mutusin layar nampilin state `empty` (ajakan mulai) atau
  /// `tidakAdaHasil` (saran ganti kata kunci/filter).
  bool get kosong =>
      items.isEmpty && search.isEmpty && kategori == null && status == null;

  bool get tidakAdaHasil => items.isEmpty && !kosong;
}

final equipmentListProvider =
    AsyncNotifierProvider<EquipmentListController, EquipmentListState>(
      EquipmentListController.new,
      retry: (retryCount, error) => null,
    );

class EquipmentListController extends AsyncNotifier<EquipmentListState> {
  @override
  Future<EquipmentListState> build() async {
    // Nempel ke user yang login: ganti user, daftar alat ikut ke-refresh.
    ref.watch(authProvider);
    return _muat(search: '', kategori: null, status: null);
  }

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  Future<EquipmentListState> _muat({
    required String search,
    required String? kategori,
    required String? status,
  }) async {
    final token = await _token();
    final halaman = await ref
        .read(equipmentServiceProvider)
        .daftar(token, search: search, kategori: kategori, status: status);

    return EquipmentListState(
      items: halaman.items,
      search: search,
      kategori: kategori,
      status: status,
    );
  }

  /// Dipanggil dari tombol "Coba lagi" dan tarik-buat-refresh — filter yang
  /// lagi aktif dipertahankan.
  Future<void> muatUlang() async {
    final filter = state.value;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _muat(
        search: filter?.search ?? '',
        kategori: filter?.kategori,
        status: filter?.status,
      ),
    );
  }

  Future<void> ubahPencarian(String search) async {
    state = await AsyncValue.guard(
      () => _muat(
        search: search,
        kategori: state.value?.kategori,
        status: state.value?.status,
      ),
    );
  }

  Future<void> ubahFilter({String? kategori, String? status}) async {
    state = await AsyncValue.guard(
      () => _muat(
        search: state.value?.search ?? '',
        kategori: kategori,
        status: status,
      ),
    );
  }

  /// Mutasi (tambah/ubah/hapus) sengaja **nggak** nyentuh `state` waktu
  /// gagal — biar error-nya kelempar ke layar form yang nanganin sendiri
  /// (pola yang sama kayak `AuthController.register`), bukan bikin seluruh
  /// daftar Alat ikut nampilin state error gara-gara satu submit gagal.
  Future<void> tambah(Equipment equipment, {int? pelangganId}) async {
    final token = await _token();
    await ref
        .read(equipmentServiceProvider)
        .tambah(token, equipment, pelangganId: pelangganId);
    await muatUlang();
  }

  Future<void> ubah(int id, Equipment equipment, {int? pelangganId}) async {
    final token = await _token();
    await ref
        .read(equipmentServiceProvider)
        .ubah(token, id, equipment, pelangganId: pelangganId);
    await muatUlang();
  }

  Future<void> hapus(int id) async {
    final token = await _token();
    await ref.read(equipmentServiceProvider).hapus(token, id);
    await muatUlang();
  }
}
