import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/pembaca_qr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pindai_lembar.dart';

/// Uji **DI PERANGKAT** — ML Kit yang beneran, bukan tiruannya.
///
/// ## Kenapa kepisah dari `flutter test`
///
/// `google_mlkit_text_recognition` & `google_mlkit_barcode_scanning` modelnya
/// hidup di sisi native. Di `flutter test` (Dart murni, tanpa perangkat)
/// dua-duanya nggak bisa dipanggil sama sekali, jadi seluruh test lain
/// terpaksa memakai pembaca tiruan. Yang nggak pernah kebuktikan di situ dua
/// hal, dan dua-duanya menentukan fiturnya jalan atau nggak:
///
///  1. **QR versi lembar kebaca dari citranya.** Server nolak seluruh pindai
///     kalau `qr.terbaca` bukan `true` — kalau ML Kit nggak nemu QR-nya di
///     lembar yang kita cetak sendiri, nggak ada satu pun pindai yang bakal
///     lolos, dan gejalanya cuma "QR nggak kebaca" di HP teknisi.
///  2. **Label Repeat (`X1..X5`) kebaca dari kotak jangkarnya.** Jangkar itu
///     penjagaan geser-satu-baris satu-satunya yang membaca isi. Kalau
///     labelnya nggak kebaca, `cocok: false`, dan lembar yang BENAR ditolak.
///
/// Jalanin:
///
/// ```
/// flutter test integration_test/pindai_hp_test.dart -d <id-perangkat>
/// ```
///
/// ## Yang MASIH belum diuji di sini
///
/// Ketajaman ML Kit pada **tulisan tangan** — itu butuh lembar yang beneran
/// diisi teknisi lalu difoto, dan hasilnya bukan lulus/gagal tapi angka
/// akurasi per kolom (`php artisan ocr:akurasi` di sisi server). Yang dijaga
/// di sini cuma yang TERCETAK, dan itu memang yang harus 100%.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late img.Image jepretan;
  late WorksheetTemplate template;

  setUpAll(() async {
    final png = await rootBundle.load(
      'test/assets/lembar-conductivity-v1.png',
    );
    final cetakan = img.decodePng(png.buffer.asUint8List())!;

    // Lembarnya dibikin mirip JEPRETAN dulu: berkas rendernya putih 255 pekat
    // (kecerahan rata-rata 247), di atas ambang server 225 — dipakai apa
    // adanya, dia ditolak gerbang mutu sebagai "terlalu terang" sebelum ML Kit
    // sempat kepanggil.
    for (var y = 0; y < cetakan.height; y++) {
      for (var x = 0; x < cetakan.width; x++) {
        final p = cetakan.getPixel(x, y);
        cetakan.setPixelRgb(
          x,
          y,
          (p.r * 0.62).round(),
          (p.g * 0.62).round(),
          (p.b * 0.62).round(),
        );
      }
    }

    jepretan = cetakan;

    final geometri =
        jsonDecode(
              await rootBundle.loadString(
                'test/assets/geometri-conductivity-v1.json',
              ),
            )
            as Map<String, dynamic>;

    final sel = <String, dynamic>{};
    final tabel = <Map<String, dynamic>>[];

    for (final t in geometri['tabel'] as List<dynamic>) {
      final m = t as Map<String, dynamic>;
      sel.addAll(m['sel'] as Map<String, dynamic>);

      tabel.add({
        'tabel_id': m['tabel_id'],
        'judul': m['judul'],
        'baris': [
          for (var i = 1; i <= 4; i++)
            {'baris_ke': i, 'titik_ukur': 25.0 * i, 'standard_id': i},
        ],
        'kolom': [
          {'field_id': 'pembacaan', 'label': 'Reading'},
          {'field_id': 'suhu', 'label': '°C'},
        ],
        'pengulangan': [1, 2, 3, 4, 5],
      });
    }

    template = WorksheetTemplate.fromJson({
      'template_id': geometri['template_id'],
      'versi': geometri['versi'],
      'kode_dokumen': geometri['kode_dokumen'],
      'judul': 'Calibration Worksheet - Conductivity Meter',
      'siap_pindai': true,
      'tabel': tabel,
      'sel': sel,
      'jangkar': geometri['jangkar'],
      'geometri': geometri,
    });
  });

  testWidgets('ML Kit baca QR versi lembar dari lembar cetaknya sendiri', (
    tester,
  ) async {
    final mesin = const PindaiLembar();
    final marker = mesin.cariMarker(jepretan);

    expect(marker, isNotNull, reason: 'Marker sudut nggak ketemu.');

    final warp = mesin.warp(
      jepretan,
      marker!,
      lebar: template.ukuranReferensi!.w,
      tinggi: template.ukuranReferensi!.h,
      tujuan: [for (final m in template.marker) (x: m.x, y: m.y)],
    );

    final pembaca = MlKitPembacaQr();

    try {
      expect(await pembaca.baca(warp.citra), template.qrIsi);
    } finally {
      await pembaca.tutup();
    }
  });

  testWidgets('ML Kit baca label Repeat di kotak jangkarnya', (tester) async {
    // Yang dipotong CUMA kotak jangkarnya, bukan seluruh 80 sel: sel lembar
    // cetak kosong semua, jadi mengOCR-nya cuma nambah menit tanpa nambah
    // bukti — dan yang belum kebuktikan justru labelnya.
    final mesin = const PindaiLembar();
    final marker = mesin.cariMarker(jepretan)!;
    final warp = mesin.warp(
      jepretan,
      marker,
      lebar: template.ukuranReferensi!.w,
      tinggi: template.ukuranReferensi!.h,
      tujuan: [for (final m in template.marker) (x: m.x, y: m.y)],
    );

    final pembaca = MlKitPembacaSel();
    final kebaca = <int, String?>{};

    try {
      for (final j in template.jangkar) {
        expect(
          j.bisaDibaca,
          isTrue,
          reason: 'Kotak jangkar ${j.teks} ukurannya nol.',
        );

        final hasil = await pembaca.baca(
          mesin.potongSel(
            warp.citra,
            x: j.kotak.x,
            y: j.kotak.y,
            w: j.kotak.w,
            h: j.kotak.h,
          ),
        );

        kebaca[j.repeatNo] = hasil.teks;
      }
    } finally {
      await pembaca.tutup();
    }

    // Semua label tercetak WAJIB cocok. Ini bukan target optimistis: yang
    // dibaca teks CETAK di kotak yang koordinatnya kita sendiri yang gambar —
    // satu saja meleset, tiap lembar yang dipindai teknisi ditolak servernya.
    expect(
      kebaca,
      {for (final j in template.jangkar) j.repeatNo: j.teks},
      reason: 'Label Repeat yang kebaca beda dari yang tercetak.',
    );
  });
}
