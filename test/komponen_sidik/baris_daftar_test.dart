// BarisDaftar: baris tanpa kartu, min 64 dp, seluruh baris bisa diketuk.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/sidik/baris_daftar.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';
import 'package:sidik_calibration/widgets/sidik/stempel.dart';

import '../support/komponen_uji.dart';

const _panjang =
    'Termometer Digital Presisi Tinggi dengan Probe Stainless Steel Tipe K '
    'dan Layar Ganda';
const _ptPanjang = 'PT Maju Jaya Sentosa Abadi Perkasa Nusantara Raya';

void main() {
  setUpAll(muatFontUji);

  group('tata letak', () {
    test('susunan kompak: < 360 dp atau huruf > 1,15x', () {
      expect(BarisDaftar.kompak(lebar: 359.9, skala: 1.0), isTrue);
      expect(BarisDaftar.kompak(lebar: 360, skala: 1.0), isFalse);
      expect(BarisDaftar.kompak(lebar: 392, skala: 1.15), isFalse);
      expect(BarisDaftar.kompak(lebar: 392, skala: 1.16), isTrue);
      expect(BarisDaftar.kompak(lebar: 320, skala: 1.3), isTrue);
    });

    testWidgets('tinggi minimum 64 dp walau isinya hanya satu baris', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          const Align(
            alignment: Alignment.topCenter,
            child: BarisDaftar(judul: 'Autoklaf', pemisah: false),
          ),
          bergulir: false,
        ),
      );
      expect(
        tester.getSize(find.byType(BarisDaftar)).height,
        greaterThanOrEqualTo(64),
      );
    });

    testWidgets('392 dp: stempel di kanan judul, tanpa kartu', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan Digital Ohaus',
                keterangan: 'CV Sentosa Abadi',
                status: StatusTampil.dariKode('FAIL'),
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      final judul = tester.getRect(find.text('Timbangan Digital Ohaus'));
      final stempel = tester.getRect(find.byType(Stempel));
      expect(stempel.left, greaterThan(judul.right));
      expect(
        (stempel.center.dy - judul.center.dy).abs(),
        lessThan(48),
        reason: 'sejajar dengan teks, bukan di baris sendiri',
      );
      // Tanpa kartu: tidak ada Card dan tidak ada bayangan.
      expect(find.byType(Card), findsNothing);
      final bahan = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BarisDaftar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(bahan.elevation, 0);
      expect(bahan.color, SidikMaterial.terangDefault.kertas);
    });

    testWidgets('320 dp: stempel pindah ke baris sendiri di bawah teks', (
      tester,
    ) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan Digital Ohaus',
                keterangan: 'CV Sentosa Abadi',
                status: StatusTampil.dariKode('expired'),
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      final ket = tester.getRect(find.text('CV Sentosa Abadi'));
      final stempel = tester.getRect(find.byType(Stempel));
      expect(stempel.top, greaterThanOrEqualTo(ket.bottom));
      expect(stempel.left, lessThan(ket.left + 2), reason: 'rata kiri');
    });

    testWidgets('huruf 1,3x di 392 dp juga menurunkan stempel', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan',
                keterangan: 'CV Sentosa Abadi',
                status: StatusTampil.dariKode('FAIL'),
              ),
            ],
          ),
          skala: 1.3,
        ),
      );
      final ket = tester.getRect(find.text('CV Sentosa Abadi'));
      expect(
        tester.getRect(find.byType(Stempel)).top,
        greaterThanOrEqualTo(ket.bottom),
      );
    });

    for (final gelap in [false, true]) {
      testWidgets(
        'teks panjang di 320 dp x 1,3: tanpa luapan, judul paling banyak 2 baris '
        '(${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          layarUji(tester, lebar: 320, tinggi: 640);
          await tester.pumpWidget(
            aplikasiUji(
              Column(
                children: [
                  BarisDaftar(
                    judul: _panjang,
                    keterangan: _ptPanjang,
                    status: StatusTampil.dariKode('expired'),
                    meta: const [
                      MetaBaris(
                        'Menunggu persetujuan admin lab',
                        ikon: Icons.schedule,
                      ),
                      MetaBaris('2 peringatan', ikon: Icons.error_outline),
                    ],
                    tambahan: const Text('tambahan'),
                    onTap: () {},
                  ),
                ],
              ),
              gelap: gelap,
              skala: 1.3,
            ),
          );
          expect(tester.takeException(), isNull);
          final judul = tester.renderObject<RenderParagraph>(
            find.text(_panjang),
          );
          expect(judul.maxLines, 2);
          expect(barisTeks(judul).length, lessThanOrEqualTo(2));
          final semua = semuaTeks(tester, find.byType(BarisDaftar));
          expect(semua, isNot(contains(' · ')));
        },
      );
    }

    testWidgets(
      '392 dp: stempel panjang dibatasi 40% lebar, judul tetap lega',
      (tester) async {
        layarUji(tester);
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                BarisDaftar(
                  judul: 'Timbangan Digital Ohaus',
                  status: StatusTampil.dariKode('expired'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(Stempel)).width,
          lessThanOrEqualTo(392 * 0.4 + 0.5),
        );
        final judul = tester.renderObject<RenderParagraph>(
          find.text('Timbangan Digital Ohaus'),
        );
        expect(
          judul.didExceedMaxLines,
          isFalse,
          reason: 'judul tidak terpotong',
        );
        expect(barisTeks(judul).length, lessThanOrEqualTo(2));
      },
    );

    testWidgets('tablet 1280 dp: tanpa luapan', (tester) async {
      layarUji(tester, lebar: 1280, tinggi: 800);
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: BarisDaftar(
                judul: _panjang,
                keterangan: _ptPanjang,
                status: StatusTampil.jadwal(-3),
                onTap: () {},
              ),
            ),
          ),
          bergulir: false,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('pemisah: garis halus di bawah, bisa dimatikan', (
      tester,
    ) async {
      final m = SidikMaterial.terangDefault;
      Future<Border?> garis(bool pemisah) async {
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [BarisDaftar(judul: 'A', pemisah: pemisah)],
            ),
          ),
        );
        final d = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(BarisDaftar),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((x) => x.decoration)
            .whereType<BoxDecoration>()
            .first;
        return d.border as Border?;
      }

      final ada = await garis(true);
      expect(ada, isNotNull);
      expect(ada!.bottom.color, m.kertasTepi);
      expect(ada.bottom.width, 1);
      expect(ada.top, BorderSide.none);
      expect(await garis(false), isNull);
    });
  });

  group('aksi dan semantik', () {
    testWidgets('ketuk di mana saja pada baris memanggil onTap', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan',
                keterangan: 'CV Sentosa Abadi',
                status: StatusTampil.dariKode('PASS'),
                onTap: () => n++,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(Stempel));
      await tester.tap(find.text('CV Sentosa Abadi'));
      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(n, 3);
    });

    testWidgets('satu node semantik: judul, keterangan, status + aksi ketuk', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan Digital Ohaus',
                keterangan: 'CV Sentosa Abadi',
                status: StatusTampil.dariKode('FAIL'),
                meta: const [MetaBaris('Menunggu 3 hari')],
                onTap: () => n++,
              ),
            ],
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(BarisDaftar))
          .getSemanticsData();
      expect(data.label, contains('Timbangan Digital Ohaus'));
      expect(data.label, contains('CV Sentosa Abadi'));
      expect(data.label, contains('Status: FAIL'));
      expect(data.label, contains('Menunggu 3 hari'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      tester.semantics.tap(find.semantics.byLabel(RegExp('Timbangan Digital')));
      expect(n, 1, reason: 'aksi ketuk semantik benar-benar memanggil onTap');
      semantik.dispose();
    });

    testWidgets('label semantik pengganti tetap membawa aksi ketuk', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan',
                semantik: 'Timbangan Ohaus, FAIL, menunggu 3 hari',
                onTap: () => n++,
              ),
            ],
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(BarisDaftar))
          .getSemanticsData();
      expect(data.label, 'Timbangan Ohaus, FAIL, menunggu 3 hari');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel(RegExp('Timbangan Ohaus')));
      expect(n, 1);
      semantik.dispose();
    });

    testWidgets('tanpa onTap: hanya baca, tanpa panah dan tanpa aksi ketuk', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(Column(children: [const BarisDaftar(judul: 'Autoklaf')])),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      final data = tester
          .getSemantics(find.byType(BarisDaftar))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isButton, isFalse);
      semantik.dispose();
    });

    testWidgets('pedoman: sasaran >= 48 dp dan berlabel', (tester) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              BarisDaftar(
                judul: 'Timbangan',
                status: StatusTampil.dariKode('PASS'),
                onTap: () {},
              ),
            ],
          ),
          skala: 1.3,
        ),
      );
      await periksaPedomanSentuh(tester);
      semantik.dispose();
    });

    for (final gelap in [false, true]) {
      testWidgets('kontras teks >= 4,5:1 (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                BarisDaftar(
                  judul: 'Timbangan',
                  keterangan: 'CV Sentosa Abadi',
                  meta: const [MetaBaris('Menunggu 3 hari')],
                  status: StatusTampil.dariKode('draft'),
                ),
                BarisDaftar(
                  judul: 'Termometer',
                  status: StatusTampil.jadwal(-2),
                ),
              ],
            ),
            gelap: gelap,
          ),
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(BarisDaftar)),
          isEmpty,
        );
      });
    }
  });
}
