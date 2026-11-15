import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/config/lab_profile.dart';
import 'package:sidik_calibration/core/motion/gerak_bersama.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/auth/forgot_password_screen.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/auth/widgets/kerangka_masuk.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';

import 'support/uji_biru_awan.dart';

/// Layar masuk dan lupa sandi Biru Awan (L5, artboard E0). Tes lama
/// (`auth_test.dart`, `forgot_password_test.dart`) menjaga alur dan teks; berkas
/// ini menjaga yang baru: kurangi gerak, huruf 1,3 pada lebar 320, label
/// pembaca layar, keadaan galat (pesan dari provider tampil apa adanya), dan
/// tombol yang mati selama memuat.

/// Auth tiruan yang jawabannya bisa diatur tes dan menghitung panggilan.
class _AuthPalsu extends MockAuthService {
  _AuthPalsu() : super(jeda: Duration.zero);

  Future<AuthSession> Function()? tanggapiLogin;
  Future<void> Function()? tanggapiReset;
  int jumlahLogin = 0;
  int jumlahReset = 0;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) {
    jumlahLogin++;
    final f = tanggapiLogin;
    return f == null
        ? super.login(identifier: identifier, password: password)
        : f();
  }

  @override
  Future<void> requestPasswordReset(String email) {
    jumlahReset++;
    final f = tanggapiReset;
    return f == null ? super.requestPasswordReset(email) : f();
  }
}

Widget _aplikasi(
  Widget layar,
  _AuthPalsu auth, {
  bool gelap = false,
  double skala = 1.0,
  bool kurangiGerak = false,
}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
    authServiceProvider.overrideWithValue(auth),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) {
      var anak = child!;
      if (kurangiGerak) {
        anak = MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: anak,
        );
      }
      return MediaQuery.withClampedTextScaling(
        minScaleFactor: skala,
        maxScaleFactor: skala,
        child: anak,
      );
    },
    home: layar,
  ),
);

