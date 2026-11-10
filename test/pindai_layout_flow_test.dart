import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/layout_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/layout/detektor_layout.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Sambungan layout detection di alur "Foto lembar kerja": dialog pemuatan,
/// progres unduh model, galat -> muat ulang / lanjut tanpa layout, bypass di
/// platform tanpa layout, dan petunjuk di layar review. Detektor & mesin baca
/// palsu: yang diuji penyambungannya, bukan akurasi model.
class _MesinPalsu extends JalankanPindaiAsli {
  _MesinPalsu({this.gagal})
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  final Object? gagal;
  int dipanggil = 0;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    dipanggil++;
    if (gagal != null) throw gagal!;

    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (s.kunci == 'sesudah_adjustment|1|1|pembacaan')
            (
              sel: s,
              bacaan: (teks: '4,01', keyakinan: 0.97, didalamKotak: true),
            ),
      ],
    );
  }
}

class _DetektorPalsu implements DetektorLayout {
  _DetektorPalsu({
    this.tersedia = true,
    this.hasil,
    this.gagal = const [],
    this.tahan,
    this.mintaIzin = false,
  });

  @override
  final bool tersedia;
  final HasilLayout? hasil;

  /// Galat yang dilempar berurutan sebelum akhirnya berhasil.
  final List<LayoutGagal> gagal;

  /// Kalau diisi, deteksi menunggu ini (supaya dialog bisa diperiksa).
  final Completer<void>? tahan;
  final bool mintaIzin;
  int panggilan = 0;
  bool? jawabanIzin;

  @override
  Future<void> siapkan({
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  }) async {}

  @override
  Future<HasilLayout> deteksi(
    Uint8List jpeg, {
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  }) async {
    panggilan++;
    if (mintaIzin) {
      jawabanIzin = await izinUnduh!();
      if (jawabanIzin != true) {
        throw const LayoutGagal(SebabLayoutGagal.unduhDitolak);
      }
    }
    kemajuan?.call(TahapLayout.mengunduhModel, 0.42);
    if (tahan != null) await tahan!.future;
    if (panggilan <= gagal.length) throw gagal[panggilan - 1];
    kemajuan?.call(TahapLayout.mendeteksi, null);

    return hasil ??
        const HasilLayout(
          wilayah: [
            WilayahLayout(
              kelas: 'Table',
              skor: 0.9,
              kotak: Rect.fromLTRB(100, 200, 900, 1200),
            ),
          ],
          lebar: 1000,
          tinggi: 1400,
          durasiMs: 3,
        );
  }
}

