import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/perusahaan_direktori.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/equipment/pelanggan_baru_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Atribusi direktori luar — **kewajiban lisensi, bukan hiasan.**
///
/// Sumber bawaannya OpenStreetMap, dan ODbL mewajibkan sumbernya disebut di
/// tempat hasilnya dipajang. Server sudah mengirimnya sejak awal di badan
/// respons (`CustomerController::direktori()`), lengkap dengan alasan tertulis
/// kenapa kalimatnya datang dari SANA dan bukan dikarang di HP.
///
/// Sisi HP tetap membuangnya: [PerusahaanDirektori.fromJson] cuma membaca
/// `ref`/`nama`/`alamat`, dan servicenya cuma membaca `json['data']`. Nol
/// error, nol log — yang hilang cuma kalimat yang justru diwajibkan. Itu
/// bentuk kegagalan yang nggak bisa ketahuan dari layar maupun dari test yang
/// cuma mengadu nama perusahaan.
///
/// Yang dijaga berkas ini tiga hal, dan yang KETIGA yang paling gampang
/// rusak diam-diam di kemudian hari.
const _baseUrl = 'http://uji/api';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

ApiCustomerLookupService _service(Object badan) => ApiCustomerLookupService(
  ApiClient(client: MockClient((_) async => _json(badan)), baseUrl: _baseUrl),
);

/// Service yang memulangkan atribusi apa pun yang disuruh — termasuk `null`.
class _DirektoriBeratribusi extends MockCustomerLookupService {
  _DirektoriBeratribusi(this.kalimat);

  final String? kalimat;

  @override
  Future<HasilDirektori> cariDirektori(
    String token, {
    required String search,
  }) async {
    final hasil = await super.cariDirektori(token, search: search);
    return (daftar: hasil.daftar, atribusi: kalimat);
  }
}

void main() {
  group('atribusi dibaca dari respons server', () {
    test('kalimatnya sampai, bukan dibuang bareng amplopnya', () async {
      final hasil = await _service({
        'data': [
          {'ref': 'x', 'nama': 'PT Sinar Rejeki', 'alamat': 'Cikarang'},
        ],
        'atribusi': '© OpenStreetMap contributors',
      }).cariDirektori('token', search: 'Sinar');

      expect(hasil.daftar, hasLength(1));
      expect(
        hasil.atribusi,
        '© OpenStreetMap contributors',
        reason: 'Atribusinya dibuang waktu amplopnya dibongkar — dan '
            'membuangnya nggak bikin satu pun error muncul.',
      );
    });

    /// Penyedia yang nggak mensyaratkan apa-apa memulangkan `null`, dan itu
    /// bukan kerusakan — layarnya cuma nggak memajang barisnya.
    test('atribusi null bukan kerusakan', () async {
      final hasil = await _service({
        'data': <Object>[],
        'atribusi': null,
      }).cariDirektori('token', search: 'Sinar');

      expect(hasil.daftar, isEmpty);
      expect(hasil.atribusi, isNull);
    });
  });

  group('atribusi sampai ke layar', () {
    /// Layarnya `ListView` dan barisnya jatuh di bawah lipatan begitu hasil
    /// direktorinya nambah.
    void layarPanjang(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 5200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> buka(
      WidgetTester tester,
      CustomerLookupService service,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              InMemoryTokenStorage('mock-token'),
            ),
            customerLookupServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('id'),
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<CustomerLookup>(
                  MaterialPageRoute(
                    builder: (_) => const PelangganBaruScreen(
                      kataKunci: 'Sinar',
                    ),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CARI DI DIREKTORI'));
      await tester.pumpAndSettle();
    }

    testWidgets('kalimat atribusinya kelihatan di bawah hasilnya', (
      tester,
    ) async {
      layarPanjang(tester);
      await buka(tester, _DirektoriBeratribusi('© OpenStreetMap contributors'));

      expect(find.text('PT Sinar Rejeki Manufaktur'), findsOneWidget);
      expect(
        find.text('© OpenStreetMap contributors'),
        findsOneWidget,
        reason: 'ODbL mewajibkan sumbernya disebut di tempat hasilnya '
            'dipajang. Hilangnya nggak ninggalin error.',
      );
    });

    /// **Ini yang paling mahal kalau rusak nanti.**
    ///
    /// Godaan berikutnya adalah menulis "© OpenStreetMap contributors" sebagai
    /// string tetap di sisi HP — kelihatannya sama di layar, dan semua test di
    /// atas tetap hijau. Tapi penyedianya bisa ditukar lewat SATU setelan di
    /// server (`DIREKTORI_PERUSAHAAN_DRIVER=google`), dan sejak detik itu lab
    /// memajang atribusi penyedia yang salah — pelanggaran lisensi yang nggak
    /// ninggalin satu pun error.
    ///
    /// Makanya yang diadu di sini kalimat penyedia LAIN.
    testWidgets('kalimatnya ikut penyedianya, bukan ditulis mati di HP', (
      tester,
    ) async {
      layarPanjang(tester);
      await buka(tester, _DirektoriBeratribusi('Powered by Google'));

      expect(find.text('Powered by Google'), findsOneWidget);
      expect(
        find.text('© OpenStreetMap contributors'),
        findsNothing,
        reason: 'Atribusinya ditulis mati di sisi HP: menukar penyedia di '
            'server bikin lab memajang atribusi yang salah.',
      );
    });

    testWidgets('atribusi null nggak nyisain baris kosong', (tester) async {
      layarPanjang(tester);
      await buka(tester, _DirektoriBeratribusi(null));

      expect(find.text('PT Sinar Rejeki Manufaktur'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsNothing);
    });
  });
}
