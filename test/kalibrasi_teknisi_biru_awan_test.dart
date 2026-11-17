// Beranda teknisi (layar 01 Kalibrasi), REVISI 16 Nov 2026 (R1, REVISI-1 §7):
// area kerja ringkas "Pekerjaan saya" menggantikan banner besar dan carousel.
//
// Melengkapi `kalibrasi_teknisi_test.dart` (tes lama, tidak diubah) dengan:
// keadaan PER BAGIAN (memuat, kosong, galat + Coba lagi, tanpa koneksi, data),
// ringkasan tiga angka (draf, perlu revisi, menunggu pemeriksaan: angka dari
// daftar yang sama, "-" bukan 0 untuk daftar yang belum terbaca, dasar hitungan
// "dari {n} kiriman terakhir"), klaim "semua terkirim" yang digerbangi salinan
// lembar di HP, DRAF = DAFTAR VERTIKAL (bukan carousel) dengan nama alat,
// pelanggan, nomor kalibrasi, waktu pembaruan, dan status per item, kurangi
// gerak, skala huruf 1,3 pada lebar 320, Semantics, sasaran sentuh >= 48 dp,
// "Kalibrasi baru" tetap membuka alur yang ada, dan tombol "Pindai lembar
// kerja" yang tetap tersembunyi (tanpa memakan ruang).
import 'dart:async';

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
import 'package:sidik_calibration/providers/jam_provider.dart';
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
import 'package:sidik_calibration/widgets/biru_awan/panel_baris.dart';
import 'package:sidik_calibration/widgets/biru_awan/stempel_sidik.dart';
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
  DateTime? diubah,
  DateTime? dikirim,
}) => CalibrationHistoryItem(
  id: id,
  namaAlat: alat,
  namaTeknisi: 'Teknisi Sidik',
  tanggalKalibrasi: DateTime(2026, 11, 3),
  status: status,
  nomorSesi: nomor,
  namaPelanggan: pelanggan,
  catatanRevisi: catatan,
  diubahPada: diubah,
  dikirimPada: dikirim,
);

/// "Sekarang" yang dipatok lewat `jamProvider`: waktu pembaruan relatif tidak
/// boleh bergantung jam dinding.
final _sekarang = DateTime(2026, 11, 16, 12);

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
    jamProvider.overrideWithValue(() => _sekarang),
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

/// Kunci kartu ringkasan.
const _kunciRingkasan = [
  'ringkasan-draf',
  'ringkasan-revisi',
  'ringkasan-menunggu',
];

/// Angka besar (28) di kartu ringkasan [kunci]: "3", atau "–" bila daftarnya
/// belum terbaca.
String _angka(WidgetTester tester, String kunci) {
  final teks = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(ValueKey(kunci)),
          matching: find.byType(Text),
        ),
      )
      .where((t) => t.style?.fontSize == 28)
      .map((t) => t.data!)
      .toList();
  expect(teks, hasLength(1), reason: 'satu angka di $kunci');
  return teks.single;
}

