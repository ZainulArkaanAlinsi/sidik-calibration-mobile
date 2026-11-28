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
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/penampung_contoh_sel.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Alur "Foto lembar kerja" (K-50-11) dengan foto SINTETIS dan mesin baca
/// palsu: yang diuji adalah penyambungan — formulir salah berhenti, angka
/// langsung mendarat di sel yang benar (ditandai perlu dicek; merah tetap
/// kosong), foto tidak diunggah.
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
    WorksheetTemplate? templat,
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
                  template: templat ?? template,
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

  testWidgets(
    'tanpa layar review: bacaan masuk LANGSUNG ke lembar dan ditandai perlu '
    'dicek; bacaan merah (keyakinan rendah) tetap kosong',
    (tester) async {
      final isian = buatState();
      await jalankan(
        tester,
        isian: isian,
        mesin: _MesinPalsu(
          bacaan: {
            // kuning: yakin tinggi tetapi tulisan tangan → tidak pernah hijau
            'sesudah_adjustment|1|1|pembacaan': ('4,01', 0.97),
            // merah: keyakinan rendah → TIDAK masuk, kotak tetap kosong
            'sesudah_adjustment|2|1|pembacaan': ('7,02', 0.40),
          },
        ),
      );

      // Keputusan pemilik 28 Nov 2026: layar "Isi cepat, satu per satu" dicabut
      // dari jalur foto lembar asli. Tidak ada layar, kotak ketik, atau tombol
      // "Masukkan" yang menahan hasilnya.
      expect(find.text('Cek Hasil Pindai'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);

      final t4 = isian.titik[4.00]!;
      final t7 = isian.titik[7.00]!;
      expect(t4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4,01');
      expect(isian.adaIsianDariFoto, isTrue);
      // Tulisan tangan tidak pernah hijau: sel yang masuk ditandai "perlu
      // dicek" (kuning) di lembar. Itu satu-satunya penanda; tidak ada
      // gerbang yang menahan Kirim karena sel kuning.
      expect(isian.selKamera, hasLength(1));
      // Sel merah: tidak ada angka karangan, tidak ada nol.
      expect(t7.kotak('sesudah_adjustment', 'pembacaan', 0).text, isEmpty);
      // Tabel "sebelum" tidak ikut terisi: kuncinya membawa tabel_id.
      expect(
        isian.titik[4.00]!.kotak('sebelum_adjustment', 'pembacaan', 0).text,
        isEmpty,
      );
    },
  );

  group('bentuk angka dijaga: titik/koma dan jumlah digit', () {
    // Template 0509 dari server belum membawa `aturan` per sel, jadi gerbang
    // bentuk mati. Di sini dua sel diberi `aturan.desimal = 2` seperti sel
    // Conductivity 0510 di server, supaya gerbangnya benar-benar aktif.
    WorksheetTemplate templatBerDesimal(Map<String, int> desimalPerKunci) {
      final json =
          jsonDecode(
                File(
                  'test/assets/template-asli-ph_meter-0509.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final sel =
          (json['data'] as Map<String, dynamic>)['sel']
              as Map<String, dynamic>;
      desimalPerKunci.forEach((kunci, d) {
        (sel[kunci] as Map<String, dynamic>)['aturan'] = {
          'tipe': 'desimal',
          'desimal': d,
        };
      });

      return WorksheetTemplate.fromJson(json);
    }

    const k1 = 'sesudah_adjustment|1|1|pembacaan'; // titik 4
    const k2 = 'sesudah_adjustment|2|1|pembacaan'; // titik 7
    const k3 = 'sesudah_adjustment|3|1|pembacaan'; // titik 10.01

    // Bacaan mesin yang BENTUKNYA salah untuk sel 2 desimal: titik hilang,
    // digit kurang, digit lebih, minus di sel tanpa minus. Semuanya harus
    // dikosongkan, bukan ditebak.
    for (final salah in ['401', '4,0', '4,011', '-4,01', '4,,01', '4.0.1']) {
      testWidgets('bacaan "$salah" di sel 2 desimal: kotak tetap kosong', (
        tester,
      ) async {
        final isian = buatState();
        await jalankan(
          tester,
          isian: isian,
          templat: templatBerDesimal({k1: 2}),
          mesin: _MesinPalsu(bacaan: {k1: (salah, 0.97)}),
        );

        expect(
          isian.titik[4.00]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
          isEmpty,
        );
        expect(isian.adaIsianDariFoto, isFalse);
        expect(isian.selKamera, isEmpty);
      });
    }

    // Sel TANPA `aturan.desimal` (pH 0509 dari server hari ini): jumlah desimal
    // tidak diketahui, tapi bentuk ngawur tetap dibuang. "701" (pemisah hilang)
    // memang belum bisa ditangkap tanpa desimal dari server: ditulis di docs.
    for (final salah in [
      '4.',
      '.5',
      '+4',
      '1e1',
      '4,,01',
      '4.0.1',
      '-',
      'NaN',
      '123456789',
      '4,01234',
    ]) {
      testWidgets('bacaan "$salah" di sel tanpa aturan desimal: tetap kosong', (
        tester,
      ) async {
        final isian = buatState();
        await jalankan(
          tester,
          isian: isian,
          mesin: _MesinPalsu(bacaan: {k1: (salah, 0.97)}),
        );

        expect(
          isian.titik[4.00]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
          isEmpty,
        );
        expect(isian.adaIsianDariFoto, isFalse);
      });
    }

    test('bentukUmumLolos: terima yang wajar, tolak sisanya', () {
      for (final ok in ['7', '7,01', '7.01', '-0,5', '10,0125', '12345678']) {
        expect(AturanFormatSel.bentukUmumLolos(ok), isTrue, reason: ok);
      }
      for (final salah in ['', ' 7', '7 ', '7,', ',5', '--5', '5-', '1e1']) {
        expect(AturanFormatSel.bentukUmumLolos(salah), isFalse, reason: salah);
      }
    });

    testWidgets(
      'bentuk benar masuk: koma dan titik sama sah (titik tampil koma), '
      'sel tanpa aturan desimal tidak ikut digerbang',
      (tester) async {
        final isian = buatState();
        await jalankan(
          tester,
          isian: isian,
          templat: templatBerDesimal({k1: 2, k2: 2}),
          mesin: _MesinPalsu(
            bacaan: {
              k1: ('4,01', 0.97),
              k2: ('7.02', 0.95),
              // k3 tanpa aturan: gerbang bentuk mati, bacaan "10" lolos
              // (nilainya tetap diperiksa ulang oleh teknisi: perlu dicek).
              k3: ('10', 0.95),
            },
          ),
        );

        expect(
          isian.titik[4.00]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
          '4,01',
        );
        expect(
          isian.titik[7.00]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
          '7,02',
          reason: 'titik terbaca sah, lembar menampilkannya dengan koma',
        );
        expect(
          isian.titik[10.01]!
              .kotak('sesudah_adjustment', 'pembacaan', 0)
              .text,
          '10',
        );
        expect(isian.selKamera, hasLength(3));
      },
    );
  });

  testWidgets(
    'sel GAGAL dibaca = kotak tetap kosong (tanpa layar review); JPEG asli '
    'diteruskan ke mesin',
    (tester) async {
      final isian = buatState();
      final mesin = _MesinPalsu(
        gagalDibaca: {'sesudah_adjustment|1|1|pembacaan'},
      );
      await jalankan(tester, isian: isian, mesin: mesin);

      // Bita foto yang diambil diteruskan apa adanya (M01: ML Kit membaca
      // JPEG asli, bukan PNG hasil encode ulang).
      expect(mesin.jpegDiterima, fotoSintetis.readAsBytesSync());

      // Tidak ada layar review dan tidak ada angka karangan: sel yang gagal
      // dibaca dibiarkan kosong; teknisi mengetiknya langsung di lembar.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(
        isian.titik[4.00]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
        isEmpty,
      );
      expect(isian.adaIsianDariFoto, isFalse);
      expect(isian.selKamera, isEmpty);
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

      // Beri waktu IO nyata: kalau ada penyimpanan yang jalan tanpa ditunggu
      // (unawaited), hasilnya sempat tertulis sebelum indeks dibaca.
      final indeks = File('${dir.path}/indeks.jsonl');
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
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

    // Contoh pelatihan hanya boleh berlabel hasil KONFIRMASI manusia. Jalur
    // foto lembar asli tidak lagi punya langkah konfirmasi (28 Nov 2026), jadi
    // keluaran mesin yang belum dicek tidak boleh disimpan sebagai label —
    // sakelar mati MAUPUN nyala.
    testWidgets(
      'sakelar NYALA: tetap tidak ada yang disimpan (tanpa konfirmasi manusia '
      'tidak ada label)',
      (tester) async {
        expect(await jalankanDanBaca(tester, nyala: true), isEmpty);
      },
    );
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
