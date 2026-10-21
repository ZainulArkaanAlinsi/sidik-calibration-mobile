import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/daftar_paket_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/studio_acuan_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/pendaftaran_push.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_studio/data/status_server_service.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/inti/penimpaan.dart';
import 'package:sidik_studio/layar/beranda/beranda_screen.dart';
import 'package:sidik_studio/layar/cangkang_studio.dart';
import 'package:sidik_studio/layar/masuk_screen.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/widget/bilah_status.dart';

import 'pembantu/studio_uji.dart';

/// Sidik Studio S1: masuk, cangkang navigasi per ukuran (FR-STU-011), seksi
/// berizin (FR-STU-012), bilah status (FR-STU-013), Beranda (FR-STU-014), dan
/// putusnya kopling auth → push.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('masuk', () {
    testWidgets('tanpa token → layar masuk Studio, tanpa petunjuk akun uji', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true));
      await tenang(tester);

      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(find.text('Masuk ke Studio'), findsOneWidget);
      expect(find.text('Sidik Studio'), findsOneWidget);
      expect(find.text('BUILD DEV — akun uji'), findsNothing);
      expect(find.textContaining('rahasia123'), findsNothing);
      // ST-01: server yang dituju + versi Studio, teks kecil.
      expect(
        find.text('Server 127.0.0.1:8000 · Studio 0.1.0+1'),
        findsOneWidget,
      );
    });

    testWidgets('petunjuk akun uji cuma di build APP_ENV=dev', (tester) async {
      await pasangUkuran(tester, const Size(711, 1138));
      await tester.pumpWidget(studioUji(petunjukDev: true));
      await tenang(tester);

      expect(find.text('BUILD DEV — akun uji'), findsOneWidget);
    });

    testWidgets('isian kosong → pesan wajib, server tidak ditembak', (
      tester,
    ) async {
      final auth = AuthHitung();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, auth: auth));
      await tenang(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tenang(tester);

      expect(find.text('ID pegawai atau email wajib diisi.'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
      expect(auth.jumlahLogin, 0);
    });

    testWidgets('sandi salah → pesan server; benar → cangkang, Beranda', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true));
      await tenang(tester);

      await masukLewatLayar(tester, 'SDK-0001', 'salah');
      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(
        find.text('ID pegawai / email atau password salah.'),
        findsOneWidget,
      );

      await masukLewatLayar(tester, 'SDK-0001', 'rahasia123');
      expect(find.byType(CangkangStudio), findsOneWidget);
      expect(find.byType(BerandaScreen), findsOneWidget);
    });

    testWidgets('akun pelanggan → "bukan akun lab", bukan petunjuk app '
        'pelanggan', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, auth: _AuthPelanggan()));
      await tenang(tester);

      await masukLewatLayar(tester, 'pelanggan@contoh.id', 'rahasia123');

      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(
        find.text('Akun ini bukan akun lab. Studio hanya untuk orang lab.'),
        findsOneWidget,
      );
      expect(find.textContaining('SIDIK Pelanggan'), findsNothing);
    });

    testWidgets('akun lab lain → 403 bukan_akun_studio → "bukan akun Studio"', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, auth: _AuthBukanStudio()));
      await tenang(tester);

      await masukLewatLayar(tester, 'teknisi@contoh.id', 'rahasia123');

      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(find.text('Akun ini bukan akun Studio.'), findsOneWidget);
    });
  });

  group('cangkang', () {
    testWidgets('Windows: sidebar + bilah status; detail paket terbuka DI '
        'panel konten', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, token: 'mock-token-1'));
      await tenang(tester);

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BilahStatus), findsOneWidget);
      expect(find.byTooltip('Akun & status server'), findsNothing);
      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      // FR-STU-013: label peran Studio untuk admin = "Master Data".
      expect(find.text('Budi Santoso · Master Data'), findsOneWidget);
      expect(find.text('Server 127.0.0.1:8000'), findsOneWidget);
      expect(find.text('Tersambung'), findsOneWidget);
      expect(find.text('Realtime mati'), findsOneWidget);
      expect(find.text('API a1b2c3d'), findsOneWidget);

      await bukaSeksi(tester, SeksiStudio.dataAcuan);
      expect(find.byType(DaftarPaketAcuanScreen), findsOneWidget);

      await tester.tap(find.text('Micrometer'));
      await tenang(tester);

      // Navigator seksi: detail terbuka, sidebar tetap ada.
      expect(find.byType(StudioAcuanScreen), findsOneWidget);
      expect(navigasi(SeksiStudio.kelolaData), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tenang(tester);
      expect(find.byType(StudioAcuanScreen), findsNothing);
      expect(find.byType(DaftarPaketAcuanScreen), findsOneWidget);
    });

    testWidgets('tablet lanskap (1138): rail berlabel; status di menu akun', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1138, 711));
      await tester.pumpWidget(studioUji(token: 'mock-token-1'));
      await tenang(tester);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.labelType, NavigationRailLabelType.all);
      expect(rail.minWidth, 72);
      expect(find.byTooltip('Buka menu'), findsNothing);
      expect(find.byType(BilahStatus), findsNothing);
      expect(find.byType(BerandaScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Akun & status server'));
      await tenang(tester);
      expect(find.byType(RincianStatus), findsOneWidget);
      expect(find.text('Tersambung'), findsOneWidget);
      expect(find.text('Server 127.0.0.1:8000'), findsOneWidget);
      expect(find.text('Master Data · SDK-0001'), findsOneWidget);
    });

    testWidgets('tablet potret (711): rail ikon tanpa label, label di '
        'tooltip', (tester) async {
      await pasangUkuran(tester, const Size(711, 1138));
      await tester.pumpWidget(studioUji(token: 'mock-token-1'));
      await tenang(tester);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.labelType, NavigationRailLabelType.none);
      expect(rail.minWidth, 56);
      expect(find.byTooltip('Buka menu'), findsNothing);
      expect(find.byTooltip('Data acuan'), findsOneWidget);

      await bukaSeksi(tester, SeksiStudio.dataAcuan);
      expect(find.byType(DaftarPaketAcuanScreen), findsOneWidget);
    });

    testWidgets('lebih sempit dari 600: drawer di balik tombol menu', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(420, 860));
      await tester.pumpWidget(studioUji(token: 'mock-token-1'));
      await tenang(tester);

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(navigasi(SeksiStudio.dataAcuan), findsNothing);

      await tester.tap(find.byTooltip('Buka menu'));
      await tenang(tester);
      expect(_diLaci('Data acuan'), findsOneWidget);
      expect(_diLaci('Kelola data'), findsOneWidget);
      expect(_diLaci('Lembar hitung'), findsOneWidget);

      await tester.tap(_diLaci('Data acuan'));
      await tenang(tester);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(DaftarPaketAcuanScreen), findsOneWidget);
    });

    testWidgets('tata letak dipilih dari platform + ukuran', (tester) async {
      TataLetakStudio t(bool meja, double l, double h) =>
          tataLetakStudio(meja: meja, ukuran: Size(l, h));
      // Windows ≥ 1280 (dan sampai 1024) sidebar; < 1024 = tablet lanskap.
      expect(t(true, 1440, 900), TataLetakStudio.sidebar);
      expect(t(true, 1280, 800), TataLetakStudio.sidebar);
      expect(t(true, 1024, 700), TataLetakStudio.sidebar);
      expect(t(true, 1000, 800), TataLetakStudio.rail);
      expect(t(true, 700, 900), TataLetakStudio.rail);
      expect(t(false, 1138, 711), TataLetakStudio.rail);
      expect(t(false, 711, 1138), TataLetakStudio.railRingkas);
      expect(t(false, 360, 800), TataLetakStudio.laci);
      expect(t(true, 500, 800), TataLetakStudio.laci);
    });

    testWidgets('tema gelap bisa dinyalakan dari kaki sidebar', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, token: 'mock-token-1'));
      await tenang(tester);

      MaterialApp app() => tester.widget(find.byType(MaterialApp).first);
      expect(app().themeMode, ThemeMode.light);

      await tester.tap(find.byTooltip('Tema gelap'));
      await tenang(tester);
      expect(app().themeMode, ThemeMode.dark);
      expect(find.byTooltip('Tema terang'), findsOneWidget);
    });

    testWidgets('bilah status: server tak terjangkau disebut dengan teks', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          statusServer: MockLayananStatusServer(
            galat: const AuthException('Nggak bisa nyambung ke server.'),
          ),
        ),
      );
      await tenang(tester);

      expect(find.text('Tidak tersambung'), findsOneWidget);
      expect(find.textContaining('Realtime'), findsNothing);
      expect(find.textContaining('API '), findsNothing);
    });
  });

  group('Beranda', () {
    testWidgets('kartu data acuan: versi aktif per paket; buka → seksi', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, token: 'mock-token-1'));
      await tenang(tester);

      expect(
        find.text('Masuk sebagai Budi Santoso · Master Data'),
        findsOneWidget,
      );
      expect(find.text('Micrometer'), findsOneWidget);
      expect(find.text('Belum diimpor'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Buka'));
      await tenang(tester);
      expect(find.byType(DaftarPaketAcuanScreen), findsOneWidget);
      expect(find.byType(BerandaScreen), findsNothing);
    });
  });

  group('seksi tahap mendatang', () {
    testWidgets('sidebar: urut §2.2, berlabel tahap, nonaktif, tidak '
        'membuka apa pun', (tester) async {
      final semantik = tester.ensureSemantics();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          // Semua seksi tersedia boleh dibuka, supaya urutan lengkap terlihat.
          izin: const Izin(
            role: UserRole.admin,
            boleh: {NamaIzin.dataAcuanLihat, izinWorkbookLihat},
          ),
        ),
      );
      await tenang(tester);

      // Urutan: Beranda · Kelola · Acuan · Workbook · Lembar · Pengesahan ·
      // Impor · Pengaturan.
      final y = [
        for (final s in SeksiStudio.values) tester.getTopLeft(navigasi(s)).dy,
      ];
      expect(y, orderedEquals([...y]..sort()));

      for (final kode in ['S1', 'S2', 'S3', 'S4', 'S5']) {
        expect(find.text('Tahap $kode'), findsOneWidget, reason: kode);
      }

      await tester.tap(navigasi(SeksiStudio.kelolaData));
      await tester.tap(navigasi(SeksiStudio.lembarHitung));
      await tenang(tester);
      // Panel konten tetap Beranda — tidak ada layar tiruan.
      expect(find.byType(BerandaScreen), findsOneWidget);

      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Kelola data\.'))),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      expect(
        find.bySemanticsLabel(
          'Lembar hitung. Belum tersedia — dibangun di Tahap S4.',
        ),
        findsOneWidget,
      );
      semantik.dispose();
    });

    testWidgets('rail: tujuan tahap nonaktif', (tester) async {
      await pasangUkuran(tester, const Size(1138, 711));
      await tester.pumpWidget(studioUji(token: 'mock-token-1'));
      await tenang(tester);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.map((d) => d.disabled), [
        false, // beranda
        true, // kelola data S2
        false, // data acuan
        true, // lembar hitung S4
        true, // pengesahan S3
        true, // impor S5
        true, // pengaturan S1 (ST-T-017)
      ]);
      expect(rail.selectedIndex, 0);

      await tester.tap(navigasi(SeksiStudio.kelolaData));
      await tenang(tester);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );
    });
  });

  group('gerbang izin', () {
    testWidgets('tanpa data-acuan.lihat → seksi & kartu tidak tampil, server '
        'acuan tidak ditembak', (tester) async {
      final layanan = LayananAcuanHitung();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          izin: const Izin(role: UserRole.admin, boleh: {'lain.lain'}),
          layanan: layanan,
        ),
      );
      await tenang(tester);

      expect(navigasi(SeksiStudio.dataAcuan), findsNothing);
      expect(find.text('Data acuan'), findsNothing);
      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(find.text('Belum ada ringkasan untuk akun ini.'), findsOneWidget);
      expect(find.byType(DaftarPaketAcuanScreen), findsNothing);
      expect(layanan.daftarPaketDipanggil, 0);
      // Seksi tahap tetap terlihat (nonaktif) — peta jalan, bukan pintu.
      expect(navigasi(SeksiStudio.kelolaData), findsOneWidget);
    });

    testWidgets('izin gagal dimuat → pesan jujur + coba lagi', (tester) async {
      final izin = _IzinGagalSekali();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, token: 'mock-token-1', izinService: izin),
      );
      // Riverpod 3 mengulang FutureProvider yang gagal dengan jeda; tunggu
      // sampai ulangannya habis.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      await tenang(tester);

      expect(find.text('Izin akun gagal dimuat.'), findsOneWidget);
      expect(find.byType(BerandaScreen), findsNothing);

      izin.gagal = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Coba lagi'));
      await tenang(tester);
      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(navigasi(SeksiStudio.dataAcuan), findsOneWidget);
    });
  });

  group('akun & push', () {
    testWidgets('ganti akun: data acuan ditarik ulang, bukan sisa akun lama', (
      tester,
    ) async {
      final layanan = LayananAcuanHitung();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, layanan: layanan));
      await tenang(tester);

      await masukLewatLayar(tester, 'SDK-0001', 'rahasia123');
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(layanan.daftarPaketDipanggil, 1);

      await tester.tap(find.byTooltip('Keluar'));
      await tenang(tester);
      expect(find.byType(MasukStudioScreen), findsOneWidget);

      await masukLewatLayar(tester, 'SDK-0002', 'rahasia123');
      expect(find.text('Andi Pratama'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsNothing);
      expect(layanan.daftarPaketDipanggil, 2);
    });

    testWidgets('ganti akun: mendarat di Beranda, bukan seksi akun lama', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true));
      await tenang(tester);

      await masukLewatLayar(tester, 'SDK-0001', 'rahasia123');
      await bukaSeksi(tester, SeksiStudio.dataAcuan);
      expect(find.byType(DaftarPaketAcuanScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Keluar'));
      await tenang(tester);
      await masukLewatLayar(tester, 'SDK-0002', 'rahasia123');

      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(find.byType(DaftarPaketAcuanScreen), findsNothing);
    });

    testWidgets('keluar dari Studio tidak menyentuh pendaftaran push', (
      tester,
    ) async {
      final push = MockPendaftaranPush();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, token: 'mock-token-1', push: push),
      );
      await tenang(tester);

      await tester.tap(find.byTooltip('Keluar'));
      await tenang(tester);

      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(push.dicabut, isEmpty);
      expect(push.didaftarkan, isEmpty);
    });

    test('penimpaan Studio: sumber token push = TanpaTokenPush', () async {
      final wadah = ProviderContainer(overrides: penimpaanStudio);
      addTearDown(wadah.dispose);

      final sumber = wadah.read(sumberTokenPushProvider);
      expect(sumber, isA<TanpaTokenPush>());
      expect(await sumber.token(), isNull);
    });
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

Finder _diLaci(String teks) =>
    find.descendant(of: find.byType(Drawer), matching: find.text(teks));

class _IzinGagalSekali implements IzinService {
  bool gagal = true;

  @override
  Future<Izin> ambil(String token) async {
    if (gagal) throw const AuthException('Server tidak menjawab.');
    return const Izin(role: UserRole.admin, boleh: {NamaIzin.dataAcuanLihat});
  }
}

/// `POST /login` dengan akun pelanggan: `403 bukan_akun_internal`
/// (`AuthController::login`, repo API).
class _AuthPelanggan extends AuthHitung {
  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => throw const ApiException(
    'Akun ini terdaftar sebagai akun pelanggan. Silakan masuk lewat '
    'aplikasi SIDIK Pelanggan.',
    status: 403,
    body: {'kode': 'bukan_akun_internal'},
  );
}

/// `POST /login` dengan header Studio, akun lab lain: `403 bukan_akun_studio`.
class _AuthBukanStudio extends AuthHitung {
  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => throw const ApiException(
    'Akun ini tidak punya akses ke Sidik Studio.',
    status: 403,
    body: {'kode': 'bukan_akun_studio'},
  );
}
