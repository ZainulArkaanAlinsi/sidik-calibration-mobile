import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/models/jatuh_tempo.dart';
import 'package:sidik_calibration/models/pelacakan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/providers/pusat_pelanggan_provider.dart';
import 'package:sidik_calibration/screens/dashboard/beranda_super_admin.dart';
import 'package:sidik_calibration/screens/equipment/equipment_form_screen.dart';
import 'package:sidik_calibration/screens/jatuh_tempo/layar_jatuh_tempo.dart';
import 'package:sidik_calibration/screens/pelacakan/pelacakan_screen.dart';
import 'package:sidik_calibration/screens/pelanggan/pusat_pelanggan_screen.dart';
import 'package:sidik_calibration/screens/pengesahan/antrean_pengesahan_screen.dart';
import 'package:sidik_calibration/services/customer_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/pengesahan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/lewati_onboarding.dart';

// Token mock: 1 = admin, 2 = teknisi, 3 = viewer, 5 = super admin.
const _admin = 'mock-token-1';
const _teknisi = 'mock-token-2';
const _viewer = 'mock-token-3';
const _superAdmin = 'mock-token-5';

/// "Hari ini" semua test ini. Tanggal jatuh tempo di bawah dihitung dari sini;
/// tanpa jam yang dipatok, test merah tiap ganti hari.
final _hariIni = DateTime(2026, 9, 26);

