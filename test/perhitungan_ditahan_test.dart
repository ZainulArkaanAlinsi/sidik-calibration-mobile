import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/penerbitan_ditahan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/app_button.dart';

/// Penerbitan ditahan menunggu Technical Manager (PR #280) di layar
/// Perhitungan/Setujui.
///
/// Teks alasan dan rujukan disalin dari respons API NYATA (uji kontrak app-API
/// 19 Nov 2026, `kontrak/hasil/dart-ditahan.json`, DT-D-proving_ring dan
/// DT-P-proving_ring). Mock di sini hanya mengantar JSON yang sama bentuknya.
const _alasan =
    'Proving Ring: U95 tercetak 2,3 kgf (pita 0 sampai 500 kgf lampiran '
    'LK-285-IDN), sedangkan master 22,4 kgf (pita 10 sampai 88 kN), sekitar '
    '10 kali lebih besar daripada sertifikat yang sudah pernah terbit. Pita '
    'CMC mana yang benar (G14) belum diputuskan';

const _ditahan = PenerbitanDitahan(
  ditahan: true,
  alasan: _alasan,
  rujukanTm: 'TM-4',
);

/// Detail sesi `GET /calibrations/{id}`; penahanannya diambil dari [bacaDitahan]
/// tiap kali dibaca, supaya tes bisa membalik keadaan server (TM melepas
/// penahanan) di tengah jalan.
class _Riwayat extends MockHistoryService {
  _Riwayat(this.bacaDitahan);

  final PenerbitanDitahan Function() bacaDitahan;
  int panggilDetail = 0;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    panggilDetail++;
    final p = bacaDitahan();
    return CalibrationDetail.fromJson({
      'id': id,
      'status': 'menunggu_approval',
      'equipment': {'id': 12, 'nama_alat': 'Proving Ring'},
      'teknisi': {'nama': 'Teknisi Sidik'},
      'nomor_sesi': 'KAL/2026/11/0030',
      'nomor_order': 'ORD/KT/proving_ring',
      'penerbitan_ditahan': {
        'ditahan': p.ditahan,
        'alasan': p.alasan,
        'rujukan_tm': p.rujukanTm,
      },
    });
  }
}

Widget _app(
  MockPerhitunganService perhitungan,
  _Riwayat riwayat, {
  CalibrationStatus? status = CalibrationStatus.menungguApproval,
}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    perhitunganServiceProvider.overrideWithValue(perhitungan),
    historyServiceProvider.overrideWithValue(riwayat),
    standardServiceProvider.overrideWithValue(MockStandardService()),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PerhitunganScreen(calibrationId: 30, statusSesi: status),
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

AppButton _tombol(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

final _banner = find.byKey(const ValueKey('banner-penerbitan-ditahan'));
final _dialog = find.byKey(const ValueKey('dialog-penerbitan-ditahan'));
final _petunjuk = find.byKey(const ValueKey('petunjuk-setujui-ditahan'));

void main() {
  group('banner dan tombol Setujui', () {
    testWidgets('ditahan: banner memuat alasan + rujukan TM, Setujui mati dan '
        'tidak mengirim apa pun', (tester) async {
      final svc = MockPerhitunganService();
      await _muat(tester, _app(svc, _Riwayat(() => _ditahan)));

      expect(_banner, findsOneWidget);
      expect(find.text('Penerbitan ditahan'), findsOneWidget);
      expect(find.text(_alasan), findsOneWidget);
      expect(find.text('Rujukan TM: TM-4'), findsOneWidget);
      expect(_petunjuk, findsOneWidget);

      expect(_tombol(tester, 'Setujui').onPressed, isNull);
      // Periksa tetap hidup: hitung ulang boleh kapan saja.
      expect(_tombol(tester, 'Periksa').onPressed, isNotNull);

      await tester.tap(find.text('Setujui'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        svc.aksi.where((a) => a.$1 == 'setujui'),
        isEmpty,
        reason: 'tombol mati tidak boleh mengirim approve',
      );
    });

    testWidgets('tidak ditahan: tidak ada banner dan Setujui hidup', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(MockPerhitunganService(), _Riwayat(() => PenerbitanDitahan.tidak)),
      );

      expect(_banner, findsNothing);
      expect(_petunjuk, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNotNull);
    });

    testWidgets('sesi yang sudah tidak bisa diputuskan tidak memajang banner', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(
          MockPerhitunganService(),
          _Riwayat(() => _ditahan),
          status: CalibrationStatus.disetujui,
        ),
      );

      expect(_banner, findsNothing);
    });

    testWidgets('"Baca alasan lengkap" membuka dialog dengan alasan utuh', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(MockPerhitunganService(), _Riwayat(() => _ditahan)),
      );

      await tester.tap(find.byKey(const ValueKey('baca-alasan-ditahan')));
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(find.byKey(const ValueKey('alasan-dialog')), findsOneWidget);
      expect(find.text(_alasan), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('tutup-dialog-ditahan')));
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    });

    testWidgets('Periksa membaca ulang penahanan: TM melepas, banner hilang '
        'dan Setujui hidup lagi', (tester) async {
      var kini = _ditahan;
      final riwayat = _Riwayat(() => kini);
      await _muat(tester, _app(MockPerhitunganService(), riwayat));
      expect(_banner, findsOneWidget);
      final sebelum = riwayat.panggilDetail;

      kini = PenerbitanDitahan.tidak;
      await tester.tap(find.text('Periksa'));
      await tester.pumpAndSettle();

      expect(riwayat.panggilDetail, greaterThan(sebelum));
      expect(_banner, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNotNull);
    });
  });

  group('422 profil_ditahan dari klien yang datanya basi', () {
    testWidgets('dialog yang terbaca, bukan SnackBar; banner menyusul dari '
        'detail yang dibaca ulang', (tester) async {
      // Detail awal belum tahu soal penahanan (klien lama / data basi); server
      // sudah menahan, jadi approve ditolak dan bacaan berikutnya ikut ditahan.
      var serverMenahan = false;
      final svc = MockPerhitunganService(penerbitanDitahan: _ditahan);
      final riwayat = _Riwayat(
        () => serverMenahan ? _ditahan : PenerbitanDitahan.tidak,
      );
      await _muat(tester, _app(svc, riwayat));
      expect(_banner, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNotNull);

      serverMenahan = true;
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('isian-nomor-sertifikat')),
        'CAL/KT/H-proving_ring',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-setujui')));
      await tester.pumpAndSettle();

      // Server menjawab 422: dialog penjelasan, bukan SnackBar panjang.
      expect(_dialog, findsOneWidget);
      expect(find.text('Penerbitan sertifikat ditahan'), findsOneWidget);
      expect(find.text(_alasan), findsWidgets);
      expect(find.text('Rujukan TM: TM-4'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tutup-dialog-ditahan')));
      await tester.pumpAndSettle();

      // Layar tetap terbuka (status sesi tidak berubah) dan kini ikut server.
      expect(find.byType(PerhitunganScreen), findsOneWidget);
      expect(_banner, findsOneWidget);
      expect(_tombol(tester, 'Setujui').onPressed, isNull);
      expect(svc.aksi.where((a) => a.$1 == 'setujui').length, 1);
    });
  });
}
