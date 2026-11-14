import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_lajur.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';

import '../support/komponen_uji.dart' show rasioKontras;

/// Gerbang desain Lab, kontras komponen bersama (Paket 2), WCAG 2.x.
///
/// Melengkapi `kontras_sidik_test.dart` (token tema) dengan pasangan yang baru
/// lahir bersama komponen: warna Lajur Bacaan (panel yang selalu gelap), stempel
/// status dari pemetaan baru, dan penanda skala. Teks 4,5:1; komponen UI 3:1.
///
/// Kalau warna digeser dan tes ini berteriak, betulkan warnanya; jangan
/// menurunkan ambang.
void main() {
  const teks = 4.5;
  const komponen = 3.0;

  for (final (nama, m) in <(String, SidikMaterial)>[
    ('terang', SidikMaterial.terangDefault),
    ('gelap', SidikMaterial.gelapDefault),
  ]) {
    final w = WarnaLajur.dari(m);

    void cek(String apa, double rasio, double ambang) => expect(
      rasio,
      greaterThanOrEqualTo(ambang),
      reason:
          '$apa di tema $nama cuma ${rasio.toStringAsFixed(2)}:1 '
          '(minimal $ambang:1)',
    );

    group('Lajur Bacaan, tema $nama', () {
      test('teks di atas panel', () {
        cek('angka/panel', rasioKontras(w.angka, w.panel), teks);
        cek('redup/panel', rasioKontras(w.redup, w.panel), teks);
        cek('aksen/panel', rasioKontras(w.aksen, w.panel), teks);
        cek('peringatan/panel', rasioKontras(w.peringatan, w.panel), teks);
      });

      test('keypad: angka di atas kunci, tepi kunci terhadap panel', () {
        cek('angka/kunci', rasioKontras(w.angka, w.kunci), teks);
        cek('tepi kunci/panel', rasioKontras(w.tepiKunci, w.panel), komponen);
        cek('tepi kunci/kunci', rasioKontras(w.tepiKunci, w.kunci), komponen);
      });

      test('Berikutnya: label di atas tombol, tombol terhadap panel', () {
        cek('label/tombol', rasioKontras(w.teksTombol, w.tombol), teks);
        cek('tombol/panel', rasioKontras(w.tombol, w.panel), komponen);
        cek('redup/kunci (mati)', rasioKontras(w.redup, w.kunci), teks);
      });

      test('panel terpisah dari latar layar (garis atas bila perlu)', () {
        final garis = rasioKontras(w.garisAtas, m.meja);
        final isi = rasioKontras(w.panel, m.meja);
        // Terang: panel gelap di atas latar terang (selisih besar). Gelap: panel
        // hampir sewarna latar, jadi garis atas yang memisahkan (>= 3:1).
        expect(
          garis >= komponen || isi >= komponen,
          isTrue,
          reason:
              'panel $nama melebur dengan latar: garis ${garis.toStringAsFixed(2)}, '
              'isi ${isi.toStringAsFixed(2)}',
        );
      });

      test('panel gelap di dua tema; tanpa hijau atau merah', () {
        expect(w.panel.computeLuminance(), lessThan(0.02));
        for (final c in [w.angka, w.redup, w.aksen, w.tombol, w.peringatan]) {
          expect(c, isNot(m.lulus));
          expect(c, isNot(m.gagal));
        }
      });
    });

    group('Stempel status, tema $nama', () {
      test('tinta di atas latar tipis tiap nada', () {
        for (final n in NadaStempel.values) {
          final (tinta, latar) = StatusTampil(
            KataStatus.draf,
            n,
            _ikon,
          ).warna(m);
          final dasar = n == NadaStempel.netral ? m.kertas : latar;
          cek('${n.name}/latar', rasioKontras(tinta, dasar), teks);
          cek('${n.name}/meja', rasioKontras(tinta, m.meja), teks);
        }
      });

      test('garis tepi stempel netral (draf) terhadap kertas', () {
        cek(
          'garis tegas/kertas',
          rasioKontras(m.garisTegas, m.kertas),
          komponen,
        );
      });
    });

    group('skala dan navigasi, tema $nama', () {
      test('penanda skala terhadap kertas', () {
        cek('kobalt/kertas', rasioKontras(m.biru, m.kertas), komponen);
        cek('ekor gagal/kertas', rasioKontras(m.gagal, m.kertas), komponen);
        cek(
          'tik garis tegas/kertas',
          rasioKontras(m.garisTegas, m.kertas),
          komponen,
        );
        cek('tinta/kertas', rasioKontras(m.tinta, m.kertas), komponen);
      });

      test('navigasi: ikon dan kata aktif di atas kapsul, lencana', () {
        cek('biru tinta/kapsul', rasioKontras(m.biruTinta, m.biruTipis), teks);
        cek('tinta/kapsul', rasioKontras(m.tinta, m.biruTipis), teks);
        cek('tinta2/kertas', rasioKontras(m.tinta2, m.kertas), teks);
        cek('angka lencana', rasioKontras(m.teksDiGagal, m.gagal), teks);
        cek('lencana/kertas', rasioKontras(m.gagal, m.kertas), komponen);
      });
    });
  }
}

const _ikon = IconData(0xe000);
