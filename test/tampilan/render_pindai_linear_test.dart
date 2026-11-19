// Alur foto LINEAR: PNG untuk persetujuan pemilik.
//
// Merender jalur "Pindai lembar kerja" (beranda -> membaca -> lembar terbuka ->
// cek hasil -> lembar terisi) dan tiap keadaan blok identitas (cocok, terpilih,
// mirip, baru, seri kosong, PT mirip, galat, tidak terbaca, foto gagal) pada
// lebar 392 dan 600 (terang dan gelap) serta 320 dp dengan huruf 2,0. Data =
// Mock*Service dan teks sintetis; tidak ada foto asli lab.
//
// PNG hanya ditulis bila `SIDIK_PNG_DIR` diisi (folder di LUAR repo):
//
//   SIDIK_PNG_DIR=/tmp/png flutter test test/tampilan/render_pindai_linear_test.dart
//
// Tanpa itu semua tes di sini dilewati: kamera tidak bisa digambar tanpa
// perangkat, dan luapan layar-layar ini sudah dijaga `blok_identitas_foto_test`.
// Satu keadaan saja: `SIDIK_KEADAAN=blok-baru`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
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
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/pindai/dari_foto_lembar.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
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
import 'package:sidik_calibration/widgets/pilih_alat_ringkas_sheet.dart';
import 'package:sidik_calibration/widgets/tombol_pindai_lembar.dart';

import '../support/daftar_pindai_uji.dart';
import '../support/halaman_identitas_uji.dart';
import '../support/layanan_alat_uji.dart';
import '../support/lewati_onboarding.dart';
import '../support/simpanan_tiruan.dart';

const _teknisi = 'mock-token-2';
final _hariIni = DateTime(2026, 11, 15, 10, 30);

