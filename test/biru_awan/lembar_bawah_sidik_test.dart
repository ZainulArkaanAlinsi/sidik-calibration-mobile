// LembarBawahSidik + tampilkanLembarBawahSidik (L2): sudut atas 32, pegangan
// 44 x 5, judul + tutup, maksimal 80 % layar dengan isi bergulir, tutup (tombol,
// latar, usap turun), kurangi gerak, Semantics, cincin fokus, sasaran 48,
// 320 dp x huruf 1,3.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/token_umpan_balik_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/lembar_bawah_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/toast_sidik.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _judul = 'Kirim sertifikat lewat';

/// Hasil terakhir lembar (null = belum selesai atau ditutup tanpa hasil).
String? _hasil;
bool _selesai = false;

Future<void> _buka(
  WidgetTester tester, {
  Widget isi = const Text('Email, WhatsApp, atau tautan.'),
  bool gelap = false,
  double skala = 1.0,
  double lebar = 392,
  double tinggi = 852,
  bool kurangi = false,
  bool tunggu = true,
}) async {
  _hasil = null;
  _selesai = false;
  layarUji(tester, lebar: lebar, tinggi: tinggi);
  Widget app = aplikasiUji(
    Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('pemicu'),
          onPressed: () async {
            _hasil = await tampilkanLembarBawahSidik<String>(
              context,
              judul: _judul,
              bangun: (_) => isi,
            );
            _selesai = true;
          },
          child: const Text('pemicu'),
        ),
      ),
    ),
    gelap: gelap,
    skala: skala,
    bergulir: false,
  );
  if (kurangi) app = kurangiGerak(app);
  await tester.pumpWidget(app);
  await tester.tap(find.byKey(const ValueKey('pemicu')));
  await tester.pump();
  if (tunggu) await tester.pump(const Duration(milliseconds: 400));
}

Finder get _lembar => find.byType(LembarBawahSidik);
Finder get _tutup => find.byType(TombolTutupSidik);

Widget _panjang(int n) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [for (var i = 0; i < n; i++) Text('Butir ${i + 1}')],
);

