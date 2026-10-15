import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/pelacakan.dart';
import 'package:sidik_calibration/models/penugasan.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/tanda_tangan_provider.dart';
import 'package:sidik_calibration/screens/pelacakan/pelacakan_screen.dart';
import 'package:sidik_calibration/screens/penugasan/penugasan_buat_screen.dart';
import 'package:sidik_calibration/screens/penugasan/penugasan_screen.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/screens/settings/tanda_tangan_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/penugasan_service.dart';
import 'package:sidik_calibration/services/tanda_tangan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/user_service.dart';

// Token mock: 1 = admin, 2 = teknisi, 3 = viewer, 5 = super admin.
const _admin = 'mock-token-1';
const _teknisi = 'mock-token-2';
const _viewer = 'mock-token-3';
const _superAdmin = 'mock-token-5';

// ── Pengganti service (merekam panggilan) ───────────────────────────────────


class _PelacakanSpy extends MockPelacakanService {
  static const paketTerlambat = PaketLacak(
    id: 35,
    nomor: 'ORD/2026/09/0035',
    pelanggan: 'CV Anugerah Kimia Utama',
    terlambatHari: 3,
    tahap: 'dikalibrasi',
    tahapLabel: 'Dikalibrasi',
    jumlahAlat: 2,
    jumlahSelesai: 0,
  );

  final daftarPanggilan = <bool>[];
  final serahTerima = <({int itemId, String tahap, String? kepada})>[];

  @override
  Future<List<PaketLacak>> daftar(
    String token, {
    String? cari,
    bool terlambat = false,
  }) async {
    daftarPanggilan.add(terlambat);
    final semua = [...await super.daftar(token), paketTerlambat];
    return terlambat
        ? semua.where((p) => p.terlambatHari != null).toList()
        : semua;
  }

  @override
  Future<void> tandaiTahapFisik(
    String token,
    int itemId, {
    required String tahap,
    String? kepada,
  }) async {
    serahTerima.add((itemId: itemId, tahap: tahap, kepada: kepada));
  }
}

class _PenugasanFake implements PenugasanService {
  final List<Penugasan> data = [
    const Penugasan(
      id: 7,
      judul: 'Kalibrasi minggu ini',
      tipe: 'grup',
      status: 'aktif',
      terlambat: false,
      persenTuntas: 29,
      teknisi: [
        AnggotaPenugasan(
          id: 2,
          nama: 'Andi Pratama',
          kode: 'AP',
          peran: 'ketua',
        ),
      ],
      baris: [
        BarisPenugasan(
          id: 1,
          jenisAlat: 'Autoklaf',
          jumlah: 4,
          jumlahSelesai: 2,
        ),
        BarisPenugasan(
          id: 2,
          jenisAlat: 'Timbangan analitik',
          jumlah: 3,
          jumlahSelesai: 0,
        ),
      ],
    ),
  ];

  final laporan = <({int barisId, int jumlah})>[];
  final dibuat =
      <({String judul, List<int> teknisi, List<BarisPenugasan> baris})>[];
  final dilihat = <int>[];

  @override
  Future<List<Penugasan>> daftar(String token, {String? status}) async =>
      List.of(data);

  @override
  Future<Penugasan> detail(String token, int id) async =>
      data.firstWhere((p) => p.id == id);

  @override
  Future<Penugasan> buat(
    String token, {
    required String judul,
    required List<int> teknisi,
    required List<BarisPenugasan> baris,
    DateTime? tanggalTarget,
    String? catatan,
  }) async {
    dibuat.add((judul: judul, teknisi: teknisi, baris: baris));
    final baru = Penugasan(
      id: 100 + dibuat.length,
      judul: judul,
      tipe: teknisi.length > 1 ? 'grup' : 'personal',
      status: 'aktif',
      terlambat: false,
      persenTuntas: 0,
      baris: baris,
    );
    data.insert(0, baru);
    return baru;
  }

