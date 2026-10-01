import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/certificate_snapshot.dart';
import '../services/certificate_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'history_provider.dart' show historyProvider;

final certificateServiceProvider = Provider<CertificateService>((ref) {
  if (AppConfig.useMock) return MockCertificateService();
  return ApiCertificateService(ref.watch(apiClientProvider));
});

/// Isi sertifikat buat pratinjau. Family-nya keyed by id sertifikat (bukan id
/// sesi) — satu sesi bisa punya sertifikat revisi nanti.
final certificateDetailProvider =
    FutureProvider.family<CertificateDetail, int>((ref, certificateId) async {
      // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
      ref.watch(authProvider);

      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref
          .read(certificateServiceProvider)
          .detail(token, certificateId);
    }, retry: (retryCount, error) => null);

/// Aksi tulis sertifikat (revisi & pembatalan, admin). Sesudah berhasil, detail
/// sertifikat yang terbuka, riwayat, dan daftar yang menampilkan statusnya
/// ditarik ulang — sertifikat lama berubah jadi `digantikan`/`dibatalkan`, dan
/// (untuk revisi) baris baru lahir.
final sertifikatAksiProvider = Provider<SertifikatAksi>(SertifikatAksi.new);

class SertifikatAksi {
  SertifikatAksi(this._ref);

  final Ref _ref;

  Future<String> _token() async {
    final token = await _ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  void _segarkan(int id) {
    _ref
      ..invalidate(certificateDetailProvider(id))
      ..invalidate(historyProvider);
  }

  /// Mengembalikan baris REVISI baru (`menunggu_generate`).
  Future<CertificateDetail> revisi(
    int id, {
    required Map<String, String> perubahan,
    required String alasan,
    String? catatanPelanggan,
  }) async {
    final hasil = await _ref
        .read(certificateServiceProvider)
        .revisi(
          await _token(),
          id,
          perubahan: perubahan,
          alasan: alasan,
          catatanPelanggan: catatanPelanggan,
        );
    _segarkan(id);
    return hasil;
  }

  Future<CertificateDetail> batalkan(
    int id, {
    required String alasan,
    String? catatanPelanggan,
  }) async {
    final hasil = await _ref
        .read(certificateServiceProvider)
        .batalkan(
          await _token(),
          id,
          alasan: alasan,
          catatanPelanggan: catatanPelanggan,
        );
    _segarkan(id);
    return hasil;
  }
}
