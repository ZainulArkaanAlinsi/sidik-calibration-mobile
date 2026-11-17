// Beranda teknisi (layar 01 Kalibrasi) dalam tampilan Biru Awan, L7a.
//
// Melengkapi `kalibrasi_teknisi_test.dart` (tes lama, tidak diubah) dengan:
// keadaan PER BAGIAN (memuat, kosong, galat + Coba lagi, tanpa koneksi, data),
// kalimat judul (termasuk gerbang klaim "semua terkirim" oleh salinan lembar di
// HP), kurangi gerak, skala huruf 1,3 pada lebar 320, Semantics, sasaran sentuh
// >= 48 dp, "Mulai kalibrasi" tetap membuka alur yang ada, tombol "Pindai
// lembar kerja" yang tetap tersembunyi (tanpa memakan ruang), dan baris Draf
// mendatar yang bisa digeser dengan tetikus.
import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_spacing.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/l10n/app_localizations_en.dart';
import 'package:sidik_calibration/l10n/app_localizations_id.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/kalibrasi_teknisi_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/screens/calibration/category_picker_screen.dart';
import 'package:sidik_calibration/screens/notification/notification_screen.dart';
import 'package:sidik_calibration/screens/teknisi/kalibrasi_teknisi_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart'
    show KoneksiException;
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/kalibrasi_teknisi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/biru_awan/hero_langit.dart';
import 'package:sidik_calibration/widgets/biru_awan/lencana.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';
import 'package:sidik_calibration/widgets/tombol_pindai_lembar.dart';

import 'support/uji_biru_awan.dart';

typedef _Muat = Future<List<CalibrationHistoryItem>> Function();

CalibrationHistoryItem _sesi(
  int id,
  String alat,
  CalibrationStatus status, {
  String? nomor,
  String? pelanggan,
  String? catatan,
}) => CalibrationHistoryItem(
  id: id,
  namaAlat: alat,
  namaTeknisi: 'Teknisi Sidik',
  tanggalKalibrasi: DateTime(2026, 11, 3),
  status: status,
  nomorSesi: nomor,
  namaPelanggan: pelanggan,
  catatanRevisi: catatan,
);

/// Layanan teknisi dengan jawaban yang bisa diatur per daftar dan dihitung
/// pemanggilannya, supaya tiap bagian bisa dibuat memuat/gagal sendiri-sendiri.
class _Teknisi implements KalibrasiTeknisiService {
  _Teknisi({required this.revisi, required this.terkirim});

  final _Muat revisi;
  final _Muat terkirim;
  int panggilRevisi = 0;
  int panggilTerkirim = 0;

  @override
  Future<List<CalibrationHistoryItem>> perluRevisi(String token) {
    panggilRevisi++;
    return revisi();
  }

  @override
  Future<List<CalibrationHistoryItem>> terkirimTerakhir(
    String token, {
    int batas = 10,
  }) {
    panggilTerkirim++;
    return terkirim();
  }
}

class _Draf extends MockHistoryService {
  _Draf(this.muat);

  final _Muat muat;
  int panggil = 0;

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) {
    panggil++;
    return muat();
  }
}

/// Salinan lembar di HP (`mock-token-2` = pengguna 2). Bawaan: antre kirim,
/// belum punya sesi di server.
DrafLokal _salinan({
  int? sesiId,
  StatusDrafLokal status = StatusDrafLokal.belumTersinkron,
}) => DrafLokal(
  userId: 2,
  sesiId: sesiId,
  clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
  profil: 'ph_meter',
  disimpanPada: DateTime.utc(2026, 11, 16),
  status: status,
  kiriman: const {'status': 'draft'},
  isian: const {},
);

/// Simpanan HP yang pembacaannya GAGAL — di aplikasi nyata `daftar` tidak
/// pernah melempar; ini menguji gerbangnya terhadap provider yang galat.
class _SimpananGagal extends SimpananDrafLokalMemori {
  @override
  Future<List<DrafLokal>> daftar(int userId) async =>
      throw StateError('simpanan rusak');
}

/// Simpanan HP yang pembacaannya belum selesai sampai [tahan] dilunasi.
class _SimpananTahan extends SimpananDrafLokalMemori {
  _SimpananTahan(this.tahan);

  final Completer<List<DrafLokal>> tahan;

  @override
  Future<List<DrafLokal>> daftar(int userId) => tahan.future;
}

Future<List<CalibrationHistoryItem>> _kosong() async => const [];

/// Jawaban tetap [d] untuk satu daftar.
_Muat _tetap(List<CalibrationHistoryItem> d) =>
    () async => d;