  @override
  Future<Penugasan> laporProgres(
    String token,
    int barisId, {
    required int jumlahSelesai,
    String? catatan,
  }) async {
    laporan.add((barisId: barisId, jumlah: jumlahSelesai));
    final p = data.first;
    final baru = Penugasan(
      id: p.id,
      judul: p.judul,
      tipe: p.tipe,
      status: p.status,
      terlambat: p.terlambat,
      persenTuntas: p.persenTuntas,
      teknisi: p.teknisi,
      baris: [
        for (final b in p.baris)
          b.id == barisId
              ? BarisPenugasan(
                  id: b.id,
                  jenisAlat: b.jenisAlat,
                  jumlah: b.jumlah,
                  jumlahSelesai: jumlahSelesai,
                )
              : b,
      ],
    );
    data[0] = baru;
    return baru;
  }

  @override
  Future<void> tandaiDilihat(String token, int id) async => dilihat.add(id);
}

/// Cuma `daftar` yang dipakai layar buat penugasan (daftar teknisi).
class _UserFake implements UserService {
  @override
  Future<List<User>> daftar(String token, {String? status}) async => const [
    User(
      id: 2,
      nama: 'Andi Pratama',
      email: 'andi@pt-sidik.com',
      employeeId: 'SDK-0002',
      role: UserRole.teknisi,
      status: UserStatus.aktif,
      organizationId: 1,
      kodeTeknisi: 'AP',
    ),
    User(
      id: 4,
      nama: 'Hana Wijayanti',
      email: 'hana@pt-sidik.com',
      employeeId: 'SDK-0004',
      role: UserRole.teknisi,
      status: UserStatus.aktif,
      organizationId: 1,
      kodeTeknisi: 'HW',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Pembungkus ──────────────────────────────────────────────────────────────

class _Peluncur extends StatelessWidget {
  const _Peluncur({required this.tujuan});

  final Widget tujuan;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => tujuan)),
        child: const Text('buka-layar'),
      ),
    ),
  );
}

