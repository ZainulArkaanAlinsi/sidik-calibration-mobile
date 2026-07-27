import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/widgets/certificate_qr.dart';

Widget _bungkus(Widget child) {
  return MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('QR verifikasi sertifikat', () {
    test('url lebih diutamakan daripada token', () {
      const qr = CertificateQr(
        token: 'abc123',
        url: 'https://sidik.example/verify/abc123',
      );

      // Yang discan orang harus URL utuh. Kalau backend ngirim dua-duanya,
      // token mentah nggak boleh menang — dia nggak nunjuk ke mana-mana.
      expect(qr.isi, 'https://sidik.example/verify/abc123');
    });

    test('token dipakai kalau url belum dikirim backend', () {
      const qr = CertificateQr(token: 'abc123');
      expect(qr.isi, 'abc123');
    });

    test('string kosong diperlakukan sama kayak nggak ada', () {
      // Backend yang ngirim `""` gampang kejadian, dan QR dari string kosong
      // itu kotak yang nggak nunjuk ke mana-mana — lebih parah daripada
      // nggak ada QR.
      const qr = CertificateQr(token: '   ', url: '');
      expect(qr.isi, isNull);
    });

    testWidgets('token ada → QR beneran digambar', (tester) async {
      await tester.pumpWidget(
        _bungkus(const CertificateQr(token: 'sidik-1-a1b2c3d4')),
      );
      await tester.pumpAndSettle();

      // Isi QR-nya sendiri nggak bisa dibaca dari widget (`_data` privat di
      // qr_flutter), jadi yang diuji di sini cuma "kegambar apa nggak".
      // Pemilihan url-vs-token diuji terpisah lewat getter `isi` di atas.
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('token belum ada → dijelasin, bukan disembunyiin diam-diam',
        (tester) async {
      await tester.pumpWidget(_bungkus(const CertificateQr(token: null)));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      // Kalau QR-nya raib tanpa keterangan, teknisi ngiranya app-nya rusak.
      expect(find.textContaining('QR-nya belum ada'), findsOneWidget);
    });

    testWidgets('latar QR putih walau tema lagi gelap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CertificateQr(token: 'abc123')),
        ),
      );
      await tester.pumpAndSettle();

      // Pemindai baca kontras gelap-di-atas-terang. QR yang ngikut warna latar
      // app di tema gelap jadi kebalik, dan banyak pemindai nolak bacanya.
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).backgroundColor,
        Colors.white,
      );
    });
  });
}