Widget _app(
  _Teknisi teknisi,
  _Draf draf, {
  bool gelap = false,
  double skala = 1.0,
  bool kurangiGerak = false,
  bool notifKosong = true,

  /// Isi simpanan salinan lembar di HP; bawaan kosong (tidak menyentuh berkas).
  SimpananDrafLokal? simpanan,
}) => ProviderScope(
  overrides: <Override>[
    simpananDrafLokalProvider.overrideWithValue(
      simpanan ?? SimpananDrafLokalMemori(),
    ),
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-2'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    historyServiceProvider.overrideWithValue(draf),
    kalibrasiTeknisiServiceProvider.overrideWithValue(teknisi),
    categoryServiceProvider.overrideWithValue(MockCategoryService()),
    notificationServiceProvider.overrideWithValue(
      MockNotificationService(kosong: notifKosong),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: skala,
      maxScaleFactor: skala,
      child: kurangiGerak
          ? MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : child!,
    ),
    home: const KalibrasiTeknisiScreen(),
  ),
);

/// Semua isi layar muat di satu layar (tinggi besar), supaya daftar malas
/// ListView tidak menyembunyikan bagian yang diuji.
Future<void> _buka(
  WidgetTester tester,
  Widget app, {
  double lebar = 412,
  double tinggi = 3000,

  /// `false` = berhenti di bingkai pertama (untuk memeriksa gerak masuk).
  bool tunggu = true,
}) async {
  layarUji(tester, lebar: lebar, tinggi: tinggi);
  // Lepas dulu aplikasi sebelumnya: ProviderScope yang sama akan membawa
  // keadaan (data yang sudah dimuat) ke skenario berikutnya.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(app);
  if (!tunggu) return;
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Finder _teksRingkas(String teks) => find.text(teks, findRichText: true);

final _kunciMulai = find.byKey(const ValueKey('tombol-mulai-kalibrasi'));

/// Judul netral (bukan klaim): tulisan id `tekBerandaJudulNetral`.
const _netral = 'Lembar kerja kamu';

void main() {
  setUpAll(muatFontUji);

  _Teknisi teknisi({_Muat? revisi, _Muat? terkirim}) =>
      _Teknisi(revisi: revisi ?? _kosong, terkirim: terkirim ?? _kosong);

  group('keadaan per bagian', () {
    testWidgets(
      'memuat: kerangka diam di Draf dan Terkirim, Perlu revisi tidak '
      'dipajang, Mulai tetap ada; tanpa animasi berulang',
      (tester) async {
        final semantik = tester.ensureSemantics();
        final tahan = Completer<List<CalibrationHistoryItem>>();
        await _buka(
          tester,
          _app(
            teknisi(revisi: () => tahan.future, terkirim: () => tahan.future),
            _Draf(() => tahan.future),
          ),
          // `pumpAndSettle` harus selesai walau data belum datang: kerangka
          // tidak boleh menjadi animasi yang berputar terus.
        );

        expect(_kunciMulai, findsOneWidget);
        expect(find.byKey(const ValueKey('bagian-perlu-revisi')), findsNothing);
        expect(find.byKey(const ValueKey('bagian-draf')), findsOneWidget);
        expect(find.byKey(const ValueKey('bagian-terkirim')), findsOneWidget);
        // Dua bagian memuat, masing-masing diumumkan satu kali.
        expect(find.bySemanticsLabel('Memuat daftar'), findsNWidgets(2));
        expect(find.text('Belum ada draf.'), findsNothing);
        expect(find.text('Daftar ini gagal dimuat.'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        tahan.complete(const []);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Memuat daftar'), findsNothing);
        expect(find.text('Belum ada draf.'), findsOneWidget);
        semantik.dispose();
      },
    );

    testWidgets('kosong: tiap bagian punya kabarnya sendiri, tanpa angka 0 di '
        'judul; Perlu revisi tersembunyi', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      expect(find.byKey(const ValueKey('bagian-perlu-revisi')), findsNothing);
      expect(find.text('Belum ada draf.'), findsOneWidget);
      expect(find.text('Belum ada lembar yang dikirim.'), findsOneWidget);
      expect(_teksRingkas('Draf'), findsOneWidget);
      expect(_teksRingkas('Terkirim terakhir'), findsOneWidget);
      expect(_teksRingkas('Draf 0'), findsNothing);
      expect(_teksRingkas('Terkirim terakhir 0'), findsNothing);
    });

    testWidgets('galat satu bagian tidak menjatuhkan yang lain; Coba lagi '
        'memuat ulang HANYA bagian itu', (tester) async {
      var gagal = true;
      final draf = _Draf(() async {
        if (gagal) throw Exception('server nggak nyaut');
        return [_sesi(5, 'Autoclave', CalibrationStatus.draft)];
      });
      final lembar = teknisi(
        terkirim: () async => [
          _sesi(8, 'pH Meter', CalibrationStatus.menungguApproval),
        ],
      );
      await _buka(tester, _app(lembar, draf));

      final galat = find.descendant(
        of: find.byKey(const ValueKey('bagian-draf')),
        matching: find.text('Daftar ini gagal dimuat.'),
      );
      expect(galat, findsOneWidget);
      expect(find.text('Daftar ini gagal dimuat.'), findsOneWidget);
      // Bagian lain tetap menampilkan datanya.
      expect(
        find.byKey(const ValueKey('kartu-sesi-teknisi-8')),
        findsOneWidget,
      );
      expect(find.text('pH Meter'), findsOneWidget);
      // Sasaran sentuh Coba lagi >= 48 dp.
      final cobaLagi = find.widgetWithText(TombolSidik, 'Coba lagi');
      expect(cobaLagi, findsOneWidget);
      expect(tester.getSize(cobaLagi).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(cobaLagi).width, greaterThanOrEqualTo(48));
      final (draf0, revisi0, kirim0) = (
        draf.panggil,
        lembar.panggilRevisi,
        lembar.panggilTerkirim,
      );

      gagal = false;
      await tester.tap(cobaLagi);
      await tester.pumpAndSettle();

      expect(draf.panggil, draf0 + 1);
      expect(lembar.panggilRevisi, revisi0, reason: 'revisi tidak ikut');
      expect(lembar.panggilTerkirim, kirim0, reason: 'terkirim tidak ikut');
      expect(find.text('Daftar ini gagal dimuat.'), findsNothing);
      expect(
        find.byKey(const ValueKey('kartu-sesi-teknisi-5')),
        findsOneWidget,
      );
    });

    testWidgets('tanpa koneksi: kalimatnya beda dari galat biasa, tetap ada '
        'Coba lagi, dan bagian lain tidak ikut', (tester) async {
      final draf = _Draf(() async => throw const KoneksiException('putus'));
      await _buka(tester, _app(teknisi(), draf));

      final bagian = find.byKey(const ValueKey('bagian-draf'));
      expect(
        find.descendant(
          of: bagian,
          matching: find.text('Tanpa koneksi. Daftar ini belum bisa dimuat.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Daftar ini gagal dimuat.'), findsNothing);
      expect(
        find.descendant(of: bagian, matching: find.text('Coba lagi')),
        findsOneWidget,
      );
      // Terkirim (berhasil, kosong) tetap menampilkan kabarnya.
      expect(find.text('Belum ada lembar yang dikirim.'), findsOneWidget);
    });

    testWidgets('Perlu revisi: galat tetap dipajang dengan Coba lagi', (
      tester,
    ) async {
      var gagal = true;
      final lembar = teknisi(
        revisi: () async {
          if (gagal) throw Exception('server nggak nyaut');
          return [_sesi(7, 'Turbidimeter', CalibrationStatus.perluRevisi)];
        },
      );
      await _buka(tester, _app(lembar, _Draf(_kosong)));

      final bagian = find.byKey(const ValueKey('bagian-perlu-revisi'));
      expect(bagian, findsOneWidget);
      expect(
        find.descendant(
          of: bagian,
          matching: find.text('Daftar ini gagal dimuat.'),
        ),
        findsOneWidget,
      );

      gagal = false;
      await tester.tap(
        find.descendant(of: bagian, matching: find.text('Coba lagi')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('kartu-sesi-teknisi-7')),
        findsOneWidget,
      );
      expect(_teksRingkas('Perlu revisi 1'), findsOneWidget);
    });

    testWidgets('Perlu revisi: catatan Master Data ditulis UTUH, tidak '
        'dipotong', (tester) async {
      const catatan =
          'Ulangi titik 3, bacaan 2 meleset dari standar. Periksa ulang '
          'suhu ruang dan catat ulang pembacaan pada ketiga pengulangan '
          'sebelum dikirim kembali ke Master Data untuk diperiksa.';
      await _buka(
        tester,
        _app(
          teknisi(
            revisi: () async => [
              _sesi(
                7,
                'Turbidimeter',
                CalibrationStatus.perluRevisi,
                catatan: catatan,
              ),
            ],
          ),
          _Draf(_kosong),
        ),
        lebar: 360,
      );

      final paragraf = tester.renderObject<RenderParagraph>(find.text(catatan));
      expect(paragraf.didExceedMaxLines, isFalse);
      expect(paragraf.size.height, greaterThan(paragraf.text.style!.fontSize!));
    });
  });

  group('data dan kalimat judul', () {
    testWidgets('kalimat memakai angka dari daftar yang sama: "{n} draf belum '
        'dikirim. {m} kiriman terakhir menunggu approval."', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(
            terkirim: () async => [
              _sesi(
                20,
                'pH Meter',
                CalibrationStatus.menungguApproval,
                nomor: 'KAL/2026/11/0001',
              ),
              _sesi(21, 'Inkubator', CalibrationStatus.disetujui),
              _sesi(22, 'Pipet Ukur', CalibrationStatus.disetujui),
            ],
          ),
          _Draf(
            () async => [
              _sesi(1, 'Flow Meter Cairan', CalibrationStatus.draft),
              _sesi(2, 'Autoclave', CalibrationStatus.draft),
              _sesi(3, 'Thermohygrometer', CalibrationStatus.draft),
            ],
          ),
        ),
      );

      expect(
        _teksRingkas(
          '3 draf belum dikirim. 1 kiriman terakhir menunggu approval.',
        ),
        findsOneWidget,
      );
      expect(_teksRingkas('Draf 3'), findsOneWidget);
      expect(_teksRingkas('Terkirim terakhir 3'), findsOneWidget);
      // Sapaan memakai nama depan akun yang login.
      expect(find.textContaining('Halo, '), findsOneWidget);
      // Stempel: ikon + kata dari pemetaan status yang ada.
      expect(find.text('Menunggu approval'), findsOneWidget);
      expect(find.text('Disetujui'), findsNWidgets(2));
      expect(find.text('KAL/2026/11/0001'), findsOneWidget);
    });

    testWidgets('bagian bernilai 0 tidak ditulis', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(
            terkirim: () async => [
              _sesi(20, 'pH Meter', CalibrationStatus.menungguApproval),
            ],
          ),
          _Draf(_kosong),
        ),
      );
      expect(
        _teksRingkas('1 kiriman terakhir menunggu approval.'),
        findsOneWidget,
      );
      expect(find.textContaining('draf belum dikirim'), findsNothing);
      expect(find.textContaining('0 '), findsNothing);
    });

    testWidgets('semua kosong dan tak ada yang perlu revisi: "Semua lembar '
        'sudah terkirim."; ada yang perlu revisi: judul netral, bukan '
        'klaim', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));
      expect(_teksRingkas('Semua lembar sudah terkirim.'), findsOneWidget);

      await _buka(
        tester,
        _app(
          teknisi(
            revisi: () async => [
              _sesi(7, 'Turbidimeter', CalibrationStatus.perluRevisi),
            ],
          ),
          _Draf(_kosong),
        ),
      );
      expect(_teksRingkas('Semua lembar sudah terkirim.'), findsNothing);
      expect(_teksRingkas('Lembar kerja kamu'), findsOneWidget);
    });

    testWidgets('daftar belum terbaca / gagal: judul netral, tidak ada angka '
        'karangan', (tester) async {
      final tahan = Completer<List<CalibrationHistoryItem>>();
      await _buka(
        tester,
        _app(teknisi(terkirim: () => tahan.future), _Draf(() => tahan.future)),
      );
      expect(_teksRingkas('Lembar kerja kamu'), findsOneWidget);
      expect(_teksRingkas('Semua lembar sudah terkirim.'), findsNothing);
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('daftar yang gagal atau masih memuat TIDAK terbaca nol: tidak '
        'ikut kalimat dan tidak memicu "semua terkirim"', (tester) async {
      final tahan = Completer<List<CalibrationHistoryItem>>();
      final menunggu2 = _tetap([
        _sesi(20, 'pH Meter', CalibrationStatus.menungguApproval),
        _sesi(21, 'Inkubator', CalibrationStatus.menungguApproval),
      ]);
      final tigaDraf = _tetap([
        _sesi(1, 'Flow Meter Cairan', CalibrationStatus.draft),
        _sesi(2, 'Autoclave', CalibrationStatus.draft),
        _sesi(3, 'Thermohygrometer', CalibrationStatus.draft),
      ]);
      Future<List<CalibrationHistoryItem>> putus() async =>
          throw const KoneksiException('putus');

      // (keadaan, layanan teknisi, layanan draf, kalimat judul seutuhnya).
      // Kecocokan kalimat PERSIS: potongan yang tidak seharusnya ada merusaknya.
      final kasus = <(String, _Teknisi, _Draf, String)>[
        (
          'draf gagal + 2 menunggu',
          teknisi(terkirim: menunggu2),
          _Draf(putus),
          '2 kiriman terakhir menunggu approval.',
        ),
        (
          'draf memuat + 2 menunggu',
          teknisi(terkirim: menunggu2),
          _Draf(() => tahan.future),
          '2 kiriman terakhir menunggu approval.',
        ),
        (
          'terkirim gagal + 3 draf',
          teknisi(terkirim: putus),
          _Draf(tigaDraf),
          '3 draf belum dikirim.',
        ),
        ('draf gagal, lainnya kosong', teknisi(), _Draf(putus), _netral),
        (
          'terkirim gagal, lainnya kosong',
          teknisi(terkirim: putus),
          _Draf(_kosong),
          _netral,
        ),
        (
          'perlu revisi gagal, lainnya kosong',
          teknisi(revisi: putus),
          _Draf(_kosong),
          _netral,
        ),
      ];
      for (final (keadaan, lembar, draf, kalimat) in kasus) {
        await _buka(tester, _app(lembar, draf));
        expect(_teksRingkas(kalimat), findsOneWidget, reason: keadaan);
        expect(
          _teksRingkas('Semua lembar sudah terkirim.'),
          findsNothing,
          reason: keadaan,
        );
      }
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('"Semua lembar sudah terkirim." digerbangi salinan lembar di '
        'HP: ada isi, gagal terbaca, atau belum selesai -> judul netral; '
        'terbaca dan kosong -> klaim', (tester) async {
      final tahan = Completer<List<DrafLokal>>();
      final antre = SimpananDrafLokalMemori();
      await antre.simpan(_salinan());
      final ditolak = SimpananDrafLokalMemori();
      await ditolak.simpan(
        _salinan(sesiId: 5, status: StatusDrafLokal.perluDiperbaiki),
      );

      final kasus = <String, SimpananDrafLokal>{
        'ada lembar antre kirim': antre,
        'ada lembar ditolak server (perlu diperbaiki)': ditolak,
        'pembacaan simpanan gagal': _SimpananGagal(),
        'pembacaan simpanan belum selesai': _SimpananTahan(tahan),
      };
      for (final e in kasus.entries) {
        // Server bersih total: tanpa gerbang lokal klaim akan muncul.
        await _buka(tester, _app(teknisi(), _Draf(_kosong), simpanan: e.value));
        expect(_teksRingkas(_netral), findsOneWidget, reason: e.key);
        expect(
          _teksRingkas('Semua lembar sudah terkirim.'),
          findsNothing,
          reason: e.key,
        );
      }

      // Pembacaan terakhir (yang tertahan) selesai dan kosong: klaim muncul.
      tahan.complete(const []);
      await tester.pumpAndSettle();
      expect(_teksRingkas('Semua lembar sudah terkirim.'), findsOneWidget);
      expect(_teksRingkas(_netral), findsNothing);
    });

    test('kalimat "kiriman terakhir menunggu approval": id dan en, tunggal '
        'dan jamak', () {
      expect(
        AppLocalizationsId().tekBerandaKirimanMenunggu(10),
        '10 kiriman terakhir menunggu approval.',
      );
      expect(
        AppLocalizationsEn().tekBerandaKirimanMenunggu(1),
        '1 recent submission awaiting approval.',
      );
      expect(
        AppLocalizationsEn().tekBerandaKirimanMenunggu(10),
        '10 recent submissions awaiting approval.',
      );
    });

    testWidgets('Terkirim = baca saja: baris tidak membuka lembar dan tidak '
        'berupa tombol; draf membuka lembar', (tester) async {
      final semantik = tester.ensureSemantics();
      await _buka(
        tester,
        _app(
          teknisi(
            terkirim: () async => [
              _sesi(
                20,
                'pH Meter',
                CalibrationStatus.menungguApproval,
                nomor: 'KAL/2026/11/0001',
                pelanggan: 'PT Contoh',
              ),
            ],
          ),
          _Draf(
            () async => [
              _sesi(
                1,
                'Flow Meter Cairan',
                CalibrationStatus.draft,
                nomor: 'KAL/2026/11/0003',
                pelanggan: 'PT Contoh Kalibrasi Nusantara',
              ),
            ],
          ),
        ),
      );

      final baris = tester
          .getSemantics(find.byKey(const ValueKey('kartu-sesi-teknisi-20')))
          .getSemanticsData();
      expect(baris.label, contains('pH Meter'));
      expect(baris.label, contains('KAL/2026/11/0001'));
      expect(baris.label, contains('Menunggu approval'));
      expect(baris.hasAction(SemanticsAction.tap), isFalse);
      expect(baris.flagsCollection.isButton, isFalse);

      final kartu = tester
          .getSemantics(find.byKey(const ValueKey('kartu-sesi-teknisi-1')))
          .getSemanticsData();
      expect(kartu.label, contains('Flow Meter Cairan'));
      expect(kartu.label, contains('KAL/2026/11/0003'));
      expect(kartu.label, contains('PT Contoh Kalibrasi Nusantara'));
      expect(kartu.hasAction(SemanticsAction.tap), isTrue);
      expect(kartu.flagsCollection.isButton, isTrue);
      semantik.dispose();
    });
  });

  group('galat dan Coba lagi di KETIGA bagian', () {
    final bagian =
        <({String nama, String kunci, int id, CalibrationStatus status})>[
          (
            nama: 'Perlu revisi',
            kunci: 'bagian-perlu-revisi',
            id: 7,
            status: CalibrationStatus.perluRevisi,
          ),
          (
            nama: 'Draf',
            kunci: 'bagian-draf',
            id: 5,
            status: CalibrationStatus.draft,
          ),
          (
            nama: 'Terkirim',
            kunci: 'bagian-terkirim',
            id: 8,
            status: CalibrationStatus.menungguApproval,
          ),
        ];

    /// Layanan dengan HANYA bagian [kunci] yang memakai [muat]; sisanya kosong.
    (_Teknisi, _Draf) pasang(String kunci, _Muat muat) => (
      teknisi(
        revisi: kunci == 'bagian-perlu-revisi' ? muat : null,
        terkirim: kunci == 'bagian-terkirim' ? muat : null,
      ),
      _Draf(kunci == 'bagian-draf' ? muat : _kosong),
    );

    for (final b in bagian) {
      testWidgets('${b.nama}: tanpa koneksi dan galat biasa punya kalimat dan '
          'ikon masing-masing; bagian lain tidak ikut', (tester) async {
        for (final jaringan in [true, false]) {
          final Object rusak = jaringan
              ? const KoneksiException('putus')
              : Exception('server nggak nyaut');
          final (lembar, draf) = pasang(b.kunci, () async => throw rusak);
          await _buka(tester, _app(lembar, draf));

          const kabarJaringan = 'Tanpa koneksi. Daftar ini belum bisa dimuat.';
          const kabarUmum = 'Daftar ini gagal dimuat.';
          final (ada, tidak) = jaringan
              ? (kabarJaringan, kabarUmum)
              : (kabarUmum, kabarJaringan);
          final (ikonAda, ikonTidak) = jaringan
              ? (Icons.wifi_off, Icons.error_outline)
              : (Icons.error_outline, Icons.wifi_off);
          final area = find.byKey(ValueKey(b.kunci));
          final alasan = '${b.nama}, ${jaringan ? 'jaringan' : 'umum'}';

          expect(
            find.descendant(of: area, matching: find.text(ada)),
            findsOneWidget,
            reason: alasan,
          );
          expect(
            find.descendant(of: area, matching: find.text(tidak)),
            findsNothing,
            reason: alasan,
          );
          expect(
            find.descendant(of: area, matching: find.byIcon(ikonAda)),
            findsOneWidget,
            reason: alasan,
          );
          expect(
            find.descendant(of: area, matching: find.byIcon(ikonTidak)),
            findsNothing,
            reason: alasan,
          );
          // Satu bagian gagal: kabarnya cuma muncul satu kali di seluruh layar.
          expect(find.text(ada), findsOneWidget, reason: alasan);
          expect(find.text(tidak), findsNothing, reason: alasan);
        }
      });

      testWidgets('${b.nama}: Coba lagi memuat ulang HANYA bagian itu lewat '
          'providernya sendiri', (tester) async {
        var gagal = true;
        final (lembar, draf) = pasang(b.kunci, () async {
          if (gagal) throw Exception('server nggak nyaut');
          return [_sesi(b.id, 'Alat ${b.id}', b.status)];
        });
        await _buka(tester, _app(lembar, draf));

        final area = find.byKey(ValueKey(b.kunci));
        expect(
          find.descendant(
            of: area,
            matching: find.text('Daftar ini gagal dimuat.'),
          ),
          findsOneWidget,
        );
        final (r, d, t) = (
          lembar.panggilRevisi,
          draf.panggil,
          lembar.panggilTerkirim,
        );

        gagal = false;
        await tester.tap(
          find.descendant(of: area, matching: find.text('Coba lagi')),
        );
        await tester.pumpAndSettle();

        // Tepat satu permintaan baru, ke layanan bagian ini, dan tidak ada
        // yang lain: provider yang salah (mis. Draf untuk Terkirim) tampak di
        // sini sebagai hitungan yang meleset DAN bagian yang tetap galat.
        final seharusnya = switch (b.kunci) {
          'bagian-perlu-revisi' => (r + 1, d, t),
          'bagian-draf' => (r, d + 1, t),
          _ => (r, d, t + 1),
        };
        expect(
          (lembar.panggilRevisi, draf.panggil, lembar.panggilTerkirim),
          seharusnya,
          reason: b.nama,
        );
        expect(
          find.byKey(ValueKey('kartu-sesi-teknisi-${b.id}')),
          findsOneWidget,
          reason: b.nama,
        );
        expect(find.text('Daftar ini gagal dimuat.'), findsNothing);
      });
    }
  });

  group('baris Draf mendatar di layar lebar', () {
    final banyak = _tetap([
      for (var i = 1; i <= 8; i++)
        _sesi(i, 'Alat $i', CalibrationStatus.draft, nomor: 'KAL/$i'),
    ]);
    final area = find.byKey(const ValueKey('bagian-draf'));
    SingleChildScrollView baris(WidgetTester tester) =>
        tester.widget<SingleChildScrollView>(
          find.descendant(
            of: area,
            matching: find.byType(SingleChildScrollView),
          ),
        );

    testWidgets('bisa digeser dengan tetikus, sentuh, trackpad, dan stylus '
        '(Windows memakai layar ini)', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(banyak)), lebar: 1000);
      final pengendali = baris(tester).controller!;
      expect(pengendali.position.maxScrollExtent, greaterThan(0));

      for (final jenis in [
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      ]) {
        pengendali.jumpTo(0);
        await tester.pumpAndSettle();
        final jari = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('kartu-sesi-teknisi-1'))),
          kind: jenis,
        );
        await jari.moveBy(const Offset(-100, 0));
        await jari.moveBy(const Offset(-100, 0));
        await jari.up();
        await tester.pumpAndSettle();
        expect(pengendali.offset, greaterThan(0), reason: 'seret $jenis');
      }
    });

    testWidgets('Scrollbar memakai pengendali yang sama dengan barisnya, dan '
        'pengendali dibuang bersama layar', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(banyak)), lebar: 1000);
      final pengendali = baris(tester).controller!;
      final bilah = tester.widget<Scrollbar>(
        find.descendant(of: area, matching: find.byType(Scrollbar)),
      );
      expect(bilah.controller, same(pengendali));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => pengendali.addListener(() {}), throwsFlutterError);
    });
  });

  group('aksi yang sudah ada tetap jalan', () {
    testWidgets('"Mulai kalibrasi" tetap membuka alur pilih kategori', (
      tester,
    ) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      expect(find.text('Mulai kalibrasi'), findsOneWidget);
      await tester.tap(_kunciMulai);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryPickerScreen), findsOneWidget);
    });

    testWidgets('lonceng membuka layar notifikasi', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      await tester.tap(find.byType(LoncengBerlencana));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationScreen), findsOneWidget);
    });

    testWidgets('tombol Pindai tetap tersembunyi (tidak ada jenis yang '
        'boleh): tanpa tombol, tanpa ruang', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      expect(find.byKey(TombolPindaiLembar.kunciTombol), findsNothing);
      expect(find.text('Pindai lembar kerja'), findsNothing);
      expect(tester.getSize(find.byType(TombolPindaiLembar)).height, 0);
      // Tidak memakan ruang SAMA SEKALI, termasuk bantalan pembungkusnya: dari
      // dasar hero langsung selebar jarak antarbagian ke bagian berikutnya
      // (Perlu revisi kosong = tersembunyi, jadi itu Draf).
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('bagian-draf'))).dy -
            tester.getBottomLeft(find.byType(HeroLangit)).dy,
        moreOrLessEquals(AppSpacing.lg),
      );
      // Jalur manual utuh.
      expect(_kunciMulai, findsOneWidget);
    });

    testWidgets('tarik-segarkan: AlwaysScrollable dan meminta ketiga daftar '
        'lagi', (tester) async {
      final draf = _Draf(_kosong);
      final lembar = teknisi();
      await _buka(tester, _app(lembar, draf));

      expect(
        tester.widget<ListView>(find.byType(ListView)).physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );
      final (r0, d0, t0) = (
        lembar.panggilRevisi,
        draf.panggil,
        lembar.panggilTerkirim,
      );

      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();

      expect(
        (lembar.panggilRevisi, draf.panggil, lembar.panggilTerkirim),
        (r0 + 1, d0 + 1, t0 + 1),
      );
    });
  });

  group('gerak', () {
    testWidgets('kurangi gerak: hero dan bagian langsung utuh; tanpa itu '
        'masuk berurutan', (tester) async {
      Iterable<double> opasitas() => tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: _kunciMulai,
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value);

      // Dengan gerak: pada bingkai pertama hero masih transparan.
      await _buka(tester, _app(teknisi(), _Draf(_kosong)), tunggu: false);
      expect(opasitas().any((o) => o < 1), isTrue);
      await tester.pumpAndSettle();
      expect(opasitas().every((o) => o == 1), isTrue);

      // Kurangi gerak: sudah utuh pada bingkai pertama.
      await _buka(
        tester,
        _app(teknisi(), _Draf(_kosong), kurangiGerak: true),
        tunggu: false,
      );
      expect(opasitas(), isNotEmpty);
      expect(opasitas().every((o) => o == 1), isTrue);
      // Lunasi pewaktu tiruan masuknya akun sebelum tes berakhir.
      await tester.pumpAndSettle();
    });
  });

  group('tata letak dan aksesibilitas', () {
    final terkirimPanjang = _tetap([
      _sesi(
        20,
        'Pressure Transmitter dengan nama yang sangat panjang sekali',
        CalibrationStatus.menungguApproval,
        nomor: 'KAL/2026/11/0001',
        pelanggan: 'PT Perkebunan Nusantara Contoh Kalibrasi Sejahtera Abadi',
      ),
      _sesi(
        21,
        'Inkubator',
        CalibrationStatus.disetujui,
        nomor: 'KAL/2026/10/0021',
      ),
    ]);
    final revisiPanjang = _tetap([
      _sesi(
        7,
        'Turbidimeter dengan nama alat yang panjang',
        CalibrationStatus.perluRevisi,
        nomor: 'KAL/2026/11/0007',
        pelanggan: 'PT Contoh',
        catatan:
            'Ulangi titik 3, bacaan 2 meleset dari standar. Periksa '
            'ulang suhu ruang dan catat ulang pembacaan.',
      ),
    ]);
    final drafPanjang = _tetap([
      _sesi(
        1,
        'Flow Meter Cairan dengan nama yang panjang sekali',
        CalibrationStatus.draft,
        nomor: 'KAL/2026/11/0003',
        pelanggan: 'PT Contoh Kalibrasi Nusantara Sejahtera Abadi',
      ),
      _sesi(2, 'Autoclave', CalibrationStatus.draft, nomor: 'KAL/2026/11/0002'),
    ]);

    testWidgets('skala huruf 1,3 pada lebar 320 tanpa luapan: data lengkap, '
        'memuat, galat, tanpa koneksi (terang dan gelap)', (tester) async {
      final tahan = Completer<List<CalibrationHistoryItem>>();
      final keadaan = <String, (_Teknisi, _Draf)>{
        'data': (
          _Teknisi(revisi: revisiPanjang, terkirim: terkirimPanjang),
          _Draf(drafPanjang),
        ),
        'memuat': (
          _Teknisi(revisi: () => tahan.future, terkirim: () => tahan.future),
          _Draf(() => tahan.future),
        ),
        'galat': (
          _Teknisi(
            revisi: () async => throw Exception('x'),
            terkirim: () async => throw Exception('x'),
          ),
          _Draf(() async => throw Exception('x')),
        ),
        'tanpa koneksi': (
          _Teknisi(
            revisi: () async => throw const KoneksiException('putus'),
            terkirim: () async => throw const KoneksiException('putus'),
          ),
          _Draf(() async => throw const KoneksiException('putus')),
        ),
      };

      for (final gelap in [false, true]) {
        for (final e in keadaan.entries) {
          await _buka(
            tester,
            _app(e.value.$1, e.value.$2, gelap: gelap, skala: 1.3),
            lebar: 320,
            tinggi: 3200,
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                'luapan di 320 dp x 1,3 (${e.key}, ${gelap ? 'gelap' : 'terang'})',
          );
          // Tombol utama tetap utuh di dalam layar.
          expect(
            tester.getRect(_kunciMulai).right,
            lessThanOrEqualTo(320),
            reason: 'Mulai kalibrasi keluar layar (${e.key})',
          );
        }
      }
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('Semantics dan sasaran sentuh: judul bagian = header, Mulai = '
        'tombol aktif, lonceng membawa jumlah belum dibaca, semua sasaran >= '
        '48 dp dan berlabel', (tester) async {
      final semantik = tester.ensureSemantics();
      await _buka(
        tester,
        _app(
          _Teknisi(revisi: revisiPanjang, terkirim: terkirimPanjang),
          _Draf(
            () async => [
              _sesi(1, 'Autoclave', CalibrationStatus.draft, nomor: 'KAL/1'),
            ],
          ),
          notifKosong: false,
        ),
      );

      // Mulai kalibrasi: tombol aktif berlabel, aksi ketuk, tinggi >= 48.
      final mulai = tester
          .getSemantics(
            find.descendant(
              of: _kunciMulai,
              matching: find.byType(FilledButton),
            ),
          )
          .getSemanticsData();
      expect(mulai.label, contains('Mulai kalibrasi'));
      expect(mulai.flagsCollection.isButton, isTrue);
      expect(mulai.hasAction(SemanticsAction.tap), isTrue);
      expect(semantikAktif(mulai), isTrue);
      expect(tester.getSize(_kunciMulai).height, greaterThanOrEqualTo(48));

      // Lonceng: label membawa jumlah (lencana sendiri hiasan), 48 x 48.
      final lonceng = tester
          .getSemantics(find.byType(LoncengBerlencana))
          .getSemanticsData();
      expect(lonceng.label, matches(RegExp(r'^Notifikasi, \d+ belum dibaca$')));
      expect(lonceng.hasAction(SemanticsAction.tap), isTrue);
      final ukuran = tester.getSize(find.byType(LoncengBerlencana));
      expect(ukuran.width, greaterThanOrEqualTo(48));
      expect(ukuran.height, greaterThanOrEqualTo(48));

      // Judul bagian dan kalimat judul: header.
      for (final judul in ['Perlu revisi 1', 'Draf 1', 'Terkirim terakhir 2']) {
        final data = tester
            .getSemantics(_teksRingkas(judul))
            .getSemanticsData();
        expect(data.flagsCollection.isHeader, isTrue, reason: judul);
      }
      expect(
        tester
            .getSemantics(find.text('Mulai dari alat yang datang hari ini'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );

      // Kartu draf dan kartu revisi: sasaran >= 48.
      for (final id in [1, 7]) {
        expect(
          tester.getSize(find.byKey(ValueKey('kartu-sesi-teknisi-$id'))).height,
          greaterThanOrEqualTo(48),
        );
      }

      await periksaPedomanSentuh(tester);
      semantik.dispose();
    });

    testWidgets('lonceng tanpa kabar baru: label polos, tanpa lencana', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      expect(
        tester
            .getSemantics(find.byType(LoncengBerlencana))
            .getSemanticsData()
            .label,
        'Notifikasi',
      );
      expect(find.byType(Lencana), findsNothing);
      semantik.dispose();
    });

    testWidgets('hero: tombol navy tegas di atas langit, tema terang dan '
        'gelap', (tester) async {
      for (final gelap in [false, true]) {
        await _buka(tester, _app(teknisi(), _Draf(_kosong), gelap: gelap));
        final m = SidikMaterial.of(tester.element(_kunciMulai));
        final tombol = tester.widget<TombolSidik>(_kunciMulai);
        expect(tombol.ragam, RagamTombolSidik.tegas);
        final isi = tester
            .widget<FilledButton>(
              find.descendant(
                of: _kunciMulai,
                matching: find.byType(FilledButton),
              ),
            )
            .style!
            .backgroundColor!
            .resolve(<WidgetState>{});
        expect(isi, m.tinta, reason: gelap ? 'gelap' : 'terang');
      }
    });
  });
}
