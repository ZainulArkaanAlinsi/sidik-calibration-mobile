import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_scan.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_review_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Layar pindai FORMULIR ASLI: tombolnya, layar review-nya, dan apa yang
/// sampai ke lembar kerja sesudah teknisi konfirmasi.
///
/// Template = fixture pH dari repo API (3222d1b); balasan pindai = bentuk
/// `WorksheetScanController::bentukHasil()` formulir asli, nilai dari contoh
/// B2. Bentuk lembar = `contohBentukLembarKerja()` (mock pH yang sama dengan
/// test lembar kerja lain: TH-2 = 40, buffer 4/7/10 = standar 2/3/4,
/// Victor belum terdaftar).
void main() {
  final dataTemplate =
      (jsonDecode(
                File(
                  'test/assets/template-asli-ph_meter-0509.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  WorksheetTemplate templateDengan([Map<String, dynamic> ubah = const {}]) =>
      WorksheetTemplate.fromJson({
        'data': {...dataTemplate, ...ubah},
      });

  group('tombol "Pindai formulir kertas"', () {
    void perbesar(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<MockWorksheetScanService> buka(
      WidgetTester tester, {
      WorksheetTemplate? formulirAsli,
      bool pindaiAktif = true,
    }) async {
      perbesar(tester);
      final scan = MockWorksheetScanService(formulirAsli: formulirAsli);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (!pindaiAktif)
              pindaiLembarAktifProvider.overrideWithValue(false),
            tokenStorageProvider.overrideWithValue(
              InMemoryTokenStorage('mock-token-1'),
            ),
            authServiceProvider.overrideWithValue(MockAuthService()),
            lembarKerjaServiceProvider.overrideWithValue(
              MockLembarKerjaService(),
            ),
            standardServiceProvider.overrideWithValue(MockStandardService()),
            roomServiceProvider.overrideWithValue(MockRoomService()),
            equipmentLookupServiceProvider.overrideWithValue(
              MockEquipmentLookupService(),
            ),
            worksheetScanServiceProvider.overrideWithValue(scan),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LembarKerjaScreen(profil: 'ph_meter'),
          ),
        ),
      );
      // `MockAuthService.me()` jeda 600 ms lewat Future.delayed.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      return scan;
    }

    testWidgets('mode uji nyala (belum siap) → tombol ADA + peringatan', (
      tester,
    ) async {
      final scan = await buka(tester, formulirAsli: templateDengan());

      expect(find.text('Pindai formulir kertas'), findsOneWidget);
      expect(
        find.text('Mode uji — semua hasil pindai wajib dicek.'),
        findsOneWidget,
      );
      // Yang diminta KODE ALAT, bukan nomor formulir.
      expect(scan.kodeAsliDiminta.first.kode, 'ph_meter');
    });

    testWidgets('siap_pindai & mode uji mati → tombol ada, tanpa peringatan', (
      tester,
    ) async {
      await buka(
        tester,
        formulirAsli: templateDengan({'siap_pindai': true, 'mode_uji': false}),
      );

      expect(find.text('Pindai formulir kertas'), findsOneWidget);
      expect(
        find.text('Mode uji — semua hasil pindai wajib dicek.'),
        findsNothing,
      );
    });

    testWidgets('belum siap & mode uji MATI (produksi sekarang) → TIDAK ada', (
      tester,
    ) async {
      await buka(
        tester,
        formulirAsli: templateDengan({'siap_pindai': false, 'mode_uji': false}),
      );

      // Lembarnya beneran kebangun — jangkar supaya `findsNothing` di bawah
      // tidak hijau gara-gara layar kosong.
      expect(find.text('Simpan sebagai draft'), findsOneWidget);
      expect(find.text('Pindai formulir kertas'), findsNothing);
    });

    testWidgets('alat tanpa formulir asli (server 404) → TIDAK ada', (
      tester,
    ) async {
      await buka(tester);

      expect(find.text('Simpan sebagai draft'), findsOneWidget);
      expect(find.text('Pindai formulir kertas'), findsNothing);
    });

    testWidgets('saklar kamera dimatikan → TIDAK ada walau template siap', (
      tester,
    ) async {
      await buka(
        tester,
        formulirAsli: templateDengan({'siap_pindai': true}),
        pindaiAktif: false,
      );

      expect(find.text('Simpan sebagai draft'), findsOneWidget);
      expect(find.text('Pindai formulir kertas'), findsNothing);
    });
  });

  group('layar review formulir asli', () {
    Future<({MockWorksheetScanService scan, List<Object?> kembali})> buka(
      WidgetTester tester, {
      Map<String, dynamic>? balasan,
    }) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final hasil = HasilPindai.fromJson(balasan ?? _balasan);
      final scan = MockWorksheetScanService(hasil: hasil);
      final kembali = <Object?>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              InMemoryTokenStorage('mock-token-1'),
            ),
            authServiceProvider.overrideWithValue(MockAuthService()),
            worksheetScanServiceProvider.overrideWithValue(scan),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _Peluncur(
              hasil: hasil,
              onKembali: kembali.add,
              labelKode: (kode) => switch (kode) {
                'suhu_awal' => 'Env. Condition — First',
                'thermohygro_standard_id' => '6. Thermohygro used',
                'standar_dicek.*.dipakai' => 'Usage Check',
                _ => null,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return (scan: scan, kembali: kembali);
    }

    testWidgets('banner mode uji, isian & centang tampil dengan labelnya', (
      tester,
    ) async {
      await buka(tester);

      expect(find.textContaining('MODE UJI'), findsOneWidget);
      expect(find.text('Isian di luar tabel'), findsOneWidget);
      expect(find.text('Env. Condition — First (°C)'), findsOneWidget);
      expect(find.text('Kotak centang'), findsOneWidget);
      expect(find.text('6. Thermohygro used'), findsOneWidget);
      expect(find.text('Usage Check'), findsOneWidget);
      expect(find.text('pH Buffer Solutions 4'), findsOneWidget);
      expect(find.text('TH-2'), findsOneWidget);
      // Bacaan mesin ditulis, bukan cuma tercermin di kotak awal.
      expect(find.text('Terbaca mesin: dicentang'), findsWidgets);
      expect(find.text('Terbaca mesin: ragu'), findsOneWidget);
      // Alasan sebagai kalimat, bukan kode mentah.
      expect(find.textContaining('template_belum_terverifikasi'), findsNothing);
      expect(
        find.textContaining('mode uji — formulir ini belum terverifikasi'),
        findsWidgets,
      );
    });

    testWidgets('mundur tanpa konfirmasi → tidak ada apa pun yang kembali', (
      tester,
    ) async {
      final r = await buka(tester);

      // Tombol kembali sistem (Android).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(r.kembali, [null]);
      expect(r.scan.koreksiTerkirim, isEmpty);
    });

    testWidgets(
      'konfirmasi: isian & centang ikut, ragu mulai TIDAK dicentang',
      (tester) async {
        final r = await buka(tester);

        // Teknisi membetulkan suhu awal.
        await tester.enterText(
          find.widgetWithText(TextField, 'Env. Condition — First (°C)'),
          '25,2',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pakai angka ini'));
        await tester.pumpAndSettle();

        final k = r.kembali.single! as KonfirmasiPindai;

        expect(k.isian.single.kode, 'suhu_awal');
        expect(k.isian.single.nilai, 25.2);
        expect(k.isian.single.perluDicek, isTrue);

        bool? dicentang(String? pilihan, int? baris) => k.centang
            .firstWhere((c) => c.pilihan == pilihan && c.barisKe == baris)
            .dicentang;

        expect(dicentang('TH-2', null), isTrue);
        // Ragu (dicentang: null) mulai kosong — teknisi yang menyalakan.
        expect(dicentang(null, 2), isFalse);
        expect(dicentang(null, 1), isTrue);

        // Koreksi: SEMUA butir, centang cuma 0/1.
        final koreksi = {
          for (final x in r.scan.koreksiTerkirim.single) x.kunci: x.nilaiFinal,
        };
        expect(koreksi['isian|suhu_awal'], 25.2);
        expect(koreksi['centang|thermohygro_standard_id|TH-2'], 1);
        expect(koreksi['centang|standar_dicek._.dipakai|2'], 0);
        expect(koreksi['centang|standar_dicek._.dipakai|1'], 1);
      },
    );

    testWidgets('TH-n cuma satu: menyalakan TH-4 mematikan TH-2', (
      tester,
    ) async {
      final r = await buka(tester);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'TH-4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pakai angka ini'));
      await tester.pumpAndSettle();

      final k = r.kembali.single! as KonfirmasiPindai;
      final th = {
        for (final c in k.centang)
          if (c.pilihan != null) c.pilihan: c.dicentang,
      };
      expect(th, {'TH-2': false, 'TH-4': true});
    });
  });

  group('konfirmasi → lembar kerja', () {
    LembarKerjaState lembar() => LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uuid-test',
    );

    KonfirmasiPindai konfirmasi() => const KonfirmasiPindai(
      sel: [],
      isian: [
        (kode: 'suhu_awal', nilai: 25.2, perluDicek: true),
        (kode: 'kelembaban_awal', nilai: 60, perluDicek: true),
        (kode: 'suhu_akhir', nilai: 25.4, perluDicek: true),
        (kode: 'kelembaban_akhir', nilai: 61, perluDicek: true),
      ],
      centang: [
        (
          kode: 'thermohygro_standard_id',
          pilihan: 'TH-2',
          barisKe: null,
          label: null,
          dicentang: true,
        ),
        (
          kode: 'thermohygro_standard_id',
          pilihan: 'TH-6',
          barisKe: null,
          label: null,
          dicentang: false,
        ),
        (
          kode: 'standar_dicek.*.dipakai',
          pilihan: null,
          barisKe: 1,
          label: 'pH Buffer Solutions 4',
          dicentang: true,
        ),
        (
          kode: 'standar_dicek.*.dipakai',
          pilihan: null,
          barisKe: 2,
          label: 'pH Buffer Solutions 7',
          dicentang: false,
        ),
        // Baris yang standarnya belum terdaftar di master — tidak bisa
        // ditautkan, jadi dilewati (bukan dipaksa ke baris lain).
        (
          kode: 'standar_dicek.*.dipakai',
          pilihan: null,
          barisKe: 5,
          label: 'Victor 14+/992613877',
          dicentang: true,
        ),
      ],
    );

    test('mengisi kolom yang benar lewat identitas server', () {
      final isian = lembar();
      final hasil = isian.terapkanKonfirmasiPindai(konfirmasi());

      expect(isian.teks['suhu_awal']!.text, '25.2');
      expect(isian.teks['kelembaban_awal']!.text, '60');
      expect(isian.teks['suhu_akhir']!.text, '25.4');
      expect(isian.teks['kelembaban_akhir']!.text, '61');
      // TH-2 → nilai pilihan kolom `thermohygro_standard_id` (40), bukan
      // posisinya di daftar.
      expect(isian.thermohygroStandardId, 40);
      expect(isian.usage(2).dipakai, isTrue);
      expect(isian.usage(3).dipakai, isFalse);
      expect(isian.adaIsianDariFoto, isTrue);

      expect(hasil.terisi, 6);
      expect(hasil.dilewati, 1); // Victor, belum terdaftar.
    });

    test('TIDAK menimpa yang sudah diisi teknisi', () {
      final isian = lembar()
        ..teks['suhu_awal']!.text = '24,8'
        ..thermohygroStandardId = 41;
      isian.usage(2).keterangan.text = 'botol baru';

      final hasil = isian.terapkanKonfirmasiPindai(konfirmasi());

      expect(isian.teks['suhu_awal']!.text, '24,8');
      expect(isian.thermohygroStandardId, 41);
      // Baris yang sudah punya isian tidak disentuh — termasuk centangnya.
      expect(isian.usage(2).dipakai, isFalse);
      expect(isian.teks['kelembaban_awal']!.text, '60');
      expect(hasil.dilewati, 4);
    });

    test('"kosong" di kertas tidak pernah mematikan centang teknisi', () {
      final isian = lembar();
      isian.usage(3).dipakai = true;

      isian.terapkanKonfirmasiPindai(konfirmasi());

      expect(isian.usage(3).dipakai, isTrue);
    });

    test('kode centang yang tidak dikenal lembar ini dilewati', () {
      final isian = lembar();
      final hasil = isian.terapkanKonfirmasiPindai(
        const KonfirmasiPindai(
          sel: [],
          centang: [
            (
              kode: 'tipe_sensor',
              pilihan: 'K',
              barisKe: null,
              label: null,
              dicentang: true,
            ),
          ],
        ),
      );

      expect(hasil, (terisi: 0, dilewati: 1));
      expect(isian.adaIsianDariFoto, isFalse);
    });
  });
}

