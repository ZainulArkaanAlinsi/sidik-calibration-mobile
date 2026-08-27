import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/potong_sel_foto.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';

/// Simpanan contoh latih di HP — mesin pengumpul data model sendiri.
///
/// ## Kenapa ini penting dijaga
///
/// Contoh latih yang hilang diam-diam nggak kelihatan sampai berbulan-bulan
/// kemudian, waktu modelnya dilatih dan ternyata datanya cuma separuh dari
/// yang dikira. Nggak ada pesan error, nggak ada yang merah — cuma model yang
/// lebih jelek daripada seharusnya, dan nggak ada yang tahu kenapa.
///
/// Tiga cara data bisa hilang diam-diam, dan tiga-tiganya dijaga di sini:
///
///  1. dua sel dari foto yang sama menimpa berkas yang sama;
///  2. baris indeks yang rusak dilewat tanpa dihitung;
///  3. pemangkasan menghapus berkas tapi meninggalkan barisnya di indeks —
///     `baca()` memulangkan contoh yang citranya sudah nggak ada.
void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('contoh_sel_test');
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  PotonganSel potongan({String fieldId = 'pembacaan', int warna = 90}) {
    final citra = img.Image(width: 8, height: 8);

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        citra.setPixelRgb(x, y, warna, warna, warna);
      }
    }

    return (
      kotak: (
        titikUkur: 100.0,
        repeatNo: 1,
        fieldId: fieldId,
        kotak: const Rect.fromLTWH(0, 0, 8, 8),
        teks: null,
      ),
      potongan: citra,
    );
  }

  test('satu contoh tersimpan: PNG-nya ada, indeksnya ada', () async {
    final simpanan = SimpananContohSel(folder);

    final hasil = await simpanan.simpan(
      potongan: potongan(),
      label: '25,3',
      lembar: 'viscometer',
      bacaanOcr: '253',
    );

    expect(hasil, isNotNull);
    expect(File('${folder.path}/${hasil!.berkas}').existsSync(), isTrue);

    final isi = await simpanan.baca();

    expect(isi.barisRusak, 0);
    expect(isi.contoh, hasLength(1));
    expect(isi.contoh.first.label, '25,3');
    expect(isi.contoh.first.bacaanOcr, '253');
    expect(isi.contoh.first.lembar, 'viscometer');
    expect(isi.contoh.first.fieldId, 'pembacaan');
  });

  test('bacaan OCR yang BEDA dari label ikut tersimpan', () async {
    // Ini contoh paling berharga: di situlah model sekarang gagal. Kalau cuma
    // labelnya yang disimpan, kegagalan OCR-nya hilang dan nggak ada yang bisa
    // dipelajari darinya.
    final simpanan = SimpananContohSel(folder);

    await simpanan.simpan(
      potongan: potongan(),
      label: '7',
      lembar: 'ph',
      bacaanOcr: '1',
    );

    final isi = await simpanan.baca();

    expect(isi.contoh.first.label, '7');
    expect(isi.contoh.first.bacaanOcr, '1');
  });

  test('OCR yang NGGAK kebaca tetap tersimpan sebagai contoh', () async {
    // Sel yang OCR-nya gagal total justru yang paling perlu dilatih. Ditolak
    // di sini, data latihnya bias ke kasus yang ML Kit sudah bisa.
    final simpanan = SimpananContohSel(folder);

    final hasil = await simpanan.simpan(
      potongan: potongan(),
      label: '4,5',
      lembar: 'conductivity',
    );

    expect(hasil, isNotNull);
    expect((await simpanan.baca()).contoh.first.bacaanOcr, isNull);
  });

  group('label kosong ditolak', () {
    test('label kosong nggak disimpan', () async {
      // Contoh tanpa label nggak bisa melatih apa pun. Disimpan diam-diam, dia
      // cuma menggelembungkan hitungan dengan sampah yang kelihatan seperti data.
      final simpanan = SimpananContohSel(folder);

      final hasil = await simpanan.simpan(
        potongan: potongan(),
        label: '',
        lembar: 'ph',
      );

      expect(hasil, isNull);
      expect((await simpanan.baca()).contoh, isEmpty);
    });

    test('label yang isinya spasi doang juga ditolak', () async {
      final simpanan = SimpananContohSel(folder);

      expect(
        await simpanan.simpan(potongan: potongan(), label: '   ', lembar: 'ph'),
        isNull,
      );
    });
  });

  test('dua sel dari foto yang SAMA nggak saling menimpa', () async {
    // Stempel waktu saja nggak cukup — sel-sel satu foto disimpan dalam
    // milidetik yang sama. Yang kedua menimpa yang pertama, dan satu contoh
    // latih hilang tanpa ada yang tahu.
    final simpanan = SimpananContohSel(folder);
    final saat = DateTime(2026, 8, 27, 10, 30);

    final a = await simpanan.simpan(
      potongan: potongan(warna: 10),
      label: '1,1',
      lembar: 'ph',
      waktu: saat,
    );
    final b = await simpanan.simpan(
      potongan: potongan(warna: 200),
      label: '2,2',
      lembar: 'ph',
      waktu: saat,
    );

    expect(a!.berkas, isNot(b!.berkas));

    final isi = await simpanan.baca();

    expect(isi.contoh, hasLength(2));
    expect(isi.contoh.map((c) => c.label), containsAll(['1,1', '2,2']));

    // Isinya juga harus beda — nama beda tapi berkas ketimpa tetap kehilangan
    // data, dan itu nggak ketahuan dari hitungannya.
    final citraA = img.decodePng(
      await File('${folder.path}/${a.berkas}').readAsBytes(),
    )!;
    final citraB = img.decodePng(
      await File('${folder.path}/${b.berkas}').readAsBytes(),
    )!;

    expect(citraA.getPixel(4, 4).r, 10);
    expect(citraB.getPixel(4, 4).r, 200);
  });

  test('baris indeks yang RUSAK dihitung, bukan dilewat diam-diam', () async {
    final simpanan = SimpananContohSel(folder);

    await simpanan.simpan(potongan: potongan(), label: '9,9', lembar: 'ph');

    await File('${folder.path}/indeks.jsonl').writeAsString(
      '{bukan json}\n{"berkas":"x.png"}\n',
      mode: FileMode.append,
    );

    final isi = await simpanan.baca();

    expect(isi.contoh, hasLength(1), reason: 'Yang sehat tetap kebaca.');
    expect(
      isi.barisRusak,
      2,
      reason:
          'Yang rusak WAJIB dilaporkan. Indeks yang menyusut diam-diam '
          'kelihatan persis seperti data yang memang segitu.',
    );
  });

  group('pemangkasan', () {
    test('yang paling tua dibuang waktu lewat batas', () async {
      final simpanan = SimpananContohSel(folder, maksimum: 3);

      for (var i = 1; i <= 5; i++) {
        await simpanan.simpan(
          potongan: potongan(),
          label: 'ke-$i',
          lembar: 'ph',
          waktu: DateTime(2026, 8, 27, 10, i),
        );
      }

      final isi = await simpanan.baca();

      expect(isi.contoh, hasLength(3));
      expect(
        isi.contoh.map((c) => c.label),
        ['ke-3', 'ke-4', 'ke-5'],
        reason: 'Yang tertua yang pergi, dan urutannya tetap.',
      );
    });

    test('berkas PNG yang dipangkas ikut terhapus', () async {
      // Kalau cuma barisnya yang hilang, PNG-nya jadi sampah yang nggak pernah
      // dibersihkan — dan batas yang dipasang buat menjaga ruang HP jadi
      // nggak menjaga apa-apa.
      final simpanan = SimpananContohSel(folder, maksimum: 2);

      final berkas = <String>[];

      for (var i = 1; i <= 4; i++) {
        final c = await simpanan.simpan(
          potongan: potongan(),
          label: 'ke-$i',
          lembar: 'ph',
          waktu: DateTime(2026, 8, 27, 10, i),
        );
        berkas.add(c!.berkas);
      }

      expect(File('${folder.path}/${berkas[0]}').existsSync(), isFalse);
      expect(File('${folder.path}/${berkas[1]}').existsSync(), isFalse);
      expect(File('${folder.path}/${berkas[2]}').existsSync(), isTrue);
      expect(File('${folder.path}/${berkas[3]}').existsSync(), isTrue);
    });

    test(
      'indeks nggak menyisakan baris buat berkas yang sudah dihapus',
      () async {
        // Baris yatim bikin `baca()` memulangkan contoh yang citranya nggak ada,
        // dan itu baru meledak jauh di tahap latih — tempat paling mahal buat
        // menemukannya.
        final simpanan = SimpananContohSel(folder, maksimum: 2);

        for (var i = 1; i <= 5; i++) {
          await simpanan.simpan(
            potongan: potongan(),
            label: 'ke-$i',
            lembar: 'ph',
            waktu: DateTime(2026, 8, 27, 10, i),
          );
        }

        final isi = await simpanan.baca();

        for (final c in isi.contoh) {
          expect(
            File('${folder.path}/${c.berkas}').existsSync(),
            isTrue,
            reason: 'Indeks nyebut ${c.berkas}, tapi berkasnya nggak ada.',
          );
        }
      },
    );
  });

  test('simpanan kosong: nol contoh, nol rusak, bukan meledak', () async {
    final isi = await SimpananContohSel(folder).baca();

    expect(isi.contoh, isEmpty);
    expect(isi.barisRusak, 0);
  });

  test('dikosongkan: berkas dan indeksnya hilang', () async {
    final simpanan = SimpananContohSel(folder);

    await simpanan.simpan(potongan: potongan(), label: '1,0', lembar: 'ph');

    await simpanan.kosongkan();

    expect((await simpanan.baca()).contoh, isEmpty);
  });
}
