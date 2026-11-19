// Perkakas uji layar CRUD lab (Order, Penugasan, Kategori alat, Arsip draf):
// izin bernama persis tabel kontrak, pembungkus aplikasi dengan service palsu.
// Dipakai test layar, test responsif, dan harness PNG.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/arsip_draf_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/kategori_kelola_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/order_kelola_provider.dart';
import 'package:sidik_calibration/providers/penugasan_kelola_provider.dart';
import 'package:sidik_calibration/providers/super_admin_provider.dart';
import 'package:sidik_calibration/services/arsip_draf_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/kategori_kelola_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/order_kelola_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/penugasan_kelola_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'lewati_onboarding.dart';

/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
const tokenAdminCrud = 'mock-token-1';
const tokenTeknisiCrud = 'mock-token-2';
const tokenSuperAdminCrud = 'mock-token-5';

/// Kunci izin yang `ya` untuk admin di tabel §1 kontrak CRUD lengkap, ditambah
/// `pelanggan.kelola` (tempat Order menumpang; satu grup `role:admin` server).
const _izinAdminCrud = <String>{
  NamaIzin.pelangganKelola,
  NamaIzin.penggunaKelola,
  NamaIzin.teknisiKelola,
  NamaIzin.kategoriKelola,
  NamaIzin.kalibrasiArsipkan,
  NamaIzin.kalibrasiPulihkan,
  NamaIzin.penugasanUbah,
  NamaIzin.penugasanBatalkan,
  // PR #284: admin dan super admin menyelesaikan; membuka lagi HANYA super admin.
  NamaIzin.penugasanSelesaikan,
};

const izinAdminCrud = Izin(role: UserRole.admin, boleh: _izinAdminCrud);

const izinSuperAdminCrud = Izin(
  role: UserRole.superAdmin,
  boleh: {
    ..._izinAdminCrud,
    NamaIzin.penggunaBuatAdmin,
    NamaIzin.penugasanBukaLagi,
  },
);

/// Teknisi: hanya `kalibrasi.arsipkan` (draf sendiri) dari kunci CRUD.
const izinTeknisiCrud = Izin(
  role: UserRole.teknisi,
  boleh: {NamaIzin.alatTambah, NamaIzin.kalibrasiBuat, NamaIzin.kalibrasiArsipkan},
);

const izinViewerCrud = Izin(
  role: UserRole.viewer,
  boleh: {NamaIzin.alatRiwayatSertifikat},
);

/// Pelanggan (PT) tiruan untuk pemilih PT. Id 3 dan 4 cocok dengan
/// [MockOrderKelolaService.contoh] dan `alatContoh`.
const pelangganUjiCrud = <CustomerLookup>[
  CustomerLookup(
    id: 3,
    nama: 'PT Tirta Contoh Mandiri',
    alamat: 'Jl. Contoh Primer A-10, Bandung',
  ),
  CustomerLookup(id: 4, nama: 'CV Maju Bersama'),
];

class LapisanUjiCrud {
  LapisanUjiCrud({
    OrderKelolaService? order,
    PenugasanKelolaService? penugasan,
    KategoriKelolaService? kategori,
    ArsipDrafService? arsipDraf,
    PenggunaSaService? pengguna,
    this.pelanggan = pelangganUjiCrud,
    this.pelangganGalat,
    this.tambahan = const [],
  }) : order = order ?? MockOrderKelolaService(),
       penugasan = penugasan ?? MockPenugasanKelolaService(),
       kategori = kategori ?? MockKategoriKelolaService(),
       arsipDraf = arsipDraf ?? MockArsipDrafService(),
       pengguna = pengguna ?? MockPenggunaSaService();

  final OrderKelolaService order;
  final PenugasanKelolaService penugasan;
  final KategoriKelolaService kategori;
  final ArsipDrafService arsipDraf;
  final PenggunaSaService pengguna;

  /// Override tambahan milik keadaan tertentu (mis. riwayat untuk layar Draf).
  final List<Override> tambahan;
  final List<CustomerLookup> pelanggan;

  /// Bila diisi, pencarian pelanggan gagal dengan galat ini.
  final Object? pelangganGalat;

  List<Override> overrides({
    String token = tokenAdminCrud,
    Izin izin = izinAdminCrud,
    List<Override> tambahan = const [],
  }) => [
    lewatiOnboarding,
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
    orderKelolaServiceProvider.overrideWithValue(order),
    penugasanKelolaServiceProvider.overrideWithValue(penugasan),
    kategoriKelolaServiceProvider.overrideWithValue(kategori),
    arsipDrafServiceProvider.overrideWithValue(arsipDraf),
    penggunaSaServiceProvider.overrideWithValue(pengguna),
    customerLookupProvider.overrideWith((ref, search) async {
      if (pelangganGalat != null) throw pelangganGalat!;
      final kata = search.toLowerCase();
      return (
        daftar: [
          for (final p in pelanggan)
            if (kata.isEmpty || p.nama.toLowerCase().contains(kata)) p,
        ],
        dariSimpanan: false,
        diambil: null,
      );
    }),
    ...this.tambahan,
    ...tambahan,
  ];
}

/// Bungkus [layar] seperti aplikasi: tema Lab, locale id, skala huruf
/// [skalaHuruf] (dipasang langsung TANPA jepitan app, agar 2,0× benar-benar
/// teruji).
Widget bungkusCrud(
  Widget layar, {
  LapisanUjiCrud? lapisan,
  String token = tokenAdminCrud,
  Izin izin = izinAdminCrud,
  bool gelap = false,
  double skalaHuruf = 1.0,
  List<Override> tambahan = const [],
  Key? kunciLatar,
}) {
  final l = lapisan ?? LapisanUjiCrud();
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
