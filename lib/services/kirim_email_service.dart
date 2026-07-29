import '../core/utils/parse_list.dart';
import '../models/kirim_email.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Kirim sertifikat ke email pelanggan — **admin doang**.
abstract class KirimEmailService {
  /// **Sinkron**: balik sesudah email beneran keluar, bukan sesudah masuk
  /// antrean. Itu disengaja backend — kiriman yang di-queue lalu gagal
  /// diam-diam berarti pelanggan nggak pernah nerima dan nggak ada yang sadar.
  /// Konsekuensinya di layar: butuh loading yang jelas, bukan snackbar kilat.
  ///
  /// Lempar [ApiException] `502` kalau gagal kirim. **Percobaannya TETAP
  /// tercatat** di riwayat — jadi jangan diperlakukan sebagai "nggak terjadi
  /// apa-apa"; riwayatnya wajib dimuat ulang sesudah gagal, sama kayak sesudah
  /// berhasil.
  Future<void> kirim(String token, int certificateId, KirimEmailPermintaan isi);

  /// Semua percobaan, **termasuk yang gagal**.
  Future<List<PercobaanEmail>> riwayat(String token, int certificateId);
}

class ApiKirimEmailService implements KirimEmailService {
  ApiKirimEmailService(this._api);

  final ApiClient _api;

  @override
  Future<void> kirim(
    String token,
    int certificateId,
    KirimEmailPermintaan isi,
  ) async {
    await _api.post(
      '/certificates/$certificateId/kirim-email',
      token: token,
      body: isi.toJson(),
      // Sinkron sampai email keluar — SMTP yang lemot gampang lewat 20 detik
      // bawaan, dan timeout di sisi kita bikin admin ngira gagal padahal
      // servernya masih ngirim.
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<List<PercobaanEmail>> riwayat(
    String token,
    int certificateId,
  ) async {
    final json = await _api.get(
      '/certificates/$certificateId/riwayat-email',
      token: token,
    );
    final data = json['data'] ?? json['riwayat'];

    return parseListAman(data, PercobaanEmail.fromJson);
  }
}

/// Versi in-memory buat mode mock & widget test.
class MockKirimEmailService implements KirimEmailService {
  MockKirimEmailService({this.gagalKirim = false});

  /// Meniru `502` — server nerima permintaannya tapi email nggak keluar.
  final bool gagalKirim;

  final List<PercobaanEmail> _riwayat = [];

  @override
  Future<void> kirim(
    String token,
    int certificateId,
    KirimEmailPermintaan isi,
  ) async {
    // Percobaannya dicatat DULU, baru dilempar errornya — meniru perilaku
    // backend: yang gagal tetap masuk riwayat.
    _riwayat.insert(
      0,
      PercobaanEmail(
        id: _riwayat.length + 1,
        ke: isi.ke,
        cc: isi.cc,
        berhasil: !gagalKirim,
        error: gagalKirim ? 'SMTP nolak: mailbox penuh.' : null,
        waktu: DateTime(2026, 7, 28, 10, _riwayat.length),
        oleh: 'Budi Santoso',
      ),
    );

    if (gagalKirim) {
      throw ApiException(
        'Email gagal dikirim. Percobaan ini tetap tercatat di riwayat.',
        status: 502,
        body: const {},
      );
    }
  }

  @override
  Future<List<PercobaanEmail>> riwayat(String token, int certificateId) async =>
      List.unmodifiable(_riwayat);
}
