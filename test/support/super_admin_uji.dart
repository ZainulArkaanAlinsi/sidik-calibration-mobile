// Perkakas uji layar pengelolaan Super Admin (Pengguna, Pelanggan & anggota,
// Ganti sandi, hub): izin bernama, pembungkus aplikasi dengan service palsu,
// dan pengukur ukuran layar. Dipakai `super_admin_layar_test.dart`,
// `super_admin_responsif_test.dart`, dan harness PNG
// `tampilan/render_layar_sa_test.dart`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/providers/ganti_sandi_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/riwayat_alat_provider.dart';
import 'package:sidik_calibration/providers/super_admin_provider.dart';
import 'package:sidik_calibration/providers/technician_provider.dart';
import 'package:sidik_calibration/services/anggota_pelanggan_service.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/ganti_sandi_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/riwayat_alat_service.dart';
import 'package:sidik_calibration/services/technician_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/undangan_pelanggan_service.dart';

import 'lewati_onboarding.dart';

/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
const tokenAdmin = 'mock-token-1';
const tokenTeknisi = 'mock-token-2';
const tokenSuperAdmin = 'mock-token-5';

/// Izin Super Admin persis daftar di kontrak §6 + kunci lama yang relevan.
const izinSuperAdmin = Izin(
  role: UserRole.superAdmin,
  boleh: {
    NamaIzin.penggunaKelola,
    NamaIzin.penggunaSetujui,
    NamaIzin.teknisiKelola,
    NamaIzin.penggunaBuatAdmin,
    NamaIzin.penggunaUbahStatus,
    NamaIzin.anggotaPelangganLihat,
    NamaIzin.anggotaPelangganCabut,
    NamaIzin.anggotaPelangganUndang,
    NamaIzin.anggotaPelangganPicAdmin,
    NamaIzin.pelangganAlatLihat,
    NamaIzin.alatRiwayatSertifikat,
    NamaIzin.pelangganPindahAlat,
  },
);

/// Master Data: kunci di tabel §6 yang `ya` untuk admin, TANPA dua kunci
/// khusus super admin (`pengguna.buat-admin`, `pengguna.ubah-status`).
const izinAdmin = Izin(
  role: UserRole.admin,
  boleh: {
    NamaIzin.penggunaKelola,
    NamaIzin.penggunaSetujui,
    NamaIzin.teknisiKelola,
    NamaIzin.anggotaPelangganLihat,
    NamaIzin.anggotaPelangganCabut,
    NamaIzin.anggotaPelangganUndang,
    NamaIzin.anggotaPelangganPicAdmin,
    NamaIzin.pelangganAlatLihat,
    NamaIzin.alatRiwayatSertifikat,
    NamaIzin.pelangganPindahAlat,
  },
);

const izinTeknisi = Izin(
  role: UserRole.teknisi,
  boleh: {NamaIzin.alatTambah, NamaIzin.kalibrasiBuat},
);

class LapisanUjiSa {
  LapisanUjiSa({
    PenggunaSaService? pengguna,
    AnggotaPelangganService? anggota,
    GantiSandiService? gantiSandi,
    TechnicianService? teknisi,
    UndanganPelangganService? undangan,
    RiwayatAlatService? riwayat,
  }) : riwayat = riwayat ?? MockRiwayatAlatService(),
       pengguna = pengguna ?? MockPenggunaSaService(),
       anggota = anggota ?? MockAnggotaPelangganService(),
       gantiSandi = gantiSandi ?? MockGantiSandiService(),
       teknisi = teknisi ?? MockTechnicianService(),
       undangan = undangan ?? MockUndanganPelangganService();

  final PenggunaSaService pengguna;
  final AnggotaPelangganService anggota;
  final GantiSandiService gantiSandi;
  final TechnicianService teknisi;
  final UndanganPelangganService undangan;
  final RiwayatAlatService riwayat;

  List<Override> overrides({
    String token = tokenSuperAdmin,
    Izin izin = izinSuperAdmin,
    List<Override> tambahan = const [],
  }) => [
    lewatiOnboarding,
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
    penggunaSaServiceProvider.overrideWithValue(pengguna),
    anggotaPelangganServiceProvider.overrideWithValue(anggota),
    gantiSandiServiceProvider.overrideWithValue(gantiSandi),
    technicianServiceProvider.overrideWithValue(teknisi),
    undanganPelangganServiceProvider.overrideWithValue(undangan),
    riwayatAlatServiceProvider.overrideWithValue(riwayat),
    certificateServiceProvider.overrideWithValue(MockCertificateService()),
    ...tambahan,
  ];
}

/// Bungkus [layar] seperti aplikasi: tema Lab, locale id, skala huruf
/// [skalaHuruf] (dipasang langsung, TANPA jepitan app — agar 2,0× benar-benar
/// teruji), orientasi/ukuran dari [ukuran].
Widget bungkusSa(
  Widget layar, {
  LapisanUjiSa? lapisan,
  String token = tokenSuperAdmin,
  Izin izin = izinSuperAdmin,
  bool gelap = false,
  double skalaHuruf = 1.0,
  List<Override> tambahan = const [],
  Key? kunciLatar,
}) {
  final l = lapisan ?? LapisanUjiSa();
  return ProviderScope(
    overrides: l.overrides(token: token, izin: izin, tambahan: tambahan),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: gelap ? AppTheme.dark : AppTheme.light,
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => RepaintBoundary(
        key: kunciLatar,
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: skalaHuruf,
          maxScaleFactor: skalaHuruf,
          child: child!,
        ),
      ),
      home: layar,
    ),
  );
}

/// Atur ukuran layar logis [lebar] x [tinggi] dp (rasio piksel 1,0 supaya
/// tes cepat) dan kembalikan saat tes selesai.
void aturLayar(WidgetTester tester, double lebar, double tinggi) {
  tester.view.physicalSize = Size(lebar, tinggi);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Font asli (lebar teks sama dengan HP) — panggil di `setUpAll`.
Future<void> muatFontSa() async {
  for (final nama in ['Inter', 'IBMPlexMono']) {
    final pemuat = FontLoader(nama);
    for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/$nama-$b.ttf').readAsBytesSync();
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

/// Selesaikan animasi masuk tanpa menunggu animasi tak berujung.
Future<void> selesaikan(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Daftar pengguna besar buat uji daftar malas.
List<User> penggunaBanyak(int n) => [
  for (var i = 0; i < n; i++)
    User(
      id: 1000 + i,
      nama: 'Pengguna Nomor $i',
      email: 'pengguna$i@lab.test',
      employeeId: 'SDK-${(1000 + i).toString().padLeft(4, '0')}',
      role: i % 3 == 0 ? UserRole.admin : UserRole.teknisi,
      status: UserStatus.aktif,
      organizationId: 1,
    ),
];

/// Nama/email/perusahaan SANGAT panjang dan data kosong.
const namaSangatPanjang =
    'Muhammad Abdurrahman Wahyudi Prasetyo Nugroho Hadiningrat Kusumawardhana '
    'Santoso bin Sumarno Jayakusuma dari Bandung Selatan';
const emailSangatPanjang =
    'muhammad.abdurrahman.wahyudi.prasetyo.nugroho.hadiningrat@laboratorium-kalibrasi-nasional-contoh-sangat-panjang.co.id';
