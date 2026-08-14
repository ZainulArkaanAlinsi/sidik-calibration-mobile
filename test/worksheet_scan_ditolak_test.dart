import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Lembar yang DITOLAK server (422).
///
/// **Satu lembar ditolak berarti nggak ada satu angka pun yang dipakai.**
/// Ngisi sebagian dari hasil yang ditolak jauh lebih bahaya daripada gagal
/// terang-terangan: separuh benar di posisi yang salah nggak kelihatan sampai
/// sertifikatnya terbit.
void main() {
  test('422 dari pipeline jadi PindaiDitolak, bukan hasil setengah jadi', () async {
    final service = ApiWorksheetScanService(
      ApiClient(
        client: _Client(422, {
          'scan_id': 392,
          'status': 'ditolak_kualitas',
          'message': 'Fotonya buram. Tahan HP lebih diam, lalu foto ulang.',
          'fallback_manual': true,
        }),
        baseUrl: 'http://contoh.test/api',
      ),
    );

    await expectLater(
      service.kirim('token', const {'template_id': 'ph_meter'}),
      throwsA(
        isA<PindaiDitolak>()
            .having((e) => e.status, 'status', 'ditolak_kualitas')
            .having((e) => e.scanId, 'scanId', 392)
            .having((e) => e.fallbackManual, 'fallbackManual', isTrue)
            // Kalimatnya ditampilin APA ADANYA — ditulis buat teknisi yang
            // lagi berdiri di depan alat pelanggan, bukan buat programmer.
            .having(
              (e) => e.pesan,
              'pesan',
              'Fotonya buram. Tahan HP lebih diam, lalu foto ulang.',
            )
            // Salah foto, bukan salah aplikasi: foto ulang menolong.
            .having((e) => e.bugAplikasi, 'bugAplikasi', isFalse),
      ),
    );
  });

  test('mapping_gagal ditandai sebagai bug aplikasi', () async {
    // Kunci asing/dobel/kurang itu kiriman APK yang salah. Nyuruh teknisi
    // foto ulang bikin dia ngulang-ngulang buat kesalahan yang nggak ada
    // hubungannya sama jepretannya.
    final service = ApiWorksheetScanService(
      ApiClient(
        client: _Client(422, {
          'scan_id': 393,
          'status': 'mapping_gagal',
          'message': 'Label baris di lembar nggak cocok sama urutan.',
          'fallback_manual': true,
        }),
        baseUrl: 'http://contoh.test/api',
      ),
    );

    await expectLater(
      service.kirim('token', const {'template_id': 'ph_meter'}),
      throwsA(
        isA<PindaiDitolak>().having((e) => e.bugAplikasi, 'bugAplikasi', isTrue),
      ),
    );
  });

  test('422 tanpa status TETAP error biasa, bukan nyamar jadi foto jelek', () async {
    // Ini 422 dari lapisan bentuk (`WorksheetScanRequest`) — bug kiriman
    // aplikasi. Menyamarkannya jadi "fotonya buram" bikin teknisi motret ulang
    // selamanya buat sesuatu yang nggak akan pernah membaik.
    final service = ApiWorksheetScanService(
      ApiClient(
        client: _Client(422, {
          'message': 'Data yang dikirim nggak valid.',
          'errors': {
            'kualitas.px_per_sel_tinggi': ['harus berupa bilangan bulat'],
          },
        }),
        baseUrl: 'http://contoh.test/api',
      ),
    );

    await expectLater(
      service.kirim('token', const {'template_id': 'ph_meter'}),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
    );
  });
}

class _Client extends http.BaseClient {
  _Client(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().toBytes();

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}
