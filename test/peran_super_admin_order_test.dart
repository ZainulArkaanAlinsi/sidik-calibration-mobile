import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/antrean_approval_screen.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/screens/admin/widgets/data_administrasi.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/kode_galat.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Super admin = semua aksi admin + teknisi, dan Order Number diisi Master
/// Data/super admin sebelum Setujui (keputusan pemilik K-49-14, 15 Okt 2026).
///
/// K-30-03 tetap: yang mengisi/mengoreksi sesi tidak bisa menyetujuinya
/// sendiri — server menjawab 422 `pemisahan_wewenang`, dan layar wajib
/// menyebut jalan keluarnya, bukan teks galat mentah.
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
const _admin = 'mock-token-1';
const _superAdmin = 'mock-token-5';

const _pesanWewenang =
    'Sesi ini Anda isi atau koreksi sendiri — harus disetujui/disahkan '
    'orang lain.';

/// Detail sesi `GET /calibrations/{id}` — Order Number ikut dari
/// [MockPerhitunganService.nomorOrderTersimpan] supaya simpan → muat ulang
/// benar-benar memperlihatkan nilai baru.
class _Riwayat extends MockHistoryService {
  _Riwayat(this.perhitungan, {this.kirimKunciNomorOrder = true});

  final MockPerhitunganService perhitungan;

  /// `false` = niru server lama yang tidak mengirim kunci `nomor_order`.
  final bool kirimKunciNomorOrder;

  int panggilDetail = 0;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    panggilDetail++;
    return CalibrationDetail.fromJson({
      'id': id,
      'status': 'menunggu_approval',
      'equipment': {'id': 14, 'nama_alat': 'pH Meter', 'profil': 'ph_meter'},
      'teknisi': {'nama': 'Teknisi Sidik'},
      'nomor_sesi': 'KAL/2026/10/0042',
      if (kirimKunciNomorOrder) 'nomor_order': perhitungan.nomorOrderTersimpan,
      'metode_kalibrasi': {
        'id': 3,
        'kode': 'SIDIK-IK-CAL-0506_Rev.4',
        'nama': 'pH',
      },
      'ruangan': {'id': 2, 'kode': 'R-01', 'nama': 'Lab Kimia'},
      'tanggal_terima': '2024-05-26',
    });
  }
}

Widget _app(
  MockPerhitunganService perhitungan, {
  String token = _admin,
  bool kirimKunciNomorOrder = true,
}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
    authServiceProvider.overrideWithValue(MockAuthService()),
    perhitunganServiceProvider.overrideWithValue(perhitungan),
    historyServiceProvider.overrideWithValue(
      _Riwayat(perhitungan, kirimKunciNomorOrder: kirimKunciNomorOrder),
    ),
    standardServiceProvider.overrideWithValue(MockStandardService()),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PerhitunganScreen(
      calibrationId: 42,
      statusSesi: CalibrationStatus.menungguApproval,
    ),
  ),
);

