import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/models/pratinjau_hitung.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Lembar kerja Micrometer membawa versi data acuan (CR-48 P4, FR-21).
///
///  1. **Kaki lembar** `data acuan <paket> v<n>` — tampil hanya bila server
///     menyebut versi data; tidak tampil untuk lembar tanpa `versi_acuan` atau
///     dengan `data: null` (`versi_acuan: null` dibaca sama dengan kunci yang
///     tidak ada — dijaga `lembar_kerja_etag_test.dart`).
///  2. **Tarik ulang** saat aplikasi kembali ke depan dan saat lembar dibuka
///     lagi — tanpa mengganggu isian yang sedang diketik.
///  3. **Tarikan ulang yang gagal diam.** Teknisi di tempat tanpa sinyal tidak
///     boleh kena snackbar galat untuk tarikan yang tidak dia minta.
void main() {
  Map<String, dynamic> versi(int nomor) => {
    'paket': 'micrometer',
    'data': {'nomor': nomor, 'sha256': 'sha-v$nomor'},
    'bentuk': null,
  };

  List<Override> overrides(LembarKerjaService service) => [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    lembarKerjaServiceProvider.overrideWithValue(service),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
  ];

  Widget materialApp(ValueNotifier<bool>? tampil) {
    const layar = LembarKerjaScreen(profil: 'micrometer');

    return MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: tampil == null
          ? layar
          : ValueListenableBuilder<bool>(
              valueListenable: tampil,
              builder: (_, t, _) => t ? layar : const SizedBox(),
            ),
    );
  }

  Widget app(LembarKerjaService service, {ValueNotifier<bool>? tampil}) =>
      ProviderScope(overrides: overrides(service), child: materialApp(tampil));

  Future<void> tunggu(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  void layarBesar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final kaki = find.byKey(const ValueKey('kaki-versi-acuan'));

  group('kaki lembar', () {
    testWidgets('versi_acuan ada → "data acuan micrometer v1", huruf angka', (
      tester,
    ) async {
      layarBesar(tester);
      await tester.pumpWidget(
        app(MockLembarKerjaService(versiAcuan: versi(1))),
      );
      await tunggu(tester);

      expect(find.text('data acuan micrometer v1'), findsOneWidget);

      final teks = tester.widget<Text>(kaki);
      expect(teks.style?.fontFamily, 'IBMPlexMono');
      // Versi bentuk lahir di P6 — bagian itu belum boleh tampil.
      expect(teks.data, isNot(contains('bentuk')));
    });

    testWidgets(
      'lembar tanpa versi_acuan (bentuk contoh/generator) → tidak tampil',
      (tester) async {
        layarBesar(tester);
        await tester.pumpWidget(app(MockLembarKerjaService()));
        await tunggu(tester);

        expect(kaki, findsNothing);
        // Lembarnya sendiri tetap jalan.
        expect(find.byType(TextField), findsWidgets);
      },
    );

    testWidgets(
      'versi_acuan.data null (server baca berkas JSON) → tidak tampil',
      (tester) async {
        layarBesar(tester);
        await tester.pumpWidget(
          app(
            MockLembarKerjaService(
              versiAcuan: {'paket': 'micrometer', 'data': null, 'bentuk': null},
            ),
          ),
        );
        await tunggu(tester);

        expect(kaki, findsNothing);
      },
    );
  });

  group('tarik ulang', () {
    testWidgets('kembali ke depan → ditarik ulang; isian yang diketik tetap', (
      tester,
    ) async {
      layarBesar(tester);
      final service = _LembarDiatur(versiAcuan: versi(1));
      await tester.pumpWidget(app(service));
      await tunggu(tester);
      final awal = service.panggilan;

      final bisaDiketik = find.byWidgetPredicate(
        (w) => w is TextField && w.enabled != false && !w.readOnly,
      );
      await tester.enterText(bisaDiketik.first, 'Merk Uji');
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tunggu(tester);

      expect(
        service.panggilan,
        awal + 1,
        reason: 'resume wajib bertanya ke server',
      );
      expect(find.text('Merk Uji'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('data acuan micrometer v1'), findsOneWidget);
    });

    testWidgets(
      'versi acuan berganti saat di latar → kaki ikut v2, isian tetap',
      (tester) async {
        layarBesar(tester);
        final service = _LembarDiatur(versiAcuan: versi(1));
        await tester.pumpWidget(app(service));
        await tunggu(tester);

        final bisaDiketik = find.byWidgetPredicate(
          (w) => w is TextField && w.enabled != false && !w.readOnly,
        );
        await tester.enterText(bisaDiketik.first, 'Merk Uji');
        await tester.pump();

        service.versiAcuan = versi(2);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tunggu(tester);

        expect(find.text('data acuan micrometer v2'), findsOneWidget);
        expect(find.text('Merk Uji'), findsOneWidget);
      },
    );

    testWidgets('tarikan ulang gagal (tanpa sinyal) → diam, formulir tetap', (
      tester,
    ) async {
      layarBesar(tester);
      final service = _LembarDiatur(versiAcuan: versi(1));
      await tester.pumpWidget(app(service));
      await tunggu(tester);

      service.gagal = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tunggu(tester);

      expect(service.panggilanGagal, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('data acuan micrometer v1'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets(
      'lembar dibuka lagi → ditarik ulang (provider-nya tidak dibuang)',
      (tester) async {
        layarBesar(tester);
        final service = _LembarDiatur(versiAcuan: versi(1));
        final tampil = ValueNotifier(true);
        addTearDown(tampil.dispose);

        await tester.pumpWidget(app(service, tampil: tampil));
        await tunggu(tester);
        final awal = service.panggilan;

        tampil.value = false;
        await tunggu(tester);
        expect(
          service.panggilan,
          awal,
          reason: 'menutup tidak menarik apa pun',
        );

        tampil.value = true;
        await tunggu(tester);

        expect(service.panggilan, awal + 1);
        expect(find.text('data acuan micrometer v1'), findsOneWidget);
      },
    );

    testWidgets(
      'dibuka pertama kali → tarik-ulang-saat-dibuka TIDAK menambah tarikan',
      (tester) async {
        layarBesar(tester);
        final service = _LembarDiatur(versiAcuan: versi(1));

        // Auth diselesaikan DULU: `lembarKerjaProvider` meng-`watch`
        // `authProvider`, jadi kalau auth selesai belakangan provider-nya
        // memang dibangun dua kali (perilaku lama, ada sebelum CR-48). Yang
        // diuji di sini cuma bahwa penjaga "sudah ada isinya?" menahan
        // invalidate pada pembukaan pertama.
        final c = ProviderContainer(overrides: overrides(service));
        addTearDown(c.dispose);
        // `runAsync`: MockAuthService menunggu `Future.delayed`, yang tidak
        // pernah maju di zona waktu palsu `testWidgets`.
        await tester.runAsync(() => c.read(authProvider.future));

        await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: materialApp(null)),
        );
        await tunggu(tester);

        expect(service.panggilan, 1);
      },
    );
  });
}

/// Layanan lembar yang jawabannya bisa diatur di tengah test. Bentuknya dari
/// [MockLembarKerjaService] (yang juga memulangkan objek SAMA untuk bentuk
/// yang sama — niru 304).
class _LembarDiatur implements LembarKerjaService {
  _LembarDiatur({this.versiAcuan});

  Map<String, dynamic>? versiAcuan;

  bool gagal = false;
  int panggilan = 0;
  int panggilanGagal = 0;

  final _dasar = <String, MockLembarKerjaService>{};

  MockLembarKerjaService get _mock {
    final v = versiAcuan;
    final kunci = '$v';
    return _dasar.putIfAbsent(
      kunci,
      () => MockLembarKerjaService(versiAcuan: v),
    );
  }

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async {
    panggilan++;
    if (gagal) {
      panggilanGagal++;
      throw const AuthException(
        'Nggak bisa nyambung ke server. Cek koneksi kamu.',
      );
    }

    return _mock.ambilBentuk(
      token,
      profil: profil,
      pengulangan: pengulangan,
      equipmentId: equipmentId,
    );
  }

  @override
  Future<PratinjauHitung> pratinjau(
    String token,
    LembarKerjaSubmission isian,
  ) => _mock.pratinjau(token, isian);

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) =>
      _mock.kirim(token, isian);

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) =>
      _mock.perbarui(token, id, isian);
}