class _Ukuran {
  const _Ukuran(
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

/// Lebar 392 dan 600, terang dan gelap, plus 320 dp dengan huruf 2,0.
const _ukuran = <_Ukuran>[
  _Ukuran('392', 392, 852, 1.0),
  _Ukuran('392', 392, 852, 1.0, gelap: true),
  _Ukuran('600', 600, 900, 1.0),
  _Ukuran('600', 600, 900, 1.0, gelap: true),
  _Ukuran('320-huruf2', 320, 640, 2.0),
];

/// Identitas yang terbaca dari kertas contoh (karangan).
const _kertas = IdentitasKertas(
  namaAlat: 'pH Meter',
  merk: 'Mettler',
  model: 'Five Easy',
  seri: 'B628755900',
  pemilik: 'PT Tirta Contoh Mandiri',
  alamat: 'Jl. Contoh Primer A-10, Kec. Cicalengka',
);

final _alat14 = daftarAlatMock.firstWhere((a) => a.id == 14);

EquipmentLookup _a(int id, String seri) => EquipmentLookup(
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
class _LembarServis implements LembarKerjaService {
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

/// Pembaca halaman yang bisa menahan pembacaan (untuk memotret dialog
/// "Membaca lembar kerja").
class _Pembaca implements PembacaHalaman {
  _Pembaca(this.halaman, {this.tahan});

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

/// Mesin baca: hasilnya sel pH sesudah-adjustment (kuning), bisa ditahan.
class _Mesin extends JalankanPindaiAsli {
  _Mesin({this.tahan, this.gagal = false})
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  Completer<void>? tahan;
  final bool gagal;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
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

WorksheetTemplate _formulirAsli() {
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

class _Dunia {
  _Dunia({
    this.alat = const [],
    PtUji? pt,
    this.halaman,
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
  final _Pembaca? halaman;
  final _Mesin? mesin;
  late final Directory dir = Directory.systemTemp.createTempSync('png-linear');
  late final File berkas = File('${dir.path}/lembar.png')
    ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  late final MockSumberFoto sumber = MockSumberFoto(file: berkas);

  List<Override> overrides() => [
    lewatiOnboarding,
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_teknisi)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    dashboardServiceProvider.overrideWithValue(
      MockDashboardService(jeda: Duration.zero),
    ),
    lembarKerjaServiceProvider.overrideWithValue(_LembarServis()),
    perhitunganServiceProvider.overrideWithValue(MockPerhitunganService()),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(pencari),
    jamProvider.overrideWithValue(() => _hariIni),
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
        formulirAsli: _formulirAsli(),
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
      halaman: () => halaman ?? _Pembaca(halamanPhUji()),
    )),
  ];
}

Widget _app({
  required Widget home,
  required _Dunia dunia,
  required _Ukuran u,
  required GlobalKey kunci,
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
        child: child!,
      ),
    ),
    home: home,
  ),
);

Future<void> _tunggu(
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

Future<void> _tenang(WidgetTester tester) async {
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

void _bersihkanSnack(WidgetTester tester) {
  final f = find.byType(ScaffoldMessenger);
  if (f.evaluate().isEmpty) return;
  tester.state<ScaffoldMessengerState>(f.first).clearSnackBars();
}

void main() {
  pasangSimpananTiruan();

  final folder = Platform.environment['SIDIK_PNG_DIR'];
  final hanya = Platform.environment['SIDIK_KEADAAN'];
  final lewati = folder == null ? 'PNG hanya bila SIDIK_PNG_DIR diisi' : null;
  if (folder != null) Directory(folder).createSync(recursive: true);

  setUpAll(() async {
    await _muatFont();
    await initializeDateFormatting('id');
  });

  Future<void> potret(
    WidgetTester tester,
    GlobalKey kunci,
    _Ukuran u,
    String nama,
  ) async {
    if (folder == null) return;
    final batas = tester.renderObject<RenderRepaintBoundary>(find.byKey(kunci));
    await tester.runAsync(() async {
      final gambar = await batas.toImage(pixelRatio: 2.0);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$folder/$nama.${u.nama}.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  void aturLayar(WidgetTester tester, _Ukuran u) {
    tester.view.physicalSize = Size(u.lebar * 2, u.tinggi * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
  }

  /// Satu keadaan LembarKerjaScreen langsung (alur sudah sampai lembar).
  void keadaan(
    String nama,
    _Dunia Function() dunia,
    DariFotoLembar Function() dariFoto, {
    Future<void> Function(WidgetTester tester, _Dunia d)? aksi,
    bool snack = false,
  }) {
    if (hanya != null && hanya != nama) return;
    for (final u in _ukuran) {
      testWidgets('$nama - ${u.nama}', (tester) async {
        aturLayar(tester, u);
        final d = dunia();
        final kunci = GlobalKey();
        await tester.pumpWidget(
          _app(
            home: BekuLembarKerja(
              child: LembarKerjaScreen(
                profil: 'ph_meter',
                judulTambahan: 'pH Meter',
                dariFoto: dariFoto(),
              ),
            ),
            dunia: d,
            u: u,
            kunci: kunci,
          ),
        );
        await _tunggu(tester, () => false, maks: 6);
        await _tenang(tester);
        if (aksi != null) {
          await aksi(tester, d);
          await _tenang(tester);
        }
        if (!snack) _bersihkanSnack(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await potret(tester, kunci, u, nama);
        expect(tester.takeException(), isNull);
      }, skip: lewati != null);
    }
  }

  DariFotoLembar bekal(IdentitasKertas id) => DariFotoLembar(
    jpeg: Uint8List.fromList(img.encodePng(img.Image(width: 64, height: 48))),
    jenis: 'pH Meter',
    otomatis: true,
    identitas: id,
    kodeDokumen: 'SIDIK-FM-CAL-0509',
    gantiJenis: (_) async => null,
  );

  Future<void> ketuk(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await _tenang(tester);
  }

  const kunciBlok = ValueKey('blok-identitas');

  _Dunia dunia({
    List<EquipmentLookup> alat = const [],
    PtUji? pt,
    bool gagal = false,
    _Mesin? mesin,
  }) => _Dunia(
    alat: alat,
    pt: pt,
    pencariGagal: gagal,
    mesin: mesin ?? _Mesin(gagal: true),
  );

  // Keadaan blok identitas ---------------------------------------------------
  keadaan('blok-cocok', () => dunia(alat: [_alat14]), () => bekal(_kertas));
  keadaan(
    'blok-terpilih',
    () => dunia(alat: [_alat14]),
    () => bekal(_kertas),
    aksi: (tester, d) =>
        ketuk(tester, find.byKey(const ValueKey('identitas-pakai-alat'))),
  );
  keadaan(
    'blok-mirip',
    () => dunia(
      alat: [_a(21, 'B628755901'), _a(22, 'B628755800'), _a(23, 'B628755910')],
    ),
    () => bekal(_kertas),
  );
  keadaan('blok-baru', dunia.call, () => bekal(_kertas));
  keadaan(
    'blok-seri-kosong',
    dunia.call,
    () => bekal(
      const IdentitasKertas(
        namaAlat: 'pH Meter',
        merk: 'Mettler',
        pemilik: 'PT Tirta Contoh Mandiri',
      ),
    ),
    aksi: (tester, d) =>
        ketuk(tester, find.byKey(const ValueKey('identitas-buat-lanjut'))),
  );
  keadaan(
    'blok-pt-mirip',
    () => dunia(
      pt: PtUji(
        mirip: const [
          CustomerLookup(
            id: 3,
            nama: 'PT Tirta Contoh Abadi',
            alamat: 'Jl. Contoh Primer A-12',
          ),
          CustomerLookup(id: 4, nama: 'PT Tirta Contoh Makmur'),
        ],
      ),
    ),
    () => bekal(_kertas),
    aksi: (tester, d) =>
        ketuk(tester, find.byKey(const ValueKey('identitas-buat-lanjut'))),
  );
  keadaan('blok-galat-server', () => dunia(gagal: true), () => bekal(_kertas));
  keadaan(
    'blok-tidak-terbaca',
    dunia.call,
    () => bekal(IdentitasKertas.kosong),
  );
  keadaan(
    'foto-gagal',
    dunia.call,
    () => bekal(IdentitasKertas.kosong),
    snack: true,
  );

  // Jalur penuh dari beranda -------------------------------------------------
  const nama = 'alur';
  if (hanya == null || hanya == nama) {
    for (final u in _ukuran) {
      testWidgets('$nama - ${u.nama}', (tester) async {
        aturLayar(tester, u);
        final tahanBaca = Completer<void>();
        final tahanMesin = Completer<void>();
        final d = _Dunia(
          alat: [_alat14],
          halaman: _Pembaca(
            halamanPhUji(
              nama: 'pH Meter',
              seri: 'B628755900',
              merk: 'Mettler',
              model: 'Five Easy',
              pemilik: 'PT Tirta Contoh Mandiri',
              alamat: ['Jl. Contoh Primer A-10, Kec. Cicalengka'],
              kalibrasi: '13 Nov 2026',
            ),
            tahan: tahanBaca,
          ),
          mesin: _Mesin(tahan: tahanMesin),
        );
        final kunci = GlobalKey();
        await tester.pumpWidget(
          _app(home: const MainShell(), dunia: d, u: u, kunci: kunci),
        );
        await tester.runAsync(() async {
          final konteks = tester.element(find.byType(MaterialApp));
          await precacheImage(
            const AssetImage('assets/images/logo_pt_sidik.png'),
            konteks,
          );
        });
        await _tenang(tester);
        await potret(tester, kunci, u, '01-beranda');

        // Kamera = layar sistem (tidak digambar); foto -> membaca.
        final tombol = find.byKey(TombolPindaiLembar.kunciTombol);
        expect(tombol, findsOneWidget);
        await tester.ensureVisible(tombol);
        await tester.pump();
        await tester.tap(tombol);
        await tester.pump();
        await _tunggu(
          tester,
          () =>
              find.textContaining('Mengenali').evaluate().isNotEmpty ||
              find.textContaining('Membaca').evaluate().isNotEmpty,
        );
        await potret(tester, kunci, u, '02-membaca');

        // Lembar terbuka: identitas masuk kuning, blok mencocokkan alat, foto
        // dibaca di latar (dialog memproses).
        tahanBaca.complete();
        await _tunggu(
          tester,
          () => find.byKey(kunciBlok).evaluate().isNotEmpty,
        );
        await _tunggu(
          tester,
          () => find
              .byKey(const ValueKey('identitas-cocok'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await potret(tester, kunci, u, '03-lembar-terbuka');

        // Cek hasil pindai.
        tahanMesin.complete();
        await _tunggu(
          tester,
          () => find.textContaining('Cek Hasil').evaluate().isNotEmpty,
          maks: 80,
        );
        await _tenang(tester);
        await potret(tester, kunci, u, '04-cek-hasil');

        // Teknisi mencentang satu per satu, lalu memasukkan.
        final cek = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith('cek-'),
        );
        for (var i = 0; i < cek.evaluate().length; i++) {
          await tester.ensureVisible(cek.at(i));
          await tester.tap(cek.at(i));
        }
        await tester.pump();
        await tester.tap(find.byType(FilledButton).last);
        await _tenang(tester);
        _bersihkanSnack(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await potret(tester, kunci, u, '05-lembar-terisi');

        expect(tester.takeException(), isNull);
      }, skip: lewati != null);
    }
  }

  // SEBELUM (1.0.819): kartu pilihan alat setelah foto -----------------------
  if (hanya == null || hanya == 'sebelum') {
    testWidgets('sebelum - 392', (tester) async {
      const u = _Ukuran('392', 392, 852, 1.0);
      aturLayar(tester, u);
      final kunci = GlobalKey();
      final d = _Dunia();
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => tampilkanPilihAlatRingkas(
                    context,
                    jenis: 'pH Meter',
                    alat: [_alat14, _a(21, 'B628755901')],
                  ),
                  child: const Text('foto'),
                ),
              ),
            ),
          ),
          dunia: d,
          u: u,
          kunci: kunci,
        ),
      );
      await tester.tap(find.text('foto'));
      await _tenang(tester);
      await potret(tester, kunci, u, '00-SEBELUM-1.0.819-kartu-pilih-alat');
    }, skip: lewati != null);
  }
}
