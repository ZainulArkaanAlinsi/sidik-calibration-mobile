import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/ocr_awan_sel_provider.dart';
import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/ocr_awan_sel_service.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Penyambungan OCR awan di alur "Foto lembar kerja" (`pindaiFormulirAsli`):
/// (1) `equipment_id` dari alat yang dipilih ikut ke permintaan 22B, dan tidak
/// dikirim bila tidak ada alat; (2) gerbang tutup = layar review IDENTIK dengan
/// sebelum fitur ini, tanpa panggilan jaringan dan tanpa membaca token.
///
/// Servis awan diganti klien HTTP palsu / servis palsu; tidak ada jaringan dan
/// tidak ada Google. Bukan bukti akurasi bacaan.
class _MesinPalsu extends JalankanPindaiAsli {
  _MesinPalsu()
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  static const kunciSel = 'sesudah_adjustment|1|1|pembacaan';

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (s.kunci == kunciSel)
            (sel: s, bacaan: (teks: null, keyakinan: null, didalamKotak: true)),
      ],
      // Gagal dibaca = baris merah kosong; potongannya ada, jadi layak ditawarkan.
      gagalDibaca: {kunciSel},
      potongan: {
        kunciSel: Uint8List.fromList(
          img.encodePng(img.Image(width: 60, height: 20)),
        ),
      },
    );
  }
}

/// Token palsu yang menghitung berapa kali dibaca.
class _TokenHitung extends InMemoryTokenStorage {
  _TokenHitung() : super('token-uji');

  int dibaca = 0;

  @override
  Future<String?> read() {
    dibaca++;

    return super.read();
  }
}

/// Klien HTTP palsu: mencatat tiap MultipartRequest yang sampai.
class _Client extends http.BaseClient {
  final List<Map<String, String>> kolom = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().toBytes();
    kolom.add(Map.of((request as http.MultipartRequest).fields));

    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'hasil': [
              {
                'kunci': _MesinPalsu.kunciSel,
                'teks_awan': '4.01',
                'keyakinan': 0.93,
                'status': 'kuning',
                'teks_normal': '4,01',
                'nilai_awan': 4.01,
                'dinormalkan': true,
                'alasan': <String>[],
              },
            ],
            'dilewati': <Map<String, dynamic>>[],
            'meta': {
              'sumber': 'google_vision',
              'usulan': true,
              'sebagian': false,
              'sisa_sel_lembar': 120,
            },
          }),
        ),
      ),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

