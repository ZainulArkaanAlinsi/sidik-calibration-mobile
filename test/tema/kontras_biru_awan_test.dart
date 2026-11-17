import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/palet_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';

import '../support/komponen_uji.dart' show rasioKontras;

/// Gerbang desain Lab, kontras komponen dasar Biru Awan (L3a), WCAG 2.x.
///
/// Menjaga setiap pasangan warna yang dipakai `lib/widgets/biru_awan/`:
/// isi + tinta stempel, ubin ikon, bulatan jumlah chip, FAIL navy pekat,
/// tombol mati, tepi isian (biasa, fokus, galat), tepi chip, pil segmen, tepi
/// kartu terpilih. Teks 4,5:1; komponen UI 3:1. Terang dan gelap.
///
/// Kalau warna digeser dan tes ini berteriak, betulkan warnanya; jangan
/// menurunkan ambang.
void main() {
  const teks = 4.5;
  const komponen = 3.0;

  for (final (nama, m, tema) in <(String, SidikMaterial, ThemeData)>[
    ('terang', SidikMaterial.terangDefault, AppTheme.light),
    ('gelap', SidikMaterial.gelapDefault, AppTheme.dark),
  ]) {
    final w = WarnaBiruAwan.dari(m);
    final s = tema.colorScheme;

    void cek(String apa, Color a, Color b, double ambang) {
      final r = rasioKontras(a, b);
      expect(
        r,
        greaterThanOrEqualTo(ambang),
        reason:
            '$apa di tema $nama cuma ${r.toStringAsFixed(2)}:1 '
            '(minimal $ambang:1)',
      );
    }

    group('Biru Awan L3a, tema $nama', () {
      test('tinta di atas isi: stempel, ubin ikon, bulatan jumlah', () {
        for (final n in IsiBiruAwan.values) {
          cek('tinta/isi ${n.name}', w.tinta(n), w.isi(n), teks);
        }
      });

      test('FAIL navy pekat: teks 4,5:1 dan terpisah dari kartu 3:1', () {
        cek('tinta FAIL/isi FAIL', w.tintaFail, w.isiFail, teks);
        cek('isi FAIL/kertas', w.isiFail, m.kertas, komponen);
        cek('isi FAIL/latar', w.isiFail, m.meja, komponen);
      });

      test('tombol mati tetap terbaca (tinta kedua di isi netral)', () {
        cek('tinta/isi mati', w.tintaTombolMati, w.isiTombolMati, teks);
      });

      test('tombol utama, bahaya, tegas, sekunder, teks', () {
        cek('onPrimary/primary', s.onPrimary, s.primary, teks);
        cek('onError/error', s.onError, s.error, teks);
        cek('kertas/tinta (tegas)', m.kertas, m.tinta, teks);
        cek('tinta/kertas (sekunder)', m.tinta, m.kertas, teks);
        cek('biruTinta/latar (teks)', m.biruTinta, m.meja, teks);
        cek('biruTinta/kertas (teks)', m.biruTinta, m.kertas, teks);
      });

      test('tepi sekunder (kontrol) terhadap kertas 3:1', () {
        cek('garisTegas/kertas', m.garisTegas, m.kertas, komponen);
      });

      test('isian: tepi biasa, fokus, galat terhadap kertas 3:1', () {
        cek('tepi biasa/kertas', m.garisTegas, m.kertas, komponen);
        cek('tepi fokus/kertas', m.biru, m.kertas, komponen);
        cek('tepi galat/kertas', w.tepiGalat, m.kertas, komponen);
      });

      test('isian: kalimat galat, bantuan, label mati terbaca 4,5:1', () {
        cek('galat/kertas', w.tintaGalat, m.kertas, teks);
        cek('galat/latar', w.tintaGalat, m.meja, teks);
        cek('bantuan/kertas', m.tinta2, m.kertas, teks);
        cek('teks mati/latar mati', m.tinta2, w.latarMati, teks);
        cek('teks/kertas', m.tinta, m.kertas, teks);
      });

      test('cincin fokus tombol terhadap kertas dan latar 3:1, dan terpisah '
          'dari isi tombol', () {
        cek('cincin/kertas', m.tinta, m.kertas, komponen);
        cek('cincin/latar', m.tinta, m.meja, komponen);
        // Cincin tidak boleh menempel pada isi: navy di atas navy (tegas) cuma
        // 1,00:1, utama dan bahaya 1,6 sampai 3,0:1. Dengan ruang >= 2 dp yang
        // bersebelahan dengan cincin adalah latar halaman, bukan isi.
        expect(
          UkuranKomponenBiruAwan.jarakCincinFokus,
          greaterThanOrEqualTo(2),
          reason: 'cincin harus terpisah dari isi tombol',
        );
      });

      test('chip: tepi dan chip terpilih (biru muda + tepi biru) 3:1', () {
        cek('tepi chip/latar', m.garisTegas, m.meja, komponen);
        // REVISI 16 Nov: terpilih = biru muda + tepi biru + kata navy. Biru muda
        // sendirian ~1,1:1, jadi TEPI biru yang membawa pilihan (3:1).
        cek('tepi chip terpilih/latar', m.biru, m.meja, komponen);
        cek('tepi chip terpilih/kertas', m.biru, m.kertas, komponen);
        cek('kata navy/biru muda (label terpilih)', m.tinta, m.biruTipis, teks);
      });

      test('segmen: penanda terpilih (biru muda + tepi biru), teks 4,5:1', () {
        cek('tepi terpilih/jalur', m.biru, m.meja, komponen);
        cek('teks terpilih', m.tinta, m.biruTipis, teks);
        cek('teks tidak terpilih', m.tinta, m.meja, teks);
        cek('teks mati terpilih', w.tintaTombolMati, w.isiTombolMati, teks);
        cek('teks mati', w.tintaTombolMati, m.meja, teks);
      });

      test('kartu terpilih: garis primer terhadap kabut 3:1', () {
        cek('primer/kabut', m.biru, w.isi(IsiBiruAwan.kabut), komponen);
      });

      test('ikon panah baris (tinta kedua) terhadap kertas 3:1', () {
        cek('tinta2/kertas', m.tinta2, m.kertas, komponen);
      });

      test('lencana jumlah: angka putih di atas merah galat', () {
        cek('angka/lencana', m.teksDiGagal, m.gagal, teks);
        cek('lencana/latar', m.gagal, m.meja, komponen);
      });

      test('bilah navigasi: ikon dan kata aktif di atas kapsul biru muda', () {
        cek('biruTinta/kapsul', m.biruTinta, m.biruTipis, teks);
        cek('tinta/kapsul', m.tinta, m.biruTipis, teks);
        cek('tinta2/kertas (butir lain)', m.tinta2, m.kertas, teks);
        cek('cincin fokus/kertas', m.tinta, m.kertas, komponen);
      });

      test('banner pembaruan: kata navy di atas biru muda, ikon primerTua', () {
        cek('tinta/kabut', m.tinta, m.biruTipis, teks);
        cek('biruTinta/kabut', m.biruTinta, m.biruTipis, teks);
      });

      test('tombol bulat putih dan navy terhadap latar', () {
        cek('ikon/putih', m.tinta, m.kertas, teks);
        cek('ikon/navy', m.kertas, m.tinta, teks);
        cek('ikon/primer', s.onPrimary, s.primary, teks);
      });
    });
  }

  group('Biru Awan L3a: pasangan terlarang, tes negatif', () {
    test('teks putih di atas isi muda status gagal: tinta HARUS gelap', () {
      expect(
        rasioKontras(PaletLab.kertas, PaletLab.koral),
        lessThan(teks),
        reason:
            'merah muda memakai tinta merah gelap, bukan putih; FAIL '
            'memakai navy pekat berteks putih',
      );
    });

    test('teks putih di atas langit gagal (DILARANG)', () {
      expect(rasioKontras(PaletLab.kertas, PaletLab.langit), lessThan(teks));
    });

    test('FAIL terang = navy pekat + putih persis', () {
      final w = WarnaBiruAwan.dari(SidikMaterial.terangDefault);
      expect(w.isiFail, PaletLab.tinta);
      expect(w.tintaFail, PaletLab.kertas);
    });
  });
}