/// Pasang layar, biarkan status auth awal (cek token) selesai, lalu tenang.
Future<void> _pasang(
  WidgetTester tester,
  Widget layar,
  _AuthPalsu auth, {
  bool gelap = false,
  double skala = 1.0,
  bool kurangiGerak = false,
}) async {
  await tester.pumpWidget(
    _aplikasi(
      layar,
      auth,
      gelap: gelap,
      skala: skala,
      kurangiGerak: kurangiGerak,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _isiLogin(WidgetTester tester, String id, String sandi) async {
  await tester.enterText(find.byType(TextField).first, id);
  await tester.enterText(find.byType(TextField).last, sandi);
}

Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

Finder get _tombolMasuk => find.widgetWithText(TombolSidik, 'MASUK');

/// Tombol Material di dalam [TombolSidik] berlabel [label].
Finder _tombolMaterial(String label) => find.descendant(
  of: find.widgetWithText(TombolSidik, label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

bool _aktif(WidgetTester tester, Finder tombol) =>
    tester.widget<ButtonStyleButton>(tombol).onPressed != null;

Future<AuthSession> _sesi() => MockAuthService(
  jeda: Duration.zero,
).login(identifier: 'SDK-0002', password: 'rahasia123');

void main() {
  setUpAll(muatFontUji);

  group('login: kurangi gerak', () {
    testWidgets('tanpa kurangi gerak isi masuk berurutan (kontrol)', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(_aplikasi(const LoginScreen(), _AuthPalsu()));
      await tester.pump();

      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'hero dan kartu seharusnya sedang masuk',
      );
      final kartu = find.descendant(
        of: find.byType(MasukBerurutan).at(1),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(kartu.first).opacity.value, 0.0);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(kartu.first).opacity.value, 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('kurangi gerak: tampil utuh sejak bingkai pertama', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(
        _aplikasi(const LoginScreen(), _AuthPalsu(), kurangiGerak: true),
      );
      await tester.pump();

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(MasukBerurutan), findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final pudar = find.descendant(
          of: find.byType(MasukBerurutan).at(i),
          matching: find.byType(FadeTransition),
        );
        expect(
          tester.widget<FadeTransition>(pudar.first).opacity.value,
          1.0,
          reason: 'bagian $i belum utuh',
        );
      }
    });

    testWidgets('kurangi gerak + memuat: pumpAndSettle tetap selesai', (
      tester,
    ) async {
      layarUji(tester);
      final auth = _AuthPalsu();
      final c = Completer<AuthSession>();
      auth.tanggapiLogin = () => c.future;
      await _pasang(tester, const LoginScreen(), auth, kurangiGerak: true);

      await _isiLogin(tester, 'SDK-0002', 'rahasia123');
      await _ketuk(tester, _tombolMasuk);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Pemutar diam (busur tetap): tidak ada bingkai yang terus diminta.
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      // Dari memuat kembali ke biasa: peralihan warna tombol juga seketika.
      c.completeError(const AuthException('Server menolak.'));
      await tester.pump(); // hasil Future masuk ke provider
      await tester.pump(); // layar membangun ulang
      expect(_aktif(tester, _tombolMaterial('MASUK')), isTrue);
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'peralihan tombol sibuk ke aktif masih beranimasi',
      );
    });
  });

  group('skala huruf 1,3 pada lebar 320', () {
    for (final gelap in [false, true]) {
      final tema = gelap ? 'gelap' : 'terang';

      testWidgets('login: biasa, kolom galat, dan galat server ($tema)', (
        tester,
      ) async {
        layarUji(tester, lebar: 320, tinggi: 568);
        final auth = _AuthPalsu();
        await _pasang(
          tester,
          const LoginScreen(),
          auth,
          gelap: gelap,
          skala: 1.3,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'login biasa ($tema) meluap',
        );

        // Kolom kosong: dua kalimat galat di bawah isian.
        await _ketuk(tester, _tombolMasuk);
        await tester.pumpAndSettle();
        expect(find.text('ID pegawai atau email wajib diisi.'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'login dengan galat kolom ($tema) meluap',
        );

        // Galat server dengan kalimat panjang.
        auth.tanggapiLogin = () async => throw const AuthException(
          'Akun kamu belum disetujui admin. Tunggu konfirmasi dulu ya, '
          'lalu coba masuk lagi dengan ID pegawai yang sama.',
        );
        await _isiLogin(tester, 'SDK-0004', 'rahasia123');
        await _ketuk(tester, _tombolMasuk);
        await tester.pumpAndSettle();
        expect(find.byType(PesanGalatMasuk), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'login dengan galat server ($tema) meluap',
        );
      });

      testWidgets('lupa sandi: form, galat, dan panel sukses ($tema)', (
        tester,
      ) async {
        layarUji(tester, lebar: 320, tinggi: 568);
        final auth = _AuthPalsu();
        await _pasang(
          tester,
          const ForgotPasswordScreen(),
          auth,
          gelap: gelap,
          skala: 1.3,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'lupa sandi ($tema) meluap',
        );

        await tester.enterText(find.byType(TextField), 'bukan.siapa@pt.com');
        await _ketuk(tester, find.text('KIRIM LINK RESET'));
        await tester.pumpAndSettle();
        expect(find.text('Email ini nggak terdaftar.'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'lupa sandi dengan galat ($tema) meluap',
        );

        await tester.enterText(find.byType(TextField), 'admin@pt-sidik.com');
        await _ketuk(tester, find.text('KIRIM LINK RESET'));
        await tester.pumpAndSettle();
        expect(find.text('Link reset terkirim'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'panel sukses ($tema) meluap',
        );
      });
    }
  });

  group('login: tata letak', () {
    testWidgets('artboard 390 x 844: hero 330, kartu menumpang 36, tombol 56', (
      tester,
    ) async {
      layarUji(tester, lebar: 390, tinggi: 844);
      await _pasang(tester, const LoginScreen(), _AuthPalsu());

      final hero = tester.getRect(find.byKey(kunciHeroMasuk));
      expect(hero.top, 0);
      expect(hero.width, 390);
      expect(hero.height, closeTo(330, 0.5));
      final kartu = tester.getRect(find.byKey(kunciKartuMasuk));
      expect(kartu.top, closeTo(hero.bottom - 36, 0.5));
      expect(kartu.left, 16);
      expect(kartu.right, 390 - 16);
      final plat = tester.getRect(
        find.descendant(
          of: find.byKey(kunciHeroMasuk),
          matching: find.byType(PlatLogo),
        ),
      );
      expect(plat.width, 104);
      expect(plat.height, 104);
      expect(plat.center.dx, closeTo(195, 0.5));
      expect(tester.getSize(_tombolMaterial('MASUK')).height, 56);
      // Kartu masuk di dalam layar: tombol terlihat tanpa menggulir.
      expect(tester.getRect(_tombolMasuk).bottom, lessThan(844));
    });

    // 800 x 600 = permukaan bawaan flutter_test yang dipakai `auth_test.dart`.
    for (final (lebar, tinggi) in [(800.0, 600.0)]) {
      testWidgets('layar pendek ${lebar.toInt()} x ${tinggi.toInt()}: tombol Masuk terlihat dan bisa diketuk tanpa menggulir', (
        tester,
      ) async {
        layarUji(tester, lebar: lebar, tinggi: tinggi);
        final auth = _AuthPalsu();
        await _pasang(tester, const LoginScreen(), auth);
        expect(tester.getRect(_tombolMasuk).bottom, lessThanOrEqualTo(tinggi));
        // Seperti `auth_test.dart`: ketuk langsung, tanpa ensureVisible.
        await tester.tap(find.text('MASUK'));
        await tester.pumpAndSettle();
        expect(find.text('ID pegawai atau email wajib diisi.'), findsOneWidget);
        expect(find.text('Password wajib diisi.'), findsOneWidget);
        expect(auth.jumlahLogin, 0, reason: 'validasi lokal tidak ke server');
      });
    }
  });

  group('login: pembaca layar', () {
    testWidgets('kolom, tombol, dan judul berlabel; tombol sandi berganti', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      await _pasang(tester, const LoginScreen(), _AuthPalsu());

      final kolom = find.byType(TextField);
      final satu = tester.getSemantics(kolom.first);
      expect(satu.label, contains('ID Pegawai / Email'));
      expect(satu.flagsCollection.isTextField, isTrue);
      final dua = tester.getSemantics(kolom.last);
      expect(dua.label, contains('Password'));
      expect(dua.flagsCollection.isObscured, isTrue);

      final masuk = tester.getSemantics(_tombolMaterial('MASUK'));
      expect(masuk.label, contains('MASUK'));
      expect(masuk.flagsCollection.isButton, isTrue);
      expect(masuk.flagsCollection.isEnabled, Tristate.isTrue);

      final lupa = tester.getSemantics(_tombolMaterial('Lupa Password?'));
      expect(lupa.label, contains('Lupa Password?'));
      expect(lupa.flagsCollection.isButton, isTrue);

      // Judul kartu dan nama produk ditandai sebagai kepala bagian.
      final judul = tester.getSemantics(find.text('Masuk ke akun lab'));
      expect(judul.flagsCollection.isHeader, isTrue);
      final merek = tester.getSemantics(find.text(namaMerekSidikLab));
      expect(merek.flagsCollection.isHeader, isTrue);

      // "Tampilkan" membuka sandi, lalu berganti menjadi "Sembunyikan".
      final tampilkan = find.bySemanticsLabel('Tampilkan');
      expect(tampilkan, findsOneWidget);
      expect(tester.widget<TextField>(kolom.last).obscureText, isTrue);
      await tester.tap(tampilkan);
      await tester.pump();
      expect(tester.widget<TextField>(kolom.last).obscureText, isFalse);
      expect(find.bySemanticsLabel('Sembunyikan'), findsOneWidget);
      expect(find.bySemanticsLabel('Tampilkan'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Sembunyikan'));
      await tester.pump();
      expect(tester.widget<TextField>(kolom.last).obscureText, isTrue);

      semantik.dispose();
    });

    testWidgets('tombol sandi menerima ketukan di seluruh area 48 x 48', (
      tester,
    ) async {
      layarUji(tester);
      await _pasang(tester, const LoginScreen(), _AuthPalsu());
      final kolom = find.byType(TextField).last;
      final area = tester.getRect(find.bySemanticsLabel('Tampilkan'));
      expect(area.width, greaterThanOrEqualTo(48));
      expect(area.height, greaterThanOrEqualTo(48));

      // Sudut-sudut area tombol, bukan hanya tulisannya.
      var tampak = false;
      for (final titik in [
        area.topLeft + const Offset(2, 2),
        area.bottomRight - const Offset(2, 2),
      ]) {
        await tester.tapAt(titik);
        await tester.pump();
        tampak = !tampak;
        expect(
          tester.widget<TextField>(kolom).obscureText,
          !tampak,
          reason: 'ketukan di $titik tidak menanggapi',
        );
      }
    });

    for (final gelap in [false, true]) {
      testWidgets('sasaran sentuh >= 48 dan berlabel (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        layarUji(tester);
        final semantik = tester.ensureSemantics();
        await _pasang(tester, const LoginScreen(), _AuthPalsu(), gelap: gelap);
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });

  group('login: keadaan galat', () {
    testWidgets('pesan AuthException dari provider tampil apa adanya', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      final auth = _AuthPalsu()
        ..tanggapiLogin = () async => throw const AuthException(
          'Akun kamu belum disetujui admin. Tunggu konfirmasi dulu ya.',
        );
      await _pasang(tester, const LoginScreen(), auth);
      expect(find.byType(PesanGalatMasuk), findsNothing);

      await _isiLogin(tester, 'SDK-0004', 'rahasia123');
      await _ketuk(tester, _tombolMasuk);
      await tester.pumpAndSettle();

      expect(
        find.text('Akun kamu belum disetujui admin. Tunggu konfirmasi dulu ya.'),
        findsOneWidget,
      );
      expect(find.byType(PesanGalatMasuk), findsOneWidget);
      // Dibaca otomatis pembaca layar begitu muncul.
      final galat = tester.getSemantics(find.byType(PesanGalatMasuk));
      expect(galat.flagsCollection.isLiveRegion, isTrue);
      expect(galat.label, contains('belum disetujui admin'));

      // Yang sudah diketik tetap ada; tombol dan kolom hidup lagi.
      expect(find.text('SDK-0004'), findsOneWidget);
      expect(_aktif(tester, _tombolMaterial('MASUK')), isTrue);
      for (final k in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(k.enabled, isTrue);
      }
      semantik.dispose();
    });

    testWidgets('galat jaringan dan galat lokal dibedakan', (tester) async {
      layarUji(tester);
      final auth = _AuthPalsu()
        ..tanggapiLogin = () async =>
            throw Exception('SocketException: Failed host lookup');
      await _pasang(tester, const LoginScreen(), auth);
      await _isiLogin(tester, 'SDK-0002', 'rahasia123');
      await _ketuk(tester, _tombolMasuk);
      await tester.pumpAndSettle();
      expect(
        find.text('Nggak bisa nyambung ke server. Coba lagi.'),
        findsOneWidget,
      );

      auth.tanggapiLogin = () async => throw StateError('keychain menolak');
      await _ketuk(tester, _tombolMasuk);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Login gagal di perangkat ini:'),
        findsOneWidget,
      );
      expect(find.textContaining('keychain menolak'), findsOneWidget);
      expect(find.textContaining('Nggak bisa nyambung'), findsNothing);
      expect(auth.jumlahLogin, 2);
    });

    testWidgets('mencoba lagi menghapus pesan galat lama', (tester) async {
      layarUji(tester);
      final auth = _AuthPalsu()
        ..tanggapiLogin = () async => throw const AuthException('Salah.');
      await _pasang(tester, const LoginScreen(), auth);
      await _isiLogin(tester, 'SDK-0002', 'ngasal');
      await _ketuk(tester, _tombolMasuk);
      await tester.pumpAndSettle();
      expect(find.text('Salah.'), findsOneWidget);

      final c = Completer<AuthSession>();
      auth.tanggapiLogin = () => c.future;
      await _ketuk(tester, _tombolMasuk);
      await tester.pump();
      expect(find.text('Salah.'), findsNothing, reason: 'galat lama menempel');
      c.complete(_sesi());
      await tester.pumpAndSettle();
    });
  });

  group('login: memuat', () {
    testWidgets('tombol, kolom, dan tautan mati; ketukan kedua diabaikan', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      final auth = _AuthPalsu();
      final c = Completer<AuthSession>();
      auth.tanggapiLogin = () => c.future;
      await _pasang(tester, const LoginScreen(), auth);

      // Sebelum memuat: semuanya hidup (kontrol).
      expect(_aktif(tester, _tombolMaterial('MASUK')), isTrue);
      expect(_aktif(tester, _tombolMaterial('Lupa Password?')), isTrue);

      await _isiLogin(tester, 'SDK-0002', 'rahasia123');
      await _ketuk(tester, _tombolMasuk);
      await tester.pump();
      expect(auth.jumlahLogin, 1);

      // Tombol mati: tidak ada aksi, pemutar tampil, pembaca layar menerima
      // "sedang diproses" dan keadaan mati.
      expect(_aktif(tester, _tombolMaterial('MASUK')), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final mati = tester.getSemantics(
        find.bySemanticsLabel('MASUK, sedang diproses'),
      );
      expect(mati.flagsCollection.isButton, isTrue);
      expect(mati.flagsCollection.isEnabled, Tristate.isFalse);

      // Kolom ketik dan tautan ikut mati.
      for (final k in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(k.enabled, isFalse);
      }
      expect(_aktif(tester, _tombolMaterial('Lupa Password?')), isFalse);

      // Ketukan kedua tidak mengirim ulang.
      await tester.tap(find.text('MASUK'), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Lupa Password?'), warnIfMissed: false);
      await tester.pump();
      expect(auth.jumlahLogin, 1, reason: 'login terkirim dua kali');
      expect(find.byType(ForgotPasswordScreen), findsNothing);

      // Selesai (gagal): semuanya hidup lagi.
      c.completeError(const AuthException('Server menolak.'));
      await tester.pumpAndSettle();
      expect(_aktif(tester, _tombolMaterial('MASUK')), isTrue);
      expect(_aktif(tester, _tombolMaterial('Lupa Password?')), isTrue);
      for (final k in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(k.enabled, isTrue);
      }
      semantik.dispose();
    });
  });

  group('lupa sandi', () {
    Future<void> bukaDariLogin(WidgetTester tester, _AuthPalsu auth) async {
      await _pasang(tester, const LoginScreen(), auth);
      await _ketuk(tester, find.text('Lupa Password?'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    }

    testWidgets('kepala sama dengan login; kembali berlabel dan berfungsi', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      await bukaDariLogin(tester, _AuthPalsu());

      final forgot = find.byType(ForgotPasswordScreen);
      expect(
        find.descendant(of: forgot, matching: find.text(namaMerekSidikLab)),
        findsOneWidget,
      );
      final kembali = find.descendant(
        of: forgot,
        matching: find.byType(TombolBulat),
      );
      expect(kembali, findsOneWidget);
      final s = tester.getSemantics(kembali);
      expect(s.label, 'Kembali');
      expect(s.flagsCollection.isButton, isTrue);
      expect(s.flagsCollection.isEnabled, Tristate.isTrue);
      final judul = tester.getSemantics(
        find.descendant(of: forgot, matching: find.text('Lupa Password')),
      );
      expect(judul.flagsCollection.isHeader, isTrue);
      final kolom = tester.getSemantics(
        find.descendant(of: forgot, matching: find.byType(TextField)),
      );
      expect(kolom.label, contains('Email'));

      await tester.tap(kembali);
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      semantik.dispose();
    });

    testWidgets('memuat: tombol, kolom, kembali, dan tautan mati', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      final auth = _AuthPalsu();
      final c = Completer<void>();
      auth.tanggapiReset = () => c.future;
      await bukaDariLogin(tester, auth);

      final forgot = find.byType(ForgotPasswordScreen);
      await tester.enterText(
        find.descendant(of: forgot, matching: find.byType(TextField)),
        'admin@pt-sidik.com',
      );
      await _ketuk(tester, find.text('KIRIM LINK RESET'));
      await tester.pump();
      expect(auth.jumlahReset, 1);

      expect(_aktif(tester, _tombolMaterial('KIRIM LINK RESET')), isFalse);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('KIRIM LINK RESET, sedang diproses'))
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: forgot, matching: find.byType(TextField)),
            )
            .enabled,
        isFalse,
      );
      expect(_aktif(tester, _tombolMaterial('Balik ke Login')), isFalse);
      final kembali = find.descendant(
        of: forgot,
        matching: find.byType(TombolBulat),
      );
      expect(
        tester.getSemantics(kembali).flagsCollection.isEnabled,
        Tristate.isFalse,
      );

      await tester.tap(find.text('KIRIM LINK RESET'), warnIfMissed: false);
      await tester.pump();
      expect(auth.jumlahReset, 1, reason: 'terkirim dua kali');

      // Gagal dengan pesan server: pesan tampil, tombol hidup lagi.
      c.completeError(const AuthException('Email ini nggak terdaftar.'));
      await tester.pumpAndSettle();
      expect(find.text('Email ini nggak terdaftar.'), findsOneWidget);
      expect(find.byType(PesanGalatMasuk), findsOneWidget);
      expect(_aktif(tester, _tombolMaterial('KIRIM LINK RESET')), isTrue);
      expect(_aktif(tester, _tombolMaterial('Balik ke Login')), isTrue);
      semantik.dispose();
    });

    testWidgets('panel sukses: kata, email, dan tombol kembali ke login', (
      tester,
    ) async {
      layarUji(tester);
      await bukaDariLogin(tester, _AuthPalsu());
      final forgot = find.byType(ForgotPasswordScreen);
      await tester.enterText(
        find.descendant(of: forgot, matching: find.byType(TextField)),
        'admin@pt-sidik.com',
      );
      await _ketuk(tester, find.text('KIRIM LINK RESET'));
      await tester.pumpAndSettle();

      expect(find.text('Link reset terkirim'), findsOneWidget);
      expect(find.textContaining('admin@pt-sidik.com'), findsOneWidget);
      expect(find.text('KIRIM LINK RESET'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.descendant(of: forgot, matching: find.text(namaMerekSidikLab)),
        findsOneWidget,
        reason: 'kepala E0 ikut di panel sukses',
      );
      await _ketuk(tester, find.text('BALIK KE LOGIN'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsNothing);
    });
  });

  group('kepala hero dan kontras', () {
    for (final gelap in [false, true]) {
      final tema = gelap ? 'gelap' : 'terang';

      testWidgets('login: logo PT SIDIK, nama produk, akreditasi ($tema)', (
        tester,
      ) async {
        // Tinggi 1000: panel bantuan dev memanjangkan isi, dan kaki akreditasi
        // yang di luar layar tidak dibangun.
        layarUji(tester, tinggi: 1000);
        await _pasang(tester, const LoginScreen(), _AuthPalsu(), gelap: gelap);

        expect(find.text(namaMerekSidikLab), findsOneWidget);
        expect(
          find.text('Akreditasi KAN ${LabProfile.nomorAkreditasi}, ISO/IEC 17025'),
          findsOneWidget,
        );
        final logo = tester.widget<Image>(
          find.descendant(
            of: find.byType(PlatLogo),
            matching: find.byType(Image),
          ),
        );
        expect(logo.excludeFromSemantics, isTrue, reason: 'logo hiasan');
        expect((logo.image as AssetImage).assetName, LabProfile.logoAsset);
      });

      testWidgets('login: semua teks terbaca >= 4,5:1, juga saat galat ($tema)', (
        tester,
      ) async {
        layarUji(tester, tinggi: 1000);
        final auth = _AuthPalsu()
          ..tanggapiLogin = () async => throw const AuthException('Salah.');
        await _pasang(tester, const LoginScreen(), auth, gelap: gelap);
        expect(
          pelanggaranKontrasTeks(tester, find.byType(LoginScreen)),
          isEmpty,
        );

        await _isiLogin(tester, 'SDK-0002', 'ngasal');
        await _ketuk(tester, _tombolMasuk);
        await tester.pumpAndSettle();
        expect(find.byType(PesanGalatMasuk), findsOneWidget);
        expect(
          pelanggaranKontrasTeks(tester, find.byType(LoginScreen)),
          isEmpty,
        );
      });
    }
  });
}
