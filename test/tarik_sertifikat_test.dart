import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/revisi_sertifikat.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/screens/certificate/sertifikat_screen.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// "Tarik ke lembar kerja" (K-50-03): admin & super admin menarik sertifikat
/// terbit dengan alasan + sandi akun sendiri. Statusnya `ditarik` (bukan
/// dibatalkan); koreksi lalu Setujui ulang menerbitkan `<nomor>-R1`.
const _admin = 'mock-token-1';
const _superAdmin = 'mock-token-5';
const _teknisi = 'mock-token-2';

List<Override> _semua(MockCertificateService svc, String token, Izin izin) => [
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  certificateServiceProvider.overrideWithValue(svc),
  izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
];

Future<void> _pasang(
  WidgetTester tester,
  MockCertificateService svc, {
  String token = _admin,
  Izin? izin,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: _semua(
        svc,
        token,
        izin ??
            const Izin(
              role: UserRole.admin,
              boleh: {NamaIzin.sertifikatTarik, 'kalibrasi.lihat'},
            ),
      ),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SertifikatScreen(certificateId: 1),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<void> _buka(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tombol-tarik-sertifikat')));
  await tester.pumpAndSettle();
}

Future<void> _isi(WidgetTester tester, {String? alasan, String? sandi}) async {
  if (alasan != null) {
    await tester.enterText(
      find.byKey(const ValueKey('isian-tarik-alasan')),
      alasan,
    );
  }
  if (sandi != null) {
    await tester.enterText(
      find.byKey(const ValueKey('isian-tarik-sandi')),
      sandi,
    );
  }
  await tester.tap(find.byKey(const ValueKey('kirim-tarik-sertifikat')));
  await tester.pumpAndSettle();
}

void main() {
  group('siapa melihat tombolnya', () {
    for (final (nama, token, peran) in [
      ('admin', _admin, UserRole.admin),
      ('super admin', _superAdmin, UserRole.superAdmin),
    ]) {
      testWidgets('$nama dengan izin sertifikat.tarik: tombol ada', (
        tester,
      ) async {
        await _pasang(
          tester,
          MockCertificateService(),
          token: token,
          izin: Izin(role: peran, boleh: const {NamaIzin.sertifikatTarik}),
        );

        expect(
          find.byKey(const ValueKey('tombol-tarik-sertifikat')),
          findsOneWidget,
        );
        expect(find.text('Tarik ke lembar kerja'), findsOneWidget);
      });
    }

    testWidgets('tanpa izin (teknisi / server lama): tombol TIDAK ada', (
      tester,
    ) async {
      await _pasang(
        tester,
        MockCertificateService(),
        token: _teknisi,
        izin: const Izin(role: UserRole.teknisi, boleh: {'kalibrasi.lihat'}),
      );
      expect(
        find.byKey(const ValueKey('tombol-tarik-sertifikat')),
        findsNothing,
      );

      // Server lama: izin belum dikirim sama sekali → tidak ada cadangan peran.
      await _pasang(
        tester,
        MockCertificateService(),
        izin: Izin.kosong,
      );
      expect(
        find.byKey(const ValueKey('tombol-tarik-sertifikat')),
        findsNothing,
      );
    });

    testWidgets('sertifikat yang sudah ditarik: tidak bisa ditarik lagi', (
      tester,
    ) async {
      final svc = MockCertificateService(
        khusus: {
          1: const CertificateDetail(
            id: 1,
            nomor: '012-CAL-524',
            status: 'ditarik',
            statusDokumenKode: 'ditarik',
          ),
        },
      );
      await _pasang(tester, svc);

      expect(find.text('Ditarik'), findsWidgets);
      expect(
        find.byKey(const ValueKey('tombol-tarik-sertifikat')),
        findsNothing,
      );
    });
  });

  group('dialog', () {
    testWidgets('alasan < 10 karakter atau sandi kosong ditahan, tanpa kirim', (
      tester,
    ) async {
      final svc = MockCertificateService();
      await _pasang(tester, svc);
      await _buka(tester);

      await _isi(tester, alasan: 'typo');
      expect(find.text('Alasan minimal 10 karakter.'), findsOneWidget);
      expect(find.text('Sandi wajib diisi.'), findsOneWidget);
      expect(svc.ditarikDengan, isEmpty);
    });

    testWidgets('sandi salah (konfirmasi_sandi_salah): pesan jelas, dialog '
        'tetap, alasan tidak hilang', (tester) async {
      final svc = MockCertificateService();
      await _pasang(tester, svc);
      await _buka(tester);

      await _isi(
        tester,
        alasan: 'Angka disk 1 salah salin dari logger.',
        sandi: 'salah-sandi',
      );

      expect(find.text('Sandi salah. Coba lagi.'), findsOneWidget);
      expect(find.byKey(const ValueKey('dialog-tarik-sertifikat')), findsOne);
      final alasan = tester.widget<TextField>(
        find.byKey(const ValueKey('isian-tarik-alasan')),
      );
      expect(alasan.controller!.text, 'Angka disk 1 salah salin dari logger.');
      expect(svc.ditarikDengan, hasLength(1));
    });

    testWidgets('berhasil: alasan + sandi terkirim, status jadi Ditarik, '
        'tombol hilang', (tester) async {
      final svc = MockCertificateService();
      await _pasang(tester, svc);
      await _buka(tester);

      await _isi(
        tester,
        alasan: '  Angka disk 1 salah salin dari logger.  ',
        sandi: 'rahasia123',
      );

      expect(svc.ditarikDengan, [
        (
          alasan: '  Angka disk 1 salah salin dari logger.  ',
          password: 'rahasia123',
        ),
      ]);
      expect(find.byKey(const ValueKey('dialog-tarik-sertifikat')), findsNothing);
      expect(
        find.text('Sertifikat ditarik. Sesi kembali ke menunggu approval.'),
        findsOneWidget,
      );
      // Detail dimuat ulang: statusnya sendiri, bukan "Dibatalkan".
      expect(find.text('Ditarik'), findsWidgets);
      expect(find.text('Dibatalkan'), findsNothing);
      expect(
        find.byKey(const ValueKey('tombol-tarik-sertifikat')),
        findsNothing,
      );
    });
  });

  test('GalatAksi membaca `kode` dan errors dari badan 422', () {
    final g = GalatAksi.dariBody('x', {
      'kode': 'konfirmasi_sandi_salah',
      'errors': {
        'password': ['Sandi salah.'],
      },
    });
    expect(g.kode, 'konfirmasi_sandi_salah');
    expect(g.untuk('password'), 'Sandi salah.');
    expect(GalatAksi.dariBody('x', const {}).kode, isNull);
  });

  test('status_dokumen `ditarik` dikenali sebagai status sendiri', () {
    final c = CertificateDetail.fromJson(const {
      'id': 9,
      'nomor': 'CAL/1',
      'status': 'ditarik',
      'status_dokumen': 'ditarik',
    });
    expect(c.statusDokumen, StatusDokumen.ditarik);
    // Server lama yang cuma mengirim `status`: tetap ditarik, bukan "belum
    // terbit".
    final lama = CertificateDetail.fromJson(const {
      'id': 9,
      'nomor': 'CAL/1',
      'status': 'ditarik',
    });
    expect(lama.statusDokumen, StatusDokumen.ditarik);
  });
}
