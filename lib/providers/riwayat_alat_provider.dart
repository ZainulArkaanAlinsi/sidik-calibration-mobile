import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/alat_pelanggan.dart';
import '../services/riwayat_alat_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';

final riwayatAlatServiceProvider = Provider<RiwayatAlatService>((ref) {
  if (AppConfig.useMock) return MockRiwayatAlatService();
  return ApiRiwayatAlatService(ref.watch(apiClientProvider));
});

/// Daftar paginasi KURSOR yang tumbuh halaman demi halaman.
///
/// Cache sengaja terbatas pada halaman yang sudah dibuka pengguna: daftar
/// hidup di provider auto-dispose, jadi keluar dari layar membuangnya, dan
/// tidak ada yang ditulis ke disk.
class DaftarKursor<T> {
  const DaftarKursor({
    required this.items,
    this.kursorBerikut,
    this.memuatLagi = false,
    this.galatLanjut,
  });

  final List<T> items;
  final String? kursorBerikut;

  /// Halaman berikutnya sedang diminta (jangan minta dua kali).
  final bool memuatLagi;

  /// Permintaan halaman berikutnya gagal. Daftar yang sudah tampak TETAP;
  /// gulir tidak mengulang otomatis (hanya tombol Coba lagi).
  final Object? galatLanjut;

  bool get adaLagi => kursorBerikut != null;

  DaftarKursor<T> salin({
    bool? memuatLagi,
    Object? galatLanjut,
    bool hapusGalat = false,
  }) => DaftarKursor(
    items: items,
    kursorBerikut: kursorBerikut,
    memuatLagi: memuatLagi ?? this.memuatLagi,
    galatLanjut: hapusGalat ? null : (galatLanjut ?? this.galatLanjut),
  );
}

/// Dasar dua daftar kursor di bawah: halaman pertama, muat ulang, dan muat
/// lebih banyak yang MENAMBAH (tidak mengosongkan daftar, supaya posisi gulir
/// tidak loncat) dengan penjaga balapan.
abstract class PemuatKursor<T> extends AsyncNotifier<DaftarKursor<T>>
    with PenjagaUrutanMuat<DaftarKursor<T>> {
  Future<HalamanKursor<T>> ambilHalaman(String token, String? kursor);

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  @override
  Future<DaftarKursor<T>> build() async {
    // Ikut akun yang login: ganti akun → daftar lab sebelumnya tidak ikut.
    ref.watch(authProvider);
    return _halamanPertama();
  }

  Future<DaftarKursor<T>> _halamanPertama() async {
    final hal = await ambilHalaman(await _token(), null);
    return DaftarKursor(items: hal.items, kursorBerikut: hal.kursorBerikut);
  }

  Future<void> muatUlang() => muatDenganPenjaga(_halamanPertama);

  /// Tambahkan halaman berikutnya. [paksa] = dari tombol Coba lagi (boleh
  /// meski permintaan sebelumnya gagal); pemicu gulir memakai bawaan `false`
  /// supaya satu galat tidak menjadi badai permintaan.
  Future<void> muatLebihBanyak({bool paksa = false}) async {
    final s = state.value;
    if (s == null || !s.adaLagi || s.memuatLagi) return;
    if (s.galatLanjut != null && !paksa) return;

    final nomor = mulaiPermintaan();
    state = AsyncData(s.salin(memuatLagi: true, hapusGalat: true));
    try {
      final hal = await ambilHalaman(await _token(), s.kursorBerikut);
      if (!masihTerbaru(nomor)) return;
      state = AsyncData(
        DaftarKursor(
          items: [...s.items, ...hal.items],
          kursorBerikut: hal.kursorBerikut,
        ),
      );
    } catch (e) {
      if (!masihTerbaru(nomor)) return;
      state = AsyncData(s.salin(memuatLagi: false, galatLanjut: e));
    }
  }
}

/// Alat milik satu pelanggan (`GET /customers/{id}/alat`).
class AlatPelangganController extends PemuatKursor<AlatRingkas> {
  AlatPelangganController(this.customerId);

  final int customerId;

  @override
  Future<HalamanKursor<AlatRingkas>> ambilHalaman(
    String token,
    String? kursor,
  ) => ref
      .read(riwayatAlatServiceProvider)
      .alat(token, customerId, kursor: kursor);
}

final alatPelangganProvider =
    AsyncNotifierProvider.family<
      AlatPelangganController,
      DaftarKursor<AlatRingkas>,
      int
    >(AlatPelangganController.new, retry: (retryCount, error) => null);

/// Riwayat sertifikat satu alat (`GET /equipments/{id}/sertifikat`).
class SertifikatAlatController extends PemuatKursor<SertifikatRingkas> {
  SertifikatAlatController(this.equipmentId);

  final int equipmentId;

  @override
  Future<HalamanKursor<SertifikatRingkas>> ambilHalaman(
    String token,
    String? kursor,
  ) => ref
      .read(riwayatAlatServiceProvider)
      .sertifikat(token, equipmentId, kursor: kursor);
}

final sertifikatAlatProvider =
    AsyncNotifierProvider.family<
      SertifikatAlatController,
      DaftarKursor<SertifikatRingkas>,
      int
    >(SertifikatAlatController.new, retry: (retryCount, error) => null);
