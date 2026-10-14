import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

/// Aturan tampil Excel yang murni geometri (`luber_teks.dart`) — tanpa
/// menggambar. Lebar kolom 64 dp (bawaan Excel), padding 2 dp.
void main() {
  // Kolom 1..10 selebar 64; kolom 5 tersembunyi (0).
  double lebar(int k) => k == 5 ? 0 : 64;

  LetakTeks letak({
    required int kolom,
    required double teks,
    TextAlign rata = TextAlign.left,
    Set<int> berisi = const {},
    bool meluber = true,
  }) => letakTeks(
    kolom: kolom,
    lebarSel: lebar(kolom),
    lebarTeks: teks,
    rata: rata,
    padding: 2,
    lebarKolom: lebar,
    bolehDilintasi: (k) => !berisi.contains(k),
    kolomTerakhir: 10,
    meluber: meluber,
  );

  group('letakTeks', () {
    test('muat di selnya: tidak meluber, rata kiri mulai di padding', () {
      final l = letak(kolom: 2, teks: 50);
      expect(l.luber, isFalse);
      expect((l.kolomAwal, l.kolomAkhir), (2, 2));
      expect((l.kiri, l.kanan), (2.0, 52.0));
    });

    test('rata kiri meluber ke KANAN sejauh teksnya, melewati sel kosong', () {
      // 2 + 150 = 152 → kolom 2 (0..64), 3 (..128), 4 (..192).
      final l = letak(kolom: 2, teks: 150);
      expect((l.kolomAwal, l.kolomAkhir), (2, 4));
      expect((l.kiri, l.kanan), (2.0, 152.0));
    });

    test('berhenti di sel BERISI berikutnya (teks dipotong di sana)', () {
      final l = letak(kolom: 2, teks: 150, berisi: {3});
      expect((l.kolomAwal, l.kolomAkhir), (2, 2));
      final l2 = letak(kolom: 2, teks: 300, berisi: {4});
      expect((l2.kolomAwal, l2.kolomAkhir), (2, 3));
    });

    test('kolom tersembunyi dilintasi tanpa menambah ruang', () {
      // Dari kolom 4: 2 + 150 = 152 → 4 (..64), 5 (0 lebar), 6 (..128),
      // 7 (..192).
      final l = letak(kolom: 4, teks: 150);
      expect((l.kolomAwal, l.kolomAkhir), (4, 7));
    });

    test('berhenti di tepi lembar', () {
      final l = letak(kolom: 9, teks: 500);
      expect((l.kolomAwal, l.kolomAkhir), (9, 10));
    });

    test('rata kanan meluber ke KIRI', () {
      // kanan = 64 − 2 = 62, kiri = 62 − 150 = −88 → kolom 7 (−64..0),
      // 6 (−128..−64).
      final l = letak(kolom: 8, teks: 150, rata: TextAlign.right);
      expect((l.kolomAwal, l.kolomAkhir), (6, 8));
      expect((l.kiri, l.kanan), (-88.0, 62.0));
    });

    test('rata tengah meluber ke DUA arah, tetap di tengah sumbernya; sisi '
        'yang terhalang dipotong saja', () {
      // tengah 32; kiri −43, kanan 107.
      final l = letak(kolom: 4, teks: 150, rata: TextAlign.center);
      expect((l.kolomAwal, l.kolomAkhir), (3, 6));
      expect((l.kiri, l.kanan), (-43.0, 107.0));
      final terhalang = letak(
        kolom: 4,
        teks: 150,
        rata: TextAlign.center,
        berisi: {3},
      );
      expect((terhalang.kolomAwal, terhalang.kolomAkhir), (4, 6));
      expect(terhalang.kiri, -43.0);
    });

    test('meluber = false (angka, dibungkus, gabungan): letak dihitung, '
        'kolom tidak melebar', () {
      final l = letak(kolom: 2, teks: 150, meluber: false);
      expect((l.kolomAwal, l.kolomAkhir), (2, 2));
    });
  });

  group('cariSumberLuber', () {
    KeadaanLuber Function(int) dari(Map<int, KeadaanLuber> peta) =>
        (k) => peta[k] ?? KeadaanLuber.kosong;

    test('sel berisi terdekat ke kiri / kanan melewati sel kosong', () {
      final keadaan = dari({2: KeadaanLuber.berisi, 8: KeadaanLuber.berisi});
      int? cari(int arah) => cariSumberLuber(
        kolom: 5,
        arah: arah,
        kolomTerakhir: 10,
        keadaan: keadaan,
        lebarKolom: lebar,
        batas: 1000,
      );
      expect(cari(-1), 2);
      expect(cari(1), 8);
    });

    test('penghalang (gabungan / belum termuat) memutus pencarian', () {
      expect(
        cariSumberLuber(
          kolom: 5,
          arah: -1,
          kolomTerakhir: 10,
          keadaan: dari({2: KeadaanLuber.berisi, 3: KeadaanLuber.penghalang}),
          lebarKolom: lebar,
          batas: 1000,
        ),
        isNull,
      );
    });

    test('lebih jauh dari batas = tidak dicari; tepi lembar = null', () {
      final keadaan = dari({1: KeadaanLuber.berisi});
      expect(
        cariSumberLuber(
          kolom: 9,
          arah: -1,
          kolomTerakhir: 10,
          keadaan: keadaan,
          lebarKolom: lebar,
          batas: 100,
        ),
        isNull,
      );
      expect(
        cariSumberLuber(
          kolom: 9,
          arah: 1,
          kolomTerakhir: 10,
          keadaan: keadaan,
          lebarKolom: lebar,
          batas: 1000,
        ),
        isNull,
      );
    });
  });

  group('teks tampil Excel', () {
    test('#### sebanyak yang muat; ruang < satu pagar = kosong', () {
      expect(teksPagar(60, 7), '########');
      expect(teksPagar(6, 7), '');
      expect(teksPagar(60, 0), '');
    });

    test('pemisah baris di sel tak-dibungkus jadi spasi', () {
      expect(
        teksSatuBaris('KALIBRASI\nHEIGHT GAUGE'),
        'KALIBRASI HEIGHT GAUGE',
      );
      expect(teksSatuBaris('a\r\nb'), 'a b');
      expect(teksSatuBaris('biasa'), 'biasa');
    });
  });

  group('satuan & zoom', () {
    test('font Excel pt → dp 1:1 (kalibrasi Inter ≈ MDW Calibri 11)', () {
      expect(ukuranFontExcelKeDp(11), 11);
      expect(ukuranFontExcelKeDp(14), 14);
    });

    test('langkah zoom 10 %, dijepit 50–200 %', () {
      expect(langkahZoom(1, 1), 1.1);
      expect(langkahZoom(1, -1), 0.9);
      expect(langkahZoom(0.87, 1), 1.0);
      expect(langkahZoom(0.5, -1), 0.5);
      expect(langkahZoom(2, 1), 2.0);
    });

    test('KendaliGridSel.aturZoom dijepit & dibulatkan 1 %; berubah = '
        'memberi tahu', () {
      final k = KendaliGridSel();
      var kabar = 0;
      k.addListener(() => kabar++);
      k.aturZoom(3);
      expect(k.zoom, 2.0);
      k.aturZoom(0.1);
      expect(k.zoom, 0.5);
      k.aturZoom(1.234);
      expect(k.zoom, 1.23);
      k.aturZoom(1.2341);
      expect(kabar, 3);
      k.dispose();
    });
  });

  group('garis tepi Excel', () {
    test('nama gaya → jenis; yang lebih tebal menang di sisi bersama', () {
      expect(JenisGaris.dari('thin'), JenisGaris.tipis);
      expect(JenisGaris.dari('medium'), JenisGaris.sedang);
      expect(JenisGaris.dari('thick'), JenisGaris.tebal);
      expect(JenisGaris.dari('double'), JenisGaris.ganda);
      expect(JenisGaris.dari('hair'), JenisGaris.rambut);
      expect(JenisGaris.dari('dashDot'), JenisGaris.putus);
      expect(JenisGaris.dari('mediumDashed'), JenisGaris.sedangPutus);
      expect(JenisGaris.dari('none'), JenisGaris.tanpa);
      expect(JenisGaris.dari(null), JenisGaris.tanpa);
      // Gaya baru yang belum dikenal: ADA garis, bukan hilang diam-diam.
      expect(JenisGaris.dari('gayaBaru'), JenisGaris.tipis);
      expect(
        JenisGaris.terberat(JenisGaris.tipis, JenisGaris.sedang),
        JenisGaris.sedang,
      );
      expect(
        JenisGaris.terberat(JenisGaris.ganda, JenisGaris.tipis),
        JenisGaris.ganda,
      );
    });
  });
}
