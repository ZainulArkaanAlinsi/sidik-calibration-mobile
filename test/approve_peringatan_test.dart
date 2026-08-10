import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Peringatan validasi harus KELIHATAN sebelum sesi disetujui.
///
/// 10 Agt 2026: sesi Turbidimeter `KAL/2026/08/0031` kesimpen dengan
/// `kelembaban_awal = 2 %RH` — `52` yang kepencet jadi `2`. Sertifikatnya
/// kecetak `%RH: 27% ± 53,2%`: ketidakpastian dua kali lipat nilainya sendiri,
/// di dokumen terakreditasi.
///
/// Validator backend sendiri UDAH bener dan udah teriak dua kali
/// (`kelembaban_mustahil` & `delta_kelembaban_ekstrem`), dan backend nolak
/// approve-nya dengan 422 + `butuh_konfirmasi`. Yang bolong jalannya ke mata
/// admin: layar Riwayat nerjemahin 422 itu jadi snackbar berisi teks exception
/// mentah, jadi admin nggak pernah lihat temuannya — apalagi mutusin.
///
/// Yang dijaga di sini: temuan kelihatan, dan lanjutnya harus SADAR.
class _ApprovalPeringatan implements ApprovalService {
  _ApprovalPeringatan();

  /// Nilai `abaikan_peringatan` di tiap panggilan approve, urut.
  final List<bool> panggilan = [];

  @override
  Future<int?> approve(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
  }) async {
    panggilan.add(abaikanPeringatan);

    if (!abaikanPeringatan) {
      throw const ApiException(
        'Hasil hitung ulang beda dari yang tersimpan.',
        status: 422,
        body: {
          'butuh_konfirmasi': true,
          'validasi': {
            'valid': false,
            'boleh_terbit': true,
            'ringkasan': {'error': 0, 'peringatan': 2, 'info': 0},
            'temuan': [
              {
                'tingkat': 'peringatan',
                'kode': 'kelembaban_mustahil',
                'pesan': 'Kelembaban awal kecatat 2 %RH — di luar rentang '
                    'wajar ruang lab (20–90 %RH).',
                'konteks': {'kolom': 'kelembaban_awal', 'nilai': 2},
              },
              {
                'tingkat': 'peringatan',
                'kode': 'delta_kelembaban_ekstrem',
                'pesan': 'Kelembaban bergeser 53 %RH selama sesi ini.',
                'konteks': {'kolom': 'kelembaban_akhir'},
              },
            ],
          },
        },
      );
    }

    return 900 + calibrationId;
  }

  @override
  Future<void> reject(String token, int calibrationId, String catatan) async {}

  @override
  Future<void> retryGenerate(String token, int certificateId) async {}
}

class _SatuSesiMenunggu implements HistoryService {
  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async => [
    CalibrationHistoryItem(
      id: 42,
      namaAlat: 'Turbidimeter',
      namaTeknisi: 'Dimas Rahardjo',
      tanggalKalibrasi: DateTime(2026, 8, 9),
      status: CalibrationStatus.menungguApproval,
    ),
  ];

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => ambilRiwayat(token);

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) =>
      MockHistoryService().ambilDetail(token, id);

  @override
  Future<CalibrationDetail> verifikasiPembacaan(String token, int id) =>
      MockHistoryService().verifikasiPembacaan(token, id);
}

Widget _app(ApprovalService approval) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(_SatuSesiMenunggu()),
      approvalServiceProvider.overrideWithValue(approval),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HistoryScreen(),
    ),
  );
}

void main() {
  testWidgets('peringatan ditampilin apa adanya, bukan teks exception', (
    tester,
  ) async {
    final approval = _ApprovalPeringatan();

    await tester.pumpWidget(_app(approval));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('SETUJUI'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Pesan temuannya kebaca utuh — ini yang dulu nggak pernah sampai ke mata
    // admin.
    expect(
      find.textContaining('Kelembaban awal kecatat 2 %RH'),
      findsOneWidget,
    );
    expect(find.textContaining('bergeser 53 %RH'), findsOneWidget);

    // Dan sesinya BELUM disetujui — masih nunggu keputusan.
    expect(approval.panggilan, [false]);
  });

  testWidgets('SETUJUI TETAP ngirim abaikan_peringatan', (tester) async {
    final approval = _ApprovalPeringatan();

    await tester.pumpWidget(_app(approval));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('SETUJUI'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('SETUJUI TETAP'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Dua panggilan: yang pertama ditolak backend, yang kedua sadar.
    expect(approval.panggilan, [false, true]);
  });

  testWidgets('PERIKSA LAGI nggak nyetujuin apa-apa', (tester) async {
    final approval = _ApprovalPeringatan();

    await tester.pumpWidget(_app(approval));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('SETUJUI'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('PERIKSA LAGI'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Cuma panggilan pertama. Nggak ada yang nyelonong lewat.
    expect(approval.panggilan, [false]);
    expect(find.text('SETUJUI'), findsOneWidget);
  });
}
