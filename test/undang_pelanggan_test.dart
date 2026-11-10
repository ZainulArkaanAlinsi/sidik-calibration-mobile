import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/undangan_pelanggan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/screens/settings/customer_list_screen.dart';
import 'package:sidik_calibration/screens/settings/undang_anggota_dialog.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/customer_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/undangan_pelanggan_service.dart';

import 'support/lewati_onboarding.dart';

/// Token mock: 1 = admin, 2 = teknisi, 3 = viewer, 5 = super admin.
Widget _layarDaftar({
  String token = 'mock-token-1',
  required UndanganPelangganService undangan,
  ThemeData? tema,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(
        MockAuthService(jeda: Duration.zero),
      ),
      customerServiceProvider.overrideWithValue(MockCustomerService()),
      undanganPelangganServiceProvider.overrideWithValue(undangan),
    ],
    child: MaterialApp(
      theme: tema,
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CustomerListScreen(),
    ),
  );
}

Widget _panelDesktop(String token) {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      pakaiPanelDesktopProvider.overrideWithValue(true),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      notificationServiceProvider.overrideWithValue(
        MockNotificationService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
      izinServiceProvider.overrideWithValue(MockIzinService()),
    ],
    child: const SidikApp(),
  );
}

Future<void> _isiDanKirim(WidgetTester tester, String email) async {
  await tester.tap(find.text('Undang anggota').first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('undang-email')), email);
  await tester.tap(find.byKey(const Key('undang-kirim')));
}

