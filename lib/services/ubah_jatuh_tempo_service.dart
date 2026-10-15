import 'api_client.dart';

/// Hasil `POST /equipments/{id}/jatuh-tempo` (kontrak-api §15).
///
/// [jalur] menentukan arti jawabannya: `jadwal_alat` (200) = hanya jadwal alat
/// yang berubah; `revisi_sertifikat` (202) = dibuat revisi `-R<n>` karena
/// tanggal tercetak berubah. Dibaca dari `jalur`, bukan dari kode HTTP.
class HasilUbahJatuhTempo {
  const HasilUbahJatuhTempo({
    required this.jalur,
    this.pesan,
    this.nomorRevisi,
  });

  final String jalur;
  final String? pesan;
  final String? nomorRevisi;

  bool get revisiSertifikat => jalur == 'revisi_sertifikat';

  factory HasilUbahJatuhTempo.fromJson(Map<String, dynamic> json) {
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    return HasilUbahJatuhTempo(
      jalur: json['jalur'] as String? ?? 'jadwal_alat',
      pesan: json['message'] as String?,
      nomorRevisi: sertifikat?['nomor'] as String?,
    );
  }
}

abstract class UbahJatuhTempoService {
  Future<HasilUbahJatuhTempo> ubah(
    String token,
    int alatId, {
    required DateTime tanggal,
    required String alasan,
  });
}

class ApiUbahJatuhTempoService implements UbahJatuhTempoService {
  ApiUbahJatuhTempoService(this._api);

  final ApiClient _api;

  @override
  Future<HasilUbahJatuhTempo> ubah(
    String token,
    int alatId, {
    required DateTime tanggal,
    required String alasan,
  }) async {
    final json = await _api.post(
      '/equipments/$alatId/jatuh-tempo',
      token: token,
      body: {
        'tanggal_jatuh_tempo': formatTanggalApi(tanggal),
        'alasan': alasan.trim(),
      },
    );
    return HasilUbahJatuhTempo.fromJson(json);
  }
}

/// `Y-m-d` tanpa zona waktu, sesuai validasi server `date_format:Y-m-d`.
String formatTanggalApi(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

class MockUbahJatuhTempoService implements UbahJatuhTempoService {
  MockUbahJatuhTempoService({this.revisi = false});

  final bool revisi;
  final panggilan = <({int id, String tanggal, String alasan})>[];

  @override
  Future<HasilUbahJatuhTempo> ubah(
    String token,
    int alatId, {
    required DateTime tanggal,
    required String alasan,
  }) async {
    panggilan.add((
      id: alatId,
      tanggal: formatTanggalApi(tanggal),
      alasan: alasan.trim(),
    ));
    return revisi
        ? const HasilUbahJatuhTempo(
            jalur: 'revisi_sertifikat',
            nomorRevisi: '012-CAL-524-R1',
          )
        : const HasilUbahJatuhTempo(jalur: 'jadwal_alat');
  }
}
