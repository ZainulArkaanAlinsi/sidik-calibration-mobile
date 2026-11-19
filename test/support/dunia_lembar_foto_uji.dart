// Dunia tiruan untuk menjalankan LembarKerjaScreen yang dibuka dari foto
// ("Pindai lembar kerja") di tes tampilan: layanan Mock*, bentuk lembar pH
// beserta bekal "alat baru", mesin baca yang bisa ditahan/digagalkan, dan
// pembantu merender (font, ukuran layar, tunggu tenang). Dipakai pengukur tinggi
// dan pembuat PNG paket OCR-SEMPIT; salinan logika yang sama ada (privat) di
// `render_pindai_linear_test.dart`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/models/pratinjau_hitung.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/catatan_identifikasi_provider.dart';
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
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/providers/technician_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/pindai/dari_foto_lembar.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/catatan_identifikasi_lembar.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart'
    show daftarAlatMock;
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart'
    show GagalPindai;
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/kalibrasi_teknisi_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/technician_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/user_service.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

import 'daftar_pindai_uji.dart';
import 'halaman_identitas_uji.dart';
import 'layanan_alat_uji.dart';
import 'lewati_onboarding.dart';

const tokenTeknisiUji = 'mock-token-2';
final hariIniUji = DateTime(2026, 11, 15, 10, 30);

/// Satu ukuran layar uji: lebar x tinggi dalam dp, skala huruf, tema.
class UkuranUji {
  const UkuranUji(
    this.kode,
    this.lebar,
    this.tinggi,
    this.huruf, {
    this.gelap = false,
  });

  final String kode;
  final double lebar;
  final double tinggi;
  final double huruf;
  final bool gelap;

  String get nama => '$kode${gelap ? '-gelap' : '-terang'}';
}

/// Identitas yang terbaca dari kertas contoh (karangan).
const kertasUji = IdentitasKertas(
  namaAlat: 'pH Meter',
  merk: 'Mettler',
  model: 'Five Easy',
  seri: 'B628755900',
  pemilik: 'PT Tirta Contoh Mandiri',
  alamat: 'Jl. Contoh Primer A-10, Kec. Cicalengka',
);

final alat14Uji = daftarAlatMock.firstWhere((a) => a.id == 14);

EquipmentLookup alatMiripUji(int id, String seri) => EquipmentLookup(
  id: id,
  namaAlat: 'pH Meter Mettler Toledo',
  serialNumber: seri,
  kategori: 'instrumen-analitik',
  status: 'aktif',
  merk: 'Mettler Toledo',
  pelangganNama: 'PT Tirta Contoh Mandiri',
);

/// Bentuk lembar pH yang membawa `alat_baru` (bekal jenis alat dari server),
/// seperti respons nyata.
class LembarServisUji implements LembarKerjaService {
  final _dasar = MockLembarKerjaService();

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async => LembarKerja.fromJson({
    ...contohBentukLembarKerja(),
    'alat_baru': {
      'kategori': 'instrumen-analitik',
      'nama_alat_kemampuan': 'pH Meter',
    },
    'pindai_foto': {
      'kolom_suhu': false,
      'standar_di_baris': true,
      'didukung': true,
    },
  });

  @override
  Future<PratinjauHitung> pratinjau(
    String token,
    LembarKerjaSubmission isian,
  ) => _dasar.pratinjau(token, isian);

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) =>
      _dasar.kirim(token, isian);

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) =>
      _dasar.perbarui(token, id, isian);
}

/// Pembaca halaman tiruan (satu kali baca; selanjutnya kosong).
class PembacaHalamanUji implements PembacaHalaman {
  PembacaHalamanUji(this.halaman, {this.tahan});

  final List<TeksTerbaca> halaman;
  Completer<void>? tahan;
  int jumlah = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    if (jumlah++ > 0) return const [];
    await tahan?.future;

    return halaman;
  }

  @override
  Future<void> tutup() async {}
}

/// Mesin baca tiruan: gagal "foto buram" (bawaan di sini) atau mengisi sel pH
/// sesudah-adjustment. Bisa ditahan.
class MesinBacaUji extends JalankanPindaiAsli {
  MesinBacaUji({this.tahan, this.gagal = true})
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  Completer<void>? tahan;
  final bool gagal;
  int dipanggil = 0;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    dipanggil++;
    await tahan?.future;
    if (gagal) {
      throw const PindaiAsliGagal(
        GagalPindaiAsli.mutu,
        mutu: GagalPindai.mutuBuram,
      );
    }

    const nilai = {1: '4,0', 2: '7,0', 3: '10,0'};

    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (s.kunci.startsWith('sesudah_adjustment|') &&
              s.kunci.endsWith('|pembacaan') &&
              s.repeatNo <= 3 &&
              nilai.containsKey(s.barisKe))
            (
              sel: s,
              bacaan: (
                teks: '${nilai[s.barisKe]}${s.repeatNo}',
                keyakinan: 0.95,
                didalamKotak: true,
              ),
            ),
      ],
      gagalDibaca: const {},
    );
  }
}

WorksheetTemplate formulirAsliUji() {
  final data =
      jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  return WorksheetTemplate.fromJson({
    'data': {...(data['data'] as Map<String, dynamic>)},
  });
}

