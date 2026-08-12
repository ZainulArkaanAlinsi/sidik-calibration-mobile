import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';


/// Bentuk lembar kerja Spectrophotometer (alat ke-6, `SIDIK-IK-CAL-0508_Rev.4`)
/// — tiga tabel dalam satu bagian, satuan campur, dan satu bagian yang tampil
/// tapi belum boleh diisi.
///
/// Bentuk mock-nya disalin dari respons ASLI
/// `GET /api/calibrations/lembar-kerja?equipment_id=12` di DB lab, bukan
/// dikarang: titiknya persis yang tercetak di master
/// `Master Olah Data_Spectrofotometer.xlsm`.
void main() {
  group('bentuk lembar kerja', () {
    test('`satuan_campuran` berbentuk DAFTAR tetap kebaca campur', () {
      // Regresi yang paling mahal di alat ini. Conductivity ngirim
      // `satuan_campuran: true`, Spectrophotometer ngirim `["nm", "%T"]` —
      // kunci yang sama, tipe yang beda. Waktu parsernya masih `as bool?`,
      // daftar itu ngelempar TypeError, dan `LembarKerja.fromJson` ada di LUAR
      // jangkauan `parseListAman`: yang gagal bukan satu kolom, tapi seluruh
      // lembar. Layar kalibrasinya kosong sebelum satu baris pun digambar.
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());

      expect(bentuk.satuanCampuran, isTrue);

      final tabel = bentuk.bagianHasil!.tabel;
      final holmium = tabel[0].baris.first;
      final transmitan = tabel[2].baris.first;

      // Satuan diambil PER BARIS, bukan dari `satuan` level lembar yang keisi
      // 'nm' — kalau ketuker, kolom %T kelabel nm.
      expect(bentuk.satuanUntuk(holmium), 'nm');
      expect(bentuk.satuanUntuk(transmitan), '%T');
    });

    test('`satuan_campuran: true` (Conductivity) nggak ikut kebawa rusak', () {
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'X',
        'satuan': '',
        'satuan_campuran': true,
        'bagian': <dynamic>[],
      });

      expect(bentuk.satuanCampuran, isTrue);
    });

    test('daftar KOSONG artinya nggak campur, bukan campur tanpa satuan', () {
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'X',
        'satuan': 'nm',
        'satuan_campuran': <dynamic>[],
        'bagian': <dynamic>[],
      });

      expect(bentuk.satuanCampuran, isFalse);
    });

    test('tiga tabel, dan kolom pengulangannya dibaca PER TABEL', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final tabel = bentuk.bagianHasil!.tabel;

      expect(tabel, hasLength(3));
      expect([for (final t in tabel) t.baris.length], [10, 9, 5]);

      // Ini yang nggak boleh diambil dari level lembar: `jumlah_pengulangan`
      // di situ 3, sementara blok %T butuh ENAM kolom (master nyetak dua baris
      // X1..X3 per nilai standar, dan `PERHITUNGAN` merata-rata keenamnya).
      expect(bentuk.jumlahPengulangan, 3);
      expect([for (final t in tabel) t.pengulangan.length], [3, 3, 6]);
    });

    test('tiap baris bawa standar & desimalnya sendiri', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final tabel = bentuk.bagianHasil!.tabel;

      // Standar nempel di baris — teknisi NGGAK milih filter per titik.
      // Rentang Holmium (283–641 nm) & Didynium (474–810 nm) tumpang tindih
      // 167 nm, jadi salah pilih nggak kelihatan dari dokumen hasilnya.
      expect(tabel[0].baris.every((b) => b.standardId == 25), isTrue);
      expect(tabel[1].baris.every((b) => b.standardId == 26), isTrue);
      expect(tabel[2].baris.every((b) => b.standardId == 27), isTrue);

      // Desimal beda per kelompok: 2 buat nm, 3 buat %T.
      expect(tabel[0].baris.first.desimal, 2);
      expect(tabel[2].baris.first.desimal, 3);
      expect(tabel[2].baris.first.label, '0.000');
    });

    test('bagian SRE kebaca berstatus & nggak nerima input', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final sre = bentuk.bagian.firstWhere((b) => b.kode == 'sre');

      expect(sre.belumBisaDiisi, isTrue);
      expect(sre.field, isEmpty);
      expect(sre.catatan, contains('#REF!'));
    });
  });

  group('layar teknisi', () {
    testWidgets('blok %T dapat ENAM kotak per baris, bukan tiga', (
      tester,
    ) async {
      await _bukaLembar(tester);

      // Tiga tabel di satu bagian: 10 baris × 3 + 9 × 3 + 5 × 6 = 87 kotak.
      // Waktu kolomnya diambil dari `jumlah_pengulangan` level lembar, yang
      // kegambar 72 — tiga kolom terakhir %T ilang dan teknisi nggak punya
      // tempat ngetik separuh datanya.
      expect(
        find.descendant(
          of: find.byType(LembarKerjaTabel),
          matching: find.byType(TextField),
        ),
        findsNWidgets(87),
      );
    });

    testWidgets('blok SRE tampil berlabel, tanpa satu pun kotak isian', (
      tester,
    ) async {
      await _bukaLembar(tester);

      expect(find.text('SRE (STRAY RADIANT ENERGY)'), findsOneWidget);
      expect(find.text('BELUM BISA DIISI'), findsOneWidget);
      // Alasannya ditampilin apa adanya — teknisi nyariin blok ini karena
      // tercetak di lembar kertas yang dia pegang.
      expect(
        find.textContaining('Backend nggak nyetak angka SRE'),
        findsOneWidget,
      );
    });
  });
}

Widget _app(MockLembarKerjaService service) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
    authServiceProvider.overrideWithValue(MockAuthService()),
    lembarKerjaServiceProvider.overrideWithValue(service),
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
    home: const LembarKerjaScreen(profil: 'spectrophotometer'),
  ),
);


Future<MockLembarKerjaService> _bukaLembar(
  WidgetTester tester, {
  MockLembarKerjaService? service,
}) async {
  // Lembarnya 24 baris × sampai 6 kolom — jauh lebih tinggi dari viewport test
  // standar, dan `ListView` cuma nge-build yang deket layar.
  // Sengaja di BAWAH ambang dua kolom (1100): lembar dua kolom nyusun ulang
  // urutan widget-nya, dan yang diuji di sini isi tabelnya, bukan tata
  // letaknya.
  tester.view.physicalSize = const Size(900, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final dipakai = service ?? MockLembarKerjaService();
  await tester.pumpWidget(_app(dipakai));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();

  return dipakai;
}

