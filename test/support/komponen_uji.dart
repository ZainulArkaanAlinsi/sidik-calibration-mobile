// Perkakas uji komponen bersama Lab (`lib/widgets/sidik/`, Paket 2): pembungkus
// aplikasi bertema Lab, font asli (Inter, IBM Plex Mono, ikon Material) supaya
// lebar teks sama dengan HP, kontras WCAG dari POHON widget (bukan sampel
// piksel), pemeriksa pedoman sentuh + label, dan pengukur teks.
//
// Dipakai `test/komponen_sidik/*` dan harness `test/tampilan/render_komponen_lab_test.dart`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';

/// Memuat Inter, IBM Plex Mono, dan font ikon Material. Panggil di `setUpAll`.
Future<void> muatFontUji() async {
  for (final nama in ['Inter', 'IBMPlexMono']) {
    final pemuat = FontLoader(nama);
    for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/$nama-$b.ttf').readAsBytesSync();
      pemuat.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await pemuat.load();
  }
  final akar = Platform.environment['FLUTTER_ROOT'];
  if (akar == null) return;
  final ikon = File(
    '$akar/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!ikon.existsSync()) return;
  final pemuat = FontLoader('MaterialIcons')
    ..addFont(Future.value(ikon.readAsBytesSync().buffer.asByteData()));
  await pemuat.load();
}

/// Layar uji [lebar] x [tinggi] dp pada kerapatan 1,0; dikembalikan otomatis.
void layarUji(WidgetTester tester, {double lebar = 392, double tinggi = 852}) {
  tester.view
    ..physicalSize = Size(lebar, tinggi)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Teks ARB untuk bahasa [kode] (`id` atau `en`), tanpa pohon widget.
AppLocalizations l10nUji([String kode = 'id']) =>
    lookupAppLocalizations(Locale(kode));

/// Aplikasi uji: tema Lab, [skala] huruf, bahasa [bahasa] (`id` atau `en`), dan
/// [anak] di dalam `Scaffold`.
/// [bergulir] membungkus [anak] dalam halaman yang bisa digulir; matikan untuk
/// komponen yang mengisi tinggi sendiri (navigasi, Lajur).
Widget aplikasiUji(
  Widget anak, {
  bool gelap = false,
  double skala = 1.0,
  bool bergulir = true,
  bool rataBawah = false,
  String bahasa = 'id',
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: Locale(bahasa),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) => MediaQuery.withClampedTextScaling(
    minScaleFactor: skala,
    maxScaleFactor: skala,
    child: child!,
  ),
  home: Scaffold(
    body: bergulir
        ? SingleChildScrollView(child: anak)
        : (rataBawah
              ? Align(alignment: Alignment.bottomCenter, child: anak)
              : anak),
  ),
);

/// Rasio kontras WCAG 2.x antara dua warna buram.
double rasioKontras(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final terang = la > lb ? la : lb;
  final gelap = la > lb ? lb : la;
  return (terang + 0.05) / (gelap + 0.05);
}

/// Warna latar yang terlihat di belakang [elemen]: `Material`, kotak berlatar,
/// `ColoredBox`, atau `Scaffold` terdekat ke atas.
Color latarEfektif(Element elemen) {
  Color? hasil;
  elemen.visitAncestorElements((a) {
    final w = a.widget;
    Color? c;
    if (w is Material && w.type != MaterialType.transparency) {
      c = w.color;
    } else if (w is DecoratedBox && w.decoration is BoxDecoration) {
      c = (w.decoration as BoxDecoration).color;
    } else if (w is ColoredBox) {
      c = w.color;
    } else if (w is Scaffold) {
      c = w.backgroundColor ?? Theme.of(a).scaffoldBackgroundColor;
    }
    if (c != null && c.a > 0) {
      hasil = c;
      return false;
    }
    return true;
  });
  return hasil ?? Theme.of(elemen).scaffoldBackgroundColor;
}

/// Satu potong teks beserta warna dan latarnya yang terlihat.
typedef TeksTerukur = ({
  String teks,
  Color warna,
  Color latar,
  double ukuran,
  double rasio,
});

void _kumpul(
  InlineSpan span,
  TextStyle? ortu,
  void Function(String teks, TextStyle gaya) catat,
) {
  if (span is! TextSpan) return;
  final gaya = ortu == null
      ? span.style
      : (span.style == null ? ortu : ortu.merge(span.style));
  final teks = span.text;
  if (teks != null && teks.trim().isNotEmpty && gaya != null) {
    catat(teks, gaya);
  }
  for (final c in span.children ?? const <InlineSpan>[]) {
    _kumpul(c, gaya, catat);
  }
}

/// Semua teks di bawah [dalam] dengan rasio kontras terhadap latarnya.
List<TeksTerukur> ukurTeks(WidgetTester tester, Finder dalam) {
  final hasil = <TeksTerukur>[];
  final kotak = tester.widgetList<RichText>(
    find.descendant(of: dalam, matching: find.byType(RichText)),
  );
  for (final rt in kotak) {
    final elemen = tester.element(find.byWidget(rt));
    final latar = latarEfektif(elemen);
    _kumpul(rt.text, null, (teks, gaya) {
      final warna = gaya.color;
      if (warna == null) return;
      final nyata = Color.alphaBlend(warna, latar);
      hasil.add((
        teks: teks,
        warna: nyata,
        latar: latar,
        ukuran: gaya.fontSize ?? 0,
        rasio: rasioKontras(nyata, latar),
      ));
    });
  }
  return hasil;
}

/// Pelanggaran kontras teks (< [minimum]) di bawah [dalam]; kosong = lolos.
List<String> pelanggaranKontrasTeks(
  WidgetTester tester,
  Finder dalam, {
  double minimum = 4.5,
}) {
  final semua = ukurTeks(tester, dalam);
  expect(semua, isNotEmpty, reason: 'tidak ada teks berwarna yang terukur');
  return [
    for (final x in semua)
      if (x.rasio < minimum)
        '"${x.teks}" ${x.rasio.toStringAsFixed(2)}:1 < $minimum '
            '(teks ${x.warna} di latar ${x.latar})',
  ];
}

/// Pedoman Flutter: sasaran sentuh Android >= 48 dp dan label untuk setiap
/// sasaran sentuh. Wajib dipanggil di antara `ensureSemantics()` dan `dispose()`
/// milik pemanggil.
Future<void> periksaPedomanSentuh(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

/// Semua teks (gabungan) yang tampil di bawah [dalam].
String semuaTeks(WidgetTester tester, Finder dalam) => tester
    .widgetList<RichText>(
      find.descendant(of: dalam, matching: find.byType(RichText)),
    )
    .map((r) => r.text.toPlainText())
    .join('\n');

/// Pecah teks satu paragraf menjadi baris-baris yang dilihat pengguna.
List<String> barisTeks(RenderParagraph p) {
  final teks = p.text.toPlainText();
  final baris = <String>[];
  final sekarang = StringBuffer();
  double? atasTerakhir;
  for (var i = 0; i < teks.length; i++) {
    final kotak = p.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (kotak.isNotEmpty) {
      final atas = kotak.first.top;
      if (atasTerakhir != null && atas - atasTerakhir > 1) {
        baris.add(sekarang.toString());
        sekarang.clear();
      }
      atasTerakhir = atas;
    }
    sekarang.write(teks[i]);
  }
  if (sekarang.isNotEmpty) baris.add(sekarang.toString());
  return baris;
}

/// Semua warna isian yang dipakai pohon di bawah [dalam]: teks, ikon,
/// `DecoratedBox`, `ColoredBox`, dan `Material`. Untuk membuktikan sebuah
/// komponen TIDAK memakai warna tertentu (mis. hijau/merah di Lajur Bacaan).
Set<Color> semuaWarna(WidgetTester tester, Finder dalam) {
  final hasil = <Color>{};
  void tambah(Color? c) {
    if (c != null && c.a > 0) hasil.add(c.withAlpha(255));
  }

  for (final rt in tester.widgetList<RichText>(
    find.descendant(of: dalam, matching: find.byType(RichText)),
  )) {
    void jelajah(InlineSpan s) {
      if (s is TextSpan) {
        tambah(s.style?.color);
        s.children?.forEach(jelajah);
      }
    }

    jelajah(rt.text);
  }
  for (final i in tester.widgetList<Icon>(
    find.descendant(of: dalam, matching: find.byType(Icon)),
  )) {
    tambah(i.color);
  }
  for (final d in tester.widgetList<DecoratedBox>(
    find.descendant(of: dalam, matching: find.byType(DecoratedBox)),
  )) {
    final dek = d.decoration;
    if (dek is BoxDecoration) {
      tambah(dek.color);
      final b = dek.border;
      if (b is Border) {
        tambah(b.top.color);
        tambah(b.bottom.color);
      }
    }
  }
  for (final c in tester.widgetList<ColoredBox>(
    find.descendant(of: dalam, matching: find.byType(ColoredBox)),
  )) {
    tambah(c.color);
  }
  for (final m in tester.widgetList<Material>(
    find.descendant(of: dalam, matching: find.byType(Material)),
  )) {
    tambah(m.color);
  }
  return hasil;
}
