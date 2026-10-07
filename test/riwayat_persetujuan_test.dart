import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/peristiwa_persetujuan.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/providers/riwayat_persetujuan_provider.dart';
import 'package:sidik_calibration/screens/history/widgets/riwayat_persetujuan_card.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/riwayat_persetujuan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Riwayat persetujuan sesi (khusus admin & super admin, keputusan pemilik
/// proyek 6 Okt 2026): tiap penolakan tampil dengan alasannya sendiri, walau
/// kolom `catatan_revisi` sesi cuma menyimpan yang terakhir.
void main() {
  test('JSON server terbaca: alasan, kolom, pelaku, waktu', () {
    final p = PeristiwaPersetujuan.fromJson({
      'jenis': 'ditolak',
      'status': 'perlu_revisi',
      'status_sebelumnya': 'menunggu_approval',
      'waktu': '2026-10-06T08:12:00+00:00',
      'oleh': {'id': 3, 'nama': 'Admin Pemeriksa'},
      'alasan': 'Titik 3 meleset',
      'kolom': ['alat_merk', 'sel:sesudah_adjustment:7:pembacaan:1'],
    });

    expect(p.ditolak, isTrue);
    expect(p.olehNama, 'Admin Pemeriksa');
    expect(p.alasan, 'Titik 3 meleset');
    expect(p.kolom, ['alat_merk', 'sel:sesudah_adjustment:7:pembacaan:1']);
    expect(p.waktu!.toUtc(), DateTime.utc(2026, 10, 6, 8, 12));

    final sistem = PeristiwaPersetujuan.fromJson({'jenis': 'disetujui', 'status': 'disetujui', 'oleh': null});
    expect(sistem.olehNama, isNull);
    expect(sistem.kolom, isEmpty);
  });

  test('hanya admin & super admin yang boleh melihat', () {
    expect(RiwayatPersetujuanBagian.bolehLihat(UserRole.admin), isTrue);
    expect(RiwayatPersetujuanBagian.bolehLihat(UserRole.superAdmin), isTrue);
    expect(RiwayatPersetujuanBagian.bolehLihat(UserRole.teknisi), isFalse);
    expect(RiwayatPersetujuanBagian.bolehLihat(UserRole.viewer), isFalse);
    expect(RiwayatPersetujuanBagian.bolehLihat(null), isFalse);
  });

  testWidgets('dua penolakan tampil dengan alasan masing-masing', (tester) async {
    final daftar = [
      PeristiwaPersetujuan(
        jenis: 'ditolak',
        status: 'perlu_revisi',
        waktu: DateTime(2026, 10, 6, 9),
        olehNama: 'Admin Pemeriksa',
        alasan: 'ALASAN PERTAMA',
        kolom: const ['alat_merk'],
      ),
      PeristiwaPersetujuan(
        jenis: 'diajukan_ulang',
        status: 'menunggu_approval',
        waktu: DateTime(2026, 10, 6, 10),
        olehNama: 'Teknisi Lapangan',
      ),
      PeristiwaPersetujuan(
        jenis: 'ditolak',
        status: 'perlu_revisi',
        waktu: DateTime(2026, 10, 6, 11),
        olehNama: 'Admin Pemeriksa',
        alasan: 'ALASAN KEDUA',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: RiwayatPersetujuanCard(daftar: daftar))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ditolak 2 kali'), findsOneWidget);
    expect(find.text('ALASAN PERTAMA'), findsOneWidget);
    expect(find.text('ALASAN KEDUA'), findsOneWidget);
    expect(find.text('Kolom/sel ditandai: alat_merk'), findsOneWidget);
    expect(find.text('Diajukan ulang sesudah revisi'), findsOneWidget);
  });

  Future<_HitungPanggilan> pasang(WidgetTester tester, String token) async {
    final servis = _HitungPanggilan();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        authServiceProvider.overrideWithValue(MockAuthService()),
        riwayatPersetujuanServiceProvider.overrideWithValue(servis),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Sesi login hidup lebih dulu, seperti di aplikasi sungguhan.
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(authProvider);
              return const SingleChildScrollView(child: RiwayatPersetujuanBagian(sesiId: 7));
            },
          ),
        ),
      ),
    ));
    // MockAuthService memakai jeda buatan — sama dengan test layar lain.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    return servis;
  }

  testWidgets('admin: kartu tampil, riwayat baru dimuat waktu dibuka', (tester) async {
    final servis = await pasang(tester, 'mock-token-1');

    expect(find.byKey(const ValueKey('riwayat-persetujuan')), findsOneWidget);
    expect(servis.panggilan, 0, reason: 'membuka detail sesi tidak boleh langsung memanggil server');

    await tester.tap(find.text('Riwayat persetujuan'));
    await tester.pumpAndSettle();

    expect(servis.panggilan, 1);
    expect(find.text('ALASAN UJI'), findsOneWidget);
  });

  testWidgets('teknisi: kartu tidak digambar, server tidak dipanggil', (tester) async {
    final servis = await pasang(tester, 'mock-token-2');

    expect(find.byKey(const ValueKey('riwayat-persetujuan')), findsNothing);
    expect(servis.panggilan, 0);
  });

  // Tinjauan 6 Okt 2026: admin yang baru menolak lalu membuka riwayat lagi
  // tidak boleh melihat daftar basi tanpa penolakan terbarunya. Dua jalur
  // tolak di aplikasi: daftar riwayat (`HistoryController`) dan layar
  // perhitungan (`AksiAdmin`).
  test('tolak dari aplikasi (dua jalur) mengambil ulang riwayat sesinya', () async {
    final servis = _HitungPanggilan();
    final container = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(MockHistoryService()),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
      perhitunganServiceProvider.overrideWithValue(MockPerhitunganService()),
      riwayatPersetujuanServiceProvider.overrideWithValue(servis),
    ]);
    addTearDown(container.dispose);

    // Bagian riwayat yang sedang terbuka di layar.
    container.listen(riwayatPersetujuanProvider(7), (_, _) {});
    await container.read(riwayatPersetujuanProvider(7).future);
    expect(servis.panggilan, 1);

    await container.read(historyProvider.notifier).reject(7, 'Alasan dari daftar riwayat');
    await container.read(riwayatPersetujuanProvider(7).future);
    expect(servis.panggilan, 2, reason: 'HistoryController.reject wajib meng-invalidate riwayat');

    await container.read(aksiAdminProvider(7)).tolak('Alasan dari layar perhitungan');
    await container.read(riwayatPersetujuanProvider(7).future);
    expect(servis.panggilan, 3, reason: 'AksiAdmin.tolak wajib meng-invalidate riwayat');
  });

  testWidgets('belum pernah ditolak: ringkasan nol dan pesan kosong', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: RiwayatPersetujuanCard(daftar: [])),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ditolak 0 kali'), findsOneWidget);
    expect(find.text('Belum ada riwayat persetujuan.'), findsOneWidget);
  });
}

/// Penghitung panggilan server — membuktikan riwayat dimuat saat dibuka saja.
class _HitungPanggilan implements RiwayatPersetujuanService {
  int panggilan = 0;

  @override
  Future<List<PeristiwaPersetujuan>> ambil(String token, int sesiId) async {
    panggilan++;
    return const [
      PeristiwaPersetujuan(jenis: 'ditolak', status: 'perlu_revisi', alasan: 'ALASAN UJI'),
    ];
  }
}
