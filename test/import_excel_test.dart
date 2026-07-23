import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/import_excel.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/import_provider.dart';
import 'package:sidik_calibration/screens/admin/import_excel_screen.dart';
import 'package:sidik_calibration/services/import_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app(MockImportService service) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      importServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ImportExcelScreen(),
    ),
  );
}

void main() {
  group('dua langkah wajib', () {
    testWidgets('tanpa file, uji coba nggak bisa ditekan', (tester) async {
      final service = MockImportService();
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      // Belum milih file = tombolnya mati. Nggak ada jalan pintas ke server.
      final tombol = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('UJI COBA'), matching: find.byType(InkWell))
            .first,
      );
      expect(tombol.onTap, isNull);
      expect(service.aksi, isEmpty);
    });

    testWidgets('tombol Terapkan belum ada sebelum uji coba jalan', (
      tester,
    ) async {
      await tester.pumpWidget(_app(MockImportService()));
      await tester.pumpAndSettle();

      // Ini penjagaan intinya: nulis ke master data dari file Excel orang lain
      // nggak boleh bisa dilakukan tanpa lihat ringkasannya dulu.
      expect(find.text('TERAPKAN SEKARANG'), findsNothing);
    });
  });

  group('model hasil import', () {
    test('uji coba yang nggak ngubah apa-apa nggak perlu diterapkan', () {
      final hasil = HasilImport.fromJson(const {
        'tipe': 'customers',
        'uji_coba': true,
        'ringkasan': {'dibaca': 2, 'dibuat': 0, 'diperbarui': 0, 'dilewati': 2},
        'baris': [
          {'baris': 2, 'tindakan': 'dilewati', 'alasan': 'Nama PT kosong.'},
        ],
      });

      expect(hasil.adaPerubahan, isFalse);
      expect(hasil.dilewati, 2);
      expect(hasil.baris.first.alasan, 'Nama PT kosong.');
    });

    test('kolom yang nggak dikenal diabaikan, bukan bikin gagal', () {
      final hasil = HasilImport.fromJson(const {
        'tipe': 'customers',
        'uji_coba': true,
        'kolom_terpetakan': {'nama': 'Nama PT'},
        'kolom_diabaikan': ['Catatan Internal', 'PIC'],
        'ringkasan': {'dibaca': 1, 'dibuat': 1},
        'baris': [],
      });

      // Ditampilin ke admin biar dia sadar kolomnya nggak kebaca — bukan
      // hilang diam-diam.
      expect(hasil.kolomDiabaikan, ['Catatan Internal', 'PIC']);
      expect(hasil.adaPerubahan, isTrue);
    });

    test('tindakan asing dianggap dilewati — nggak ngaku nulis', () {
      final b = BarisImport.fromJson(const {
        'baris': 5,
        'tindakan': 'sesuatu_yang_baru',
      });

      expect(b.tindakan, TindakanImport.dilewati);
    });
  });

  group('service', () {
    test('uji_coba dikirim eksplisit, nggak gantung ke default server', () async {
      final service = MockImportService();

      await service.unggah(
        't',
        filePath: '/tmp/a.xlsx',
        tipe: 'customers',
        ujiCoba: true,
      );
      await service.unggah(
        't',
        filePath: '/tmp/a.xlsx',
        tipe: 'customers',
        ujiCoba: false,
      );

      expect(service.aksi, [('customers', true), ('customers', false)]);
    });
  });
}
