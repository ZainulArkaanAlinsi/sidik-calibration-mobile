import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_draft.dart' show LokasiKalibrasi;
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Inlab nanya RUANGAN, Insitu nanya NAMA TEMPAT — dan yang nggak ditanya wajib
/// ikut KOSONG di payload, bukan cuma ilang dari layar.
///
/// Ini bug 6 Agt 2026 yang kecetak di dokumen resmi: dropdown `Ruangan` selalu
/// tampil dan nggak pernah direset, jadi teknisi yang milih Inlab dulu lalu
/// pindah ke Insitu tetap ngirim `room_id` lab. Sertifikat kunjungan ke
/// pelanggan kecetak nama ruang lab — tempat yang alatnya nggak pernah ke sana.
/// Makanya yang diuji di sini PAYLOAD-nya, bukan cuma kotaknya kelihatan apa
/// nggak: layar yang bener sambil payload yang kotor persis keadaan waktu itu.
const _labelRuangan = 'Ruangan (Inlab)';
const _labelNamaTempat = 'Nama Tempat (Insitu)';
const _ruanganPertama = 'LAB-A — Lab. Uji A';

Widget _app(MockLembarKerjaService service) => ProviderScope(
  overrides: [
    pindaiLembarAktifProvider.overrideWithValue(false),
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
    authServiceProvider.overrideWithValue(MockAuthService()),
    lembarKerjaServiceProvider.overrideWithValue(service),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LembarKerjaScreen(profil: 'ph_meter'),
  ),
);

