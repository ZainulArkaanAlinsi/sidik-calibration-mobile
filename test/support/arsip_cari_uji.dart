import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/garis_waktu_arsip.dart';
import 'package:sidik_calibration/models/pencarian_arsip.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/arsip_cari_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/screens/arsip/garis_waktu_arsip_screen.dart';
import 'package:sidik_calibration/services/arsip_cari_service.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

// Perlengkapan bersama tes layar Arsip menurut waktu (fungsional + desain):
// akun uji, service tiruan yang bisa diatur per tes, pembangun sesi, dan
// pemasang layar. Auth diselesaikan DULU (di luar jam palsu) supaya
// penyelesaiannya tidak dibaca sebagai pergantian akun.

const akunUji = User(
  id: 1,
  nama: 'Budi Santoso',
  email: 'admin@pt-sidik.com',
  employeeId: 'SDK-0001',
  role: UserRole.admin,
  status: UserStatus.aktif,
  organizationId: 1,
);

const akunUjiB = User(
  id: 2,
  nama: 'Andi Pratama',
  email: 'teknisi@pt-sidik.com',
  employeeId: 'SDK-0002',
  role: UserRole.teknisi,
  status: UserStatus.aktif,
  organizationId: 2,
);

class AuthUji extends AuthController {
  @override
  Future<User?> build() async => akunUji;

  /// Menggantikan akun yang sedang masuk (tanpa lewat layar login).
  void ganti(User? akun) => state = AsyncData(akun);
}

/// Mock bawaan + jawaban Riwayat/galat yang bisa diatur per test.
class ServiceLayar extends MockArsipCariService {
  ServiceLayar({super.sesi, super.kosong, super.gagal, super.jeda});

  Future<HalamanRiwayat> Function(FilterArsip filter, int halaman)?
  riwayatKhusus;
  Object? galatGarisWaktu;

  /// Jawaban garis waktu yang diatur tes (mis. ditahan dengan `Completer`).
  Future<HalamanGarisWaktu> Function(
    PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman,
  )?
  garisKhusus;

  @override
  Future<HalamanGarisWaktu> garisWaktu(
    String token, {
    required PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman = 1,
  }) {
    final khusus = garisKhusus;
    if (khusus != null) {
      panggilanGarisWaktu.add((
        posisi: posisi,
        pelangganId: pelangganId,
        halaman: halaman,
      ));
      return khusus(posisi, pelangganId, halaman);
    }
    final galat = galatGarisWaktu;
    if (galat != null) {
      panggilanGarisWaktu.add((
        posisi: posisi,
        pelangganId: pelangganId,
        halaman: halaman,
      ));
      return Future.error(galat);
    }
    return super.garisWaktu(
      token,
      posisi: posisi,
      pelangganId: pelangganId,
      halaman: halaman,
    );
  }

  @override
  Future<HalamanRiwayat> cariRiwayat(
    String token, {
    required FilterArsip filter,
    int halaman = 1,
  }) {
    final khusus = riwayatKhusus;
    if (khusus == null) {
      return super.cariRiwayat(token, filter: filter, halaman: halaman);
    }
    panggilanRiwayat.add((filter: filter, halaman: halaman));
    return khusus(filter, halaman);
  }
}

CalibrationHistoryItem sesiUji(
  int id, {
  required String alat,
  required String seri,
  required String sertifikat,
  String pt = 'PT Contoh Alfa',
  String status = 'terbit',
  int? alatId,
}) => CalibrationHistoryItem(
  id: id,
  namaAlat: alat,
  namaTeknisi: 'Dr. Arch Schaefer',
  tanggalKalibrasi: DateTime(2026, 11, 11),
  status: CalibrationStatus.disetujui,
  keputusan: Keputusan.pass,
  nomorSeri: seri,
  namaPelanggan: pt,
  nomorSertifikat: sertifikat,
  statusSertifikat: status,
  equipmentId: alatId,
);

void ukuranLayar(
  WidgetTester tester,
  double lebar, [
  double tinggi = 800,
  double skalaTeks = 1,
]) {
  tester.view.physicalSize = Size(lebar * 2, tinggi * 2);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = skalaTeks;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pasang layar. Auth diselesaikan DULU (di luar jam palsu), supaya
/// penyelesaiannya tidak dibaca sebagai pergantian akun dan tidak menggandakan
/// panggilan pertama.
Future<ProviderContainer> bukaLayarArsip(
  WidgetTester tester,
  ArsipCariService service, {
  double lebar = 800,
  double tinggi = 1200,
  double skalaTeks = 1,
  Locale locale = const Locale('id'),
  ThemeData? tema,
  bool tungguSelesai = true,
}) async {
  ukuranLayar(tester, lebar, tinggi, skalaTeks);
  SharedPreferences.setMockInitialValues({});

  final wadah = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('token')),
      authProvider.overrideWith(AuthUji.new),
      arsipCariServiceProvider.overrideWithValue(service),
      customerLookupServiceProvider.overrideWithValue(
        MockCustomerLookupService(),
      ),
      calibrationDetailProvider.overrideWith(
        (ref, id) async => throw Exception('detail tidak dimuat di test'),
      ),
    ],
  );
  addTearDown(wadah.dispose);
  final langganan = wadah.listen<AsyncValue<User?>>(authProvider, (_, _) {});
  addTearDown(langganan.close);
  await tester.runAsync(() => wadah.read(authProvider.future));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      // Kunci baru tiap pemasangan: tanpa ini pohon lama (rute, lembar PT yang
      // masih terbuka, State layar) terbawa ke pemasangan berikutnya.
      key: UniqueKey(),
      container: wadah,
      child: MaterialApp(
        theme: tema,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GarisWaktuArsipScreen(),
      ),
    ),
  );
  // Pemuatan yang sengaja ditahan menjalankan animasi tanpa akhir (garis
  // kemajuan); `pumpAndSettle` tidak akan pernah selesai di situ.
  tungguSelesai ? await tester.pumpAndSettle() : await tester.pump();
  return wadah;
}

/// Ketik di kotak cari lalu tunggu debounce dan jawabannya.
Future<void> cariDiKotak(WidgetTester tester, String kata) async {
  await tester.enterText(find.byType(TextField).first, kata);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}
