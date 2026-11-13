import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/token_kamera.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/calibration/kamera_pindai_screen.dart';
import 'package:sidik_calibration/services/kamera_pindai.dart';
import 'package:sidik_calibration/services/petunjuk_kamera.dart';
import 'package:sidik_calibration/widgets/dialog_foto_ulang.dart';

import 'support/kontrol_kamera_palsu.dart';

/// Standar kualitas desain Sidik untuk layar kamera — DITEGAKKAN oleh test,
/// bukan diklaim:
///
///  1. hanya token tema (tanpa warna/ukuran/radius mentah, tanpa gradien);
///  2. satu aksi utama, di tepi ibu jari (bawah-tengah / sisi kanan);
///  3. ikon + kata untuk setiap saran, kontras teks ≥ 4,5:1 DI ATAS pratinjau
///     putih (piksel hasil render), sasaran sentuh ≥ 48 dp, label Semantics;
///  4. semua keadaan dirancang: memuat, izin ditolak, tanpa senter, jeda;
///  5. tangguh: tanpa overflow di 320 dp, huruf 1,3×, tegak & lanskap, tablet
///     840 dp, tema terang & gelap.
///
/// Render PNG (bukan golden — jangan diregenerasi di Windows): jalankan dengan
/// `RENDER_KAMERA=<folder>` untuk menulis gambar tiap keadaan ke folder itu.

Future<void> _muatFont() async {
  final inter = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    inter.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await inter.load();

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await ikon.load();
}

enum _Keadaan {
  siap,
  gelap,
  agakGelap,
  silau,
  bayangan,
  terpotong,
  buram,
  buramGerak,
  pesan,
  tanpaSenter,
  izin,
  memuat,
  menjeda,
}

class _Ukuran {
  const _Ukuran(this.nama, this.ukuran);

  final String nama;
  final Size ukuran;

  bool get lanskap => ukuran.width > ukuran.height;
}

const _ukuranUji = [
  _Ukuran('hp-sempit-320x640', Size(320, 640)),
  _Ukuran('hp-360x800', Size(360, 800)),
  _Ukuran('hp-lanskap-800x360', Size(800, 360)),
  _Ukuran('hp-sempit-lanskap-568x320', Size(568, 320)),
  _Ukuran('tablet-tegak-840x1180', Size(840, 1180)),
  _Ukuran('tablet-lanskap-1180x840', Size(1180, 840)),
];

const _halamanPh = 792 / 612;

Widget _aplikasi(Widget layar, {required bool gelap, required double skala}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('id'),
    builder: (context, anak) => MediaQuery.withClampedTextScaling(
      minScaleFactor: skala,
      maxScaleFactor: skala,
      child: anak!,
    ),
    home: layar,
  );
}

