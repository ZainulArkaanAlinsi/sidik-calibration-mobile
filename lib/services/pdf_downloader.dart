import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Ngunduh sertifikat PDF ke file lokal — beda dari [ApiClient], `pdf_url`
/// (`docs/kontrak-api.md` §5, `CertificateController::download()`) balikin
/// **file PDF mentah, bukan JSON**, dan butuh header `Authorization: Bearer`
/// yang sama kayak endpoint API lain (bukan link publik yang bisa dibuka
/// langsung di browser HP).
abstract class PdfDownloader {
  /// Balikin path file lokal siap dibuka (`OpenFilex.open(path)`).
  Future<String> unduh(String token, String url, {required String namaFile});
}

class PdfDownloadException implements Exception {
  const PdfDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HttpPdfDownloader implements PdfDownloader {
  HttpPdfDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> unduh(String token, String url, {required String namaFile}) async {
    final http.Response res;
    try {
      res = await _client
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const PdfDownloadException(
        'Gagal ngunduh PDF. Cek koneksi kamu.',
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PdfDownloadException(
        'Server nolak unduhan PDF (${res.statusCode}).',
      );
    }

    // Direktori temp — bukan penyimpanan permanen, cukup buat "buka sekali
    // lihat". Nama file dibersihin dari `/` (nomor sertifikat ada slash-nya,
    // mis. CAL/2026/07/0001) biar valid jadi nama file.
    final dir = await getTemporaryDirectory();
    final aman = namaFile.replaceAll('/', '-');
    final file = File('${dir.path}/$aman');
    await file.writeAsBytes(res.bodyBytes);
    return file.path;
  }
}

/// Data tiruan buat test — nggak nyentuh filesystem/network beneran.
class MockPdfDownloader implements PdfDownloader {
  MockPdfDownloader({this.gagal = false});

  final bool gagal;
  String? lastUrl;

  @override
  Future<String> unduh(String token, String url, {required String namaFile}) async {
    lastUrl = url;
    if (gagal) throw const PdfDownloadException('Gagal ngunduh PDF. Cek koneksi kamu.');
    return '/tmp/$namaFile';
  }
}