const _tombolMinta = ValueKey('minta-usulan-awan');

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
    final dir = Directory.systemTemp.createTempSync('foto-awan-alur');
    fotoSintetis = File('${dir.path}/lembar.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  });

  LembarKerjaState buatState({EquipmentLookup? alat}) => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
    clientRequestId: 'uuid-test',
  )..alat = alat;

  const alat42 = EquipmentLookup(
    id: 42,
    namaAlat: 'pH Meter',
    serialNumber: 'UJI-001',
    kategori: 'ph_meter',
    status: 'aktif',
  );

  Widget bungkus(List<Override> overrides, Widget isi) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      home: isi,
    ),
  );

  /// Menjalankan alur sampai layar review terbuka.
  Future<void> bukaReview(
    WidgetTester tester, {
    required LembarKerjaState isian,
    required List<Override> overrides,
  }) async {
    final salinan = File(
      '${fotoSintetis.path}.${DateTime.now().microsecondsSinceEpoch}',
    )..writeAsBytesSync(fotoSintetis.readAsBytesSync());

    await tester.pumpWidget(
      bungkus(
        [
          sumberFotoProvider.overrideWithValue(MockSumberFoto(file: salinan)),
          ...overrides,
        ],
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              // Izin dimuat lebih dulu, seperti di aplikasi (dimuat saat masuk).
              ref.watch(izinProvider);

              return ElevatedButton(
                onPressed: () => pindaiFormulirAsli(
                  context: context,
                  ref: ref,
                  isian: isian,
                  template: template,
                  mesin: _MesinPalsu(),
                ),
                child: const Text('foto'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('foto'));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(FotoReviewScreen).evaluate().isNotEmpty) break;
    }
    await tester.pump();
    expect(find.byType(FotoReviewScreen), findsOneWidget);
  }

  const izinBoleh = Izin(role: null, boleh: {'alat.lihat'});

  group('equipment_id ikut ke permintaan 22B', () {
    Future<_Client> mintaUsulan(
      WidgetTester tester, {
      required LembarKerjaState isian,
    }) async {
      final klien = _Client();
      await bukaReview(
        tester,
        isian: isian,
        overrides: [
          sakelarOcrProvider.overrideWithValue(
            const SakelarOcr(ocrAwanSel: true),
          ),
          izinProvider.overrideWith((ref) async => izinBoleh),
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('token-uji'),
          ),
          ocrAwanSelServiceProvider.overrideWithValue(
            ApiOcrAwanSelService(
              ApiClient(client: klien, baseUrl: 'http://contoh.test/api'),
            ),
          ),
        ],
      );

      await tester.tap(find.byKey(_tombolMinta));
      for (var i = 0; i < 20 && klien.kolom.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      return klien;
    }

    testWidgets('alat dipilih: field multipart equipment_id = id alat', (
      tester,
    ) async {
      final klien = await mintaUsulan(tester, isian: buatState(alat: alat42));

      expect(klien.kolom, hasLength(1));
      expect(klien.kolom.single['equipment_id'], '42');
      expect(klien.kolom.single['template_id'], template.templateId);
      expect(klien.kolom.single['kertas'], 'asli');
      expect(klien.kolom.single['sel[0][kunci]'], _MesinPalsu.kunciSel);
    });

    testWidgets('tanpa alat: field equipment_id TIDAK dikirim', (tester) async {
      final klien = await mintaUsulan(tester, isian: buatState());

      expect(klien.kolom, hasLength(1));
      expect(klien.kolom.single.containsKey('equipment_id'), isFalse);
      expect(klien.kolom.single['template_id'], template.templateId);
    });
  });

  group('gerbang tutup: layar identik, nol jaringan', () {
    /// Teks yang tampil di layar review, berurutan, plus kunci-kunci widgetnya.
    ({List<String> teks, List<String> kunci}) lihat(WidgetTester tester) {
      final akar = find.byType(FotoReviewScreen);

      return (
        teks: [
          for (final w in tester.widgetList<Text>(
            find.descendant(of: akar, matching: find.byType(Text)),
          ))
            w.data ?? w.textSpan?.toPlainText() ?? '',
        ],
        kunci: [
          for (final e
              in find
                  .descendant(
                    of: akar,
                    matching: find.byWidgetPredicate(
                      (w) => w.key is ValueKey<String>,
                    ),
                  )
                  .evaluate())
            (e.widget.key! as ValueKey<String>).value,
        ],
      );
    }

    final kasus = <String, ({SakelarOcr sakelar, Izin izin})>{
      'sakelar klien mati (konstruktor const)': (
        sakelar: const SakelarOcr(),
        izin: izinBoleh,
      ),
      'izin belum dijawab backend': (
        sakelar: const SakelarOcr(ocrAwanSel: true),
        izin: Izin.kosong,
      ),
      'Super Admin mematikan ocr_cloud_sel': (
        sakelar: const SakelarOcr(ocrAwanSel: true),
        izin: const Izin(
          role: null,
          boleh: {'alat.lihat'},
          fiturNonaktif: {KodeFitur.ocrCloudSel},
        ),
      ),
      'Super Admin mematikan pindai_lembar': (
        sakelar: const SakelarOcr(ocrAwanSel: true),
        izin: const Izin(
          role: null,
          boleh: {'alat.lihat'},
          fiturNonaktif: {KodeFitur.pindaiLembar},
        ),
      ),
    };

    for (final MapEntry(key: nama, value: k) in kasus.entries) {
      testWidgets(nama, (tester) async {
        final servis = MockOcrAwanSelService();
        final token = _TokenHitung();

        await bukaReview(
          tester,
          isian: buatState(alat: alat42),
          overrides: [
            sakelarOcrProvider.overrideWithValue(k.sakelar),
            izinProvider.overrideWith((ref) async => k.izin),
            tokenStorageProvider.overrideWithValue(token),
            ocrAwanSelServiceProvider.overrideWithValue(servis),
          ],
        );

        final layar = tester.widget<FotoReviewScreen>(
          find.byType(FotoReviewScreen),
        );
        expect(layar.mintaUsulanAwan, isNull);
        expect(find.byKey(_tombolMinta), findsNothing);

        // Nol panggilan jaringan, dan token tidak pernah dibaca.
        expect(servis.permintaan, isEmpty);
        expect(token.dibaca, 0);

        // Identik dengan layar yang dirakit TANPA penerus awan sama sekali
        // (keadaan sebelum fitur ini): teks dan kunci widget sama persis.
        final dariAlur = lihat(tester);
        expect(
          dariAlur.teks.where((t) => t.toLowerCase().contains('awan')),
          isEmpty,
        );

        // Lepas dulu: jumlah override ProviderScope tidak boleh berubah.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          bungkus(
            const [],
            FotoReviewScreen(
              baris: layar.baris,
              catatan: layar.catatan,
              kunciSkorMentah: layar.kunciSkorMentah,
            ),
          ),
        );
        await tester.pump();

        final acuan = lihat(tester);
        expect(dariAlur.teks, acuan.teks);
        expect(dariAlur.kunci, acuan.kunci);
      });
    }
  });
}
