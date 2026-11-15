import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/config/lab_profile.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/auth/splash_screen.dart';
import 'package:sidik_calibration/screens/auth/widgets/kerangka_masuk.dart';

import 'support/uji_biru_awan.dart';

/// Splash Biru Awan (L5, artboard E1): timeline SEKALI jalan dengan urutan dan
/// durasi dari `docs/desain-ulang/ELEMEN.md` §Splash. Tes lama
/// (`scene3d_test.dart` "splash berhenti sendiri", golden `splash`) tetap ada;
/// berkas ini menjaga jadwalnya, kurangi gerak, dan tanpa pengulangan.
Widget _aplikasi({
  bool gelap = false,
  double skala = 1.0,
  bool kurangiGerak = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('id'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) {
    var anak = child!;
    if (kurangiGerak) {
      anak = MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: anak,
      );
    }
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: skala,
      maxScaleFactor: skala,
      child: anak,
    );
  },
  home: const SplashScreen(),
);

/// Nilai tiap tahap (0..1) pada bingkai yang sedang tampil.
typedef _Keadaan = ({
  double cincin,
  double plat,
  bool sapuan,
  double nama,
  double tagline,
  double perusahaan,
});

_Keadaan _baca(WidgetTester tester) {
  double opasitas(String kunci) =>
      tester.widget<Opacity>(find.byKey(Key(kunci))).opacity;
  final cincin =
      tester.widget<CustomPaint>(find.byKey(const Key('splash-cincin')))
          .painter!
          as PelukisCincinSplash;
  return (
    cincin: cincin.progres,
    plat: opasitas('splash-plat'),
    sapuan: find.byKey(const Key('splash-sapuan')).evaluate().isNotEmpty,
    nama: opasitas('splash-nama'),
    tagline: opasitas('splash-tagline'),
    perusahaan: opasitas('splash-perusahaan'),
  );
}

