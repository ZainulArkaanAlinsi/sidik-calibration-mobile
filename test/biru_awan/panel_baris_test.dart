// PanelBaris + BarisMenu64 + BarisDaftar72 + UbinIkon.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/panel_baris.dart';
import 'package:sidik_calibration/widgets/biru_awan/stempel_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/ubin_ikon.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';

import '../support/uji_biru_awan.dart';

Widget _menu({
  VoidCallback? onTap,
  IsiBiruAwan warna = IsiBiruAwan.kabut,
  Widget? akhir,
  String judul = 'Pelanggan',
  String? keterangan = 'Kelola daftar pelanggan lab',
}) => BarisMenu64(
  judul: judul,
  keterangan: keterangan,
  ikon: Icons.people_outline,
  warna: warna,
  akhir: akhir,
  onTap: onTap,
);

Widget _daftar({
  VoidCallback? onTap,
  Widget? akhir,
  String judul = 'Oven Memmert',
  String? keterangan = 'PT Karya Logam',
  String? nomor,
}) => BarisDaftar72(
  judul: judul,
  keterangan: keterangan,
  nomor: nomor,
  awal: const UbinIkon.baris(ikon: Icons.thermostat),
  akhir: akhir,
  onTap: onTap,
);

void main() {
  setUpAll(muatFontUji);

  group('PanelBaris', () {
    testWidgets('putih, sudut 24; pemisah hanya DI ANTARA baris', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          PanelBaris(
            anak: [
              _menu(onTap: () {}, judul: 'A'),
              _menu(onTap: () {}, judul: 'B'),
              _menu(onTap: () {}, judul: 'C'),
            ],
          ),
        ),
      );
      final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
      final panel = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PanelBaris),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(panel.color, m.kertas);
      expect(
        (panel.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(BentukBiruAwan.kartu),
      );
      final pemisah = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(PanelBaris),
              matching: find.byType(ColoredBox),
            ),
          )
          .where((c) => c.color == m.kertasTepi);
      expect(pemisah, hasLength(2), reason: '3 baris = 2 pemisah');
    });

    testWidgets('bantalan: menu 6; daftar 14 samping', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          Column(
            children: [
              PanelBaris(key: const ValueKey('m'), anak: [_menu()]),
              PanelBaris.daftar(key: const ValueKey('d'), anak: [_daftar()]),
            ],
          ),
        ),
      );
      Padding bantalan(String k) => tester.widget<Padding>(
        find
            .descendant(
              of: find.byKey(ValueKey(k)),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(bantalan('m').padding, const EdgeInsets.all(6));
      expect(
        bantalan('d').padding,
        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      );
    });

    testWidgets('satu baris: tanpa pemisah', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(PanelBaris(anak: [_menu(onTap: () {})])),
      );
      final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
      expect(
        tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where((c) => c.color == m.kertasTepi),
        isEmpty,
      );
    });
  });

  group('BarisMenu64', () {
    testWidgets(
      'minimum 64; ubin ikon bulat 44; panah hanya bila bisa diketuk',
      (tester) async {
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                KeyedSubtree(
                  key: const ValueKey('a'),
                  child: _menu(onTap: () {}),
                ),
                KeyedSubtree(key: const ValueKey('b'), child: _menu()),
              ],
            ),
          ),
        );
        final a = find.byKey(const ValueKey('a'));
        final b = find.byKey(const ValueKey('b'));
        expect(tester.getSize(a).height, greaterThanOrEqualTo(64));
        expect(tester.getSize(a).height, 64);
        expect(
          tester.getSize(
            find.descendant(of: a, matching: find.byType(UbinIkon)),
          ),
          const Size(44, 44),
        );
        expect(
          find.descendant(of: a, matching: find.byIcon(Icons.chevron_right)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: b, matching: find.byIcon(Icons.chevron_right)),
          findsNothing,
        );
      },
    );

    testWidgets('judul 16/600 dan keterangan 13 tinta kedua', (tester) async {
      await tester.pumpWidget(aplikasiUji(_menu(onTap: () {})));
      final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
      final judul = tester.widget<Text>(find.text('Pelanggan')).style!;
      final ket = tester
          .widget<Text>(find.text('Kelola daftar pelanggan lab'))
          .style!;
      expect((judul.fontSize, judul.fontWeight), (16, FontWeight.w600));
      expect((ket.fontSize, ket.color), (13, m.tinta2));
    });

    testWidgets('akhir (mis. lencana) tampil sebelum panah', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(_menu(onTap: () {}, akhir: const Text('29'))),
      );
      final lencana = tester.getCenter(find.text('29')).dx;
      final panah = tester.getCenter(find.byIcon(Icons.chevron_right)).dx;
      expect(lencana, lessThan(panah));
    });

    testWidgets(
      'ketuk memanggil onTap; semantik tombol dengan judul + keterangan',
      (tester) async {
        final semantik = tester.ensureSemantics();
        var n = 0;
        await tester.pumpWidget(aplikasiUji(_menu(onTap: () => n++)));
        final data = tester
            .getSemantics(find.byType(BarisMenu64))
            .getSemanticsData();
        expect(data.label, contains('Pelanggan'));
        expect(data.label, contains('Kelola daftar pelanggan lab'));
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'baris yang bisa diketuk diumumkan sebagai tombol',
        );
        await tester.tap(find.text('Pelanggan'));
        expect(n, 1);
        semantik.dispose();
      },
    );

    testWidgets('semantik pengganti', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          BarisMenu64(
            judul: 'Antrean',
            ikon: Icons.inbox,
            onTap: () {},
            semantik: 'Antrean, 4 menunggu',
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(BarisMenu64))
          .getSemanticsData();
      expect(data.label, 'Antrean, 4 menunggu');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantik.dispose();
    });

    testWidgets('tanpa onTap: hanya baca, tanpa aksi', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(aplikasiUji(_menu()));
      final data = tester
          .getSemantics(find.byType(BarisMenu64))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(
        data.flagsCollection.isButton,
        isFalse,
        reason: 'hanya baca bukan tombol',
      );
      semantik.dispose();
    });
  });

  group('BarisDaftar72', () {
    testWidgets('minimum 64 (dulu 72); ubin visual 48 persegi sudut 12', (
      tester,
    ) async {
      await tester.pumpWidget(aplikasiUji(_daftar(onTap: () {})));
      expect(tester.getSize(find.byType(BarisDaftar72)).height, 64);
      expect(tester.getSize(find.byType(UbinIkon)), const Size(48, 48));
      final kotak =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(UbinIkon),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(kotak.shape, BoxShape.rectangle);
      expect(
        kotak.borderRadius,
        BorderRadius.circular(BentukBiruAwan.ikonUbin),
      );
    });

    testWidgets('judul 16/600, nomor mono 12, keterangan 13', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(_daftar(nomor: 'KAL/2026/11/0001', onTap: () {})),
      );
      final judul = tester.widget<Text>(find.text('Oven Memmert')).style!;
      final nomor = tester.widget<Text>(find.text('KAL/2026/11/0001')).style!;
      expect((judul.fontSize, judul.fontWeight), (16, FontWeight.w600));
      expect(nomor.fontFamily, 'IBMPlexMono');
      expect(nomor.fontSize, 12);
    });

    testWidgets('akhir berupa stempel: tidak melewati 40 % lebar', (
      tester,
    ) async {
      layarUji(tester, lebar: 360, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          PanelBaris.daftar(
            anak: [
              _daftar(
                onTap: () {},
                akhir: StempelSidik(StatusTampil.dariKode('expired')),
              ),
            ],
          ),
        ),
      );
      final baris = tester.getSize(find.byType(BarisDaftar72)).width;
      expect(
        tester.getSize(find.byType(StempelSidik)).width,
        lessThanOrEqualTo(baris * 0.4 + 0.01),
      );
    });

    testWidgets('ketuk memanggil onTap dan semantik tombol', (tester) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(aplikasiUji(_daftar(onTap: () => n++)));
      final data = tester
          .getSemantics(find.byType(BarisDaftar72))
          .getSemanticsData();
      expect(data.label, contains('Oven Memmert'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      await tester.tap(find.text('Oven Memmert'));
      expect(n, 1);

      // Tanpa onTap: hanya baca, bukan tombol, tanpa aksi.
      await tester.pumpWidget(aplikasiUji(_daftar()));
      final bacaSaja = tester
          .getSemantics(find.byType(BarisDaftar72))
          .getSemanticsData();
      expect(bacaSaja.flagsCollection.isButton, isFalse);
      expect(bacaSaja.hasAction(SemanticsAction.tap), isFalse);
      semantik.dispose();
    });
  });

  group('UbinIkon', () {
    testWidgets('menu bulat 44; warna menurut IsiBiruAwan dua tema', (
      tester,
    ) async {
      for (final gelap in [false, true]) {
        for (final warna in IsiBiruAwan.values) {
          await tester.pumpWidget(
            aplikasiUji(
              Center(
                child: UbinIkon(ikon: Icons.science, warna: warna),
              ),
              gelap: gelap,
            ),
          );
          final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
          expect(tester.getSize(find.byType(UbinIkon)), const Size(44, 44));
          final dek =
              tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(UbinIkon),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration;
          expect(dek.shape, BoxShape.circle);
          expect(dek.color, w.isi(warna), reason: '${warna.name} $gelap');
          expect(tester.widget<Icon>(find.byType(Icon)).color, w.tinta(warna));
        }
      }
    });

    testWidgets(
      'hiasan: tersembunyi dari pembaca layar; semantik bila diberi',
      (tester) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(const UbinIkon(ikon: Icons.science)),
        );
        expect(find.byType(ExcludeSemantics), findsWidgets);
        await tester.pumpWidget(
          aplikasiUji(
            const UbinIkon(ikon: Icons.science, semantik: 'Pelanggan'),
          ),
        );
        expect(find.bySemanticsLabel('Pelanggan'), findsOneWidget);
        semantik.dispose();
      },
    );

    testWidgets('child menggantikan ikon (mis. gambar alat)', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          const UbinIkon.baris(
            child: SizedBox(key: ValueKey('gambar'), width: 44, height: 44),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('gambar')), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    test('tanpa ikon dan tanpa child ditolak', () {
      expect(() => UbinIkon(), throwsAssertionError);
    });
  });

  group('kurangi gerak', () {
    testWidgets('baris, panel, dan ubin tidak menjalankan animasi sendiri', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          kurangiGerak(
            Column(
              children: [
                PanelBaris(
                  anak: [
                    _menu(onTap: () {}),
                    _menu(),
                  ],
                ),
                PanelBaris.daftar(
                  anak: [
                    _daftar(onTap: () {}),
                    _daftar(),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.byType(BarisMenu64), findsNWidgets(2));
      expect(find.byType(BarisDaftar72), findsNWidgets(2));
    });
  });

  group('tangguh', () {
    testWidgets(
      '320 dp x huruf 1,3: menu dan daftar membungkus, tanpa luapan',
      (tester) async {
        await periksaSkala13(
          tester,
          Column(
            children: [
              PanelBaris(
                anak: [
                  _menu(
                    onTap: () {},
                    judul: 'Tanda tangan sertifikat yang dicetak di sertifikat',
                    keterangan:
                        'Nama, alamat, nomor akreditasi untuk kop sertifikat',
                    akhir: const Text('12'),
                  ),
                  _menu(onTap: () {}, warna: IsiBiruAwan.koralTipis),
                ],
              ),
              const SizedBox(height: 12),
              PanelBaris.daftar(
                anak: [
                  _daftar(
                    onTap: () {},
                    judul: 'Timbangan Analitik Elektronik Kapasitas Besar',
                    nomor: 'KAL/2026/11/0001',
                    akhir: StempelSidik(StatusTampil.dariKode('expired')),
                  ),
                  _daftar(onTap: () {}, akhir: const Text('88 hr')),
                ],
              ),
            ],
          ),
          tinggi: 1400,
        );
      },
    );

    for (final gelap in [false, true]) {
      testWidgets(
        'kontras teks dan pedoman sentuh (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          final semantik = tester.ensureSemantics();
          await tester.pumpWidget(
            aplikasiUji(
              Column(
                children: [
                  PanelBaris(
                    anak: [
                      _menu(onTap: () {}),
                      _menu(onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PanelBaris.daftar(
                    anak: [
                      _daftar(onTap: () {}),
                      _daftar(onTap: () {}),
                    ],
                  ),
                ],
              ),
              gelap: gelap,
            ),
          );
          expect(
            pelanggaranKontrasTeks(tester, find.byType(Column).first),
            isEmpty,
          );
          await periksaPedomanSentuh(tester);
          semantik.dispose();
        },
      );
    }
  });
}
