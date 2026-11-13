// Gerbang desain Lab, bagian 3: HARNESS RENDER.
//
// Me-render layar kunci (data = Mock*Service bawaan repo) pada tiga ukuran dan
// dua tema, dan GAGAL bila ada luapan (RenderFlex overflow) atau galat lain
// saat build/layout/paint. Tanpa emulator, tanpa perangkat.
//
// Ukuran:
//   hp      392 x 852, huruf 1,0   (HP biasa)
//   sempit  320 x 640, huruf 1,3   (HP murah + huruf diperbesar; batas app)
//   tablet  1280 x 800, huruf 1,0  (landscape)
// Tema: terang dan gelap.
//
// PNG hanya ditulis bila `SIDIK_PNG_DIR` diisi (folder di LUAR repo):
//
//   SIDIK_PNG_DIR=/tmp/desain flutter test test/tampilan/render_layar_lab_test.dart
//
// Tidak ada golden baseline: gambar dari mesin non-macOS tidak boleh menjadi
// acuan (lihat test/flutter_test_config.dart). Tes ini menjaga LUAPAN, bukan
// piksel.
//
// Satu layar saja: `SIDIK_LAYAR=login flutter test ...` (nama dari daftar di
// bawah). Berguna untuk memotret ulang satu layar.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/kalibrasi_teknisi_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/providers/technician_provider.dart';
import 'package:sidik_calibration/screens/admin/antrean_approval_screen.dart';
import 'package:sidik_calibration/screens/alur/alur_kerja_screen.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/calibration/category_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/equipment/equipment_list_screen.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/screens/jatuh_tempo/layar_jatuh_tempo.dart';
import 'package:sidik_calibration/screens/profile/profile_screen.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/kalibrasi_teknisi_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/technician_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/user_service.dart';

import '../support/halaman_lembar.dart';
import '../support/lewati_onboarding.dart';
import '../support/simpanan_tiruan.dart';

enum _Ukuran {
  hp('hp', 392, 852, 1.0, 2.0),
  sempit('sempit', 320, 640, 1.3, 2.0),
  tablet('tablet', 1280, 800, 1.0, 1.25);

  const _Ukuran(
    this.kode,
    this.lebar,
    this.tinggi,
    this.skalaHuruf,
    this.piksel,
  );
  final String kode;
  final double lebar;
  final double tinggi;
  final double skalaHuruf;
  final double piksel;
}

class _Layar {
  const _Layar(
    this.nama,
    this.bangun,
    this.tipe, {
    this.token = 'mock-token-1',
    this.sesudah,
  });

  final String nama;
  final Widget Function() bangun;

  /// Jenis widget yang HARUS muncul. Tanpa ini tes bisa hijau padahal layarnya
  /// gagal dibangun.
  final Type tipe;

  /// `mock-token-1` admin, `mock-token-2` teknisi, `mock-token-5` super admin
  /// (lihat MockAuthService).
  final String token;
  final Future<void> Function(WidgetTester tester)? sesudah;
}

