import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/customer.dart';
import '../models/customer_lookup.dart';
import '../models/order.dart';
import '../models/organization.dart';
import '../models/user.dart';
import '../services/customer_lookup_service.dart';
import '../services/customer_service.dart';
import '../services/order_service.dart';
import '../services/organization_service.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'simpanan_pelanggan_provider.dart';

/// Live sejak 14 Jul (`docs/kontrak-api.md` §8) — admin doang.
final organizationServiceProvider = Provider<OrganizationService>((ref) {
  if (AppConfig.useMock) return MockOrganizationService();
  return ApiOrganizationService(ref.watch(apiClientProvider));
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  if (AppConfig.useMock) return MockCustomerService();
  return ApiCustomerService(ref.watch(apiClientProvider));
});

final customerLookupServiceProvider = Provider<CustomerLookupService>((ref) {
  if (AppConfig.useMock) return MockCustomerLookupService();
  return ApiCustomerLookupService(ref.watch(apiClientProvider));
});

/// Hasil pencarian pelanggan, berikut dari mana dia datang.
///
/// [dariSimpanan] ikut karena teknisi berhak tahu daftar yang dia lihat
/// mungkin ketinggalan — pelanggan yang baru didaftarkan admin sejam lalu
/// belum ada di situ. Tanpa penanda ini, "nggak ketemu" waktu offline kebaca
/// sama persis dengan "beneran nggak ada", dan dia mendaftarkan ulang
/// perusahaan yang sebenarnya sudah terdaftar.
typedef HasilPelanggan = ({
  List<CustomerLookup> daftar,
  bool dariSimpanan,
  DateTime? diambil,
});

/// Isi picker pelanggan di form Alat. **Jangan diganti [customerProvider]**
/// walaupun isinya mirip: yang itu narik `GET /customers` yang admin-only,
/// jadi daftarnya bakal kosong di akun teknisi — padahal teknisi boleh nambah
/// alat, dan `pelanggan_id` wajib diisi. Lihat [ApiCustomerLookupService].
///
/// Di-key sama kata kunci pencarian, bukan sekali ambil semua: daftarnya
/// dipaginasi 15/halaman di backend, jadi lab yang pelanggannya lebih dari itu
/// nggak bakal nemu sebagian pelanggannya kalau nyarinya cuma di sisi mobile.
/// Pencariannya dikerjain server lewat `?search=`.
final customerLookupProvider = FutureProvider.family<HasilPelanggan, String>(
  (ref, search) async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    final akun = ref.watch(authProvider).value;

    final simpanan = ref.read(simpananPelangganProvider);
    final token = await ref.read(tokenStorageProvider).read();

    if (token == null) throw const TokenHilangException();

    try {
      final daftar = await ref
          .read(customerLookupServiceProvider)
          .cari(token, search: search);

      // Cuma daftar UTUH yang disimpan, bukan hasil pencarian.
      //
      // Menyimpan hasil `?search=` bikin isi simpanan bergantung pada apa
      // yang kebetulan terakhir dicari — dan waktu offline, teknisi cuma
      // menemukan pelanggan yang pernah dia ketik namanya. Daftar utuh
      // memang lebih besar, tapi itulah yang bikin jalur offline berguna.
      if (search.trim().isEmpty) {
        await simpanan.simpan(akun?.organizationId, daftar);
      }

      return (daftar: daftar, dariSimpanan: false, diambil: null);
    } catch (_) {
      // Server nggak bisa dihubungi → pakai salinan di HP.
      //
      // Teknisi berdiri di dalam pabrik: beton, mesin, dan sering nol
      // sinyal. Kalau pemilih pelanggan cuma jalan waktu server bisa
      // dihubungi, dia mentok persis di tempat yang paling sering dia
      // datangi.
      final isi = await simpanan.baca(akun?.organizationId);

      // Nggak ada salinan sama sekali → biarkan gagalnya naik apa adanya.
      // Memulangkan daftar kosong di sini bikin layarnya bilang "pelanggan
      // nggak ketemu" padahal yang terjadi servernya mati — dan teknisi
      // yang percaya itu mendaftarkan ulang pelanggan yang sudah ada.
      if (isi == null) rethrow;

      return (
        daftar: simpanan.saring(isi.daftar, search),
        dariSimpanan: true,
        diambil: isi.diambil,
      );
    }
  },
  // `retry: null` = **matiin retry otomatis bawaan Riverpod 3**, sama
  // kayak provider tetangganya di berkas ini.
  //
  // Ini yang KETINGGALAN dari awal, dan akibatnya justru paling parah di
  // layar ini. Providernya gagal cuma waktu server nggak kejangkau DAN
  // nggak ada salinan di HP — yaitu teknisi yang lagi di dalam pabrik,
  // baterainya dipakai seharian, sinyalnya nol. Dengan retry bawaan,
  // keadaan gagal nggak pernah sampai ke layar sama sekali: state-nya
  // nyangkut di `AsyncLoading(retrying)`, jadi yang dia lihat pemuat yang
  // muter terus — sementara HP-nya nembak server mati berulang-ulang
  // dengan jeda yang makin lebar, dan nggak ada satu pun jalan buat
  // ngetik nama PT-nya manual.
  //
  // Lebih jujur: tampilin gagalnya, dan biarkan dia lanjut jalan.
  retry: (retryCount, error) => null,
);

