import 'dart:typed_data';

import '../models/worksheet_scan.dart';
import '../models/worksheet_template.dart';
import 'api_client.dart';

/// Jalur **pindai lembar kerja (OCR lokal)** — `docs/SPEC-ocr-template-lokal.md`
/// di repo API.
///
/// Tiga hal yang bikin jalur ini beda dari AI Vision yang lama, dan ketiganya
/// dijaga di sini:
///
///  1. **Fotonya nggak keluar dari HP.** Yang dikirim hasil BACANYA (teks per
///     sel + skor + kotak), bukan citranya; citra cuma lampiran audit dan boleh
///     gagal naik tanpa mbatalin hasil pindai.
///  2. **Kunci sel diambil dari template apa adanya.** HP nggak pernah nyusun
///     kunci dari indeks tampilan — kiriman berkunci asing bikin satu lembar
///     penuh ditolak, dan kunci karangan bisa mendaratkan angka di sel yang
///     salah tanpa error.
///  3. **Hasil pindai itu USULAN.** Nyimpen hasil kalibrasi tetap lewat
///     `POST`/`PUT /api/calibrations`; endpoint pindai nggak pernah bikin
///     `raw_measurements`.
abstract class WorksheetScanService {
  /// Daftar lembar kerja yang dikenal sistem, berikut `siap_pindai`-nya.
  Future<List<WorksheetTemplate>> daftarTemplate(String token);

  /// Bentuk + geometri satu lembar. [equipmentId] dikirim kalau alatnya udah
  /// dipilih: satuan, resolusi, dan desimal per baris lahir dari alat
  /// pelanggan, dan tanpa itu ketiganya balik `null`.
  Future<WorksheetTemplate> template(
    String token,
    String kode, {
    int? equipmentId,
    int? jumlahPengulangan,
  });

  /// Kirim hasil baca satu lembar — `POST /api/worksheet-scans`.
  ///
  /// [body] disusun `PayloadPindai.susun()`, dan dikirim APA ADANYA. Jangan
  /// disunting di sini: kunci selnya milik template, dan satu kunci yang
  /// diubah bikin seluruh lembar ditolak server.
  Future<HasilPindai> kirim(String token, Map<String, dynamic> body);

  /// Hasil pindai yang udah tersimpan — buat layar review yang dibuka lagi.
  Future<HasilPindai> ambilHasil(String token, int scanId);

  /// Dipanggil waktu teknisi nekan "Pakai Angka Ini".
  ///
  /// Kirim **semua** sel, termasuk yang bacanya udah bener dan nggak diubah:
  /// ini satu-satunya sumber data akurasi sistem. Sel yang dilewat berarti
  /// nggak ada bukti bacanya bener, dan sel hijau yang salah nggak akan pernah
  /// ketahuan.
  Future<void> kirimKoreksi(String token, int scanId, List<KoreksiSel> koreksi);

  /// Potongan citra satu sel, JPEG mentah.
  ///
  /// Ditarik lewat [ApiClient.ambilBytes], bukan `Image.network`: endpointnya
  /// di balik auth dan `Image.network` nggak bawa header `Authorization`.
  ///
  /// Balasannya `Cache-Control: private` dan berisi data pelanggan — boleh
  /// nempel di memori selama layar hidup, **jangan** ditulis ke penyimpanan
  /// bersama, galeri, atau folder yang ikut ter-backup ke cloud.
  Future<Uint8List?> cropSel(String token, int scanId, String kunci);

  /// URL potongan citra satu sel — dipakai layar review buat mbandingin angka
  /// bacaan mesin sama coretan aslinya di layar yang sama.
  ///
  /// `|` di kunci WAJIB di-URL-encode.
  String urlCrop(int scanId, String kunci);
}

class ApiWorksheetScanService implements WorksheetScanService {
  ApiWorksheetScanService(this._api);

  final ApiClient _api;

  @override
  Future<List<WorksheetTemplate>> daftarTemplate(String token) async {
    final json = await _api.get('/worksheet-templates', token: token);
    final data = json['data'] as List<dynamic>? ?? const [];

    return [
      for (final t in data)
        if (t is Map<String, dynamic>) WorksheetTemplate.fromJson(t),
    ];
  }

