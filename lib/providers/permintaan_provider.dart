import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/permintaan_pelanggan.dart';
import '../services/permintaan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'pengendalian_provider.dart' show Saringan, daftarPaketProvider;
import 'penjaga_urutan_muat.dart';

/// Permintaan kalibrasi pelanggan, sisi lab (keputusan 30 Sep 2026, §41).
///
/// Semua provider `ref.watch(authProvider)`: ganti akun → data lab sebelumnya
/// tidak ikut (aturan `sidik-fe-scope-akun`).

final permintaanServiceProvider = Provider<PermintaanService>((ref) {
  if (AppConfig.useMock) return MockPermintaanService();
  return ApiPermintaanService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Tab status antrean. `baru` dulu: itu pekerjaan yang ditunggu; yang lain
/// riwayat. Kosong = semua status.
///
/// Di provider sendiri (bukan field controller) karena `realtimeSyncProvider`
/// meng-invalidate antreannya tiap ada sinyal — lihat [Saringan].
final statusPermintaanProvider = NotifierProvider<Saringan<String>, String>(
  () => Saringan('baru'),
);

final cariPermintaanProvider = NotifierProvider<Saringan<String>, String>(
  () => Saringan(''),
);

final antreanPermintaanProvider =
    AsyncNotifierProvider<AntreanPermintaanController, HalamanPermintaan>(
      AntreanPermintaanController.new,
      retry: (retryCount, error) => null,
    );

class AntreanPermintaanController extends AsyncNotifier<HalamanPermintaan>
    with PenjagaUrutanMuat<HalamanPermintaan> {
  @override
  Future<HalamanPermintaan> build() async {
    ref.watch(authProvider);
    final status = ref.read(statusPermintaanProvider);
    return ref
        .read(permintaanServiceProvider)
        .daftar(
          await _token(ref),
          status: status.isEmpty ? null : status,
          cari: ref.read(cariPermintaanProvider),
        );
  }

  Future<void> saring(String status) async {
    ref.read(statusPermintaanProvider.notifier).setel(status);
    await muatDenganPenjaga(build);
  }

  Future<void> cari(String q) async {
    ref.read(cariPermintaanProvider.notifier).setel(q);
    await muatDenganPenjaga(build);
  }

  Future<void> muatUlang() => muatDenganPenjaga(build);
}

/// Angka badge menu (`meta.jumlah_baru`) — terlepas dari tab & kata cari yang
/// sedang terbuka, jadi provider sendiri, bukan turunan antrean.
///
/// Gagal → 0 (tanpa badge): angka dekorasi tidak boleh menjatuhkan menu yang
/// menampungnya.
final jumlahPermintaanBaruProvider = FutureProvider<int>((ref) async {
  ref.watch(authProvider);
  try {
    final h = await ref
        .read(permintaanServiceProvider)
        .daftar(await _token(ref), status: 'baru', perPage: 1);
    return h.jumlahBaru;
  } catch (_) {
    return 0;
  }
}, retry: (retryCount, error) => null);

/// Detail satu permintaan. `autoDispose`: dibuka sesekali.
final detailPermintaanProvider = FutureProvider.autoDispose
    .family<PermintaanPelanggan, int>((ref, id) async {
      ref.watch(authProvider);
      return ref.read(permintaanServiceProvider).detail(await _token(ref), id);
    }, retry: (retryCount, error) => null);

/// Utas pesan satu permintaan (terlama di atas).
final pesanPermintaanProvider = FutureProvider.autoDispose
    .family<UtasPermintaan, int>((ref, id) async {
      ref.watch(authProvider);
      return ref.read(permintaanServiceProvider).pesan(await _token(ref), id);
    }, retry: (retryCount, error) => null);

/// Aksi tulis. Sesudah berhasil, semua yang menampilkan permintaan itu ditarik
/// ulang sekaligus — antrean, badge, detail, dan utas — supaya tab "Baru" tidak
/// masih memuat permintaan yang barusan diterima.
final permintaanAksiProvider = Provider<PermintaanAksi>(PermintaanAksi.new);

class PermintaanAksi {
  PermintaanAksi(this._ref);

  final Ref _ref;

  void _segarkan(int id) {
    _ref
      ..invalidate(antreanPermintaanProvider)
      ..invalidate(jumlahPermintaanBaruProvider)
      ..invalidate(detailPermintaanProvider(id))
      ..invalidate(pesanPermintaanProvider(id));
  }

  Future<PermintaanPelanggan> terima(
    int id, {
    DateTime? tanggalMasuk,
    DateTime? tanggalJanjiSelesai,
    String? catatan,
    List<LengkapiAlatBaru> alatBaru = const [],
  }) async {
    final hasil = await _ref
        .read(permintaanServiceProvider)
        .terima(
          await _token(_ref),
          id,
          tanggalMasuk: tanggalMasuk,
          tanggalJanjiSelesai: tanggalJanjiSelesai,
          catatan: catatan,
          alatBaru: alatBaru,
        );
    // Penerimaan melahirkan Order: daftar paket (pelacakan) ikut basi. Perangkat
    // LAIN dikabari lewat siaran realtime; ini untuk perangkat yang menekan
    // tombolnya sendiri.
    _segarkan(id);
    _ref.invalidate(daftarPaketProvider);
    return hasil;
  }

  Future<PermintaanPelanggan> tolak(int id, String alasan) async {
    final hasil = await _ref
        .read(permintaanServiceProvider)
        .tolak(await _token(_ref), id, alasan);
    _segarkan(id);
    return hasil;
  }

  /// Jadwalkan teknisi (permintaan `diterima` + `diambil_lab`).
  Future<PermintaanPelanggan> jadwalkan(
    int id, {
    required DateTime jadwalPada,
    String? lokasi,
    String? catatan,
  }) async {
    final hasil = await _ref
        .read(permintaanServiceProvider)
        .jadwalkan(
          await _token(_ref),
          id,
          jadwalPada: jadwalPada,
          lokasi: lokasi,
          catatan: catatan,
        );
    _segarkan(id);
    return hasil;
  }

  /// Tandai alat sudah tiba di lab.
  Future<PermintaanPelanggan> alatTiba(int id) async {
    final hasil = await _ref
        .read(permintaanServiceProvider)
        .alatTiba(await _token(_ref), id);
    _segarkan(id);
    return hasil;
  }

  Future<PesanPermintaan> kirimPesan(int id, String isi) async {
    final hasil = await _ref
        .read(permintaanServiceProvider)
        .kirimPesan(await _token(_ref), id, isi);
    _ref
      ..invalidate(pesanPermintaanProvider(id))
      ..invalidate(detailPermintaanProvider(id));
    return hasil;
  }
}
