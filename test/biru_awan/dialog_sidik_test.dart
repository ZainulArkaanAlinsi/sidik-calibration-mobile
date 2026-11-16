// DialogSidik + tampilkanDialogSidik (L2): kartu 340/420, radius 28, ubin 56,
// Batal kiri dan aksi kanan (bahaya merah), latar redup, hasil bool, Semantics,
// tutup (Batal, ketuk latar, tombol kembali), kurangi gerak, cincin fokus,
// sasaran 48, 320 dp x huruf 1,3.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/token_umpan_balik_biru_awan.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/dialog_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _judul = 'Kirim untuk approval?';
const _isi =
    'Lembar kerja tidak bisa diubah setelah dikirim, kecuali admin meminta '
    'revisi.';

/// Hasil terakhir `tampilkanDialogSidik` (null = belum selesai).
bool? _hasil;

Future<void> _buka(
  WidgetTester tester, {
  bool bahaya = false,
  String aksi = 'Kirim',
  String? batal = 'Batal',
  String isi = _isi,
  bool gelap = false,
  double skala = 1.0,
  double lebar = 392,
  double tinggi = 852,
  bool kurangi = false,
  bool tunggu = true,
}) async {
  _hasil = null;
  layarUji(tester, lebar: lebar, tinggi: tinggi);
  Widget app = aplikasiUji(
    Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('pemicu'),
          onPressed: () async {
            _hasil = await tampilkanDialogSidik(
              context,
              ikon: Icons.send_outlined,
              judul: _judul,
              isi: isi,
              aksi: aksi,
              batal: batal,
              bahaya: bahaya,
            );
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
  if (tunggu) await tester.pump(const Duration(milliseconds: 300));
}

Finder get _kartu => find.byType(DialogSidik);
Finder get _tombolAksi => find.byWidgetPredicate(
  (w) => w is TombolSidik && w.ragam != RagamTombolSidik.sekunder,
);
Finder get _tombolBatal => find.byWidgetPredicate(
  (w) => w is TombolSidik && w.ragam == RagamTombolSidik.sekunder,
);

void main() {
  setUpAll(muatFontUji);

  group('kartu: ukuran, bentuk, token', () {
    testWidgets('lebar 340 (HP), radius 28, padding 24, ubin 56/20, bayangan', (
      tester,
    ) async {
      await _buka(tester);
      final r = tester.getRect(_kartu);
      expect(r.width, 340);
      expect(r.center.dx, closeTo(392 / 2, 0.5), reason: 'di tengah');
      final dekor = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
      expect(dekor.borderRadius, BorderRadius.circular(28));
      expect(dekor.color, bahan(tester).kertas);
      expect(dekor.boxShadow!.single.offset, const Offset(0, 20));
      expect(dekor.boxShadow!.single.blurRadius, 50);

      // Ubin 56 dengan sudut 20 di bantalan 24.
      final ubin = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.send_outlined),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(ubin.size, const Size(56, 56));
      expect(ubin.left - r.left, 24);
      expect(ubin.top - r.top, 24);
      final dekorUbin = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius == BorderRadius.circular(20));
      expect(dekorUbin.color, warna(tester).isi(IsiBiruAwan.kabut));
    });

    testWidgets('lebar 420 di layar >= 600', (tester) async {
      await _buka(tester, lebar: 800);
      expect(tester.getSize(_kartu).width, 420);
    });

    testWidgets('judul 20/26 800 tinta; isi 14/20 tinta kedua', (tester) async {
      await _buka(tester);
      final judul = tester.widget<Text>(find.text(_judul)).style!;
      expect(judul.fontSize, 20);
      expect(judul.height, closeTo(26 / 20, 0.001));
      expect(judul.fontWeight, FontWeight.w800);
      expect(judul.color, bahan(tester).tinta);
      final isi = tester.widget<Text>(find.text(_isi)).style!;
      expect(isi.fontSize, 14);
      expect(isi.height, closeTo(20 / 14, 0.001));
      expect(isi.color, bahan(tester).tinta2);
    });

    testWidgets('Batal di kiri (sekunder 48), aksi di kanan (tegas 48)', (
      tester,
    ) async {
      await _buka(tester);
      final batal = tester.getRect(_tombolBatal);
      final aksi = tester.getRect(_tombolAksi);
      expect(batal.left, lessThan(aksi.left));
      expect(batal.top, aksi.top);
      expect(batal.height, 48);
      expect(aksi.height, 48);
      expect(aksi.left - batal.right, 10);
      expect(batal.width, closeTo(aksi.width, 0.5), reason: 'sama lebar');
      expect(
        tester.widget<TombolSidik>(_tombolAksi).ragam,
        RagamTombolSidik.tegas,
      );
      expect(find.text('OK'), findsNothing);
      expect(find.text('Ya'), findsNothing);
    });

    testWidgets('tanpa Batal: satu tombol aksi penuh', (tester) async {
      await _buka(tester, batal: null);
      expect(_tombolBatal, findsNothing);
      expect(
        tester.getRect(_tombolAksi).width,
        340 - 48,
        reason: 'selebar isi kartu',
      );
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('bahaya: aksi merah, ubin koral tipis ($nama)', (
        tester,
      ) async {
        await _buka(tester, bahaya: true, aksi: 'Hapus', gelap: gelap);
        final tombol = tester.widget<TombolSidik>(_tombolAksi);
        expect(tombol.ragam, RagamTombolSidik.bahaya);
        expect(tombol.label, 'Hapus');
        final isi = tester
            .widget<FilledButton>(
              find.descendant(
                of: _tombolAksi,
                matching: find.byType(FilledButton),
              ),
            )
            .style!
            .backgroundColor!
            .resolve({});
        expect(isi, skemaWarna(tester).error);
        expect(
          rasioKontras(skemaWarna(tester).onError, skemaWarna(tester).error),
          greaterThanOrEqualTo(4.5),
        );
        final dekorUbin = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.borderRadius == BorderRadius.circular(20));
        expect(dekorUbin.color, warna(tester).isi(IsiBiruAwan.koralTipis));
      });
    }
  });

  group('membuka dan menutup: hasil bool', () {
    testWidgets('latar redup navy 42 % dan kartu di atasnya', (tester) async {
      await _buka(tester);
      final latar = tester.widget<AnimatedModalBarrier>(
        find.byType(AnimatedModalBarrier).last,
      );
      final u = WarnaUmpanBalikBiruAwan.of(tester.element(_kartu));
      expect(latar.color.value, u.scrim);
      expect(u.scrim.a, closeTo(0.42, 0.005));
    });

    testWidgets('aksi mengembalikan true dan menutup', (tester) async {
      await _buka(tester);
      await tester.tap(_tombolAksi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_hasil, isTrue);
      expect(_kartu, findsNothing);
    });

    testWidgets('Batal mengembalikan false', (tester) async {
      await _buka(tester);
      await tester.tap(_tombolBatal);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_hasil, isFalse);
      expect(_kartu, findsNothing);
    });

    testWidgets('ketuk latar mengembalikan false; ketuk kartu tidak menutup', (
      tester,
    ) async {
      await _buka(tester);
      await tester.tapAt(tester.getRect(_kartu).center);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_kartu, findsOneWidget, reason: 'ketuk isi kartu tidak menutup');
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_hasil, isFalse);
      expect(_kartu, findsNothing);
    });

    testWidgets('tombol kembali sistem menutup dengan false', (tester) async {
      await _buka(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_hasil, isFalse);
      expect(_kartu, findsNothing);
    });

    testWidgets('pudar 240 ms: mulai transparan, penuh di 300 ms', (
      tester,
    ) async {
      await _buka(tester, tunggu: false);
      await tester.pump(const Duration(milliseconds: 60));
      double opasitas() => tester
          .widget<FadeTransition>(
            find
                .ancestor(of: _kartu, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
      expect(opasitas(), inInclusiveRange(0.01, 0.99));
      await tester.pump(const Duration(milliseconds: 240));
      expect(opasitas(), 1.0);
    });

    testWidgets('kurangi gerak: penuh di satu frame, hilang tanpa animasi', (
      tester,
    ) async {
      await _buka(tester, kurangi: true, tunggu: false);
      final op = tester
          .widget<FadeTransition>(
            find
                .ancestor(of: _kartu, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
      expect(op, 1.0);
      await tester.tap(_tombolAksi);
      await tester.pump();
      await tester.pump();
      expect(_kartu, findsNothing, reason: 'tanpa animasi keluar');
      expect(_hasil, isTrue);
    });
  });

  group('pembaca layar', () {
    testWidgets('rute bernama judul; tombol berlabel dan aktif', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _buka(tester);
      final rute = tester
          .getSemantics(find.bySemanticsLabel(_judul).first)
          .getSemanticsData();
      expect(rute.flagsCollection.namesRoute, isTrue);
      expect(rute.flagsCollection.scopesRoute, isTrue);
      for (final nama in ['Kirim', 'Batal']) {
        final d = tester
            .getSemantics(find.bySemanticsLabel(nama))
            .getSemanticsData();
        expect(d.flagsCollection.isButton, isTrue, reason: nama);
        expect(d.hasAction(SemanticsAction.tap), isTrue, reason: nama);
        expect(semantikAktif(d), isTrue, reason: nama);
      }
      handle.dispose();
    });

    testWidgets('pedoman: sasaran >= 48 dan berlabel', (tester) async {
      final handle = tester.ensureSemantics();
      await _buka(tester, bahaya: true, aksi: 'Hapus');
      await periksaPedomanSentuh(tester);
      handle.dispose();
    });
  });

  group('cincin fokus tombol di dalam dialog, kontras >= 3:1', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('Tab memfokuskan tombol; cincin lawan kartu ($nama)', (
        tester,
      ) async {
        await _buka(tester, gelap: gelap);
        for (var i = 0; i < 4; i++) {
          if (find.byKey(kunciCincinFokusTombol).evaluate().isNotEmpty) break;
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        final cincin = find.byKey(kunciCincinFokusTombol);
        expect(cincin, findsOneWidget);
        final garis =
            ((tester
                        .widget<DecoratedBox>(
                          find.descendant(
                            of: cincin,
                            matching: find.byType(DecoratedBox),
                          ),
                        )
                        .decoration
                    as BoxDecoration)
                .border!
                .top);
        expect(garis.width, AppUkuran.garisTebal);
        expect(
          rasioKontras(garis.color, bahan(tester).kertas),
          greaterThanOrEqualTo(ambangBukanTeks),
          reason: 'cincin/kartu dialog ($nama)',
        );
        final kartu = tester.getRect(_kartu);
        expect(
          kartu.inflate(0.01).contains(tester.getRect(cincin).topLeft) &&
              kartu.inflate(0.01).contains(tester.getRect(cincin).bottomRight),
          isTrue,
          reason: 'cincin tidak terpotong kartu',
        );
      });
    }
  });

  group('huruf 1,3 pada 320 dp', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('tanpa luapan; tombol bertumpuk, aksi di atas ($nama)', (
        tester,
      ) async {
        await _buka(
          tester,
          gelap: gelap,
          skala: 1.3,
          lebar: 320,
          aksi: 'Tarik sertifikat',
          bahaya: true,
        );
        expect(tester.takeException(), isNull);
        final kartu = tester.getRect(_kartu);
        expect(kartu.left, greaterThanOrEqualTo(0));
        expect(kartu.right, lessThanOrEqualTo(320));
        final aksi = tester.getRect(_tombolAksi);
        final batal = tester.getRect(_tombolBatal);
        expect(
          aksi.bottom,
          lessThanOrEqualTo(batal.top),
          reason: 'aksi di atas',
        );
        expect(aksi.height, greaterThanOrEqualTo(48));
        expect(batal.height, greaterThanOrEqualTo(48));
        expect(aksi.width, batal.width);
      });
    }

    testWidgets(
      'isi sangat panjang di layar pendek: isi bergulir, tombol tetap',
      (tester) async {
        await _buka(
          tester,
          skala: 1.3,
          lebar: 320,
          tinggi: 480,
          isi: List.filled(80, 'penjelasan panjang dari server').join(' '),
        );
        expect(tester.takeException(), isNull);
        final kartu = tester.getRect(_kartu);
        expect(kartu.top, greaterThanOrEqualTo(0));
        expect(kartu.bottom, lessThanOrEqualTo(480));
        expect(tester.getRect(_tombolAksi).bottom, lessThanOrEqualTo(480));
      },
    );

    testWidgets('layar 392 dp tanpa huruf besar: tombol berdampingan', (
      tester,
    ) async {
      await _buka(tester);
      expect(tester.getRect(_tombolAksi).top, tester.getRect(_tombolBatal).top);
    });
  });
}
