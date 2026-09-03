import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_draft.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// "Simpan Draft" beneran nyimpen yang setengah jadi.
///
/// ## Kenapa berkas ini ada
///
/// `_submit()` di layar ini menjalankan SELURUH validasinya tanpa syarat —
/// suhu & kelembaban wajib, tiap titik wajib nilai acuan + satuan + minimal dua
/// pembacaan — dan `draft` baru dibaca jauh di bawah, sesudah semua `return`
/// awal terlewati. Jadi tombol yang namanya "SIMPAN DRAFT" menuntut lembar yang
/// LENGKAP.
///
/// Layar lembar kerja utama sudah benar sejak awal (`lembar_kerja_screen`
/// membungkus penjagaannya dengan `if (!draft)`), modelnya sendiri
/// mendokumentasikan niatnya (`simpanSebagaiDraft` = *"simpan dulu, lanjut
/// nanti"*), dan backend-nya sudah longgar (`suhu_ruang`/`kelembaban`
/// `nullable`, `measurements` `sometimes`, `pembacaan` `nullable`). Yang bolong
/// cuma layar ini.
///
/// Yang kena teknisi: baru mengukur sebagian titik — baterai menipis, alat
/// pelanggan belum siap — dan tidak bisa menyimpan progresnya lewat tombol yang
/// menjanjikan persis itu. Pilihannya tunggu sampai lengkap, atau kehilangan
/// seluruh isian.
///
/// ## Kenapa jalur approval ikut diuji di sini
///
/// Setengah berkas ini isinya penjaga anti-kebablasan. Melonggarkan draft itu
/// gampang; melonggarkannya SAMPAI KEBAWA ke jalur approval juga gampang, dan
/// yang kedua jauh lebih mahal — angka setengah jadi yang lolos ke antrean
/// admin berujung di sertifikat. Jadi tiap pelonggaran di sini punya pasangan
/// yang membuktikan jalur approval-nya tidak ikut longgar.

/// Mock yang **menyimpan apa yang dikirim**, bukan cuma bilang sukses.
///
/// Itu yang bikin test ini tidak bisa hijau karena kebetulan: "layarnya ketutup"
/// saja belum membuktikan drafnya benar-benar berangkat, dan tidak membuktikan
/// apa pun soal ISI yang berangkat.
class _PerekamKalibrasi implements CalibrationService {
  int panggilan = 0;
  CalibrationDraft? terakhir;

  @override
  Future<int> buatSesi(String token, CalibrationDraft draft) async {
    panggilan++;
    terakhir = draft;
    return 999;
  }
}