void main() {
  setUpAll(muatFontUji);

  group('bentuk dan token', () {
    testWidgets('sudut atas 32, pegangan 44 x 5, bantalan 10/16/20', (
      tester,
    ) async {
      await _buka(tester);
      final r = tester.getRect(_lembar);
      expect(r.width, 392, reason: 'selebar layar di HP');
      expect(r.bottom, 852, reason: 'menempel di bawah');
      final dekor = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _lembar, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(
        dekor.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(32)),
      );
      expect(dekor.color, bahan(tester).kertas);

      final u = WarnaUmpanBalikBiruAwan.of(tester.element(_lembar));
      final pegangan = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _lembar, matching: find.byType(DecoratedBox)),
          )
          .where((d) => (d.decoration as BoxDecoration).color == u.pegangan)
          .single;
      final rp = tester.getRect(find.byWidget(pegangan));
      expect(rp.size, const Size(44, 5));
      expect(rp.top - r.top, 10, reason: 'bantalan atas 10');
      expect(rp.center.dx, closeTo(196, 0.5), reason: 'di tengah');
      expect(tester.getRect(find.text(_judul)).left - r.left, 16);
      expect(
        r.bottom -
            tester.getRect(find.text('Email, WhatsApp, atau tautan.')).bottom,
        greaterThanOrEqualTo(20),
        reason: 'bantalan bawah 20',
      );
    });

    testWidgets('judul 20/26 800 tinta; tombol tutup 44 digambar, sasaran 48', (
      tester,
    ) async {
      await _buka(tester);
      final judul = tester.widget<Text>(find.text(_judul)).style!;
      expect(judul.fontSize, 20);
      expect(judul.fontWeight, FontWeight.w800);
      expect(judul.color, bahan(tester).tinta);
      expect(
        tester.getSize(_tutup),
        const Size(52, 52),
        reason: '44 + margin cincin 2 x 4: sasaran >= 48',
      );
      final gambar = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.close_rounded),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(gambar, const Size(44, 44));
    });

    testWidgets('isi panjang: tinggi <= 80 % layar dan bergulir', (
      tester,
    ) async {
      await _buka(tester, isi: _panjang(120));
      final r = tester.getRect(_lembar);
      expect(r.height, lessThanOrEqualTo(852 * 0.8 + 0.01));
      expect(r.height, closeTo(852 * 0.8, 1), reason: 'penuh sampai batas');
      expect(
        tester.getRect(find.text('Butir 120')).top,
        greaterThan(r.bottom),
        reason: 'butir terakhir di luar jendela lembar',
      );
      await tester.drag(find.text('Butir 3'), const Offset(0, -6000));
      await tester.pump();
      expect(
        tester.getRect(find.text('Butir 120')).bottom,
        lessThanOrEqualTo(r.bottom),
        reason: 'bisa digulir sampai butir terakhir',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('isi pendek: lembar membungkus isi (tidak mengisi 80 %)', (
      tester,
    ) async {
      await _buka(tester);
      expect(tester.getRect(_lembar).height, lessThan(852 * 0.4));
    });
  });

  group('menutup', () {
    testWidgets('tombol tutup menutup; hasil null', (tester) async {
      await _buka(tester);
      await tester.tap(_tutup);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_lembar, findsNothing);
      expect(_selesai, isTrue);
      expect(_hasil, isNull);
    });

    testWidgets('ketuk latar menutup; ketuk isi tidak', (tester) async {
      await _buka(tester);
      await tester.tap(find.text(_judul));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_lembar, findsOneWidget);
      await tester.tapAt(const Offset(196, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_lembar, findsNothing);
    });

    testWidgets('usap turun menutup; usap naik tidak', (tester) async {
      await _buka(tester);
      await tester.fling(find.text(_judul), const Offset(0, -200), 1500);
      await tester.pumpAndSettle();
      expect(_lembar, findsOneWidget, reason: 'usap naik diabaikan');
      await tester.fling(find.text(_judul), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      expect(_lembar, findsNothing);
      expect(_selesai, isTrue);
    });

    testWidgets('Navigator.pop membawa hasil', (tester) async {
      await _buka(tester);
      Navigator.of(tester.element(_lembar)).pop('email');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasil, 'email');
    });

    testWidgets('latar redup navy 42 %', (tester) async {
      await _buka(tester);
      final latar = tester.widget<AnimatedModalBarrier>(
        find.byType(AnimatedModalBarrier).last,
      );
      final u = WarnaUmpanBalikBiruAwan.of(tester.element(_lembar));
      expect(latar.color.value, u.scrim);
    });
  });

  group('gerak', () {
    testWidgets(
      'animasi masuk: belum di tempat di 60 ms, di tempat setelahnya',
      (tester) async {
        await _buka(tester, tunggu: false);
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          tester.getRect(_lembar).bottom,
          greaterThan(852),
          reason: 'masih naik dari bawah',
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getRect(_lembar).bottom, 852);
      },
    );

    testWidgets('kurangi gerak: langsung di tempat dan hilang seketika', (
      tester,
    ) async {
      await _buka(tester, kurangi: true, tunggu: false);
      await tester.pump();
      expect(tester.getRect(_lembar).bottom, 852);
      await tester.tap(_tutup);
      await tester.pump();
      await tester.pump();
      expect(_lembar, findsNothing);
    });
  });

  group('pembaca layar', () {
    testWidgets('judul header, tutup berlabel, pegangan tak terbaca', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _buka(tester);
      final header = tester
          .getSemantics(find.bySemanticsLabel(_judul).first)
          .getSemanticsData();
      expect(header.flagsCollection.isHeader, isTrue);
      // Latar modal juga bernama "Tutup" (label bawaan Material): ambil tombol
      // kita lewat induknya.
      final tutup = tester
          .getSemantics(
            find.descendant(
              of: find.byType(TombolTutupSidik),
              matching: find.bySemanticsLabel('Tutup'),
            ),
          )
          .getSemanticsData();
      expect(tutup.flagsCollection.isButton, isTrue);
      expect(tutup.hasAction(SemanticsAction.tap), isTrue);
      expect(semantikAktif(tutup), isTrue);
      await periksaPedomanSentuh(tester);
      handle.dispose();
    });
  });

  group('cincin fokus tombol tutup 44, tidak terpotong', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('geometri dan kontras ($nama)', (tester) async {
        await _buka(tester, gelap: gelap);
        for (var i = 0; i < 4; i++) {
          if (find.byKey(kunciCincinFokusUmpanBalik).evaluate().isNotEmpty) {
            break;
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        final cincinFinder = find.byKey(kunciCincinFokusUmpanBalik);
        expect(cincinFinder, findsOneWidget);
        final cincin = tester.getRect(cincinFinder);
        expect(cincin.size, const Size(52, 52), reason: '44 + 2 x (2 + 2)');
        final lembar = tester.getRect(_lembar);
        expect(
          lembar.inflate(0.01).contains(cincin.topLeft) &&
              lembar.inflate(0.01).contains(cincin.bottomRight),
          isTrue,
          reason: 'cincin utuh di dalam lembar',
        );
        final bentuk =
            (tester
                            .widget<DecoratedBox>(
                              find.descendant(
                                of: cincinFinder,
                                matching: find.byType(DecoratedBox),
                              ),
                            )
                            .decoration
                        as ShapeDecoration)
                    .shape
                as OutlinedBorder;
        expect(bentuk.side.width, AppUkuran.garisTebal);
        expect(
          rasioKontras(bentuk.side.color, bahan(tester).kertas),
          greaterThanOrEqualTo(ambangBukanTeks),
          reason: 'cincin/lembar ($nama)',
        );
      });
    }
  });

  group('huruf 1,3 pada 320 dp', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('judul panjang dan isi panjang tanpa luapan ($nama)', (
        tester,
      ) async {
        await _buka(
          tester,
          gelap: gelap,
          skala: 1.3,
          lebar: 320,
          isi: _panjang(60),
        );
        expect(tester.takeException(), isNull);
        final r = tester.getRect(_lembar);
        expect(r.width, 320);
        expect(r.height, lessThanOrEqualTo(852 * 0.8 + 0.01));
        expect(tester.getSize(_tutup).shortestSide, greaterThanOrEqualTo(48));
      });
    }
  });
}
