import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/perhitungan.dart';
import '../models/validasi.dart';
import '../services/perhitungan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

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
  final token = await _token(ref);
  return ref.read(perhitunganServiceProvider).ambil(token, calibrationId);
}, retry: (retryCount, error) => null);

/// Aksi admin di satu sesi: periksa, setujui, tolak, simpan kolom
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

  /// Temuannya ikut di [HasilApprove] — baik waktu disetujui maupun ditolak —
  /// jadi layar nggak perlu nembak `/validasi` lagi sesudah ini.
  Future<HasilApprove> setujui({bool abaikanPeringatan = false}) async {
    final token = await _token(_ref);
    final hasil = await _ref
        .read(perhitunganServiceProvider)
        .setujui(token, calibrationId, abaikanPeringatan: abaikanPeringatan);

    if (hasil.disetujui) _segarkan();
    return hasil;
  }

  Future<void> tolak(String catatanRevisi) async {
    final token = await _token(_ref);
    await _ref
        .read(perhitunganServiceProvider)
        .tolak(token, calibrationId, catatanRevisi);
    _segarkan();
  }

  Future<void> simpanKolomAdmin({
    String? nomorOrder,
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
          thermohygroStandardId: thermohygroStandardId,
          roomId: roomId,
          tanggalTerima: tanggalTerima,
        );

    // WAJIB muat ulang: begitu thermohygro dipilih, koreksi & U95% kondisi
    // lingkungan langsung ikut terhitung di server. Tanpa ini admin lihat
    // kolom yang masih kosong padahal barusan keisi.
    _ref.invalidate(perhitunganProvider(calibrationId));
  }

  void _segarkan() {
    _ref.invalidate(perhitunganProvider(calibrationId));
  }
}
