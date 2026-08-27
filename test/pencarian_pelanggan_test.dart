import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show categoryServiceProvider;
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/equipment/equipment_form_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Pemilih pelanggan di form Tambah Alat — *"nama pt nya gede terus bawah nya
/// alamat nya kecil terus tinggal di pencet aja"*.
///
/// Yang dijaga di sini bukan cuma tampilannya. Daftar ini dulu ditarik dari
/// `GET /api/arsip/perusahaan`, yang ngelist **FOLDER**, bukan pelanggan — dan
/// `id` folder yang kekirim balik sebagai `pelanggan_id` bikin alat kedaftar ke
/// PT LAIN tanpa satu pun error muncul.
const _baseUrl = 'http://uji/api';

class _EquipmentServiceKosong implements EquipmentService {
  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) async => const EquipmentPage(items: [], currentPage: 1, lastPage: 1);

  @override
  Future<Equipment> simpan(String token, Equipment data) async => data;

  @override
  Future<Equipment> ubah(String token, Equipment data) async => data;

  @override
  Future<void> hapus(String token, int id) async {}
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('jalur HTTP-nya nunjuk ke endpoint pelanggan, bukan endpoint folder', () {
    test('/customers/lookup yang dipanggil, bukan /arsip/perusahaan', () async {
      final diminta = <String>[];
      final service = ApiCustomerLookupService(
        ApiClient(
          client: MockClient((req) async {
            diminta.add(req.url.path + (req.url.query.isEmpty ? '' : '?${req.url.query}'));
            return _json({'data': []});
          }),
          baseUrl: _baseUrl,
        ),
      );

      await service.cari('token');
      await service.cari('token', search: 'Maju');

      expect(diminta, [
        '/api/customers/lookup',
        '/api/customers/lookup?search=Maju',
      ]);
      // `/arsip/perusahaan` mulangin id FOLDER. Dipakai di sini, `pelanggan_id`
      // yang kesimpen nunjuk PT lain — sah menurut validasi, salah menurut
      // kenyataan.
      expect(
        diminta.where((p) => p.contains('arsip')),
        isEmpty,
        reason: 'daftar pelanggan nggak boleh datang dari daftar folder',
      );
    });

    test('alamat kebaca, dan yang nggak ada nggak bikin baris hilang', () async {
      final service = ApiCustomerLookupService(
        ApiClient(
          client: MockClient(
            (req) async => _json({
              'data': [
                {'id': 7, 'nama': 'PT Alfa', 'alamat': 'Jl. Cikarang KM 27'},
                // Alamat boleh kosong di master — barisnya tetap harus utuh,
                // bukan dibuang `parseListAman` gara-gara null.
                {'id': 9, 'nama': 'PT Beta', 'alamat': null},
                {'id': 11, 'nama': 'PT Gamma'},
              ],
            }),
          ),
          baseUrl: _baseUrl,
        ),
      );

      final hasil = await service.cari('token');

      expect(hasil.map((c) => c.id), [7, 9, 11]);
      expect(hasil[0].alamat, 'Jl. Cikarang KM 27');
      expect(hasil[1].alamat, isNull);
      expect(hasil[2].alamat, isNull);
    });

    test('`id` dibaca apa adanya dari server, bukan dari urutan baris', () {
      // Kalau suatu saat ada yang tergoda memakai indeks daftar sebagai id,
      // inilah yang harus merah duluan.
      final c = CustomerLookup.fromJson({
        'id': 42,
        'nama': 'PT Gamma',
        'alamat': 'Jl. Industri No. 88',
      });

      expect(c.id, 42);
    });
  });

  group('layarnya: nama gede, alamat kecil di bawahnya', () {
    Widget app() => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        equipmentServiceProvider.overrideWithValue(_EquipmentServiceKosong()),
        categoryServiceProvider.overrideWithValue(MockCategoryService()),
        customerLookupServiceProvider.overrideWithValue(
          MockCustomerLookupService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EquipmentFormScreen(),
      ),
    );

    Future<void> bukaPemilih(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih pelanggan'));
      await tester.pumpAndSettle();
    }

    testWidgets('alamat nongol di bawah namanya, dan hurufnya lebih kecil', (
      tester,
    ) async {
      await bukaPemilih(tester);

      expect(find.text('PT Maju Jaya'), findsOneWidget);
      final alamat = find.text('Jl. Raya Bekasi KM 27, Cikarang, Bekasi');
      expect(alamat, findsOneWidget);

      final ukuranNama = tester
          .widget<Text>(find.text('PT Maju Jaya'))
          .style!
          .fontSize!;
      final ukuranAlamat = tester.widget<Text>(alamat).style!.fontSize!;

      expect(
        ukuranAlamat,
        lessThan(ukuranNama),
        reason: 'nama PT-nya yang gede, alamatnya yang kecil',
      );
    });

    testWidgets('pelanggan tanpa alamat nggak nyisain baris kosong', (
      tester,
    ) async {
      await bukaPemilih(tester);

      final tanpaAlamat = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('PT Industri Presisi'),
          matching: find.byType(ListTile),
        ),
      );

      expect(tanpaAlamat.subtitle, isNull);
    });

    testWidgets('tinggal dipencet — pilihannya masuk ke kolom pelanggan', (
      tester,
    ) async {
      await bukaPemilih(tester);

      await tester.tap(find.text('CV Sentosa Abadi'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih pelanggan'), findsNothing);
      expect(find.text('CV Sentosa Abadi'), findsOneWidget);
    });

    testWidgets('dicari lewat ALAMAT juga ketemu', (tester) async {
      // Begini cara teknisi mengingat pelanggannya: satu kawasan industri
      // isinya belasan PT bernama mirip, dan yang dia pegang alamat
      // penjemputannya.
      await bukaPemilih(tester);

      await tester.enterText(find.byType(TextField).last, 'Industri Selatan');
      // Ketikannya di-debounce 350ms sebelum dikirim.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('CV Sentosa Abadi'), findsOneWidget);
      expect(find.text('PT Maju Jaya'), findsNothing);
    });
  });
}