Future<void> _muat(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1400, 4400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _tekanSetujui(WidgetTester tester) async {
  await tester.tap(find.text('Setujui'));
  await tester.pumpAndSettle();
}

void main() {
  group('aturan peran (K-49-14)', () {
    test('super admin memegang hak admin DAN bisa input', () {
      expect(UserRole.superAdmin.hakAdmin, isTrue);
      expect(UserRole.superAdmin.bisaInput, isTrue);
      expect(UserRole.admin.hakAdmin, isTrue);
      expect(UserRole.admin.bisaInput, isTrue);
    });

    test('teknisi bisa input tapi TIDAK punya hak admin; viewer nol', () {
      expect(UserRole.teknisi.hakAdmin, isFalse);
      expect(UserRole.teknisi.bisaInput, isTrue);
      expect(UserRole.viewer.hakAdmin, isFalse);
      expect(UserRole.viewer.bisaInput, isFalse);
    });

    test('cadangan izin: hakAdmin aman untuk peran null', () {
      const UserRole? kosong = null;
      expect(kosong.hakAdmin, isFalse);
      expect(UserRole.superAdmin.hakAdmin, isTrue);
    });

    test('kode galat dibaca dari `kode` maupun `code`', () {
      expect(
        kodeDariBadan({'kode': 'pemisahan_wewenang'}),
        KodeGalat.pemisahanWewenang,
      );
      expect(
        kodeDariBadan({'code': 'nomor_order_wajib'}),
        KodeGalat.nomorOrderWajib,
      );
      expect(kodeDariBadan(const {}), isNull);
      expect(
        kodeGalatApi(
          const ApiException('x', status: 422, body: {'kode': 'apa_saja'}),
        ),
        'apa_saja',
      );
      expect(kodeGalatApi(Exception('x')), isNull);
    });
  });

  group('kartu Data administrasi', () {
    testWidgets('memperlihatkan Order Number kosong, metode, ruangan, '
        'tanggal terima, dan tombol buka lembar', (tester) async {
      await _muat(tester, _app(MockPerhitunganService()));

      expect(find.byKey(const ValueKey('kartu-data-administrasi')), findsOne);
      expect(find.text('DATA ADMINISTRASI'), findsOneWidget);
      expect(find.text('Belum diisi'), findsOneWidget);
      expect(find.text('SIDIK-IK-CAL-0506_Rev.4'), findsOneWidget);
      expect(find.text('R-01 — Lab Kimia'), findsOneWidget);
      expect(find.text('2024-05-26'), findsWidgets);
      expect(find.byKey(const ValueKey('buka-lembar-teknisi')), findsOneWidget);
      // Petunjuk di bilah aksi: Setujui akan meminta Order Number.
      expect(
        find.byKey(const ValueKey('petunjuk-nomor-order')),
        findsOneWidget,
      );
    });

    testWidgets('Ubah Order Number → PATCH /admin cuma membawa nomor_order', (
      tester,
    ) async {
      final svc = MockPerhitunganService();
      await _muat(tester, _app(svc));

      await tester.tap(find.byKey(const ValueKey('ubah-nomor-order')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('isian-nomor-order')),
        '  2405.13.A  ',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-nomor-order')));
      await tester.pumpAndSettle();

      expect(svc.kolomAdminTerkirim, [
        {'nomor_order': '2405.13.A'},
      ]);
      // Detail dimuat ulang: kartu menampilkan nilai baru.
      expect(find.text('2405.13.A'), findsOneWidget);
      expect(find.text('Belum diisi'), findsNothing);
      expect(find.byKey(const ValueKey('petunjuk-nomor-order')), findsNothing);
    });

    testWidgets('Order Number tidak bisa disimpan kosong', (tester) async {
      final svc = MockPerhitunganService();
      await _muat(tester, _app(svc));

      await tester.tap(find.byKey(const ValueKey('ubah-nomor-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('simpan-nomor-order')));
      await tester.pumpAndSettle();

      expect(find.text('Order Number wajib diisi.'), findsOneWidget);
      expect(find.byType(DialogNomorOrder), findsOneWidget);
      expect(svc.kolomAdminTerkirim, isEmpty);
    });
  });

  group('Setujui ditahan sampai Order Number terisi', () {
    testWidgets('Order Number kosong: Setujui minta diisi dulu, baru approve', (
      tester,
    ) async {
      final svc = MockPerhitunganService(wajibNomorOrder: true);
      await _muat(tester, _app(svc));
      final setujuiSebelum = svc.aksi.where((a) => a.$1 == 'setujui').length;

      await _tekanSetujui(tester);

      // Dialog muncul SEBELUM ada approve yang dikirim.
      expect(find.byType(DialogNomorOrder), findsOneWidget);
      expect(svc.aksi.where((a) => a.$1 == 'setujui').length, setujuiSebelum);

      await tester.enterText(
        find.byKey(const ValueKey('isian-nomor-order')),
        'ORD-77',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-nomor-order')));
      await tester.pumpAndSettle();

      expect(svc.nomorOrderTersimpan, 'ORD-77');
      expect(svc.aksi.where((a) => a.$1 == 'setujui'), hasLength(1));
      // Disetujui → layar ditutup.
      expect(find.byType(PerhitunganScreen), findsNothing);
    });

    testWidgets('batal di dialog Order Number = tidak ada approve', (
      tester,
    ) async {
      final svc = MockPerhitunganService(wajibNomorOrder: true);
      await _muat(tester, _app(svc));

      await _tekanSetujui(tester);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(svc.aksi.where((a) => a.$1 == 'setujui'), isEmpty);
      expect(svc.kolomAdminTerkirim, isEmpty);
    });

    testWidgets('server lama tanpa kunci nomor_order: tidak ditahan di '
        'layar; 422 nomor_order_wajib → diminta lalu diulang', (tester) async {
      final svc = MockPerhitunganService(wajibNomorOrder: true);
      await _muat(tester, _app(svc, kirimKunciNomorOrder: false));

      expect(find.byKey(const ValueKey('petunjuk-nomor-order')), findsNothing);

      await _tekanSetujui(tester);

      // Approve pertama sudah terkirim & ditolak 422 → dialog muncul.
      expect(svc.aksi.where((a) => a.$1 == 'setujui'), hasLength(1));
      expect(find.byType(DialogNomorOrder), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('isian-nomor-order')),
        'ORD-9',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-nomor-order')));
      await tester.pumpAndSettle();

      expect(svc.aksi.where((a) => a.$1 == 'setujui'), hasLength(2));
      expect(find.byType(PerhitunganScreen), findsNothing);
    });
  });

  group('422 pemisahan_wewenang', () {
    for (final (nama, token) in [
      ('admin', _admin),
      ('super admin', _superAdmin),
    ]) {
      testWidgets('$nama: pesan jelas — orang lain yang menyetujui', (
        tester,
      ) async {
        final svc = MockPerhitunganService(
          kodeTolakApprove: KodeGalat.pemisahanWewenang,
        )..nomorOrderTersimpan = 'ORD-1';
        await _muat(tester, _app(svc, token: token));

        await _tekanSetujui(tester);

        expect(find.text(_pesanWewenang), findsOneWidget);
        expect(find.byType(DialogNomorOrder), findsNothing);
      });
    }
  });

  group('antrean approval (tombol di kartu)', () {
    testWidgets('Order Number kosong → diminta, disimpan, lalu disetujui', (
      tester,
    ) async {
      final approval = _ApprovalRekam();
      final perhitungan = MockPerhitunganService();
      await _muatAntrean(tester, approval, perhitungan);

      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      expect(find.byType(DialogNomorOrder), findsOneWidget);
      expect(approval.panggilan, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('isian-nomor-order')),
        'ORD-12',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-nomor-order')));
      await tester.pumpAndSettle();

      expect(perhitungan.kolomAdminTerkirim, [
        {'nomor_order': 'ORD-12'},
      ]);
      expect(approval.panggilan, [42]);
    });

    testWidgets('422 pemisahan_wewenang → kalimat jelas di snackbar', (
      tester,
    ) async {
      final approval = _ApprovalRekam(kode: KodeGalat.pemisahanWewenang);
      await _muatAntrean(
        tester,
        approval,
        MockPerhitunganService(),
        nomorOrder: 'ORD-1',
      );

      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();

      expect(find.textContaining(_pesanWewenang), findsOneWidget);
    });
  });
}

class _ApprovalRekam implements ApprovalService {
  _ApprovalRekam({this.kode});

  final String? kode;
  final List<int> panggilan = [];

  @override
  Future<int?> approve(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
  }) async {
    if (kode != null) {
      throw ApiException(
        'Kamu ikut mengisi atau mengoreksi data sesi ini.',
        status: 422,
        body: {'kode': kode},
      );
    }
    panggilan.add(calibrationId);
    return null;
  }

  @override
  Future<void> reject(String token, int calibrationId, String catatan) async {}

  @override
  Future<void> retryGenerate(String token, int certificateId) async {}
}

class _AntreanSatu extends MockHistoryService {
  _AntreanSatu(this.nomorOrder);

  final String? nomorOrder;

  CalibrationHistoryItem get _item => CalibrationHistoryItem(
    id: 42,
    namaAlat: 'pH Meter',
    namaTeknisi: 'Teknisi Sidik',
    tanggalKalibrasi: DateTime(2026, 10, 14),
    status: CalibrationStatus.menungguApproval,
    nomorOrder: nomorOrder,
    nomorOrderDiketahui: true,
  );

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async => [
    _item,
  ];

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => [_item];
}

Future<void> _muatAntrean(
  WidgetTester tester,
  ApprovalService approval,
  MockPerhitunganService perhitungan, {
  String? nomorOrder,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_admin)),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(_AntreanSatu(nomorOrder)),
        approvalServiceProvider.overrideWithValue(approval),
        perhitunganServiceProvider.overrideWithValue(perhitungan),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AntreanApprovalScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}
