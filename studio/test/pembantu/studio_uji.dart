import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/data_acuan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/data_acuan_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pendaftaran_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/app.dart';
import 'package:sidik_studio/data/status_server_provider.dart';
import 'package:sidik_studio/data/status_server_service.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/inti/penimpaan.dart';
import 'package:sidik_studio/layar/cangkang_studio.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/tema/font_studio.dart';

/// Akar Studio untuk widget test — penimpaan produksi ([penimpaanStudio])
/// ditambah layanan tiruan.
///
/// Akun & sandi = `MockAuthService` paket bersama (fixture yang sama dengan
/// seeder lokal API: `SDK-0001` admin, `SDK-0002` teknisi, `rahasia123`).
/// Isi paket acuan = `MockDataAcuanService` (dicetak dari kode server).
Widget studioUji({
  String? token,
  bool meja = false,
  bool petunjukDev = false,
  Izin izin = const Izin(
    role: UserRole.admin,
    boleh: {NamaIzin.dataAcuanLihat},
  ),
  IzinService? izinService,
  MockDataAcuanService? layanan,
  AuthService? auth,
  TokenStorage? penyimpanan,
  PendaftaranPush? push,
  LayananStatusServer? statusServer,
  WorkbookService? workbook,
  String? alamatServer = 'http://127.0.0.1:8000/api',
  bool isianServerDev = false,
  List<Override> tambahan = const [],
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    ...penimpaanStudio,
    pakaiPanelDesktopProvider.overrideWithValue(meja),
    petunjukDevStudioProvider.overrideWithValue(petunjukDev),
    isianServerDevStudioProvider.overrideWithValue(isianServerDev),
    // `null` = alamat dihitung provider aslinya (test isian server dev).
    if (alamatServer != null)
      alamatServerStudioProvider.overrideWithValue(alamatServer),
    tokenStorageProvider.overrideWithValue(
      penyimpanan ?? InMemoryTokenStorage(token),
    ),
    authServiceProvider.overrideWithValue(
      auth ?? MockAuthService(jeda: Duration.zero),
    ),
    izinServiceProvider.overrideWithValue(
      izinService ?? MockIzinService(izin: izin),
    ),
    dataAcuanServiceProvider.overrideWithValue(layanan ?? LayananAcuanHitung()),
    pendaftaranPushServiceProvider.overrideWithValue(
      push ?? MockPendaftaranPush(),
    ),
    layananStatusServerProvider.overrideWithValue(
      statusServer ?? MockLayananStatusServer(),
    ),
    workbookServiceProvider.overrideWithValue(
      workbook ?? MockWorkbookService(),
    ),
    ...tambahan,
  ],
  child: const SidikStudioApp(),
);

/// Mock memegang `Future.delayed(Duration.zero)` berantai (auth → izin →
/// daftar paket); `pumpAndSettle` saja berhenti terlalu dini. Pola
/// `test/data_acuan_layar_test.dart` paket bersama.
Future<void> tenang(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
  }
}

Future<void> pasangUkuran(WidgetTester tester, Size ukuran) async {
  tester.view.physicalSize = ukuran;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> masukLewatLayar(
  WidgetTester tester,
  String id,
  String sandi,
) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'ID pegawai atau email'),
    id,
  );
  await tester.enterText(find.widgetWithText(TextField, 'Kata sandi'), sandi);
  await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
  await tenang(tester);
}

/// Butir navigasi seksi (sidebar, rail, atau drawer).
Finder navigasi(SeksiStudio seksi) => find.byKey(kunciNavigasi(seksi));

Future<void> bukaSeksi(WidgetTester tester, SeksiStudio seksi) async {
  await tester.tap(navigasi(seksi));
  await tenang(tester);
}

/// Wadah provider aplikasi yang sedang dipompa.
ProviderContainer wadahDari(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SidikStudioApp)),
  listen: false,
);

class LayananAcuanHitung extends MockDataAcuanService {
  int daftarPaketDipanggil = 0;

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) {
    daftarPaketDipanggil++;
    return super.daftarPaket(token);
  }
}

class IzinHitung implements IzinService {
  IzinHitung([
    this.izin = const Izin(
      role: UserRole.admin,
      boleh: {NamaIzin.dataAcuanLihat},
    ),
  ]);

  Izin izin;
  int dipanggil = 0;

  @override
  Future<Izin> ambil(String token) async {
    dipanggil++;
    return izin;
  }
}

class AuthHitung extends MockAuthService {
  AuthHitung() : super(jeda: Duration.zero);

  int jumlahLogin = 0;
  final identitasLogin = <String>[];

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) {
    jumlahLogin++;
    identitasLogin.add(identifier);
    return super.login(identifier: identifier, password: password);
  }
}

/// Muat font Studio (Inter & IBM Plex Mono dari bundel paket bersama, di
/// bawah nama keluarga yang dipakai tema) + ikon Material, untuk golden.
///
/// Tanpa ini teks golden jadi kotak-kotak font uji dan ikonnya kotak kosong —
/// gambar yang tidak bisa dipakai menilai tata letak.
Future<void> muatFontStudio() async {
  final bundel = rootBundle;
  for (final (keluarga, nama) in const [
    ('Inter', FontStudio.inter),
    ('IBMPlexMono', FontStudio.mono),
  ]) {
    final pemuat = FontLoader(nama);
    for (final ragam in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      pemuat.addFont(bundel.load(FontStudio.kunciAset(keluarga, ragam)));
    }
    await pemuat.load();
  }
  await daftarkanAliasFont();

  // Font ikon ikut SDK, bukan repo (pola `test/screenshot_test.dart` akar).
  final akar = Platform.environment['FLUTTER_ROOT'];
  if (akar == null) return;
  final berkas = File(
    '$akar/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!berkas.existsSync()) return;
  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(berkas.readAsBytesSync().buffer.asByteData()));
  await ikon.load();
}
