import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:sidik_calibration/providers/arsip_provider.dart';
import 'package:sidik_calibration/screens/arsip/arsip_screen.dart';
import 'package:sidik_calibration/screens/arsip/garis_waktu_arsip_screen.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/services/arsip_service.dart';
import 'package:sidik_calibration/services/arsip_cari_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/master_detail_pane.dart';
import 'package:sidik_calibration/widgets/skeleton.dart';

import 'support/arsip_cari_uji.dart';

/// Layar Arsip menurut waktu + pencarian terpadu: keadaan kosong, memuat,
/// galat, hasil, cari tanpa hasil, penelusuran bertingkat, debounce, satu
/// baris per alat, pemisahan PT, dan tata letak HP vs tablet.
///
/// Data garis waktu mengikuti contoh kontrak API
/// `docs/perintah-frontend-arsip-cari.md` §3 (lihat `MockArsipCariService`).
/// Teks yang diharapkan ditulis literal — itu yang dibaca pengguna.
///
/// Yang TIDAK terbukti di sini: tampilan sebenarnya di tablet/HP (tidak ada
/// perangkat), dan golden (CI golden berjalan di macOS).

Iterable<String> _semuaTeks(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null) t.data!,
];

void main() {
  group('keadaan layar', () {
    testWidgets('kosong: arsip belum berisi dokumen', (tester) async {
      await bukaLayarArsip(tester, ServiceLayar(kosong: true));

      expect(find.text('Belum ada dokumen di sini.'), findsOneWidget);
      expect(find.text('Total 0 dokumen'), findsNothing);
    });

    testWidgets('memuat: kerangka tampil sampai jawaban datang', (
      tester,
    ) async {
      final service = ServiceLayar(jeda: const Duration(seconds: 5));
      ukuranLayar(tester, 800, 1200);
      SharedPreferences.setMockInitialValues({});
      final wadah = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('t')),
          authProvider.overrideWith(AuthUji.new),
          arsipCariServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(wadah.dispose);
      final langganan = wadah.listen<AsyncValue<User?>>(
        authProvider,
        (_, _) {},
      );
      addTearDown(langganan.close);
      await tester.runAsync(() => wadah.read(authProvider.future));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: wadah,
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GarisWaktuArsipScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.text('2026'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('galat jaringan: pesan + Coba lagi memanggil ulang', (
      tester,
    ) async {
      final service = ServiceLayar(gagal: true);
      await bukaLayarArsip(tester, service);

      expect(find.text('Gagal memuat arsip.'), findsOneWidget);
      expect(service.panggilanGarisWaktu, hasLength(1));

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(service.panggilanGarisWaktu, hasLength(2));
    });

    testWidgets('403: kalimat khusus, bukan "gagal" umum', (tester) async {
      final service = ServiceLayar()
        ..galatGarisWaktu = const ApiException('Terlarang', status: 403);
      await bukaLayarArsip(tester, service);

      expect(
        find.text('Akun ini tidak diizinkan melihat arsip ini.'),
        findsOneWidget,
      );
      expect(find.text('Gagal memuat arsip.'), findsNothing);
    });

    testWidgets('server belum mendukung: pesan jelas, TANPA Coba lagi', (
      tester,
    ) async {
      final service = ServiceLayar()
        ..galatGarisWaktu = const ServerBelumMendukungArsipException();
      await bukaLayarArsip(tester, service);

      expect(
        find.text(
          'Server belum mendukung pencarian arsip terpadu. Hubungi admin.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsNothing);
    });

    testWidgets('cari tanpa hasil: pesan memuat kata yang dicari', (
      tester,
    ) async {
      final service = ServiceLayar(sesi: const []);
      await bukaLayarArsip(tester, service);

      await cariDiKotak(tester, 'zzz-9');

      expect(find.text('Tidak ada hasil untuk "zzz-9".'), findsOneWidget);
      expect(
        find.textContaining('Periksa ejaannya'),
        findsOneWidget,
        reason: 'saran muncul hanya bila ada kata yang dicari',
      );
      expect(find.text('Gagal memuat arsip.'), findsNothing);
    });

    testWidgets('hasil kosong karena tanggal saja: pesan tanpa kata', (
      tester,
    ) async {
      final service = ServiceLayar(sesi: const []);
      final wadah = await bukaLayarArsip(tester, service);

      wadah
          .read(filterArsipProvider.notifier)
          .aturRentang(DateTime(2026, 11), DateTime(2026, 11, 15));
      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada sesi yang cocok dengan saringan ini.'),
        findsOneWidget,
      );
      expect(find.textContaining('Periksa ejaannya'), findsNothing);
    });
  });

  group('garis waktu bertingkat', () {
    testWidgets('tahun → bulan → pekan → hari, tiap tingkat dibuka bertahap', (
      tester,
    ) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);

      // Tingkat tahun: hanya SATU panggilan, hitungan dari server.
      expect(service.panggilanGarisWaktu, hasLength(1));
      expect(find.text('Total 6 dokumen'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('5 dokumen'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('Semua tahun'), findsNothing);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Oktober 2026'), findsOneWidget);
      // Jejak: tingkat sekarang tebal, yang di atasnya bisa diketuk.
      expect(find.text('Semua tahun'), findsOneWidget);

      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      // Pekan 44 hanya berisi 1 Nov — label persis dari server.
      expect(find.text('Pekan 46 (9–15 Nov 2026)'), findsOneWidget);
      expect(find.text('Pekan 44 (1 Nov 2026)'), findsOneWidget);

      await tester.tap(find.text('Pekan 46 (9–15 Nov 2026)'));
      await tester.pumpAndSettle();

      // Tingkat hari: kelompok per hari + dokumennya.
      expect(find.text('Kamis, 12 Nov 2026'), findsOneWidget);
      expect(find.text('Senin, 9 Nov 2026'), findsOneWidget);
      expect(find.text('CAL/2026/11/0005'), findsOneWidget);
      expect(find.text('CAL/2026/11/0004'), findsOneWidget);
      expect(find.text('No. Seri SN-0205'), findsOneWidget);
      expect(find.text('Order PO-2026-0042'), findsOneWidget);
      expect(find.text('Terbit 12 Nov 2026'), findsNWidgets(2));

      // Satu panggilan per tingkat, persis sesuai `telusuri` server.
      expect(service.panggilanGarisWaktu.map((p) => p.posisi.parameter), [
        {'tingkat': 'tahun'},
        {'tingkat': 'bulan', 'tahun': '2026'},
        {'tingkat': 'pekan', 'tahun': '2026', 'bulan': '11'},
        {'tingkat': 'hari', 'tahun': '2026', 'bulan': '11', 'pekan': '46'},
      ]);
    });

    testWidgets('jejak: ketuk tingkat di atas untuk naik', (tester) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Pekan 46 (9–15 Nov 2026)'), findsOneWidget);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();

      expect(find.text('Oktober 2026'), findsOneWidget);
      expect(find.text('Pekan 46 (9–15 Nov 2026)'), findsNothing);
    });

    testWidgets('tombol kembali sistem naik satu tingkat dulu', (tester) async {
      await bukaLayarArsip(tester, ServiceLayar());
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('Oktober 2026'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Layar masih ada, kembali ke daftar tahun.
      expect(find.byType(GarisWaktuArsipScreen), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('Oktober 2026'), findsNothing);
    });

    testWidgets('tingkat hari: PT terpisah dengan judul sendiri', (
      tester,
    ) async {
      await bukaLayarArsip(tester, ServiceLayar());
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pekan 46 (9–15 Nov 2026)'));
      await tester.pumpAndSettle();

      // Dua dokumen PT yang sama berurutan: satu judul, bukan dua.
      expect(find.text('PT Contoh Alfa'), findsOneWidget);
    });

    testWidgets('saringan PT dikirim ke server dan jalur kembali ke akar', (
      tester,
    ) async {
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('Oktober 2026'), findsOneWidget);

      wadah
          .read(filterArsipProvider.notifier)
          .aturPelanggan(3, 'PT Contoh Alfa');
      await tester.pumpAndSettle();

      expect(service.panggilanGarisWaktu.last.pelangganId, 3);
      expect(service.panggilanGarisWaktu.last.posisi.parameter, {
        'tingkat': 'tahun',
      });
      expect(find.text('Oktober 2026'), findsNothing);
      expect(find.text('2026'), findsOneWidget);
      // Chip menampilkan PT yang dipilih.
      expect(find.text('PT Contoh Alfa'), findsOneWidget);
    });
  });

  group('akun', () {
    testWidgets('ganti akun saat layar terpasang: isi akun lama tidak tampil '
        'selagi isi akun baru dimuat', (tester) async {
      final tahan = Completer<HalamanGarisWaktu>();
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);
      expect(find.text('2026'), findsOneWidget);

      service.garisKhusus = (posisi, pelangganId, halaman) => tahan.future;
      (wadah.read(authProvider.notifier) as AuthUji).ganti(akunUjiB);
      await tester.pump();
      await tester.pump();

      expect(find.text('2026'), findsNothing);
      expect(find.byType(SkeletonBox), findsWidgets);

      tahan.complete(
        await MockArsipCariService().garisWaktu(
          'token',
          posisi: PosisiGarisWaktu.akar,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget);
    });
  });

  group('pencarian terpadu', () {
    testWidgets('debounce 300 ms, lalu satu panggilan dengan kata apa adanya', (
      tester,
    ) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);

      await tester.enterText(find.byType(TextField).first, 'sn-0204');
      // Kontrak: jeda >= 300 ms. Tepat 1 ms sebelum batas belum memicu, tepat
      // di batas memicu — jeda 201–299 ms ikut tertangkap.
      await tester.pump(const Duration(milliseconds: 299));
      expect(service.panggilanRiwayat, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      // Tepat di batas 300 ms sudah memicu — diperiksa SEBELUM waktu maju lagi,
      // supaya jeda 301 ms pun tertangkap.
      await tester.pump();
      await tester.pump();
      expect(service.panggilanRiwayat, hasLength(1));
      await tester.pumpAndSettle();

      expect(service.panggilanRiwayat, hasLength(1));
      expect(service.panggilanRiwayat.single.filter.kataKirim, 'sn-0204');
      expect(service.panggilanRiwayat.single.halaman, 1);
      // Satu sesi cocok → kartu hasil, garis waktu disembunyikan.
      expect(find.text('Jangka Sorong'), findsOneWidget);
      expect(find.text('CAL/2026/11/0004'), findsOneWidget);
      expect(find.text('No. Seri SN-0204'), findsOneWidget);
      expect(find.text('Order PO-2026-0042'), findsOneWidget);
      expect(find.text('1 sesi cocok'), findsOneWidget);
      expect(find.text('2026'), findsNothing);
    });

    testWidgets('jumlah hasil diambil dari server, bukan dihitung di HP', (
      tester,
    ) async {
      final service = ServiceLayar()
        ..riwayatKhusus = (filter, halaman) async => HalamanRiwayat(
          baris: [
            sesiUji(
              9,
              alat: 'Jangka Sorong',
              seri: 'SN-1',
              sertifikat: 'CAL/2026/11/0009',
            ),
          ],
          halaman: 1,
          halamanTerakhir: 3,
          total: 120,
        );
      await bukaLayarArsip(tester, service);

      await cariDiKotak(tester, 'sn');

      // Baru satu baris termuat, tetapi server bilang 120 sesi cocok.
      expect(find.text('120 sesi cocok'), findsOneWidget);
      expect(find.text('1 sesi cocok'), findsNothing);
    });

    testWidgets('ketikan beruntun cepat hanya satu panggilan (yang terakhir)', (
      tester,
    ) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);
      final kotak = find.byType(TextField).first;

      await tester.enterText(kotak, 'sn');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(kotak, 'sn-');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(kotak, 'sn-02');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(service.panggilanRiwayat, hasLength(1));
      expect(service.panggilanRiwayat.single.filter.kataKirim, 'sn-02');
    });

    testWidgets('satu huruf: tidak ada pencarian, ada petunjuk', (
      tester,
    ) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);

      await cariDiKotak(tester, 'a');

      expect(service.panggilanRiwayat, isEmpty);
      expect(
        find.text('Ketik minimal 2 karakter untuk mencari.'),
        findsOneWidget,
      );
      // Tetap di garis waktu.
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('hapus pencarian: kembali ke garis waktu', (tester) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);
      await cariDiKotak(tester, 'sn-0204');
      expect(find.text('2026'), findsNothing);

      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    });

    testWidgets('rentang tanggal terkirim, kata tidak dipaksakan', (
      tester,
    ) async {
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);

      wadah
          .read(filterArsipProvider.notifier)
          .aturRentang(DateTime(2026, 11), DateTime(2026, 11, 15));
      await tester.pumpAndSettle();

      final filter = service.panggilanRiwayat.single.filter;
      expect(filter.dari, DateTime(2026, 11));
      expect(filter.sampai, DateTime(2026, 11, 15));
      expect(filter.kataKirim, isNull);
      // Chip tanggal menampilkan rentangnya.
      expect(find.text('1 Nov 2026 – 15 Nov 2026'), findsOneWidget);
    });

    testWidgets('Hapus semua saringan mengembalikan layar ke awal', (
      tester,
    ) async {
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);
      expect(find.text('Hapus semua saringan'), findsNothing);

      await cariDiKotak(tester, 'sn-0204');
      wadah.read(filterArsipProvider.notifier).aturPelanggan(3, 'PT A');
      await tester.pumpAndSettle();
      expect(find.text('Hapus semua saringan'), findsOneWidget);

      await tester.tap(find.text('Hapus semua saringan'));
      await tester.pumpAndSettle();

      expect(wadah.read(filterArsipProvider), FilterArsip.kosong);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Hapus semua saringan'), findsNothing);
    });

    testWidgets('pemilih PT: pilih PT → chip berubah dan terkirim ke server', (
      tester,
    ) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);

      await tester.tap(find.text('Semua PT'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih pelanggan (PT)'), findsOneWidget);
      expect(find.text('PT Maju Jaya'), findsOneWidget);

      await tester.tap(find.text('PT Maju Jaya'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih pelanggan (PT)'), findsNothing);
      expect(find.text('PT Maju Jaya'), findsOneWidget);
      expect(service.panggilanGarisWaktu.last.pelangganId, 1);
    });

    testWidgets('pemilih PT: mengetik menyaring daftar lewat server', (
      tester,
    ) async {
      await bukaLayarArsip(tester, ServiceLayar());
      await tester.tap(find.text('Semua PT'));
      await tester.pumpAndSettle();
      expect(find.text('PT Maju Jaya'), findsOneWidget);
      expect(find.text('PT Industri Presisi'), findsOneWidget);

      // Kotak cari kedua = milik lembar pemilih.
      await tester.enterText(find.byType(TextField).last, 'presisi');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('PT Industri Presisi'), findsOneWidget);
      expect(find.text('PT Maju Jaya'), findsNothing);
    });

    testWidgets('pemilih PT: "Semua PT" melepas PT yang terpilih', (
      tester,
    ) async {
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);
      wadah
          .read(filterArsipProvider.notifier)
          .aturPelanggan(2, 'CV Sentosa Abadi');
      await tester.pumpAndSettle();

      await tester.tap(find.text('CV Sentosa Abadi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua PT'));
      await tester.pumpAndSettle();

      expect(wadah.read(filterArsipProvider).pelangganId, isNull);
      expect(service.panggilanGarisWaktu.last.pelangganId, isNull);
    });

    testWidgets('batal memilih PT (tutup lembar) tidak mengubah saringan', (
      tester,
    ) async {
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);
      wadah.read(filterArsipProvider.notifier).aturPelanggan(2, 'CV Sentosa');
      await tester.pumpAndSettle();
      final sebelum = service.panggilanGarisWaktu.length;

      await tester.tap(find.text('CV Sentosa'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(wadah.read(filterArsipProvider).pelangganId, 2);
      expect(service.panggilanGarisWaktu.length, sebelum);
    });
  });

  group('bahasa Inggris', () {
    testWidgets('teks layar mengikuti bahasa aplikasi', (tester) async {
      await bukaLayarArsip(tester, ServiceLayar(), locale: const Locale('en'));

      expect(find.text('Archive timeline'), findsOneWidget);
      expect(find.text('6 documents in total'), findsOneWidget);
      expect(find.text('5 documents'), findsOneWidget);
      expect(find.text('All customers'), findsOneWidget);
      expect(find.text('Calibration date'), findsOneWidget);
      // Tidak ada sisa kalimat Indonesia.
      expect(find.text('Garis waktu arsip'), findsNothing);
      expect(find.text('Semua PT'), findsNothing);
    });
  });

  group('satu baris per alat & pemisahan PT', () {
    testWidgets('dua alat berseri "-" tampil sebagai dua baris', (
      tester,
    ) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar(
          sesi: [
            sesiUji(
              9,
              alat: 'Timbangan Analitik',
              seri: '-',
              sertifikat: 'CAL/2026/11/0001',
              alatId: 1,
            ),
            sesiUji(
              8,
              alat: 'Oven',
              seri: '-',
              sertifikat: 'CAL/2026/11/0002',
              alatId: 2,
            ),
          ],
        ),
      );

      await cariDiKotak(tester, 'CAL');

      expect(find.text('CAL/2026/11/0001'), findsOneWidget);
      expect(find.text('CAL/2026/11/0002'), findsOneWidget);
      expect(find.textContaining('sesi lain alat ini'), findsNothing);
    });

    testWidgets('wakil = sertifikat terbit terbaru walau sesi yang lebih baru '
        'masih draf; tombol menyebut jumlah sesi terlipat', (tester) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar(
          sesi: [
            const CalibrationHistoryItem(
              id: 12,
              namaAlat: 'Jangka Sorong',
              namaTeknisi: 'Dr. Arch Schaefer',
              status: CalibrationStatus.draft,
              nomorSeri: 'SN-0204',
              namaPelanggan: 'PT Contoh Alfa',
              equipmentId: 5,
            ),
            sesiUji(
              9,
              alat: 'Jangka Sorong',
              seri: 'SN-0204',
              sertifikat: 'CAL/2026/11/0009',
              alatId: 5,
            ),
            sesiUji(
              4,
              alat: 'Jangka Sorong',
              seri: 'SN-0204',
              sertifikat: 'CAL/2025/11/0004',
              alatId: 5,
            ),
          ],
        ),
      );

      await cariDiKotak(tester, 'sn');

      expect(find.text('CAL/2026/11/0009'), findsOneWidget);
      expect(find.text('CAL/2025/11/0004'), findsNothing);
      expect(find.text('2 sesi lain alat ini'), findsOneWidget);
    });
    final sesi = [
      sesiUji(
        9,
        alat: 'Jangka Sorong',
        seri: 'SN-0204',
        sertifikat: 'CAL/2026/11/0009',
      ),
      sesiUji(
        8,
        alat: 'Micrometer',
        seri: 'SN-0205',
        sertifikat: 'CAL/2026/11/0008',
        pt: 'PT Contoh Beta',
      ),
      sesiUji(
        7,
        alat: 'Jangka Sorong',
        seri: 'sn-0204',
        sertifikat: 'CAL/2025/11/0007',
        status: 'dibatalkan',
      ),
    ];

    testWidgets(
      'alat dengan nomor seri sama tampil sekali; sesi lain dilipat',
      (tester) async {
        await bukaLayarArsip(tester, ServiceLayar(sesi: sesi));

        await cariDiKotak(tester, 'sn');

        // Tiga sesi cocok (angka dari server), tetapi dua alat di layar.
        expect(find.text('3 sesi cocok'), findsOneWidget);
        expect(find.text('CAL/2026/11/0009'), findsOneWidget);
        expect(find.text('CAL/2026/11/0008'), findsOneWidget);
        expect(find.text('CAL/2025/11/0007'), findsNothing);
        expect(find.text('1 sesi lain alat ini'), findsOneWidget);
        expect(
          find.textContaining('Satu baris per alat'),
          findsOneWidget,
          reason: 'pengguna diberi tahu bahwa ada baris yang dilipat',
        );

        await tester.tap(find.text('1 sesi lain alat ini'));
        await tester.pumpAndSettle();
        expect(find.text('CAL/2025/11/0007'), findsOneWidget);
        expect(find.text('Tutup sesi lain'), findsOneWidget);

        await tester.tap(find.text('Tutup sesi lain'));
        await tester.pumpAndSettle();
        expect(find.text('CAL/2025/11/0007'), findsNothing);
      },
    );

    testWidgets('tiap PT punya judul sendiri; dengan satu PT dipilih judulnya '
        'hilang', (tester) async {
      final wadah = await bukaLayarArsip(tester, ServiceLayar(sesi: sesi));
      await cariDiKotak(tester, 'sn');

      expect(find.text('PT Contoh Alfa'), findsOneWidget);
      expect(find.text('PT Contoh Beta'), findsOneWidget);

      wadah
          .read(filterArsipProvider.notifier)
          .aturPelanggan(1, 'PT Contoh Alfa');
      await tester.pumpAndSettle();

      expect(find.text('PT Contoh Beta'), findsNothing);
      // Tinggal chip-nya.
      expect(find.text('PT Contoh Alfa'), findsOneWidget);
    });

    testWidgets('urutan server dipertahankan (tidak diurutkan ulang di HP)', (
      tester,
    ) async {
      await bukaLayarArsip(tester, ServiceLayar(sesi: sesi));
      await cariDiKotak(tester, 'sn');

      final atas = tester.getTopLeft(find.text('CAL/2026/11/0009')).dy;
      final bawah = tester.getTopLeft(find.text('CAL/2026/11/0008')).dy;
      expect(atas, lessThan(bawah));
    });
  });

  group('muat lebih banyak', () {
    testWidgets('tombol muncul bila masih ada halaman, lalu menempel', (
      tester,
    ) async {
      final service = ServiceLayar()
        ..riwayatKhusus = (filter, halaman) async => HalamanRiwayat(
          baris: [
            if (halaman == 1)
              sesiUji(
                9,
                alat: 'Jangka Sorong',
                seri: 'SN-1',
                sertifikat: 'CAL/2026/11/0009',
              )
            else
              sesiUji(
                8,
                alat: 'Micrometer',
                seri: 'SN-2',
                sertifikat: 'CAL/2026/11/0008',
              ),
          ],
          halaman: halaman,
          halamanTerakhir: 2,
          total: 2,
        );
      await bukaLayarArsip(tester, service);
      await cariDiKotak(tester, 'sn');

      expect(find.text('CAL/2026/11/0009'), findsOneWidget);
      expect(find.text('CAL/2026/11/0008'), findsNothing);

      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();

      expect(service.panggilanRiwayat.last.halaman, 2);
      expect(find.text('CAL/2026/11/0009'), findsOneWidget);
      expect(find.text('CAL/2026/11/0008'), findsOneWidget);
      // Halaman terakhir: tombol hilang.
      expect(find.text('Muat lebih banyak'), findsNothing);
    });

    testWidgets('halaman berikutnya gagal: pesan + tombol tetap ada', (
      tester,
    ) async {
      final service = ServiceLayar()
        ..riwayatKhusus = (filter, halaman) async {
          if (halaman == 2) throw Exception('putus');
          return HalamanRiwayat(
            baris: [
              sesiUji(
                9,
                alat: 'Jangka Sorong',
                seri: 'SN-1',
                sertifikat: 'CAL/2026/11/0009',
              ),
            ],
            halaman: 1,
            halamanTerakhir: 2,
            total: 2,
          );
        };
      await bukaLayarArsip(tester, service);
      await cariDiKotak(tester, 'sn');

      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal memuat halaman berikutnya. Ketuk untuk mencoba lagi.'),
        findsOneWidget,
      );
      expect(find.text('CAL/2026/11/0009'), findsOneWidget);
      expect(find.text('Muat lebih banyak'), findsOneWidget);
    });
  });

  group('tata letak HP dan tablet', () {
    final sesi = [
      sesiUji(
        9,
        alat: 'Jangka Sorong',
        seri: 'SN-0204',
        sertifikat: 'CAL/2026/11/0009',
      ),
    ];

    testWidgets('< 700 dp: satu daftar, tanpa panel detail; ketuk = buka '
        'layar detail', (tester) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar(sesi: sesi),
        lebar: 360,
        tinggi: 760,
      );
      await cariDiKotak(tester, 'sn');

      expect(find.byType(PanePlaceholder), findsNothing);
      expect(find.byType(CalibrationDetailScreen), findsNothing);

      await tester.tap(find.text('Jangka Sorong'));
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationDetailScreen), findsOneWidget);
      // Daftar tertutup oleh layar detail (bukan berdampingan).
      expect(find.byType(TextField).hitTestable(), findsNothing);
    });

    testWidgets('>= 700 dp: dua kolom; ketuk membuka detail di kanan', (
      tester,
    ) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar(sesi: sesi),
        lebar: 900,
        tinggi: 800,
      );
      await cariDiKotak(tester, 'sn');

      expect(find.byType(PanePlaceholder), findsOneWidget);
      expect(find.text('Belum ada sesi yang dipilih'), findsOneWidget);

      await tester.tap(find.text('Jangka Sorong'));
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationDetailScreen), findsOneWidget);
      expect(find.byType(PanePlaceholder), findsNothing);
      // Daftar tetap bisa dipakai di sebelahnya.
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
    });

    testWidgets('ambang tepat 700 dp memakai dua kolom', (tester) async {
      await bukaLayarArsip(tester, ServiceLayar(), lebar: 700, tinggi: 800);

      expect(find.byType(PanePlaceholder), findsOneWidget);
    });

    testWidgets('699 dp masih satu kolom', (tester) async {
      await bukaLayarArsip(tester, ServiceLayar(), lebar: 699, tinggi: 800);

      expect(find.byType(PanePlaceholder), findsNothing);
    });
  });

  group('pintu masuk', () {
    testWidgets('Arsip folder punya tombol Garis waktu yang membukanya', (
      tester,
    ) async {
      ukuranLayar(tester, 800, 1200);
      SharedPreferences.setMockInitialValues({});
      final wadah = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('t')),
          authProvider.overrideWith(AuthUji.new),
          arsipServiceProvider.overrideWithValue(MockArsipService()),
          arsipCariServiceProvider.overrideWithValue(ServiceLayar()),
        ],
      );
      addTearDown(wadah.dispose);
      final langganan = wadah.listen<AsyncValue<User?>>(
        authProvider,
        (_, _) {},
      );
      addTearDown(langganan.close);
      await tester.runAsync(() => wadah.read(authProvider.future));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: wadah,
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ArsipScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GarisWaktuArsipScreen), findsNothing);

      await tester.tap(find.byTooltip('Garis waktu arsip'));
      await tester.pumpAndSettle();

      expect(find.byType(GarisWaktuArsipScreen), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });
  });

  group('teks', () {
    testWidgets('tidak memakai istilah "Kedaluwarsa" di layar mana pun', (
      tester,
    ) async {
      final service = ServiceLayar();
      final wadah = await bukaLayarArsip(tester, service);

      final teks = <String>[..._semuaTeks(tester)];
      await cariDiKotak(tester, 'sn-0204');
      teks.addAll(_semuaTeks(tester));
      wadah.read(filterArsipProvider.notifier).bersihkan();
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      teks.addAll(_semuaTeks(tester));

      expect(teks, isNotEmpty);
      for (final t in teks) {
        expect(
          t.toLowerCase(),
          isNot(matches(RegExp('kedaluwarsa|kadaluarsa|expired'))),
          reason: 'keputusan K3 belum diambil: jangan pakai istilah itu',
        );
      }
    });

    test('kunci gw* ada di dua bahasa dan bebas istilah terlarang', () {
      Map<String, dynamic> baca(String berkas) =>
          jsonDecode(File('lib/l10n/$berkas').readAsStringSync())
              as Map<String, dynamic>;

      final id = baca('app_id.arb');
      final en = baca('app_en.arb');
      Set<String> kunciGw(Map<String, dynamic> m) => {
        for (final k in m.keys)
          if (k.startsWith('gw')) k,
      };

      expect(kunciGw(id), isNotEmpty);
      expect(kunciGw(id), kunciGw(en));

      for (final peta in [id, en]) {
        for (final k in kunciGw(peta)) {
          final nilai = (peta[k]).toString().toLowerCase();
          expect(
            nilai,
            isNot(matches(RegExp('kedaluwarsa|kadaluarsa|expired|expiry'))),
            reason: 'kunci $k',
          );
        }
      }
    });
  });
}
