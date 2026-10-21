import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/screens/jatuh_tempo/layar_jatuh_tempo.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/ubah_jatuh_tempo_service.dart';

Equipment _alat() => Equipment(
  id: 5,
  namaAlat: 'Timbangan X',
  serialNumber: 'SN-5',
  kategori: 'massa',
  status: EquipmentStatus.overdue,
  pelangganId: 1,
  pelangganNama: 'PT Tirta',
  tanggalJatuhTempo: DateTime(2026, 9, 1),
);

Future<void> _buka(
  WidgetTester tester,
  MockUbahJatuhTempoService ubah, {
  required Izin izin,
  String token = 'mock-token-1',
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final overrides = <Override>[
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    jamProvider.overrideWithValue(() => DateTime(2026, 9, 26)),
    equipmentServiceProvider.overrideWithValue(
      MockEquipmentService(awal: [_alat()]),
    ),
    izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
    ubahJatuhTempoServiceProvider.overrideWithValue(ubah),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const JadwalKalibrasiScreen(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('admin: dialog menjelaskan revisi vs jadwal, alasan wajib, '
      'kirim tanggal Y-m-d + alasan', (tester) async {
    final ubah = MockUbahJatuhTempoService(revisi: true);
    await _buka(
      tester,
      ubah,
      izin: Izin(role: UserRole.admin, boleh: {NamaIzin.alatUbahJatuhTempo}),
    );

    await tester.tap(find.text('Ubah jatuh tempo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dibuat REVISI'), findsOneWidget);
    expect(
      find.textContaining('hanya jadwal alat yang berubah'),
      findsOneWidget,
    );

    // Tanpa tanggal & alasan: ditolak di klien, tidak ada panggilan.
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal dulu.'), findsOneWidget);
    expect(find.text('Alasan minimal 5 huruf.'), findsOneWidget);
    expect(ubah.panggilan, isEmpty);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextButton),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Koreksi tanggal');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(ubah.panggilan, hasLength(1));
    expect(ubah.panggilan.single.id, 5);
    expect(ubah.panggilan.single.alasan, 'Koreksi tanggal');
    expect(
      ubah.panggilan.single.tanggal,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
    // Jalur revisi_sertifikat (202) diberitahukan lengkap dengan nomornya.
    expect(find.textContaining('012-CAL-524-R1'), findsOneWidget);
  });

  testWidgets('tanpa izin: tombol Ubah jatuh tempo tidak tampil', (
    tester,
  ) async {
    await _buka(
      tester,
      MockUbahJatuhTempoService(),
      izin: Izin(role: UserRole.viewer, boleh: const {}),
      token: 'mock-token-3',
    );
    expect(find.text('Timbangan X'), findsOneWidget);
    expect(find.text('Ubah jatuh tempo'), findsNothing);
  });

  test('jalur dibaca dari body, bukan dari kode HTTP', () {
    final r = HasilUbahJatuhTempo.fromJson({
      'jalur': 'revisi_sertifikat',
      'sertifikat': {'id': 1, 'nomor': 'X-R2'},
    });
    expect(r.revisiSertifikat, isTrue);
    expect(r.nomorRevisi, 'X-R2');
    expect(
      HasilUbahJatuhTempo.fromJson({'jalur': 'jadwal_alat'}).revisiSertifikat,
      isFalse,
    );
    expect(formatTanggalApi(DateTime(2026, 3, 5)), '2026-03-05');
  });
}