/// Layar kunci: yang paling sering dipakai teknisi dan admin, dan semuanya
/// sudah punya Mock*Service. Layar arsip, kamera/pindai, tinjau foto, dan
/// penampil PDF sengaja tidak ada di sini (jalur lain / butuh perangkat).
final _layarKunci = <_Layar>[
  _Layar('login', () => const LoginScreen(), LoginScreen),
  _Layar('beranda-admin', () => const MainShell(), MainShell),
  _Layar(
    'beranda-super-admin',
    () => const MainShell(),
    MainShell,
    token: 'mock-token-5',
  ),
  _Layar(
    'kalibrasi-teknisi',
    () => const MainShell(),
    MainShell,
    token: 'mock-token-2',
  ),
  _Layar(
    'antrean-persetujuan',
    () => const AntreanApprovalScreen(),
    AntreanApprovalScreen,
  ),
  _Layar('riwayat', () => const HistoryScreen(), HistoryScreen),
  _Layar(
    'detail-sesi',
    () => const CalibrationDetailScreen(calibrationId: 1),
    CalibrationDetailScreen,
  ),
  _Layar('alat', () => const EquipmentListScreen(), EquipmentListScreen),
  _Layar('kelola-lab', () => const KelolaLabScreen(), KelolaLabScreen),
  _Layar('profil', () => const ProfileScreen(), ProfileScreen),
  _Layar('alur-kerja', () => const AlurKerjaScreen(), AlurKerjaScreen),
  _Layar('jadwal', () => const JadwalKalibrasiScreen(), JadwalKalibrasiScreen),
  _Layar(
    'pilih-kategori',
    () => const CategoryPickerScreen(),
    CategoryPickerScreen,
    token: 'mock-token-2',
  ),
  _Layar(
    'lembar-hal1',
    () => const LembarKerjaScreen(profil: 'thermocouple'),
    LembarKerjaScreen,
    token: 'mock-token-2',
  ),
  _Layar(
    'lembar-hal2',
    () => const LembarKerjaScreen(profil: 'thermocouple'),
    LembarKerjaScreen,
    token: 'mock-token-2',
    sesudah: keHalamanAkhir,
  ),
];

/// UTANG LUAPAN: kombinasi `layar|ukuran` yang SUDAH meluap sebelum gerbang ini
/// ada. Nilainya batas luapan (px) yang diizinkan. Gerbang tidak boleh merah
/// karena kode lama, tetapi utangnya dicatat di sini, hanya boleh mengecil, dan
/// tes gagal bila utang ternyata sudah lunas (supaya daftar ini dibersihkan).
///
/// - riwayat|sempit: `history_screen.dart` baris 511, Row kartu sesi meluap
///   8,3 px di 320 dp x huruf 1,3 (ikon + judul + lencana tak muat). Perbaikan
///   = paket layar daftar, bukan token.
const _utangLuapan = <String, double>{'riwayat|sempit': 8.3};

/// Patokan "hari ini" supaya tanggal di layar tetap.
final _hariIni = DateTime(2026, 11, 9, 10, 30);

Widget _bungkus(
  Widget layar,
  _Ukuran u, {
  required bool gelap,
  required String token,
  Key? kunci,
}) {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      perhitunganServiceProvider.overrideWithValue(MockPerhitunganService()),
      historyServiceProvider.overrideWithValue(MockHistoryService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      jamProvider.overrideWithValue(() => _hariIni),
      equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
      userServiceProvider.overrideWithValue(MockUserService()),
      izinServiceProvider.overrideWithValue(MockIzinService()),
      certificateServiceProvider.overrideWithValue(MockCertificateService()),
      kalibrasiTeknisiServiceProvider.overrideWithValue(
        MockKalibrasiTeknisiService(),
      ),
      notificationServiceProvider.overrideWithValue(MockNotificationService()),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      customerLookupServiceProvider.overrideWithValue(
        MockCustomerLookupService(),
      ),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
      technicianServiceProvider.overrideWithValue(MockTechnicianService()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: gelap ? AppTheme.dark : AppTheme.light,
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => RepaintBoundary(
        key: kunci,
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: u.skalaHuruf,
          maxScaleFactor: u.skalaHuruf,
          child: child!,
        ),
      ),
      home: layar,
    ),
  );
}