/// Balasan pindai formulir asli (pangkas): satu isian, centang TH-2/TH-4 dan
/// Usage Check baris 1 (dicentang) & 2 (ragu).
final _balasan = <String, dynamic>{
  'scan_id': 77,
  'status': 'perlu_review',
  'ringkasan': {
    'total_sel': 5,
    'hijau': 0,
    'kuning': 5,
    'merah': 0,
    'kosong': 0,
  },
  'tabel': <dynamic>[],
  'boleh_auto_isi': true,
  'wajib_dicek': true,
  'kertas': 'asli',
  'mode_uji': true,
  'isian': [
    {
      'kode': 'suhu_awal',
      'kunci': 'isian|suhu_awal',
      'satuan': '°C',
      'teks_mentah': '25,0',
      'nilai': 25,
      'status': 'kuning',
      'alasan': ['template_belum_terverifikasi'],
      'normalisasi': <String>[],
    },
  ],
  'centang': [
    _centang('thermohygro_standard_id', pilihan: 'TH-2', dicentang: true),
    _centang('thermohygro_standard_id', pilihan: 'TH-4', dicentang: false),
    _centang(
      'standar_dicek.*.dipakai',
      baris: 1,
      label: 'pH Buffer Solutions 4',
      dicentang: true,
    ),
    _centang(
      'standar_dicek.*.dipakai',
      baris: 2,
      label: 'pH Buffer Solutions 7',
      dicentang: null,
      alasan: ['centang_ragu', 'template_belum_terverifikasi'],
    ),
  ],
};