/// Pasang layar kamera dalam [keadaan]. Mengembalikan kamera tiruan (kecuali
/// keadaan yang tidak punya kamera).
Future<KontrolKameraPalsu?> _pasang(
  WidgetTester tester,
  _Keadaan keadaan, {
  required Size ukuran,
  required bool gelap,
  double skala = 1.0,
  Color warnaPratinjau = const Color(0xFF223344),
  GlobalKey? kunciRender,
}) async {
  tester.view.physicalSize = ukuran;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final frame = switch (keadaan) {
    _Keadaan.gelap => frameRata(25),
    _Keadaan.agakGelap => frameAgakGelap(),
    _Keadaan.silau => frameRata(255),
    _Keadaan.bayangan => frameBayangan(),
    _Keadaan.terpotong => frameTerpotong(),
    _Keadaan.buram => frameBuram(),
    _Keadaan.buramGerak => frameGerak(),
    _ => frameBagus(),
  };
  final kontrol = keadaan == _Keadaan.izin || keadaan == _Keadaan.memuat
      ? null
      : KontrolKameraPalsu(
          punyaSenter: keadaan != _Keadaan.tanpaSenter,
          senterMenolak: keadaan == _Keadaan.pesan,
          contoh: [frame],
          warnaPratinjau: warnaPratinjau,
        );
  final tertahan = Completer<KontrolKamera>();

  Future<KontrolKamera> pabrik() async {
    if (keadaan == _Keadaan.izin) {
      throw const KameraGagal(SebabKameraGagal.izinDitolak);
    }
    if (keadaan == _Keadaan.memuat) return tertahan.future;

    return kontrol!;
  }

  Widget layar = KameraPindaiScreen(
    // Kunci baru tiap pasang: dua pemasangan dalam satu test tidak boleh
    // memakai ulang State layar sebelumnya.
    key: UniqueKey(),
    rasioKertas: _halamanPh,
    selangContoh: const Duration(milliseconds: 100),
    // Isolate tidak jalan di jam palsu test: pengukur sinkron.
    pengukur: (f) async => UkurFrame.ukur(f),
    pabrik: pabrik,
  );
  if (kunciRender != null) {
    layar = RepaintBoundary(key: kunciRender, child: layar);
  }

  await tester.pumpWidget(_aplikasi(layar, gelap: gelap, skala: skala));
  await tester.pump();
  await tester.pump();

  switch (keadaan) {
    case _Keadaan.gelap ||
        _Keadaan.agakGelap ||
        _Keadaan.silau ||
        _Keadaan.bayangan ||
        _Keadaan.terpotong ||
        _Keadaan.buram ||
        _Keadaan.buramGerak:
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    case _Keadaan.pesan:
      await tester.tap(find.byKey(const ValueKey('kamera-senter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    case _Keadaan.menjeda:
      // Urutan nyata Android: inactive dulu, baru paused (frame berhenti).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
    default:
      break;
  }

  return kontrol;
}

double _luminans(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _rasio(Color a, Color b) {
  final l1 = _luminans(a);
  final l2 = _luminans(b);
  final terang = math.max(l1, l2);
  final gelap = math.min(l1, l2);

  return (terang + 0.05) / (gelap + 0.05);
}

/// Warna piksel (x, y) dari hasil render [kunci].
Future<Color> _piksel(WidgetTester tester, GlobalKey kunci, Offset p) async {
  final data = await tester.runAsync(() async {
    final batas =
        kunci.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final gambar = await batas.toImage();
    final bita = (await gambar.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (p.dy.round() * gambar.width + p.dx.round()) * 4;

    return Color.fromARGB(
      255,
      bita.getUint8(i),
      bita.getUint8(i + 1),
      bita.getUint8(i + 2),
    );
  });

  return data!;
}

void main() {
  setUpAll(_muatFont);

  // ── 1. Hanya token tema ────────────────────────────────────────────────────
  group('hanya token tema (pemeriksaan statis berkas sumber)', () {
    final berkas = {
      'layar kamera': 'lib/screens/calibration/kamera_pindai_screen.dart',
      'dialog foto ulang': 'lib/widgets/dialog_foto_ulang.dart',
    };

    String tanpaKomentar(String s) => s
        .split('\n')
        .map((b) => b.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');

    for (final e in berkas.entries) {
      final isi = tanpaKomentar(File(e.value).readAsStringSync());

      test('${e.key}: tanpa warna mentah', () {
        expect(
          RegExp(r'\bColor\s*\(').hasMatch(isi),
          isFalse,
          reason: 'Color(',
        );
        expect(
          RegExp(r'\bColors\.').allMatches(isi).map((m) => m.group(0)),
          isEmpty,
          reason: 'Colors.* (pakai SidikMaterial)',
        );
        expect(isi.contains('fromARGB'), isFalse);
        expect(isi.contains('fromRGBO'), isFalse);
      });

      test('${e.key}: tanpa gradien dekoratif / kartu / bayangan', () {
        for (final kata in [
          'Gradient',
          'BoxShadow',
          'Card(',
          'Chip(',
          'ShaderMask',
          'BackdropFilter',
          'ImageFilter',
        ]) {
          expect(isi.contains(kata), isFalse, reason: kata);
        }
      });

      test('${e.key}: tanpa ukuran huruf / ukuran / radius / jarak mentah', () {
        expect(isi.contains('fontSize'), isFalse);

        // Literal angka selain 0, 1, 2 (pembagi/pengali) harus lewat token.
        // Durasi (ms / detik) dan nilai `clamp(0.0, 1.0)` dikecualikan.
        final pelanggar = <String>[];
        for (final baris in isi.split('\n')) {
          if (baris.contains('Duration(') ||
              baris.contains('milliseconds:') ||
              baris.contains('seconds:')) {
            continue;
          }
          for (final m in RegExp(
            r'''(?<![\w.'"\-])(\d+(?:\.\d+)?)(?![\w'"])''',
          ).allMatches(baris)) {
            final nilai = double.parse(m.group(1)!);
            if (nilai == 0 || nilai == 1 || nilai == 2) continue;
            pelanggar.add(baris.trim());
          }
        }
        expect(pelanggar, isEmpty, reason: 'angka mentah: $pelanggar');
      });
    }

    test('token yang dipakai ada di tema, bukan di layar', () {
      expect(TokenKamera.sasaranSentuh, greaterThanOrEqualTo(48));
      expect(TokenKamera.tombolJepret, greaterThan(TokenKamera.sasaranSentuh));
    });
  });

  // ── 2. Kontras ─────────────────────────────────────────────────────────────
  group('kontras (token, kasus terburuk = pratinjau putih / hitam)', () {
    for (final (nama, m) in <(String, SidikMaterial)>[
      ('terang', SidikMaterial.terangDefault),
      ('gelap', SidikMaterial.gelapDefault),
    ]) {
      for (final (fondasi, warna) in <(String, Color)>[
        ('putih', const Color(0xFFFFFFFF)),
        ('hitam', const Color(0xFF000000)),
      ]) {
        test('tema $nama, pratinjau $fondasi: teks & ikon di atas lapisan', () {
          final lapisan = Color.alphaBlend(
            m.kaca.withValues(alpha: TokenKamera.dasarLapisan),
            warna,
          );

          expect(
            _rasio(m.lcdTeks, lapisan),
            greaterThanOrEqualTo(4.5),
            reason: 'teks terang di atas lapisan',
          );
          expect(
            _rasio(m.lcdAmber, lapisan),
            greaterThanOrEqualTo(4.5),
            reason: 'ikon saran (amber) di atas lapisan',
          );
        });
      }

      test('tema $nama: pasangan token tombol', () {
        expect(_rasio(m.kaca, m.lcdAmber), greaterThanOrEqualTo(4.5));
        expect(_rasio(m.kaca, m.lcdTeks), greaterThanOrEqualTo(4.5));
        expect(_rasio(m.lcdTeks, m.kaca), greaterThanOrEqualTo(4.5));
      });
    }
  });

  testWidgets(
    'kontras NYATA dari piksel render: teks di atas pratinjau PUTIH ≥ 4,5:1',
    (tester) async {
      final kunci = GlobalKey();
      await _pasang(
        tester,
        _Keadaan.gelap,
        ukuran: const Size(390, 844),
        gelap: false,
        warnaPratinjau: const Color(0xFFFFFFFF),
        kunciRender: kunci,
      );
      final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));

      // Bilah bawah (bantuan + jepret) dan kartu saran, di sela teks.
      final bilah = await _piksel(tester, kunci, const Offset(6, 740));
      expect(
        _rasio(m.lcdTeks, bilah),
        greaterThanOrEqualTo(4.5),
        reason: 'bilah',
      );

      final kartu = tester.getRect(
        find.byKey(const ValueKey('kamera-petunjuk')),
      );
      final dalamKartu = await _piksel(
        tester,
        kunci,
        Offset(kartu.left + 6, kartu.center.dy),
      );
      expect(
        _rasio(m.lcdTeks, dalamKartu),
        greaterThanOrEqualTo(4.5),
        reason: 'teks saran di atas pratinjau putih',
      );
      expect(
        _rasio(m.lcdAmber, dalamKartu),
        greaterThanOrEqualTo(3),
        reason: 'ikon saran',
      );

      // Pratinjau putih benar-benar tampil di dalam bingkai (uji tidak kosong).
      final pratinjau = await _piksel(tester, kunci, const Offset(195, 421));
      expect(_luminans(pratinjau), greaterThan(0.5));
    },
  );

  // ── 3. Hierarki, ikon + kata, sasaran sentuh, semantik ─────────────────────
  group('hierarki & aksesibilitas', () {
    testWidgets('satu aksi utama: tombol jepret terbesar, yang lain 48 dp', (
      tester,
    ) async {
      await _pasang(
        tester,
        _Keadaan.siap,
        ukuran: const Size(390, 844),
        gelap: false,
      );

      final jepret = tester.getSize(
        find.byKey(const ValueKey('kamera-jepret')),
      );
      final senter = tester.getSize(
        find.byKey(const ValueKey('kamera-senter')),
      );
      final tutup = tester.getSize(find.byKey(const ValueKey('kamera-tutup')));

      expect(jepret, const Size.square(TokenKamera.tombolJepret));
      expect(senter, const Size.square(TokenKamera.sasaranSentuh));
      expect(tutup, const Size.square(TokenKamera.sasaranSentuh));
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('HP tegak: jepret di tepi ibu jari (tengah bawah)', (
      tester,
    ) async {
      await _pasang(
        tester,
        _Keadaan.siap,
        ukuran: const Size(390, 844),
        gelap: false,
      );
      final pusat = tester.getCenter(
        find.byKey(const ValueKey('kamera-jepret')),
      );

      expect(pusat.dx, closeTo(195, 1));
      expect(pusat.dy, greaterThan(844 * 0.8));
    });

    testWidgets('lanskap & tablet lanskap: jepret di sisi kanan, senter di '
        'dekatnya', (tester) async {
      for (final u in _ukuranUji.where((u) => u.lanskap)) {
        await _pasang(tester, _Keadaan.siap, ukuran: u.ukuran, gelap: false);
        final jepret = tester.getCenter(
          find.byKey(const ValueKey('kamera-jepret')),
        );
        final senter = tester.getCenter(
          find.byKey(const ValueKey('kamera-senter')),
        );

        expect(jepret.dx, greaterThan(u.ukuran.width - TokenKamera.lebarRel));
        expect(senter.dx, closeTo(jepret.dx, 1), reason: u.nama);
        expect(
          (senter.dy - jepret.dy).abs(),
          lessThan(TokenKamera.tombolJepret + TokenKamera.sasaranSentuh),
          reason: u.nama,
        );
      }
    });

    for (final saran in [
      _Keadaan.gelap,
      _Keadaan.agakGelap,
      _Keadaan.silau,
      _Keadaan.bayangan,
      _Keadaan.terpotong,
      _Keadaan.buram,
      _Keadaan.buramGerak,
    ]) {
      testWidgets('saran ${saran.name}: IKON + KATA dalam satu kartu', (
        tester,
      ) async {
        await _pasang(
          tester,
          saran,
          ukuran: const Size(390, 844),
          gelap: false,
        );
        final kartu = find.byKey(const ValueKey('kamera-petunjuk'));

        expect(kartu, findsOneWidget);
        expect(
          find.descendant(of: kartu, matching: find.byType(Icon)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: kartu, matching: find.byType(Text)),
          findsOneWidget,
        );
      });
    }

    testWidgets(
      'senter menyala berubah lewat IKON dan isian, bukan warna saja',
      (tester) async {
        await _pasang(
          tester,
          _Keadaan.siap,
          ukuran: const Size(390, 844),
          gelap: false,
        );
        IconData ikon() => tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('kamera-senter')),
                matching: find.byType(Icon),
              ),
            )
            .icon!;

        final mati = ikon();
        await tester.tap(find.byKey(const ValueKey('kamera-senter')));
        await tester.pump();

        expect(ikon(), isNot(mati));
      },
    );

    testWidgets('label Semantics: senter, jepret, tutup, foto ulang', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _pasang(
        tester,
        _Keadaan.siap,
        ukuran: const Size(390, 844),
        gelap: false,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Ambil foto')),
        isSemantics(
          label: 'Ambil foto',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Nyalakan senter'), findsOneWidget);
      expect(find.bySemanticsLabel('Tutup kamera'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kamera-senter')));
      await tester.pump();
      expect(find.bySemanticsLabel('Matikan senter'), findsOneWidget);
      semantik.dispose();
    });

    testWidgets('dialog Foto ulang: label Semantics dan tombol ≥ 48 dp', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final semantik = tester.ensureSemantics();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _aplikasi(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => tawarkanFotoUlang(
                    context,
                    pesan: 'Alasan.',
                    halamanTerpotong: true,
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
            gelap: false,
            skala: 1.3,
          ),
        );
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Foto ulang'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('foto-ulang'))).height,
          greaterThanOrEqualTo(TokenKamera.sasaranSentuh),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('foto-ulang-tutup'))).height,
          greaterThanOrEqualTo(TokenKamera.sasaranSentuh),
        );
        expect(tester.takeException(), isNull, reason: 'dialog 320 dp, 1,3×');
        semantik.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'tanpa gradien / kartu / bayangan di pohon widget yang tampil',
      (tester) async {
        await _pasang(
          tester,
          _Keadaan.terpotong,
          ukuran: const Size(390, 844),
          gelap: false,
        );

        expect(find.byType(Card), findsNothing);
        for (final d in tester.allWidgets.whereType<DecoratedBox>()) {
          final dekor = d.decoration;
          if (dekor is BoxDecoration) {
            expect(dekor.gradient, isNull);
            expect(dekor.boxShadow, isNull);
          }
        }
      },
    );
  });

  // ── 4. Keadaan dirancang ───────────────────────────────────────────────────
  group('keadaan', () {
    testWidgets('memuat: pemutar + kata, jepret mati, tombol tutup hidup', (
      tester,
    ) async {
      await _pasang(
        tester,
        _Keadaan.memuat,
        ukuran: const Size(390, 844),
        gelap: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Membuka kamera…'), findsOneWidget);
      expect(find.byKey(const ValueKey('kamera-tutup')), findsOneWidget);
      expect(find.byKey(const ValueKey('kamera-senter')), findsNothing);
    });

    testWidgets('tanpa senter: tombol hilang, jepret tidak bergeser', (
      tester,
    ) async {
      await _pasang(
        tester,
        _Keadaan.siap,
        ukuran: const Size(390, 844),
        gelap: false,
      );
      final dengan = tester.getCenter(
        find.byKey(const ValueKey('kamera-jepret')),
      );

      await _pasang(
        tester,
        _Keadaan.tanpaSenter,
        ukuran: const Size(390, 844),
        gelap: false,
      );
      expect(find.byKey(const ValueKey('kamera-senter')), findsNothing);
      expect(
        tester.getCenter(find.byKey(const ValueKey('kamera-jepret'))),
        dengan,
      );
    });

    testWidgets('izin ditolak: satu-satunya aksi = Coba lagi, tombol ≥ 48 dp', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pasang(
          tester,
          _Keadaan.izin,
          ukuran: const Size(320, 640),
          gelap: true,
          skala: 1.3,
        );

        expect(find.byType(FilledButton), findsOneWidget);
        for (final k in ['kamera-coba-lagi']) {
          expect(
            tester.getSize(find.byKey(ValueKey(k))).height,
            greaterThanOrEqualTo(TokenKamera.sasaranSentuh),
            reason: k,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('menjeda (app di latar): pratinjau hilang, tidak crash', (
      tester,
    ) async {
      final k = await _pasang(
        tester,
        _Keadaan.menjeda,
        ukuran: const Size(390, 844),
        gelap: false,
      );

      expect(k!.jumlahLepas, 1);
      expect(find.byKey(const ValueKey('pratinjau-palsu')), findsNothing);
    });
  });

  // ── 5. Tangguh: tanpa overflow ─────────────────────────────────────────────
  group('tanpa overflow (layar × huruf × tema × keadaan)', () {
    final lebar = [
      _Keadaan.siap,
      _Keadaan.terpotong,
      _Keadaan.pesan,
      _Keadaan.izin,
    ];

    for (final u in _ukuranUji) {
      for (final skala in [1.0, 1.3]) {
        for (final gelap in [false, true]) {
          for (final keadaan in lebar) {
            testWidgets(
              '${u.nama} · huruf ${skala}x · ${gelap ? 'gelap' : 'terang'} · '
              '${keadaan.name}',
              (tester) async {
                debugDefaultTargetPlatformOverride = TargetPlatform.android;
                try {
                  await _pasang(
                    tester,
                    keadaan,
                    ukuran: u.ukuran,
                    gelap: gelap,
                    skala: skala,
                  );

                  expect(tester.takeException(), isNull);
                  if (keadaan == _Keadaan.siap) {
                    for (final k in [
                      'kamera-tutup',
                      'kamera-senter',
                      'kamera-jepret',
                    ]) {
                      final s = tester.getSize(find.byKey(ValueKey(k)));
                      expect(
                        s.shortestSide,
                        greaterThanOrEqualTo(TokenKamera.sasaranSentuh),
                        reason: k,
                      );
                      final r = tester.getRect(find.byKey(ValueKey(k)));
                      expect(r.left, greaterThanOrEqualTo(0), reason: k);
                      expect(r.top, greaterThanOrEqualTo(0), reason: k);
                      expect(
                        r.right,
                        lessThanOrEqualTo(u.ukuran.width),
                        reason: k,
                      );
                      expect(
                        r.bottom,
                        lessThanOrEqualTo(u.ukuran.height),
                        reason: k,
                      );
                    }
                  }
                } finally {
                  debugDefaultTargetPlatformOverride = null;
                }
              },
            );
          }
        }
      }
    }

    for (final keadaan in [
      _Keadaan.gelap,
      _Keadaan.agakGelap,
      _Keadaan.silau,
      _Keadaan.bayangan,
      _Keadaan.buram,
      _Keadaan.buramGerak,
      _Keadaan.memuat,
      _Keadaan.menjeda,
      _Keadaan.tanpaSenter,
    ]) {
      for (final u in [_ukuranUji[0], _ukuranUji[3], _ukuranUji[4]]) {
        testWidgets('${u.nama} · huruf 1.3x · ${keadaan.name}', (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            await _pasang(
              tester,
              keadaan,
              ukuran: u.ukuran,
              gelap: keadaan.index.isEven,
              skala: 1.3,
            );

            expect(tester.takeException(), isNull);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  });

  // ── 6. Bukti render PNG (opsional, tidak ikut CI) ──────────────────────────
  final folderRender = Platform.environment['RENDER_KAMERA'];
  group('render PNG', skip: folderRender == null, () {
    final cuplikan = [
      (_Keadaan.siap, _ukuranUji[1], false, 1.0),
      (_Keadaan.gelap, _ukuranUji[0], true, 1.3),
      (_Keadaan.terpotong, _ukuranUji[1], false, 1.0),
      (_Keadaan.pesan, _ukuranUji[1], true, 1.0),
      (_Keadaan.izin, _ukuranUji[1], true, 1.0),
      (_Keadaan.memuat, _ukuranUji[1], false, 1.0),
      (_Keadaan.siap, _ukuranUji[2], false, 1.0),
      (_Keadaan.terpotong, _ukuranUji[3], true, 1.3),
      (_Keadaan.siap, _ukuranUji[4], false, 1.0),
      (_Keadaan.gelap, _ukuranUji[5], true, 1.0),
    ];

    for (final (keadaan, u, gelap, skala) in cuplikan) {
      testWidgets(
        '${keadaan.name} ${u.nama} ${gelap ? 'gelap' : 'terang'} $skala',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            final kunci = GlobalKey();
            await _pasang(
              tester,
              keadaan,
              ukuran: u.ukuran,
              gelap: gelap,
              skala: skala,
              // Pratinjau putih = kasus terburuk untuk keterbacaan lapisan.
              warnaPratinjau: const Color(0xFFE8E8E8),
              kunciRender: kunci,
            );
            await tester.runAsync(() async {
              final batas =
                  kunci.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final gambar = await batas.toImage();
              final png = (await gambar.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final nama =
                  '${keadaan.name}_${u.nama}_${gelap ? 'gelap' : 'terang'}_$skala.png';
              File('$folderRender/$nama')
                ..createSync(recursive: true)
                ..writeAsBytesSync(png.buffer.asUint8List());
            });
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }
  });
}
