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

/// Alur "Foto lembar kerja" (`pindaiFormulirAsli`) setelah layar periksa
/// dihapus (keputusan pemilik 28 Nov 2026): hasil baca langsung masuk lembar.
///
/// Layar periksa adalah satu-satunya tempat tombol "Minta usulan awan", jadi
/// alur ini tidak punya jalan ke OCR awan lagi. Tes di sini mengunci itu: di
/// SEMUA keadaan gerbang awan (terbuka maupun tertutup), alur tidak membuka
/// layar periksa, tidak membaca token, dan tidak mengirim satu pun permintaan.
///
/// Bentuk permintaan 22B (`equipment_id` ada bila alat dipilih dan tidak ada bila
/// tidak, `template_id`, `kertas`, `sel[n][kunci]`) kini dikunci di tingkat
/// servis oleh `ocr_awan_sel_service_test.dart`, bukan lewat alur ini.
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
      // Gagal dibaca = sel kosong; potongannya ada, jadi dulu layak ditawarkan
      // ke awan lewat layar periksa.
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

  /// Menjalankan alur sampai hasil baca masuk lembar (pemberitahuan tampil).
  /// Tidak ada layar periksa yang ditunggu.
  Future<void> jalankanAlur(
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
      if (find.byType(SnackBar).evaluate().isNotEmpty) break;
    }
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  }

  const izinBoleh = Izin(role: null, boleh: {'alat.lihat'});

  group('foto lembar langsung ke lembar: tanpa layar periksa, nol jaringan', () {
    final kasus = <String, ({SakelarOcr sakelar, Izin izin})>{
      // Gerbang TERBUKA: dulu layar periksa menawarkan "Minta usulan awan".
      // Sekarang alur tidak punya layar itu, jadi tidak ada jalan ke awan.
      'gerbang awan terbuka (sakelar klien + izin)': (
        sakelar: const SakelarOcr(ocrAwanSel: true),
        izin: izinBoleh,
      ),
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
      for (final denganAlat in [true, false]) {
        testWidgets('$nama, ${denganAlat ? 'alat dipilih' : 'tanpa alat'}', (
          tester,
        ) async {
          final klien = _Client();
          final token = _TokenHitung();
          final servis = MockOcrAwanSelService();

          await jalankanAlur(
            tester,
            isian: buatState(alat: denganAlat ? alat42 : null),
            overrides: [
              sakelarOcrProvider.overrideWithValue(k.sakelar),
              izinProvider.overrideWith((ref) async => k.izin),
              tokenStorageProvider.overrideWithValue(token),
              ocrAwanSelServiceProvider.overrideWithValue(servis),
            ],
          );

          // Tanpa layar periksa dan tanpa tombol usulan awan.
          expect(find.byType(FotoReviewScreen), findsNothing);
          expect(find.byKey(_tombolMinta), findsNothing);

          // Nol panggilan jaringan; token tidak pernah dibaca.
          expect(servis.permintaan, isEmpty);
          expect(token.dibaca, 0);
          expect(klien.kolom, isEmpty);
        });
      }
    }

    testWidgets('servis awan ASLI terpasang dan gerbang terbuka: tetap nol '
        'permintaan HTTP dari alur foto lembar', (tester) async {
      final klien = _Client();
      final token = _TokenHitung();

      await jalankanAlur(
        tester,
        isian: buatState(alat: alat42),
        overrides: [
          sakelarOcrProvider.overrideWithValue(
            const SakelarOcr(ocrAwanSel: true),
          ),
          izinProvider.overrideWith((ref) async => izinBoleh),
          tokenStorageProvider.overrideWithValue(token),
          ocrAwanSelServiceProvider.overrideWithValue(
            ApiOcrAwanSelService(
              ApiClient(client: klien, baseUrl: 'http://contoh.test/api'),
            ),
          ),
        ],
      );

      expect(find.byType(FotoReviewScreen), findsNothing);
      expect(klien.kolom, isEmpty);
      expect(token.dibaca, 0);
    });
  });
}