Map<String, dynamic> _centang(
  String kode, {
  String? pilihan,
  int? baris,
  String? label,
  required bool? dicentang,
  List<String> alasan = const ['template_belum_terverifikasi'],
}) => {
  'kunci': 'centang|${kode.replaceAll('*', '_')}|${pilihan ?? baris ?? 0}',
  'kode': kode,
  'pilihan': pilihan,
  'baris_ke': baris,
  'label': label,
  'rasio_gelap': dicentang == null ? 0.09 : (dicentang ? 0.4 : 0.01),
  'dicentang': dicentang,
  'nilai': dicentang == null ? null : (dicentang ? 1 : 0),
  'status': 'kuning',
  'alasan': alasan,
  'pesan': null,
};

class _Peluncur extends StatefulWidget {
  const _Peluncur({
    required this.hasil,
    required this.onKembali,
    required this.labelKode,
  });

  final HasilPindai hasil;
  final void Function(KonfirmasiPindai?) onKembali;
  final String? Function(String) labelKode;

  @override
  State<_Peluncur> createState() => _PeluncurState();
}

class _PeluncurState extends State<_Peluncur> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onKembali(
        await PindaiReviewScreen.bukaFormulirAsli(
          Navigator.of(context),
          widget.hasil,
          labelKode: widget.labelKode,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
