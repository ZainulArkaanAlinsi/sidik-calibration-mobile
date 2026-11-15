// ChipSaring: pil 44 (sentuh >= 48) dengan bulatan jumlah 32.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/chip_saring.dart';

import '../support/uji_biru_awan.dart';

ChipSaring _c({
  String label = 'Semua',
  bool terpilih = false,
  VoidCallback? onTap,
  int? jumlah,
  IsiBiruAwan isi = IsiBiruAwan.netral,
}) => ChipSaring(
  label: label,
  terpilih: terpilih,
  onTap: onTap,
  jumlah: jumlah,
  isiJumlah: isi,
);

/// Pil bergambar di dalam chip (bukan bidang sentuhnya).
Finder _pil() => find.descendant(
  of: find.byType(ChipSaring),
  matching: find.byType(InkWell),
);

void main() {
  setUpAll(muatFontUji);

  group('ukuran', () {
    testWidgets('pil 44, bidang sentuh 48', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(Center(child: _c(onTap: () {}, jumlah: 4))),
      );
      expect(tester.getSize(_pil()).height, 44);
      expect(tester.getSize(find.byType(ChipSaring)).height, 48);
    });

    testWidgets('bulatan jumlah 32 dan melebar untuk angka panjang', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: _c(onTap: () {}, jumlah: 4, isi: IsiBiruAwan.kuning),
          ),
        ),
      );
      final bulatan = find.ancestor(
        of: find.text('4'),
        matching: find.byType(ConstrainedBox),
      );
      final ukuran = tester.getSize(bulatan.first);
      expect(ukuran, const Size(32, 32));

      await tester.pumpWidget(
        aplikasiUji(Center(child: _c(onTap: () {}, jumlah: 123456))),
      );
      final lebar = tester.getSize(
        find
            .ancestor(
              of: find.text('123456'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(lebar.height, 32);
      expect(lebar.width, greaterThan(32));
    });

    testWidgets('tanpa jumlah: tidak ada bulatan', (tester) async {
      await tester.pumpWidget(aplikasiUji(Center(child: _c(onTap: () {}))));
      expect(find.text('4'), findsNothing);
    });

    testWidgets('label sangat panjang dipotong, bukan meluap', (tester) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Row(
            children: [
              _c(
                label:
                    'Label yang sangat panjang sekali sampai melebihi dua ratus dp',
                onTap: () {},
                jumlah: 12,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ChipSaring)).width, lessThan(320));
    });

    testWidgets('ketukan di bidang transparan atas-bawah pil tetap diterima', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(Center(child: _c(onTap: () => n++, jumlah: 4))),
      );
      final kotak = tester.getRect(find.byType(ChipSaring));
      await tester.tapAt(kotak.topCenter + const Offset(0, 1));
      expect(n, 1, reason: '2 dp di atas pil 44 di dalam bidang 48');
    });
  });

  group('warna dari tema', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets(
        'terpilih navy, belum terpilih putih bertepi kontrol ($nama)',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(
              Row(
                children: [
                  _c(label: 'Aktif', terpilih: true, onTap: () {}),
                  _c(label: 'Biasa', onTap: () {}),
                ],
              ),
              gelap: gelap,
            ),
          );
          final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
          Material bahan(String l) => tester.widget<Material>(
            find.descendant(
              of: find.widgetWithText(ChipSaring, l),
              matching: find.byType(Material),
            ),
          );
          expect(bahan('Aktif').color, m.tinta);
          expect(bahan('Biasa').color, m.kertas);
          final tepi = (bahan('Biasa').shape! as StadiumBorder).side;
          expect(tepi.color, m.garisTegas, reason: 'tepi kontrol 3:1');
          expect(tepi.width, 1);
          expect(
            (bahan('Aktif').shape! as StadiumBorder).side,
            BorderSide.none,
          );
        },
      );

      testWidgets('warna bulatan menurut isiJumlah ($nama)', (tester) async {
        await tester.pumpWidget(
          aplikasiUji(
            Row(
              children: [
                _c(label: 'A', onTap: () {}, jumlah: 1, isi: IsiBiruAwan.koral),
                _c(
                  label: 'B',
                  onTap: () {},
                  jumlah: 2,
                  isi: IsiBiruAwan.kuning,
                ),
              ],
            ),
            gelap: gelap,
          ),
        );
        final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
        Color warnaBulatan(String angka) {
          final d = tester.widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text(angka),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          return (d.decoration as BoxDecoration).color!;
        }

        expect(warnaBulatan('1'), w.isi(IsiBiruAwan.koral));
        expect(warnaBulatan('2'), w.isi(IsiBiruAwan.kuning));
      });

      testWidgets('kontras teks >= 4,5:1: terpilih, biasa, mati ($nama)', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            Wrap(
              children: [
                _c(
                  label: 'Semua',
                  terpilih: true,
                  onTap: () {},
                  jumlah: 4,
                  isi: IsiBiruAwan.kuning,
                ),
                _c(
                  label: 'Ada FAIL',
                  onTap: () {},
                  jumlah: 1,
                  isi: IsiBiruAwan.koral,
                ),
                _c(label: 'Lewat jadwal', onTap: () {}, jumlah: 6),
                _c(label: 'Mati', onTap: null, jumlah: 3),
              ],
            ),
            gelap: gelap,
          ),
        );
        expect(pelanggaranKontrasTeks(tester, find.byType(Wrap)), isEmpty);
      });
    }

    testWidgets('mati: tanpa penangan, semantik tombol MATI tanpa aksi ketuk; '
        'aktif ditandai aktif', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(Center(child: _c(onTap: null, jumlah: 2))),
      );
      await tester.tap(find.byType(ChipSaring), warnIfMissed: false);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<InkWell>(_pil()).onTap,
        isNull,
        reason: 'tidak ada callback yang bisa terpanggil',
      );
      final mati = tester
          .getSemantics(find.byType(ChipSaring))
          .getSemanticsData();
      expect(mati.flagsCollection.isButton, isTrue);
      expect(semantikAktif(mati), isFalse, reason: 'mati harus terbaca mati');
      expect(mati.hasAction(SemanticsAction.tap), isFalse);

      await tester.pumpWidget(
        aplikasiUji(Center(child: _c(onTap: () {}, jumlah: 2))),
      );
      final aktif = tester
          .getSemantics(find.byType(ChipSaring))
          .getSemanticsData();
      expect(semantikAktif(aktif), isTrue);
      expect(aktif.hasAction(SemanticsAction.tap), isTrue);
      semantik.dispose();
    });
  });

  group('perilaku dan semantik', () {
    testWidgets('ketuk memanggil onTap', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(Center(child: _c(onTap: () => n++, jumlah: 4))),
      );
      await tester.tap(find.text('Semua'));
      expect(n, 1);
    });

    testWidgets('label gabungan "label, jumlah", terpilih, aksi ketuk', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: _c(
              label: 'Ada FAIL',
              terpilih: true,
              onTap: () => n++,
              jumlah: 1,
            ),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(ChipSaring))
          .getSemanticsData();
      expect(data.label, 'Ada FAIL, 1');
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Ada FAIL, 1'));
      expect(n, 1);
      semantik.dispose();
    });

    testWidgets('tanpa jumlah: label apa adanya; belum terpilih', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: _c(label: 'Semua', onTap: () {}),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(ChipSaring))
          .getSemanticsData();
      expect(data.label, 'Semua');
      expect(data.flagsCollection.isSelected, Tristate.isFalse);
      semantik.dispose();
    });

    testWidgets('kurangi gerak: tekan langsung berskala, tanpa animasi', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(kurangiGerak(Center(child: _c(onTap: () {})))),
      );
      final gestur = await tester.startGesture(
        tester.getCenter(find.byType(ChipSaring)),
      );
      await tester.pump();
      final skala = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(skala.scale, 0.97);
      expect(skala.duration, Duration.zero);
      await gestur.up();
    });
  });

  group('tangguh', () {
    testWidgets('320 dp x huruf 1,3: barisan chip digeser mendatar', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _c(
                label: 'Semua',
                terpilih: true,
                onTap: () {},
                jumlah: 4,
                isi: IsiBiruAwan.kuning,
              ),
              const SizedBox(width: 8),
              _c(
                label: 'Ada FAIL',
                onTap: () {},
                jumlah: 1,
                isi: IsiBiruAwan.koral,
              ),
              const SizedBox(width: 8),
              _c(label: '31 sampai 60 hari', onTap: () {}, jumlah: 9),
            ],
          ),
        ),
      );
    });

    testWidgets('di dalam geser mendatar, chip tidak melar setinggi layar', (
      tester,
    ) async {
      layarUji(tester, lebar: 360, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [_c(onTap: () {}, jumlah: 4)]),
          ),
          bergulir: false,
        ),
      );
      expect(tester.getSize(find.byType(ChipSaring)).height, 48);
    });

    for (final gelap in [false, true]) {
      testWidgets('pedoman sentuh dan label (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            Row(
              children: [
                _c(label: 'Semua', terpilih: true, onTap: () {}, jumlah: 4),
                _c(label: 'Ada FAIL', onTap: () {}, jumlah: 1),
              ],
            ),
            gelap: gelap,
          ),
        );
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });
}