final organizationProvider =
    AsyncNotifierProvider<OrganizationController, Organization>(
      OrganizationController.new,
      retry: (retryCount, error) => null,
    );

class OrganizationController extends AsyncNotifier<Organization> {
  @override
  Future<Organization> build() async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

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

    final hasil = await ref
        .read(organizationServiceProvider)
        .simpan(token, data);
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
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

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

final userServiceProvider = Provider<UserService>((ref) {
  if (AppConfig.useMock) return MockUserService();
  return ApiUserService(ref.watch(apiClientProvider));
});

final orderServiceProvider = Provider<OrderService>(
  (ref) => ApiOrderService(ref.watch(apiClientProvider)),
);

/// Antrean order. `teknisiId: 'saya'` dipakai layar Tugas Saya; null buat
/// daftar penuh (admin).
final orderListProvider =
    AsyncNotifierProvider<OrderListController, List<OrderKalibrasi>>(
      OrderListController.new,
      retry: (retryCount, error) => null,
    );

class OrderListController extends AsyncNotifier<List<OrderKalibrasi>> {
  String? _teknisiId;
  String _search = '';

  String? get filterTeknisi => _teknisiId;

  @override
  Future<List<OrderKalibrasi>> build() async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref
        .read(orderServiceProvider)
        .daftar(token, teknisiId: _teknisiId, search: _search);
  }

  Future<void> saring({String? teknisiId}) async {
    _teknisiId = teknisiId;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
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
}

/// Daftar akun buat layar Data Teknisi. Filter status disimpen di sini biar
/// `muatUlang()` sesudah setujui/tolak balik ke filter yang lagi dipakai —
/// kalau nggak, admin yang lagi lihat tab "Pending" bakal kelempar ke "Semua"
/// tiap habis nyetujui satu akun.
final userListProvider = AsyncNotifierProvider<UserListController, List<User>>(
  UserListController.new,
  retry: (retryCount, error) => null,
);

class UserListController extends AsyncNotifier<List<User>> {
  String? _status;

  String? get statusAktif => _status;

  @override
  Future<List<User>> build() async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(userServiceProvider).daftar(token, status: _status);
  }

  Future<void> saring(String? status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> setujui(int id, UserRole role) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(userServiceProvider).setujui(token, id, role);
    await muatUlang();
  }

  Future<void> tolak(int id) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(userServiceProvider).tolak(token, id);
    await muatUlang();
  }

  /// Sengaja nggak `muatUlang()` — reset password nggak ngubah isi daftar,
  /// jadi nggak perlu bikin layar kedip-kedip.
  Future<void> resetPassword(int id, String passwordBaru) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref.read(userServiceProvider).resetPassword(token, id, passwordBaru);
  }

  /// Betulin data akun. Beda dari [resetPassword], ini **memang** perlu
  /// `muatUlang()` — nama/email/role yang berubah harus langsung kelihatan di
  /// kartunya, bukan baru muncul sesudah admin nutup-buka layar.
  Future<void> ubah(
    int id, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
  }) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref
        .read(userServiceProvider)
        .ubah(
          token,
          id,
          nama: nama,
          email: email,
          employeeId: employeeId,
          department: department,
          role: role,
        );
    await muatUlang();
  }
}
