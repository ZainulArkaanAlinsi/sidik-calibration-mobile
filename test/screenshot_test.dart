@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/models/customer.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/screens/dashboard/dashboard_screen.dart';
import 'package:sidik_calibration/screens/jatuh_tempo/layar_jatuh_tempo.dart';
import 'package:sidik_calibration/screens/pelanggan/pusat_pelanggan_screen.dart';
import 'package:sidik_calibration/services/customer_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/auth/onboarding_screen.dart';
import 'package:sidik_calibration/screens/auth/splash_screen.dart';
import 'package:sidik_calibration/screens/profile/profile_screen.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/screens/dashboard/ringkasan_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/permintaan_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/providers/koreksi_provider.dart';
import 'package:sidik_calibration/models/revisi_sertifikat.dart';
import 'package:sidik_calibration/screens/certificate/revisi_sertifikat_screen.dart';
import 'package:sidik_calibration/screens/certificate/sertifikat_screen.dart';
import 'package:sidik_calibration/screens/koreksi/antrean_koreksi_screen.dart';
import 'package:sidik_calibration/screens/koreksi/detail_koreksi_screen.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/koreksi_service.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/screens/pelacakan/pelacakan_screen.dart';
import 'package:sidik_calibration/screens/permintaan/antrean_permintaan_screen.dart';
import 'package:sidik_calibration/screens/permintaan/detail_permintaan_screen.dart';
import 'package:sidik_calibration/screens/pengesahan/antrean_pengesahan_screen.dart';
import 'package:sidik_calibration/screens/penugasan/penugasan_buat_screen.dart';
import 'package:sidik_calibration/screens/penugasan/penugasan_screen.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/permintaan_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/pengesahan_service.dart';
import 'package:sidik_calibration/services/penugasan_service.dart';
import 'package:sidik_calibration/services/user_service.dart';

import 'support/halaman_lembar.dart';

/// Bikin screenshot layar-layar utama ke `test/screenshots/*.png`.
///
/// Jalanin: `flutter test test/screenshot_test.dart --update-goldens`
///
/// Gunanya: lihat tampilan app **tanpa perlu emulator/HP**. Kalau ragu
/// "desainnya udah kepasang belum?", buka PNG-nya.
Future<void> _muatFont() async {
  // Di widget test, font custom nggak ke-load otomatis — teks bakal kerender
  // jadi kotak-kotak hitam. Jadi Inter-nya dimuat manual dari disk.
  final inter = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    inter.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await inter.load();

  // Font angka (`SidikTheme.gayaAngka`). Tanpa ini angka & serial di golden
  // kerender jadi kotak, jadi perubahan angka tidak pernah tertangkap.
  final mono = FontLoader('IBMPlexMono');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/IBMPlexMono-$b.ttf').readAsBytesSync();
    mono.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await mono.load();

  // Font ikon Material juga nggak ke-load sendiri — tanpa ini semua ikon
  // kerender jadi kotak kosong. Itu bikin screenshot-nya nyaris nggak ada
  // gunanya: separuh bahasa desain kita ikon, dan aturan "status nggak boleh
  // dibedain lewat warna doang" nggak bisa dicek kalau ikonnya kotak semua.
  //
  // Font-nya ikut SDK, bukan repo. Kalau nggak ketemu (versi Flutter beda),
  // screenshot-nya tetap kebikin — cuma ikonnya balik jadi kotak. Nggak worth
  // bikin test-nya merah cuma gara-gara ini.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;

  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;

  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await ikon.load();
}

/// Pump layar + precache logo + settle.
///
/// Logo PT Sidik = `Image.asset`. Di golden test, decode gambar jalan di async
/// queue yang di-pause, jadi kalau nggak di-precache manual di dalam `runAsync`
/// logonya kerender kosong. Precache dulu → `pumpAndSettle` → logo muncul.
/// Aset logo resmi (dulu diekspor `neu.dart`; kini auth memakai badge ikon
/// placeholder, jadi konstanta dipindah ke test yang masih mem-precache-nya).
const String kLogoPtSidik = 'assets/images/logo_pt_sidik.png';

Future<void> _pumpLayar(WidgetTester tester, Widget layar) async {
  await tester.pumpWidget(layar);
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(kLogoPtSidik),
      tester.element(find.byType(MaterialApp)),
    );
  });
  await tester.pumpAndSettle();
}

