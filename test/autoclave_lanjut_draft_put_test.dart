import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/autoclave_hasil.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/autoclave_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/autoclave_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **Draft Autoklaf yang dilanjutkan disimpan ke sesi YANG SAMA.**
///
/// Sampai 14 Okt 2026 `_kirimMatriks` selalu `POST /calibrations/autoclave`
/// dan mengabaikan `sesiId`. Lembar yang dibuka ulang membawa
/// `client_request_id` baru, jadi tiap "Simpan draft" melahirkan sesi Autoklaf
/// kembar di server.
///
/// Pasangannya ikut diuji: begitu simpannya `PUT`, matriks yang KOSONG waktu
/// dibuka ulang akan menimpa lembar di server. Jadi yang dibuktikan bukan cuma
/// "metodenya PUT", tapi juga "angka lama ikut terkirim balik".
///
/// Angka lembar di bawah bukan angka kalibrasi yang dihitung — cuma isian yang
/// diadu bolak-balik (server → layar → payload), jadi bentuknya yang penting,
/// bukan nilainya. Bentuk `lembar` disalin dari payload
/// `POST /calibrations/autoclave` (`AutoclaveStoreRequest::dataUkur`, API).
void main() {
  setUp(() => MockStore.instance.reset());

  Future<MockAutoclaveService> buka(
    WidgetTester tester, {
    int? sesiId,
    Map<String, dynamic> hasilAutoclave = const {'lembar': _lembar},
  }) async {
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final autoclave = MockAutoclaveService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(
            _RiwayatAutoklaf(hasilAutoclave),
          ),
          lembarKerjaServiceProvider.overrideWithValue(
            MockLembarKerjaService(),
          ),
          autoclaveServiceProvider.overrideWithValue(autoclave),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Dibungkus tombol: simpan yang sukses memanggil `Navigator.pop`,
          // jadi layarnya butuh rute di bawahnya.
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LembarKerjaScreen(
                        profil: 'autoclave',
                        sesiId: sesiId,
                      ),
                    ),
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    return autoclave;
  }

  Future<void> pilihAlatLaluSimpanDraft(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentLookup>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan sebagai draft'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('draft yang dilanjutkan: PUT ke id sesinya, bukan POST baru', (
    tester,
  ) async {
    final autoclave = await buka(tester, sesiId: 88);

    await pilihAlatLaluSimpanDraft(tester);

    expect(autoclave.panggilan, hasLength(1));
    final p = autoclave.panggilan.single;
    expect(p.metode, 'PUT', reason: 'Draft lama disimpan jadi sesi kembar.');
    expect(p.id, 88);
    expect(p.payload['status'], 'draft');
  });

  testWidgets('matriks lama dipulihkan, jadi PUT tidak menimpanya dengan '
      'kotak kosong', (tester) async {
    final autoclave = await buka(tester, sesiId: 88);

    await pilihAlatLaluSimpanDraft(tester);

    final payload = autoclave.panggilan.single.payload;
    final suhu = payload['suhu'] as Map<String, dynamic>;
    final tekanan = payload['tekanan'] as Map<String, dynamic>;

    expect(suhu['disk'], _lembar['suhu']['disk']);
    expect(suhu['indikator'], _lembar['suhu']['indikator']);
    expect(
      tekanan['indikator_pressure'],
      _lembar['tekanan']['indikator_pressure'],
    );
    expect(tekanan['satuan'], 'Bar');
    expect(payload['waktu'], _lembar['waktu']);
    expect(payload['set_point'], 121);
  });

  testWidgets('lembar baru tetap POST', (tester) async {
    final autoclave = await buka(tester);

    await pilihAlatLaluSimpanDraft(tester);

    expect(autoclave.panggilan, hasLength(1));
    final p = autoclave.panggilan.single;
    expect(p.metode, 'POST');
    expect(p.id, isNull);
    expect(p.payload['status'], 'draft');
  });

  // Kontrak API 14 Okt 2026 (`docs/kontrak-api.md`, PUT
  // /calibrations/autoclave/{id}): draf Autoklaf boleh disimpan TANPA set
  // point, jadi `hasil_autoclave.set_point` dan `lembar.set_point` bisa null.
  // Review 14 Okt 2026: tebakan mesin (`hasil_autoclave.ocr`) ikut pulih,
  // supaya PUT ulang nggak menghapus bahan pengukur akurasi kamera. Bentuk
  // `ocr` di sini = yang dikirim `payloadMatriks` (deret per `kode_data`,
  // wadah bernomor diratakan, sejajar indeks dengan deret nilainya).
  testWidgets('draf Autoklaf dari foto dibuka ulang: PUT mengirim blok ocr '
      'yang sama', (tester) async {
    const lembarFoto = <String, dynamic>{
      'suhu': {
        'disk': [
          [121.3, 121.4, 121.2, 121.3, 121.5],
          [121.1, 121.2, 121.2, 121.4, 121.3],
          [121.6, 121.5, 121.4, 121.5, 121.6],
        ],
      },
    };
    const ocr = <String, dynamic>{
      'suhu': {
        'disk': [
          [
            {'raw_text': '121.3', 'confidence': 0.91},
            {'raw_text': '121,4', 'confidence': 0.42},
            null,
            null,
            null,
          ],
          [null, null, null, null, null],
          [
            null,
            null,
            null,
            null,
            {'raw_text': '121.6'},
          ],
        ],
      },
    };

    final autoclave = await buka(
      tester,
      sesiId: 88,
      hasilAutoclave: const {'lembar': lembarFoto, 'ocr': ocr},
    );

    // Sel bertebakan ditandai "dari foto" lagi (penanda & tebakan selalu
    // lahir bersamaan di jalur foto).
    final sel = tester.widget(find.byKey(const Key('matriks_suhu.disk.0_1')));
    expect((sel as dynamic).dariFoto, isTrue);
    final selKetik = tester.widget(
      find.byKey(const Key('matriks_suhu.disk.1_1')),
    );
    expect((selKetik as dynamic).dariFoto, isFalse);

    await pilihAlatLaluSimpanDraft(tester);

    final p = autoclave.panggilan.single;
    expect(p.metode, 'PUT');
    expect(p.payload['ocr'], ocr);
  });

  group('draf tanpa set point', () {
    const lembarTanpaSetPoint = <String, dynamic>{
      'waktu': ['10:00:00', '10:01:00', '10:02:00', '10:03:00', '10:04:00'],
      'suhu': {
        'disk': [
          [121.3, 121.4, 121.2, 121.3, 121.5],
        ],
      },
    };
    const hasil = <String, dynamic>{
      'set_point': null,
      'suhu': null,
      'tekanan': null,
      'lembar': lembarTanpaSetPoint,
    };

    test('detail sesi terbaca: set point null, lembar tetap ada', () {
      final detail = CalibrationDetail.fromJson({
        'id': 88,
        'status': 'draft',
        'equipment': {'nama_alat': 'Autoclave', 'profil': 'autoclave'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil_autoclave': hasil,
      });

      expect(detail.autoclave, isNotNull);
      expect(detail.autoclave!.setPoint, isNull);
      expect(detail.autoclave!.suhu, isNull);
      expect(detail.lembarAutoclave, lembarTanpaSetPoint);
    });

    test('respons olah data dengan set point null nggak meledak', () {
      final h = AutoclaveHasil.fromJson({
        'data': {'set_point': null, 'suhu': {}, 'tekanan': {}},
      });
      expect(h.setPoint, isNull);
    });

    testWidgets('dibuka ulang lalu disimpan: matriksnya ikut, set point '
        'tetap absen (bukan 0)', (tester) async {
      final autoclave = await buka(tester, sesiId: 88, hasilAutoclave: hasil);

      await pilihAlatLaluSimpanDraft(tester);

      final p = autoclave.panggilan.single;
      expect(p.metode, 'PUT');
      expect(p.payload.containsKey('set_point'), isFalse);
      expect(
        (p.payload['suhu'] as Map)['disk'],
        (lembarTanpaSetPoint['suhu'] as Map)['disk'],
      );
    });
  });
}

const _lembar = <String, dynamic>{
  'set_point': 121,
  'waktu': ['10:00:00', '10:01:00', '10:02:00', '10:03:00', '10:04:00'],
  'suhu': {
    'disk': [
      [121.3, 121.4, 121.2, 121.3, 121.5],
      [121.1, 121.2, 121.2, 121.4, 121.3],
      [121.6, 121.5, 121.4, 121.5, 121.6],
    ],
    'indikator': [121, 121, 121, 121, 121],
  },
  'tekanan': {
    'indikator_pressure': [1.1, 1.1, 1.1, 1.1, 1.1],
    'satuan': 'Bar',
  },
};

class _RiwayatAutoklaf extends MockHistoryService {
  _RiwayatAutoklaf(this.hasilAutoclave);

  final Map<String, dynamic> hasilAutoclave;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': id,
        'status': 'draft',
        'desimal': 2,
        'equipment': {'nama_alat': 'Autoclave', 'profil': 'autoclave'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil': {'keputusan': null},
        'titik': const <Map<String, dynamic>>[],
        'pembacaan_mentah': const <Map<String, dynamic>>[],
        'hasil_autoclave': hasilAutoclave,
      });
}