  @override
  Future<WorksheetTemplate> template(
    String token,
    String kode, {
    int? equipmentId,
    int? jumlahPengulangan,
  }) async {
    final q = <String>[
      if (equipmentId != null) 'equipment_id=$equipmentId',
      if (jumlahPengulangan != null) 'jumlah_pengulangan=$jumlahPengulangan',
    ];
    final json = await _api.get(
      '/worksheet-templates/$kode${q.isEmpty ? '' : '?${q.join('&')}'}',
      token: token,
    );

    return WorksheetTemplate.fromJson(json);
  }

  @override
  Future<HasilPindai> kirim(String token, Map<String, dynamic> body) async {
    // Batas waktunya dilonggarkan: bodinya membawa 80+ sel berikut kotak &
    // buktinya, dan server masih menilai mutu foto sebelum menjawab.
    final json = await _api.post(
      '/worksheet-scans',
      body: body,
      token: token,
      timeout: const Duration(seconds: 60),
    );

    return HasilPindai.fromJson(json);
  }

  @override
  Future<HasilPindai> ambilHasil(String token, int scanId) async {
    final json = await _api.get('/worksheet-scans/$scanId', token: token);

    return HasilPindai.fromJson(json);
  }

  @override
  Future<void> kirimKoreksi(
    String token,
    int scanId,
    List<KoreksiSel> koreksi,
  ) async {
    await _api.post(
      '/worksheet-scans/$scanId/koreksi',
      token: token,
      body: {'koreksi': [for (final k in koreksi) k.toJson()]},
    );
  }

  @override
  Future<Uint8List?> cropSel(String token, int scanId, String kunci) =>
      _api.ambilBytes(urlCrop(scanId, kunci), token: token);

  @override
  String urlCrop(int scanId, String kunci) =>
      '/worksheet-scans/$scanId/sel/${Uri.encodeComponent(kunci)}/crop';
}

/// Tiruan buat test & mode mock.
///
/// Bawaannya nirukan keadaan SEKARANG di server: keenam lembar
/// `siap_pindai: false` karena geometri selnya belum diukur dari formulir cetak
/// asli. Itu bukan kekurangan mock — itu keadaan yang wajib kehandle layar,
/// dan yang paling gampang kelewat kalau mock-nya optimistis.
class MockWorksheetScanService implements WorksheetScanService {
  MockWorksheetScanService({this.siapPindai = false, this.hasil, this.crop});

  /// Byte potongan sel yang dibalikin [cropSel]. `null` = server belum punya
  /// citranya (citra audit boleh gagal naik tanpa mbatalin hasil pindai).
  final Uint8List? crop;

  final bool siapPindai;

  /// Hasil yang dibalikin [ambilHasil]. Dititipin test dari respons ASLI —
  /// nggak dikarang di sini.
  final HasilPindai? hasil;

  final List<List<KoreksiSel>> koreksiTerkirim = [];

  Map<String, dynamic> _template(String kode) => {
    'template_id': kode,
    'versi': 1,
    'kode_dokumen': 'SIDIK-IK-CAL-0508_Rev.4',
    'judul': 'Calibration Worksheet - Spectrophotometer',
    'siap_pindai': siapPindai,
    'alasan_belum_siap': siapPindai ? null : 'geometri_belum_diverifikasi',
    'tabel': <Map<String, dynamic>>[],
    'sel': <String, dynamic>{},
  };

  @override
  Future<List<WorksheetTemplate>> daftarTemplate(String token) async => [
    WorksheetTemplate.fromJson(_template('spectrophotometer')),
  ];

  @override
  Future<WorksheetTemplate> template(
    String token,
    String kode, {
    int? equipmentId,
    int? jumlahPengulangan,
  }) async => WorksheetTemplate.fromJson(_template(kode));

  /// Bodi yang dikirim [kirim] — dipegang biar test bisa memeriksanya tanpa
  /// jaringan.
  final List<Map<String, dynamic>> terkirim = [];

  @override
  Future<HasilPindai> kirim(String token, Map<String, dynamic> body) async {
    terkirim.add(body);

    return ambilHasil(token, 0);
  }

  @override
  Future<HasilPindai> ambilHasil(String token, int scanId) async {
    final h = hasil;
    if (h == null) throw Exception('belum ada hasil pindai');

    return h;
  }

  @override
  Future<void> kirimKoreksi(
    String token,
    int scanId,
    List<KoreksiSel> koreksi,
  ) async {
    koreksiTerkirim.add(koreksi);
  }

  @override
  Future<Uint8List?> cropSel(String token, int scanId, String kunci) async =>
      crop;

  @override
  String urlCrop(int scanId, String kunci) =>
      '/worksheet-scans/$scanId/sel/${Uri.encodeComponent(kunci)}/crop';
}
