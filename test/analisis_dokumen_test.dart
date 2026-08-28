import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/analisis_dokumen.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';

/// Lapisan paling bawah pemahaman dokumen GENERIK: mengubah kepingan OCR jadi
/// baris, lalu baris jadi pasangan label → nilai — **tanpa tahu lembar apa yang
/// difoto**.
///
/// Bedanya dari `peta_tabel_foto_test`: yang di sana menempatkan angka ke dalam
/// bentuk lembar yang SUDAH diketahui (server mengirim titik ukur & kolomnya).
/// Yang di sini kebalikannya — dokumennya yang menentukan bentuknya, dan nggak
/// ada satu pun nama alat yang boleh muncul di berkas ini.
void main() {
  const analisis = AnalisisDokumen();

  /// Satu kepingan OCR. [y] tepi atas, tinggi hurufnya 20 — semua ambang di
  /// `AnalisisDokumen` relatif terhadap tinggi huruf, jadi angkanya konsisten.
  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 12, 20),
    keyakinan: keyakinan,
  );

  group('kepingan disatukan jadi baris', () {
    test('kata-kata sebaris jadi SATU baris, urut kiri ke kanan', () {
      final baris = analisis.kelompokkanBaris([
        kata('Alat', 160, 100),
        kata('Nama', 100, 100),
        kata(':', 240, 100),
      ]);

      expect(baris, hasLength(1));
      expect(
        baris.single.teks,
        'Nama Alat :',
        reason: 'ML Kit memulangkan per KATA — `Nama Alat :` nggak pernah '
            'datang utuh. Seluruh pemahaman dokumen berdiri di atas '
            'penyatuan ini.',
      );
    });

    test('foto agak miring tetap kebaca sebaris', () {
      // Tepi atasnya beda 6 px di seberang halaman — kertas yang nggak lurus di
      // meja. Tumpang tindihnya masih jauh di atas setengah tinggi huruf.
      final baris = analisis.kelompokkanBaris([
        kata('Merk', 100, 100),
        kata('Fluke', 300, 106),
      ]);

      expect(
        baris,
        hasLength(1),
        reason: 'Nuntut tumpang tindih penuh bikin satu baris pecah jadi '
            'beberapa, dan tiap pecahannya kehilangan pasangannya.',
      );
    });

    test('baris yang beneran beda tetap terpisah', () {
      final baris = analisis.kelompokkanBaris([
        kata('Nama', 100, 100),
        kata('Merk', 100, 140),
      ]);

      expect(baris, hasLength(2));
    });

    test('barisnya urut atas ke bawah, bukan urut masuknya', () {
      final baris = analisis.kelompokkanBaris([
        kata('bawah', 100, 300),
        kata('atas', 100, 100),
        kata('tengah', 100, 200),
      ]);

      expect(baris.map((b) => b.teks), ['atas', 'tengah', 'bawah']);
    });

    test('kepingan berkotak nol dibuang, bukan bikin baris menelan halaman', () {
      final baris = analisis.kelompokkanBaris([
        (teks: 'garis', kotak: Rect.zero, keyakinan: null),
        kata('Nama', 100, 100),
        kata('Merk', 100, 300),
      ]);

      expect(baris, hasLength(2));
    });
  });

  group('pasangan label dan nilai', () {
    test('label bertitik dua ketemu nilainya di kanan', () {
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Nama', 100, 100),
          kata('Alat', 160, 100),
          kata(':', 240, 100),
          kata('Digital', 270, 100),
          kata('Thermometer', 370, 100),
        ]),
      );

      expect(p, hasLength(1));
      expect(p.single.label, 'Nama Alat');
      expect(
        p.single.nilai,
        'Digital Thermometer',
        reason: 'Yang dicari HUBUNGANNYA, bukan satu string panjang '
            '"Nama Alat Digital Thermometer".',
      );
    });

    test('titik dua yang nempel di ekor kata juga kebaca', () {
      // Jaraknya beda per lembar; ada yang nyetak `Merk:` rapat.
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([kata('Merk:', 100, 100), kata('Fluke', 200, 100)]),
      );

      expect(p, hasLength(1));
      expect(p.single.label, 'Merk');
      expect(p.single.nilai, 'Fluke');
    });

    test('DUA pasangan sebaris nggak saling menelan', () {
      // `Merk : Fluke        Tipe : 87V` — celah lebar sebelum `Tipe` yang
      // memisahkan. Tanpa itu, nilainya kebaca `Fluke Tipe`.
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Merk', 100, 100),
          kata(':', 160, 100),
          kata('Fluke', 190, 100),
          kata('Tipe', 400, 100),
          kata(':', 460, 100),
          kata('87V', 490, 100),
        ]),
      );

      expect(p, hasLength(2));
      expect(p[0].label, 'Merk');
      expect(p[0].nilai, 'Fluke');
      expect(p[1].label, 'Tipe');
      expect(p[1].nilai, '87V');
    });

    test('nilai bercelah wajar tetap satu nilai', () {
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Nama', 100, 100),
          kata(':', 160, 100),
          kata('PT', 190, 100),
          kata('Tirta', 220, 100),
          kata('Gracia', 290, 100),
        ]),
      );

      expect(p.single.nilai, 'PT Tirta Gracia');
    });

    test('label tanpa nilai tetap pulang — kolom kosong itu keterangan', () {
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([kata('Serial', 100, 100), kata('Number:', 170, 100)]),
      );

      expect(p, hasLength(1));
      expect(p.single.label, 'Serial Number');
      expect(
        p.single.nilai,
        isEmpty,
        reason: 'Kolom yang belum diisi teknisi itu keterangan yang berguna, '
            'bukan ketiadaan. Yang menyaringnya pemanggil.',
      );
    });

    test('teks tanpa titik dua NGGAK dianggap pasangan', () {
      // Kepala kolom tabel — itu urusan pendeteksi tabel, bukan di sini.
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Standard', 100, 100),
          kata('Reading', 300, 100),
        ]),
      );

      expect(p, isEmpty);
    });
  });

  group('keyakinan pasangan', () {
    test('diambil dari NILAI-nya, bukan labelnya', () {
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Suhu', 100, 100, keyakinan: 0.99),
          kata(':', 160, 100, keyakinan: 0.99),
          kata('25,4', 190, 100, keyakinan: 0.42),
        ]),
      );

      expect(
        p.single.keyakinan,
        0.42,
        reason: 'Label itu teks CETAK yang hampir selalu kebaca benar. '
            'Mencampurnya bikin keyakinan pasangan kelihatan tinggi padahal '
            'tulisan tangan di kanannya dibaca ragu-ragu.',
      );
    });

    test('yang terendah yang menang', () {
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Nama', 100, 100),
          kata(':', 160, 100),
          kata('PT', 190, 100, keyakinan: 0.90),
          kata('Gracia', 230, 100, keyakinan: 0.55),
        ]),
      );

      expect(p.single.keyakinan, 0.55);
    });

    test('satu kepingan tak dilaporkan bikin SELURUH pasangan tak diketahui', () {
      final p = analisis.deteksiPasangan(
        analisis.kelompokkanBaris([
          kata('Nama', 100, 100),
          kata(':', 160, 100),
          kata('PT', 190, 100, keyakinan: 0.95),
          kata('Gracia', 230, 100),
        ]),
      );

      expect(
        p.single.keyakinan,
        isNull,
        reason: 'Diambil dari kepingan yang kebetulan punya angka, pasangan '
            'yang separuhnya nggak dinilai kelihatan sudah dinilai.',
      );
    });
  });


  group('tabel dikenali dari keteraturan kolomnya', () {
    /// Satu tabel 3 kolom × 3 baris + kepala, tanpa satu pun garis kotak —
    /// karena OCR itu pengenal TEKS, dan garis tabel sering nggak kebaca sama
    /// sekali.
    List<TeksTerbaca> tabelTiga() => [
      kata('No', 100, 100),
      kata('Standard', 300, 100),
      kata('Reading', 500, 100),
      kata('1', 100, 140),
      kata('4,01', 300, 140),
      kata('4,02', 500, 140),
      kata('2', 100, 180),
      kata('7,00', 300, 180),
      kata('7,03', 500, 180),
    ];

    test('tabel tanpa garis tetap kedeteksi', () {
      final t = analisis.deteksiTabel(analisis.kelompokkanBaris(tabelTiga()));

      expect(t, hasLength(1));
      expect(t.single.kepala, ['No', 'Standard', 'Reading']);
      expect(t.single.baris, [
        ['1', '4,01', '4,02'],
        ['2', '7,00', '7,03'],
      ]);
    });

    test('sel KOSONG tetap di posisinya, kolom sesudahnya nggak geser', () {
      final t = analisis.deteksiTabel(
        analisis.kelompokkanBaris([
          ...tabelTiga(),
          // Baris ketiga: kolom tengah bolong, teknisi belum mengisinya.
          kata('3', 100, 220),
          kata('9,05', 500, 220),
        ]),
      );

      expect(
        t.single.baris.last,
        ['3', '', '9,05'],
        reason: 'Sel yang digeser bikin `9,05` mendarat di kolom Standard. '
            'Angkanya lengkap, tabelnya wajar, dan yang salah cuma kolom mana '
            'yang dimaksud — nggak ada satu pun error di jalurnya.',
      );
    });

    test('tabel yang LANGSUNG mulai dari data nggak kehilangan baris pertama', () {
      final t = analisis.deteksiTabel(
        analisis.kelompokkanBaris([
          kata('1', 100, 100),
          kata('4,01', 300, 100),
          kata('2', 100, 140),
          kata('7,00', 300, 140),
        ]),
      );

      expect(t.single.kepala, isEmpty);
      expect(
        t.single.baris,
        [
          ['1', '4,01'],
          ['2', '7,00'],
        ],
        reason: 'Baris pertama cuma jadi kepala kalau nggak satu pun selnya '
            'angka. Lembar tanpa baris kepala nggak boleh kehilangan datanya.',
      );
    });

    test('dua kata dalam satu sel digabung, bukan saling menimpa', () {
      final t = analisis.deteksiTabel(
        analisis.kelompokkanBaris([
          kata('Nama', 100, 100),
          kata('Nilai', 400, 100),
          kata('PT', 100, 140),
          kata('Gracia', 140, 140),
          kata('7,00', 400, 140),
        ]),
      );

      expect(t.single.baris.single.first, 'PT Gracia');
    });

    test('teks biasa yang bukan tabel nggak dianggap tabel', () {
      final t = analisis.deteksiTabel(
        analisis.kelompokkanBaris([
          kata('Nama', 100, 100),
          kata(':', 160, 100),
          kata('Fluke', 190, 100),
        ]),
      );

      expect(
        t,
        isEmpty,
        reason: 'Satu baris doang bukan tabel — butuh keteraturan yang '
            'BERULANG, minimal dua baris.',
      );
    });

    test('kolom yang berjauhan nggak saling ditelan', () {
      final t = analisis.deteksiTabel(analisis.kelompokkanBaris(tabelTiga()));

      expect(t.single.pusatKolom, hasLength(3));
    });
  });

  test('lembar yang belum pernah ada tetap kebaca strukturnya', () {
    // Bukan lembar mana pun yang dikenal aplikasi ini — justru itu intinya.
    // Nggak ada profil, nggak ada geometri, nggak ada parser.
    final p = analisis.deteksiPasangan(
      analisis.kelompokkanBaris([
        kata('Torque', 100, 100),
        kata('Wrench', 190, 100),
        kata('Calibration', 300, 100),
        kata('Nama', 100, 160),
        kata('Alat', 160, 160),
        kata(':', 240, 160),
        kata('Tohnichi', 270, 160),
        kata('Kapasitas', 100, 200),
        kata(':', 220, 200),
        kata('200', 250, 200),
        kata('Nm', 290, 200),
      ]),
    );

    expect(
      {for (final x in p) x.label: x.nilai},
      {'Nama Alat': 'Tohnichi', 'Kapasitas': '200 Nm'},
      reason: 'Ini pengujian paling penting di berkas ini: worksheet baru '
          'harus kebaca TANPA dibuatkan parser manual.',
    );
  });
}
