import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/penugasan.dart';
import '../services/penugasan_kelola_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';
import 'super_admin_provider.dart' show DaftarBerhalaman;

/// Provider kelola Penugasan (papan, ubah, batalkan). Disaring per akun
/// (`ref.watch(authProvider)`) seperti semua data lab (skill scope-akun).
final penugasanKelolaServiceProvider = Provider<PenugasanKelolaService>((ref) {
  if (AppConfig.useMock) return MockPenugasanKelolaService();
  return ApiPenugasanKelolaService(ref.watch(apiClientProvider));
});

/// Status yang bisa disaring. Bawaan `aktif`: hanya penugasan aktif yang bisa
/// diubah atau dibatalkan, jadi itu yang pertama dilihat.
abstract final class StatusPenugasan {
  static const aktif = 'aktif';
  static const selesai = 'selesai';
  static const dibatalkan = 'dibatalkan';

  static const semua = [aktif, selesai, dibatalkan];
}

final penugasanKelolaProvider =
    AsyncNotifierProvider<
      PenugasanKelolaController,
      DaftarBerhalaman<Penugasan>
    >(PenugasanKelolaController.new, retry: (retryCount, error) => null);

class PenugasanKelolaController
    extends AsyncNotifier<DaftarBerhalaman<Penugasan>>
    with PenjagaUrutanMuat<DaftarBerhalaman<Penugasan>> {
  String? _status = StatusPenugasan.aktif;

  /// `null` = semua status.
  String? get status => _status;

  @override
  Future<DaftarBerhalaman<Penugasan>> build() async {
    // Daftarkan build ini sebagai permintaan terbaru SEBELUM apa pun (lihat
    // `OrderKelolaController.build`): halaman 2 akun lama tidak boleh
    // menempel ke daftar akun baru.
    mulaiPermintaan();
    // Hanya identitas akun yang memicu bangun ulang: emisi auth lain (mis.
    // sesudah pendaftaran push) tidak boleh membuang saringan yang sedang
    // dipakai. Ganti akun (id berubah, termasuk lewat logout) tetap bangun ulang.
    ref.watch(authProvider.select((a) => a.value?.id));
    _status = StatusPenugasan.aktif;
    return _muat(1);
  }

  Future<DaftarBerhalaman<Penugasan>> _muat(int halaman) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await ref
        .read(penugasanKelolaServiceProvider)
        .daftar(token, status: _status, halaman: halaman);
    return DaftarBerhalaman(
      items: hasil.items,
      halaman: hasil.halaman,
      halamanTerakhir: hasil.halamanTerakhir,
    );
  }

  Future<void> saring(String? status) async {
    _status = status;
    await muatDenganPenjaga(() => _muat(1));
  }

  /// Dipanggil sesudah SETIAP aksi sukses: papan diambil ulang dari server.
  Future<void> muatUlang() => muatDenganPenjaga(() => _muat(1));

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