Widget _app(
  Widget home, {
  String token = _admin,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(
        MockAuthService(jeda: Duration.zero),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
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

void main() {
  group('Pelacakan paket', () {
    Future<_PelacakanSpy> buka(WidgetTester tester, String token) async {
      final spy = _PelacakanSpy();
      await _pasang(
        tester,
        _app(
          const PelacakanScreen(),
          token: token,
          overrides: [pelacakanServiceProvider.overrideWithValue(spy)],
        ),
      );
      return spy;
    }

    testWidgets('daftar paket tampil dengan progres & tahapnya', (
      tester,
    ) async {
      await buka(tester, _admin);

      expect(find.text('Pelacakan paket'), findsOneWidget);
      expect(find.text('ORD/2026/09/0034'), findsOneWidget);
      expect(find.text('ORD/2026/09/0035'), findsOneWidget);
      expect(find.text('1 dari 3 selesai'), findsWidgets);
      expect(find.text('Terlambat 3 hari'), findsOneWidget);
    });

    testWidgets('saringan "terlambat" menyempitkan daftar & bisa dilepas', (
      tester,
    ) async {
      final spy = await buka(tester, _admin);

      await tester.tap(find.text('Hanya yang terlambat'));
      await tester.pumpAndSettle();

      expect(spy.daftarPanggilan.last, isTrue);
      expect(find.text('ORD/2026/09/0034'), findsNothing);
      expect(find.text('ORD/2026/09/0035'), findsOneWidget);

      await tester.tap(find.text('Hanya yang terlambat'));
      await tester.pumpAndSettle();

      expect(spy.daftarPanggilan.last, isFalse);
      expect(find.text('ORD/2026/09/0034'), findsOneWidget);
    });

    testWidgets('membuka paket menampilkan garis waktu & alat di dalamnya', (
      tester,
    ) async {
      await buka(tester, _admin);
      await tester.tap(find.text('ORD/2026/09/0034'));
      await tester.pumpAndSettle();

      expect(find.byType(DetailPaketScreen), findsOneWidget);
      // Tujuh langkah garis waktu dari server.
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Menunggu pemeriksaan admin'), findsOneWidget);
      expect(find.text('Siap diambil'), findsOneWidget);
      expect(find.text('Diserahkan'), findsOneWidget);
      expect(find.text('Alat dalam paket (3)'), findsOneWidget);
      expect(find.text('Timbangan Analitik · Ohaus PX224'), findsOneWidget);
      expect(find.text('CAL/2026/09/0141'), findsOneWidget);
    });

    Future<_PelacakanSpy> bukaDialogSerahTerima(WidgetTester tester) async {
      final spy = await buka(tester, _admin);
      await tester.tap(find.text('ORD/2026/09/0034'));
      await tester.pumpAndSettle();

      // Hanya alat yang sudah bersertifikat yang bisa diserahkan.
      expect(find.text('Tandai sudah diserahkan'), findsOneWidget);
      await tester.tap(find.text('Tandai sudah diserahkan'));
      await tester.pumpAndSettle();
      return spy;
    }

    VoidCallback? Function(WidgetTester) simpanAktif() =>
        (tester) => tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Simpan serah terima'),
            )
            .onPressed;

    testWidgets(
      'tandai diserahkan: nama penerima kosong menahan tombol simpan',
      (tester) async {
        final spy = await bukaDialogSerahTerima(tester);
        final simpan = simpanAktif();

        expect(simpan(tester), isNull);
        await tester.enterText(find.byType(TextField).last, '   ');
        await tester.pump();
        expect(simpan(tester), isNull);

        await tester.enterText(find.byType(TextField).last, 'Budi');
        await tester.pump();
        expect(simpan(tester), isNotNull);

        await tester.enterText(find.byType(TextField).last, '');
        await tester.pump();
        expect(simpan(tester), isNull);
        expect(spy.serahTerima, isEmpty);
      },
    );

    // Penjaga bug 30 Sep 2026: `_serahkan` dulu membuang controller begitu
    // dialog di-pop, padahal animasi penutup dialog masih membangun TextField
    // → "TextEditingController was used after being disposed" tepat waktu
    // admin menyimpan serah terima. Controller kini milik State dialog
    // (`_DialogSerahTerima`); test ini merah lagi kalau pola itu kembali.
    testWidgets(
      'tandai diserahkan: nama penerima dikirim ke service (dipangkas)',
      (tester) async {
        final spy = await bukaDialogSerahTerima(tester);

        await tester.enterText(find.byType(TextField).last, ' Budi (QC) ');
        await tester.pump();
        await tester.tap(find.text('Simpan serah terima'));
        await tester.pumpAndSettle();

        expect(spy.serahTerima, hasLength(1));
        expect(spy.serahTerima.single.itemId, 1);
        expect(spy.serahTerima.single.tahap, 'diserahkan');
        expect(spy.serahTerima.single.kepada, 'Budi (QC)');
      },
    );

    testWidgets('teknisi & viewer tidak melihat tombol serah terima', (
      tester,
    ) async {
      for (final token in [_teknisi, _viewer]) {
        await buka(tester, token);
        await tester.tap(find.text('ORD/2026/09/0034'));
        await tester.pumpAndSettle();

        expect(find.text('Alat dalam paket (3)'), findsOneWidget);
        expect(find.text('Tandai sudah diserahkan'), findsNothing);

        // Buang pohon widget sebelum putaran berikutnya.
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('Penugasan', () {
    Future<_PenugasanFake> buka(WidgetTester tester, String token) async {
      final fake = _PenugasanFake();
      await _pasang(
        tester,
        _app(
          const PenugasanScreen(),
          token: token,
          overrides: [penugasanServiceProvider.overrideWithValue(fake)],
        ),
      );
      return fake;
    }

    Future<_PenugasanFake> bukaDetail(WidgetTester tester, String token) async {
      final fake = await buka(tester, token);
      await tester.tap(find.text('Kalibrasi minggu ini'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailPenugasanScreen), findsOneWidget);
      return fake;
    }

    testWidgets('admin & super admin melihat papan + tombol Tugaskan', (
      tester,
    ) async {
      for (final token in [_admin, _superAdmin]) {
        await buka(tester, token);

        expect(find.text('Penugasan'), findsOneWidget);
        expect(find.text('Tugas saya'), findsNothing);
        expect(find.text('Tugaskan'), findsOneWidget);
        expect(find.text('Kalibrasi minggu ini'), findsOneWidget);
        expect(find.text('4 Autoklaf · 3 Timbangan analitik'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('teknisi melihat "Tugas saya" tanpa tombol Tugaskan', (
      tester,
    ) async {
      await buka(tester, _teknisi);

      expect(find.text('Tugas saya'), findsOneWidget);
      expect(find.text('Tugaskan'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Kalibrasi minggu ini'), findsOneWidget);
    });

    testWidgets('Tugaskan membuka layar buat penugasan', (tester) async {
      await buka(tester, _admin);
      await tester.tap(find.text('Tugaskan'));
      await tester.pumpAndSettle();

      expect(find.byType(PenugasanBuatScreen), findsOneWidget);
    });

    testWidgets('detail: tombol + / − melapor progres ke service', (
      tester,
    ) async {
      final fake = await bukaDetail(tester, _teknisi);

      // Membuka detail = tandai dilihat, sekali.
      expect(fake.dilihat, [7]);
      expect(find.text('2 dari 4 selesai'), findsOneWidget);
      expect(find.text('0 dari 3 selesai'), findsOneWidget);

      await tester.tap(find.byTooltip('Tambah').first);
      await tester.pumpAndSettle();
      expect(fake.laporan.last, (barisId: 1, jumlah: 3));
      expect(find.text('3 dari 4 selesai'), findsOneWidget);

      await tester.tap(find.byTooltip('Kurangi').first);
      await tester.pumpAndSettle();
      expect(fake.laporan.last, (barisId: 1, jumlah: 2));
      expect(find.text('2 dari 4 selesai'), findsOneWidget);
      expect(fake.laporan, hasLength(2));
    });

    testWidgets('detail: tombol − mati di nol dan tidak melapor', (
      tester,
    ) async {
      final fake = await bukaDetail(tester, _teknisi);

      final kurangi = find.widgetWithIcon(
        IconButton,
        Icons.remove_circle_outline,
      );
      expect(kurangi, findsNWidgets(2));
      expect(tester.widget<IconButton>(kurangi.at(0)).onPressed, isNotNull);
      // Baris "Timbangan analitik" baru 0 dari 3.
      expect(tester.widget<IconButton>(kurangi.at(1)).onPressed, isNull);

      await tester.tap(kurangi.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fake.laporan, isEmpty);
    });

    testWidgets('detail: admin boleh melapor', (tester) async {
      await bukaDetail(tester, _admin);
      expect(find.byTooltip('Tambah'), findsNWidgets(2));
    });

    // K-49-14 (15 Okt 2026): super admin memegang semua aksi admin & teknisi.
    testWidgets('detail: super admin boleh melapor', (tester) async {
      await bukaDetail(tester, _superAdmin);
      expect(find.byTooltip('Tambah'), findsNWidgets(2));
    });

    testWidgets('detail: viewer TIDAK bisa melapor', (tester) async {
      for (final token in [_viewer]) {
        await bukaDetail(tester, token);

        expect(find.text('Rincian pekerjaan'), findsOneWidget);
        expect(find.byTooltip('Tambah'), findsNothing);
        expect(find.byTooltip('Kurangi'), findsNothing);

        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('Buat penugasan', () {
    Future<_PenugasanFake> buka(WidgetTester tester) async {
      final fake = _PenugasanFake();
      await _pasang(
        tester,
        _app(
          const _Peluncur(tujuan: PenugasanBuatScreen()),
          overrides: [
            penugasanServiceProvider.overrideWithValue(fake),
            userServiceProvider.overrideWithValue(_UserFake()),
          ],
        ),
      );
      await tester.tap(find.text('buka-layar'));
      await tester.pumpAndSettle();
      expect(find.byType(PenugasanBuatScreen), findsOneWidget);
      return fake;
    }

    Future<void> kirim(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Kirim penugasan'));
      await tester.tap(find.text('Kirim penugasan'));
      await tester.pumpAndSettle();
    }

    Future<void> isiJudul(WidgetTester tester) => tester.enterText(
      find.widgetWithText(TextField, 'Judul'),
      'Order PT Maju',
    );

    Future<void> isiJenis(WidgetTester tester) => tester.enterText(
      find.widgetWithText(TextField, 'Jenis alat'),
      'Jangka sorong',
    );

    testWidgets('tanpa judul: ditolak dengan pesan, tidak ada yang terkirim', (
      tester,
    ) async {
      final fake = await buka(tester);
      await kirim(tester);

      expect(find.text('Isi judul penugasan.'), findsOneWidget);
      expect(fake.dibuat, isEmpty);
      expect(find.byType(PenugasanBuatScreen), findsOneWidget);
    });

    testWidgets('tanpa teknisi: ditolak', (tester) async {
      final fake = await buka(tester);
      await isiJudul(tester);
      await isiJenis(tester);
      await kirim(tester);

      expect(find.text('Pilih minimal satu teknisi.'), findsOneWidget);
      expect(fake.dibuat, isEmpty);
    });

    testWidgets('tanpa baris alat: ditolak', (tester) async {
      final fake = await buka(tester);
      await isiJudul(tester);
      await tester.tap(find.text('AP'));
      await tester.pump();
      await kirim(tester);

      expect(
        find.text('Isi minimal satu jenis alat beserta jumlahnya.'),
        findsOneWidget,
      );
      expect(fake.dibuat, isEmpty);
    });

    testWidgets('jumlah 0 dianggap bukan baris', (tester) async {
      final fake = await buka(tester);
      await isiJudul(tester);
      await isiJenis(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah'), '0');
      await tester.tap(find.text('AP'));
      await tester.pump();
      await kirim(tester);

      expect(
        find.text('Isi minimal satu jenis alat beserta jumlahnya.'),
        findsOneWidget,
      );
      expect(fake.dibuat, isEmpty);
    });

    testWidgets('teknisi pertama yang dipilih ditandai ketua', (tester) async {
      await buka(tester);
      await tester.tap(find.text('HW'));
      await tester.pump();
      await tester.tap(find.text('AP'));
      await tester.pump();

      expect(find.text('HW · Ketua'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);
    });

    testWidgets('form valid memanggil service tepat sekali lalu kembali', (
      tester,
    ) async {
      final fake = await buka(tester);
      await isiJudul(tester);
      await tester.tap(find.text('HW'));
      await tester.pump();
      await tester.tap(find.text('AP'));
      await tester.pump();
      await isiJenis(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah'), '12');
      await kirim(tester);

      expect(fake.dibuat, hasLength(1));
      final k = fake.dibuat.single;
      expect(k.judul, 'Order PT Maju');
      // Urutan pilihan dipertahankan: HW (id 4) ketua, lalu AP (id 2).
      expect(k.teknisi, [4, 2]);
      expect(k.baris, hasLength(1));
      expect(k.baris.single.jenisAlat, 'Jangka sorong');
      expect(k.baris.single.jumlah, 12);
      // Layar menutup sendiri → kembali ke peluncur.
      expect(find.byType(PenugasanBuatScreen), findsNothing);
      expect(find.text('buka-layar'), findsOneWidget);
    });
  });

  group('Kelola lab', () {
    const judulPintu = [
      'Pelanggan',
      'Standar Acuan',
      'Data Teknisi',
      'Metode Kalibrasi',
      'Rumus Kalibrasi',
      'Ruangan Lab',
      'Tanda Tangan Sertifikat',
      'Data Organisasi',
      'Import Excel',
    ];

    testWidgets('sembilan pintu dalam tiga grup', (tester) async {
      await _pasang(tester, _app(const KelolaLabScreen()));

      expect(find.text('Kelola lab'), findsOneWidget);
      for (final grup in [
        'DATA MASTER',
        'METODE & RUANGAN',
        'DOKUMEN & SISTEM',
      ]) {
        expect(find.text(grup), findsOneWidget);
      }
      for (final judul in judulPintu) {
        expect(find.text(judul), findsOneWidget, reason: judul);
      }
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(9));
    });

    testWidgets('mengetuk pintu mendorong layar tujuan', (tester) async {
      await _pasang(
        tester,
        _app(
          const KelolaLabScreen(),
          overrides: [
            tandaTanganServiceProvider.overrideWithValue(
              MockTandaTanganService(),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Tanda Tangan Sertifikat'));
      await tester.pumpAndSettle();

      expect(find.byType(TandaTanganScreen), findsOneWidget);
      // Layar induk tetap di bawahnya (push, bukan replace).
      expect(find.byType(KelolaLabScreen, skipOffstage: false), findsOneWidget);
    });
  });
}