Equipment _alat(
  int id,
  String nama, {
  required EquipmentStatus status,
  required DateTime? tempo,
  int pelangganId = 1,
  String pelanggan = 'PT Maju Jaya',
  String sn = 'SN-0',
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

/// Dua lewat jadwal (12 & 8 hari), satu dalam 30 hari, satu dalam 90 hari,
/// satu di luar jangkauan.
List<Equipment> _alatJatuhTempo() => [
  _alat(
    1,
    'Timbangan Ohaus',
    status: EquipmentStatus.overdue,
    tempo: DateTime(2026, 9, 14),
    sn: 'C3349',
  ),
  _alat(
    2,
    'Thermohygrometer Lutron',
    status: EquipmentStatus.overdue,
    tempo: DateTime(2026, 9, 18),
    pelangganId: 2,
    pelanggan: 'CV Sentosa Abadi',
  ),
  _alat(
    3,
    'Micrometer Mitutoyo',
    status: EquipmentStatus.aktif,
    tempo: DateTime(2026, 10, 5),
  ),
  _alat(
    4,
    'Viscometer Brookfield',
    status: EquipmentStatus.aktif,
    tempo: DateTime(2026, 12, 1),
    pelangganId: 2,
    pelanggan: 'CV Sentosa Abadi',
  ),
  _alat(
    5,
    'Oven Memmert',
    status: EquipmentStatus.aktif,
    tempo: DateTime(2027, 6, 1),
  ),
];

class _PelacakanSpy extends MockPelacakanService {
  final serah = <({int itemId, String tahap, String? kepada})>[];
  Object? galat;

  @override
  Future<void> tandaiTahapFisik(
    String token,
    int itemId, {
    required String tahap,
    String? kepada,
  }) async {
    if (galat != null) throw galat!;
    serah.add((itemId: itemId, tahap: tahap, kepada: kepada));
  }
}

/// Satu paket dengan alat di tiga tahap fisik yang berbeda.
class _PelacakanTigaTahap extends _PelacakanSpy {
  @override
  Future<(PaketLacak, List<LangkahGarisWaktu>)> detail(
    String token,
    int id,
  ) async {
    final (paket, garis) = await super.detail(token, id);
    return (
      PaketLacak(
        id: paket.id,
        nomor: paket.nomor,
        pelanggan: paket.pelanggan,
        tahap: 'sertifikat_terbit',
        tahapLabel: 'Sertifikat terbit',
        jumlahAlat: 3,
        jumlahSelesai: 3,
        alat: const [
          AlatDalamPaket(
            itemId: 1,
            nama: 'Alat Terbit',
            tahap: 'sertifikat_terbit',
            tahapLabel: 'Sertifikat terbit',
          ),
          AlatDalamPaket(
            itemId: 2,
            nama: 'Alat Siap',
            tahap: 'siap_diambil',
            tahapLabel: 'Siap diambil',
          ),
          AlatDalamPaket(
            itemId: 3,
            nama: 'Alat Serah',
            tahap: 'diserahkan',
            tahapLabel: 'Diserahkan',
            diserahkanKepada: 'Budi',
          ),
        ],
      ),
      garis,
    );
  }
}

/// Paket berjalan milik "PT Maju Jaya" (satu jalan, satu sudah diserahkan) dan
/// satu milik pelanggan lain yang terlambat.
class _PelacakanPelanggan extends MockPelacakanService {
  @override
  Future<List<PaketLacak>> daftar(
    String token, {
    String? cari,
    bool terlambat = false,
  }) async => const [
    PaketLacak(
      id: 34,
      nomor: 'ORD/2026/09/0034',
      pelanggan: 'PT Maju Jaya',
      tahap: 'dikalibrasi',
      tahapLabel: 'Dikalibrasi',
      jumlahAlat: 4,
      jumlahSelesai: 1,
    ),
    PaketLacak(
      id: 20,
      nomor: 'ORD/2026/09/0020',
      pelanggan: 'PT Maju Jaya',
      tahap: 'diserahkan',
      tahapLabel: 'Diserahkan',
      jumlahAlat: 2,
      jumlahSelesai: 2,
    ),
    PaketLacak(
      id: 35,
      nomor: 'ORD/2026/09/0035',
      pelanggan: 'CV Sentosa Abadi',
      terlambatHari: 3,
      tahap: 'dikalibrasi',
      tahapLabel: 'Dikalibrasi',
      jumlahAlat: 2,
      jumlahSelesai: 0,
    ),
  ];
}

List<Override> _semua({
  String token = _admin,
  List<Equipment>? alat,
  bool alatGagal = false,
  MockPelacakanService? pelacakan,
  MockCustomerService? pelanggan,
  MockPengesahanService? pengesahan,
  MockDashboardService? dashboard,
}) => [
  lewatiOnboarding,
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  jamProvider.overrideWithValue(() => _hariIni),
  dashboardServiceProvider.overrideWithValue(
    dashboard ?? MockDashboardService(jeda: Duration.zero),
  ),
  equipmentServiceProvider.overrideWithValue(
    MockEquipmentService(awal: alat ?? _alatJatuhTempo(), gagal: alatGagal),
  ),
  pelacakanServiceProvider.overrideWithValue(
    pelacakan ?? _PelacakanPelanggan(),
  ),
  pengesahanServiceProvider.overrideWithValue(
    pengesahan ?? MockPengesahanService(),
  ),
  customerServiceProvider.overrideWithValue(pelanggan ?? MockCustomerService()),
];

Widget _layar(
  Widget layar, {
  String token = _admin,
  List<Equipment>? alat,
  bool alatGagal = false,
  MockPelacakanService? pelacakan,
  MockCustomerService? pelanggan,
}) {
  return ProviderScope(
    overrides: _semua(
      token: token,
      alat: alat,
      alatGagal: alatGagal,
      pelacakan: pelacakan,
      pelanggan: pelanggan,
    ),
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: layar,
    ),
  );
}

Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Widget _appPenuh(
  String token, {
  List<Equipment>? alat,
  bool alatGagal = false,
  MockPelacakanService? pelacakan,
  MockPengesahanService? pengesahan,
  MockDashboardService? dashboard,
}) => ProviderScope(
  overrides: [
    ..._semua(
      token: token,
      alat: alat,
      alatGagal: alatGagal,
      pelacakan: pelacakan,
      pengesahan: pengesahan,
      dashboard: dashboard,
    ),
    pakaiPanelDesktopProvider.overrideWithValue(false),
  ],
  child: const SidikApp(),
);

Future<void> _pasangPenuh(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(500, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('susunJatuhTempo', () {
    RingkasanJatuhTempo susun(List<Equipment> a) =>
        susunJatuhTempo(a, DateTime(2026, 9, 26, 15, 40));

    test('hari ini belum lewat; kemarin sudah; jam tidak ikut dihitung', () {
      final r = susun([
        _alat(
          1,
          'hari ini',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 9, 26),
        ),
        _alat(
          2,
          'kemarin',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 9, 25),
        ),
      ]);

      expect(r.lewat.map((a) => a.alat.namaAlat), ['kemarin']);
      expect(r.lewat.single.hari, -1);
      expect(r.dalam30.map((a) => a.alat.namaAlat), ['hari ini']);
      expect(r.dalam30.single.hari, 0);
    });

    test('batas 30 dan 90 hari: rentang bertingkat, 91 hari dibuang', () {
      final r = susun([
        _alat(
          1,
          'h30',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 10, 26),
        ),
        _alat(
          2,
          'h31',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 10, 27),
        ),
        _alat(
          3,
          'h90',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 12, 25),
        ),
        _alat(
          4,
          'h91',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 12, 26),
        ),
      ]);

      expect(r.dalam30.map((a) => a.alat.namaAlat), ['h30']);
      // 90 hari MEMUAT yang 30 hari — sama seperti chip di desain.
      expect(r.dalam90.map((a) => a.alat.namaAlat), ['h30', 'h31', 'h90']);
    });

    test('lewat: paling lama dulu, tanggal tak dikenal di dasar, nonaktif '
        'dan id ganda dibuang', () {
      final r = susun([
        _alat(
          1,
          'baru',
          status: EquipmentStatus.overdue,
          tempo: DateTime(2026, 9, 20),
        ),
        _alat(2, 'tanpa tanggal', status: EquipmentStatus.overdue, tempo: null),
        _alat(
          3,
          'lama',
          status: EquipmentStatus.overdue,
          tempo: DateTime(2026, 8, 1),
        ),
        _alat(
          4,
          'nonaktif',
          status: EquipmentStatus.nonaktif,
          tempo: DateTime(2026, 1, 1),
        ),
        // Id sama datang dari dua permintaan (overdue lalu aktif).
        _alat(
          3,
          'lama',
          status: EquipmentStatus.aktif,
          tempo: DateTime(2026, 8, 1),
        ),
      ]);

      expect(r.lewat.map((a) => a.alat.namaAlat), [
        'lama',
        'baru',
        'tanpa tanggal',
      ]);
      expect(r.lewat.last.hari, isNull);
      expect(r.terlamaLewatHari, 56);
      expect(r.kosong, isFalse);
    });

    test('aktif tanpa tanggal tidak masuk kelompok mana pun', () {
      final r = susun([
        _alat(1, 'x', status: EquipmentStatus.aktif, tempo: null),
      ]);
      expect(r.kosong, isTrue);
      expect(r.terlamaLewatHari, isNull);
    });
  });

  group('Pelacakan: tandai siap diambil', () {
    Future<_PelacakanSpy> bukaDetail(
      WidgetTester tester,
      String token, {
      _PelacakanSpy? spy,
    }) async {
      final s = spy ?? _PelacakanSpy();
      await _pasang(
        tester,
        _layar(const PelacakanScreen(), token: token, pelacakan: s),
      );
      await tester.tap(find.text('ORD/2026/09/0034'));
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('admin: satu ketukan memanggil service dengan siap_diambil, '
        'tanpa dialog', (tester) async {
      final spy = await bukaDetail(tester, _admin);

      expect(find.byType(DetailPaketScreen), findsOneWidget);
      await tester.tap(find.text('Tandai siap diambil'));
      await tester.pumpAndSettle();

      expect(spy.serah, hasLength(1));
      expect(spy.serah.single.itemId, 1);
      expect(spy.serah.single.tahap, 'siap_diambil');
      // Nama penerima cuma untuk "diserahkan" — tidak ada dialog di sini.
      expect(spy.serah.single.kepada, isNull);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('super admin juga melihat tombolnya', (tester) async {
      await bukaDetail(tester, _superAdmin);
      expect(find.text('Tandai siap diambil'), findsOneWidget);
    });

    testWidgets('teknisi & viewer tidak melihatnya', (tester) async {
      for (final token in [_teknisi, _viewer]) {
        await bukaDetail(tester, token);
        expect(find.byType(DetailPaketScreen), findsOneWidget);
        expect(find.text('Tandai siap diambil'), findsNothing);
      }
    });

    testWidgets('hanya untuk alat yang baru bersertifikat: hilang sesudah '
        'siap diambil & diserahkan', (tester) async {
      await bukaDetail(tester, _admin, spy: _PelacakanTigaTahap());

      // Tiga alat: terbit (siap + serah), siap diambil (serah saja),
      // diserahkan (tak ada tombol sama sekali).
      expect(find.text('Tandai siap diambil'), findsOneWidget);
      expect(find.text('Tandai sudah diserahkan'), findsNWidgets(2));
    });

    testWidgets('galat dari server ditampilkan apa adanya di snackbar', (
      tester,
    ) async {
      final spy = _PelacakanSpy()
        ..galat = Exception('Alat belum bersertifikat.');
      await bukaDetail(tester, _admin, spy: spy);

      await tester.tap(find.text('Tandai siap diambil'));
      await tester.pumpAndSettle();

      expect(find.text('Alat belum bersertifikat.'), findsOneWidget);
      expect(spy.serah, isEmpty);
    });
  });

  group('Daftar jatuh tempo', () {
    testWidgets('ringkasan di judul, yang paling lama lewat di atas', (
      tester,
    ) async {
      await _pasang(tester, _layar(const DaftarJatuhTempoScreen()));

      expect(find.text('Jatuh tempo'), findsOneWidget);
      expect(find.text('2 alat lewat · 1 dalam 30 hari'), findsOneWidget);
      expect(find.text('Sudah lewat 2'), findsOneWidget);
      expect(find.text('30 hari ke depan 1'), findsOneWidget);
      expect(find.text('PER 26 SEP 2026'), findsOneWidget);
      expect(find.text('Lewat 12 hari'), findsOneWidget);
      expect(find.text('Lewat 8 hari'), findsOneWidget);

      final atas = tester.getTopLeft(find.text('Timbangan Ohaus')).dy;
      final bawah = tester.getTopLeft(find.text('Thermohygrometer Lutron')).dy;
      expect(atas, lessThan(bawah), reason: '12 hari lewat harus di atas 8');
      // Yang belum jatuh tempo tidak nyasar ke tab ini.
      expect(find.text('Micrometer Mitutoyo'), findsNothing);
    });

    testWidgets('tab 30 hari menampilkan yang akan datang, paling dekat dulu', (
      tester,
    ) async {
      await _pasang(tester, _layar(const DaftarJatuhTempoScreen()));

      await tester.tap(find.text('30 hari ke depan 1'));
      await tester.pumpAndSettle();

      expect(find.text('Micrometer Mitutoyo'), findsOneWidget);
      expect(find.text('9 hari lagi'), findsOneWidget);
      expect(find.text('Timbangan Ohaus'), findsNothing);
      // 66 hari lagi hanya ada di jadwal 90 hari, bukan di daftar ini.
      expect(find.text('Viscometer Brookfield'), findsNothing);
    });

    testWidgets('kosong: kalimat yang menenangkan, bukan layar polos', (
      tester,
    ) async {
      await _pasang(
        tester,
        _layar(const DaftarJatuhTempoScreen(), alat: const []),
      );

      expect(
        find.text('Tidak ada alat yang lewat jatuh tempo.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'gagal memuat: pesan + coba lagi yang benar-benar menarik ulang',
      (tester) async {
        await _pasang(
          tester,
          _layar(const DaftarJatuhTempoScreen(), alatGagal: true),
        );

        expect(find.text('Daftar jatuh tempo gagal dimuat.'), findsOneWidget);
        expect(find.text('Coba lagi'), findsOneWidget);
      },
    );

    testWidgets('mengetuk alat membuka form alat', (tester) async {
      await _pasang(tester, _layar(const DaftarJatuhTempoScreen()));

      await tester.tap(find.text('Timbangan Ohaus'));
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentFormScreen), findsOneWidget);
    });

    testWidgets('kartu jatuh tempo di dashboard admin membuka daftar ini', (
      tester,
    ) async {
      await _pasangPenuh(tester, _appPenuh(_admin));

      // Dashboard mock: 3 alat overdue → banner peringatan.
      await tester.tap(find.textContaining('3 alat'));
      await tester.pumpAndSettle();

      expect(find.byType(DaftarJatuhTempoScreen), findsOneWidget);
    });
  });

  group('Jadwal kalibrasi ulang', () {
    testWidgets('tiga rentang bertingkat dengan hitungannya', (tester) async {
      await _pasang(tester, _layar(const JadwalKalibrasiScreen()));

      expect(find.text('Jadwal kalibrasi ulang'), findsOneWidget);
      expect(find.text('Lewat jadwal 2'), findsOneWidget);
      expect(find.text('30 hari 1'), findsOneWidget);
      // 90 hari memuat yang 30 hari: 1 + 1.
      expect(find.text('90 hari 2'), findsOneWidget);

      await tester.tap(find.text('90 hari 2'));
      await tester.pumpAndSettle();

      expect(find.text('Micrometer Mitutoyo'), findsOneWidget);
      expect(find.text('Viscometer Brookfield'), findsOneWidget);
      expect(find.text('Oven Memmert'), findsNothing);
      expect(find.text('66 hari lagi'), findsOneWidget);
    });

    testWidgets('kosong per rentang menyebut rentangnya', (tester) async {
      await _pasang(
        tester,
        _layar(const JadwalKalibrasiScreen(), alat: const []),
      );

      await tester.tap(find.text('90 hari 0'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada alat yang jatuh tempo dalam 90 hari ke depan.'),
        findsOneWidget,
      );
    });
  });

  group('Pusat pelanggan', () {
    testWidgets('daftar dengan jumlah alat & lencana lewat jadwal', (
      tester,
    ) async {
      await _pasang(tester, _layar(const PusatPelangganScreen()));

      expect(find.text('Pusat pelanggan'), findsOneWidget);
      expect(find.text('2 pelanggan cocok'), findsOneWidget);
      expect(find.text('PT Maju Jaya'), findsOneWidget);
      expect(find.text('CV Sentosa Abadi'), findsOneWidget);
      expect(find.text('3 alat'), findsOneWidget);
      // Satu alat lewat jadwal per pelanggan (Ohaus → Maju Jaya, Lutron → Sentosa).
      expect(find.text('1 lewat jadwal'), findsNWidgets(2));
      expect(find.text('PIC Budi Santoso'), findsOneWidget);
    });

    testWidgets('mencari mengecilkan daftar; kata cari hidup di provider', (
      tester,
    ) async {
      await _pasang(tester, _layar(const PusatPelangganScreen()));

      await tester.enterText(find.byType(TextField), 'sentosa');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('1 pelanggan cocok'), findsOneWidget);
      expect(find.text('PT Maju Jaya'), findsNothing);

      // Realtime meng-invalidate daftar; kata cari tidak boleh ikut hilang.
      final wadah = ProviderScope.containerOf(
        tester.element(find.byType(PusatPelangganScreen)),
      );
      expect(wadah.read(kataCariPelangganProvider), 'sentosa');
      wadah.invalidate(pusatPelangganProvider);
      await tester.pumpAndSettle();
      expect(find.text('1 pelanggan cocok'), findsOneWidget);
    });

    testWidgets('tidak ada yang cocok', (tester) async {
      await _pasang(tester, _layar(const PusatPelangganScreen()));

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada pelanggan yang cocok.'), findsOneWidget);
    });

    testWidgets('server gagal: pesan + coba lagi', (tester) async {
      await _pasang(
        tester,
        _layar(
          const PusatPelangganScreen(),
          pelanggan: MockCustomerService(gagal: true),
        ),
      );

      expect(find.text('Daftar pelanggan gagal dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('detail: identitas, alat yang perlu kalibrasi, paket jalan', (
      tester,
    ) async {
      await _pasang(tester, _layar(const PusatPelangganScreen()));

      await tester.tap(find.text('PT Maju Jaya'));
      await tester.pumpAndSettle();

      expect(find.byType(DetailPelangganScreen), findsOneWidget);
      expect(find.text('Jl. Industri No. 5, Bekasi'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('021-9876543'), findsOneWidget);
      expect(find.text('budi@majujaya.co.id'), findsOneWidget);

      // Alat Maju Jaya: Ohaus (lewat) & Micrometer (9 hari); Oven di luar 90 hari.
      expect(find.text('Timbangan Ohaus'), findsOneWidget);
      expect(find.text('Micrometer Mitutoyo'), findsOneWidget);
      expect(find.text('Oven Memmert'), findsNothing);
      // Alat pelanggan lain tidak ikut.
      expect(find.text('Thermohygrometer Lutron'), findsNothing);

      // Paket berjalan: yang sudah diserahkan tidak dihitung.
      expect(find.text('ORD/2026/09/0034'), findsOneWidget);
      expect(find.text('ORD/2026/09/0020'), findsNothing);
      expect(find.text('ORD/2026/09/0035'), findsNothing);
    });

    testWidgets('detail: mengetuk paket membuka detail paketnya', (
      tester,
    ) async {
      await _pasang(tester, _layar(const PusatPelangganScreen()));
      await tester.tap(find.text('PT Maju Jaya'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ORD/2026/09/0034'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('ORD/2026/09/0034'));
      await tester.pumpAndSettle();

      expect(find.byType(DetailPaketScreen), findsOneWidget);
    });

    testWidgets('detail: pelanggan tanpa alat bermasalah & tanpa paket', (
      tester,
    ) async {
      await _pasang(
        tester,
        _layar(const PusatPelangganScreen(), alat: const []),
      );
      await tester.tap(find.text('CV Sentosa Abadi'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada alat yang lewat atau mendekati jatuh tempo.'),
        findsOneWidget,
      );
      // Satu paket CV Sentosa masih berjalan (terlambat), jadi bagian paket
      // tidak kosong.
      expect(find.text('ORD/2026/09/0035'), findsOneWidget);
    });
  });

  group('Beranda super admin', () {
    testWidgets('super admin dapat beranda sendiri: pengesahan, paket, '
        'perhatian, aksi', (tester) async {
      await _pasangPenuh(tester, _appPenuh(_superAdmin));

      expect(find.byType(BerandaSuperAdmin), findsOneWidget);
      expect(find.text('Halo, Eko Wibowo'), findsOneWidget);
      expect(find.text('MENUNGGU PENGESAHAN KAMU'), findsOneWidget);
      // Dua sesi di antrean mock.
      expect(find.text('2'), findsWidgets);
      expect(find.text('lembar kerja siap disahkan'), findsOneWidget);
      expect(find.textContaining('Tertua: Timbangan Analitik'), findsOneWidget);
      expect(find.text('Paket pelanggan berjalan'), findsOneWidget);
      // Dua paket berjalan (yang diserahkan disaring), satu terlambat.
      expect(find.text('PT Maju Jaya'), findsOneWidget);
      expect(find.text('CV Sentosa Abadi'), findsOneWidget);
      expect(
        find.text('2 alat pelanggan lewat jadwal kalibrasi'),
        findsOneWidget,
      );
      expect(find.text('Paling lama 12 hari.'), findsOneWidget);
      expect(find.text('1 alat jatuh tempo dalam 30 hari'), findsOneWidget);
      expect(find.text('1 paket melewati janji selesai'), findsOneWidget);
    });

    testWidgets('admin tetap dapat dashboard umum', (tester) async {
      await _pasangPenuh(tester, _appPenuh(_admin));

      expect(find.byType(BerandaSuperAdmin), findsNothing);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('tombol gerbang sertifikat membuka antrean pengesahan', (
      tester,
    ) async {
      await _pasangPenuh(tester, _appPenuh(_superAdmin));

      await tester.tap(find.text('Buka gerbang sertifikat'));
      await tester.pumpAndSettle();

      expect(find.byType(AntreanPengesahanScreen), findsOneWidget);
    });

    testWidgets('baris perhatian & aksi cepat membuka layar tujuannya', (
      tester,
    ) async {
      await _pasangPenuh(tester, _appPenuh(_superAdmin));

      await tester.tap(find.text('2 alat pelanggan lewat jadwal kalibrasi'));
      await tester.pumpAndSettle();
      expect(find.byType(DaftarJatuhTempoScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Semua paket'));
      await tester.pumpAndSettle();
      expect(find.byType(PelacakanScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Pusat pelanggan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Pusat pelanggan'));
      await tester.pumpAndSettle();
      expect(find.byType(PusatPelangganScreen), findsOneWidget);
    });

    testWidgets('antrean kosong & semuanya aman: tidak ada alarm palsu', (
      tester,
    ) async {
      await _pasangPenuh(
        tester,
        _appPenuh(
          _superAdmin,
          pengesahan: MockPengesahanService(awal: const []),
          alat: const [],
          pelacakan: _PelacakanKosong(),
        ),
      );

      expect(find.text('Tidak ada yang menunggu pengesahan.'), findsOneWidget);
      expect(find.text('Belum ada paket yang berjalan.'), findsOneWidget);
      expect(
        find.text('Tidak ada yang perlu diperhatikan sekarang.'),
        findsOneWidget,
      );
    });

    testWidgets('satu bagian gagal tidak menjatuhkan bagian lain', (
      tester,
    ) async {
      await _pasangPenuh(tester, _appPenuh(_superAdmin, alatGagal: true));

      // Jatuh tempo gagal → satu kartu galat; pengesahan & paket tetap tampil.
      expect(find.text('Bagian ini gagal dimuat.'), findsOneWidget);
      expect(find.text('lembar kerja siap disahkan'), findsOneWidget);
      expect(find.text('PT Maju Jaya'), findsOneWidget);
    });
  });
}

class _PelacakanKosong extends MockPelacakanService {
  @override
  Future<List<PaketLacak>> daftar(
    String token, {
    String? cari,
    bool terlambat = false,
  }) async => const [];
}
