import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Hasil baca satu potongan sel.
typedef BacaanSel = ({String? teks, double? keyakinan, bool didalamKotak});

/// Hasil baca satu label tercetak (nomor Repeat) — bukti barisnya nggak geser.
typedef BacaanJangkar = ({
  String fieldId,
  int repeatNo,
  String? teks,
  bool cocok,
});

/// Baca teks tiap potongan sel — **ML Kit on-device**.
///
/// ## Kenapa dibaca PER CROP, bukan sehalaman
///
/// OCR halaman penuh ngasih daftar teks + kotaknya, lalu ada yang harus nebak
/// teks mana masuk sel mana. Tebakan itu persis sumber bug "angka pindah baris"
/// yang bikin seluruh fitur ini dirancang ulang. Baca per crop bikin
/// pertanyaannya nggak pernah muncul: satu crop = satu sel, dan kuncinya udah
/// ditentukan SEBELUM dibaca.
///
/// ## Kenapa on-device
///
/// Foto lembar kerja itu data pelanggan. ML Kit jalan sepenuhnya di HP: nggak
/// ada citra yang keluar dari perangkat, nggak ada biaya per foto, dan jalan
/// tanpa sinyal — lab pelanggan sering nggak ada.
abstract class PembacaSel {
  /// Baca satu potongan. Balikin teks APA ADANYA — termasuk yang jelas ngawur.
  ///
  /// **Jangan dibersihin di sini.** Yang mutusin itu angka atau bukan cuma
  /// server, dan cuma server yang nyimpen jejaknya. `133659` dikirim
  /// `133659`, bukan ditebak jadi `1,33659`.
  Future<BacaanSel> baca(img.Image potongan);

  Future<void> tutup();
}

class MlKitPembacaSel implements PembacaSel {
  MlKitPembacaSel();

  final _pengenal = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    // ML Kit minta berkas atau byte ber-metadata; potongan sel kecil, jadi
    // ditulis ke folder sementara app — BUKAN galeri atau folder bersama.
    // Isinya lembar kerja pelanggan.
    final dir = await getTemporaryDirectory();
    final berkas = File(
      '${dir.path}/sel-${DateTime.now().microsecondsSinceEpoch}.png',
    );

    try {
      await berkas.writeAsBytes(img.encodePng(potongan));

      final hasil = await _pengenal.processImage(InputImage.fromFile(berkas));
      final teks = hasil.text.trim();

      if (teks.isEmpty) {
        return (teks: null, keyakinan: null, didalamKotak: true);
      }

      // Kotak hasil baca duduk di dalam potongannya?
      //
      // Kalau tulisannya nempel di tepi, besar kemungkinan itu coretan dari sel
      // SEBELAH yang ikut kepotong. Server nandain sel begini MERAH, dan itu
      // penjagaan yang bener — angka tetangga yang nyasar nggak kelihatan salah
      // dari angkanya sendiri.
      var didalam = true;
      for (final blok in hasil.blocks) {
        final k = blok.boundingBox;
        if (k.left < 1 ||
            k.top < 1 ||
            k.right > potongan.width - 1 ||
            k.bottom > potongan.height - 1) {
          didalam = false;
          break;
        }
      }

      return (
        teks: teks.replaceAll(RegExp(r'\s+'), ' '),
        // ML Kit Latin nggak ngasih skor per blok di semua versi. Yang nggak
        // ada dikirim `null`, bukan diisi angka karangan — server punya
        // aturannya sendiri buat sel tanpa skor.
        keyakinan: null,
        didalamKotak: didalam,
      );
    } finally {
      if (berkas.existsSync()) berkas.deleteSync();
    }
  }

  @override
  Future<void> tutup() => _pengenal.close();
}

/// Tiruan buat test & mode mock.
///
/// Bacaannya dititipin per kunci sel, jadi test bisa niru "sel ini kebaca
/// `28O`" tanpa ML Kit maupun kamera.
class MockPembacaSel implements PembacaSel {
  MockPembacaSel({this.bacaan = const [], this.didalamKotak = true});

  /// Dibalikin berurutan tiap kali [baca] dipanggil. Habis daftarnya → null
  /// (sel kosong).
  final List<String?> bacaan;
  final bool didalamKotak;

  int _ke = 0;

  /// Berapa kali sel dibaca — dipakai test buat mastiin SEMUA sel template
  /// diproses, bukan cuma yang keisi.
  int get jumlahDibaca => _ke;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    final teks = _ke < bacaan.length ? bacaan[_ke] : null;
    _ke++;

    return (teks: teks, keyakinan: null, didalamKotak: didalamKotak);
  }

  @override
  Future<void> tutup() async {}
}

/// Payload `POST /api/worksheet-scans` yang disusun dari hasil baca.
///
/// Disusun di kelas sendiri supaya bisa diuji tanpa kamera, tanpa ML Kit, dan
/// tanpa server — dan supaya aturan yang paling mahal kalau salah kelihatan di
/// satu tempat:
///
///  - **kunci diambil dari template APA ADANYA**, nggak pernah disusun dari
///    indeks tampilan;
///  - **SEMUA sel template dikirim**, termasuk yang kosong. Sel yang nggak ikut
///    bikin seluruh lembar ditolak — dan sel yang hilang tanpa suara lebih
///    bahaya daripada scan yang ditolak;
///  - **teks dikirim apa adanya**, tanpa dibersihin & tanpa nambah koma.
class PayloadPindai {
  const PayloadPindai();