Widget _app(_PerekamKalibrasi perekam) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      calibrationServiceProvider.overrideWithValue(perekam),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Dibungkus tombol "buka", bukan langsung `home:` — layarnya memanggil
      // `Navigator.pop()` waktu submit sukses, jadi butuh stack Navigator
      // beneran. Sama alasannya dengan `calibration_input_test.dart`.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalibrationInputScreen(),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// Form-nya lebih panjang dari viewport bawaan test, dan `find.byType(TextField).at(n)`
  /// cuma menemukan yang sudah di-build `ListView`-nya.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> bukaLayar(WidgetTester tester) async {
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  Future<void> tekan(WidgetTester tester, String tombol) async {
    final target = find.text(tombol);
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Kategori + alat + standar. Ketiganya TETAP wajib walau draft — tanpa
  /// ketiganya tidak ada yang bisa dikirim sama sekali, dan `CalibrationDraft`
  /// menuntutnya non-null. Sama seperti alat di lembar kerja utama.
  Future<void> pilihIdentitas(WidgetTester tester) async {
    await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panjang').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Jangka Sorong Mitutoyo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih standar acuan'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gauge Block Set Grade 0').last);
    await tester.pumpAndSettle();
  }

  // Urutan TextField di layar: suhu ruang[0], kelembaban[1] (dua-duanya sudah
  // terisi bawaan), lalu nilai acuan[2] + satuan[3] + dua pembacaan[4,5].
  Future<void> kosongkanLingkungan(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.enterText(find.byType(TextField).at(1), '');
  }

  group('simpan draft', () {
    /// Inti bug-nya. Sebelum diperbaiki, tap ini berhenti di
    /// "Isi angka yang valid." dan `buatSesi` tidak pernah dipanggil.
    testWidgets('lembar kosong melompong tetap bisa disimpan', (tester) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      await kosongkanLingkungan(tester);
      await tekan(tester, 'SIMPAN DRAFT');

      expect(
        perekam.panggilan,
        1,
        reason: 'Draft-nya nggak pernah berangkat ke server.',
      );
      expect(find.byType(CalibrationInputScreen), findsNothing);

      // Baris titiknya kosong melompong, jadi tidak ada yang hilang — pesannya
      // harus pesan sukses biasa, bukan peringatan "1 baris dilewat".
      // Peringatan yang isinya tidak benar melatih orang mengabaikan yang asli.
      expect(find.text('Draft kalibrasi disimpan.'), findsOneWidget);

      final draft = perekam.terakhir!;
      expect(draft.simpanSebagaiDraft, isTrue);
      expect(draft.suhuRuang, isNull);
      expect(draft.kelembaban, isNull);
      expect(draft.measurements, isEmpty);

      // Sampai ke payload-nya: null harus HILANG dari JSON, bukan terkirim
      // sebagai `null` — backend membedakan "tidak dikirim" dari "dikirim
      // kosong" di beberapa tempat, dan `toJson()` memang sudah menyaringnya.
      final json = draft.toJson();
      expect(json.containsKey('suhu_ruang'), isFalse);
      expect(json.containsKey('kelembaban'), isFalse);
      expect(json['status'], 'draft');
    });

    /// Satu pembacaan itu sah untuk draft — yang tidak sah cuma untuk
    /// approval. Type A butuh minimal dua pengulangan supaya ada sebaran yang
    /// bisa dihitung, tapi itu syarat MENERBITKAN angka, bukan syarat mencatat.
    testWidgets('titik dengan satu pembacaan ikut tersimpan', (tester) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      await tester.enterText(find.byType(TextField).at(2), '50.0');
      await tester.enterText(find.byType(TextField).at(3), 'mm');
      await tester.enterText(find.byType(TextField).at(4), '50.02');
      await tekan(tester, 'SIMPAN DRAFT');

      expect(perekam.panggilan, 1);

      final titik = perekam.terakhir!.measurements;
      expect(titik, hasLength(1));
      expect(titik.single.titikUkur, 50.0);
      expect(titik.single.satuan, 'mm');
      expect(titik.single.pembacaan, [50.02]);
    });

    /// Baris yang tidak bisa ikut HARUS dikatakan.
    ///
    /// `measurements.*.titik_ukur` itu `required` di backend bahkan untuk
    /// draft, jadi baris tanpa nilai acuan bakal menolak SELURUH request —
    /// bukan cuma barisnya. Karena itu barisnya dilewat di klien. Tapi
    /// melewatinya diam-diam berarti angka yang sudah diketik teknisi hilang
    /// tanpa jejak, dan itu persis yang dilarang penjaga `kebuang` di lembar
    /// kerja utama: *"Angka yang nggak ketemu barisnya HARUS diomongin."*
    testWidgets('baris tanpa nilai acuan dilewat, tapi dikatakan', (
      tester,
    ) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      // Nilai acuan[2] sengaja dibiarkan kosong; pembacaannya diisi.
      await tester.enterText(find.byType(TextField).at(3), 'mm');
      await tester.enterText(find.byType(TextField).at(4), '50.02');
      await tester.enterText(find.byType(TextField).at(5), '50.01');
      await tekan(tester, 'SIMPAN DRAFT');

      expect(perekam.panggilan, 1);
      expect(perekam.terakhir!.measurements, isEmpty);
      expect(
        find.textContaining('1 baris'),
        findsOneWidget,
        reason: 'Baris yang dilewat hilang tanpa ada yang ngomong.',
      );
    });

    /// Angka yang SALAH KETIK juga hilang — dan dulu dia hilang tanpa
    /// dilaporkan sama sekali.
    ///
    /// `50x` gagal di-parse, jadi nilai acuannya null dan barisnya dilewat
    /// seperti baris tanpa acuan. Bedanya: sebelum diperbaiki, penghitung
    /// baris-dilewat memeriksa HASIL parse-nya. Satuan kosong dan pembacaan
    /// yang juga gagal di-parse membuat baris ini terbaca sebagai baris kosong
    /// melompong — jadi yang muncul pesan sukses biasa, padahal ada yang
    /// diketik dan dibuang.
    ///
    /// Ini bentuk kehilangan yang paling mahal: teknisi melihat konfirmasi
    /// berhasil, menutup layarnya, dan angkanya tidak pernah ada.
    testWidgets('baris yang angkanya salah ketik tetap dilaporkan', (
      tester,
    ) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      // Cuma nilai acuannya yang diisi, dan isinya bukan angka. Satuan &
      // pembacaan sengaja dibiarkan kosong — itu keadaan yang dulu lolos.
      await tester.enterText(find.byType(TextField).at(2), '50x');
      await tekan(tester, 'SIMPAN DRAFT');

      expect(perekam.panggilan, 1);
      expect(perekam.terakhir!.measurements, isEmpty);
      expect(
        find.textContaining('1 baris'),
        findsOneWidget,
        reason: 'Angka salah ketik dibuang diam-diam, layarnya bilang sukses.',
      );
    });

    /// JANGAN kebablasan: baris yang benar-benar kosong tetap TIDAK dilaporkan.
    ///
    /// Penjagaan di atas gampang diperbaiki kebablasan jadi "hitung semua baris
    /// yang dilewat", dan hasilnya peringatan di tiap draft kosong. Peringatan
    /// yang isinya tidak benar melatih orang mengabaikan yang asli — dan yang
    /// asli di sini yang menahan angka hilang.
    testWidgets('baris kosong melompong tetap nggak dilaporkan', (
      tester,
    ) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      await tekan(tester, 'SIMPAN DRAFT');

      expect(find.text('Draft kalibrasi disimpan.'), findsOneWidget);
      expect(find.textContaining('baris'), findsNothing);
    });

    /// Identitas tetap wajib, bahkan buat draft.
    testWidgets('tanpa kategori tetap ditahan', (tester) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await tekan(tester, 'SIMPAN DRAFT');

      expect(find.text('Pilih kategori dulu.'), findsOneWidget);
      expect(perekam.panggilan, 0);
      expect(find.byType(CalibrationInputScreen), findsOneWidget);
    });
  });

  /// JANGAN kebablasan. Kalau grup ini merah, pelonggarannya bocor ke jalur
  /// yang salah — dan angka setengah jadi yang lolos ke antrean admin berujung
  /// di sertifikat terakreditasi.
  group('kirim approval tetap ketat', () {
    testWidgets('kondisi lingkungan kosong ditolak', (tester) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      await kosongkanLingkungan(tester);
      await tester.enterText(find.byType(TextField).at(2), '50.0');
      await tester.enterText(find.byType(TextField).at(3), 'mm');
      await tester.enterText(find.byType(TextField).at(4), '50.02');
      await tester.enterText(find.byType(TextField).at(5), '50.01');
      await tekan(tester, 'KIRIM UNTUK APPROVAL');

      expect(find.text('Isi angka yang valid.'), findsOneWidget);
      expect(perekam.panggilan, 0);
    });

    testWidgets('satu pembacaan saja ditolak', (tester) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      await tester.enterText(find.byType(TextField).at(2), '50.0');
      await tester.enterText(find.byType(TextField).at(3), 'mm');
      await tester.enterText(find.byType(TextField).at(4), '50.02');
      await tekan(tester, 'KIRIM UNTUK APPROVAL');

      expect(
        find.text('Tiap titik ukur minimal 2 pembacaan angka.'),
        findsOneWidget,
      );
      expect(perekam.panggilan, 0);
    });

    testWidgets('nilai acuan kosong ditolak, bukan dilewat', (tester) async {
      perbesarViewport(tester);
      final perekam = _PerekamKalibrasi();
      await tester.pumpWidget(_app(perekam));
      await tester.pumpAndSettle();
      await bukaLayar(tester);

      await pilihIdentitas(tester);
      await tester.enterText(find.byType(TextField).at(3), 'mm');
      await tester.enterText(find.byType(TextField).at(4), '50.02');
      await tester.enterText(find.byType(TextField).at(5), '50.01');
      await tekan(tester, 'KIRIM UNTUK APPROVAL');

      expect(find.text('Isi angka yang valid.'), findsOneWidget);
      expect(
        perekam.panggilan,
        0,
        reason: 'Baris tanpa nilai acuan kelewat ke antrean approval.',
      );
    });
  });
}