void main() {
  late WorksheetTemplate template;
  late File fotoSintetis;

  setUpAll(() {
    template = WorksheetTemplate.fromJson(
      jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final dir = Directory.systemTemp.createTempSync('foto-layout');
    fotoSintetis = File('${dir.path}/lembar.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  });

  LembarKerjaState buatState() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
    clientRequestId: 'uuid-test',
  );

  Future<void> mulai(
    WidgetTester tester, {
    required DetektorLayout detektor,
    required _MesinPalsu mesin,
    Future<bool> Function()? takBerbayar,
    List<Override> tambahan = const [],
  }) async {
    final salinan = File(
      '${fotoSintetis.path}.${DateTime.now().microsecondsSinceEpoch}',
    )..writeAsBytesSync(fotoSintetis.readAsBytesSync());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberFotoProvider.overrideWithValue(MockSumberFoto(file: salinan)),
          if (takBerbayar != null)
            jaringanTakBerbayarProvider.overrideWithValue(takBerbayar),
          ...tambahan,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => pindaiFormulirAsli(
                  context: context,
                  ref: ref,
                  isian: buatState(),
                  template: template,
                  mesin: mesin,
                  detektorLayout: detektor,
                ),
                child: const Text('foto'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('foto'));
  }

  /// Memompa sampai [selesai] benar atau 4 detik habis (decode foto di
  /// Isolate = IO sungguhan, di luar jam palsu test).
  Future<void> tunggu(WidgetTester tester, bool Function() selesai) async {
    for (var i = 0; i < 40 && !selesai(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'layout tersedia: dialog "Mendeteksi Tabel & Membaca Formulir…" + progres unduh',
    (tester) async {
      final tahan = Completer<void>();
      final detektor = _DetektorPalsu(tahan: tahan);
      await mulai(tester, detektor: detektor, mesin: _MesinPalsu());

      await tunggu(
        tester,
        () => find
            .byKey(const ValueKey('progres-unduh-model'))
            .evaluate()
            .isNotEmpty,
      );

      expect(find.text('Mendeteksi Tabel & Membaca Formulir…'), findsOneWidget);
      expect(find.byKey(const ValueKey('progres-unduh-model')), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('progres-unduh-model')),
            )
            .value,
        0.42,
      );
      expect(find.textContaining('42%'), findsOneWidget);
      // Kalimat bypass TIDAK muncul selama layout berjalan.
      expect(find.textContaining('Membaca foto di HP'), findsNothing);

      tahan.complete();
      await tunggu(
        tester,
        () => find.byType(FilledButton).evaluate().isNotEmpty,
      );

      // Selesai -> layar review (layout tidak menambah angka apa pun).
      expect(find.byType(FilledButton), findsOneWidget);
      expect(detektor.panggilan, 1);
    },
  );

  testWidgets(
    'Windows/iOS/web (tersedia=false): dialog lama, layout tak dipanggil',
    (tester) async {
      final detektor = _DetektorPalsu(tersedia: false);
      final mesin = _MesinPalsu();
      await mulai(tester, detektor: detektor, mesin: mesin);

      await tunggu(
        tester,
        () => find.byType(FilledButton).evaluate().isNotEmpty,
      );

      expect(detektor.panggilan, 0);
      expect(mesin.dipanggil, 1);
      expect(find.text('Mendeteksi Tabel & Membaca Formulir…'), findsNothing);
      // Review tetap tampil, tanpa petunjuk layout.
      expect(find.byKey(const ValueKey('peringatan-layout')), findsNothing);
    },
  );

  testWidgets('bypass: dialog progres memakai kalimat lama selama membaca', (
    tester,
  ) async {
    final tahan = Completer<void>();
    final mesin = _TahanMesin(tahan);
    await mulai(
      tester,
      detektor: _DetektorPalsu(tersedia: false),
      mesin: mesin,
    );

    await tunggu(tester, () => mesin.dipanggil > 0);

    expect(find.textContaining('Membaca foto di HP'), findsOneWidget);
    expect(find.text('Mendeteksi Tabel & Membaca Formulir…'), findsNothing);

    tahan.complete();
    await tunggu(tester, () => find.byType(FilledButton).evaluate().isNotEmpty);
  });

  testWidgets('gagal -> "Muat ulang" mencoba lagi; sukses di percobaan kedua', (
    tester,
  ) async {
    final detektor = _DetektorPalsu(
      gagal: const [LayoutGagal(SebabLayoutGagal.unduhGagal)],
    );
    await mulai(tester, detektor: detektor, mesin: _MesinPalsu());

    await tunggu(
      tester,
      () =>
          find.byKey(const ValueKey('layout-muat-ulang')).evaluate().isNotEmpty,
    );
    expect(find.text('Deteksi tabel belum bisa jalan'), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-lanjut-tanpa')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('layout-muat-ulang')));
    await tunggu(tester, () => find.byType(FilledButton).evaluate().isNotEmpty);

    expect(detektor.panggilan, 2);
    expect(find.byType(FilledButton), findsOneWidget); // review
  });

  testWidgets(
    'gagal -> "Lanjut tanpa deteksi tabel": pembacaan sel tetap jalan',
    (tester) async {
      final detektor = _DetektorPalsu(
        gagal: const [LayoutGagal(SebabLayoutGagal.modelRusak)],
      );
      final mesin = _MesinPalsu();
      await mulai(tester, detektor: detektor, mesin: mesin);

      await tunggu(
        tester,
        () => find
            .byKey(const ValueKey('layout-lanjut-tanpa'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.textContaining('sha256'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('layout-lanjut-tanpa')));
      await tunggu(
        tester,
        () => find.byType(FilledButton).evaluate().isNotEmpty,
      );

      expect(detektor.panggilan, 1);
      expect(mesin.dipanggil, 1);
      expect(find.byKey(const ValueKey('peringatan-layout')), findsNothing);
    },
  );

  testWidgets(
    'hasil tanpa tabel -> petunjuk di layar review (sel tetap harus dicek)',
    (tester) async {
      final detektor = _DetektorPalsu(
        hasil: const HasilLayout(
          wilayah: [],
          lebar: 1000,
          tinggi: 1400,
          durasiMs: 1,
        ),
      );
      await mulai(tester, detektor: detektor, mesin: _MesinPalsu());

      await tunggu(
        tester,
        () => find
            .byKey(const ValueKey('peringatan-layout'))
            .evaluate()
            .isNotEmpty,
      );

      expect(find.byKey(const ValueKey('peringatan-layout')), findsOneWidget);
      expect(find.textContaining('Tabel tidak terdeteksi'), findsOneWidget);
      // Petunjuk tidak melonggarkan apa pun: tombol masuk tetap terkunci sampai
      // sel kuning dicek.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'data seluler: ditanya dulu; "Lanjut tanpa" -> tanpa unduhan, baca jalan',
    (tester) async {
      final detektor = _DetektorPalsu(mintaIzin: true);
      final mesin = _MesinPalsu();
      await mulai(
        tester,
        detektor: detektor,
        mesin: mesin,
        takBerbayar: () async => false,
      );

      await tunggu(
        tester,
        () => find.byKey(const ValueKey('layout-lewati')).evaluate().isNotEmpty,
      );
      expect(find.text('Unduh model lewat data seluler?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('layout-lewati')));
      await tunggu(
        tester,
        () => find.byType(FilledButton).evaluate().isNotEmpty,
      );

      expect(detektor.jawabanIzin, isFalse);
      expect(mesin.dipanggil, 1);
    },
  );

  group('nama formulir lain (detectWorksheetType)', ujiNamaFormulirLain);

  testWidgets('WiFi: tidak ditanya, langsung jalan', (tester) async {
    final detektor = _DetektorPalsu(mintaIzin: true);
    await mulai(
      tester,
      detektor: detektor,
      mesin: _MesinPalsu(),
      takBerbayar: () async => true,
    );

    await tunggu(tester, () => find.byType(FilledButton).evaluate().isNotEmpty);

    expect(find.byKey(const ValueKey('layout-lewati')), findsNothing);
    expect(detektor.jawabanIzin, isTrue);
  });
}

// Dipisah ke fungsi supaya ditempel di dalam main() lewat grup tersendiri.
void ujiNamaFormulirLain() {
  const dikenal = <FormulirDikenal>[
    (
      templateId: 'conductivity_meter',
      kodeDokumen: 'SIDIK-FM-CAL-0510_Rev.5',
      judul: 'Calibration Worksheet - Conductivity Meter',
    ),
    (
      templateId: 'ph_meter',
      kodeDokumen: 'SIDIK-FM-CAL-0509_Rev.4',
      judul: 'Calibration Worksheet - pH Meter',
    ),
  ];
  late WorksheetTemplate template;
  late File foto;

  setUpAll(() {
    template = WorksheetTemplate.fromJson(
      jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    foto = File(
      '${Directory.systemTemp.createTempSync('foto-nama').path}/l.png',
    )..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  });

  Future<void> jalan(
    WidgetTester tester,
    List<Override> tambahan,
    String terbaca,
  ) async {
    final salinan = File(
      '${foto.path}.${DateTime.now().microsecondsSinceEpoch}',
    )..writeAsBytesSync(foto.readAsBytesSync());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberFotoProvider.overrideWithValue(MockSumberFoto(file: salinan)),
          ...tambahan,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => pindaiFormulirAsli(
                  context: context,
                  ref: ref,
                  isian: LembarKerjaState(
                    bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
                    clientRequestId: 'uuid-test',
                  ),
                  template: template,
                  detektorLayout: const DetektorLayoutTakTersedia(),
                  mesin: _MesinPalsu(
                    gagal: PindaiAsliGagal(
                      GagalPindaiAsli.formulirLain,
                      terbaca: terbaca,
                    ),
                  ),
                ),
                child: const Text('foto'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('foto'));
    for (var i = 0; i < 40 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('formulir lain yang DIKENAL server: pesan menyebut jenisnya', (
    tester,
  ) async {
    await jalan(tester, [
      formulirDikenalProvider.overrideWithValue(const AsyncData(dikenal)),
    ], 'SIDIK-FM-CAL-0510');

    expect(
      find.textContaining('SIDIK-FM-CAL-0510 (Conductivity Meter)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('bukan formulir untuk alat ini'),
      findsOneWidget,
    );
  });

  testWidgets(
    'daftar server belum termuat: kalimat lama, tanpa menunggu jaringan',
    (tester) async {
      await jalan(tester, [
        formulirDikenalProvider.overrideWithValue(const AsyncLoading()),
      ], 'SIDIK-FM-CAL-0510');

      expect(
        find.textContaining('Ini formulir lain (SIDIK-FM-CAL-0510)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('kode yang tidak dikenal server: kalimat lama', (tester) async {
    await jalan(tester, [
      formulirDikenalProvider.overrideWithValue(const AsyncData(dikenal)),
    ], 'SIDIK-FM-CAL-0999');

    expect(
      find.textContaining('Ini formulir lain (SIDIK-FM-CAL-0999)'),
      findsOneWidget,
    );
  });
}

class _TahanMesin extends _MesinPalsu {
  _TahanMesin(this.tahan);

  final Completer<void> tahan;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    dipanggil++;
    await tahan.future;
    dipanggil--;

    return super.baca(foto, template: template, jpegAsli: jpegAsli);
  }
}
