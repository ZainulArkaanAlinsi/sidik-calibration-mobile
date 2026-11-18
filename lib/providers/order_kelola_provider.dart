import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_kelola_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';
import 'super_admin_provider.dart'
    show DaftarBerhalaman, penggunaSaServiceProvider;

/// Provider kelola Order. Semua yang menyajikan data satu lab/akun
/// `ref.watch(authProvider)` (skill scope-akun): ganti akun di HP yang sama
/// tidak boleh meninggalkan daftar order lab sebelumnya.
final orderKelolaServiceProvider = Provider<OrderKelolaService>((ref) {
  if (AppConfig.useMock) return MockOrderKelolaService();
  return ApiOrderKelolaService(ref.watch(apiClientProvider));
});

/// Saringan daftar order. `null` = tidak disaring.
class FilterOrder {
  const FilterOrder({this.status, this.cari = ''});

  final String? status;
  final String cari;

  FilterOrder salin({Object? status = _tetap, String? cari}) => FilterOrder(
    status: identical(status, _tetap) ? this.status : status as String?,
    cari: cari ?? this.cari,
  );

  static const _tetap = Object();
}

final orderKelolaProvider =
    AsyncNotifierProvider<OrderKelolaController, DaftarBerhalaman<OrderKalibrasi>>(
      OrderKelolaController.new,
      retry: (retryCount, error) => null,
    );

class OrderKelolaController
    extends AsyncNotifier<DaftarBerhalaman<OrderKalibrasi>>
    with PenjagaUrutanMuat<DaftarBerhalaman<OrderKalibrasi>> {
  FilterOrder _filter = const FilterOrder();

  FilterOrder get filter => _filter;

  @override
  Future<DaftarBerhalaman<OrderKalibrasi>> build() async {
    // Daftarkan build ini sebagai permintaan terbaru SEBELUM apa pun: tanpa
    // itu "muat lebih banyak" milik akun sebelumnya yang masih di jalan lolos
    // [masihTerbaru] dan halaman 2 lab lain menempel ke daftar akun baru
    // (HP lab dipakai gantian). Pola yang sama dengan `EquipmentController`.
    mulaiPermintaan();

    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut,
    // termasuk saringan/kata cari akun sebelumnya.
    // Hanya identitas akun yang memicu bangun ulang: emisi auth lain (mis.
    // sesudah pendaftaran push) tidak boleh membuang saringan yang sedang
    // dipakai. Ganti akun (id berubah, termasuk lewat logout) tetap bangun ulang.
    ref.watch(authProvider.select((a) => a.value?.id));
    _filter = const FilterOrder();

    return _muat(1);
  }

  Future<DaftarBerhalaman<OrderKalibrasi>> _muat(int halaman) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(orderKelolaServiceProvider)
        .daftar(
          token,
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

  Future<void> saring(FilterOrder baru) async {
    _filter = baru;
    await muatDenganPenjaga(() => _muat(1));
  }

  /// Dipanggil sesudah SETIAP aksi sukses: daftar diambil ulang dari server,
  /// bukan ditambal di state lokal (nomor & status milik server).
  Future<void> muatUlang() => muatDenganPenjaga(() => _muat(1));

  /// Tambahkan halaman berikutnya TANPA mengosongkan daftar yang sudah tampak.
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

/// Satu order lengkap (dengan `items`) buat layar detail dan form ubah.
final orderKelolaDetailProvider = FutureProvider.family<OrderKalibrasi, int>(
  (ref, id) async {
    ref.watch(authProvider);
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(orderKelolaServiceProvider).detail(token, id);
  },
  // Tanpa ini Riverpod 3 mengulang provider yang gagal berkali-kali dengan
  // jeda membesar, dan layar tetap "memuat" alih-alih menampilkan galat.
  retry: (retryCount, error) => null,
);

/// Teknisi AKTIF lab untuk pemilih teknisi di baris order/penugasan. Server
/// yang menolak teknisi nonaktif (`422`); daftar ini hanya menawarkan yang sah.
/// Semua halaman dibaca (maks 10 × 15) — jumlah teknisi satu lab kecil.
final teknisiAktifProvider = FutureProvider<List<User>>((ref) async {
  ref.watch(authProvider);
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  final layanan = ref.read(penggunaSaServiceProvider);
  final hasil = <User>[];
  for (var halaman = 1; halaman <= 10; halaman++) {
    final h = await layanan.daftar(
      token,
      peran: 'teknisi',
      status: 'aktif',
      halaman: halaman,
    );
    hasil.addAll(h.items);
    if (!h.adaLagi) break;
  }
  return hasil;
}, retry: (retryCount, error) => null);