/// Font sungguhan (Inter, IBM Plex Mono, ikon Material) supaya PNG dan ukuran
/// teks sama dengan perangkat, bukan kotak Ahem bawaan flutter_test.
Future<void> muatFontUji() async {
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

class DuniaLembarFoto {
  DuniaLembarFoto({
    this.alat = const [],
    PtUji? pt,
    this.mesin,
    this.pencariGagal = false,
  }) : pt = pt ?? PtUji(),
       pencari = PencariAlatUji(alat)..gagal = pencariGagal,
       layanan = LayananAlatUji();

  final List<EquipmentLookup> alat;
  final bool pencariGagal;
  final PtUji pt;
  final PencariAlatUji pencari;
  final LayananAlatUji layanan;
  final MesinBacaUji? mesin;
  late final Directory dir = Directory.systemTemp.createTempSync('png-sempit');
  late final File berkas = File('${dir.path}/lembar.png')
    ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  late final MockSumberFoto sumber = MockSumberFoto(file: berkas);

  List<Override> overrides() => [
    lewatiOnboarding,
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage(tokenTeknisiUji),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    dashboardServiceProvider.overrideWithValue(
      MockDashboardService(jeda: Duration.zero),
    ),
    lembarKerjaServiceProvider.overrideWithValue(LembarServisUji()),
    perhitunganServiceProvider.overrideWithValue(MockPerhitunganService()),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(pencari),
    jamProvider.overrideWithValue(() => hariIniUji),
    equipmentServiceProvider.overrideWithValue(layanan),
    userServiceProvider.overrideWithValue(MockUserService()),
    izinServiceProvider.overrideWithValue(MockIzinService()),
    certificateServiceProvider.overrideWithValue(MockCertificateService()),
    kalibrasiTeknisiServiceProvider.overrideWithValue(
      MockKalibrasiTeknisiService(),
    ),
    notificationServiceProvider.overrideWithValue(MockNotificationService()),
    categoryServiceProvider.overrideWithValue(MockCategoryService()),
    customerLookupServiceProvider.overrideWithValue(pt),
    approvalServiceProvider.overrideWithValue(MockApprovalService()),
    technicianServiceProvider.overrideWithValue(MockTechnicianService()),
    calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
    worksheetScanServiceProvider.overrideWithValue(
      MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
        formulirAsli: formulirAsliUji(),
      ),
    ),
    pindaiLembarAktifProvider.overrideWithValue(true),
    sumberFotoProvider.overrideWithValue(sumber),
    catatanIdentifikasiLembarProvider.overrideWithValue(
      const CatatanIdentifikasiKosong(),
    ),
    if (mesin != null) mesinPindaiAsliProvider.overrideWithValue(mesin),
    pabrikPembacaPindaiProvider.overrideWithValue((
      sel: MockPembacaSel.new,
      qr: () => throw UnimplementedError('QR tidak dipakai'),
      halaman: () => PembacaHalamanUji(halamanPhUji()),
    )),
  ];
}

/// Aplikasi dengan skala huruf dikunci [UkuranUji.huruf] dan tema terang/gelap
/// sesuai ukuran; [kunci] membungkus SELURUH layar (termasuk lembar bawah) untuk
/// dipotret.
///
/// [papanKetik] > 0 menggambar kotak abu-abu "papan ketik (sistem)" setinggi itu
/// di dasar layar, HANYA supaya PNG menunjukkan ruang yang dimakan papan ketik
/// (papan ketik sungguhan digambar sistem, bukan Flutter). Tinggi untuk tata
/// letaknya ditentukan `tester.view.viewInsets`, bukan parameter ini.
Widget appUji({
  required Widget home,
  required DuniaLembarFoto dunia,
  required UkuranUji u,
  required GlobalKey kunci,
  double papanKetik = 0,
}) => ProviderScope(
  overrides: dunia.overrides(),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: u.gelap ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => RepaintBoundary(
      key: kunci,
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: u.huruf,
        maxScaleFactor: u.huruf,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (papanKetik > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: papanKetik,
                child: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: ColoredBox(
                    color: Color(0xFFCFD3DA),
                    child: Center(
                      child: Text(
                        'papan ketik (sistem)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF5A6070),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    home: home,
  ),
);

/// Pembungkus bekal foto: jenis pH, identitas dari kertas, kode formulir 0509.
DariFotoLembar bekalFotoUji(IdentitasKertas id) => DariFotoLembar(
  jpeg: Uint8List.fromList(img.encodePng(img.Image(width: 64, height: 48))),
  jenis: 'pH Meter',
  otomatis: true,
  identitas: id,
  kodeDokumen: 'SIDIK-FM-CAL-0509',
  gantiJenis: (_) async => null,
);

Future<void> tungguUji(
  WidgetTester tester,
  bool Function() selesai, {
  int maks = 120,
}) async {
  for (var i = 0; i < maks; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (selesai()) return;
  }
}

Future<void> tenangUji(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> bersihkanSnackUji(WidgetTester tester) async {
  final f = find.byType(ScaffoldMessenger);
  if (f.evaluate().isEmpty) return;
  final pesan = tester.state<ScaffoldMessengerState>(f.first);
  for (var i = 0; i < 6 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
    pesan
      ..clearSnackBars()
      ..hideCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 450));
  }
}
