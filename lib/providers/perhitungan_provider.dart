import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/bandingkan.dart';
import '../models/perhitungan.dart';
import '../models/validasi.dart';
import '../services/bandingkan_service.dart';
import '../services/perhitungan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'history_provider.dart' show calibrationDetailProvider;
import 'riwayat_persetujuan_provider.dart';

final perhitunganServiceProvider = Provider<PerhitunganService>((ref) {
  if (AppConfig.useMock) return MockPerhitunganService();
  return ApiPerhitunganService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Lembar PERHITUNGAN satu sesi.
final perhitunganProvider = FutureProvider.family<Perhitungan, int>((
  ref,
  calibrationId,
) async {
  // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
  ref.watch(authProvider);

  final token = await _token(ref);
  return ref.read(perhitunganServiceProvider).ambil(token, calibrationId);
}, retry: (retryCount, error) => null);

/// Aksi admin di satu sesi: periksa, setujui, simpan kolom
/// administratif.
///
/// Hasil "Periksa" **nggak ditaruh di provider**: cuma satu layar yang
/// memakainya, dan pemeriksaan itu hitung ulang penuh dari pembacaan mentah
/// yang admin sendiri yang mutusin kapan dijalankan — bukan tiap kali layar
/// kebuka. Jadi layarnya yang megang, dan `setujui()` balikin temuannya
/// sekalian lewat [HasilApprove].
final aksiAdminProvider = Provider.family<AksiAdmin, int>(AksiAdmin.new);

class AksiAdmin {
  AksiAdmin(this._ref, this.calibrationId);

  final Ref _ref;
  final int calibrationId;

  Future<HasilValidasi> periksa() async {
    final token = await _token(_ref);
    return _ref.read(perhitunganServiceProvider).periksa(token, calibrationId);
  }

  /// Temuannya ikut di [HasilApprove] — baik waktu disetujui maupun ditahan —
  /// jadi layar nggak perlu nembak `/validasi` lagi sesudah ini.
  Future<HasilApprove> setujui({
    bool abaikanPeringatan = false,
    String? nomorSertifikat,
  }) async {
    final token = await _token(_ref);
    final hasil = await _ref
        .read(perhitunganServiceProvider)
        .setujui(
          token,
          calibrationId,
          abaikanPeringatan: abaikanPeringatan,
          nomorSertifikat: nomorSertifikat,
        );

    if (hasil.disetujui) _segarkan();
    return hasil;
  }

  /// Kolom administratif (`PATCH /calibrations/{id}/admin`). Yang `null`
  /// TIDAK dikirim — kirim null mengosongkan kolomnya di server.
  ///
  /// Order Number diisi di sini oleh Master Data atau super admin, tidak
  /// pernah oleh teknisi (K-49-14).
  Future<void> simpanKolomAdmin({
    String? nomorOrder,
    int? calibrationMethodId,
    int? thermohygroStandardId,
    int? roomId,
    String? tanggalTerima,
  }) async {
    final token = await _token(_ref);
    await _ref
        .read(perhitunganServiceProvider)
        .simpanKolomAdmin(
          token,
          calibrationId,
          nomorOrder: nomorOrder,
          calibrationMethodId: calibrationMethodId,
          thermohygroStandardId: thermohygroStandardId,
          roomId: roomId,
          tanggalTerima: tanggalTerima,
        );

    // WAJIB muat ulang: begitu thermohygro dipilih, koreksi & U95% kondisi
    // lingkungan langsung ikut terhitung di server. Tanpa ini admin lihat
    // kolom yang masih kosong padahal barusan keisi.
    _ref.invalidate(perhitunganProvider(calibrationId));
    // Kartu "Data administrasi" membaca detail sesi — Order Number yang
    // barusan disimpan harus kelihatan, dan Setujui berhenti memintanya.
    _ref.invalidate(calibrationDetailProvider(calibrationId));
  }

  void _segarkan() {
    _ref.invalidate(perhitunganProvider(calibrationId));
    // Setuju menambah satu peristiwa di riwayat persetujuan sesi ini.
    _ref.invalidate(riwayatPersetujuanProvider(calibrationId));
  }
}

final bandingkanServiceProvider = Provider<BandingkanService>((ref) {
  if (AppConfig.useMock) return MockBandingkanService();
  return ApiBandingkanService(ref.watch(apiClientProvider));
});

/// Isian asli teknisi lawan sekarang (layar Bandingkan). `autoDispose`: dibuka
/// ulang selalu menarik yang terbaru, karena koreksi baru bisa saja terjadi.
final bandingkanProvider = FutureProvider.autoDispose
    .family<Bandingkan, int>((ref, calibrationId) async {
      ref.watch(authProvider);
      final token = await _token(ref);
      return ref.read(bandingkanServiceProvider).ambil(token, calibrationId);
    }, retry: (retryCount, error) => null);