/// Layar yang langsung me-`watch(authProvider)` (pengesahan, pelacakan,
/// penugasan) memicu `MockAuthService` dengan jedanya 600 ms. `pumpAndSettle`
/// tidak memajukan timer, jadi tanpa ini golden-nya kebikin tapi test-nya
/// gagal di akhir dengan `!timersPending` — persis yang terjadi di run golden
/// pertama ketujuh layar ini.
Future<void> _pumpLayarBerakun(WidgetTester tester, Widget layar) async {
  await _pumpLayar(tester, layar);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Tanggal yang kecetak di golden lembar kerja. Angkanya sendiri nggak penting
/// — yang penting dia TETAP. Kalau diubah, dua golden lembar kerja mesti
/// digenerate ulang.
final _tanggalGolden = DateTime(2026, 8, 9, 10, 30);

Widget _bungkus(
  Widget layar, {
  required Brightness mode,
  // `mock-token-1` = admin, `mock-token-2` = teknisi, `mock-token-5` = super
  // admin (lihat MockAuthService).
  // Dua-duanya dipotret: layar teknisi dan layar admin sekarang beda isi,
  // jadi satu golden aja nutupin separuh app yang berubah.
  String token = 'mock-token-1',
  // Patokan "hari ini" & data tiruan untuk layar jatuh tempo/pelanggan.
  // Diisi HANYA oleh golden paket-lab: golden lain tetap memakai
  // [_tanggalGolden] dan daftar bawaan, jadi tidak ada yang bergeser.
  DateTime? jam,
  List<Equipment>? alat,
  List<Customer>? pelanggan,
  // Revisi/batal sertifikat, koreksi pelanggan, dan perjalanan permintaan
  // (1 Okt). Diisi HANYA oleh golden barunya; yang lain memakai bawaan mock.
  CertificateService? sertifikat,
  PermintaanService? permintaan,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      perhitunganServiceProvider.overrideWithValue(MockPerhitunganService()),
      // Layar detail sesi narik dari sini. Tanpa override-nya, golden-nya cuma
      // kerangka skeleton — providernya nembak API asli dan gagal.
      historyServiceProvider.overrideWithValue(MockHistoryService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      // Jam dipatok, alasannya sama persis kayak locale di bawah: bikin golden
      // deterministik.
      //
      // Lembar kerja ngisi "Calibration Date" dengan tanggal hari ini, dan itu
      // kecetak ke gambarnya. Tanpa patokan ini, dua golden lembar kerja MERAH
      // TIAP GANTI HARI padahal nggak ada yang rusak — dan tes yang merahnya
      // nggak nyambung sama perubahan kode itu lama-lama diabaikan orang,
      // termasuk waktu dia beneran nangkep bug. Kejadian 10 Agt 2026.
      jamProvider.overrideWithValue(() => jam ?? _tanggalGolden),
      if (alat != null)
        equipmentServiceProvider.overrideWithValue(
          MockEquipmentService(awal: alat),
        ),
      if (pelanggan != null)
        customerServiceProvider.overrideWithValue(
          MockCustomerService(awal: pelanggan),
        ),
      // Layar paket 29 Sep (pengesahan, pelacakan, penugasan). Tanpa mock-nya
      // ketiganya menembak API asli di golden dan cuma memotret pesan galat.
      pengesahanServiceProvider.overrideWithValue(MockPengesahanService()),
      pelacakanServiceProvider.overrideWithValue(MockPelacakanService()),
      penugasanServiceProvider.overrideWithValue(MockPenugasanService()),
      userServiceProvider.overrideWithValue(MockUserService()),
      // Permintaan pelanggan (1 Okt): antrean & detail. Izin tiruan supaya
      // layar detail tidak menembak `/me/permissions` asli di golden.
      permintaanServiceProvider.overrideWithValue(
        permintaan ?? MockPermintaanService(),
      ),
      izinServiceProvider.overrideWithValue(MockIzinService()),
      koreksiServiceProvider.overrideWithValue(MockKoreksiService()),
      certificateServiceProvider.overrideWithValue(
        sertifikat ?? MockCertificateService(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: mode == Brightness.light ? AppTheme.light : AppTheme.dark,
      // Locale dikunci ke ID biar golden deterministik (nggak ketarik locale
      // mesin CI/dev yang beda-beda).
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: layar,
    ),
  );
}

void main() {
  setUpAll(_muatFont);

  /// Ukuran HP beneran (bukan 800x600 bawaan test), biar layoutnya wajar —
  /// dan biar overflow yang cuma muncul di lebar HP ketahuan di sini.
  void pasangUkuranHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('login — terang', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const LoginScreen(), mode: Brightness.light),
    );

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('screenshots/login-terang.png'),
    );
  });

  testWidgets('login — gelap', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const LoginScreen(), mode: Brightness.dark),
    );

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('screenshots/login-gelap.png'),
    );
  });

  testWidgets('dashboard', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const MainShell(), mode: Brightness.light),
    );

    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('screenshots/dashboard.png'),
    );
  });

  /// Dashboard TEKNISI — beda isi dari dashboard admin: panel 3D di atas,
  /// tanpa grafik tren. Golden-nya kepisah karena kalau cuma admin yang
  /// dipotret, seluruh layar yang dilihat teknisi tiap hari nggak kejaga.
  testWidgets('dashboard teknisi', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(
        const MainShell(),
        mode: Brightness.light,
        token: 'mock-token-2',
      ),
    );

    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('screenshots/dashboard-teknisi.png'),
    );
  });

  /// Onboarding karyawan baru — halaman pertama.
  testWidgets('onboarding', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(
        OnboardingScreen(
          user: User(
            id: 2,
            nama: 'Andi Pratama',
            email: 'teknisi@pt-sidik.com',
            employeeId: 'SDK-0002',
            role: UserRole.teknisi,
            status: UserStatus.aktif,
            department: 'Kalibrasi',
            organizationId: 1,
          ),
        ),
        mode: Brightness.light,
      ),
    );

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('screenshots/onboarding.png'),
    );
  });

  testWidgets('profil teknisi', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(
        const ProfileScreen(),
        mode: Brightness.light,
        token: 'mock-token-2',
      ),
    );

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('screenshots/profil-teknisi.png'),
    );
  });

  testWidgets('profil', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const ProfileScreen(), mode: Brightness.light),
    );

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('screenshots/profil.png'),
    );
  });

  testWidgets('splash', (tester) async {
    pasangUkuranHp(tester);
    await tester.pumpWidget(
      _bungkus(const SplashScreen(), mode: Brightness.dark),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(kLogoPtSidik),
        tester.element(find.byType(MaterialApp)),
      );
    });
    // Bukan pumpAndSettle: splash punya spinner yang muter terus. Pump durasi
    // tetap biar frame golden-nya deterministik.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('screenshots/splash.png'),
    );
  });

  /// Lembar kerja Chlorin Meter (`SIDIK-FM-CAL-0531_Rev.2`) — alat ke-3.
  ///
  /// Ada di sini bukan buat gaya-gayaan: bentuk lembarnya datang dari backend
  /// dan gampang "hijau di test tapi jelek di layar". PNG-nya bisa diadu sama
  /// PDF kertasnya tanpa perlu nyalain HP.
  testWidgets('lembar kerja chlorine', (tester) async {
    // Lebih tinggi dari HP beneran: yang mau dilihat justru bagian tabel
    // hasilnya, bukan cuma kepala formulir. Sejak lembarnya dua halaman
    // (26 Sep 2026) tabelnya di halaman 2, jadi halaman itu yang dipotret.
    tester.view.physicalSize = const Size(1200, 7600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Bukan `_pumpLayar`: `MockAuthService.me()` jeda 600 ms lewat
    // `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame — jadi
    // `pumpAndSettle` balik duluan dan timernya nyangkut. Sama persis kayak
    // `_muat()` di `lembar_kerja_test.dart`.
    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'chlorine_meter'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Halaman PENGUKURAN — tabel yang dijaga gambar ini ada di sana.
    await keHalamanAkhir(tester);

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-kerja-chlorine.png'),
    );
  });

  /// Lembar kerja Spectrophotometer (`SIDIK-IK-CAL-0508_Rev.4`) — alat ke-6.
  ///
  /// Ini lembar yang bentuknya paling jauh dari lima alat sebelumnya: TIGA
  /// tabel dalam satu bagian, kolom "No.", kepala `Std Value (λ1)` /
  /// `Measurement Result` / `X1..X3`, kolom `λ (nm)` yang kegabung di blok %T,
  /// dan tiap nilai standar %T menaungi DUA baris X1..X3.
  ///
  /// PNG-nya ada supaya bisa diadu langsung sama lembar cetaknya tanpa nyalain
  /// HP — versi pertama layar ini "hijau di test" tapi susunannya nggak sama
  /// sekali kayak kertas yang dipegang teknisi.
  testWidgets('lembar kerja spectrophotometer', (tester) async {
    tester.view.physicalSize = const Size(1200, 11000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'spectrophotometer'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Halaman PENGUKURAN — tabel yang dijaga gambar ini ada di sana.
    await keHalamanAkhir(tester);

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-kerja-spectrophotometer.png'),
    );
  });

  // ## Tiga lembar suhu ber-PASANGAN deret (alat ke-18, 19, 20)
  //
  // Ketiganya beda bentuk dari tujuh belas lembar sebelumnya, dan bedanya persis
  // jenis yang paling sulit dinilai dari kode: **dua tabel pembacaan per
  // besaran** — satu deret standar, satu deret UUT — yang di kertas berdiri
  // bersebelahan dan di layar bertumpuk. Yang gampang salah bukan angkanya
  // melainkan susunannya, dan itu cuma kelihatan kalau digambar.
  //
  // Tingginya diukur, bukan ditebak: rentang gulir tiap lembar pada lebar logis
  // 600 masing-masing 6072, 6696, dan 8305 dp. Angka di bawah dibulatkan ke
  // atas dari situ supaya lembarnya kepotret UTUH sampai blok penutup — beda
  // dari golden Chlorine & Spectro yang jatahnya lebih pendek dari isinya.

  /// Lembar kerja Thermocouple (`SIDIK-IK-CAL-0529_Rev.2`) — alat ke-18.
  ///
  /// Yang dijaga di sini susunan dua deretnya: `Pembacaan Standard` (detik ke-0,
  /// 20, 40, 60, 80) dan `Pembacaan UUT` (detik ke-10, 30, 50, 70, 90) sebagai
  /// DUA tabel terpisah, plus blok `No. Termokopel` yang cuma menempel di tabel
  /// standar. Sempat kejadian keduanya berbagi satu controller — layarnya tetap
  /// tergambar rapi dan angka UUT muncul juga di deret standar, tanpa satu pun
  /// error.
  testWidgets('lembar kerja thermocouple', (tester) async {
    tester.view.physicalSize = const Size(1200, 12200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'thermocouple'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Halaman PENGUKURAN — tabel yang dijaga gambar ini ada di sana.
    await keHalamanAkhir(tester);

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-kerja-thermocouple.png'),
    );
  });

  /// Lembar kerja Termometer Gelas (`SIDIK-IK-CAL-0527_Rev.1`) — alat ke-19.
  ///
  /// Bedanya dari Thermocouple: oilbath & tipe pencelupan menggantikan dryblock,
  /// dan ada blok **Uji Titik Es** (`Ice Point X1..X3`) yang harus tergambar
  /// sebagai kotak isian — bukan catatan. Rentangnya masuk budget
  /// ketidakpastian, jadi blok yang hilang dari layar berarti komponen yang
  /// diam-diam nol.
  testWidgets('lembar kerja termometer gelas', (tester) async {
    tester.view.physicalSize = const Size(1200, 13400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'thermometer_glass'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Halaman PENGUKURAN — tabel yang dijaga gambar ini ada di sana.
    await keHalamanAkhir(tester);

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-kerja-termometer-gelas.png'),
    );
  });

  /// Lembar kerja Thermohygrometer (`SIDIK-IK-CAL-0518_Rev.4`) — alat ke-20.
  ///
  /// Lembar terpanjang dari ketiganya, dan satu-satunya yang punya **DUA
  /// besaran**: suhu (°C) dan kelembapan (%RH), masing-masing sepasang tabel —
  /// jadi EMPAT tabel dalam satu lembar. Set point `50` muncul di dua blok
  /// sekaligus (50 °C dan 50 %RH); waktu barisnya dikunci ke angka saja, dua
  /// baris itu berbagi satu state dan lembarnya menyusut jadi sembilan baris
  /// dengan satuan yang salah diwarisi. Itu yang dijaga gambar ini.
  testWidgets('lembar kerja thermohygro', (tester) async {
    tester.view.physicalSize = const Size(1200, 16700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'thermohygro'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Halaman PENGUKURAN — tabel yang dijaga gambar ini ada di sana.
    await keHalamanAkhir(tester);

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-kerja-thermohygro.png'),
    );
  });

  /// Calibration Result Details — layar yang dipakai admin sebelum nerbitin.
  ///
  /// Ada di sini karena bentuknya yang paling gampang berantakan: 24 titik
  /// dalam tiga kelompok, masing-masing punya ringkasan + rantai hitung
  /// berikut rumus Excel-nya. PNG-nya bikin "rapi apa nggak" bisa dinilai
  /// tanpa nyalain HP.
  testWidgets('detail sesi spectrophotometer', (tester) async {
    tester.view.physicalSize = const Size(1200, 9000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const CalibrationDetailScreen(calibrationId: 1),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CalibrationDetailScreen),
      matchesGoldenFile('screenshots/detail-sesi.png'),
    );
  });

  /// Lembar PERHITUNGAN — layar utama admin.
  ///
  /// Ada di sini karena ini layar yang paling lama dipelototin admin, dan
  /// paling gampang "hijau di test tapi kelihatan dari aplikasi lain": isinya
  /// campuran tabel, blok kondisi, dan bilah aksi yang tiap bagiannya ditulis
  /// terpisah. PNG-nya bikin ketidakkonsistenan langsung kelihatan.
  testWidgets('perhitungan admin', (tester) async {
    tester.view.physicalSize = const Size(1200, 5200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const PerhitunganScreen(calibrationId: 1),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PerhitunganScreen),
      matchesGoldenFile('screenshots/perhitungan-admin.png'),
    );
  });

  /// Panel Ringkasan di lebar desktop.
  ///
  /// Ada di sini gara-gara satu bug yang cuma kelihatan di lebar segini: label
  /// "Sebaran status sesi" dikunci `SizedBox(width: 140)` TANPA jarak ke batang
  /// progresnya, jadi label yang lebih panjang dari itu ("Menunggu approval")
  /// nempel langsung ke bar dan kebaca kayak satu gumpalan. Nol test yang
  /// gagal, nol error — cuma kelihatan kalau dilihat.
  testWidgets('ringkasan desktop', (tester) async {
    tester.view.physicalSize = const Size(2400, 1700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(const RingkasanScreen(), mode: Brightness.light),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RingkasanScreen),
      matchesGoldenFile('screenshots/ringkasan-desktop.png'),
    );
  });

  /// Lembar Chlorine DENGAN alat kepilih.
  ///
  /// Yang dicek: blok Identitas Alat keisi dari master — khususnya
  /// "2. Range/Resolution", yang di sheet PERHITUNGAN dipisah jadi Rentang
  /// Ukur / Kapasitas Max. / Resolusi Alat.
  testWidgets('lembar chlorine — alat kepilih', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'chlorine_meter'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih alat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chlorine Meter Hanna · 905320134111').last);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-chlorine-alat-kepilih.png'),
    );
  });

  // ── Paket 29 Sep 2026: menu per peran & layar pengendalian ──────────────
  //
  // Tujuh layar ini lahir tanpa satu golden pun, jadi tampilannya belum pernah
  // dilihat siapa pun sebelum dirilis. Yang pertama kali memotretnya justru
  // menemukan baris meta di antrean pengesahan meluap 46 px di lebar HP.

  Future<void> potretMenu(
    WidgetTester tester, {
    required String token,
    required String berkas,
    Brightness mode = Brightness.light,
  }) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const MainShell(), mode: mode, token: token),
    );
    bukaMenuUtama();
    await tester.pumpAndSettle();
    await expectLater(find.byType(MainShell), matchesGoldenFile(berkas));
  }

  testWidgets('menu super admin', (tester) async {
    await potretMenu(
      tester,
      token: 'mock-token-5',
      berkas: 'screenshots/menu-super-admin.png',
    );
  });

  /// Tema gelap: baris menu aktif pernah 1,9:1 di sini (biru di atas
  /// biru-tipis). Dipotret supaya perbaikannya kelihatan dan terjaga.
  testWidgets('menu super admin — gelap', (tester) async {
    await potretMenu(
      tester,
      token: 'mock-token-5',
      berkas: 'screenshots/menu-super-admin-gelap.png',
      mode: Brightness.dark,
    );
  });

  testWidgets('menu teknisi', (tester) async {
    await potretMenu(
      tester,
      token: 'mock-token-2',
      berkas: 'screenshots/menu-teknisi.png',
    );
  });

  /// Antrean permintaan pelanggan — tab Baru: lencana status, lama menunggu
  /// (dipatok ke 1 Okt 2026 supaya "Menunggu 3 hari" tidak bergeser), dan
  /// deretan chip status.
  testWidgets('permintaan pelanggan antrean', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const AntreanPermintaanScreen(),
        mode: Brightness.light,
        jam: DateTime(2026, 10, 1, 10),
      ),
    );
    await expectLater(
      find.byType(AntreanPermintaanScreen),
      matchesGoldenFile('screenshots/permintaan-antrean.png'),
    );
  });

  /// Detail permintaan: satu alat terdaftar + satu alat baru yang harus
  /// dilengkapi admin (kategori & nomor seri), dengan bilah Tolak/Terima.
  testWidgets('permintaan pelanggan detail', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const DetailPermintaanScreen(permintaanId: 12),
        mode: Brightness.light,
        jam: DateTime(2026, 10, 1, 10),
      ),
    );
    await expectLater(
      find.byType(DetailPermintaanScreen),
      matchesGoldenFile('screenshots/permintaan-detail.png'),
    );
  });

  testWidgets('pengesahan super admin', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const AntreanPengesahanScreen(),
        mode: Brightness.light,
        token: 'mock-token-5',
      ),
    );
    await expectLater(
      find.byType(AntreanPengesahanScreen),
      matchesGoldenFile('screenshots/pengesahan-super-admin.png'),
    );
  });

  testWidgets('pelacakan paket', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(const PelacakanScreen(), mode: Brightness.light),
    );
    await expectLater(
      find.byType(PelacakanScreen),
      matchesGoldenFile('screenshots/pelacakan-paket.png'),
    );
  });

  testWidgets('penugasan admin', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(const PenugasanScreen(), mode: Brightness.light),
    );
    await expectLater(
      find.byType(PenugasanScreen),
      matchesGoldenFile('screenshots/penugasan-admin.png'),
    );
  });

  /// Detail tugas dari sisi teknisi — tempat tombol −/+ lapor progres.
  testWidgets('penugasan detail teknisi', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(
        const PenugasanScreen(),
        mode: Brightness.light,
        token: 'mock-token-2',
      ),
    );
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DetailPenugasanScreen),
      matchesGoldenFile('screenshots/penugasan-detail-teknisi.png'),
    );
  });

  testWidgets('penugasan buat', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(const PenugasanBuatScreen(), mode: Brightness.light),
    );
    await expectLater(
      find.byType(PenugasanBuatScreen),
      matchesGoldenFile('screenshots/penugasan-buat.png'),
    );
  });

  testWidgets('kelola lab', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const KelolaLabScreen(), mode: Brightness.light),
    );
    await expectLater(
      find.byType(KelolaLabScreen),
      matchesGoldenFile('screenshots/kelola-lab.png'),
    );
  });

  // ── Sisa paket lab (30 Sep 2026): jatuh tempo, jadwal, pusat pelanggan,
  // beranda super admin, dan tombol "siap diambil" di detail paket. ────────
  //
  // Jam dipatok ke 26 Sep 2026 (tanggal artboard) supaya "lewat 12 hari" tidak
  // berubah tiap hari — golden lain tetap memakai [_tanggalGolden].

  final hariGoldenLab = DateTime(2026, 9, 26);

  Equipment alatLab(
    int id,
    String nama,
    String sn,
    String pelanggan,
    int pelangganId,
    DateTime tempo, {
    EquipmentStatus status = EquipmentStatus.aktif,
  }) => Equipment(
    id: id,
    namaAlat: nama,
    serialNumber: sn,
    kategori: 'suhu',
    status: status,
    pelangganId: pelangganId,
    pelangganNama: pelanggan,
    tanggalJatuhTempo: tempo,
  );

  const tirta = 'PT Tirta Mandiri Laboratorium';
  final alatGoldenLab = [
    alatLab(
      1,
      'Timbangan Elektronik Ohaus PX224',
      'C3349',
      'PT Bumi Farma Sejahtera',
      3,
      DateTime(2026, 9, 14),
      status: EquipmentStatus.overdue,
    ),
    alatLab(
      2,
      'Thermohygrometer Lutron HT-3007',
      'L-3007-118',
      tirta,
      1,
      DateTime(2026, 9, 18),
      status: EquipmentStatus.overdue,
    ),
    alatLab(
      3,
      'Viscometer Brookfield DV2T',
      '8820415',
      'CV Anugerah Kimia Utama',
      2,
      DateTime(2026, 9, 21),
      status: EquipmentStatus.overdue,
    ),
    alatLab(
      4,
      'Micrometer Mitutoyo 293-240',
      '61203847',
      'RS Harapan Medika',
      4,
      DateTime(2026, 9, 24),
      status: EquipmentStatus.overdue,
    ),
    alatLab(
      5,
      'pH Meter Hanna HI2211',
      'HI2211-0419',
      tirta,
      1,
      DateTime(2026, 10, 14),
    ),
    alatLab(
      6,
      'Oven Memmert UN55',
      'B415.0923',
      'PT Sinar Pangan Nusantara',
      5,
      DateTime(2026, 11, 20),
    ),
  ];
  const pelangganGoldenLab = [
    Customer(
      id: 1,
      nama: tirta,
      alamat: 'Jl. Industri Selatan 4 Blok GG-2, Cikarang',
      contactPerson: 'Budi Santoso',
      telepon: '0812 1156 4470',
      email: 'budi@tirtamandiri.example',
      jumlahAlat: 12,
    ),
    Customer(
      id: 2,
      nama: 'CV Anugerah Kimia Utama',
      alamat: 'Jl. Soekarno-Hatta 219, Kota Bandung',
      contactPerson: 'Maya Ratnasari',
      telepon: '022 5550 1122',
      email: 'maya@anugerah.example',
      jumlahAlat: 8,
    ),
  ];

  testWidgets('daftar jatuh tempo', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const DaftarJatuhTempoScreen(),
        mode: Brightness.light,
        jam: hariGoldenLab,
        alat: alatGoldenLab,
      ),
    );
    await expectLater(
      find.byType(DaftarJatuhTempoScreen),
      matchesGoldenFile('screenshots/daftar-jatuh-tempo.png'),
    );
  });

  testWidgets('jadwal kalibrasi ulang', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const JadwalKalibrasiScreen(),
        mode: Brightness.light,
        jam: hariGoldenLab,
        alat: alatGoldenLab,
      ),
    );
    await expectLater(
      find.byType(JadwalKalibrasiScreen),
      matchesGoldenFile('screenshots/jadwal-kalibrasi-ulang.png'),
    );
  });

  testWidgets('pusat pelanggan', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const PusatPelangganScreen(),
        mode: Brightness.light,
        token: 'mock-token-5',
        jam: hariGoldenLab,
        alat: alatGoldenLab,
        pelanggan: pelangganGoldenLab,
      ),
    );
    await expectLater(
      find.byType(PusatPelangganScreen),
      matchesGoldenFile('screenshots/pusat-pelanggan.png'),
    );
  });

  testWidgets('detail pelanggan', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        DetailPelangganScreen(pelanggan: pelangganGoldenLab.first),
        mode: Brightness.light,
        token: 'mock-token-5',
        jam: hariGoldenLab,
        alat: alatGoldenLab,
        pelanggan: pelangganGoldenLab,
      ),
    );
    await expectLater(
      find.byType(DetailPelangganScreen),
      matchesGoldenFile('screenshots/detail-pelanggan.png'),
    );
  });

  testWidgets('beranda super admin', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const DashboardScreen(),
        mode: Brightness.light,
        token: 'mock-token-5',
        jam: hariGoldenLab,
        alat: alatGoldenLab,
      ),
    );
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('screenshots/beranda-super-admin.png'),
    );
  });

  /// Detail paket dengan alat yang baru bersertifikat: dua tombol fisik
  /// ("siap diambil" lalu "diserahkan") berdampingan.
  testWidgets('pelacakan detail siap diambil', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(const DetailPaketScreen(paketId: 34), mode: Brightness.light),
    );
    await expectLater(
      find.byType(DetailPaketScreen),
      matchesGoldenFile('screenshots/pelacakan-detail-siap-diambil.png'),
    );
  });

  // ── Revisi & pembatalan sertifikat, koreksi pelanggan, perjalanan alat ────
  // (1 Okt 2026). Semua memakai mock sintetis; token 1 = admin.

  /// Sertifikat yang sudah digantikan: lencana Digantikan + tautan ke revisi
  /// yang masih dirender.
  testWidgets('sertifikat digantikan', (tester) async {
    pasangUkuranHp(tester);
    final dasar = await MockCertificateService().detail('t', 1);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const SertifikatScreen(certificateId: 1),
        mode: Brightness.light,
        sertifikat: MockCertificateService(
          khusus: {
            1: dasar.salin(
              statusDokumenKode: 'digantikan',
              digantikanOleh: const RujukanSertifikat(
                id: 900,
                nomor: '012-CAL-524-R1',
                status: 'menunggu_generate',
              ),
            ),
          },
        ),
      ),
    );
    await expectLater(
      find.byType(SertifikatScreen),
      matchesGoldenFile('screenshots/sertifikat-digantikan.png'),
    );
  });

  /// Sertifikat dibatalkan: tanggal, oleh, alasan internal, dan catatan untuk
  /// pelanggan; bilah unduh tetap ada (arsip lab).
  testWidgets('sertifikat dibatalkan', (tester) async {
    pasangUkuranHp(tester);
    final dasar = await MockCertificateService().detail('t', 1);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const SertifikatScreen(certificateId: 1),
        mode: Brightness.light,
        sertifikat: MockCertificateService(
          khusus: {
            1: dasar.salin(
              status: 'dibatalkan',
              statusDokumenKode: 'dibatalkan',
              dibatalkanPada: DateTime.utc(2026, 10, 1, 5),
              dibatalkanOleh: 'Hendra Wijaya',
              alasanPembatalan: 'Data alat keliru saat input.',
              catatanPelanggan: 'Mohon abaikan sertifikat ini.',
            ),
          },
        ),
      ),
    );
    await expectLater(
      find.byType(SertifikatScreen),
      matchesGoldenFile('screenshots/sertifikat-dibatalkan.png'),
    );
  });

  /// Formulir revisi: delapan isian dari `data_cetak`, alasan & catatan.
  testWidgets('sertifikat formulir revisi', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dasar = await MockCertificateService(bolehAksi: true).detail('t', 1);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        RevisiSertifikatScreen(sertifikat: dasar),
        mode: Brightness.light,
      ),
    );
    await expectLater(
      find.byType(RevisiSertifikatScreen),
      matchesGoldenFile('screenshots/sertifikat-revisi-formulir.png'),
    );
  });

  /// Dialog batal: gaya merusak + peringatan jadwal dikosongkan.
  testWidgets('sertifikat dialog batal', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const SertifikatScreen(certificateId: 1),
        mode: Brightness.light,
        sertifikat: MockCertificateService(
          bolehAksi: true,
          dampak: const DampakPembatalan(jadwalDikosongkan: true),
        ),
      ),
    );
    final tombol = find.byKey(const ValueKey('tombol-batal-sertifikat'));
    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('dialog-batal-sertifikat')),
      matchesGoldenFile('screenshots/sertifikat-dialog-batal.png'),
    );
  });

  /// Antrean koreksi, tab Menunggu: jenis alat & sertifikat, hitungan.
  testWidgets('koreksi pelanggan antrean', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayarBerakun(
      tester,
      _bungkus(const AntreanKoreksiScreen(), mode: Brightness.light),
    );
    await expectLater(
      find.byType(AntreanKoreksiScreen),
      matchesGoldenFile('screenshots/koreksi-antrean.png'),
    );
  });

  /// Detail koreksi alat: lama → baru, catatan, foto, Tolak/Terima.
  testWidgets('koreksi pelanggan detail', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const DetailKoreksiScreen(koreksiId: 7),
        mode: Brightness.light,
      ),
    );
    await expectLater(
      find.byType(DetailKoreksiScreen),
      matchesGoldenFile('screenshots/koreksi-detail.png'),
    );
  });

  /// Permintaan diantar sendiri: tahap, resi, progres, foto pelat nama, dan
  /// tombol Tandai alat tiba.
  testWidgets('permintaan pelanggan detail perjalanan', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const DetailPermintaanScreen(permintaanId: 14),
        mode: Brightness.light,
        jam: DateTime(2026, 10, 1, 10),
        permintaan: MockPermintaanService(
          awal: MockPermintaanService.contohPerjalanan,
        ),
      ),
    );
    await expectLater(
      find.byType(DetailPermintaanScreen),
      matchesGoldenFile('screenshots/permintaan-detail-perjalanan.png'),
    );
  });

  /// Permintaan diambil lab yang sudah dijadwalkan.
  testWidgets('permintaan pelanggan detail jadwal', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpLayarBerakun(
      tester,
      _bungkus(
        const DetailPermintaanScreen(permintaanId: 16),
        mode: Brightness.light,
        jam: DateTime(2026, 10, 1, 10),
        permintaan: MockPermintaanService(
          awal: MockPermintaanService.contohPerjalanan,
        ),
      ),
    );
    await expectLater(
      find.byType(DetailPermintaanScreen),
      matchesGoldenFile('screenshots/permintaan-detail-jadwal.png'),
    );
  });
}