  /// @param sel  kunci sel → hasil bacanya.
  /// @param kotak kunci sel → kotak di citra WARP (bukan foto mentah).
  Map<String, dynamic> susun({
    required String templateId,
    required int templateVersi,
    required Map<String, BacaanSel> sel,
    required Map<String, ({double x, double y, double w, double h})> kotak,
    required Map<String, ({double titikUkur, int? standardId})> bukti,
    required List<({double x, double y})> marker,
    required double residualPx,
    required ({int w, int h}) ukuranReferensi,
    required ({double blur, double kecerahan, double glare}) mutu,
    required double sudutMiringDeg,
    required int pxPerSelTinggi,
    List<BacaanJangkar> jangkar = const [],
    int? calibrationSessionId,
    int? equipmentId,
    int? jumlahPengulangan,
    String? qrIsi,
    Map<String, String>? perangkat,
  }) {
    return {
      'template_id': templateId,
      'template_versi': templateVersi,
      if (calibrationSessionId case final int id) 'calibration_session_id': id,
      if (equipmentId case final int id) 'equipment_id': id,
      if (jumlahPengulangan case final int n) 'jumlah_pengulangan': n,

      'qr': {'terbaca': qrIsi != null, if (qrIsi case final String isi) 'isi': isi},

      'geometri': {
        'marker': [
          for (var i = 0; i < marker.length; i++)
            {'id': i, 'x': marker[i].x, 'y': marker[i].y},
        ],
        'residual_reproyeksi_px': residualPx,
        'grid_tersnap': true,
        'ukuran_referensi': {
          'w': ukuranReferensi.w,
          'h': ukuranReferensi.h,
        },
      },

      // Angkanya dikirim APA ADANYA, nggak dibulatkan: ambangnya milik server
      // (`config/ocr.php`), dan membulatkan di sini bikin foto yang pas-pasan
      // lolos/ketolak beda dari yang seharusnya.
      //
      // Kecuali `px_per_sel_tinggi`, yang divalidasi server sebagai `integer`
      // (`WorksheetScanRequest`) — pecahan di situ bikin SELURUH kiriman
      // ditolak 422 di lapisan bentuk, sebelum satu sel pun dilihat.
      'kualitas': {
        'blur_laplacian': mutu.blur,
        'kecerahan_rata': mutu.kecerahan,
        'rasio_glare': mutu.glare,
        'sudut_kemiringan_deg': sudutMiringDeg,
        'px_per_sel_tinggi': pxPerSelTinggi,
      },

      if (perangkat case final Map<String, String> p) 'perangkat': p,
      'diambil_pada': DateTime.now().toIso8601String(),

      // SEMUA sel template, termasuk yang kosong & yang nggak kebaca.
      'sel': [
        for (final e in kotak.entries)
          () {
            final bagian = e.key.split('|');
            final baca = sel[e.key];
            final b = bukti[e.key];

            return {
              'tabel_id': bagian[0],
              'baris_ke': int.tryParse(bagian[1]) ?? 0,
              'repeat_no': int.tryParse(bagian[2]) ?? 0,
              'field_id': bagian.length > 3 ? bagian[3] : '',
              'teks_mentah': baca?.teks,
              'confidence_ocr': baca?.keyakinan,
              'kotak_teks_di_dalam_sel': baca?.didalamKotak ?? true,
              'kotak': {
                'x': e.value.x,
                'y': e.value.y,
                'w': e.value.w,
                'h': e.value.h,
              },
              // Bukti pembanding, BUKAN bagian kunci. Kalau nilainya beda dari
              // template, server mbatalin seluruh pemetaan — dan itu memang
              // yang diinginkan.
              if (b != null) 'titik_ukur': b.titikUkur,
              if (b?.standardId case final int id) 'standard_id': id,
              'sumber': 'mlkit',
            };
          }(),
      ],

      // Label Repeat yang tercetak di lembar. Kosong = nggak ada satu pun
      // jangkar yang bisa dibaca, dan server MENOLAK lembarnya karena itu —
      // memang begitu maunya: tanpa jangkar, posisi baris cuma dijamin sama
      // geometri, dan geometri yang meleset satu baris nggak ngasih gejala apa
      // pun.
      if (jangkar.isNotEmpty)
        'sel_jangkar': [
          for (final j in jangkar)
            {
              'field_id': j.fieldId,
              'repeat_no': j.repeatNo,
              'teks_mentah': j.teks,
              'cocok': j.cocok,
            },
        ],
    };
  }
}

/// Byte PNG citra hasil warp — dilampirkan sebagai `citra_warp`.
///
/// Lampiran audit: boleh gagal naik tanpa mbatalin hasil pindai. Sinyal
/// lapangan sering lemah, dan nolak hasil baca gara-gara fotonya gagal naik itu
/// ngorbanin kerjaan teknisi demi arsip.
Uint8List pngDari(img.Image citra) => img.encodePng(citra);
