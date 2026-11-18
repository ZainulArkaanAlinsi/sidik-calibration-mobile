import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/anggota_pelanggan.dart';
import '../models/customer.dart';
import '../models/user.dart';
import '../services/anggota_pelanggan_service.dart';
import '../services/pengguna_sa_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';

/// Provider layar pengelolaan Super Admin (Pengguna, Pelanggan & anggota).
///
/// Semua yang menyajikan data satu lab/akun `ref.watch(authProvider)` (lihat
/// skill scope-akun): ganti akun di HP yang sama tidak boleh meninggalkan
/// daftar pengguna lab sebelumnya.
final penggunaSaServiceProvider = Provider<PenggunaSaService>((ref) {
  if (AppConfig.useMock) return MockPenggunaSaService();
  return ApiPenggunaSaService(ref.watch(apiClientProvider));
});

final anggotaPelangganServiceProvider = Provider<AnggotaPelangganService>((
  ref,
) {
  if (AppConfig.useMock) return MockAnggotaPelangganService();
  return ApiAnggotaPelangganService(ref.watch(apiClientProvider));
});

/// Daftar berpaginasi + keadaan halamannya, satu nilai (`state`) supaya tidak
/// ada frame yang menampilkan daftar baru dengan nomor halaman lama.
class DaftarBerhalaman<T> {
  const DaftarBerhalaman({
    required this.items,
    this.halaman = 1,
    this.halamanTerakhir = 1,
  });

  final List<T> items;
  final int halaman;
  final int halamanTerakhir;

  bool get adaLagi => halaman < halamanTerakhir;
}

/// Filter daftar pengguna. Nilai `null` = tidak disaring.
class FilterPengguna {
  const FilterPengguna({this.peran, this.status, this.cari = ''});

  final String? peran;
  final String? status;
  final String cari;

  FilterPengguna salin({
    Object? peran = _tetap,
    Object? status = _tetap,
    String? cari,
  }) => FilterPengguna(
    peran: identical(peran, _tetap) ? this.peran : peran as String?,
    status: identical(status, _tetap) ? this.status : status as String?,
    cari: cari ?? this.cari,
  );

  static const _tetap = Object();
}

final penggunaSaProvider =
    AsyncNotifierProvider<PenggunaSaController, DaftarBerhalaman<User>>(
      PenggunaSaController.new,
      retry: (retryCount, error) => null,
    );

class PenggunaSaController extends AsyncNotifier<DaftarBerhalaman<User>>
    with PenjagaUrutanMuat<DaftarBerhalaman<User>> {
  FilterPengguna _filter = const FilterPengguna();

  FilterPengguna get filter => _filter;

  @override
  Future<DaftarBerhalaman<User>> build() async {
    ref.watch(authProvider);
    return _muat(1);
  }

  Future<DaftarBerhalaman<User>> _muat(int halaman) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(penggunaSaServiceProvider)
        .daftar(
          token,
          peran: _filter.peran,
          status: _filter.status,
          cari: _filter.cari,
          halaman: halaman,
        );
    return DaftarBerhalaman(
      items: hasil.items,
      halaman: hasil.halaman,
      halamanTerakhir: hasil.halamanTerakhir,
    );
  }

  Future<void> saring(FilterPengguna baru) async {
    _filter = baru;
    await muatDenganPenjaga(() => _muat(1));
  }

  /// Dipanggil sesudah SETIAP aksi sukses: daftar diambil ulang dari server,
  /// bukan ditambal di state lokal.
  Future<void> muatUlang() => muatDenganPenjaga(() => _muat(1));

  /// Tambahkan halaman berikutnya TANPA mengosongkan daftar yang sudah
  /// tampak (posisi gulir tidak loncat).
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

/// Daftar pelanggan buat layar "Pelanggan & anggota" (cari + paginasi).
final pelangganSaProvider =
    AsyncNotifierProvider<PelangganSaController, DaftarBerhalaman<Customer>>(
      PelangganSaController.new,
      retry: (retryCount, error) => null,
    );

class PelangganSaController extends AsyncNotifier<DaftarBerhalaman<Customer>>
    with PenjagaUrutanMuat<DaftarBerhalaman<Customer>> {
  String _cari = '';

  @override
  Future<DaftarBerhalaman<Customer>> build() async {
    ref.watch(authProvider);
    return _muat(1);
  }

  Future<DaftarBerhalaman<Customer>> _muat(int halaman) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(anggotaPelangganServiceProvider)
        .daftarPelanggan(token, cari: _cari, halaman: halaman);
    return DaftarBerhalaman(
      items: hasil.items,
      halaman: hasil.halaman,
      halamanTerakhir: hasil.halamanTerakhir,
    );
  }

  Future<void> cari(String kata) async {
    _cari = kata;
    await muatDenganPenjaga(() => _muat(1));
  }

  Future<void> muatUlang() => muatDenganPenjaga(() => _muat(1));

  Future<void> muatLebihBanyak() async {
    final sekarang = state.value;
    if (sekarang == null || !sekarang.adaLagi) return;

    final nomor = mulaiPermintaan();
    final hasil = await AsyncValue.guard(() => _muat(sekarang.halaman + 1));
    if (!masihTerbaru(nomor)) return;

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

/// Satu pelanggan LENGKAP (hitungan & penanda server, kontrak §3.6) buat
/// ringkasan di detail; diambil ulang sesudah undang / pindah alat.
final pelangganDetailSaProvider = FutureProvider.family<Customer, int>((
  ref,
  customerId,
) async {
  ref.watch(authProvider);
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  return ref
      .read(anggotaPelangganServiceProvider)
      .detailPelanggan(token, customerId);
});

/// Anggota + undangan menunggu + PIC admin satu pelanggan. Diambil ulang
/// (`ref.invalidate`) sesudah setiap aksi sukses.
final anggotaPelangganProvider =
    FutureProvider.family<DataAnggotaPelanggan, int>((ref, customerId) async {
      ref.watch(authProvider);
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref.read(anggotaPelangganServiceProvider).ambil(token, customerId);
    });