/// Font Inter dan IBM Plex Mono dari aset repo (lebar teks sama dengan di HP,
/// bukan kotak Ahem) dan font ikon Material dari SDK.
Future<void> _muatFont() async {
  for (final (nama, berkas) in [
    ('Inter', 'Inter'),
    ('IBMPlexMono', 'IBMPlexMono'),
  ]) {
    final pemuat = FontLoader(nama);
    for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/$berkas-$b.ttf').readAsBytesSync();
      pemuat.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await pemuat.load();
  }
  final akar = Platform.environment['FLUTTER_ROOT'];
  if (akar == null) return;
  final ikon = File(
    '$akar/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!ikon.existsSync()) return;
  final pemuat = FontLoader('MaterialIcons')
    ..addFont(Future.value(ikon.readAsBytesSync().buffer.asByteData()));
  await pemuat.load();
}

Future<void> _selesai(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 4),
    );
  } catch (_) {
    // Ada animasi yang berputar terus (mis. indikator): cukup satu jeda.
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  pasangSimpananTiruan();

  setUpAll(_muatFont);

  final folder = Platform.environment['SIDIK_PNG_DIR'];
  if (folder != null) Directory(folder).createSync(recursive: true);
  final hanya = Platform.environment['SIDIK_LAYAR'];

  for (final l in _layarKunci) {
    if (hanya != null && hanya != l.nama) continue;
    for (final u in _Ukuran.values) {
      for (final gelap in const [false, true]) {
        final tema = gelap ? 'gelap' : 'terang';
        testWidgets('${l.nama} - ${u.kode} - $tema', (tester) async {
          final galat = <String>[];
          final rincian = <String>[];
          final bawaan = FlutterError.onError;
          FlutterError.onError = (d) {
            galat.add(d.exceptionAsString().split('\n').first);
            rincian.add(d.toString().split('\n').take(14).join('\n'));
          };
          final kunci = GlobalKey();
          // Untuk PNG, bayangan digambar sungguhan (bawaan flutter_test:
          // kotak hitam keras). Harus dikembalikan sebelum tes selesai.
          if (folder != null) debugDisableShadows = false;
          tester.view.physicalSize = Size(
            u.lebar * u.piksel,
            u.tinggi * u.piksel,
          );
          tester.view.devicePixelRatio = u.piksel;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          try {
            await tester.pumpWidget(
              _bungkus(
                l.bangun(),
                u,
                gelap: gelap,
                token: l.token,
                kunci: kunci,
              ),
            );
            await tester.runAsync(() async {
              final konteks = tester.element(find.byType(MaterialApp));
              await precacheImage(
                const AssetImage('assets/images/logo_pt_sidik.png'),
                konteks,
              );
            });
            await _selesai(tester);
            if (l.sesudah != null) {
              await l.sesudah!(tester);
              await _selesai(tester);
            }

            if (folder != null) {
              final batas = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(kunci),
              );
              await tester.runAsync(() async {
                final gambar = await batas.toImage(pixelRatio: u.piksel);
                final data = await gambar.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                File(
                  '$folder/${l.nama}.${u.kode}${gelap ? '-gelap' : ''}.png',
                ).writeAsBytesSync(data!.buffer.asUint8List());
              });
            }

            expect(
              find.byType(l.tipe),
              findsWidgets,
              reason: '${l.nama} tidak terbangun',
            );
          } finally {
            FlutterError.onError = bawaan;
            debugDisableShadows = true;
          }
          final unik = galat.toSet().toList();
          final utang = _utangLuapan['${l.nama}|${u.kode}'];
          if (utang == null) {
            expect(
              unik,
              isEmpty,
              reason:
                  '${l.nama} - ${u.kode} - $tema: galat saat render '
                  '(luapan = RenderFlex overflowed)\n'
                  '${rincian.isEmpty ? '' : rincian.first}',
            );
          } else {
            // Utang lama (lihat [_utangLuapan]): boleh masih meluap, tetapi
            // tidak boleh bertambah parah dan tidak boleh berganti jenis.
            expect(
              unik,
              isNotEmpty,
              reason:
                  '${l.nama} - ${u.kode} sudah tidak meluap: hapus dari '
                  '_utangLuapan.',
            );
            for (final g in unik) {
              final cocok = RegExp(
                r'overflowed by ([0-9.]+) pixels',
              ).firstMatch(g);
              expect(cocok, isNotNull, reason: 'galat bukan luapan: $g');
              expect(
                double.parse(cocok!.group(1)!),
                lessThanOrEqualTo(utang + 0.05),
                reason:
                    '${l.nama} - ${u.kode} meluap lebih parah dari $utang px',
              );
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
