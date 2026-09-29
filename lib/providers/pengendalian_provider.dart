import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/pelacakan.dart';
import '../models/penugasan.dart';
import '../models/pengesahan.dart';
import '../services/pelacakan_service.dart';
import '../services/penugasan_service.dart';
import '../services/pengesahan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';

/// Tiga fitur "pengendalian" dari keputusan 26 Sep 2026 — gerbang pengesahan,
/// pelacakan paket, penugasan teknisi. Satu berkas karena ketiganya lahir
/// bersama dan dipakai layar super admin yang sama; kalau salah satunya tumbuh
/// besar, pecah ke berkasnya sendiri.
///
/// Semua controller `ref.watch(authProvider)` di `build()`: ganti akun → data
/// lab sebelumnya tidak ikut (aturan `sidik-fe-scope-akun`).

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

// ── Pengesahan ──────────────────────────────────────────────────────────────

final pengesahanServiceProvider = Provider<PengesahanService>((ref) {
  if (AppConfig.useMock) return MockPengesahanService();
  return ApiPengesahanService(ref.watch(apiClientProvider));
});

final antreanPengesahanProvider =
    AsyncNotifierProvider<AntreanPengesahanController, List<ItemPengesahan>>(
      AntreanPengesahanController.new,
      retry: (retryCount, error) => null,
    );

class AntreanPengesahanController extends AsyncNotifier<List<ItemPengesahan>>
    with PenjagaUrutanMuat<List<ItemPengesahan>> {
  String _cari = '';

  @override
  Future<List<ItemPengesahan>> build() async {
    ref.watch(authProvider);
    return ref
        .read(pengesahanServiceProvider)
        .antrean(await _token(ref), cari: _cari);
  }

  Future<void> cari(String q) async {
    _cari = q;
    await muatDenganPenjaga(build);
  }

  Future<void> muatUlang() => muatDenganPenjaga(build);

  /// Melempar [PengesahanButuhKonfirmasi] ke layar — layar yang menampilkan
  /// temuan pemisahan wewenang, bukan controller ini.
  Future<String> sahkan(int sesiId, {bool abaikanPeringatan = false}) async {
    final pesan = await ref
        .read(pengesahanServiceProvider)
        .sahkan(await _token(ref), sesiId, abaikanPeringatan: abaikanPeringatan);
    await muatUlang();
    return pesan;
  }

  Future<String> kembalikan(int sesiId, String alasan) async {
    final pesan = await ref
        .read(pengesahanServiceProvider)
        .kembalikan(await _token(ref), sesiId, alasan);
    await muatUlang();
    return pesan;
  }

  Future<String> tarik(int sesiId, String alasan) async {
    final pesan = await ref
        .read(pengesahanServiceProvider)
        .tarik(await _token(ref), sesiId, alasan);
    await muatUlang();
    return pesan;
  }
}

// ── Pelacakan ───────────────────────────────────────────────────────────────

final pelacakanServiceProvider = Provider<PelacakanService>((ref) {
  if (AppConfig.useMock) return MockPelacakanService();
  return ApiPelacakanService(ref.watch(apiClientProvider));
});

final daftarPaketProvider =
    AsyncNotifierProvider<DaftarPaketController, List<PaketLacak>>(
      DaftarPaketController.new,
      retry: (retryCount, error) => null,
    );

class DaftarPaketController extends AsyncNotifier<List<PaketLacak>>
    with PenjagaUrutanMuat<List<PaketLacak>> {
  String _cari = '';
  bool _terlambat = false;

  bool get cumaTerlambat => _terlambat;

  @override
  Future<List<PaketLacak>> build() async {
    ref.watch(authProvider);
    return ref
        .read(pelacakanServiceProvider)
        .daftar(await _token(ref), cari: _cari, terlambat: _terlambat);
  }

  Future<void> cari(String q) async {
    _cari = q;
    await muatDenganPenjaga(build);
  }

  Future<void> saringTerlambat(bool nyala) async {
    _terlambat = nyala;
    await muatDenganPenjaga(build);
  }

  Future<void> muatUlang() => muatDenganPenjaga(build);
}

/// Detail satu paket + garis waktunya.
final detailPaketProvider = FutureProvider.autoDispose
    .family<(PaketLacak, List<LangkahGarisWaktu>), int>((ref, id) async {
      ref.watch(authProvider);
      return ref.read(pelacakanServiceProvider).detail(await _token(ref), id);
    });

// ── Penugasan ───────────────────────────────────────────────────────────────

final penugasanServiceProvider = Provider<PenugasanService>((ref) {
  if (AppConfig.useMock) return MockPenugasanService();
  return ApiPenugasanService(ref.watch(apiClientProvider));
});

final daftarPenugasanProvider =
    AsyncNotifierProvider<DaftarPenugasanController, List<Penugasan>>(
      DaftarPenugasanController.new,
      retry: (retryCount, error) => null,
    );

class DaftarPenugasanController extends AsyncNotifier<List<Penugasan>>
    with PenjagaUrutanMuat<List<Penugasan>> {
  @override
  Future<List<Penugasan>> build() async {
    ref.watch(authProvider);
    return ref.read(penugasanServiceProvider).daftar(await _token(ref));
  }

  Future<void> muatUlang() => muatDenganPenjaga(build);

  Future<Penugasan> buat({
    required String judul,
    required List<int> teknisi,
    required List<BarisPenugasan> baris,
    DateTime? tanggalTarget,
    String? catatan,
  }) async {
    final baru = await ref
        .read(penugasanServiceProvider)
        .buat(
          await _token(ref),
          judul: judul,
          teknisi: teknisi,
          baris: baris,
          tanggalTarget: tanggalTarget,
          catatan: catatan,
        );
    await muatUlang();
    return baru;
  }

  Future<void> laporProgres(int barisId, int jumlahSelesai) async {
    await ref
        .read(penugasanServiceProvider)
        .laporProgres(await _token(ref), barisId, jumlahSelesai: jumlahSelesai);
    await muatUlang();
  }

  /// Dipanggil sekali waktu teknisi membuka detail tugasnya. Gagal di sini
  /// tidak boleh menghalangi layar: yang dirugikan cuma satu baris "sudah
  /// dilihat", dan layar kosong karena itu jauh lebih merugikan.
  Future<void> tandaiDilihat(int id) async {
    try {
      await ref.read(penugasanServiceProvider).tandaiDilihat(await _token(ref), id);
    } catch (_) {}
  }
}
