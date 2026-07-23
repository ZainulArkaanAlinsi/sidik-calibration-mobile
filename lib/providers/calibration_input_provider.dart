import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/calibration_draft.dart';
import '../models/category.dart';
import '../models/equipment_lookup.dart';
import '../models/standard.dart';
import '../services/calibration_service.dart';
import '../services/category_service.dart';
import '../services/equipment_lookup_service.dart';
import '../services/standard_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// Semua nembak API asli — live sejak 14 Jul (`docs/kontrak-api.md` §3/§4).
final categoryServiceProvider = Provider<CategoryService>((ref) {
  if (AppConfig.useMock) return MockCategoryService();
  return ApiCategoryService(ref.watch(apiClientProvider));
});

final standardServiceProvider = Provider<StandardService>((ref) {
  if (AppConfig.useMock) return MockStandardService();
  return ApiStandardService(ref.watch(apiClientProvider));
});

final equipmentLookupServiceProvider = Provider<EquipmentLookupService>((ref) {
  if (AppConfig.useMock) return MockEquipmentLookupService();
  return ApiEquipmentLookupService(ref.watch(apiClientProvider));
});

final calibrationServiceProvider = Provider<CalibrationService>((ref) {
  if (AppConfig.useMock) return MockCalibrationService();
  return ApiCalibrationService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

final categoryListProvider = FutureProvider<List<Category>>((ref) async {
  final token = await _token(ref);
  return ref.read(categoryServiceProvider).daftar(token);
}, retry: (retryCount, error) => null);

/// Family-nya keyed by kode kategori — dipakai buat dropdown "Jenis Alat
/// (Kemampuan Kalibrasi)" di form Alat, ganti kategori = kueri baru.
final categoryDetailProvider = FutureProvider.family<CategoryDetail, String>((
  ref,
  kode,
) async {
  final token = await _token(ref);
  return ref.read(categoryServiceProvider).detail(token, kode);
}, retry: (retryCount, error) => null);

final standardListProvider = FutureProvider<List<Standard>>((ref) async {
  final token = await _token(ref);
  return ref.read(standardServiceProvider).daftar(token);
}, retry: (retryCount, error) => null);

/// Beda sama [standardListProvider] (read-only, dipakai dropdown di layar
/// kalibrasi): ini yang dipakai layar kelola Standar Acuan (admin) —
/// `AsyncNotifier` biar bisa `tambah`/`ubah`/`hapus` terus refresh sendiri.
final standardCrudProvider =
    AsyncNotifierProvider<StandardCrudController, List<Standard>>(
      StandardCrudController.new,
      retry: (retryCount, error) => null,
    );

class StandardCrudController extends AsyncNotifier<List<Standard>> {
  @override
  Future<List<Standard>> build() async {
    final token = await _token(ref);
    return ref.read(standardServiceProvider).daftar(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> tambah(Standard data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(standardServiceProvider).simpan(token, data);
    await muatUlang();
  }

  Future<void> ubah(Standard data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(standardServiceProvider).ubah(token, data);
    await muatUlang();
  }

  Future<void> hapus(int id) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(standardServiceProvider).hapus(token, id);
    await muatUlang();
  }
}

/// Family-nya keyed by kategori (nullable) — ganti kategori = kueri equipment
/// baru, biar picker cuma nampilin alat yang relevan.
final equipmentLookupProvider =
    FutureProvider.family<List<EquipmentLookup>, String?>((
      ref,
      kategori,
    ) async {
      final token = await _token(ref);
      return ref
          .read(equipmentLookupServiceProvider)
          .cari(token, kategori: kategori);
    }, retry: (retryCount, error) => null);

/// Controller submit — nggak nyimpen state list, cuma nembak `POST` sekali
/// dan balikin id sesi (atau lempar error yang layar tampilin).
class CalibrationSubmitController extends Notifier<AsyncValue<int?>> {
  @override
  AsyncValue<int?> build() => const AsyncValue.data(null);

  Future<int?> submit(CalibrationDraft draft) async {
    state = const AsyncValue.loading();
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      state = AsyncValue.error(const TokenHilangException(), StackTrace.current);
      return null;
    }

    try {
      final id = await ref.read(calibrationServiceProvider).buatSesi(token, draft);
      state = AsyncValue.data(id);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final calibrationSubmitProvider =
    NotifierProvider<CalibrationSubmitController, AsyncValue<int?>>(
      CalibrationSubmitController.new,
    );