void main() {
  group('siapa yang melihat Undang anggota', () {
    for (final (token, nama) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super_admin'),
    ]) {
      testWidgets('$nama melihat tombolnya di setiap perusahaan', (
        tester,
      ) async {
        await tester.pumpWidget(
          _layarDaftar(token: token, undangan: MockUndanganPelangganService()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Undang anggota'), findsNWidgets(2));
      });
    }

    for (final (token, nama) in [
      ('mock-token-2', 'teknisi'),
      ('mock-token-3', 'viewer'),
    ]) {
      testWidgets('$nama TIDAK melihat tombolnya', (tester) async {
        await tester.pumpWidget(
          _layarDaftar(token: token, undangan: MockUndanganPelangganService()),
        );
        await tester.pumpAndSettle();

        expect(find.text('PT Maju Jaya'), findsOneWidget);
        expect(find.text('Undang anggota'), findsNothing);
      });
    }
  });

  group('menu Pelanggan di panel desktop', () {
    Future<void> buka(WidgetTester tester, String token) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_panelDesktop(token));
      await tester.pumpAndSettle();
    }

    for (final (token, nama) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super_admin'),
    ]) {
      testWidgets('$nama melihat menu Pelanggan', (tester) async {
        await buka(tester, token);
        expect(find.text('Pelanggan'), findsOneWidget);
      });
    }

    for (final (token, nama) in [
      ('mock-token-2', 'teknisi'),
      ('mock-token-3', 'viewer'),
    ]) {
      testWidgets('$nama TIDAK melihat menu Pelanggan', (tester) async {
        await buka(tester, token);
        expect(find.text('Pelanggan'), findsNothing);
      });
    }
  });

  group('alur undang', () {
    testWidgets('sukses: kode tampil besar, Salin menyalin ke clipboard', (
      tester,
    ) async {
      final salinan = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            salinan.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final layanan = MockUndanganPelangganService(kode: 'K7M2QX9P');
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, '  siti@majujaya.co.id ');
      await tester.pumpAndSettle();

      expect(layanan.riwayat, hasLength(1));
      expect(layanan.riwayat.single.customerId, 1);
      expect(layanan.riwayat.single.email, 'siti@majujaya.co.id');
      expect(layanan.riwayat.single.peran, PeranUndangan.staf);

      expect(find.byKey(const Key('undang-kode')), findsOneWidget);
      expect(find.text('K7M2QX9P'), findsOneWidget);
      expect(find.byKey(const Key('undang-berlaku')), findsOneWidget);
      expect(
        find.textContaining('kode tidak bisa dilihat lagi. Berlaku 7 hari'),
        findsOneWidget,
      );
      expect(find.textContaining('membatalkan kode lama'), findsOneWidget);
      expect(
        find.text('Di app SIDIK Pelanggan: Masuk → Pakai kode undangan'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('undang-salin')));
      await tester.pump();

      expect(salinan, ['K7M2QX9P']);
      expect(find.text('Kode disalin'), findsOneWidget);
    });

    testWidgets('peran PIC utama ikut terkirim', (tester) async {
      final layanan = MockUndanganPelangganService();
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undang anggota').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIC utama'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('undang-email')),
        'pic@majujaya.co.id',
      );
      await tester.tap(find.byKey(const Key('undang-kirim')));
      await tester.pumpAndSettle();

      expect(layanan.riwayat.single.peran, PeranUndangan.picUtama);
    });

    testWidgets('respons tanpa kode: pesan jelas, tidak crash', (tester) async {
      final layanan = MockUndanganPelangganService(kode: null);
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, 'siti@majujaya.co.id');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('undang-tanpa-kode')), findsOneWidget);
      expect(
        find.text(
          'Undangan dibuat, tetapi kode belum tersedia di versi server ini — '
          'gunakan panel.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('undang-kode')), findsNothing);
      expect(find.byKey(const Key('undang-salin')), findsNothing);
    });

    testWidgets('422 dari server: pesan asli tampil, dialog tetap terbuka', (
      tester,
    ) async {
      final layanan = MockUndanganPelangganService(
        galat: const AuthException('Email ini sudah menjadi anggota aktif.'),
      );
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, 'siti@majujaya.co.id');
      await tester.pumpAndSettle();

      expect(
        find.text('Email ini sudah menjadi anggota aktif.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('undang-kode')), findsNothing);
      // Tombol hidup lagi supaya admin bisa memperbaiki dan mengirim ulang.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('undang-kirim')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('galat tak dikenal: pesan umum, bukan teks mentah', (
      tester,
    ) async {
      final layanan = _LayananMeledak();
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, 'siti@majujaya.co.id');
      await tester.pumpAndSettle();

      expect(find.text('Undangan gagal dikirim. Coba lagi.'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
    });

    testWidgets('email tidak valid ditolak di klien, tanpa request', (
      tester,
    ) async {
      final layanan = MockUndanganPelangganService();
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, 'bukan-email');
      await tester.pumpAndSettle();

      expect(find.text('Alamat email tidak valid.'), findsOneWidget);
      expect(layanan.jumlahPanggilan, 0);

      await tester.enterText(find.byKey(const Key('undang-email')), '');
      await tester.tap(find.byKey(const Key('undang-kirim')));
      await tester.pumpAndSettle();
      expect(find.text('Isi alamat email.'), findsOneWidget);
      expect(layanan.jumlahPanggilan, 0);
    });

    testWidgets('dobel ketuk Kirim = SATU request', (tester) async {
      final layanan = MockUndanganPelangganService(
        jeda: const Duration(seconds: 1),
      );
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, 'siti@majujaya.co.id');
      // Ketukan kedua tanpa menunggu frame — persis jari yang gelisah.
      await tester.tap(find.byKey(const Key('undang-kirim')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('undang-kirim')));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(layanan.jumlahPanggilan, 1);
    });

    testWidgets('selama mengirim tombol nonaktif', (tester) async {
      final layanan = MockUndanganPelangganService(
        jeda: const Duration(seconds: 1),
      );
      await tester.pumpWidget(_layarDaftar(undangan: layanan));
      await tester.pumpAndSettle();

      await _isiDanKirim(tester, 'siti@majujaya.co.id');
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('undang-kirim')))
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('dialog kode', () {
    for (final (tema, nama) in [
      (SidikTheme.terang, 'terang'),
      (SidikTheme.gelap, 'gelap'),
    ]) {
      testWidgets('tampil tanpa galat di mode $nama', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: tema,
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DialogKodeUndangan(
                undangan: UndanganPelanggan(
                  id: 9,
                  email: 'a@b.co',
                  berlakuSampai: DateTime(2026, 11, 17),
                  kode: 'ABCD2345',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('ABCD2345'), findsOneWidget);
        expect(find.text('Berlaku sampai 17 Nov 2026'), findsOneWidget);
      });
    }
  });

  group('UndanganPelanggan.fromJson', () {
    test('respons lengkap', () {
      final u = UndanganPelanggan.fromJson({
        'message': 'ok',
        'data': {
          'id': 4,
          'email': 'a@b.co',
          'peran': 'staf',
          'berlaku_sampai': '2026-11-17T10:00:00+07:00',
          'kode': 'ABCD2345',
        },
      });
      expect(u.kode, 'ABCD2345');
      expect(u.punyaKode, isTrue);
      expect(u.berlakuSampai, isNotNull);
    });

    test('server lama tanpa kode / tanpa data tidak melempar', () {
      final tanpaKode = UndanganPelanggan.fromJson({
        'data': {'id': 4, 'email': 'a@b.co'},
      });
      expect(tanpaKode.kode, isNull);
      expect(tanpaKode.punyaKode, isFalse);

      final kosong = UndanganPelanggan.fromJson({'message': 'ok'});
      expect(kosong.kode, isNull);
    });

    test('kode kosong dianggap tidak ada', () {
      final u = UndanganPelanggan.fromJson({
        'data': {'id': 1, 'email': 'a@b.co', 'kode': '  '},
      });
      expect(u.kode, isNull);
    });
  });

  test('berkas dialog tidak menyimpan kode ke penyimpanan lokal', () {
    final sumber = File(
      'lib/screens/settings/undang_anggota_dialog.dart',
    ).readAsStringSync();
    expect(sumber.contains('SharedPreferences'), isFalse);
    expect(sumber.contains('FlutterSecureStorage'), isFalse);
  });
}

class _LayananMeledak implements UndanganPelangganService {
  @override
  Future<UndanganPelanggan> undang(
    String token,
    int customerId, {
    required String email,
    required PeranUndangan peran,
  }) async => throw const FormatException('mentah');
}
