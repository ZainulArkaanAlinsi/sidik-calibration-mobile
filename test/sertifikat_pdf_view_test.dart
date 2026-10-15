import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/screens/certificate/sertifikat_screen.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar sertifikat merender PDF server (G4): badan sertifikat bukan lagi tabel
/// rakitan app, jadi struktur per jenis alat identik dengan cetak. Test ini
/// menjaga: ringkasan di atas, penampil PDF, skeleton, galat + coba lagi, dan
/// salinan tersimpan saat luring. Fixture PDF dibangkitkan di sini (kosong,
/// tanpa data pelanggan).

/// PDF satu halaman A4 minimal, offset xref dihitung benar.
List<int> _pdfKecil() {
  final objek = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >>',
  ];
  final b = StringBuffer('%PDF-1.4\n');
  final offset = <int>[];
  for (var i = 0; i < objek.length; i++) {
    offset.add(b.length);
    b.write('${i + 1} 0 obj\n${objek[i]}\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objek.length + 1}\n0000000000 65535 f \n');
  for (final o in offset) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write(
    'trailer\n<< /Size ${objek.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return latin1.encode(b.toString());
}

CertificateDetail _sertifikat({String? statusDokumen, int revisiKe = 0}) =>
    CertificateDetail.fromJson({
      'id': 1,
      'nomor': 'CAL/2026/10/0099',
      'status': 'terbit',
      'status_dokumen': statusDokumen,
      'revisi_ke': revisiKe,
      'berlaku_sampai': '2027-10-15',
      'snapshot': {
        'desimal': 2,
        'header': {
          'certificate_number': 'CAL/2026/10/0099',
          'owner': 'PT Contoh Uji',
          'equipment_name': 'Oven Laboratorium',
        },
      },
    });

Future<void> _pasang(
  WidgetTester tester,
  CertificateDetail s,
  Future<PdfSertifikat> Function() pdf,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final overrides = <Override>[
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-2'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    certificateServiceProvider.overrideWithValue(
      MockCertificateService(khusus: {1: s}),
    ),
    pdfSertifikatProvider.overrideWith((ref, id) => pdf()),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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

void main() {
  testWidgets('ringkasan di atas + penampil PDF; tabel rakitan app hilang', (
    tester,
  ) async {
    await _pasang(
      tester,
      _sertifikat(),
      () async => PdfSertifikat(_pdfKecil()),
    );

    expect(find.byKey(const ValueKey('ringkasan-sertifikat')), findsOneWidget);
    expect(find.text('CAL/2026/10/0099'), findsOneWidget);
    expect(find.text('PT Contoh Uji'), findsOneWidget);
    expect(find.text('Oven Laboratorium'), findsOneWidget);
    expect(find.text('2027-10-15'), findsOneWidget);
    expect(find.byType(PdfViewer), findsOneWidget);
    expect(find.text('Tabel Hasil Kalibrasi'), findsNothing);
    expect(find.byKey(const ValueKey('pdf-sertifikat-luring')), findsNothing);
  });

  testWidgets('status ditarik dan revisi R-n tetap tampil di kartu status', (
    tester,
  ) async {
    await _pasang(
      tester,
      _sertifikat(statusDokumen: 'ditarik', revisiKe: 2),
      () async => PdfSertifikat(_pdfKecil()),
    );

    expect(
      find.byKey(const ValueKey('info-dokumen-sertifikat')),
      findsOneWidget,
    );
    expect(find.text('Revisi ke-2'), findsOneWidget);
  });

  testWidgets('memuat: skeleton statis, lalu penampil setelah PDF datang', (
    tester,
  ) async {
    final selesai = Completer<PdfSertifikat>();
    await _pasang(tester, _sertifikat(), () => selesai.future);

    expect(find.byKey(const ValueKey('pdf-sertifikat-memuat')), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);

    selesai.complete(PdfSertifikat(_pdfKecil()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pdf-sertifikat-memuat')), findsNothing);
    expect(find.byType(PdfViewer), findsOneWidget);
  });

  testWidgets('gagal: pesan + Coba lagi memuat ulang', (tester) async {
    var panggilan = 0;
    await _pasang(tester, _sertifikat(), () async {
      panggilan++;
      if (panggilan == 1) throw Exception('putus');
      return PdfSertifikat(_pdfKecil());
    });

    expect(find.byKey(const ValueKey('pdf-sertifikat-gagal')), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);
    // Ringkasan tetap ada walau PDF gagal.
    expect(find.byKey(const ValueKey('ringkasan-sertifikat')), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(panggilan, 2);
    expect(find.byType(PdfViewer), findsOneWidget);
  });

  testWidgets('luring: salinan tersimpan tampil dengan keterangannya', (
    tester,
  ) async {
    await _pasang(
      tester,
      _sertifikat(),
      () async => PdfSertifikat(_pdfKecil(), dariCache: true),
    );

    expect(find.byKey(const ValueKey('pdf-sertifikat-luring')), findsOneWidget);
    expect(find.byType(PdfViewer), findsOneWidget);
  });

  testWidgets('bilah unduh tetap ada di bawah penampil', (tester) async {
    await _pasang(
      tester,
      _sertifikat(),
      () async => PdfSertifikat(_pdfKecil()),
    );

    expect(find.text('PDF'), findsOneWidget);
  });
}