/// Viewport raksasa biar seluruh formulir ke-build sekaligus — `ListView` cuma
/// nge-build yang deket layar, dan kotak lokasi ada di bagian tengah lembar.
/// Lebarnya di bawah ambang dua kolom (1100): yang diuji isian & payloadnya,
/// bukan tata letak layar lebar.
Future<MockLembarKerjaService> _buka(
  WidgetTester tester, {
  MockLembarKerjaService? service,
}) async {
  tester.view.physicalSize = const Size(900, 16000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final dipakai = service ?? MockLembarKerjaService();
  await tester.pumpWidget(_app(dipakai));
  // `MockAuthService.me()` jeda 600 ms lewat `Future.delayed`, dan timer kayak
  // gitu nggak ngejadwalin frame — `pumpAndSettle` doang balik kecepetan.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();

  return dipakai;
}

/// `equipment_id` wajib di payload, jadi tiap test yang ngirim mesti lewat sini.
Future<void> _pilihAlat(WidgetTester tester) async {
  await tester.tap(find.text('Pilih alat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
  await tester.pumpAndSettle();
}

/// Dropdown-nya dibuka lewat WIDGET-nya, bukan lewat teks labelnya: label
/// `InputDecorator` duduk di luar kotak yang bisa dipencet, jadi `tap` ke
/// teksnya nyasar ke tempat lain dan cuma kebetulan kena.
Future<void> _pilihLokasi(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.text('1. Location'),
      matching: find.byType(DropdownButtonFormField<LokasiKalibrasi>),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pilihRuangan(WidgetTester tester) async {
  await tester.tap(
    find.ancestor(
      of: find.text(_labelRuangan),
      matching: find.byType(DropdownButtonFormField<int>),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(_ruanganPertama).last);
  await tester.pumpAndSettle();
}

Future<void> _simpanDraft(WidgetTester tester) async {
  await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
  await tester.pumpAndSettle();
}

void main() {
  group('kotak lokasi: yang tampil ngikut `tampil_kalau`, bukan nama kolom', () {
    testWidgets('bawaan Inlab → Ruangan tampil, Nama Tempat nggak', (
      tester,
    ) async {
      await _buka(tester);

      expect(find.text(_labelRuangan), findsOneWidget);
      expect(find.text(_labelNamaTempat), findsNothing);
    });

    testWidgets('pilih Insitu → Ruangan ilang, Nama Tempat muncul + contohnya',
        (tester) async {
      await _buka(tester);
      await _pilihLokasi(tester, 'Insitu');

      expect(find.text(_labelRuangan), findsNothing);
      expect(find.text(_labelNamaTempat), findsOneWidget);

      // Contohnya, bukan istilah sistem: "Nama Tempat" doang kebaca macam-macam
      // di lapangan, dan yang keketik mendarat di sertifikat sebagai
      // `Calibration Location : Insitu (…)`.
      expect(find.text('Contoh: PT. LDC'), findsOneWidget);
    });

    /// INTI bug-nya. Yang diperiksa payload, bukan tampilan: kotak yang ilang
    /// dari layar tapi nilainya masih kekirim itu keadaan yang bikin sertifikat
    /// Insitu kecetak nama ruang lab, dan nggak ada satu pun yang kelihatan
    /// salah di layar teknisi.
    testWidgets('ruangan udah kepilih lalu pindah Insitu → `room_id` null', (
      tester,
    ) async {
      final service = await _buka(tester);
      await _pilihAlat(tester);

      await _pilihRuangan(tester);
      await _pilihLokasi(tester, 'Insitu');

      await tester.enterText(
        find.widgetWithText(TextField, _labelNamaTempat),
        'PT. LDC',
      );
      await tester.pumpAndSettle();
      await _simpanDraft(tester);

      expect(service.payloadTerakhir!['lokasi'], 'onsite');
      expect(service.payloadTerakhir!['lokasi_nama'], 'PT. LDC');
      expect(service.payloadTerakhir!['room_id'], isNull);
    });

    /// Arah sebaliknya, dan sama seriusnya: `lokasi_nama` yang nyangkut bikin
    /// `CertificateSnapshotBuilder` nulis `Insitu (PT. LDC)` buat sesi yang
    /// lokasinya `lab`.
    testWidgets('nama tempat udah diketik lalu balik Inlab → `lokasi_nama` null',
        (tester) async {
      final service = await _buka(tester);
      await _pilihAlat(tester);

      await _pilihLokasi(tester, 'Insitu');
      await tester.enterText(
        find.widgetWithText(TextField, _labelNamaTempat),
        'PT. LDC',
      );
      await tester.pumpAndSettle();

      await _pilihLokasi(tester, 'Inlab');
      await _pilihRuangan(tester);
      await _simpanDraft(tester);

      expect(service.payloadTerakhir!['lokasi'], 'lab');
      expect(service.payloadTerakhir!['room_id'], 1);
      expect(service.payloadTerakhir!['lokasi_nama'], isNull);
    });

    /// Bolak-balik juga nggak boleh ninggalin sisa: teknisi yang salah pencet
    /// lalu balikin lagi mesti dapat kotak KOSONG, bukan nilai lama yang
    /// diam-diam idup lagi.
    testWidgets('balik lagi ke Insitu → kotaknya kosong, bukan isi yang lama', (
      tester,
    ) async {
      final service = await _buka(tester);
      await _pilihAlat(tester);

      await _pilihLokasi(tester, 'Insitu');
      await tester.enterText(
        find.widgetWithText(TextField, _labelNamaTempat),
        'PT. LDC',
      );
      await tester.pumpAndSettle();

      await _pilihLokasi(tester, 'Inlab');
      await _pilihLokasi(tester, 'Insitu');

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, _labelNamaTempat))
            .controller!
            .text,
        isEmpty,
      );

      await _simpanDraft(tester);
      expect(service.payloadTerakhir!['lokasi_nama'], isNull);
    });
  });

  /// Lab nge-update HP duluan, servernya belakangan. Selama itu bentuk lembar
  /// datang tanpa `tampil_kalau` sama sekali, dan APK baru wajib tetap kepakai.
  group('server lama (belum ngirim `tampil_kalau`)', () {
    testWidgets('Ruangan tetap tampil walau Insitu — persis perilaku lama', (
      tester,
    ) async {
      await _buka(tester, service: MockLembarKerjaService(tanpaTampilKalau: true));
      await _pilihLokasi(tester, 'Insitu');

      // Nggak ideal, tapi ini yang lama: yang ngasih tau teknisi kotak mana yang
      // berlaku tinggal label `(Inlab)`/`(Insitu)`-nya. Yang nggak boleh justru
      // sebaliknya — kotak ilang gara-gara penanda yang emang nggak pernah
      // dikirim server.
      expect(find.text(_labelRuangan), findsOneWidget);
      expect(find.text(_labelNamaTempat), findsOneWidget);
    });

    testWidgets('Nama Tempat tetap disembunyiin waktu Inlab', (tester) async {
      await _buka(tester, service: MockLembarKerjaService(tanpaTampilKalau: true));

      expect(find.text(_labelNamaTempat), findsNothing);
      expect(find.text(_labelRuangan), findsOneWidget);
    });
  });

  group('SyaratTampil.fromJson', () {
    test('bentuk yang bener kebaca', () {
      final syarat = SyaratTampil.fromJson({
        'kode': 'lokasi',
        'nilai': ['onsite'],
      });

      expect(syarat!.kode, 'lokasi');
      expect(syarat.dipenuhi('onsite'), isTrue);
      expect(syarat.dipenuhi('lab'), isFalse);
    });

    /// Bentuk yang nggak kebaca jatuh ke "selalu tampil", BUKAN "selalu
    /// disembunyiin". Kotak nyasar itu ganggu; kotak yang ilang bikin teknisi
    /// nggak bisa nyelesein lembarnya dan nggak punya cara tahu kenapa.
    test('yang nggak lengkap / bukan map → null, artinya selalu tampil', () {
      expect(SyaratTampil.fromJson(null), isNull);
      expect(SyaratTampil.fromJson('onsite'), isNull);
      expect(SyaratTampil.fromJson({'kode': 'lokasi'}), isNull);
      expect(SyaratTampil.fromJson({'kode': 'lokasi', 'nilai': []}), isNull);
      expect(SyaratTampil.fromJson({'nilai': ['onsite']}), isNull);
    });

    /// Nilai acuan yang nggak ketauan dianggap kepenuhan — lihat alasan yang
    /// sama di atas.
    test('nilai acuan null → dianggap kepenuhan', () {
      final syarat = SyaratTampil.fromJson({
        'kode': 'lokasi',
        'nilai': ['onsite'],
      });

      expect(syarat!.dipenuhi(null), isTrue);
    });
  });
}
