import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/data_acuan.dart';
import '../services/data_acuan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// Studio Data Acuan (CR-48) — lapisan baca untuk layar S1/S2/S3/S7.
///
/// Semua provider di sini:
///  - di-`watch` ke [authProvider]: ganti akun → data lab sebelumnya tidak ikut,
///    dan teknisi ↔ admin melihat isi yang memang beda (server yang memutuskan);
///  - `retry: null` — retry otomatis bawaan Riverpod 3 dimatikan, pola
///    `dashboardProvider`. 404 untuk teknisi (versi non-aktif, banding, riwayat
///    sel) itu jawaban tetap; mengulangnya cuma menggempur server.
///
/// Disegarkan oleh `realtime_provider.dart` (sinyal `data_acuan`, FR-22, dan
/// tarikan berkala) — invalidate lazy: yang ditarik ulang cuma yang sedang
/// ditonton.
final dataAcuanServiceProvider = Provider<DataAcuanService>((ref) {
  if (AppConfig.useMock) return MockDataAcuanService();
  return ApiDataAcuanService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
  ref.watch(authProvider);

  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Daftar paket (S1). Nama sengaja ber-`Acuan`: `daftarPaketProvider` sudah
/// dipakai modul pengendalian (paket pekerjaan pelanggan).
final daftarPaketAcuanProvider = FutureProvider<List<PaketAcuan>>((ref) async {
  final token = await _token(ref);
  return ref.read(dataAcuanServiceProvider).daftarPaket(token);
}, retry: (retryCount, error) => null);

/// Detail satu paket + skema (S2), di-key kode paket (`micrometer`).
final detailPaketAcuanProvider = FutureProvider.family<PaketAcuan, String>((
  ref,
  kode,
) async {
  final token = await _token(ref);
  return ref.read(dataAcuanServiceProvider).paket(token, kode);
}, retry: (retryCount, error) => null);

/// Garis waktu versi satu paket (FR-28), tanpa `isi`.
final garisWaktuAcuanProvider = FutureProvider.family<List<VersiAcuan>, String>(
  (ref, kode) async {
    final token = await _token(ref);
    return ref.read(dataAcuanServiceProvider).garisWaktu(token, kode);
  },
  retry: (retryCount, error) => null,
);

/// Satu versi lengkap dengan `isi` (S2), di-key id versi.
final versiAcuanProvider = FutureProvider.family<VersiAcuan, int>((
  ref,
  versiId,
) async {
  final token = await _token(ref);
  return ref.read(dataAcuanServiceProvider).versi(token, versiId);
}, retry: (retryCount, error) => null);

/// Kunci [berlakuAcuanProvider]. [tanggal] sebaiknya tanggal saja (tanpa
/// jam): dua `DateTime` di hari yang sama tapi jam beda = dua kunci cache.
typedef KunciBerlakuAcuan = ({String kode, DateTime tanggal, String jenis});

/// "Sesi bertanggal X dihitung pakai versi yang mana?" (FR-04). `versi`
/// `null` + `alasan` itu jawaban sah, bukan galat.
final berlakuAcuanProvider =
    FutureProvider.family<HasilBerlakuAcuan, KunciBerlakuAcuan>((
      ref,
      kunci,
    ) async {
      final token = await _token(ref);
      return ref
          .read(dataAcuanServiceProvider)
          .berlaku(token, kunci.kode, kunci.tanggal, jenis: kunci.jenis);
    }, retry: (retryCount, error) => null);

/// Kunci [bandingAcuanProvider]: [lama] → [baru].
typedef KunciBandingAcuan = ({int lama, int baru});

/// Banding dua versi (S3, FR-11). Teknisi → 404 dari server.
final bandingAcuanProvider =
    FutureProvider.family<BandingAcuan, KunciBandingAcuan>((ref, kunci) async {
      final token = await _token(ref);
      return ref
          .read(dataAcuanServiceProvider)
          .banding(token, kunci.lama, kunci.baru);
    }, retry: (retryCount, error) => null);

/// Kunci [riwayatSelAcuanProvider] — alamat satu sel di satu versi.
typedef KunciSelAcuan = ({
  int versiId,
  String lembar,
  String kunci,
  String kolom,
});

/// Riwayat satu sel lintas versi + suntingannya (S7, FR-03/FR-28). Teknisi →
/// 404 dari server.
final riwayatSelAcuanProvider =
    FutureProvider.family<RiwayatSelAcuan, KunciSelAcuan>((ref, sel) async {
      final token = await _token(ref);
      return ref
          .read(dataAcuanServiceProvider)
          .riwayatSel(
            token,
            versiId: sel.versiId,
            lembar: sel.lembar,
            kunci: sel.kunci,
            kolom: sel.kolom,
          );
    }, retry: (retryCount, error) => null);

/// Tarik ulang SEMUA provider data acuan (lazy). Satu pintu supaya sinyal
/// realtime dan layar yang ingin menyegarkan tidak lupa salah satunya.
void segarkanDataAcuan(Ref ref) {
  ref.invalidate(daftarPaketAcuanProvider);
  ref.invalidate(detailPaketAcuanProvider);
  ref.invalidate(garisWaktuAcuanProvider);
  ref.invalidate(versiAcuanProvider);
  ref.invalidate(berlakuAcuanProvider);
  ref.invalidate(bandingAcuanProvider);
  ref.invalidate(riwayatSelAcuanProvider);
}
