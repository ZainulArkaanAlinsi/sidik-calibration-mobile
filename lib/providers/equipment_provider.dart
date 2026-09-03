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

    _page = 1;
    final hasil = await _ambil(1);

    // `build()` yang dipanggil Riverpod sendiri selalu yang terbaru — nggak ada
    // permintaan lain yang bisa mendahuluinya, jadi metadatanya dipasang
    // langsung. Yang lewat penjaga cuma [_muatUlangTerjaga] di bawah.
    _lastPage = hasil.lastPage;

    return hasil.items;
  }

  /// Satu permintaan daftar — item DAN metadata halamannya, dibawa bersama.
  ///
  /// Dipisah dari `build()` supaya pemanggilnya bisa memilih KAPAN metadatanya
  /// dipasang. Waktu masih tertanam di dalam `build()`, `_lastPage` tertulis
  /// sebelum penjaga urutan sempat menolak hasilnya.
  Future<EquipmentPage> _ambil(int page) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref
        .read(equipmentServiceProvider)
        .daftar(
          token,
          search: _search,
          kategori: _kategori,
          status: _status,
          page: page,
        );
  }

  /// Muat ulang halaman pertama lewat penjaga urutan — daftar dan metadata
  /// halamannya dipasang sebagai satu kesatuan, atau dibuang dua-duanya.
  Future<void> _muatUlangTerjaga() async {
    // Lokal per panggilan, jadi dua pencarian yang tumpang tindih nggak saling
    // menimpa hasilnya sebelum penjaganya sempat memutuskan.
    EquipmentPage? hasil;

    await muatDenganPenjaga(
      () async {
        hasil = await _ambil(1);
        return hasil!.items;
      },
      saatTerbaru: () {
        _page = 1;
        _lastPage = hasil!.lastPage;
      },
    );
  }

  Future<void> cari(String query) async {
    _search = query;
    await _muatUlangTerjaga();
  }

  Future<void> filter({String? kategori, String? status}) async {
    _kategori = kategori;
    _status = status;
    await _muatUlangTerjaga();
  }

  Future<void> muatUlang() async {
    await _muatUlangTerjaga();
  }

  /// Nambahin halaman berikutnya ke daftar yang udah ada — bukan
  /// `muatUlang()`, biar scroll position teknisi nggak keloncat ke atas.
  ///
  /// Ikut penjaga urutan yang sama, tapi TANPA `loading`: mengosongkan daftar
  /// jadi spinner bikin scroll teknisi loncat ke atas, dan itu persis yang
  /// dihindari pintu ini. Yang dibeli penjaganya: pencarian baru yang berangkat
  /// selagi halaman ini di jalan bikin hasil halaman ini dibuang, bukan
  /// ditempel ke daftar kata kunci yang lain.
  Future<void> muatLebihBanyak() async {
    final sebelum = state.value;
    if (sebelum == null || !bisaMuatLagi) return;

    // Nomornya diambil SEBELUM `await` pertama. Kalau diambil sesudahnya,
    // pencarian yang berangkat di sela-sela justru dapat nomor yang lebih
    // kecil — dan halaman 2 milik kata kunci LAMA menang, lalu ditempel ke
    // daftar kata kunci yang baru.
    final nomor = mulaiPermintaan();
    final halaman = _page + 1;

    // Token dibaca di sini, bukan lewat `_ambil`, supaya perilakunya persis
    // seperti sebelumnya: token hilang di tengah scroll berhenti diam-diam,
    // bukan memerahkan daftar yang sudah kelihatan.
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final hasil = await ref
        .read(equipmentServiceProvider)
        .daftar(
          token,
          search: _search,
          kategori: _kategori,
          status: _status,
          page: halaman,
        );

    if (!masihTerbaru(nomor)) return;

    _page = halaman;
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
