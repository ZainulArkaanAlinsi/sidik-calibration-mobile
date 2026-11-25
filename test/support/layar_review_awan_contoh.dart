import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/services/ocr_awan_sel_service.dart';
import 'package:sidik_calibration/services/saran_ocr_awan.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

import 'potongan_sel_contoh.dart';

/// Layar review PALSU untuk tes usulan OCR awan: empat sel angka dengan nasib
/// berbeda di sisi awan. Angka dan kunci karangan tes; bukan data pelanggan dan
/// bukan bukti akurasi.
///
/// - A: dibaca HP merah (kosong), awan memberi usulan kuning 4,01.
/// - B: dibaca HP kuning 7,00, awan memberi usulan kuning 7,02 (beda).
/// - C: dibaca HP merah (kosong), awan melihat sel KOSONG.
/// - D: dibaca HP merah (kosong), awan membaca sampah `l0,0` (merah).
const kunciA = 'tabel_ph|1|1|pembacaan';
const kunciB = 'tabel_ph|2|1|pembacaan';
const kunciC = 'tabel_ph|2|2|pembacaan';
const kunciD = 'tabel_ph|3|1|pembacaan';

const konteksContoh = KonteksOcrAwanSel(
  templateId: 'ph_meter_0515',
  kodeDokumen: 'F-0515',
);

const kunciAngkaContoh = {kunciA, kunciB, kunciC, kunciD};

BarisReviewFoto _baris(
  double titik,
  int repeat,
  int barisKe,
  String judul,
  String teks,
  double keyakinan,
) => (
  titikUkur: titik,
  repeatNo: repeat,
  fieldId: 'tabel_ph@@$barisKe@@pembacaan',
  judul: judul,
  teks: teks,
  keyakinan: keyakinan,
  vonis: NilaiVonisFoto.dari(keyakinan),
  potongan: potonganNyata(),
);

List<BarisReviewFoto> barisReviewContoh() => [
  _baris(4, 1, 1, 'Set Point 4,00 · Ulangan 1', '4,0', 0.30),
  _baris(7, 1, 2, 'Set Point 7,00 · Ulangan 1', '7,00', 0.82),
  _baris(7, 2, 2, 'Set Point 7,00 · Ulangan 2', '', 0.20),
  _baris(10, 1, 3, 'Set Point 10,00 · Ulangan 1', '1', 0.25),
];

/// Kunci baris review -> kunci templat server, persis yang diisi
/// `pindai_formulir_asli_flow.dart` dari `SelTemplateAsli.kunci`.
Map<String, String> kunciServerContoh(List<BarisReviewFoto> baris) {
  const urutan = [kunciA, kunciB, kunciC, kunciD];

  return {
    for (var i = 0; i < baris.length; i++)
      kunciSelFoto(baris[i].titikUkur, baris[i].repeatNo, baris[i].fieldId):
          urutan[i],
  };
}

HasilOcrAwan hasilAwanContoh() => HasilOcrAwan(
  hasil: [
    SelOcrAwan.dariJson({
      'kunci': kunciA,
      'status': 'kuning',
      'teks_awan': '4.01',
      'teks_normal': '4,01',
      'nilai_awan': 4.01,
      'dinormalkan': true,
      'alasan': <String>[],
    })!,
    SelOcrAwan.dariJson({
      'kunci': kunciB,
      'status': 'kuning',
      'teks_awan': '7,02',
      'teks_normal': '7,02',
      'nilai_awan': 7.02,
      'dinormalkan': false,
      'alasan': ['jauh_dari_repeat_lain'],
    })!,
    SelOcrAwan.dariJson({
      'kunci': kunciC,
      'status': 'kosong',
      'teks_awan': '',
    })!,
    SelOcrAwan.dariJson({
      'kunci': kunciD,
      'status': 'merah',
      'teks_awan': 'l0,0',
      'alasan': ['karakter_di_luar_whitelist'],
    })!,
  ],
  dilewati: const [],
  meta: const MetaOcrAwan(jumlahDikirim: 4, jumlahPanggilan: 1),
);

/// Penjalur tanpa jeda sungguhan dan tanpa token nyata.
PenjalurSaranAwan penjalurContoh(OcrAwanSelService service) =>
    PenjalurSaranAwan(
      service: service,
      bacaToken: () async => 'token-uji',
      nyala: () => true,
      tidur: (_) async {},
    );

/// Sama dengan penutup yang dirakit `pindai_formulir_asli_flow.dart`.
PemintaUsulanAwan pemintaContoh(
  PenjalurSaranAwan penjalur,
  List<BarisReviewFoto> baris,
) {
  final peta = kunciServerContoh(baris);

  return ({onKemajuan, dibatalkan}) => penjalur.minta(
    konteks: konteksContoh,
    kandidat: pilihKandidatAwan(
      kunciAngka: kunciAngkaContoh,
      baris: baris,
      kunciServerPerBaris: peta,
    ),
    onKemajuan: onKemajuan,
    dibatalkan: dibatalkan,
  );
}
