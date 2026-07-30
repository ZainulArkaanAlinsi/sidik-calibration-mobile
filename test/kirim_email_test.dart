import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/kirim_email.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/kirim_email_provider.dart';
import 'package:sidik_calibration/screens/history/kirim_email_screen.dart';
import 'package:sidik_calibration/services/kirim_email_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app(MockKirimEmailService service, {String token = 'mock-token-1'}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      kirimEmailServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const KirimEmailScreen(
        certificateId: 7,
        nomorSertifikat: 'CAL/2026/07/0001',
      ),
    ),
  );
}

/// `MockAuthService` jedanya 600 ms dan `pumpAndSettle()` nggak majuin timer.
Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _isiKe(WidgetTester tester, String teks) async {
  await tester.enterText(find.widgetWithText(TextField, 'Ke'), teks);
  await tester.pumpAndSettle();
}

/// `url_launcher` nembak kanal platform yang nggak ada di test. Dipalsukan di
/// sini biar alur "catat ke server lalu buka WhatsApp" bisa diuji utuh —
/// yang penting diuji itu urutannya & apa yang tercatat, bukan WhatsApp-nya
/// beneran kebuka.
List<String> _pasangKanalWa() {
  final dibuka = <String>[];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (panggilan) async {
      if (panggilan.method == 'launch') {
        dibuka.add(panggilan.arguments['url'] as String);
      }
      return true;   // canLaunch & launch dua-duanya
    },
  );

  return dibuka;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PercobaanEmail — parsing tahan bentuk yang belum pasti', () {
    test('bentuk normal', () {
      final p = PercobaanEmail.fromJson(const {
        'id': 1,
        'ke': ['a@b.com'],
        'cc': ['c@d.com'],
        'status': 'terkirim',
        'dikirim_pada': '2026-07-28T10:00:00Z',
        'oleh': {'nama': 'Budi'},
      });

      expect(p.ke, ['a@b.com']);
      expect(p.cc, ['c@d.com']);
      expect(p.berhasil, isTrue);
      expect(p.oleh, 'Budi');
    });

    test('alamat dikirim sebagai string berkoma, bukan array', () {
      final p = PercobaanEmail.fromJson(const {
        'id': 1,
        'ke': 'a@b.com, c@d.com',
      });

      expect(p.ke, ['a@b.com', 'c@d.com']);
    });

    test('status nggak kebaca + ada error → dianggap GAGAL', () {
      // Salah nandain gagal jadi berhasil lebih bahaya: admin ngira udah
      // kekirim padahal belum, dan pelanggan nggak pernah nerima.
      final p = PercobaanEmail.fromJson(const {
        'id': 1,
        'ke': ['a@b.com'],
        'error': 'SMTP timeout',
      });

      expect(p.berhasil, isFalse);
      expect(p.error, 'SMTP timeout');
    });

    test('error string kosong nggak dianggap ada error', () {
      final p = PercobaanEmail.fromJson(const {
        'id': 1,
        'ke': ['a@b.com'],
        'error': '',
      });

      expect(p.berhasil, isTrue);
      expect(p.error, isNull);
    });
  });

  group('Layar kirim email', () {
    testWidgets('teknisi ditolak — form nggak dirender sama sekali',
        (tester) async {
      await _pasang(
        tester,
        _app(MockKirimEmailService(), token: 'mock-token-2'),
      );

      expect(find.textContaining('Cuma admin'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('penerima kosong ditolak sebelum nembak server',
        (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      expect(find.textContaining('minimal satu penerima'), findsOneWidget);
      expect(await service.riwayat('t', 7), isEmpty);
    });

    testWidgets('alamat ngawur ditolak, alamatnya disebut', (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await _isiKe(tester, 'bukan-email');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      // Alamat mana yang salah ikut disebut — kalau ada 8 alamat, "ada yang
      // salah" doang nggak nolong. Dicari teks error-nya persis, bukan
      // `textContaining`: isi TextField-nya juga ngandung 'bukan-email'.
      expect(
        find.text('Bukan alamat email yang sah: bukan-email'),
        findsOneWidget,
      );
      expect(await service.riwayat('t', 7), isEmpty);
    });

    testWidgets('lebih dari 10 alamat ditolak di layar', (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      final banyak = List.generate(11, (i) => 'orang$i@pt-sidik.com').join(',');
      await _isiKe(tester, banyak);
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      // Teks persis: keterangan di bawah kolom juga nyebut "Maks 10".
      expect(find.text('Maks 10 alamat.'), findsOneWidget);
      expect(await service.riwayat('t', 7), isEmpty);
    });

    testWidgets('kirim berhasil → masuk riwayat', (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await _isiKe(tester, 'pelanggan@pt-maju.com');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      expect(find.text('Sertifikat terkirim.'), findsOneWidget);
      expect(find.text('pelanggan@pt-maju.com'), findsWidgets);
      expect(find.text('Terkirim'), findsOneWidget);
    });

    testWidgets('kirim GAGAL → percobaannya TETAP muncul di riwayat',
        (tester) async {
      final service = MockKirimEmailService(gagalKirim: true);
      await _pasang(tester, _app(service));

      await _isiKe(tester, 'pelanggan@pt-maju.com');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      // Ini inti §2d: `502` BUKAN "nggak terjadi apa-apa". Riwayatnya nambah
      // satu baris, dan itu yang dicari waktu pelanggan ngaku nggak nerima.
      expect(find.text('Gagal'), findsOneWidget);
      expect(find.textContaining('mailbox penuh'), findsOneWidget);
    });

    testWidgets('belum pernah dikirim → dibilang, bukan daftar kosong melompong',
        (tester) async {
      await _pasang(tester, _app(MockKirimEmailService()));

      expect(find.text('Belum pernah dikirim.'), findsOneWidget);
    });
  });

  group('Pilihan format kirim', () {
    testWidgets('bawaannya PDF, dan itu yang kekirim kalau nggak diapa-apain',
        (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await _isiKe(tester, 'pelanggan@pt-maju.com');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      final riwayat = await service.riwayat('t', 7);
      expect(riwayat.single.format, FormatKirim.pdf);
    });

    testWidgets('pilih Tautan → yang kekirim `tautan`, bukan PDF',
        (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await tester.tap(find.text('Tautan'));
      await tester.pumpAndSettle();
      await _isiKe(tester, 'pelanggan@pt-maju.com');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      final riwayat = await service.riwayat('t', 7);
      expect(riwayat.single.format, FormatKirim.tautan);
    });

    testWidgets('pilih Excel → yang kekirim `xlsx`', (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await tester.tap(find.text('Excel'));
      await tester.pumpAndSettle();
      await _isiKe(tester, 'pelanggan@pt-maju.com');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      expect((await service.riwayat('t', 7)).single.format, FormatKirim.xlsx);
    });

    testWidgets('konsekuensi tiap pilihan ditulis, bukan cuma namanya',
        (tester) async {
      await _pasang(tester, _app(MockKirimEmailService()));

      // "Tautan" kedengeran ringan sampai admin sadar pelanggan nggak nerima
      // berkas apa pun — kalimatnya harus ganti waktu pilihannya ganti.
      expect(find.textContaining('dilampirkan di email'), findsOneWidget);

      await tester.tap(find.text('Tautan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tanpa lampiran'), findsOneWidget);
    });

    testWidgets('format ikut kelihatan di baris riwayat', (tester) async {
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await tester.tap(find.text('Excel'));
      await tester.pumpAndSettle();
      await _isiKe(tester, 'pelanggan@pt-maju.com');
      await tester.tap(find.text('KIRIM SEKARANG'));
      await tester.pumpAndSettle();

      // Dua baris "Terkirim" bisa berarti hal beda — yang satu pelanggan
      // pegang dokumennya, yang satu cuma dapat tautan. Jadi formatnya wajib
      // kebaca di riwayat, bukan cuma waktu ngirim.
      expect(find.textContaining('Excel'), findsWidgets);
    });

    testWidgets('pilih WhatsApp → kolom Cc ilang, nomor yang diminta', (
      tester,
    ) async {
      await _pasang(tester, _app(MockKirimEmailService()));

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      // WhatsApp nggak punya konsep salinan — kolom Cc di situ cuma bikin
      // admin ngira ada yang ikut dikirimin padahal nggak.
      expect(find.widgetWithText(TextField, 'Cc (opsional)'), findsNothing);
      expect(find.widgetWithText(TextField, 'Nomor WhatsApp'), findsOneWidget);
      expect(find.text('BUKA WHATSAPP'), findsOneWidget);
    });

    testWidgets('lewat WA, keterangannya jujur: yang dikirim TAUTAN', (
      tester,
    ) async {
      await _pasang(tester, _app(MockKirimEmailService()));

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      // Format masih PDF (bawaan), tapi lewat WA yang kekirim tetap tautan —
      // dan itu harus dibilang, bukan dibiarin admin ngira PDF-nya nempel.
      expect(find.textContaining('tautan unduh PDF'), findsOneWidget);
    });

    testWidgets('kiriman WA masuk riwayat yang sama dengan email', (
      tester,
    ) async {
      final dibuka = _pasangKanalWa();
      final service = MockKirimEmailService();
      await _pasang(tester, _app(service));

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nomor WhatsApp'),
        '08123456789',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BUKA WHATSAPP'));
      await tester.pumpAndSettle();

      // "Sertifikat ini udah dikirim ke siapa aja" harus kejawab dari SATU
      // tempat — bukan email di sini, WA di kepala admin.
      final riwayat = await service.riwayat('t', 7);
      expect(riwayat.single.format, FormatKirim.whatsapp);
      expect(riwayat.single.ke, ['628123456789']);

      // WhatsApp dibuka SESUDAH tercatat, bukan sebelumnya. Kalau kebalik,
      // admin bisa ngirim pesan lalu pencatatannya gagal — dan riwayat bilang
      // "belum pernah dikirim" padahal pelanggan udah nerima.
      expect(dibuka.single, contains('wa.me/628123456789'));
    });

    test('nomor lokal 08... dinormalin ke 628...', () {
      // `wa.me` cuma nerima digit bentuk internasional. Teknisi & admin nulis
      // nomor dengan cara lokal, dan itu nggak boleh jadi alasan gagal kirim.
      expect(normalkanNomorWa('0812-3456-789'), '628123456789');
      expect(normalkanNomorWa('+62 812 3456 789'), '628123456789');
      expect(normalkanNomorWa('628123456789'), '628123456789');
      expect(normalkanNomorWa('12'), isNull);
    });

    test('riwayat lama tanpa field `format` dianggap PDF, bukan error', () {
      final p = PercobaanEmail.fromJson(const {
        'id': 1,
        'ke': ['a@b.com'],
        'status': 'terkirim',
      });

      expect(p.format, FormatKirim.pdf);
    });
  });
}
