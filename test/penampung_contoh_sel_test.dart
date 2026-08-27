import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/penampung_contoh_sel.dart';
import 'package:sidik_calibration/services/potong_sel_foto.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';

/// Potongan ditahan dari saat difoto sampai teknisi menekan SIMPAN.
///
/// ## Kenapa penundaan itu inti fiturnya
///
/// Keputusan pemilik lab: yang jadi label itu angka **waktu Simpan ditekan**,
/// bukan yang dibaca OCR sesaat setelah foto.
///
/// Bedanya bukan kerapian. Teknisi memotret, lalu MENGOREKSI angka yang salah
/// baca — dan koreksi itu justru kejadian paling berharga: di situ OCR-nya
/// meleset, dan di situ angka benarnya akhirnya diketik. Disimpan sesaat
/// setelah foto, potongannya dipasangkan dengan bacaan yang SALAH, dan
/// modelnya dilatih buat mengulangi kesalahan yang barusan dibetulkan orang.
///
/// Itu kegagalan yang paling mahal di seluruh fitur ini, karena datanya
/// kelihatan bertambah banyak sementara isinya justru mengajarkan yang keliru.
void main() {
  late Directory folder;
  late SimpananContohSel simpanan;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('penampung_test');
    simpanan = SimpananContohSel(folder);
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  PotonganSel potongan({
    double titikUkur = 100.0,
    int repeatNo = 1,
    String fieldId = 'pembacaan',
    String? teksOcr,
    int warna = 90,
  }) {
    final citra = img.Image(width: 8, height: 8);

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        citra.setPixelRgb(x, y, warna, warna, warna);
      }
    }

    return (
      kotak: (
        titikUkur: titikUkur,
        repeatNo: repeatNo,
        fieldId: fieldId,
        kotak: const Rect.fromLTWH(0, 0, 8, 8),
        teks: teksOcr,
      ),
      potongan: citra,
    );
  }

  test('yang ditahan belum menulis apa pun', () async {
    // Teknisi yang membatalkan lembarnya nggak boleh meninggalkan jejak.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(potongan: [potongan()], lembar: 'ph');

    expect(penampung.jumlah, 1);
    expect((await simpanan.baca()).contoh, isEmpty);
  });

  test('LABELNYA yang saat Simpan, bukan yang dibaca OCR', () async {
    // Inti seluruh berkas ini. OCR membaca `1`, teknisi membetulkannya jadi
    // `7`. Yang boleh jadi label cuma `7`.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(
      potongan: [potongan(teksOcr: '1')],
      lembar: 'ph',
    );

    final hasil = await penampung.serahkan((_) => '7');

    expect(hasil.tersimpan, 1);

    final isi = await simpanan.baca();

    expect(isi.contoh.first.label, '7', reason: 'Angka final teknisi.');
    expect(
      isi.contoh.first.bacaanOcr,
      '1',
      reason:
          'Bacaan OCR yang salah TETAP disimpan — justru itu yang bikin '
          'contohnya berharga: di situ model sekarang gagal.',
    );
  });

  test('sel yang dikosongkan teknisi nggak disimpan, tapi dihitung', () async {
    // Contoh tanpa label nggak bisa melatih apa pun. Dilewat diam-diam,
    // angkanya hilang — padahal banyaknya sel yang dikosongkan itu petunjuk
    // tentang mutu fotonya.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(
      potongan: [
        potongan(repeatNo: 1),
        potongan(repeatNo: 2),
        potongan(repeatNo: 3),
      ],
      lembar: 'ph',
    );

    final hasil = await penampung.serahkan(
      (k) => k.repeatNo == 2 ? null : '5,0',
    );

    expect(hasil.tersimpan, 2);
    expect(hasil.tanpaLabel, 1);
    expect((await simpanan.baca()).contoh, hasLength(2));
  });

  test('label yang isinya spasi doang dihitung tanpa label', () async {
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(potongan: [potongan()], lembar: 'ph');

    final hasil = await penampung.serahkan((_) => '   ');

    expect(hasil.tersimpan, 0);
    expect(hasil.tanpaLabel, 1);
  });

  test(
    'sel yang DIFOTO ULANG: yang lama ditimpa, bukan ikut tersimpan',
    () async {
      // Jepretan kedua dilakukan justru karena yang pertama jelek. Yang lama
      // bukan contoh tambahan — dia contoh yang sudah ditolak teknisinya sendiri.
      final penampung = PenampungContohSel(simpanan);

      penampung.tampung(
        potongan: [potongan(warna: 10, teksOcr: 'buram')],
        lembar: 'ph',
      );
      penampung.tampung(
        potongan: [potongan(warna: 200, teksOcr: 'jelas')],
        lembar: 'ph',
      );

      expect(penampung.jumlah, 1, reason: 'Satu sel, bukan dua.');

      await penampung.serahkan((_) => '3,3');

      final isi = await simpanan.baca();

      expect(isi.contoh, hasLength(1));
      expect(isi.contoh.first.bacaanOcr, 'jelas');

      final citra = img.decodePng(
        await File('${folder.path}/${isi.contoh.first.berkas}').readAsBytes(),
      )!;

      expect(
        citra.getPixel(4, 4).r,
        200,
        reason: 'Citranya juga yang baru, bukan cuma teksnya.',
      );
    },
  );

  test('sel BEDA nggak saling menimpa', () async {
    // Penjaga arah buat test di atas: kunci yang kekasar bikin seluruh tabel
    // menyusut jadi satu contoh, dan itu kelihatan seperti "menimpa yang lama"
    // yang bekerja terlalu baik.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(
      potongan: [
        potongan(titikUkur: 100, repeatNo: 1, fieldId: 'pembacaan'),
        potongan(titikUkur: 100, repeatNo: 1, fieldId: 'suhu'),
        potongan(titikUkur: 100, repeatNo: 2, fieldId: 'pembacaan'),
        potongan(titikUkur: 200, repeatNo: 1, fieldId: 'pembacaan'),
      ],
      lembar: 'viscometer',
    );

    expect(penampung.jumlah, 4);
  });

  test('Simpan ditekan DUA KALI: contohnya nggak dobel', () async {
    // Tampungannya dikosongkan sesudah diserahkan. Tanpa itu, tiap penekanan
    // Simpan menambah satu salinan dari sel yang sama, dan data latihnya penuh
    // duplikat yang bikin model condong ke lembar yang kebetulan disimpan
    // berkali-kali.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(potongan: [potongan()], lembar: 'ph');

    final pertama = await penampung.serahkan((_) => '8,8');
    final kedua = await penampung.serahkan((_) => '8,8');

    expect(pertama.tersimpan, 1);
    expect(kedua.tersimpan, 0);
    expect((await simpanan.baca()).contoh, hasLength(1));
  });

  test('dibuang: nggak ada yang tersimpan, tampungannya kosong', () async {
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(potongan: [potongan()], lembar: 'ph');
    penampung.buang();

    expect(penampung.jumlah, 0);

    final hasil = await penampung.serahkan((_) => '1,0');

    expect(hasil.tersimpan, 0);
    expect((await simpanan.baca()).contoh, isEmpty);
  });

  test('lembarnya ikut tersimpan, buat menyeimbangkan data', () async {
    // Angka suhu dan angka viskositas beda rentang dan beda cara ditulis.
    // Tanpa penanda lembar, data latihnya nggak bisa diseimbangkan.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(potongan: [potongan()], lembar: 'conductivity');
    await penampung.serahkan((_) => '1413');

    expect((await simpanan.baca()).contoh.first.lembar, 'conductivity');
  });

  test('dua jepretan tabel BEDA numpuk, bukan saling buang', () async {
    // Lembar Spektro punya tiga tabel, difoto satu per satu. Jepretan kedua
    // nggak boleh membuang tampungan tabel pertama — kalau itu terjadi, cuma
    // tabel terakhir yang pernah jadi data latih dan nggak ada yang tahu.
    final penampung = PenampungContohSel(simpanan);

    penampung.tampung(potongan: [potongan(titikUkur: 100)], lembar: 'spektro');
    penampung.tampung(potongan: [potongan(titikUkur: 200)], lembar: 'spektro');

    expect(penampung.jumlah, 2);

    final hasil = await penampung.serahkan((_) => '0,5');

    expect(hasil.tersimpan, 2);
  });
}
