import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../models/certificate_snapshot.dart';
import '../services/certificate_service.dart';
import '../services/pdf_downloader.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'history_provider.dart'
    show antreanApprovalProvider, historyProvider, pdfDownloaderProvider;

final certificateServiceProvider = Provider<CertificateService>((ref) {
  if (AppConfig.useMock) return MockCertificateService();
  return ApiCertificateService(ref.watch(apiClientProvider));
});

/// Isi sertifikat buat pratinjau. Family-nya keyed by id sertifikat (bukan id
/// sesi) — satu sesi bisa punya sertifikat revisi nanti.
final certificateDetailProvider = FutureProvider.family<CertificateDetail, int>(
  (ref, certificateId) async {
    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(certificateServiceProvider).detail(token, certificateId);
  },
  retry: (retryCount, error) => null,
);

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

  /// Tarik sertifikat ke lembar kerja (admin & super admin). Sesinya kembali ke
  /// `menunggu_approval`, jadi riwayat & antrean ikut ditarik ulang.
  Future<CertificateDetail> tarik(
    int id, {
    required String alasan,
    required String password,
  }) async {
    final hasil = await _ref
        .read(certificateServiceProvider)
        .tarik(await _token(), id, alasan: alasan, password: password);
    _segarkan(id);
    _ref.invalidate(antreanApprovalProvider);
    return hasil;
  }
}

/// PDF sertifikat yang dirender di layar sertifikat: berkas server yang sama
/// dengan tombol Unduh (G4), jadi struktur per jenis alat identik dengan cetak.
class PdfSertifikat {
  const PdfSertifikat(this.bytes, {this.dariCache = false});

  final List<int> bytes;

  /// `true` = unduhan gagal (mis. luring) dan yang tampil salinan terakhir.
  final bool dariCache;
}

/// Unduh lewat klien berotorisasi yang sama; kalau gagal, pakai berkas yang
/// terakhir tersimpan (nama tetap per id) sebelum menyerah.
final pdfSertifikatProvider = FutureProvider.family<PdfSertifikat, int>((
  ref,
  certificateId,
) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  final url = ref.read(certificateServiceProvider).urlPdf(certificateId);
  final nama = 'pratinjau-sertifikat-$certificateId.pdf';
  try {
    final path = await ref
        .read(pdfDownloaderProvider)
        .unduh(token, url, namaFile: nama);
    return PdfSertifikat(await File(path).readAsBytes());
  } on PdfDownloadException {
    final dir = await getTemporaryDirectory();
    final cache = File('${dir.path}/$nama');
    if (await cache.exists()) {
      return PdfSertifikat(await cache.readAsBytes(), dariCache: true);
    }
    rethrow;
  }
}, retry: (retryCount, error) => null);
