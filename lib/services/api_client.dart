import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
    // Pembacaan aman diulang berapa kali pun — nggak ada yang berubah di
    // server. Ini juga yang paling sering kena pergantian & bangun-tidur
    // server, karena tiap layar dibuka pasti ngambil data dulu.
    return _kirim(
      () => _client.get(_uri(path), headers: _headers(token)),
      bolehUlang: true,
    );
  }

  /// [timeout] dinaikin buat endpoint yang kerjanya SINKRON — mis. kirim
  /// email sertifikat, yang balik sesudah SMTP beneran ngirim, bukan sesudah
  /// masuk antrean. Timeout bawaan 20 detik gampang kelewat di situ, dan
  /// kalau kita nyerah duluan admin ngira gagal padahal servernya masih jalan.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) async {
    // Cuma kiriman ber-`client_request_id` yang diulang. Backend nyari sesi
    // dengan kunci sama sebelum bikin baru, jadi kiriman kedua mendarat di
    // sesi yang itu-itu juga — bukan sesi kalibrasi kembar.
    //
    // `POST` lain (approve, reject, kirim email) SENGAJA nggak diulang:
    // nggak ada kunci yang bikin server tau itu kiriman yang sama, dan email
    // sertifikat yang kekirim dua kali ke pelanggan nggak bisa ditarik balik.
    return _kirim(
      () => _client.post(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ),
      timeout: timeout,
      bolehUlang: body != null && body['client_request_id'] != null,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    // `PUT` mengganti isi sumber daya, bukan nambah yang baru — dijalankan
    // dua kali hasilnya sama persis. Ini yang dipakai "lanjutkan draft" dan
    // "perbaiki lembar kerja".
    return _kirim(
      () => _client.put(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ),
      bolehUlang: true,
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

  /// [body] opsional — dipakai `DELETE /device-tokens`, yang butuh nyebut
  /// token perangkat MANA yang dicabut. Pemanggil lama nggak berubah: tanpa
  /// [body], badannya nggak ikut dikirim sama sekali, sama persis kayak dulu.
  Future<Map<String, dynamic>> delete(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    return _kirim(
      () => _client.delete(
        _uri(path),
        headers: _headers(token),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  /// Unggah file (multipart) — dipakai Import Excel & foto OCR.
  ///
  /// Nggak lewat [_headers]: `Content-Type` harus dibiarin `http` yang nyusun
  /// (dia yang tau boundary multipart-nya). Kalau dipaksa
  /// `application/json` kayak endpoint lain, server nolak sebelum baca filenya.
  ///
  /// [timeout] lebih longgar dari request biasa: file 10 MB lewat sinyal
  /// lapangan nggak bakal kelar dalam 20 detik.
  Future<Map<String, dynamic>> unggahFile(
    String path, {
    required String field,
    required String filePath,
    Map<String, String> fields = const {},
    String? token,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    return _kirim(
      () async {
        final request = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll({
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          })
          ..fields.addAll(fields)
          ..files.add(await http.MultipartFile.fromPath(field, filePath));

        // `request.send()` sengaja NGGAK dipakai: dia bikin `http.Client()`
        // BARU sendiri di dalam, jadi client yang disuntik lewat konstruktor
        // nggak kepakai sama sekali di jalur unggah. Efeknya jalur ini satu-
        // satunya yang nggak bisa dites — mock client di test nggak pernah
        // kena, jadi unggah foto & Import Excel lolos tanpa uji apa pun.
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      },
      // Timeout-nya dioper ke [_kirim], BUKAN dipasang di dalam closure.
      // Dulu dipasang di dalam, dan itu nggak ada efeknya: `_kirim` membungkus
      // seluruh closure dengan batas bawaan 20 detik, jadi 20 detik yang
      // menang dan unggahan >20 detik selalu mati duluan dengan "Server nggak
      // nyaut" — persis di sinyal lapangan yang bikin batas 60 detik ini ada.
      timeout: timeout,
    );
  }

  /// Unggah beberapa berkas SEKALIGUS sama bodi bersarang — dipakai kiriman
  /// hasil pindai lembar kerja (`POST /worksheet-scans`).
  ///
  /// Beda dari [unggahFile] yang cuma bawa satu berkas + kolom datar: bodinya
  /// di sini array bersarang (80+ sel, tiap sel punya kotak sendiri), dan
  /// citranya lampiran yang boleh nggak ada. `multipart` nggak kenal JSON, jadi
  /// bodinya diratakan jadi kolom bertanda kurung (`sel[0][kotak][x]`) — bentuk
  /// yang Laravel rakit balik jadi array yang sama persis.
  Future<Map<String, dynamic>> unggahBanyak(
    String path, {
    required Map<String, dynamic> body,
    Map<String, ({String namaBerkas, Uint8List isi})> berkas = const {},
    String? token,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    return _kirim(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll({
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        })
        ..fields.addAll(ratakanUntukMultipart(body));

      for (final e in berkas.entries) {
        request.files.add(
          http.MultipartFile.fromBytes(
            e.key,
            e.value.isi,
            filename: e.value.namaBerkas,
          ),
        );
      }

      final streamed = await _client.send(request);

      return http.Response.fromStream(streamed);
    }, timeout: timeout);
  }

  /// Ambil **byte mentah**, bukan JSON — buat gambar yang dilayani di balik
  /// auth (tanda tangan sertifikat).
  ///
  /// Kenapa nggak `Image.network` aja: `Image.network` nggak bawa header
  /// `Authorization`, jadi endpoint yang butuh Bearer token bakal balikin
  /// `401` dan gambarnya nggak pernah muncul. Byte-nya ditarik di sini, terus
  /// dipasang lewat `Image.memory`.
  ///
  /// Balikin `null` kalau `404` — itu jawaban sah buat "belum ada tanda
  /// tangan yang diunggah", bukan error yang perlu diteriakin ke user.
  Future<Uint8List?> ambilBytes(String path, {String? token}) async {
    final http.Response res;

    try {
      res = await _client
          .get(_uri(path), headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          })
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const AuthException(
        'Nggak bisa nyambung ke server. Cek koneksi kamu.',
      );
    } catch (_) {
      throw const AuthException('Server nggak nyaut. Coba lagi sebentar.');
    }

    if (res.statusCode == 404) return null;

    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;

    throw ApiException(
      _pesanError(res.statusCode, _decode(res)),
      status: res.statusCode,
      body: const {},
    );
  }

  /// Jeda antar percobaan. Naik supaya percobaan pertama cepat (kedipan
  /// sedetik nggak usah bikin nunggu lama) tapi yang terakhir masih nutup
  /// pergantian server yang makan puluhan detik.
  static const _jedaUlang = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];

  /// Kode HTTP yang artinya "servernya lagi nggak siap", BUKAN "permintaanmu
  /// salah".
  ///
  /// 502/503/504 itu persis yang dibalikin Render waktu container lama
  /// dimatikan dan yang baru belum siap, dan waktu layanan paket gratis
  /// dibangunkan dari tidur. 500 SENGAJA nggak masuk: itu aplikasinya yang
  /// meledak, dan ngulang cuma ngulang ledakan yang sama.
  static const _kodeServerBelumSiap = {502, 503, 504};

  Future<Map<String, dynamic>> _kirim(
    Future<http.Response> Function() request, {
    Duration? timeout,
    bool bolehUlang = false,
  }) async {
    final http.Response res;

    try {
      res = await _dengarUlang(request, timeout: timeout, bolehUlang: bolehUlang);
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

  /// Coba lagi waktu yang gagal SERVERNYA, bukan permintaannya.
  ///
  /// ## Kenapa ini ada
  ///
  /// Sebelumnya satu kali gagal langsung jadi pesan merah di layar teknisi.
  /// Itu bikin dua keadaan yang sebenarnya normal kebaca sebagai kerusakan:
  ///
  ///  1. **Server lagi diganti.** Tiap deploy, container lama dimatikan dan
  ///     yang baru butuh belasan detik buat siap. Selama itu Render jawab
  ///     502/503/504.
  ///  2. **Server lagi bangun.** Paket gratis Render menidurkan layanannya
  ///     sesudah ~15 menit nganggur; permintaan pertama sesudah itu butuh
  ///     30–60 detik.
  ///
  /// Dua-duanya sembuh sendiri kalau ditunggu. Yang salah bukan servernya,
  /// tapi aplikasinya yang nyerah di percobaan pertama.
  ///
  /// ## Kenapa nggak semua diulang
  ///
  /// [bolehUlang] dipasang PER PEMANGGIL, bukan dinyalain borongan. Ngulang
  /// permintaan yang sudah terlanjur sampai ke server bisa bikin kerjaan
  /// dobel — dan buat alat ukur, sesi kalibrasi dobel itu lebih buruk daripada
  /// satu pesan gagal.
  ///
  /// Yang aman diulang cuma yang hasilnya sama berapa kali pun dijalankan:
  /// pembacaan (`GET`), penggantian utuh (`PUT`), penghapusan (`DELETE`), dan
  /// `POST` yang bawa `client_request_id` — backend mendedup yang itu
  /// (`CalibrationController` nyari sesi ber-`client_request_id` sama sebelum
  /// bikin baru).
  Future<http.Response> _dengarUlang(
    Future<http.Response> Function() request, {
    Duration? timeout,
    required bool bolehUlang,
  }) async {
    final batas = timeout ?? const Duration(seconds: 20);

    for (var percobaan = 0; ; percobaan++) {
      final bolehLagi = bolehUlang && percobaan < _jedaUlang.length;

      try {
        final res = await request().timeout(batas);

        if (bolehLagi && _kodeServerBelumSiap.contains(res.statusCode)) {
          await Future<void>.delayed(_jedaUlang[percobaan]);
          continue;
        }

        return res;
      } on SocketException {
        if (!bolehLagi) rethrow;
        await Future<void>.delayed(_jedaUlang[percobaan]);
      } on TimeoutException {
        if (!bolehLagi) rethrow;
        await Future<void>.delayed(_jedaUlang[percobaan]);
      }
    }
  }

  /// Bodi bersarang → kolom multipart bertanda kurung.
  ///
  /// `{"sel": [{"kotak": {"x": 1}}]}` jadi `sel[0][kotak][x] = "1"`. Bentuk itu
  /// yang dirakit balik Laravel jadi array yang sama persis, jadi aturan
  /// validasinya (`sel.*.kotak.x`) tetap kena.
  ///
  /// **`null` dibuang, bukan dikirim string `"null"`.** Multipart nggak punya
  /// nilai kosong yang beda dari teks; `"null"` bakal lolos `nullable|string`
  /// sebagai teks empat huruf, dan sel yang memang KOSONG di kertasnya berubah
  /// jadi sel berisi. `bool` jadi `"1"`/`"0"` — dua-duanya diterima aturan
  /// `boolean` Laravel, sementara `"true"`/`"false"` cuma diterima sebagian.
  @visibleForTesting
  static Map<String, String> ratakanUntukMultipart(Map<String, dynamic> body) {
    final hasil = <String, String>{};

    void isi(String kunci, dynamic nilai) {
      if (nilai == null) return;

      if (nilai is Map) {
        nilai.forEach((k, v) => isi('$kunci[$k]', v));
      } else if (nilai is List) {
        for (var i = 0; i < nilai.length; i++) {
          isi('$kunci[$i]', nilai[i]);
        }
      } else if (nilai is bool) {
        hasil[kunci] = nilai ? '1' : '0';
      } else {
        hasil[kunci] = '$nilai';
      }
    }

    body.forEach(isi);

    return hasil;
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
    // Dicek pakai `is String`, BUKAN `as String?`. Nggak semua yang balikin
    // `message` itu Laravel-nya sendiri: proxy, load balancer, atau paket lain
    // bisa naruh objek/array di situ. `as String?` bakal ngelempar TypeError
    // DI DALAM penanganan error — jadi status 500 yang harusnya kebaca "Server
    // lagi bermasalah" malah jadi crash mentah yang naik ke layar.
    final dariServer = json['message'];
    if (dariServer is String && dariServer.isNotEmpty) return dariServer;

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
