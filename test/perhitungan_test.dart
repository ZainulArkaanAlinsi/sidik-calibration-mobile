import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/validasi.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

HasilValidasi _validasi({
  int error = 0,
  int peringatan = 0,
  int info = 0,
  List<Temuan> temuan = const [],
}) => HasilValidasi(
  valid: error == 0 && peringatan == 0,
  bolehTerbit: error == 0,
  temuan: temuan,
  ringkasan: {
    TingkatTemuan.error: error,
    TingkatTemuan.peringatan: peringatan,
    TingkatTemuan.info: info,
  },
);

Widget _app(
  MockPerhitunganService service, {
  MockStandardService? standar,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      perhitunganServiceProvider.overrideWithValue(service),
      standardServiceProvider.overrideWithValue(
        standar ?? MockStandardService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PerhitunganScreen(calibrationId: 1),
    ),
  );
}

void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _muat(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('lembar PERHITUNGAN dirender apa adanya', () {
    testWidgets('empat blok sheet PERHITUNGAN muncul', (tester) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService()));

      expect(find.text('IDENTITAS ALAT'), findsOneWidget);
      expect(find.text('IDENTITAS CUSTOMER'), findsOneWidget);
      expect(find.text('PERHITUNGAN KONDISI LINGKUNGAN'), findsOneWidget);
      expect(find.text('DATA HASIL KALIBRASI'), findsOneWidget);

      expect(find.text('Before Adjustment Reading'), findsOneWidget);
      expect(find.text('After Adjustment Reading'), findsOneWidget);
    });

    testWidgets('angka ditampilkan dari server, bukan dihitung ulang', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService()));

      // Nilai Standard = nilai buffer pada suhu larutan (4,0092252 di 22,2 °C),
      // BUKAN nominal 4,00. Ini angka asli dari PERHITUNGAN.csv.
      //
      // Yang dicek versi TAMPILNYA — dibulatkan ke resolusi alat (0,01), sama
      // kayak yang kecetak di sertifikat. Angkanya tetap dari server: buffer
      // nominal 10,01 tampil `9.98`, dan itu mustahil muncul kalau layar ini
      // mbulatkan nominalnya sendiri. Dua kali per nilai — tabel Before &
      // After punya baris Standard masing-masing.
      expect(find.text('6.99'), findsNWidgets(2));
      expect(find.text('9.98'), findsNWidgets(2));

      // U95% Sertifikat suhu TH-3, hasil akar(1,7² + 0,2²).
      expect(find.text('1.7117'), findsOneWidget);
    });

    testWidgets('dua catatan tanda & nilai standar ikut ditampilkan', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService()));

      // Correction di lembar ini kebalikan dari sertifikat — kalau catatan ini
      // ilang, cepat atau lambat ada yang salah baca tandanya.
      expect(
        find.textContaining('Correction = Average − Standard'),
        findsOneWidget,
      );
      expect(
        find.textContaining('nilai buffer pada suhu larutan'),
        findsOneWidget,
      );
    });

    testWidgets('kolom yang belum kehitung nampil strip, bukan nol', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockPerhitunganService(thermohygroBelumDipilih: true)),
      );

      // Koreksi 0 itu hasil pengukuran; koreksi kosong itu data sertifikat
      // thermohygro yang belum diisi. Dua hal beda.
      expect(find.text('—'), findsWidgets);
      expect(
        find.textContaining('Belum dipilih'),
        findsOneWidget,
      );
    });
  });

  group('alur periksa & setujui', () {
    testWidgets('Periksa nampilin temuan tanpa nyetujuin', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          info: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.info,
              kode: 'nomor_order_kosong',
              pesan: 'Order Number belum diisi.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('PERIKSA'));
      await tester.pumpAndSettle();

      expect(find.text('Order Number belum diisi.'), findsOneWidget);
      expect(service.aksi, contains(('periksa', 1)));
      // Periksa NGGAK boleh ikut nyetujuin.
      expect(service.aksi.any((a) => a.$1 == 'setujui'), isFalse);
    });

    /// Temuan dimuat SENDIRI begitu layar kebuka, tanpa nunggu admin mencet.
    ///
    /// **Bug lapangan 7 Agt 2026.** Pemeriksaan cuma jalan waktu tombol PERIKSA
    /// ditekan, jadi yang tampil bisa temuan basi. Teknisi baru aja ngonfirmasi
    /// pembacaan hasil foto dari HP, tapi layar admin masih nulis "1 Blocks
    /// issuance — pembacaan AI Vision belum diverifikasi". Admin mencet Approve,
    /// ditolak, dan nggak ada petunjuk kalau blokirnya sebenarnya udah nggak
    /// ada. Temuan yang salah lebih menyesatkan daripada nggak ada temuan.
    testWidgets('temuan kemuat sendiri waktu layar dibuka', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          info: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.info,
              kode: 'nomor_order_kosong',
              pesan: 'Order Number belum diisi.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      // Belum ada satu pun tap ke PERIKSA.
      expect(service.aksi, contains(('periksa', 1)));
      expect(find.text('Order Number belum diisi.'), findsOneWidget);

      // Tombolnya TETAP ada — admin masih bisa ngulang kapan pun.
      expect(find.text('PERIKSA'), findsOneWidget);
    });

    testWidgets('temuan error mematikan tombol Setujui', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          error: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.error,
              kode: 'belum_ada_hitungan',
              pesan: 'Belum ada titik yang kehitung.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('PERIKSA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nahan penerbitan'), findsWidgets);

      // Temuan fatal nahan approve TANPA SYARAT — tombolnya mati, bukan cuma
      // dikasih peringatan.
      final tombol = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('SETUJUI'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(tombol.onTap, isNull);
    });

    testWidgets('peringatan: ditolak sekali, muncul dialog, lalu lanjut', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          peringatan: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.peringatan,
              kode: 'standar_titik_hilang',
              pesan: 'Titik ke-2: standar acuannya nggak ketemu, hitung ulang '
                  'dilewati.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();

      // Percobaan pertama HARUS ditolak dengan dialog konfirmasi.
      expect(find.text('Ada peringatan. Lanjut?'), findsOneWidget);

      // Dan dialognya nyebut peringatan yang BENERAN nyala. Judul dialog dulu
      // "Hasil hitung ulang beda. Lanjut?" buat peringatan apa pun — padahal
      // yang nahan sesi ini standar acuan yang nggak ketemu, dan hitung
      // ulangnya nggak pernah menghasilkan selisih satu pun.
      //
      // Dicari DI DALAM dialognya, bukan di seluruh layar. Versi pertama test
      // ini nyari ke mana saja dan tetap hijau waktu cacatnya dikembalikan —
      // yang kena teks yang sama di panel temuan di belakang dialog, jadi yang
      // sebetulnya diuji cuma "panelnya kegambar".
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('standar acuannya nggak ketemu'),
        ),
        findsOneWidget,
      );
      expect(service.aksi, contains(('setujui', false)));

      await tester.tap(find.text('TETAP SETUJUI'));
      await tester.pumpAndSettle();

      // Percobaan kedua bawa abaikan_peringatan: true.
      expect(service.aksi, contains(('setujui', true)));
    });

    testWidgets('batal di dialog peringatan = nggak jadi disetujui', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(peringatan: 1),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PERIKSA LAGI'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('setujui', false)));
      expect(service.aksi, isNot(contains(('setujui', true))));
    });

    testWidgets('sesi bersih langsung disetujui tanpa dialog', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('setujui', false)));
      expect(find.text('Ada peringatan. Lanjut?'), findsNothing);
    });
  });

  group('tolak', () {
    /// Tombol kirimnya MATI selama belum ada alasan — bukan nyala, ditekan,
    /// lalu dimarahin snackbar kayak versi dialog yang lama.
    testWidgets('tanpa alasan, tombol kirimnya mati', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();

      // `NeuButton` matiin tombolnya lewat `InkWell.onTap` null, bukan lewat
      // widget tombol Material — jadi yang diperiksa InkWell-nya.
      final tombol = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('KEMBALIKAN KE TEKNISI'),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(tombol.onTap, isNull);
      expect(service.aksi.any((a) => a.$1 == 'tolak'), isFalse);
    });

    testWidgets('catatan bebas kekirim apa adanya', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Catatan tambahan (opsional)'),
        'Buffer 7 cuma 2 bacaan.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('KEMBALIKAN KE TEKNISI'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('tolak', 'Buffer 7 cuma 2 bacaan.')));
    });

    /// Ini inti perbaikannya: sekali tap alasan, kalimatnya kesusun sendiri
    /// DAN kode kolomnya ikut kekirim — jadi lembar kerja teknisi bisa nyorot
    /// persis yang salah, bukan cuma ngasih paragraf buat disisir sendiri.
    testWidgets('alasan siap-pakai nyusun catatan + nandain kolomnya', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serial number nggak cocok'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KEMBALIKAN KE TEKNISI'));
      await tester.pumpAndSettle();

      expect(
        service.aksi,
        contains(('tolak', '• Serial number nggak cocok')),
      );
      expect(service.fieldTerakhir, ['alat_serial_number']);
    });

    /// Kotak "Catatan tambahan" itu satu-satunya kolom ketik di lembar ini,
    /// jadi keyboard PASTI kebuka di alur normal. Tanpa `viewInsets`, tombol
    /// KEMBALIKAN KE TEKNISI mendarat di bawah papan ketik: admin ngetik
    /// alasannya, terus kelihatan nggak ada tombol kirim sama sekali.
    testWidgets('tombol kirim nggak ketutup keyboard', (tester) async {
      _perbesarViewport(tester);
      const tinggiKeyboard = 900.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: tinggiKeyboard);
      addTearDown(tester.view.resetViewInsets);

      await _muat(tester, _app(MockPerhitunganService()));

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();

      final tombol = find.ancestor(
        of: find.text('KEMBALIKAN KE TEKNISI'),
        matching: find.byType(InkWell),
      ).first;
      final batasKeyboard =
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
          tinggiKeyboard;

      expect(tester.getRect(tombol).bottom, lessThanOrEqualTo(batasKeyboard));
    });
  });

  group('panel admin nggak boleh jadi jalan buntu', () {
    /// Ini yang paling kejam waktu kejadian: peringatan "Thermohygro belum
    /// dipilih" tetap nongol, tapi picker buat mbenerinnya LENYAP tanpa
    /// sepatah kata. Admin dikasih tahu ada yang kurang, lalu kontrolnya
    /// diumpetin — kebaca kayak app-nya rusak, padahal cuma `GET /standards`
    /// yang lagi nggak nyaut.
    testWidgets('standar gagal dimuat → pesan + COBA LAGI, bukan lenyap', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(
          MockPerhitunganService(thermohygroBelumDipilih: true),
          standar: MockStandardService(gagal: true),
        ),
      );

      expect(find.text('Gagal memuat standar acuan.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsWidgets);

      // Peringatannya tetap ada — yang salah dulu bukan peringatannya, tapi
      // hilangnya jalan keluar.
      expect(find.textContaining('Belum dipilih'), findsOneWidget);
    });

    testWidgets('picker tetap ada waktu standarnya kebaca normal', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockPerhitunganService(thermohygroBelumDipilih: true)),
      );

      // Kebalikannya: jangan sampai pesan gagal nongol di keadaan sehat.
      expect(find.text('Gagal memuat standar acuan.'), findsNothing);
      expect(find.text('Thermohygro used'), findsOneWidget);
    });

    testWidgets('lembar gagal dimuat → tombol coba lagi, bukan layar kosong', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService(gagal: true)));

      expect(find.text('Gagal memuat lembar perhitungan.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);

      // Bilah aksi nggak boleh ikut kegambar waktu datanya nggak ada — tombol
      // SETUJUI di atas layar error itu tombol yang nggak tau lagi nyetujuin
      // apa.
      expect(find.text('SETUJUI'), findsNothing);
    });
  });

  group('model validasi', () {
    test('tingkat asing dianggap info — nggak nahan apa-apa', () {
      final t = Temuan.fromJson({
        'tingkat': 'sesuatu_yang_baru',
        'kode': 'x',
        'pesan': 'y',
      });
      expect(t.tingkat, TingkatTemuan.info);
    });

    test('perluKonfirmasi cuma waktu boleh terbit tapi nggak valid', () {
      expect(_validasi(peringatan: 1).perluKonfirmasi, isTrue);
      expect(_validasi(error: 1).perluKonfirmasi, isFalse);
      expect(_validasi().perluKonfirmasi, isFalse);
      expect(_validasi(info: 3).perluKonfirmasi, isFalse);
    });
  });
}
