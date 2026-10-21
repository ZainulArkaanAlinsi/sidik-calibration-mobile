import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/contoh_sel_provider.dart';
import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/modul_pembaca_teks.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/penampung_contoh_sel.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Alur "Foto lembar kerja" (K-50-11) dengan foto SINTETIS dan mesin baca
/// palsu: yang diuji adalah penyambungan — formulir salah berhenti, review
/// merah/kuning, angka mendarat di sel yang benar, foto tidak diunggah.
class _MesinPalsu extends JalankanPindaiAsli {
  _MesinPalsu({
    this.gagal,
    this.bacaan = const {},
    this.gagalDibaca = const {},
    this.potongan = const {},
  }) : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  final Object? gagal;

  /// kunci sel → (teks, keyakinan)
  final Map<String, (String, double)> bacaan;

  /// kunci sel yang pembacaannya GAGAL (galat ML Kit), bukan kosong.
  final Set<String> gagalDibaca;

  /// kunci sel → PNG potongan.
  final Map<String, Uint8List> potongan;

  /// JPEG yang diteruskan alur ke mesin (M01).
  Uint8List? jpegDiterima;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    jpegDiterima = jpegAsli;
    if (gagal != null) throw gagal!;

    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (bacaan[s.kunci] case (final t, final k))
            (sel: s, bacaan: (teks: t, keyakinan: k, didalamKotak: true))
          else if (gagalDibaca.contains(s.kunci))
            (sel: s, bacaan: (teks: null, keyakinan: null, didalamKotak: true)),
      ],
      gagalDibaca: gagalDibaca,
      potongan: potongan,
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
    final dir = Directory.systemTemp.createTempSync('foto-sintetis');
    fotoSintetis = File('${dir.path}/lembar.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  });

  LembarKerjaState buatState() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
    clientRequestId: 'uuid-test',
  );

  Future<MockSumberFoto> jalankan(
    WidgetTester tester, {
    required LembarKerjaState isian,
    required JalankanPindaiAsli mesin,
    List<Override> tambahan = const [],
    Object? galatKamera,
  }) async {
    // Alur menghapus berkas foto setelah dibaca → salinan baru tiap jalan.
    final salinan = File(
      '${fotoSintetis.path}.${DateTime.now().microsecondsSinceEpoch}',
    )..writeAsBytesSync(fotoSintetis.readAsBytesSync());
    final sumber = MockSumberFoto(file: salinan, galat: galatKamera);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberFotoProvider.overrideWithValue(sumber), ...tambahan],
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
                  isian: isian,
                  template: template,
                  mesin: mesin,
                ),
                child: const Text('foto'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('foto'));
    // Decode di Isolate = IO sungguhan; beri waktu di luar jam palsu test.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(SnackBar).evaluate().isNotEmpty ||
          find.byType(FilledButton).evaluate().isNotEmpty) {
        break;
      }
    }

    return sumber;
  }

  testWidgets(
    'formulir LAIN: berhenti dengan pesan jelas, lembar tak berubah',
    (tester) async {
      final isian = buatState();
      final sumber = await jalankan(
        tester,
        isian: isian,
        mesin: _MesinPalsu(
          gagal: const PindaiAsliGagal(
            GagalPindaiAsli.formulirLain,
            terbaca: 'SIDIK-FM-CAL-0510',
          ),
        ),
      );

      expect(find.textContaining('SIDIK-FM-CAL-0510'), findsOneWidget);
      expect(find.textContaining('formulir lain'), findsOneWidget);
      expect(isian.adaIsianDariFoto, isFalse);
      // Dibatasi 4200 px per sisi (anti-OOM di HP murah; kanvas perataan
      // cuma ~2526 px) tapi mutu JPEG TETAP 100 — sama dengan foto tabel.
      expect(sumber.maxWidthTerakhir, batasSisiFotoAsli);
      expect(sumber.maxHeightTerakhir, batasSisiFotoAsli);
      expect(batasSisiFotoAsli, 4200);
      expect(sumber.kualitasTerakhir, 100);
    },
  );

  testWidgets('review: merah wajib diketik, kuning wajib dicek, lalu masuk', (
    tester,
  ) async {
    final isian = buatState();
    await jalankan(
      tester,
      isian: isian,
      mesin: _MesinPalsu(
        bacaan: {
          // kuning: yakin tinggi tetapi tulisan tangan → tidak pernah hijau
          'sesudah_adjustment|1|1|pembacaan': ('4,01', 0.97),
          // merah: keyakinan rendah → kotak kosong, wajib diketik
          'sesudah_adjustment|2|1|pembacaan': ('7,02', 0.40),
        },
      ),
    );

    expect(find.text('Cek Hasil Pindai'), findsNothing); // layar lama dicabut
    final masukkan = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(masukkan).onPressed, isNull);

    // Merah mulai kosong.
    final kotak = find.byType(TextField);
    expect(tester.widget<TextField>(kotak.first).controller!.text, isEmpty);

    await tester.enterText(kotak.first, '7,03');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(masukkan).onPressed,
      isNull,
      reason: 'kuning belum dicek',
    );

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('cek-'),
      ),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(masukkan).onPressed, isNotNull);

    await tester.tap(masukkan);
    await tester.pumpAndSettle();

    final t4 = isian.titik[4.00]!;
    final t7 = isian.titik[7.00]!;
    expect(t4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4,01');
    expect(t7.kotak('sesudah_adjustment', 'pembacaan', 0).text, '7,03');
    expect(isian.adaIsianDariFoto, isTrue);
    // Tabel "sebelum" tidak ikut terisi: kuncinya membawa tabel_id.
    expect(
      isian.titik[4.00]!.kotak('sebelum_adjustment', 'pembacaan', 0).text,
      isEmpty,
    );
  });

  testWidgets(
    'sel GAGAL dibaca = merah kosong di review; sel kosong tetap tak tampil; '
    'JPEG asli diteruskan ke mesin',
    (tester) async {
      final isian = buatState();
      final mesin = _MesinPalsu(
        gagalDibaca: {'sesudah_adjustment|1|1|pembacaan'},
      );
      await jalankan(tester, isian: isian, mesin: mesin);

      // Bita foto yang diambil diteruskan apa adanya (M01: ML Kit membaca
      // JPEG asli, bukan PNG hasil encode ulang).
      expect(mesin.jpegDiterima, fotoSintetis.readAsBytesSync());

      // Satu-satunya baris review = sel yang gagal; merah → kosong, wajib
      // diketik. Tidak ada angka karangan, tidak ada nol.
      final kotak = find.byType(TextField);
      expect(kotak, findsOneWidget);
      expect(tester.widget<TextField>(kotak).controller!.text, isEmpty);
      final masukkan = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(masukkan).onPressed, isNull);

      await tester.enterText(kotak, '4,05');
      await tester.pump();
      expect(tester.widget<FilledButton>(masukkan).onPressed, isNotNull);
      await tester.tap(masukkan);
      await tester.pumpAndSettle();

      expect(
        isian.titik[4.00]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
        '4,05',
      );
    },
  );

  group('contoh sel terkonfirmasi (lokal, sakelar)', () {
    Future<List<Map<String, dynamic>>> jalankanDanBaca(
      WidgetTester tester, {
      required bool nyala,
    }) async {
      final dir = Directory.systemTemp.createTempSync('contoh-alur');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows: berkas masih dipegang antrean simpanan; folder temp OS.
        }
      });
      final simpanan = SimpananContohSel(dir);
      final png = img.encodePng(img.Image(width: 60, height: 20));

      final isian = buatState();
      await jalankan(
        tester,
        isian: isian,
        mesin: _MesinPalsu(
          gagalDibaca: {'sesudah_adjustment|1|1|pembacaan'},
          potongan: {'sesudah_adjustment|1|1|pembacaan': png},
        ),
        tambahan: [
          sakelarOcrProvider.overrideWithValue(
            SakelarOcr(kumpulkanContohSel: nyala),
          ),
          penampungContohSelProvider.overrideWith(
            (ref) async => PenampungContohSel(simpanan),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), '4,05');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Penyimpanan jalan tanpa ditunggu (unawaited) di zona test: IO nyata
      // diberi waktu lewat runAsync, lanjutannya dijalankan lewat pump.
      final indeks = File('${dir.path}/indeks.jsonl');
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (indeks.existsSync() && indeks.readAsStringSync().isNotEmpty) break;
      }
      final isi = indeks.existsSync()
          ? [
              for (final b in indeks.readAsLinesSync())
                if (b.trim().isNotEmpty) jsonDecode(b) as Map<String, dynamic>,
            ]
          : const <Map<String, dynamic>>[];
      return isi;
    }

    testWidgets('sakelar MATI (bawaan): tidak ada yang disimpan', (
      tester,
    ) async {
      expect(await jalankanDanBaca(tester, nyala: false), isEmpty);
    });

    testWidgets('sakelar NYALA: label = nilai yang dikonfirmasi teknisi', (
      tester,
    ) async {
      final isi = await jalankanDanBaca(tester, nyala: true);
      expect(isi, hasLength(1));
      expect(isi.single['label'], '4,05');
      expect(isi.single['berkas'], endsWith('.jpg'));
    });
  });

  testWidgets(
    'modul ML Kit belum terunduh: pesan jelas, lembar tidak berubah, tak crash',
    (tester) async {
      final isian = buatState();
      await jalankan(
        tester,
        isian: isian,
        mesin: _MesinPalsu(gagal: const ModulPembacaTeksBelumSiap()),
      );

      expect(find.textContaining('butuh internet sekali'), findsOneWidget);
      expect(isian.adaIsianDariFoto, isFalse);
    },
  );

  testWidgets(
    'izin kamera ditolak: kalimat manusia + petunjuk Pengaturan, tak crash',
    (tester) async {
      final isian = buatState();
      await jalankan(
        tester,
        isian: isian,
        mesin: _MesinPalsu(),
        galatKamera: PlatformException(
          code: 'camera_access_denied',
          message: 'The user did not allow camera access.',
        ),
      );

      expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
      expect(find.textContaining('Pengaturan'), findsOneWidget);
      expect(find.textContaining('camera_access_denied'), findsNothing);
      expect(isian.adaIsianDariFoto, isFalse);
    },
  );

  testWidgets('galat tak terduga saat baca: pesan umum, galat mentah tidak '
      'tampil', (tester) async {
    final isian = buatState();
    await jalankan(
      tester,
      isian: isian,
      mesin: _MesinPalsu(gagal: StateError('/data/rahasia.jpg')),
    );

    expect(find.textContaining('Foto gagal diproses'), findsOneWidget);
    expect(find.textContaining('/data/'), findsNothing);
    expect(isian.adaIsianDariFoto, isFalse);
  });
}
