import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/usulan_ocr_awan.dart';

/// Papan usulan PALSU untuk tes layar usulan OCR awan dan PNG persetujuan.
/// Angka dan kunci karangan tes; bukan data pelanggan dan bukan bukti akurasi.
const kunciDuaBentuk = 'tabel_ph|1|1|pembacaan';
const kunciSatuBentuk = 'tabel_ph|2|1|pembacaan';
const kunciBeralasan = 'tabel_ph|3|1|pembacaan';
const kunciMerah = 'tabel_ph|4|1|pembacaan';
const kunciKosong = 'tabel_ph|5|1|pembacaan';

const _label = <String, String>{
  kunciDuaBentuk: 'Set Point 4,00 · Ulangan 1',
  kunciSatuBentuk: 'Set Point 7,00 · Ulangan 1',
  kunciBeralasan: 'Set Point 7,00 · Ulangan 2',
  kunciMerah: 'Set Point 10,00 · Ulangan 1',
  kunciKosong: 'Set Point 10,00 · Ulangan 2',
};

String labelSelContoh(String kunci) => _label[kunci] ?? 'Sel tanpa nama';

PapanUsulanAwan papanUsulanContoh() => PapanUsulanAwan.dari(
  HasilOcrAwan(
    hasil: [
      SelOcrAwan.dariJson({
        'kunci': kunciDuaBentuk,
        'status': 'kuning',
        'teks_awan': '4.01',
        'teks_normal': '4,01',
        'nilai_awan': 4.01,
        'dinormalkan': true,
        'alasan': <String>[],
      })!,
      SelOcrAwan.dariJson({
        'kunci': kunciSatuBentuk,
        'status': 'kuning',
        'teks_awan': '7,02',
        'teks_normal': '7,02',
        'nilai_awan': 7.02,
        'dinormalkan': false,
        'alasan': <String>[],
      })!,
      SelOcrAwan.dariJson({
        'kunci': kunciBeralasan,
        'status': 'kuning',
        'teks_awan': '7,40',
        'teks_normal': '7,40',
        'nilai_awan': 7.4,
        'dinormalkan': false,
        'alasan': ['jauh_dari_repeat_lain'],
      })!,
      SelOcrAwan.dariJson({
        'kunci': kunciMerah,
        'status': 'merah',
        'teks_awan': 'l0,0',
        'alasan': ['karakter_di_luar_whitelist'],
      })!,
      SelOcrAwan.dariJson({
        'kunci': kunciKosong,
        'status': 'kosong',
        'teks_awan': '',
      })!,
    ],
    dilewati: const [
      SelDilewatiAwan(kunci: 'tabel_ph|6|1|pembacaan', alasan: 'google_gagal'),
      SelDilewatiAwan(kunci: 'tabel_ph|6|2|pembacaan', alasan: 'google_gagal'),
    ],
    meta: const MetaOcrAwan(sebagian: true),
  ),
);
