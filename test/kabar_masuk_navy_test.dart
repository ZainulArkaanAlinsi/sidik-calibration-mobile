// LapisanKabarMasuk memakai varian kabar navy `ToastSidik` (L2). Perilaku dedup,
// hitung mundur 5 detik, dan ketukan tetap diuji di `kabar_masuk_test.dart`
// (tidak diubah); di sini hanya yang baru: kartu navy berlogo, aksi "Buka",
// tombol tutup, Semantics, huruf 1,3 pada 320 dp, kurangi gerak.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/token_umpan_balik_biru_awan.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/kabar_toast.dart';
import 'package:sidik_calibration/models/notification_item.dart';
import 'package:sidik_calibration/providers/kabar_masuk_provider.dart';
import 'package:sidik_calibration/widgets/biru_awan/toast_sidik.dart';
import 'package:sidik_calibration/widgets/lapisan_kabar_masuk.dart';

import 'support/uji_biru_awan.dart';

class _Catat extends PenavigasiKabar {
  final tujuan = <NotifTautan?>[];
  int daftar = 0;

  @override
  void bukaTujuan(NotifTautan? tautan) => tujuan.add(tautan);

  @override
  void bukaDaftar() => daftar++;
}

Widget _app(
  _Catat nav, {
  bool gelap = false,
  double skala = 1.0,
  bool kurangi = false,
}) => ProviderScope(
  overrides: [penavigasiKabarProvider.overrideWithValue(nav)],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: kurangi,
        textScaler: TextScaler.linear(skala),
      ),
      child: LapisanKabarMasuk(child: child!),
    ),
    home: const Scaffold(body: SizedBox.expand()),
  ),
);

ProviderContainer _wadah(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first));

KabarToast _kabar(String judul, {String? id, NotifTautan? tautan}) =>
    KabarToast(judul: judul, isi: 'isi $judul', tautan: tautan, kunci: id);

Finder get _kartu => find.byKey(const ValueKey('kartu_kabar_masuk'));

void main() {
  setUpAll(muatFontUji);

  testWidgets('kartu = ToastSidik jenis kabar: navy, logo, Buka, tutup', (
    tester,
  ) async {
    layarUji(tester);
    await tester.pumpWidget(_app(_Catat()));
    _wadah(tester).read(kabarMasukProvider.notifier).tambahkan([
      _kabar('Lembar masuk', id: '1'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final toast = tester.widget<ToastSidik>(_kartu);
    expect(toast.jenis, JenisToast.kabar);
    expect(toast.judul, 'Lembar masuk');
    expect(toast.isi, 'isi Lembar masuk');
    expect(toast.aksi, 'Buka');
    expect(toast.wilayahHidup, isTrue);
    final u = WarnaUmpanBalikBiruAwan.of(tester.element(find.byType(Scaffold)));
    final dekor = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .first;
    expect(dekor.color, u.kabarLatar);
    expect(dekor.borderRadius, BorderRadius.circular(22));
    expect(
      find.descendant(of: _kartu, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(find.text('Buka'), findsOneWidget);
    expect(find.byType(TombolTutupSidik), findsOneWidget);
  });

  testWidgets('"Buka" membuka tujuan sekali dan menutup toast', (tester) async {
    final nav = _Catat();
    layarUji(tester);
    await tester.pumpWidget(_app(nav));
    const tujuan = NotifTautan(tipe: 'calibration', id: 7);
    _wadah(tester).read(kabarMasukProvider.notifier).tambahkan([
      _kabar('A', id: '1', tautan: tujuan),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Buka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(nav.tujuan.single?.id, 7);
    expect(nav.daftar, 0);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('tombol tutup menutup tanpa membuka tujuan', (tester) async {
    final nav = _Catat();
    layarUji(tester);
    await tester.pumpWidget(_app(nav));
    _wadah(
      tester,
    ).read(kabarMasukProvider.notifier).tambahkan([_kabar('A', id: '1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(TombolTutupSidik));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('A'), findsNothing);
    expect(nav.tujuan, isEmpty);
    expect(nav.daftar, 0);
    expect(_wadah(tester).read(kabarMasukProvider), isEmpty);
  });

  testWidgets('banyak kabar: "Buka" membuka daftar', (tester) async {
    final nav = _Catat();
    layarUji(tester);
    await tester.pumpWidget(_app(nav));
    _wadah(tester).read(kabarMasukProvider.notifier).tambahkan([
      _kabar('A', id: '1'),
      _kabar('B', id: '2'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 kabar baru'), findsOneWidget);
    await tester.tap(find.text('Buka'));
    await tester.pump();
    expect(nav.daftar, 1);
    expect(nav.tujuan, isEmpty);
  });

  testWidgets('Semantics: live region "judul. isi" + tombol Buka dan Tutup', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    layarUji(tester);
    await tester.pumpWidget(_app(_Catat()));
    _wadah(
      tester,
    ).read(kabarMasukProvider.notifier).tambahkan([_kabar('A', id: '1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final teks = tester
        .getSemantics(find.bySemanticsLabel('A. isi A'))
        .getSemanticsData();
    expect(teks.flagsCollection.isLiveRegion, isTrue);
    expect(teks.hasAction(SemanticsAction.tap), isTrue, reason: 'ketuk kartu');
    for (final nama in ['Buka', 'Tutup']) {
      final d = tester
          .getSemantics(find.bySemanticsLabel(nama))
          .getSemanticsData();
      expect(d.flagsCollection.isButton, isTrue, reason: nama);
      expect(d.hasAction(SemanticsAction.tap), isTrue, reason: nama);
    }
    await periksaPedomanSentuh(tester);
    handle.dispose();
    await tester.pump(const Duration(seconds: 6));
  });

  for (final gelap in [false, true]) {
    final nama = gelap ? 'gelap' : 'terang';
    testWidgets('huruf 1,3 pada 320 dp: tanpa luapan, di dalam layar ($nama)', (
      tester,
    ) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(_app(_Catat(), gelap: gelap, skala: 1.3));
      _wadah(tester).read(kabarMasukProvider.notifier).tambahkan([
        _kabar('Lembar kerja baru masuk antrean approval', id: '1'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final r = tester.getRect(_kartu);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
      expect(r.top, greaterThanOrEqualTo(16));
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('kurangi gerak: penuh di satu frame, tanpa animasi', (
    tester,
  ) async {
    layarUji(tester);
    await tester.pumpWidget(_app(_Catat(), kurangi: true));
    _wadah(
      tester,
    ).read(kabarMasukProvider.notifier).tambahkan([_kabar('A', id: '1')]);
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(tester.getRect(_kartu).top, 16);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('A'), findsNothing);
  });
}
