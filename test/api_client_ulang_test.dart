import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';

/// Server yang lagi diganti atau lagi bangun nggak boleh kebaca sebagai
/// kerusakan — TAPI nggak semua permintaan boleh diulang.
///
/// ## Kenapa
///
/// Sebelum ini `ApiClient` nyerah di percobaan PERTAMA: sekali gagal langsung
/// jadi "Server nggak nyaut" di layar teknisi. Dua keadaan yang sebenarnya
/// normal ikut kena:
///
///  1. **Server lagi diganti.** Tiap deploy, container lama dimatikan dan yang
///     baru butuh belasan detik siap. Selama itu jawabannya 502/503/504.
///  2. **Server lagi bangun.** Paket gratis Render tidur sesudah ~15 menit
///     nganggur; permintaan pertama sesudahnya butuh 30–60 detik.
///
/// ## Yang dijaga di sini
///
/// Bukan cuma "ngulang jalan", tapi juga **yang nggak boleh diulang tetap
/// nggak diulang**. Buat alat ukur, sesi kalibrasi kembar atau email
/// sertifikat yang kekirim dua kali ke pelanggan lebih buruk daripada satu
/// pesan gagal yang jujur.
class _ServerGoyah extends http.BaseClient {
  _ServerGoyah({required this.gagalBerapaKali, this.kode = 503});

  /// Berapa percobaan pertama yang dijawab gagal sebelum akhirnya sukses.
  final int gagalBerapaKali;

  /// `null` = putus koneksi (SocketException), bukan jawaban HTTP.
  final int? kode;

  int panggilan = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    panggilan++;

    if (panggilan <= gagalBerapaKali) {
      if (kode == null) throw const SocketException('koneksi ditolak');

      return http.StreamedResponse(
        Stream.value('{"message":"sedang tidak siap"}'.codeUnits),
        kode!,
      );
    }

    return http.StreamedResponse(
      Stream.value('{"data":{"ok":true}}'.codeUnits),
      200,
    );
  }
}

void main() {
  group('yang AMAN diulang', () {
    test('GET nembus 503 beruntun — layar nggak lihat kegagalan sama sekali',
        () async {
      final server = _ServerGoyah(gagalBerapaKali: 2);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      final hasil = await api.get('/dashboard');

      expect(hasil['data'], {'ok': true});
      expect(server.panggilan, 3, reason: '2 gagal + 1 berhasil');
    });

    test('GET nembus koneksi putus, bukan cuma kode HTTP', () async {
      final server = _ServerGoyah(gagalBerapaKali: 1, kode: null);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      await api.get('/dashboard');

      expect(server.panggilan, 2);
    });

    test('PUT diulang — ngganti isi, dijalanin dua kali hasilnya sama', () async {
      final server = _ServerGoyah(gagalBerapaKali: 1);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      await api.put('/calibrations/1', body: {'equipment_id': 5});

      expect(server.panggilan, 2);
    });

    test('POST ber-client_request_id diulang — backend mendedup', () async {
      final server = _ServerGoyah(gagalBerapaKali: 2);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      await api.post(
        '/calibrations',
        body: {
          'equipment_id': 5,
          'client_request_id': '11111111-2222-4333-8444-555555555555',
        },
      );

      expect(server.panggilan, 3);
    });
  });

  group('yang TIDAK boleh diulang', () {
    test('POST tanpa kunci idempotensi cuma sekali — email nggak dobel',
        () async {
      final server = _ServerGoyah(gagalBerapaKali: 1);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      await expectLater(
        api.post('/certificates/93/kirim-email', body: {'to': 'a@b.c'}),
        throwsA(isA<AuthException>()),
      );

      expect(
        server.panggilan,
        1,
        reason: 'kiriman tanpa kunci idempotensi nggak boleh diulang '
            '— server bisa jadi sudah terlanjur mengirim',
      );
    });

    test('400/422 nggak diulang — itu permintaannya yang salah, bukan server',
        () async {
      final server = _ServerGoyah(gagalBerapaKali: 1, kode: 422);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      await expectLater(api.get('/dashboard'), throwsA(isA<AuthException>()));

      expect(
        server.panggilan,
        1,
        reason: 'ngulang permintaan yang ditolak validasi cuma buang waktu',
      );
    });

    test('500 nggak diulang — aplikasinya yang meledak, bukan lagi bangun',
        () async {
      final server = _ServerGoyah(gagalBerapaKali: 1, kode: 500);
      final api = ApiClient(client: server, baseUrl: 'http://uji');

      await expectLater(api.get('/dashboard'), throwsA(isA<AuthException>()));

      expect(server.panggilan, 1);
    });
  });

  test('server yang nggak sembuh-sembuh tetap nyerah, bukan nunggu selamanya',
      () async {
    final server = _ServerGoyah(gagalBerapaKali: 999);
    final api = ApiClient(client: server, baseUrl: 'http://uji');

    await expectLater(api.get('/dashboard'), throwsA(isA<AuthException>()));

    // 1 percobaan awal + 3 ulangan. Batasnya ada supaya teknisi dapat kabar,
    // bukan menatap layar muter tanpa ujung.
    expect(server.panggilan, 4);
  });
}