void main() {
  setUpAll(muatFontUji);

  group('timeline sekali jalan', () {
    testWidgets('urutan dan durasi mengikuti ELEMEN.md §Splash', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(_aplikasi());
      await tester.pump();

      // Bingkai pertama: semuanya belum tampil, tetapi trek cincin ada.
      var k = _baca(tester);
      expect(k.cincin, 0.0);
      expect(k.plat, 0.0);
      expect(k.sapuan, isFalse);
      expect(k.nama, 0.0);
      expect(k.tagline, 0.0);
      expect(k.perusahaan, 0.0);

      // Pindai tiap 10 ms; catat kapan tiap tahap mulai (> 0) dan penuh (== 1).
      final mulai = <String, int>{};
      final penuh = <String, int>{};
      void catat(String nama, double nilai, int ms) {
        if (nilai > 0 && !mulai.containsKey(nama)) mulai[nama] = ms;
        if (nilai >= 1 && !penuh.containsKey(nama)) penuh[nama] = ms;
      }

      var sapuanMulai = -1;
      var sapuanSelesai = -1;
      for (var ms = 10; ms <= 1800; ms += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        k = _baca(tester);
        catat('cincin', k.cincin, ms);
        catat('plat', k.plat, ms);
        catat('nama', k.nama, ms);
        catat('tagline', k.tagline, ms);
        catat('perusahaan', k.perusahaan, ms);
        if (k.sapuan && sapuanMulai < 0) sapuanMulai = ms;
        if (!k.sapuan && sapuanMulai >= 0 && sapuanSelesai < 0) {
          sapuanSelesai = ms;
        }
      }

      // Toleransi 20 ms: pemindaian 10 ms, kurva mulai dari nol.
      void dekat(String nama, Map<String, int> peta, int harapan) {
        expect(
          peta[nama],
          isNotNull,
          reason: '$nama tidak pernah ${identical(peta, mulai) ? 'mulai' : 'penuh'}',
        );
        expect(
          peta[nama]!.toDouble(),
          closeTo(harapan.toDouble(), 20),
          reason: '$nama: ${peta[nama]} ms, harapan $harapan ms',
        );
      }

      // Mulai: cincin 100, plat 500, nama 1100, tagline 1250, nama PT 1400.
      dekat('cincin', mulai, 100);
      dekat('plat', mulai, 500);
      dekat('nama', mulai, 1100);
      dekat('tagline', mulai, 1250);
      dekat('perusahaan', mulai, 1400);
      // Penuh: cincin 700 ms (800), plat 420 ms (920), tiga teks 280 ms.
      dekat('cincin', penuh, 800);
      dekat('plat', penuh, 920);
      dekat('nama', penuh, 1380);
      dekat('tagline', penuh, 1530);
      dekat('perusahaan', penuh, 1680);
      // Sapuan cahaya: 600 ms, mulai 900 ms.
      expect(sapuanMulai, closeTo(900, 20));
      expect(sapuanSelesai, closeTo(1500, 20));

      // Urutannya sendiri, tanpa tumpang tindih terbalik.
      final urutan = [
        mulai['cincin']!,
        mulai['plat']!,
        sapuanMulai,
        mulai['nama']!,
        mulai['tagline']!,
        mulai['perusahaan']!,
      ];
      expect(urutan, orderedEquals([...urutan]..sort()));
      expect(urutan.toSet().length, urutan.length);

      // Selesai: keadaan akhir diam. Total 1680 ms, lalu tidak ada bingkai.
      expect(k.cincin, 1.0);
      expect(k.plat, 1.0);
      expect(k.nama, 1.0);
      expect(k.tagline, 1.0);
      expect(k.perusahaan, 1.0);
      expect(k.sapuan, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      expect(JadwalSplash.total, 1680);
    });

    for (final gelap in [false, true]) {
      testWidgets('tanpa pengulangan: pumpAndSettle selesai (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        layarUji(tester);
        await tester.pumpWidget(_aplikasi(gelap: gelap));
        // `pumpAndSettle` melempar kalau masih ada bingkai sesudah 10 menit
        // waktu uji; satu `repeat()` di splash membuatnya gagal di sini.
        final bingkai = await tester.pumpAndSettle();
        expect(bingkai, greaterThan(1));
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);

        // Sesudah itu tetap diam, berapa lama pun.
        await tester.pump(const Duration(seconds: 30));
        expect(_baca(tester).cincin, 1.0);
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }
  });

  group('kurangi gerak', () {
    for (final gelap in [false, true]) {
      testWidgets('langsung keadaan akhir, tanpa animasi (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        layarUji(tester);
        await tester.pumpWidget(_aplikasi(gelap: gelap, kurangiGerak: true));
        await tester.pump();

        final k = _baca(tester);
        expect(k.cincin, 1.0);
        expect(k.plat, 1.0);
        expect(k.nama, 1.0);
        expect(k.tagline, 1.0);
        expect(k.perusahaan, 1.0);
        expect(k.sapuan, isFalse, reason: 'sapuan cahaya ikut animasi');
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);

        // Semua kata sudah tampil sejak bingkai pertama.
        expect(find.text(namaMerekSidikLab), findsOneWidget);
        expect(find.text('Kalibrasi terakreditasi KAN'), findsOneWidget);
        expect(find.text(LabProfile.nama), findsOneWidget);
      });
    }
  });

  group('tampilan', () {
    for (final gelap in [false, true]) {
      testWidgets('huruf 1,3 pada lebar 320 tanpa luapan (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        layarUji(tester, lebar: 320, tinggi: 568);
        await tester.pumpWidget(_aplikasi(gelap: gelap, skala: 1.3));
        // Di tengah timeline dan sesudah selesai.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull, reason: 'meluap di tengah');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'meluap di akhir');
        expect(find.text(LabProfile.nama), findsOneWidget);
      });
    }

    testWidgets('pembaca layar: tiga teks, nama produk berupa judul', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(_aplikasi());
      await tester.pumpAndSettle();

      final nama = tester.getSemantics(find.text(namaMerekSidikLab));
      expect(nama.flagsCollection.isHeader, isTrue);
      expect(nama.label, namaMerekSidikLab);
      expect(find.bySemanticsLabel('Kalibrasi terakreditasi KAN'), findsOne);
      expect(find.bySemanticsLabel(LabProfile.nama), findsOne);
      // Logo dan cincin hiasan: tidak ada simpul bergambar.
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).excludeFromSemantics,
        isTrue,
      );
      semantik.dispose();
    });

    testWidgets('teks yang terbaca ada di bahasa Inggris juga', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const SplashScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('KAN-accredited calibration'), findsOneWidget);
    });

    for (final gelap in [false, true]) {
      testWidgets('semua teks terbaca >= 4,5:1 (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        layarUji(tester);
        await tester.pumpWidget(_aplikasi(gelap: gelap));
        await tester.pumpAndSettle();
        expect(
          pelanggaranKontrasTeks(tester, find.byType(SplashScreen)),
          isEmpty,
        );
      });
    }
  });
}