/// Semua teks dalam kartu ringkasan [kunci].
List<String> _teksKartu(WidgetTester tester, String kunci) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(kunci)),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data!)
    .toList();

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
      expect(_teksRingkas('Lanjutkan pekerjaan'), findsOneWidget);
      expect(_teksRingkas('Aktivitas terbaru'), findsOneWidget);
      expect(_teksRingkas('Lanjutkan pekerjaan 0'), findsNothing);
      expect(_teksRingkas('Aktivitas terbaru 0'), findsNothing);
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

  group('judul, ringkasan, dan klaim', () {
    final tigaDraf = _tetap([
      _sesi(1, 'Flow Meter Cairan', CalibrationStatus.draft),
      _sesi(2, 'Autoclave', CalibrationStatus.draft),
      _sesi(3, 'Thermohygrometer', CalibrationStatus.draft),
    ]);
    Future<List<CalibrationHistoryItem>> putus() async =>
        throw const KoneksiException('putus');

    testWidgets('judul "Pekerjaan saya" (header), sapaan nama depan, tanpa '
        'hero langit', (tester) async {
      final semantik = tester.ensureSemantics();
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      expect(_teksRingkas('Pekerjaan saya'), findsOneWidget);
      expect(
        tester
            .getSemantics(_teksRingkas('Pekerjaan saya'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(find.textContaining('Halo, '), findsOneWidget);
      // Banner besar dan kalimat 28/800 sudah tidak ada.
      expect(find.byType(HeroLangit), findsNothing);
      expect(find.text('Mulai dari alat yang datang hari ini'), findsNothing);
      expect(find.textContaining('draf belum dikirim'), findsNothing);
      semantik.dispose();
    });

    testWidgets('ringkasan: angka dari daftar yang sama dengan bagian di '
        'bawahnya; "menunggu" menyebut dasar hitungannya', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(
            revisi: () async => [
              _sesi(7, 'Turbidimeter', CalibrationStatus.perluRevisi),
            ],
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
          _Draf(tigaDraf),
        ),
      );

      expect(_angka(tester, 'ringkasan-draf'), '3');
      expect(_angka(tester, 'ringkasan-revisi'), '1');
      expect(_angka(tester, 'ringkasan-menunggu'), '1');
      expect(
        _teksKartu(tester, 'ringkasan-menunggu'),
        contains('dari 3 kiriman terakhir'),
        reason: 'angka ini hanya dari kiriman terakhir yang sudah dimuat',
      );
      expect(_teksKartu(tester, 'ringkasan-draf'), contains('Draf'));
      expect(_teksKartu(tester, 'ringkasan-revisi'), contains('Perlu revisi'));
      expect(
        _teksKartu(tester, 'ringkasan-menunggu'),
        contains('Menunggu pemeriksaan'),
      );
      // Judul bagian memakai daftar yang sama: jumlahnya cocok.
      expect(_teksRingkas('Lanjutkan pekerjaan 3'), findsOneWidget);
      expect(_teksRingkas('Aktivitas terbaru 3'), findsOneWidget);
      // Stempel: ikon + kata dari pemetaan status yang ada.
      expect(find.text('Menunggu approval'), findsOneWidget);
      expect(find.text('Disetujui'), findsNWidgets(2));
      expect(find.text('KAL/2026/11/0001'), findsOneWidget);
    });

    testWidgets('daftar yang TERBACA dan kosong = 0 (klaim sah); yang belum '
        'terbaca = "–", BUKAN 0', (tester) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));
      expect(
        [for (final k in _kunciRingkasan) _angka(tester, k)],
        ['0', '0', '0'],
      );

      final tahan = Completer<List<CalibrationHistoryItem>>();
      await _buka(
        tester,
        _app(teknisi(terkirim: () => tahan.future), _Draf(() => tahan.future)),
      );
      expect(
        [for (final k in _kunciRingkasan) _angka(tester, k)],
        ['–', '0', '–'],
        reason: 'revisi terbaca (kosong); draf dan terkirim masih memuat',
      );
      // Tanpa daftar terkirim terbaca: tidak ada kalimat dasar hitungan.
      expect(
        _teksKartu(
          tester,
          'ringkasan-menunggu',
        ).where((t) => t.contains('kiriman terakhir')),
        isEmpty,
      );
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('daftar yang gagal atau masih memuat TIDAK terbaca nol: "–" di '
        'kartunya, tidak ikut hitungan, tidak memicu "semua terkirim"', (
      tester,
    ) async {
      final tahan = Completer<List<CalibrationHistoryItem>>();
      final menunggu2 = _tetap([
        _sesi(20, 'pH Meter', CalibrationStatus.menungguApproval),
        _sesi(21, 'Inkubator', CalibrationStatus.menungguApproval),
      ]);

      // (keadaan, layanan, draf, [draf, revisi, menunggu] yang diharapkan).
      final kasus = <(String, _Teknisi, _Draf, List<String>)>[
        (
          'draf gagal + 2 menunggu',
          teknisi(terkirim: menunggu2),
          _Draf(putus),
          ['–', '0', '2'],
        ),
        (
          'draf memuat + 2 menunggu',
          teknisi(terkirim: menunggu2),
          _Draf(() => tahan.future),
          ['–', '0', '2'],
        ),
        (
          'terkirim gagal + 3 draf',
          teknisi(terkirim: putus),
          _Draf(tigaDraf),
          ['3', '0', '–'],
        ),
        (
          'draf gagal, lainnya kosong',
          teknisi(),
          _Draf(putus),
          ['–', '0', '0'],
        ),
        (
          'terkirim gagal, lainnya kosong',
          teknisi(terkirim: putus),
          _Draf(_kosong),
          ['0', '0', '–'],
        ),
        (
          'perlu revisi gagal, lainnya kosong',
          teknisi(revisi: putus),
          _Draf(_kosong),
          ['0', '–', '0'],
        ),
      ];
      for (final (keadaan, lembar, draf, angka) in kasus) {
        await _buka(tester, _app(lembar, draf));
        expect(
          [for (final k in _kunciRingkasan) _angka(tester, k)],
          angka,
          reason: keadaan,
        );
        expect(
          _teksRingkas('Semua lembar sudah terkirim.'),
          findsNothing,
          reason: keadaan,
        );
      }
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('"Menunggu pemeriksaan" dihitung dari kiriman terakhir yang '
        'DIMUAT (10), dan kalimatnya menyebut itu', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(
            terkirim: () async => [
              for (var i = 0; i < 10; i++)
                _sesi(
                  30 + i,
                  'Alat $i',
                  i < 4
                      ? CalibrationStatus.menungguApproval
                      : CalibrationStatus.disetujui,
                ),
            ],
          ),
          _Draf(_kosong),
        ),
      );
      expect(_angka(tester, 'ringkasan-menunggu'), '4');
      expect(
        _teksKartu(tester, 'ringkasan-menunggu'),
        contains('dari 10 kiriman terakhir'),
      );
    });

    testWidgets(
      'kartu "Perlu revisi" krem HANYA bila ada yang perlu diperiksa',
      (tester) async {
        Color? isi(WidgetTester t) {
          final kartu = find.descendant(
            of: find.byKey(const ValueKey('ringkasan-revisi')),
            matching: find.byType(Material),
          );
          return t.widget<Material>(kartu.first).color;
        }

        await _buka(tester, _app(teknisi(), _Draf(_kosong)));
        final m = SidikMaterial.of(tester.element(_kunciMulai));
        expect(isi(tester), m.kertas, reason: '0 revisi: netral');
        expect(isi(tester), isNot(m.awasTipis));

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
        expect(isi(tester), m.awasTipis, reason: 'ada revisi: krem');
        // Dua kartu lain tidak pernah krem.
        for (final k in ['ringkasan-draf', 'ringkasan-menunggu']) {
          final kartu = find.descendant(
            of: find.byKey(ValueKey(k)),
            matching: find.byType(Material),
          );
          expect(tester.widget<Material>(kartu.first).color, m.kertas);
        }
      },
    );

    testWidgets('semua kosong dan tak ada yang perlu revisi: "Semua lembar '
        'sudah terkirim."; ada yang perlu revisi: tidak ada klaim', (
      tester,
    ) async {
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
    });

    testWidgets('daftar belum terbaca / gagal: tidak ada klaim', (
      tester,
    ) async {
      final tahan = Completer<List<CalibrationHistoryItem>>();
      await _buka(
        tester,
        _app(teknisi(terkirim: () => tahan.future), _Draf(() => tahan.future)),
      );
      expect(_teksRingkas('Semua lembar sudah terkirim.'), findsNothing);
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('"Semua lembar sudah terkirim." digerbangi salinan lembar di '
        'HP: ada isi, gagal terbaca, atau belum selesai -> tanpa klaim; '
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
    });

    test('dasar hitungan "dari {n} kiriman terakhir": id dan en, tunggal dan '
        'jamak', () {
      expect(
        AppLocalizationsId().tekRingkasanDariKiriman(10),
        'dari 10 kiriman terakhir',
      );
      expect(
        AppLocalizationsEn().tekRingkasanDariKiriman(1),
        'from the latest submission',
      );
      expect(
        AppLocalizationsEn().tekRingkasanDariKiriman(10),
        'from the latest 10 submissions',
      );
    });
  });

  group('daftar vertikal: item membawa nama alat, pelanggan, nomor, waktu '
      'pembaruan, dan status', () {
    testWidgets('draf: satu baris per draf, urut ke bawah, tombol yang bisa '
        'diketuk', (tester) async {
      final semantik = tester.ensureSemantics();
      await _buka(
        tester,
        _app(
          teknisi(),
          _Draf(
            () async => [
              _sesi(
                1,
                'Flow Meter Cairan',
                CalibrationStatus.draft,
                nomor: 'KAL/2026/11/0003',
                pelanggan: 'PT Contoh Kalibrasi Nusantara',
                diubah: _sekarang.subtract(const Duration(minutes: 5)),
              ),
              _sesi(2, 'Autoclave', CalibrationStatus.draft, nomor: 'KAL/2'),
            ],
          ),
        ),
      );

      final baris1 = find.byKey(const ValueKey('kartu-sesi-teknisi-1'));
      expect(find.byType(BarisDaftar72), findsNWidgets(2));
      expect(
        find.descendant(of: baris1, matching: find.text('Flow Meter Cairan')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: baris1,
          matching: find.text('PT Contoh Kalibrasi Nusantara'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: baris1, matching: find.text('KAL/2026/11/0003')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: baris1,
          matching: find.text('Diperbarui 5 menit lalu'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: baris1, matching: find.text('Draf')),
        findsOneWidget,
        reason: 'status per item',
      );
      expect(
        find.descendant(of: baris1, matching: find.byType(StempelSidik)),
        findsOneWidget,
      );
      // Vertikal: x sama, y naik; bisa diketuk.
      final a = tester.getRect(baris1);
      final b = tester.getRect(
        find.byKey(const ValueKey('kartu-sesi-teknisi-2')),
      );
      expect(b.top, greaterThanOrEqualTo(a.bottom));
      expect(b.left, a.left);
      final data = tester.getSemantics(baris1).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains('Flow Meter Cairan'));
      expect(data.label, contains('Diperbarui 5 menit lalu'));
      semantik.dispose();
    });

    testWidgets('waktu pembaruan: diubahPada, atau dikirimPada bila hanya itu; '
        'TANPA keduanya baris waktu tidak ditulis', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(
            terkirim: () async => [
              _sesi(
                20,
                'pH Meter',
                CalibrationStatus.menungguApproval,
                dikirim: _sekarang.subtract(const Duration(hours: 3)),
              ),
              _sesi(21, 'Inkubator', CalibrationStatus.disetujui),
            ],
          ),
          _Draf(
            () async => [
              _sesi(
                1,
                'Autoclave',
                CalibrationStatus.draft,
                diubah: _sekarang.subtract(const Duration(days: 1)),
                dikirim: _sekarang.subtract(const Duration(days: 9)),
              ),
            ],
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kartu-sesi-teknisi-20')),
          matching: find.text('Diperbarui 3 jam lalu'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kartu-sesi-teknisi-1')),
          matching: find.text('Diperbarui Kemarin'),
        ),
        findsOneWidget,
        reason: 'diubahPada menang atas dikirimPada',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kartu-sesi-teknisi-21')),
          matching: find.textContaining('Diperbarui'),
        ),
        findsNothing,
        reason: 'tidak ada titik waktu: tidak dikarang',
      );
    });

    testWidgets('draf BUKAN carousel: delapan draf tersusun ke bawah, tanpa '
        'gulir mendatar dan tanpa Scrollbar', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(),
          _Draf(
            _tetap([
              for (var i = 1; i <= 8; i++)
                _sesi(i, 'Alat $i', CalibrationStatus.draft, nomor: 'KAL/$i'),
            ]),
          ),
        ),
        lebar: 1000,
      );
      final area = find.byKey(const ValueKey('bagian-draf'));
      expect(
        find.descendant(
          of: area,
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        ),
        findsNothing,
        reason: 'tidak ada baris yang menggulir ke samping',
      );
      expect(
        find.descendant(of: area, matching: find.byType(Scrollbar)),
        findsNothing,
      );
      var atas = double.negativeInfinity;
      for (var i = 1; i <= 8; i++) {
        final r = tester.getRect(find.byKey(ValueKey('kartu-sesi-teknisi-$i')));
        expect(r.top, greaterThanOrEqualTo(atas), reason: 'draf $i');
        expect(
          r.left,
          tester
              .getRect(find.byKey(const ValueKey('kartu-sesi-teknisi-1')))
              .left,
        );
        expect(
          r.right,
          lessThanOrEqualTo(1000),
          reason: 'draf $i di dalam layar',
        );
        atas = r.bottom;
      }
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

    testWidgets('urutan blok: header, judul, ringkasan, Kalibrasi baru, '
        'Perlu revisi, Lanjutkan pekerjaan, Aktivitas terbaru', (tester) async {
      await _buka(
        tester,
        _app(
          teknisi(
            revisi: () async => [
              _sesi(7, 'Turbidimeter', CalibrationStatus.perluRevisi),
            ],
            terkirim: () async => [
              _sesi(20, 'pH Meter', CalibrationStatus.disetujui),
            ],
          ),
          _Draf(() async => [_sesi(1, 'Autoclave', CalibrationStatus.draft)]),
        ),
      );
      double y(Finder f) => tester.getTopLeft(f).dy;
      final urut = <(String, double)>[
        ('header', y(find.text('SIDIK Lab'))),
        ('judul', y(find.text('Pekerjaan saya'))),
        ('ringkasan', y(find.byKey(const ValueKey('ringkasan-draf')))),
        ('Kalibrasi baru', y(_kunciMulai)),
        ('revisi', y(find.byKey(const ValueKey('bagian-perlu-revisi')))),
        ('draf', y(find.byKey(const ValueKey('bagian-draf')))),
        ('terkirim', y(find.byKey(const ValueKey('bagian-terkirim')))),
      ];
      for (var i = 1; i < urut.length; i++) {
        expect(
          urut[i].$2,
          greaterThan(urut[i - 1].$2),
          reason: '${urut[i].$1} harus di bawah ${urut[i - 1].$1}',
        );
      }
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
            nama: 'Lanjutkan pekerjaan',
            kunci: 'bagian-draf',
            id: 5,
            status: CalibrationStatus.draft,
          ),
          (
            nama: 'Aktivitas terbaru',
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

  group('aksi yang sudah ada tetap jalan', () {
    testWidgets('"Kalibrasi baru" tetap membuka alur pilih kategori', (
      tester,
    ) async {
      await _buka(tester, _app(teknisi(), _Draf(_kosong)));

      expect(find.text('Kalibrasi baru'), findsOneWidget);
      expect(find.text('Mulai kalibrasi'), findsNothing);
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
      // dasar tombol "Kalibrasi baru" langsung selebar jarak antarbagian ke
      // bagian berikutnya (Perlu revisi kosong = tersembunyi, jadi itu Draf).
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('bagian-draf'))).dy -
            tester.getBottomLeft(_kunciMulai).dy,
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
    testWidgets('kurangi gerak: tombol dan bagian langsung utuh; tanpa itu '
        'masuk berurutan', (tester) async {
      Iterable<double> opasitas() => tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: _kunciMulai,
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value);

      // Dengan gerak: pada bingkai pertama tombol masih transparan.
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
            reason: 'Kalibrasi baru keluar layar (${e.key})',
          );
        }
      }
      tahan.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('Semantics dan sasaran sentuh: judul bagian = header, '
        'Kalibrasi baru = tombol aktif, lonceng membawa jumlah belum dibaca, '
        'semua sasaran >= 48 dp dan berlabel', (tester) async {
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

      // Kalibrasi baru: tombol aktif berlabel, aksi ketuk, tinggi >= 48.
      final mulai = tester
          .getSemantics(
            find.descendant(
              of: _kunciMulai,
              matching: find.byType(FilledButton),
            ),
          )
          .getSemanticsData();
      expect(mulai.label, contains('Kalibrasi baru'));
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

      // Judul bagian: header.
      for (final judul in [
        'Perlu revisi 1',
        'Lanjutkan pekerjaan 1',
        'Aktivitas terbaru 2',
      ]) {
        final data = tester
            .getSemantics(_teksRingkas(judul))
            .getSemanticsData();
        expect(data.flagsCollection.isHeader, isTrue, reason: judul);
      }
      expect(
        tester
            .getSemantics(find.text('Pekerjaan saya'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      // Tiga kartu ringkasan: satu simpul berlabel "label: angka".
      for (final (kunci, label) in [
        ('ringkasan-draf', 'Draf: 1'),
        ('ringkasan-revisi', 'Perlu revisi: 1'),
        (
          'ringkasan-menunggu',
          'Menunggu pemeriksaan: 1, dari 2 kiriman terakhir',
        ),
      ]) {
        expect(
          tester.getSemantics(find.byKey(ValueKey(kunci))).label,
          label,
          reason: kunci,
        );
      }

      // Baris draf dan kartu revisi: sasaran >= 48.
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

    testWidgets('tombol utama: biru aksi 48 dp selebar kolom (bukan banner), '
        'tema terang dan gelap', (tester) async {
      for (final gelap in [false, true]) {
        await _buka(tester, _app(teknisi(), _Draf(_kosong), gelap: gelap));
        final m = SidikMaterial.of(tester.element(_kunciMulai));
        final tema = Theme.of(tester.element(_kunciMulai)).colorScheme;
        final tombol = tester.widget<TombolSidik>(_kunciMulai);
        expect(tombol.ragam, RagamTombolSidik.utama);
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
        expect(isi, tema.primary, reason: gelap ? 'gelap' : 'terang');
        expect(isi, m.biru);
        final ukuran = tester.getSize(_kunciMulai);
        expect(ukuran.height, 48);
        expect(ukuran.width, 412 - 2 * AppSpacing.md, reason: 'selebar kolom');
      }
    });

    testWidgets('ringkasan: tiga kartu sebaris di 412 dp, ditumpuk di 360 dp '
        'dan di 320 dp x huruf 1,3; kata terpanjang tidak putus di tengah', (
      tester,
    ) async {
      const label = {
        'ringkasan-draf': 'Draf',
        'ringkasan-revisi': 'Perlu revisi',
        'ringkasan-menunggu': 'Menunggu pemeriksaan',
      };

      /// Kata terpanjang ("pemeriksaan") muat dalam satu baris: lebar kata
      /// terpanjang <= lebar paragraf yang dipakai.
      void kataUtuh(String alasan) {
        for (final e in label.entries) {
          final p = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(ValueKey(e.key)),
              matching: find.text(e.value),
            ),
          );
          expect(
            p.getMinIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(p.size.width + 0.01),
            reason: 'kata terpanjang "${e.value}" putus di tengah ($alasan)',
          );
        }
      }

      double atas(String k) => tester.getTopLeft(find.byKey(ValueKey(k))).dy;

      // 412 dp: sebaris.
      await _buka(tester, _app(teknisi(), _Draf(_kosong)), lebar: 412);
      expect({for (final k in _kunciRingkasan) atas(k)}, hasLength(1));
      kataUtuh('412 dp, sebaris');

      // 360 dp: sel sempit, ditumpuk (di sebaris "pemeriksaan" akan putus).
      await _buka(tester, _app(teknisi(), _Draf(_kosong)), lebar: 360);
      expect(atas('ringkasan-revisi'), greaterThan(atas('ringkasan-draf')));
      expect(atas('ringkasan-menunggu'), greaterThan(atas('ringkasan-revisi')));
      kataUtuh('360 dp, ditumpuk');

      // 320 dp x 1,3: ditumpuk, selebar kolom, tanpa luapan.
      await _buka(
        tester,
        _app(teknisi(), _Draf(_kosong), skala: 1.3),
        lebar: 320,
        tinggi: 3200,
      );
      expect(tester.takeException(), isNull);
      expect(atas('ringkasan-revisi'), greaterThan(atas('ringkasan-draf')));
      expect(atas('ringkasan-menunggu'), greaterThan(atas('ringkasan-revisi')));
      for (final k in _kunciRingkasan) {
        expect(
          tester.getSize(find.byKey(ValueKey(k))).width,
          320 - 2 * AppSpacing.md,
          reason: '$k selebar kolom',
        );
      }
      kataUtuh('320 dp x 1,3, ditumpuk');
    });
  });
}
