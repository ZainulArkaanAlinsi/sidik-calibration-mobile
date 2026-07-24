import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import 'auth_service.dart';

/// Pembungkus HTTP buat semua panggilan ke `sidik-calibration-api`.
///
/// Tugasnya cuma dua: nempelin header yang bener (termasuk token Sanctum),
/// dan **nerjemahin error HTTP jadi pesan yang layak dibaca manusia**.
/// Layar nggak boleh lihat status code mentah — itu tugas file ini.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    // Sanctum: token dikirim apa adanya sebagai Bearer. Bentuknya
    // `1|JpQDXLhSEz...`, bukan JWT — tapi caranya sama persis.
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    return _kirim(() => _client.get(_uri(path), headers: _headers(token)));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _kirim(
      () => _client.post(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _kirim(
      () => _client.put(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  /// Dipakai kolom administratif sesi (`PATCH /calibrations/{id}/admin`) —
  /// PATCH, bukan PUT, karena yang dikirim cuma kolom yang diubah.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _kirim(
      () => _client.patch(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    return _kirim(() => _client.delete(_uri(path), headers: _headers(token)));
  }

  /// Unggah file (multipart) — dipakai Import Excel & foto OCR.
  ///
  /// Nggak lewat [_headers]: `Content-Type` harus dibiarin `http` yang nyusun
  /// (dia yang tau boundary multipart-nya). Kalau dipaksa
  /// `application/json` kayak endpoint lain, server nolak sebelum baca filenya.
  Future<Map<String, dynamic>> unggahFile(
    String path, {
    required String field,
    required String filePath,
    Map<String, String> fields = const {},
    String? token,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    return _kirim(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll({
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        })
        ..fields.addAll(fields)
        ..files.add(await http.MultipartFile.fromPath(field, filePath));

      // Timeout-nya lebih longgar dari request biasa: file 10 MB lewat sinyal
      // lapangan nggak bakal kelar dalam 20 detik.
      final streamed = await request.send().timeout(timeout);
      return http.Response.fromStream(streamed);
    });
  }

  Future<Map<String, dynamic>> _kirim(
    Future<http.Response> Function() request,
  ) async {
    final http.Response res;

    try {
      res = await request().timeout(const Duration(seconds: 20));
    } on SocketException {
      // Paling sering kejadian: teknisi di lapangan sinyalnya ilang, atau
      // `php artisan serve` di laptop belum dinyalain.
      throw const AuthException(
        'Nggak bisa nyambung ke server. Cek koneksi kamu.',
      );
    } catch (_) {
      throw const AuthException('Server nggak nyaut. Coba lagi sebentar.');
    }

    final json = _decode(res);

    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    // Body-nya ikut dilempar, bukan cuma pesannya: sebagian jawaban gagal
    // isinya data yang harus ditampilin (mis. `validasi` + `butuh_konfirmasi`
    // di approve). Lihat ApiException.
    throw ApiException(
      _pesanError(res.statusCode, json),
      status: res.statusCode,
      body: json,
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      // Body-nya bukan JSON — biasanya halaman error HTML dari Laravel.
      // Jangan lempar mentah ke user.
      return {};
    }
  }

  /// Pesan dari backend dipakai kalau ada — dia yang paling tahu konteksnya
  /// (mis. beda pesan buat akun `pending` vs `nonaktif`). Kalau kosong, baru
  /// pakai pesan cadangan per status code.
  String _pesanError(int status, Map<String, dynamic> json) {
    final dariServer = json['message'] as String?;
    if (dariServer != null && dariServer.isNotEmpty) return dariServer;

    return switch (status) {
      401 => 'ID pegawai / email atau password salah.',
      403 => 'Kamu nggak punya akses ke sini.',
      404 => 'Data nggak ketemu.',
      // Rate limit Sanctum: login 10x/menit, register 5x/menit.
      429 => 'Kebanyakan percobaan. Tunggu sebentar terus coba lagi.',
      422 => 'Data yang dikirim nggak valid.',
      >= 500 => 'Server lagi bermasalah. Coba lagi sebentar.',
      _ => 'Ada yang salah. Coba lagi.',
    };
  }
}
