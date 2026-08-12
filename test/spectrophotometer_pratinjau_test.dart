import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/pratinjau_hitung.dart';
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


/// Pratinjau hitung (`POST /api/calibrations/preview`) buat Spectrophotometer.
///
/// Angka acuan di file ini BUKAN karangan: diambil dari sesi `DEMO-SPECTRO-LDC`
/// (PT LDC Indonesia, Perkin Elmer Lambda 25 s/n `501S13102801`, 21 Juli 2023)
/// lewat backend lokal, dan cocok sama tabel acuan handoff:
///
/// | Kelompok   | U95        | k          |
/// | ---------- | ---------- | ---------- |
/// | Holmium    | 0,43255708 | 3,18244631 |
/// | Didynium   | 0,4        | 2,36462425 |
/// | Akurasi %T | 0,5        | 2,00855911 |
///
/// Didynium & %T kena lantai CMC, makanya U-nya bulat — itu bener, bukan
/// placeholder. **Nol rumus di sisi mobile**: hasilnya dititipin ke mock apa
/// adanya, jadi kalau angkanya salah, yang salah pemetaan datanya.
void main() {
  group('pratinjau hitung', () {
    test('respons preview asli kebaca utuh', () {
      final hasil = PratinjauHitung.fromJson(_previewDemo);

      expect(hasil.titik, hasLength(3));
      expect(hasil.belumDihitung, hasLength(1));

      final holmium = hasil.titik.first;

      // Diadu ke tabel acuan handoff, bukan ke hasil hitung sendiri — sisi
      // mobile emang nggak ngitung apa-apa.
      expect(holmium.ketidakpastianDiperluas, 0.43255708);
      expect(holmium.faktorCakupanK, 3.18244631);
      expect(holmium.rataRata, 280.0);
      expect(holmium.koreksi, -0.4);
      expect(holmium.desimal, 2);
      expect(holmium.satuan, 'nm');
      expect(holmium.remark, 'Wave Length ( λ ) - Filter Holmium');

      // Alat ini nggak punya batas keberterimaan sama sekali.
      expect(holmium.keputusan, isNull);
      expect(hasil.titik.every((t) => t.keputusan == null), isTrue);
    });

    test('sepuluh titik sekelompok BOLEH punya U95 yang sama persis', () {
      final hasil = PratinjauHitung.fromJson(_previewDemo);
      final didynium = hasil.titik[1];
      final transmitan = hasil.titik[2];

      // Bukan data kembar: U95 alat ini lahir per KELOMPOK, dari STDEV
      // terbesar seluruh titik kelompoknya. Angka bulat 0,4 & 0,5 itu lantai
      // CMC, bukan placeholder.
      expect(didynium.ketidakpastianDiperluas, 0.4);
      expect(didynium.faktorCakupanK, 2.36462425);
      expect(transmitan.ketidakpastianDiperluas, 0.5);
      expect(transmitan.faktorCakupanK, 2.00855911);
    });

    testWidgets('isian diketik → preview kepanggil, hasilnya kegambar', (
      tester,
    ) async {
      final service = MockLembarKerjaService()
        ..balasanPratinjau = PratinjauHitung.fromJson(_previewDemo);

      await _bukaLembar(tester, service: service);
      await _pilihAlat(tester);

      // Satu baris Holmium: tiga kotak pertama di tabel pertama. Dicari lewat
      // tabelnya, bukan lewat urutan `TextField` di layar — kolom formulir di
      // atas tabel jumlahnya beda-beda per role & per alat.
      final kotak = find.descendant(
        of: find.byType(LembarKerjaTabel).first,
        matching: find.byType(TextField),
      );

      for (var i = 0; i < 3; i++) {
        await tester.enterText(kotak.at(i), '280');
      }
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(service.payloadPratinjau, isNotEmpty);

      final body = service.payloadPratinjau.last;
      final measurements = (body['measurements'] as List)
          .cast<Map<String, dynamic>>();

      // Bodinya identik sama `POST /calibrations` — satuan & standar ikut PER
      // BARIS, bukan satu satuan buat seluruh lembar.
      expect(body['equipment_id'], isNotNull);
      expect(
        measurements.firstWhere((m) => m['titik_ukur'] == 279.6)['satuan'],
        'nm',
      );
      expect(
        measurements.firstWhere((m) => m['titik_ukur'] == 9.9)['satuan'],
        '%T',
      );
      expect(
        measurements.firstWhere((m) => m['titik_ukur'] == 9.9)['pembacaan'],
        hasLength(6),
      );

      // Panelnya nampilin angka backend + judul kelompok dari `remark`.
      expect(find.text('HASIL HITUNG SEMENTARA'), findsOneWidget);
      // Dua kali: judul tabel isiannya, dan kepala kelompok di panel hasil.
      expect(
        find.text('Wave Length ( λ ) - Filter Holmium'),
        findsNWidgets(2),
      );
      expect(find.text('280,00'), findsWidgets);
      expect(find.text('-0,40'), findsWidgets);
      expect(find.text('0,43'), findsWidgets);

      // %T dicetak 3 desimal, nol belakangnya DIPERTAHANKAN.
      expect(find.text('9,665'), findsWidgets);

      // Titik yang belum bisa dihitung wajib kelihatan — tiap titik kosong
      // ngurangin dasar hitung kelompoknya.
      expect(find.text('BELUM BISA DIHITUNG'), findsOneWidget);
      expect(
        find.textContaining('Baru 1 pembacaan terisi'),
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


Future<void> _pilihAlat(WidgetTester tester) async {
  await tester.tap(find.text('Pilih alat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
  await tester.pumpAndSettle();
}


/// Potongan respons ASLI `POST /api/calibrations/preview` buat sesi
/// `DEMO-SPECTRO-LDC` — satu titik per kelompok, plus satu titik yang backend
/// tolak hitung. Angkanya nggak diubah sama sekali.
const _previewDemo = <String, dynamic>{
  'data': {
    'titik': [
      {
        'titik_ke': 1,
        'titik_ukur': 279.6,
        'standard_id': 25,
        'desimal': 2,
        'satuan': 'nm',
        'tanda_nol': true,
        'remark': 'Wave Length ( λ ) - Filter Holmium',
        'rata_rata': 280,
        'error': 0.4,
        'koreksi': -0.4,
        'standar_deviasi': 0,
        'jumlah_pengulangan': 3,
        'type_a': 0.11844666,
        'type_b': 0.06666744,
        'ketidakpastian_gabungan': 0.13591968,
        'faktor_cakupan_k': 3.18244631,
        'ketidakpastian_diperluas': 0.43255708,
        'toleransi': null,
        'keputusan': null,
      },
      {
        'titik_ke': 11,
        'titik_ukur': 513.7,
        'standard_id': 26,
        'desimal': 2,
        'satuan': 'nm',
        'tanda_nol': true,
        'remark': 'Wave Length ( λ ) - Filter Didynium',
        'rata_rata': 514.2,
        'error': 0.5,
        'koreksi': -0.5,
        'standar_deviasi': 0.15011107,
        'jumlah_pengulangan': 3,
        'type_a': 0.11405,
        'type_b': 0.10974,
        'ketidakpastian_gabungan': 0.1582851,
        'faktor_cakupan_k': 2.36462425,
        'ketidakpastian_diperluas': 0.4,
        'toleransi': null,
        'keputusan': null,
      },
      {
        'titik_ke': 22,
        'titik_ukur': 9.9,
        'standard_id': 27,
        'desimal': 3,
        'satuan': '%T',
        'tanda_nol': true,
        'remark': 'Accuracy %T and Linierity at λ = 560nm',
        'rata_rata': 9.665,
        'error': -0.235,
        'koreksi': 0.235,
        'standar_deviasi': 0.00409878,
        'jumlah_pengulangan': 6,
        'type_a': 0.00167332,
        'type_b': 0.02886,
        'ketidakpastian_gabungan': 0.02891741,
        'faktor_cakupan_k': 2.00855911,
        'ketidakpastian_diperluas': 0.5,
        'toleransi': null,
        'keputusan': null,
      },
    ],
    'belum_dihitung': [
      {
        'titik_ke': 2,
        'alasan':
            'Baru 1 pembacaan terisi, minimal 2 — standar deviasi nggak bisa '
            'dihitung dari satu angka.',
      },
    ],
  },
};