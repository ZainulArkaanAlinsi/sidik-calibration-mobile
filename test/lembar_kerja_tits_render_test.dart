import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar lembar kerja **TITS** (Temperature Indikator Tanpa Sensor, alat ke-11).
///
/// Sama seperti sepuluh alat lain, TITS lewat `LembarKerjaScreen` yang generik —
/// nggak punya layar sendiri kayak Autoklaf. Yang bikin dia gampang salah bukan
/// strukturnya, melainkan EMPAT hal yang cuma dia punya, dan tiga di antaranya
/// gagal tanpa memunculkan error:
///
///  1. **Judul kolom bertukar sisi antar mode.** Mode `measure` kolom kirinya
///     setpoint kalibrator, mode `source` justru angka di UUT. Judul yang salah
///     bikin teknisi ngisi kolom yang keliru dan angkanya tetap masuk.
///  2. **Enam pembacaan berarah** — UP ×3 lalu DOWN ×3.
///  3. **Titik ukur boleh ditambah/dihapus** — barisnya cuma saran.
///  4. **Dua dropdown yang nentuin ANGKA**: `mode_kalibrasi` & `tipe_sensor`.
void main() {
  Widget app(String profil) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
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
        home: LembarKerjaScreen(profil: profil),
      ),
    );
  }

  Future<void> buka(WidgetTester tester, String profil) async {
    tester.view.physicalSize = const Size(1400, 5200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(profil));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('bentuk lembar TITS', () {
    test('kunci lama tetap bertipe lama, bentuk baru di kunci tambahan', () {
      final lembar = LembarKerja.fromJson(contohBentukLembarKerjaTits());
      final tabel = lembar.bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      // Kalau dua ini berubah jadi peta/objek, SELURUH lembar gagal kebuka —
      // itu yang sempat kejadian waktu TITS pertama ditambahkan.
      expect(tabel.judulNilai, 'Standard Indication');
      expect(tabel.pengulangan, [1, 2, 3, 4, 5, 6]);

      expect(tabel.judulNilaiPerMode, {
        'measure': 'Standard Indication',
        'source': 'UUT Indication',
      });
      expect(tabel.pengulanganArah[1], 'UP X1');
      expect(tabel.pengulanganArah[4], 'DOWN X1');
      expect(tabel.titikBisaDiubah, isTrue);
    });

    test('judul kolom ikut mode, jatuh ke bawaan kalau mode belum dipilih', () {
      final lembar = LembarKerja.fromJson(contohBentukLembarKerjaTits());
      final tabel = lembar.bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      expect(tabel.judulNilaiUntuk(null), 'Standard Indication');
      expect(tabel.judulNilaiUntuk('measure'), 'Standard Indication');
      expect(tabel.judulNilaiUntuk('source'), 'UUT Indication');

      expect(tabel.judulPengulanganUntuk('measure'), 'Reading Unit Under Test');
      expect(tabel.judulPengulanganUntuk('source'), 'Reading Standard');

      // Mode asing nggak bikin judulnya kosong — jatuh ke bawaan.
      expect(tabel.judulNilaiUntuk('mode_ngawur'), 'Standard Indication');
    });

    test('alat lain nggak kesenggol — peta kosong, judul lama tetap dipakai', () {
      final lembar = LembarKerja.fromJson(contohBentukLembarKerjaGas());
      final tabel = lembar.bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      expect(tabel.judulNilaiPerMode, isEmpty);
      expect(tabel.pengulanganArah, isEmpty);
      expect(tabel.titikBisaDiubah, isFalse);
      expect(tabel.judulNilaiUntuk('measure'), tabel.judulNilai);
    });

    test('isi aneh di kunci baru dibuang, nggak bikin lembar gagal', () {
      final bentuk = contohBentukLembarKerjaTits();
      final bagian = (bentuk['bagian'] as List).cast<Map<String, dynamic>>();
      final hasil = bagian.firstWhere((b) => b['kode'] == 'hasil');
      final tabel = (hasil['tabel'] as List).cast<Map<String, dynamic>>().first;

      tabel['judul_nilai_per_mode'] = {'measure': 42, 'source': 'UUT Indication'};
      tabel['pengulangan_arah'] = [
        {'ke': 1, 'label': ''},
        {'label': 'tanpa nomor'},
        {'ke': 3, 'label': 'UP X3'},
        'bukan objek',
      ];

      final lembar = LembarKerja.fromJson(bentuk);
      final t = lembar.bagian.firstWhere((b) => b.kode == 'hasil').tabel.first;

      // Yang bukan teks dibuang, yang sah tetap kepakai.
      expect(t.judulNilaiPerMode, {'source': 'UUT Indication'});
      expect(t.pengulanganArah, {3: 'UP X3'});
    });
  });

  group('layar TITS', () {
    testWidgets('kerender dengan dropdown mode & tipe sensor', (tester) async {
      await buka(tester, 'tits');

      expect(
        find.textContaining('Temperature Indicator Tanpa Sensor'),
        findsWidgets,
      );
      expect(find.text('1. Mode'), findsOneWidget);
      expect(find.text('2. Temperature Type'), findsOneWidget);
    });

    testWidgets('kepala kolom bawa arah UP/DOWN, bukan Repeat', (tester) async {
      await buka(tester, 'tits');

      expect(find.text('UP X1'), findsWidgets);
      expect(find.text('DOWN X3'), findsWidgets);
      expect(find.textContaining('Repeat'), findsNothing);
    });

    testWidgets('judul kolom bertukar waktu mode diganti', (tester) async {
      await buka(tester, 'tits');

      // Mode belum dipilih: yang tampil varian measure (nilai polosnya).
      expect(find.text('Standard Indication'), findsWidgets);
      expect(find.text('UUT Indication'), findsNothing);

      await tester.tap(find.text('1. Mode').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source (UUT men-source)').last);
      await tester.pumpAndSettle();

      expect(find.text('UUT Indication'), findsWidgets);
      expect(find.text('Reading Standard'), findsWidgets);
    });

    testWidgets('pengatur titik muncul dan bisa nambah titik', (tester) async {
      await buka(tester, 'tits');

      expect(find.textContaining('Titik Ukur'), findsWidgets);
      expect(find.text('Tambah'), findsOneWidget);

      // Titik saran dari backend kegambar sebagai chip.
      expect(find.widgetWithText(InputChip, '-20'), findsOneWidget);
      expect(find.widgetWithText(InputChip, '1000'), findsOneWidget);
      expect(find.widgetWithText(InputChip, '1200'), findsNothing);

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '1200');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, '1200'), findsOneWidget);
    });

    testWidgets('titik bisa dihapus', (tester) async {
      await buka(tester, 'tits');

      expect(find.widgetWithText(InputChip, '600'), findsOneWidget);

      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, '600'),
      );
      chip.onDeleted!();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, '600'), findsNothing);
      // Yang lain nggak ikut hilang.
      expect(find.widgetWithText(InputChip, '800'), findsOneWidget);
    });

    testWidgets('alat lain nggak dapat pengatur titik', (tester) async {
      await buka(tester, 'gas_detector');

      expect(find.text('Tambah'), findsNothing);
      expect(find.byType(InputChip), findsNothing);
    });
  });
}
