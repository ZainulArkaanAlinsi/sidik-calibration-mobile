import 'package:sidik_calibration/models/worksheet_template.dart';

/// Kunci `asli` persis seperti respons nyata kontrak
/// (`perintah-frontend-templat-asli.md` §1, `OCR_FORMULIR_ASLI_UJI=true`).
/// Bawaannya = jenis yang BOLEH dipindai (mode uji, revisi 4).
Map<String, dynamic> asliKontrak({
  bool ada = true,
  String kode = 'SIDIK-FM-CAL-0509',
  String? revisi = '4',
  bool siap = false,
  bool uji = true,
  bool konfirmasi = false,
}) => {
  'ada': ada,
  'kode_dokumen': ada ? kode : null,
  'revisi': revisi,
  'siap_pindai': siap,
  'mode_uji': uji,
  'perlu_konfirmasi_lab': konfirmasi,
};

/// Satu entri `GET /worksheet-templates` (tujuh kunci lama + `asli` di ujung).
/// [asli] = `null` berarti kuncinya ada tapi nilainya null; [tanpaKunciAsli]
/// = server/APK lama yang tidak mengirim kuncinya sama sekali.
WorksheetTemplate entriDaftar(
  String id, {
  String nama = 'pH Meter',
  String kode = 'SIDIK-FM-CAL-0509',
  Object? asli = 'bawaan',
  bool tanpaKunciAsli = false,
}) => WorksheetTemplate.fromJson({
  'template_id': id,
  'versi': 1,
  'kode_dokumen': '${kode}_Rev.4',
  'judul': 'Calibration Worksheet - $nama',
  'jumlah_sel': 60,
  'siap_pindai': true,
  'alasan_belum_siap': null,
  if (!tanpaKunciAsli)
    'asli': asli == 'bawaan' ? asliKontrak(kode: kode) : asli,
});
