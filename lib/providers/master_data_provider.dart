import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/organization.dart';
import '../services/customer_service.dart';
import '../services/organization_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// Live sejak 14 Jul (`docs/kontrak-api.md` §8) — admin doang.
final organizationServiceProvider = Provider<OrganizationService>(
  (ref) => ApiOrganizationService(ref.watch(apiClientProvider)),
);

final customerServiceProvider = Provider<CustomerService>(
  (ref) => ApiCustomerService(ref.watch(apiClientProvider)),
);

final organizationProvider =
    AsyncNotifierProvider<OrganizationController, Organization>(
      OrganizationController.new,
      retry: (retryCount, error) => null,
    );

class OrganizationController extends AsyncNotifier<Organization> {
  @override
  Future<Organization> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(organizationServiceProvider).ambil(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> simpan(Organization data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final hasil = await ref.read(organizationServiceProvider).simpan(token, data);
    state = AsyncValue.data(hasil);
  }
}

/// Bukan `AsyncNotifierProvider` biasa: layar Customers butuh pencarian
/// (`search`), jadi kueri terakhir disimpen di sini dan `muatUlang()`
/// makainya ulang.
final customerProvider =
    AsyncNotifierProvider<CustomerController, List<Customer>>(
      CustomerController.new,
      retry: (retryCount, error) => null,
    );

class CustomerController extends AsyncNotifier<List<Customer>> {
  String _search = '';

  @override
  Future<List<Customer>> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(customerServiceProvider).daftar(token, search: _search);
  }

  Future<void> cari(String query) async {
    _search = query;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> tambah(Customer data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(customerServiceProvider).simpan(token, data);
    await muatUlang();
  }

  Future<void> ubah(Customer data) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(customerServiceProvider).ubah(token, data);
    await muatUlang();
  }

  /// Ngelempar `AuthException` apa adanya kalau pelanggan masih punya alat
  /// (`422`) — layar yang nampilin pesannya, provider nggak nerjemahin.
  Future<void> hapus(int id) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(customerServiceProvider).hapus(token, id);
    await muatUlang();
  }
}
