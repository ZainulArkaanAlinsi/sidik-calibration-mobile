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
  ///
  /// Baliknya `peringatan` dari server, atau `null` kalau emailnya beneran
  /// keluar. Isinya kejadian yang **sukses tapi nggak nyampe** — mis. server
  /// masih pakai `MAIL_MAILER=log`, yang nulis email ke berkas log dan nggak
  /// pernah gagal. Tanpa ini layar bakal bilang "Email terkirim" buat email
  /// yang nggak pernah keluar, dan admin nungguin balasan yang nggak ada.
  Future<String?> kirim(String token, int certificateId, KirimEmailPermintaan isi);

  /// Catat pengiriman lewat WhatsApp & ambil teks siap-tempelnya.
  ///
  /// Server nggak ngirim pesannya — yang ngirim aplikasi WhatsApp di HP admin.
  /// Endpoint ini nyatet jejaknya (kapan, ke nomor mana, sama siapa), karena
  /// itu yang ditanya waktu pelanggan ngaku nggak nerima, dan jejak yang cuma
  /// ada di HP satu orang nggak bisa mbuktiin apa-apa.
  Future<HasilCatatWhatsapp> catatWhatsapp(
    String token,
    int certificateId, {
    required List<String> ke,
    FormatKirim format = FormatKirim.tautan,
  });

  /// Semua percobaan, **termasuk yang gagal**.
  Future<List<PercobaanEmail>> riwayat(String token, int certificateId);
}

class ApiKirimEmailService implements KirimEmailService {
  ApiKirimEmailService(this._api);

  final ApiClient _api;

  @override
  Future<String?> kirim(
    String token,
    int certificateId,
    KirimEmailPermintaan isi,
  ) async {
    final json = await _api.post(
      '/certificates/$certificateId/kirim-email',
      token: token,
      body: isi.toJson(),
      // Sinkron sampai email keluar — SMTP yang lemot gampang lewat 20 detik
      // bawaan, dan timeout di sisi kita bikin admin ngira gagal padahal
      // servernya masih ngirim.
      timeout: const Duration(seconds: 60),
    );

    // Server lama nggak ngirim field ini — dianggep beneran terkirim, persis
    // kayak perilaku sebelumnya.
    final peringatan = json['peringatan'];
    if (peringatan is! String) return null;

    final teks = peringatan.trim();
    return teks.isEmpty ? null : teks;
  }

  @override
  Future<HasilCatatWhatsapp> catatWhatsapp(
    String token,
    int certificateId, {
    required List<String> ke,
    FormatKirim format = FormatKirim.tautan,
  }) async {
    final json = await _api.post(
      '/certificates/$certificateId/catat-whatsapp',
      token: token,
      body: {'ke': ke, 'format': format.kode},
    );

    return HasilCatatWhatsapp.fromJson(json);
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
  MockKirimEmailService({this.gagalKirim = false, this.peringatan});

  /// Meniru `502` — server nerima permintaannya tapi email nggak keluar.
  final bool gagalKirim;

  /// Meniru sukses-tapi-nggak-nyampe (`MAIL_MAILER=log` di server).
  final String? peringatan;

  final List<PercobaanEmail> _riwayat = [];

  @override
  Future<String?> kirim(
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
        format: isi.format,
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

    return peringatan;
  }

  @override
  Future<HasilCatatWhatsapp> catatWhatsapp(
    String token,
    int certificateId, {
    required List<String> ke,
    FormatKirim format = FormatKirim.tautan,
  }) async {
    _riwayat.insert(
      0,
      PercobaanEmail(
        id: _riwayat.length + 1,
        ke: ke,
        cc: const [],
        format: FormatKirim.whatsapp,
        berhasil: true,
        waktu: DateTime(2026, 7, 29, 11, _riwayat.length),
        oleh: 'Budi Santoso',
      ),
    );

    return const HasilCatatWhatsapp(pesan: 'Sertifikat Kalibrasi CAL/2026/07/0001');
  }

  @override
  Future<List<PercobaanEmail>> riwayat(String token, int certificateId) async =>
      List.unmodifiable(_riwayat);
}
