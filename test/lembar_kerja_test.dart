import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/worksheet_vision.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Lembar kerjanya panjang banget (2 tabel x 3 baris x 5 repeat x 2 kolom =
/// 60 kotak angka doang). `ListView` cuma nge-build yang deket viewport, jadi
/// index widget-nya berubah-ubah tiap discroll — viewport test dibikin raksasa
/// biar seluruh formulir ke-build sekaligus & index-nya stabil.
/// Lebarnya SENGAJA di bawah ambang dua kolom (1100) — ini mode halaman, yang
/// dipakai teknisi di HP. Buat mode dua kolom pakai [_viewportLebar].
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 14000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Layar lebar: lembar kerjanya digambar dua kolom bersebelahan, persis
/// kertasnya.
void _viewportLebar(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 14000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  MockLembarKerjaService service, {
  String profil = 'ph_meter',
  MockStandardService? standar,
  MockRoomService? ruangan,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(service),
      standardServiceProvider.overrideWithValue(
        standar ?? MockStandardService(),
      ),
      roomServiceProvider.overrideWithValue(ruangan ?? MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: profil),
    ),
  );
}

/// Buka layar & tunggu semua yang async kelar.
///
/// `pumpAndSettle` doang nggak cukup: `MockAuthService.me()` jeda 600 ms lewat
/// `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame — jadi
/// `pumpAndSettle` balik duluan dan timernya nyangkut. Sama kayak
/// `dashboard_test`.
Future<void> _muat(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Pilih alat lewat dropdown "Pilih alat" — sesudah ini kolom identitas &
/// pemilik harusnya keisi sendiri.
Future<void> _pilihAlat(
  WidgetTester tester, {
  String alat = 'pH Meter Mettler Toledo · B628755900',
}) async {
  await tester.tap(find.text('Pilih alat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(alat).last);
  await tester.pumpAndSettle();
}

/// Lembar kerjanya sekarang 2 halaman (ngikut kertasnya). Tabel hasil & tombol
/// kirim ada di halaman terakhir, jadi hampir semua test butuh ini dulu.
Future<void> _keHalamanAkhir(WidgetTester tester) async {
  final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
  while (lanjut.evaluate().isNotEmpty) {
    await tester.tap(lanjut);
    await tester.pumpAndSettle();
  }
}

/// Tekan KIRIM KE ADMIN, terus setujui dialog konfirmasi angkanya.
///
/// Dialognya cuma nongol kalau ada pembacaan yang keisi (lihat
/// `_konfirmasiAngka` di layar), jadi test yang ngirim lembar kosong tetap
/// lewat sini tanpa perlu tau bedanya.
Future<void> _kirimKeAdmin(WidgetTester tester) async {
  await tester.tap(find.text('KIRIM KE ADMIN'));
  await tester.pumpAndSettle();

  final konfirmasi = find.text('Kirim sekarang');
  if (konfirmasi.evaluate().isNotEmpty) {
    await tester.tap(konfirmasi);
    await tester.pumpAndSettle();
  }
}

void main() {
  _testRevisi();

  group('bentuk formulir datang dari backend', () {
    testWidgets('bagian & kolom digambar dari respons, bukan di-hardcode', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Halaman 1 ngikut urutan kertas.
      expect(find.text('EQUIPMENT IDENTITY AND CUSTOMER DATA'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('STANDARD'), findsOneWidget);
      expect(find.text('CALIBRATION DATA'), findsOneWidget);
      expect(find.text('SIDIK-FM-CAL-0509_Rev.4'), findsOneWidget);

      // Satu halaman: tabel hasilnya langsung kelihatan, nggak perlu dibalik.
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);

      expect(find.text('CALIBRATION RESULT'), findsOneWidget);
      expect(find.text('Before adjustment Reading'), findsOneWidget);
      expect(find.text('After adjustment Reading'), findsOneWidget);
    });

    testWidgets('teknisi nggak lihat satu pun kolom administratif', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Backend nggak ngirim kolom ini ke teknisi sama sekali (bukan cuma
      // disembunyiin) — kalau sampai kelihatan, penyaringan per-role bocor.
      expect(find.text('2. Calibration Methode'), findsNothing);
      expect(find.textContaining('Order Number'), findsNothing);

      // Thermohygro SEBALIKNYA: pindah jadi hak teknisi 29 Juli 2026 — dia yang
      // tau unit mana yang kebawa ke lokasi. Dulu kolom ini dibuang backend,
      // jadi teknisi ngisi di HP dan nyampe server jadi null.
      expect(find.text('6. Thermohygro used'), findsOneWidget);
      expect(find.text('TH-2'), findsOneWidget);
      expect(find.text('Insitu'), findsOneWidget);
    });

    testWidgets('kolom otomatis keisi dari alat & jadi read-only', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      await _pilihAlat(tester);

      // Nama alat & rentang tetap READ-ONLY — ketarik dari master, nggak
      // diketik.
      // Pemisah rentangnya en-dash (`–`), bukan hyphen — itu format yang
      // dipakai `EquipmentLookup.rentangTeks` di seluruh layar worksheet.
      expect(find.text('0–14 pH / 0.01 pH'), findsOneWidget);

      // Merk, Type/Model, Serial Number & identitas pemilik keisi dari master
      // juga — TAPI di kotak yang bisa diedit, bukan teks mati. Teknisi mulai
      // dari data yang benar dan cuma nyentuh yang beda sama barang fisiknya.
      final merk = tester.widget<TextField>(
        find.ancestor(
          of: find.text('Mettler Toledo'),
          matching: find.byType(TextField),
        ),
      );
      expect(merk.enabled, isNot(false));
    });
  });

  group('tombol kirim nggak pernah dikunci', () {
    testWidgets('formulir kosong melompong tetap bisa dikirim', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      // Cuma alat yang dipilih. Nol pembacaan, nol kondisi lingkungan.
      await _pilihAlat(tester);

      await _keHalamanAkhir(tester);
      await _kirimKeAdmin(tester);

      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['status'], 'menunggu_approval');
    });

    testWidgets('simpan draft kirim status draft', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      expect(service.payloadTerakhir!['status'], 'draft');
    });
  });

  group('sel kosong dikirim sebagai null', () {
    testWidgets('Repeat yang dilewat nggak bikin nomor berikutnya geser', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);

      // Isi Repeat 1 dan Repeat 3 di tabel After adjustment, titik pH 4 —
      // Repeat 2 sengaja dibiarin kos\ong.
      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Urutan kotak di baris pertama: [r1 pH, r1 °C, r2 pH, r2 °C, r3 pH, ...]
      await tester.enterText(kotak.at(0), '4.00');
      await tester.enterText(kotak.at(1), '22.2');
      await tester.enterText(kotak.at(4), '4.02');
      await tester.enterText(kotak.at(5), '22.1');
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;
      final titik4 = measurements.firstWhere(
        (m) => (m as Map)['titik_ukur'] == 4.00,
      ) as Map<String, dynamic>;

      // INI aturannya: panjangnya tetap 5, dan yang kosong jadi null di
      // POSISINYA — bukan dibuang sampai Repeat 3 naik jadi Repeat 2.
      expect(titik4['pembacaan'], [4.00, null, 4.02, null, null]);
      expect(titik4['suhu'], [22.2, null, 22.1, null, null]);
    });

    /// Dua tabel diisi PENUH pakai angka master — padanan tes yang sama buat
    /// Turbidimeter & Chlorine, biar ketiga alat setara penjagaannya.
    ///
    /// pH yang paling nggak boleh ketuker barisnya. Di dua alat lain, Standard
    /// Value itu angka nominal apa adanya; di sini dia dikoreksi kurva suhu
    /// dulu (buffer 4 di 22,2 °C jadi 4,009244572). Jadi pembacaan yang nyasar
    /// ke baris lain bukan cuma pindah tempat — dia diadu ke nilai acuan yang
    /// salah, dan koreksinya ikut salah tanpa ada yang kelihatan aneh.
    ///
    /// Repeat 4 titik 4 pH sengaja `5,00`: itu angka ASLI dari sheet lab
    /// (`PERHITUNGAN.csv` baris 27, tabel Before). Nilai nyeleneh yang cuma ada
    /// di satu sel itu justru penanda posisi paling bagus — kalau dia mendarat
    /// di Repeat lain, langsung ketahuan.
    testWidgets('tiga titik keisi penuh: baris & tahapnya nggak ketuker', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);

      // `Master Olah Data_pH for trial_CSV/PERHITUNGAN.csv`: Before baris
      // 24–28, After baris 37–41. Rata-rata After yang jadi Unit Under Test di
      // sertifikat 012-CAL-524: 4,00 · 7,004 · 10,11.
      const after = [
        ['4', '4', '4', '4', '4'],
        ['7,01', '7,01', '7', '7', '7'],
        ['10,11', '10,11', '10,11', '10,11', '10,11'],
      ];
      const suhuAfter = [
        ['22,2', '22,2', '22,1', '22,2', '22,2'],
        ['22,2', '22,2', '22,2', '22,2', '22,2'],
        ['22,1', '22,1', '22,1', '22,1', '22,1'],
      ];
      const before = [
        ['4,04', '4,04', '4,04', '5', '4,04'],
        ['7,02', '7,04', '7,05', '7,02', '7,02'],
        ['9,61', '9,94', '9,66', '9,61', '9,61'],
      ];
      const suhuBefore = ['22,2', '22,3', '22,2'];

      Finder kotakTabel(String judul) => find.descendant(
        of: find
            .ancestor(of: find.text(judul), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      );

      // Satu baris = 5 Repeat × 2 kotak (pH, °C); baris urut 4 → 7 → 10,01.
      for (var titik = 0; titik < 3; titik++) {
        for (var r = 0; r < 5; r++) {
          final sel = titik * 10 + r * 2;
          await tester.enterText(
            kotakTabel('After adjustment Reading').at(sel),
            after[titik][r],
          );
          await tester.enterText(
            kotakTabel('After adjustment Reading').at(sel + 1),
            suhuAfter[titik][r],
          );
          await tester.enterText(
            kotakTabel('Before adjustment Reading').at(sel),
            before[titik][r],
          );
          await tester.enterText(
            kotakTabel('Before adjustment Reading').at(sel + 1),
            suhuBefore[titik],
          );
        }
      }
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      // Yang dikirim mobile itu nominal buffernya. Koreksi kurva suhu jadi
      // 4,009244572 dikerjain backend — mobile nggak boleh nebak-nebak sendiri.
      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [4.00, 7.00, 10.01],
      );

      final titik4 = measurements[0] as Map<String, dynamic>;
      final titik7 = measurements[1] as Map<String, dynamic>;
      final titik10 = measurements[2] as Map<String, dynamic>;

      expect(titik4['pembacaan'], [4.0, 4.0, 4.0, 4.0, 4.0]);
      expect(titik7['pembacaan'], [7.01, 7.01, 7.0, 7.0, 7.0]);
      expect(titik10['pembacaan'], [10.11, 10.11, 10.11, 10.11, 10.11]);

      // `5,00` di Repeat 4 — penanda posisi dari sheet aslinya.
      expect(titik4['pembacaan_sebelum'], [4.04, 4.04, 4.04, 5.0, 4.04]);
      expect(titik7['pembacaan_sebelum'], [7.02, 7.04, 7.05, 7.02, 7.02]);
      expect(titik10['pembacaan_sebelum'], [9.61, 9.94, 9.66, 9.61, 9.61]);

      // Suhu per Repeat, bukan satu angka per baris: titik 4 Repeat 3 tercatat
      // 22,1 °C sementara sisanya 22,2 (sheet baris 39).
      expect(titik4['suhu'], [22.2, 22.2, 22.1, 22.2, 22.2]);
      expect(titik7['suhu_sebelum'], [22.3, 22.3, 22.3, 22.3, 22.3]);

      double rata(List<dynamic> n) =>
          n.cast<double>().reduce((a, b) => a + b) / n.length;

      expect(rata(titik4['pembacaan'] as List<dynamic>), closeTo(4.0, 1e-9));
      expect(rata(titik7['pembacaan'] as List<dynamic>), closeTo(7.004, 1e-9));
      expect(rata(titik10['pembacaan'] as List<dynamic>), closeTo(10.11, 1e-9));
    });

    testWidgets('titik yang sama sekali kosong tetap ikut terkirim', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      // Tiga larutan standar tetap ada semua, biar admin lihat kolom mana yang
      // kosong — bukan barisnya ilang dari tabel.
      expect(measurements.length, 3);
      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [4.00, 7.00, 10.01],
      );
      for (final m in measurements) {
        expect((m as Map)['pembacaan'], [null, null, null, null, null]);
      }
    });

    testWidgets('koma desimal diterima, dikirim sebagai titik', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);

      // Ditunjuk lewat blok CALIBRATION RESULT, bukan `TextField` indeks 0.
      // Indeks itu dulu kebetulan `suhu_awal` cuma karena halaman 2 mulai dari
      // situ; begitu lembarnya jadi satu halaman (ngikut backend), indeksnya
      // geser dan test-nya ngetik ke kolom yang salah tanpa ada yang gagal.
      final blokHasil = find.ancestor(
        of: find.text('CALIBRATION RESULT'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: blokHasil.first,
        matching: find.byType(TextField),
      );
      // Formulir kertasnya pakai koma desimal — teknisi ngetik sesuai yang
      // dia lihat, dan itu nggak boleh jadi angka hilang.
      await tester.enterText(kotak.first, '21,3');
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      expect(service.payloadTerakhir!['suhu_awal'], 21.3);
    });
  });

  group('client_request_id', () {
    testWidgets('retry sesudah sinyal putus bawa UUID yang sama', (
      tester,
    ) async {
      _perbesarViewport(tester);
      // Percobaan pertama gagal (niru sinyal putus pas nunggu respons),
      // percobaan kedua sukses — persis kejadian yang bikin sesi dobel kalau
      // UUID-nya digenerate ulang tiap tap.
      final service = MockLembarKerjaService(gagalKirimSampaiPercobaanKe: 1);
      await _muat(tester, _app(service));

      await _pilihAlat(tester);

      await _keHalamanAkhir(tester);
      await _kirimKeAdmin(tester);

      // Gagal → layarnya TETAP kebuka, isian nggak ilang, teknisi bisa coba lagi.
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);

      await _keHalamanAkhir(tester);
      await _kirimKeAdmin(tester);

      expect(service.jumlahKirim, 2);
      final pertama = service.payload[0]['client_request_id'];
      final kedua = service.payload[1]['client_request_id'];

      expect(pertama, isNotNull);
      expect(kedua, pertama);
    });

    testWidgets('UUID beda antar sesi pengisian yang beda', (tester) async {
      _perbesarViewport(tester);

      final a = MockLembarKerjaService();
      await _muat(tester, _app(a));
      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      // Layar dibuang beneran dulu. Tanpa ini Flutter cuma memperbarui element
      // yang lama (dua-duanya `LembarKerjaScreen` tanpa key), `_FormState`-nya
      // kepakai lagi, dan UUID-nya "kelihatan" sama padahal cuma nggak pernah
      // dibikin ulang.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final b = MockLembarKerjaService();
      await _muat(tester, _app(b));
      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      // Dua kejadian kalibrasi yang beda harus kebaca beda di server —
      // kalau UUID-nya sama, yang kedua malah dikira retry & dibuang.
      expect(
        b.payloadTerakhir!['client_request_id'],
        isNot(a.payloadTerakhir!['client_request_id']),
      );
    });
  });

  group('gagal muat bentuk formulir', () {
    testWidgets('nampilin pesan + tombol coba lagi, bukan layar kosong', (
      tester,
    ) async {
      await _muat(tester, _app(MockLembarKerjaService(gagal: true)));

      expect(find.text('Gagal memuat bentuk lembar kerja.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });

  group('layar lebar: dua kolom kayak kertasnya', () {
    testWidgets('kiri & kanan kelihatan sekaligus, tanpa tombol halaman', (
      tester,
    ) async {
      _viewportLebar(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Kiri: identitas & standar. Kanan: hasil kalibrasi. Satu layar, persis
      // formulir cetaknya — teknisi udah hafal peta ini.
      expect(find.text('EQUIPMENT IDENTITY AND CUSTOMER DATA'), findsOneWidget);
      expect(find.text('CALIBRATION RESULT'), findsOneWidget);
      expect(find.text('Before adjustment Reading'), findsOneWidget);

      // Nggak ada yang perlu dibalik halaman — semuanya udah kelihatan.
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);
    });
  });

  group('lembar kerja SATU halaman — sama kayak backend', () {
    /// Dulu bentuk pH di mock dipecah dua halaman, padahal backend udah nggak
    /// sejak `3ab1d09` ("satu gulungan"). Bedanya kelihatan: build mock
    /// nampilin tombol "LANJUT KE HALAMAN BERIKUTNYA" yang di build asli nggak
    /// ada sama sekali. Diadu langsung ke `?profil=ph_meter` dari API hidup
    /// 5 Agt 2026.
    test('semua bagian di satu halaman, urutannya ngikut kertas', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());

      expect(bentuk.halaman, [1]);
      expect(
        bentuk.bagianDiHalaman(1).map((b) => b.kode),
        ['identitas_alat', 'pemilik', 'usage_check', 'data_kalibrasi', 'hasil', 'penutup'],
      );
    });

    test('Env. Condition nempel sama tabel hasilnya', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final hasil = bentuk.bagian.firstWhere((b) => b.kode == 'hasil');

      // Di kertas Env. Condition itu baris pertama blok CALIBRATION RESULT —
      // dicatat waktu ngukur, bukan waktu nyiapin sesi.
      expect(hasil.field.map((f) => f.kode), contains('suhu_awal'));
      expect(hasil.tabel, hasLength(2));
    });

    test('bentuk lama tanpa `halaman` nggak bikin layar kosong', () {
      final bentuk = LembarKerja.fromJson({
        'bagian': [
          {'kode': 'a', 'judul': 'A', 'field': <Map<String, dynamic>>[]},
        ],
      });

      expect(bentuk.halaman, [1]);
      expect(bentuk.bagianDiHalaman(1), hasLength(1));
    });
  });

  group('tabel STANDARD barisnya tercetak', () {
    test('lima baris, bukan seluruh katalog standar lab', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final standar = bentuk.bagian.firstWhere((b) => b.kode == 'usage_check');

      expect(standar.baris.map((b) => b.label), [
        'pH Buffer Solutions 4',
        'pH Buffer Solutions 7',
        'pH Buffer Solutions 10',
        'RTD Sensor/SH1/20',
        'Victor 14+/992613877',
      ]);
    });

    test('standar yang belum kedaftar TETAP jadi baris, tanpa id', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final standar = bentuk.bagian.firstWhere((b) => b.kode == 'usage_check');
      final victor = standar.baris.last;

      // Barisnya hilang jauh lebih bahaya daripada baris yang belum ketaut:
      // teknisi nggak bakal sadar ada standar yang nggak kecatat.
      expect(victor.terdaftar, isFalse);
      expect(victor.standardId, isNull);
    });
  });

  group('Thermohygro used', () {
    test('empat unit tercetak, dikelompokkan Insitu & Inlab', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final field = bentuk.bagian
          .expand((b) => b.field)
          .firstWhere((f) => f.kode == 'thermohygro_standard_id');

      expect(field.sumber, SumberField.masterThermohygro);
      expect(
        field.pilihan.map((p) => (p.label, p.grup)),
        [('TH-2', 'Insitu'), ('TH-6', 'Insitu'), ('TH-7', 'Insitu'), ('TH-4', 'Inlab')],
      );
    });

    test('BUKAN kolom admin lagi — teknisi yang tau unit mana yang kebawa', () {
      final teknisi = LembarKerja.fromJson(contohBentukLembarKerja());

      expect(
        teknisi.bagian.expand((b) => b.field).map((f) => f.kode),
        contains('thermohygro_standard_id'),
      );
    });
  });

  group('model bentuk formulir', () {
    test('kolom bertitik dikenali sebagai turunan, bukan kunci payload', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final identitas = bentuk.bagian.first;

      final namaAlat = identitas.field.firstWhere(
        (f) => f.kode == 'equipment.nama_alat',
      );
      expect(namaAlat.turunan, isTrue);
      expect(namaAlat.sumber.readOnly, isTrue);

      final tanggal = identitas.field.firstWhere(
        (f) => f.kode == 'tanggal_terima',
      );
      expect(tanggal.turunan, isFalse);
    });

    test('tipe kolom yang belum dikenal jatuh ke teks, bukan bikin crash', () {
      final f = FieldLembarKerja.fromJson({
        'kode': 'kolom_baru_rev_5',
        'label': 'Kolom Baru',
        'tipe': 'sesuatu_yang_belum_ada',
      });

      expect(f.tipe, TipeField.teks);
      expect(f.wajib, isFalse);
    });

    test('semua kolom di formulir selalu opsional', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());

      for (final bagian in bentuk.bagian) {
        for (final f in bagian.field) {
          expect(f.wajib, isFalse, reason: '${f.kode} nggak boleh wajib');
        }
      }
      expect(bentuk.semuaKolomOpsional, isTrue);
    });

    test('bentuk admin bawa kolom administratif, bentuk teknisi nggak', () {
      final teknisi = LembarKerja.fromJson(contohBentukLembarKerja());
      final admin = LembarKerja.fromJson(
        contohBentukLembarKerja(untukAdmin: true),
      );

      Iterable<String> kode(LembarKerja lk) =>
          lk.bagian.expand((b) => b.field).map((f) => f.kode);

      expect(kode(teknisi), isNot(contains('calibration_method_id')));
      expect(kode(admin), contains('calibration_method_id'));

      // `thermohygro_standard_id` SENGAJA nggak di sini lagi: sejak 29 Juli
      // 2026 dia hak teknisi, bukan kolom administratif. Lihat group
      // "Thermohygro used".
      expect(kode(teknisi), contains('thermohygro_standard_id'));
      expect(admin.untukAdmin, isTrue);
      expect(teknisi.untukAdmin, isFalse);
    });

    test('bentuk backend cacat cuma ngilangin bagian rusak, bukan seluruh form', () {
      // Backend nyampur bagian sehat sama yang cacat: satu bagian tanpa `kode`,
      // satu field tanpa `kode`, satu baris tabel tanpa `titik_ukur`. Sebelum
      // ada jaring _petakanAman, satu cast keras yang gagal ngerontokin SELURUH
      // form jadi layar "gagal muat" — gejala "komponen hilang" di lapangan.
      final rusak = <String, dynamic>{
        'kode_dokumen': 'X',
        'untuk': 'teknisi',
        'bagian': [
          {
            'kode': 'sehat',
            'judul': 'Sehat',
            'field': [
              {'kode': 'a', 'label': 'A', 'tipe': 'teks'},
              {'label': 'tanpa kode'}, // field cacat → dilewat
            ],
          },
          {
            // bagian tanpa `kode` → dilewat, tapi nggak ngebunuh form
            'judul': 'Tanpa kode',
            'field': <Map<String, dynamic>>[],
          },
          {
            'kode': 'hasil',
            'judul': 'Hasil',
            'tabel': [
              {
                'tahap': 'sebelum_adjustment',
                'baris': [
                  {'titik_ukur': 4.0, 'label': '4'},
                  {'label': 'tanpa titik_ukur'}, // baris cacat → dilewat
                ],
                'kolom': [
                  {'kode': 'pembacaan', 'label': 'pH'},
                ],
                'pengulangan': [1, 2],
              },
            ],
          },
        ],
      };

      final bentuk = LembarKerja.fromJson(rusak);

      // Form tetap kebentuk, bukan lempar exception.
      final kodeBagian = bentuk.bagian.map((b) => b.kode).toList();
      expect(kodeBagian, contains('sehat'));
      expect(kodeBagian, contains('hasil'));
      expect(kodeBagian, isNot(contains('Tanpa kode'))); // bagian cacat dilewat

      final sehat = bentuk.bagian.firstWhere((b) => b.kode == 'sehat');
      expect(sehat.field.map((f) => f.kode), ['a']); // field cacat dilewat

      final tabel =
          bentuk.bagian.firstWhere((b) => b.kode == 'hasil').tabel.first;
      expect(tabel.baris.length, 1); // baris cacat dilewat
      expect(tabel.baris.first.titikUkur, 4.0);
    });
  });

  group('OCR tabel worksheet', () {
    /// `baris` itu **Repeat**, isinya satu angka per larutan standar. Dua sumbu
    /// ini gampang kebalik, dan kalau kebalik angkanya nyasar ke buffer yang
    /// salah tanpa ada yang error — makanya diuji eksplisit.
    HasilEkstraksiTabel contohHasil() => const HasilEkstraksiTabel(
      baris: [
        BarisTabel(ph: [4.01, 7.02, 10.11], suhu: [22.2, 22.3, 22.1]),
        BarisTabel(ph: [4.02, 7.03, 10.12], suhu: [22.2, 22.3, 22.1]),
      ],
      jumlahSelKebaca: 12,
      jumlahSelDiharapkan: 30,
      jumlahAngkaTerdeteksi: 12,
    );

    LembarKerjaState buatState() => LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uuid-test',
    );

    test('angka masuk ke Repeat & larutan standar yang benar', () {
      final isian = buatState();
      final terisi = isian.terapkanHasilEkstraksi(
        contohHasil(),
        tahap: 'sesudah_adjustment',
      );

      // 2 Repeat x 3 titik x 2 kolom (pH & suhu).
      expect(terisi, 12);

      final titik4 = isian.titik[4.00]!;
      final titik10 = isian.titik[10.01]!;

      // Repeat 1 buffer 4 -> 4.01, BUKAN 7.02 (itu buffer 7 di Repeat yang sama).
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4.01');
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 1).text, '4.02');
      expect(titik10.kotak('sesudah_adjustment', 'pembacaan', 0).text, '10.11');
      expect(titik4.kotak('sesudah_adjustment', 'suhu', 0).text, '22.2');
    });

    test('sel yang udah diketik manual NGGAK ketimpa hasil foto', () {
      final isian = buatState();
      final titik4 = isian.titik[4.00]!;

      // Teknisi udah betulin angka ini sendiri.
      titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text = '4.00';

      final terisi = isian.terapkanHasilEkstraksi(
        contohHasil(),
        tahap: 'sesudah_adjustment',
      );

      // Foto boleh dipakai berkali-kali buat nambal yang kurang; yang udah
      // dibetulin manusia harus menang.
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4.00');
      expect(terisi, 11, reason: 'satu sel dilewat karena udah keisi');
    });

    test('blok non-tabel keisi dari foto yang sama', () {
      final isian = buatState();
      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          field: {
            'suhu_awal': NilaiHeader(
              nilai: '22.2',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
            'catatan_teknisi': NilaiHeader(
              nilai: 'buffer 10 baru dibuka',
              keyakinan: TingkatKeyakinan.rendah,
            ),
          },
          tanggal: {
            'tanggal_terima': NilaiHeader(
              nilai: '23/07/2026',
              keyakinan: TingkatKeyakinan.sedang,
            ),
          },
        ),
      );

      expect(terisi, 3);
      expect(isian.teks['suhu_awal']!.text, '22.2');
      expect(isian.teks['catatan_teknisi']!.text, 'buffer 10 baru dibuka');
      expect(isian.tanggal['tanggal_terima'], DateTime(2026, 7, 23));

      // Cuma yang keyakinannya rendah yang ditandai — nyuruh cek SEMUA kolom
      // sama aja nggak nandain apa-apa.
      expect(
        isian.selRendahKeyakinan.contains(
          LembarKerjaState.kunciField('catatan_teknisi'),
        ),
        isTrue,
      );
      expect(
        isian.selRendahKeyakinan.contains(
          LembarKerjaState.kunciField('suhu_awal'),
        ),
        isFalse,
      );
    });

    test('AI NGGAK BISA nulis serial number / tanda tangan', () {
      // Ini pagar paling penting di seluruh alur foto. Serial number salah satu
      // digit bikin kalibrasi nempel ke instrumen yang salah — itu cacat
      // sertifikat berakreditasi, bukan sekadar bug. Sumbernya wajib DB.
      // Tanda tangan "Checked by" apalagi: itu provenance, bukan data.
      final isian = buatState();
      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          field: {
            'equipment.serial_number': NilaiHeader(
              nilai: 'B628755900',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
            'customer.nama': NilaiHeader(
              nilai: 'PT Tirta Gracia',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
            'reviewer.nama': NilaiHeader(
              nilai: 'Budi',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          },
        ),
      );

      // Backend boleh nekat ngirim kolom ini; mobile tetap nolak semuanya.
      expect(terisi, 0);
      expect(isian.teks.containsKey('equipment.serial_number'), isFalse);
      expect(isian.teks.containsKey('customer.nama'), isFalse);
      expect(isian.teks.containsKey('reviewer.nama'), isFalse);
    });

    test('kolom non-tabel yang udah diketik manual NGGAK ketimpa', () {
      final isian = buatState();
      isian.teks['suhu_awal']!.text = '23.0';

      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          field: {
            'suhu_awal': NilaiHeader(
              nilai: '22.2',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          },
        ),
      );

      expect(terisi, 0);
      expect(isian.teks['suhu_awal']!.text, '23.0');
    });

    test('tanggal_kalibrasi udah keisi hari ini → AI nggak nimpa', () {
      final isian = buatState();
      final sebelum = isian.tanggal['tanggal_kalibrasi'];

      isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          tanggal: {
            'tanggal_kalibrasi': NilaiHeader(
              nilai: '01/01/2020',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          },
        ),
      );

      expect(isian.tanggal['tanggal_kalibrasi'], sebelum);
    });

    test('usage check dari AI SELALU ditandai perlu dicek', () {
      // Centang yang kebalik itu klaim standar mana yang dipakai — alias
      // ketertelusuran. Beda kelas dari salah baca satu angka, jadi keyakinan
      // "high" pun nggak cukup buat ngelolosin tanpa mata manusia.
      final isian = buatState();
      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          usageCheck: [
            UsageCheckAi(
              standardId: 3,
              dipakai: true,
              keterangan: 'buffer 4',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          ],
        ),
      );

      expect(terisi, 1);
      expect(isian.usageCheck[3]!.dipakai, isTrue);
      expect(isian.usageCheck[3]!.keterangan.text, 'buffer 4');
      expect(
        isian.selRendahKeyakinan.contains(LembarKerjaState.kunciUsage(3)),
        isTrue,
      );
    });

    test('foto tabel Before nggak nyentuh tabel After', () {
      final isian = buatState();
      isian.terapkanHasilEkstraksi(contohHasil(), tahap: 'sebelum_adjustment');

      final titik4 = isian.titik[4.00]!;
      expect(titik4.kotak('sebelum_adjustment', 'pembacaan', 0).text, '4.01');
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, isEmpty);
    });

    test('hasil OCR ikut kekirim lewat payload, sel sisanya tetap null', () {
      final isian = buatState()..alat = null;
      isian.terapkanHasilEkstraksi(contohHasil(), tahap: 'sesudah_adjustment');

      final titik4 = isian.titik[4.00]!.toSubmission().toJson();

      // Dua Repeat keisi dari foto, tiga sisanya tetap null di posisinya.
      expect(titik4['pembacaan'], [4.01, 4.02, null, null, null]);
    });

    /// Asal-usul angka ikut kesimpen, bukan cuma angkanya.
    ///
    /// Dulu payload selalu nulis `input_method: manual`, termasuk buat tabel
    /// yang dibaca AI dari foto. Waktu ada angka sertifikat yang kelihatan
    /// meleset (6 Agt 2026, chlorine titik 1,83), pertanyaan pertama admin —
    /// "ini diketik atau hasil foto?" — cuma bisa dijawab dengan ngubek log
    /// server, dan log-nya nggak selamanya ada.
    test('sesi yang tabelnya dari foto kecatat ai_vision, bukan manual', () {
      final polos = buatState()..alat = daftarAlatMock.first;
      expect(polos.toSubmission(draft: false).toJson()['input_method'], 'manual');

      final difoto = buatState()..alat = daftarAlatMock.first;
      difoto.terapkanHasilEkstraksi(contohHasil(), tahap: 'sesudah_adjustment');

      expect(
        difoto.toSubmission(draft: false).toJson()['input_method'],
        'ai_vision',
      );
    });
  });

  _testDropdownGagal();
  _testTurbidimeter();
  _testChlorine();
  _testRefractometer();
  _testKonfirmasiKirim();
}

/// Refractometer — jenis alat KEEMPAT yang punya lembar kerja sendiri
/// (`SIDIK-FM-CAL-0523_Rev.2`, satu halaman).
///
/// Angka-angka di grup ini dari sesi master `2211.11.R`
/// (`Refractometer_CSV/INPUT DATA.csv` + `PERHITUNGAN.csv`), sesi yang sama yang
/// dijaga `SertifikatCocokMasterTest` di backend. Kalau layar ini nampilin atau
/// ngirim angka lain, yang salah layarnya.
void _testRefractometer() {
  group('Refractometer: suhu tiap pembacaan ikut kekirim', () {
    /// **Test paling penting di grup ini.**
    ///
    /// Beda paling tajam dari tiga alat sebelumnya: di lembar Chlorine kolom °C
    /// cuma dicatat buat jejak, di sini dia yang dipakai NGITUNG. Indeks bias
    /// berubah ikut suhu, jadi backend mindahin pembacaan ke 20 °C dulu
    /// (`Corrected = Observed + 0,00045 × (T − 20)`) sebelum diadu ke larutan
    /// standar.
    ///
    /// Di master, Repeat 5 titik 1,33659 suhunya **35 °C** sementara empat
    /// lainnya 25 °C — rata-ratanya jadi 27, dan `1,3362` jadi `1,33935` di
    /// sertifikat. Satu angka 35 itu yang mindahin hasilnya. Kalau layar ini
    /// ngedrop atau mbuletin kolom suhu, sertifikatnya meleset tanpa ada satu
    /// pun yang error — persis jenis kegagalan yang bikin grup ini ditulis.
    testWidgets('kolom suhu nyampe utuh per pembacaan, termasuk yang 35 °C', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'refractometer'));

      await _pilihAlat(tester, alat: 'Refractometer · C12345');

      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Master `INPUT DATA.csv` blok After Adjustment: dua titik, lima Repeat,
      // dan Repeat 5 titik pertama suhunya 35 °C.
      const suhu174 = ['25', '25', '25', '25', '35'];
      for (var r = 0; r < 5; r++) {
        await tester.enterText(kotak.at(r * 2), '1,3362');
        await tester.enterText(kotak.at(r * 2 + 1), suhu174[r]);
        await tester.enterText(kotak.at(10 + r * 2), '1,3986');
        await tester.enterText(kotak.at(10 + r * 2 + 1), '25');
      }
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;
      final titik1 = measurements.first as Map<String, dynamic>;
      final titik2 = measurements.last as Map<String, dynamic>;

      expect(titik1['titik_ukur'], 1.33659);
      expect(titik1['pembacaan'], [1.3362, 1.3362, 1.3362, 1.3362, 1.3362]);
      expect(titik1['suhu'], [25.0, 25.0, 25.0, 25.0, 35.0]);
      expect(titik1['satuan'], 'n20D');

      expect(titik2['titik_ukur'], 1.39986);
      expect(titik2['pembacaan'], [1.3986, 1.3986, 1.3986, 1.3986, 1.3986]);
      expect(titik2['suhu'], [25.0, 25.0, 25.0, 25.0, 25.0]);
    });

    /// Empat desimal itu resolusi alatnya (0,0001). Kalau ada yang mbuletin
    /// pembacaan di jalan — mis. nganggep dua desimal kayak tiga alat lain —
    /// `1,3362` jadi `1,34` dan sertifikatnya meleset 0,004 n20D, empat puluh
    /// kali resolusi alatnya.
    testWidgets('empat desimal nggak dibuletin di jalan', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'refractometer'));

      await _pilihAlat(tester, alat: 'Refractometer · C12345');

      final kotak = find.descendant(
        of: find
            .ancestor(
              of: find.text('After adjustment Reading'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      );
      await tester.enterText(kotak.at(0), '1,3362');
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;
      expect((measurements.first as Map)['pembacaan'], [
        1.3362,
        null,
        null,
        null,
        null,
      ]);
    });

    testWidgets('lembarnya satu halaman & titiknya dua, bukan tiga', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'refractometer'),
      );

      expect(find.text('SIDIK-FM-CAL-0523_Rev.2'), findsOneWidget);
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);

      // Larutan standarnya empat baris walau titik yang dikalibrasi cuma dua:
      // satu botol fisik dipakai buat dua satuan sekaligus.
      expect(
        find.text('Refractometer Std Solution 1.33659 n20D'),
        findsOneWidget,
      );
      expect(find.text('Refractometer Std Solution 2.5 oBrix'), findsOneWidget);

      // Satuan ditanya di depan — dia yang nentuin koefisien suhu (0,00045 vs
      // 0,07), titik standar, sama CMC-nya.
      expect(find.text('7. Satuan Refracto'), findsOneWidget);
    });

    testWidgets('sesi baru masuk antrean sebagai Refractometer', (tester) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'refractometer'),
      );

      await _pilihAlat(tester, alat: 'Refractometer · C12345');
      await _kirimKeAdmin(tester);

      expect(MockStore.instance.sesi.first.namaAlat, 'Refractometer (sesi baru)');
    });

    /// Dropdown "7. Satuan Refracto" mesti **nyampe ke payload**, bukan cuma
    /// kelihatan di layar.
    ///
    /// Pilihannya nentuin koefisien suhu yang dipakai backend buat mindahin
    /// pembacaan ke 20 °C — 0,00045/°C buat n20D, 0,07/°C buat °Brix, beda 155
    /// kali. Waktu kolom ini belum kerender sama sekali, seluruh sesi °Brix
    /// diam-diam kekirim sebagai n20D: nggak ada yang error, angkanya cuma
    /// salah.
    testWidgets('pilihan °Brix ikut ke tiap measurements[].satuan', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'refractometer'));

      await _pilihAlat(tester, alat: 'Refractometer · C12345');

      await tester.tap(
        find.ancestor(
          of: find.text('7. Satuan Refracto'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('°Brix').last);
      await tester.pumpAndSettle();

      final kotak = find.descendant(
        of: find
            .ancestor(
              of: find.text('After adjustment Reading'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      );
      await tester.enterText(kotak.at(0), '1,3362');
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      // DUA-DUANYA, bukan cuma titik yang keisi: satuan itu sifat alatnya,
      // bukan sifat baris yang kebetulan diketik.
      expect(
        measurements.map((m) => (m as Map)['satuan']).toList(),
        ['°Brix', '°Brix'],
      );

      // **Titik standarnya ikut ganti, bukan cuma labelnya.** Larutan fisiknya
      // sama — BSAG2.5-0034 dibaca 2,5 °Brix ATAU 1,33659 n20D — tapi angka
      // yang ditulis di lembar kerja beda. Sebelum ini sesi °Brix ngirim titik
      // n20D bareng satuan °Brix, lalu dikoreksi pakai koefisien °Brix: nilai
      // standar satu skala, pembacaan skala lain, dan nggak ada yang error.
      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [2.5, 40.0],
      );

      // Backend milih koefisien suhu dari `equipments.satuan`, BUKAN dari
      // satuan per pembacaan — jadi pilihannya mesti nyampe lewat kunci ini
      // juga. Tanpa dia, pembacaannya kelabel °Brix tapi tetap dikoreksi pakai
      // koefisien n20D.
      expect(service.payloadTerakhir!['equipment_satuan'], '°Brix');
    });

    /// Alat yang kecatat °Brix mesti kebaca °Brix **di kotaknya**, bukan cuma
    /// di dalam state.
    ///
    /// Bedanya penting: kalau kotaknya nulis n20D sementara yang dikirim °Brix,
    /// teknisi nyetujuin satu hal dan yang kekirim hal lain. `FormField` nggak
    /// nyinkronin `initialValue` waktu rebuild, jadi ini beneran gampang lepas.
    testWidgets('alat °Brix bikin kotaknya langsung nulis °Brix', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'refractometer'));

      await _pilihAlat(tester, alat: 'Refractometer · C67890');

      // Nilai TERPILIH-nya yang dibaca, bukan sekadar ada tulisan "°Brix" di
      // dalam dropdown. `DropdownButtonFormField` mbangun SEMUA item-nya di
      // tree buat ngukur lebar, jadi `find.text('°Brix')` ketemu terus — kepilih
      // atau nggak. Assertion versi itu lolos dua-duanya, dan gara-gara itu bug
      // preselect-nya sempat lolos ke HP (7 Agt 2026).
      final dropdown = find.descendant(
        of: find.ancestor(
          of: find.text('7. Satuan Refracto'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        matching: find.byType(DropdownButton<String>),
      );
      expect(tester.widget<DropdownButton<String>>(dropdown).value, '°Brix');

      await _kirimKeAdmin(tester);
      expect(service.payloadTerakhir!['equipment_satuan'], '°Brix');
    });
  });

  group('Refractometer: satuan awal ngikut master alat', () {
    LembarKerjaState buatState() => LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaRefractometer()),
      clientRequestId: 'uuid-test',
    );

    EquipmentLookup alat(
      String satuan, {
      String serial = 'C12345',
      String merk = '',
    }) => EquipmentLookup(
      id: 17,
      namaAlat: 'Refractometer',
      serialNumber: serial,
      kategori: 'instrumen-analitik',
      status: 'aktif',
      satuan: satuan,
      merk: merk,
    );

    /// Alat yang didaftarin sebagai °Brix mesti KEBUKA sebagai °Brix.
    ///
    /// Kalau formulirnya balik ke bawaan n20D, teknisi mesti inget sendiri buat
    /// ngeganti — dan yang lupa nggak dapat peringatan apa pun, cuma sertifikat
    /// yang koefisien suhunya salah.
    test('alat °Brix bikin formulirnya kebuka di °Brix', () {
      final isian = buatState()..alat = alat('°Brix');
      expect(isian.satuan, 'n20D'); // bawaan formulir, sebelum alat dibaca

      isian.isiDariAlat();
      expect(isian.satuan, '°Brix');

      // Titik yang udah kebentuk duluan ikut kebawa — bukan cuma nilai di layar.
      expect(isian.titik.values.map((t) => t.satuan).toSet(), {'°Brix'});
    });

    /// Labnya nulis `oBrix` di Excel dan `°Brix` di lampiran akreditasi, jadi
    /// master alat bisa nyimpen ejaan mana pun. Backend
    /// (`RefractometerProfile::satuan()`) nganggep dua-duanya °Brix; layar ini
    /// mesti sepakat, bukan diam-diam jatuh ke n20D gara-gara beda satu huruf.
    test('ejaan `oBrix` dari master tetap kebaca °Brix', () {
      final isian = buatState()..alat = alat('oBrix');
      isian.isiDariAlat();

      expect(isian.satuan, '°Brix');
    });

    /// Master alat sering basi — barang fisik yang datang bisa beda dari yang
    /// kecatat waktu didaftarin. Yang sah tetap yang dibaca teknisi di lapangan.
    test('pilihan teknisi nggak ketimpa master', () {
      final isian = buatState()
        ..satuan = 'n20D'
        ..alat = alat('°Brix');
      isian.isiDariAlat();

      expect(isian.satuan, 'n20D');
    });

    /// Tiga alat lama nggak punya kolom "Satuan Refracto" sama sekali, jadi
    /// master alat nggak boleh ngutak-atik satuan mereka lewat pintu belakang
    /// ini — apa pun isi `equipments.satuan`.
    test('alat tanpa kolom satuan nggak kesentuh', () {
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'uuid-test',
      )..alat = alat('°Brix');
      isian.isiDariAlat();

      expect(isian.satuan, 'pH');
    });

    /// Ganti alat = identitasnya ikut ganti SEMUA, bukan setengah-setengah.
    ///
    /// **Bug nyata, ketemu di HP 7 Agt 2026.** Pilih Jangka Sorong, terus ganti
    /// ke Refractometer Atago: Type/Model & Merk ikut alat baru (dua kolom itu
    /// kosong di Jangka Sorong, jadi kena aturan "isi yang kosong"), tapi Serial
    /// Number nyisa `MT-500-196-30` punya si jangka sorong. Satu blok identitas
    /// berisi dua alat berbeda, di lembar kerja yang gunanya justru nyatet alat
    /// mana yang dikalibrasi — dan nggak ada satu pun yang error.
    test('ganti alat nggak ninggalin identitas alat sebelumnya', () {
      final isian = buatState()..alat = alat('n20D', serial: 'MT-500-196-30');
      isian.isiDariAlat();
      expect(isian.teks['alat_serial_number']!.text, 'MT-500-196-30');

      isian
        ..alat = alat('°Brix', serial: 'C67890', merk: 'Atago')
        ..isiDariAlat();

      expect(isian.teks['alat_serial_number']!.text, 'C67890');
      expect(isian.teks['alat_merk']!.text, 'Atago');
    });

    /// Alat baru yang serial-nya belum kecatat di master mesti nampilin kotak
    /// KOSONG, biar teknisi ngisi dari badan alat. Nyisain serial alat
    /// sebelumnya itu kegagalan yang sama, cuma lebih sunyi.
    test('alat baru tanpa serial mengosongkan kolomnya, bukan nyisain yang lama',
        () {
      final isian = buatState()..alat = alat('n20D', serial: 'MT-500-196-30');
      isian.isiDariAlat();

      isian
        ..alat = alat('n20D', serial: '')
        ..isiDariAlat();

      expect(isian.teks['alat_serial_number']!.text, isEmpty);
    });

    /// Pagar yang bikin perbaikan di atas aman: yang DIKETIK teknisi tetap
    /// haram disentuh. Master diisi admin dan sering beda dari unit fisik yang
    /// beneran datang — yang sah tetap yang dibaca teknisi dari badan alat.
    test('yang diketik teknisi nggak ketimpa waktu ganti alat', () {
      final isian = buatState()..alat = alat('n20D', serial: 'C12345');
      isian.isiDariAlat();

      isian.teks['alat_serial_number']!.text = 'C12345-REV2';

      isian
        ..alat = alat('°Brix', serial: 'C67890')
        ..isiDariAlat();

      expect(isian.teks['alat_serial_number']!.text, 'C12345-REV2');
    });

    /// Ganti satuan nuker baris tabelnya, bukan cuma label kolomnya.
    test('titik standar ikut satuan: n20D 1,33659/1,39986 → °Brix 2,5/40', () {
      final isian = buatState();
      expect(isian.titikUrut.map((t) => t.titikUkur), [1.33659, 1.39986]);

      isian.satuan = '°Brix';
      expect(isian.titikUrut.map((t) => t.titikUkur), [2.5, 40.0]);
      expect(isian.titikUrut.map((t) => t.label), ['2,5', '40']);

      // Balik lagi ke n20D tetap dapat titik n20D — bukan nyangkut di °Brix.
      isian.satuan = 'n20D';
      expect(isian.titikUrut.map((t) => t.titikUkur), [1.33659, 1.39986]);
    });

    /// Pembacaan yang udah diketik bakal kebuang waktu satuannya diganti, dan
    /// itu memang benar — angka n20D nggak punya arti sebagai °Brix. Yang nggak
    /// boleh: ilang tanpa ditanya. State ngasih tau layar kapan mesti nanya.
    test('layar dikasih tau kalau ganti satuan bakal ngosongin tabel', () {
      final isian = buatState();

      // Tabel masih kosong → nggak ada yang perlu dikonfirmasi.
      expect(isian.gantiSatuanMenghapusIsian('°Brix'), isFalse);

      isian.titik[1.33659]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
          '1,3362';
      expect(isian.gantiSatuanMenghapusIsian('°Brix'), isTrue);

      // Satuan yang sama nggak ngubah tabel, jadi nggak perlu nanya walau ada
      // isian.
      expect(isian.gantiSatuanMenghapusIsian('n20D'), isFalse);
    });

    /// Satuan kena kelas bug yang sama, dan taruhannya paling tinggi: dia yang
    /// nentuin koefisien normalisasi suhu di backend (0,00045/°C vs 0,07/°C).
    test('ganti ke alat °Brix bikin satuannya ikut, kalau teknisi belum milih',
        () {
      final isian = buatState()..alat = alat('n20D');
      isian.isiDariAlat();
      expect(isian.satuan, 'n20D');

      isian
        ..alat = alat('°Brix')
        ..isiDariAlat();

      expect(isian.satuan, '°Brix');
    });

    /// `equipment_satuan` nulis ke data MASTER alat di backend. Kalau lembar pH
    /// ikut ngirimnya, tiap sesi pH diam-diam nyetel `equipments.satuan` jadi
    /// "pH" — data master keubah sama kiriman yang nggak pernah nanya soal itu.
    test('kunci equipment_satuan cuma ikut buat lembar yang punya kolomnya', () {
      final refracto = buatState()..alat = alat('n20D');
      expect(
        refracto.toSubmission(draft: false).toJson()['equipment_satuan'],
        'n20D',
      );

      final ph = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'uuid-test',
      )..alat = alat('n20D');

      expect(
        ph.toSubmission(draft: false).toJson().containsKey('equipment_satuan'),
        isFalse,
      );
    });
  });
}

/// Chlorin Meter — jenis alat KETIGA yang punya lembar kerja sendiri
/// (`SIDIK-FM-CAL-0531_Rev.2`, satu halaman, metode SIDIK-IK-CAL-0524).
void _testChlorine() {
  LembarKerja bentukChlorine({bool untukAdmin = false}) => LembarKerja.fromJson(
    contohBentukLembarKerjaChlorine(untukAdmin: untukAdmin),
  );

  group('Chlorin Meter: titiknya ikut akreditasi, bukan yang tercetak', () {
    /// **Test paling penting di grup ini.**
    ///
    /// Lembar cetak Rev.2 yang dipegang teknisi nulis `Solution Standard 0.40`
    /// & `4.00`. Tiga sumber yang lebih baru bilang 1,74 & 1,83: lampiran
    /// akreditasi LK-285-IDN no. 42, `Chlorine_Meter_CSV/DATABASE.csv`, dan
    /// sesi asli 0189-CAL-624. Yang dipakai yang ADA DI LINGKUP AKREDITASI —
    /// kalibrasi di titik luar lampiran nggak bisa jadi sertifikat.
    ///
    /// Kalau suatu hari ada yang "mbenerin" ini ngikut kertasnya, test ini yang
    /// bakal teriak duluan. Jangan diubah tanpa ngurus lampirannya dulu.
    test('titik ukurnya 1,74 & 1,83 — BUKAN 0,40 & 4,00 yang dicetak', () {
      final bentuk = bentukChlorine();

      expect(bentuk.larutanStandar, [1.74, 1.83]);
      expect(bentuk.larutanStandar, isNot(contains(0.40)));
      expect(bentuk.larutanStandar, isNot(contains(4.00)));
      expect(bentuk.satuan, 'mg/L');
    });

    test('profil chlorine_meter → dokumen 0531, bukan 0509 punya pH', () async {
      final turun = await MockLembarKerjaService().ambilBentuk(
        't',
        profil: 'chlorine_meter',
      );

      expect(turun.kodeDokumen, 'SIDIK-FM-CAL-0531_Rev.2');
      expect(turun.judul, 'Calibration Worksheet - Chlorine Meter');
      expect(turun.larutanStandar, [1.74, 1.83]);
    });

    test('DUA titik, bukan tiga — pH & Turbidimeter kebetulan sama-sama 3', () {
      final tabel = bentukChlorine()
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      expect(tabel.baris, hasLength(2));
      expect(tabel.baris.map((b) => b.titikUkur), [1.74, 1.83]);
      expect(tabel.kolom.map((k) => k.label), ['mg/L', '°C']);
    });

    test('resolusi SERAGAM 0,01 → desimal per baris sengaja nggak dikirim', () {
      final tabel = bentukChlorine()
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      // Beda dari Turbidimeter (2/1/0). Alat ini resolusinya sama di dua titik,
      // jadi `null` = seragam — bukan lupa diisi.
      expect(tabel.baris.map((b) => b.desimal), [null, null]);
      expect(tabel.baris.map((b) => b.resolusi), [null, null]);
    });

    test('STANDARD-nya larutan chlorine dari DATABASE.csv', () {
      final standar =
          bentukChlorine().bagian.firstWhere((b) => b.kode == 'usage_check');

      expect(standar.baris.map((b) => b.label), [
        'Chlorine Standard Solution 1.74 mg/L',
        'Chlorine Standar Cuvettes 1.83 mg/L',
        'RTD Sensor/SH1/20',
        'Victor 14+/992613877',
      ]);
      expect(standar.baris.last.terdaftar, isFalse);
      expect(standar.baris.last.standardId, isNull);
    });

    test('satu halaman — `Page 1 of 1` di kertasnya', () {
      expect(bentukChlorine().halaman, [1]);
    });

    test('kolom admin tetap disaring sama kayak dua alat sebelumnya', () {
      Iterable<String> kode(LembarKerja lk) =>
          lk.bagian.expand((b) => b.field).map((f) => f.kode);

      expect(kode(bentukChlorine()), isNot(contains('calibration_method_id')));
      expect(
        kode(bentukChlorine(untukAdmin: true)),
        contains('calibration_method_id'),
      );
    });
  });

  group('nama alat → profil', () {
    /// `namaAlat` itu teks bebas dari lampiran akreditasi, bukan enum. Lampiran
    /// nulis "Chlorin Meter", lembar kerjanya "Chlorine Meter" — dua-duanya
    /// wajib nyampe ke profil yang sama. Dulu dicocokin persis, jadi beda satu
    /// huruf bikin alatnya diam-diam jatuh ke form generik tanpa error.
    test('dua ejaan Chlorin/Chlorine sama-sama ke chlorine_meter', () {
      expect(profilLembarKerjaUntuk('Chlorin Meter'), 'chlorine_meter');
      expect(profilLembarKerjaUntuk('Chlorine Meter'), 'chlorine_meter');
    });

    test('beda huruf besar-kecil & spasi dobel nggak bikin jatuh ke generik', () {
      expect(profilLembarKerjaUntuk('CHLORINE METER'), 'chlorine_meter');
      expect(profilLembarKerjaUntuk('  chlorine   meter  '), 'chlorine_meter');
      expect(profilLembarKerjaUntuk('pH METER'), 'ph_meter');
      expect(profilLembarKerjaUntuk('turbidimeter'), 'turbidimeter');
    });

    test('alat tanpa lembar khusus tetap null → form generik', () {
      expect(profilLembarKerjaUntuk('Conductivity Meter'), isNull);
      expect(profilLembarKerjaUntuk('Timbangan'), isNull);
      expect(profilLembarKerjaUntuk(''), isNull);
    });
  });

  group('Chlorin Meter di layar', () {
    testWidgets('dua titik mg/L ikut terkirim, sel kosong tetap null', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      expect(find.text('SIDIK-FM-CAL-0531_Rev.2'), findsOneWidget);
      expect(find.text('Chlorine Standard Solution 1.74 mg/L'), findsOneWidget);
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');

      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Angka dari sesi asli 0189-CAL-624: titik 1,74 kebaca 1,76 di 25,7 °C.
      await tester.enterText(kotak.at(0), '1,76');
      await tester.enterText(kotak.at(1), '25.7');
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [1.74, 1.83],
      );

      final titik174 = measurements.first as Map<String, dynamic>;
      expect(titik174['pembacaan'], [1.76, null, null, null, null]);
      expect(titik174['suhu'], [25.7, null, null, null, null]);
      expect(titik174['satuan'], 'mg/L');
    });

    testWidgets('sesi baru masuk antrean sebagai Chlorine, bukan alat lain', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'chlorine_meter'),
      );

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');
      await _kirimKeAdmin(tester);

      expect(
        MockStore.instance.sesi.first.namaAlat,
        'Chlorine Meter Hanna (sesi baru)',
      );
    });

    /// Seluruh tabel diisi, bukan satu sel — yang dijaga di sini **pemetaan
    /// baris**, bukan "angka bisa masuk".
    ///
    /// 6 Agt 2026: sertifikat di HP nampilin titik kedua `1,90` / `-0,07`,
    /// padahal sertifikat asli `0189-CAL-624` nulis `1,86` / `-0,03`. Yang
    /// dicurigai duluan olah datanya; ternyata pembacaan yang KESIMPEN emang
    /// 1,90 — hitungannya bener buat masukan itu (dibuktiin
    /// `SertifikatCocokMasterTest` di backend). Buat mastiin bukan layar ini
    /// yang naruh angka di baris yang salah, seluruh tabel diadu ke masternya.
    ///
    /// Kalau dua baris ini ketuker atau nyampur, angkanya tetap "kelihatan
    /// wajar" di layar — nggak ada yang error, dan ketahuannya baru waktu
    /// pelanggan mbandingin sertifikat sama kertas lab.
    testWidgets('dua titik keisi penuh: angkanya nggak ketuker antar baris', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');

      // Angka master `Chlorine_Meter_CSV/INPUT_DATA.csv` baris 44–48: titik
      // 1,74 kebaca 1,76 (Repeat 5 turun ke 1,75), titik 1,83 kebaca 1,86 rata.
      const bacaan174 = ['1,76', '1,76', '1,76', '1,76', '1,75'];
      const bacaan183 = ['1,86', '1,86', '1,86', '1,86', '1,86'];
      const suhu = ['25,7', '25,8', '25,8', '25,8', '25,8'];

      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Satu baris = 5 Repeat × 2 kotak (mg/L, °C), baris 1,74 duluan.
      for (var r = 0; r < 5; r++) {
        await tester.enterText(kotak.at(r * 2), bacaan174[r]);
        await tester.enterText(kotak.at(r * 2 + 1), suhu[r]);
        await tester.enterText(kotak.at(10 + r * 2), bacaan183[r]);
        await tester.enterText(kotak.at(10 + r * 2 + 1), suhu[r]);
      }
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;
      final titik174 = measurements.first as Map<String, dynamic>;
      final titik183 = measurements.last as Map<String, dynamic>;

      expect(titik174['titik_ukur'], 1.74);
      expect(titik174['pembacaan'], [1.76, 1.76, 1.76, 1.76, 1.75]);
      expect(titik183['titik_ukur'], 1.83);
      expect(titik183['pembacaan'], [1.86, 1.86, 1.86, 1.86, 1.86]);

      // Suhunya sama di dua baris, jadi kalau kolom pembacaan & suhu ketuker
      // bedanya nggak kelihatan dari nilai suhu doang — makanya dicek juga
      // bahwa kolom pembacaan nggak kemasukan 25,x.
      expect(titik174['suhu'], [25.7, 25.8, 25.8, 25.8, 25.8]);
      expect(titik183['suhu'], [25.7, 25.8, 25.8, 25.8, 25.8]);
    });
  });
}

/// Tiga dropdown di lembar kerja dulu HILANG tanpa sepatah kata kalau daftarnya
/// gagal diambil. Buat teknisi, kolom yang nggak ada itu nggak bisa dibedain
/// dari kolom yang emang nggak diminta di lembar ini — dia lanjut ngisi,
/// ngirim, dan baru tahu ada yang kurang waktu admin ngembaliin sesinya.
void _testDropdownGagal() {
  group('daftar gagal dimuat → kolomnya bilang, bukan menghilang', () {
    testWidgets('standar acuan per titik: pesan + COBA LAGI', (tester) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(
          MockLembarKerjaService(),
          standar: MockStandardService(gagal: true),
        ),
      );
      await _keHalamanAkhir(tester);

      // Tiga titik pH → tiga dropdown standar per titik, tiga-tiganya wajib
      // ngaku. Ini ketertelusuran: sesi tanpa standar yang ketaut nggak bisa
      // jadi sertifikat berakreditasi.
      expect(find.text('Gagal memuat standar acuan.'), findsNWidgets(3));
      expect(find.text('COBA LAGI'), findsNWidgets(3));
    });

    testWidgets('ruangan: gagal muat beda dari "belum ada ruangan"', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), ruangan: MockRoomService(gagal: true)),
      );

      expect(find.text('Gagal memuat daftar ruangan.'), findsOneWidget);
    });

    testWidgets('daftar sehat → nggak ada pesan gagal yang nyasar', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));
      await _keHalamanAkhir(tester);

      expect(find.text('Gagal memuat standar acuan.'), findsNothing);
      expect(find.text('Gagal memuat daftar ruangan.'), findsNothing);
    });

    testWidgets('lembar tetap bisa dikirim walau daftarnya gagal', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(
        tester,
        _app(
          service,
          standar: MockStandardService(gagal: true),
          ruangan: MockRoomService(gagal: true),
        ),
      );

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await _kirimKeAdmin(tester);

      // Aturan lembar kerja nggak berubah: tombol kirim NGGAK PERNAH dikunci.
      // Pesan gagal itu ngasih tahu, bukan ngeblok — kalau sampai ngeblok,
      // teknisi di lapangan kehilangan seluruh isian gara-gara satu daftar
      // yang nggak keambil.
      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['standard_id'], isNull);
      expect(service.payloadTerakhir!['room_id'], isNull);
    });
  });
}

/// Turbidimeter itu jenis alat KEDUA yang punya lembar kerja sendiri, dan
/// bentuknya beda dari pH di tempat-tempat yang gampang ketuker: satu halaman
/// (bukan dua), titik 1/100/1000 NTU, dan resolusinya beda PER BARIS. Selama
/// ini semua test lembar kerja cuma megang pH, jadi kalau jalur `?profil=`
/// diam-diam balik ke bentuk pH, nggak ada satu pun yang gagal.
void _testTurbidimeter() {
  LembarKerja bentukTurbidi({bool untukAdmin = false}) =>
      LembarKerja.fromJson(contohBentukLembarKerjaTurbidi(untukAdmin: untukAdmin));

  group('Turbidimeter: bentuknya sendiri, bukan pH yang disamar', () {
    test('profil dilempar ke backend → dokumen & titik ukurnya ikut ganti', () async {
      final service = MockLembarKerjaService();

      final turbidi = await service.ambilBentuk('t', profil: 'turbidimeter');
      expect(turbidi.kodeDokumen, 'SIDIK-FM-CAL-0530_Rev.2');
      expect(turbidi.satuan, 'NTU');
      expect(turbidi.larutanStandar, [1.0, 100.0, 1000.0]);
    });

    test('profil kosong tetap dapat pH — bukan error, bukan layar kosong', () async {
      final service = MockLembarKerjaService();

      // Layar lama & tautan yang belum bawa `profil` masih ada di app —
      // `LembarKerjaScreen.profil` default-nya `ph_meter`, dan `ApiLembarKerja
      // Service` malah nggak nempelin query-nya sama sekali kalau kosong.
      // Jadi "tanpa profil" wajib jatuh ke pH, bukan error.
      final tanpaProfil = await service.ambilBentuk('t');
      expect(tanpaProfil.kodeDokumen, 'SIDIK-FM-CAL-0509_Rev.4');
      expect(tanpaProfil.satuan, 'pH');
    });

    test('resolusi beda PER BARIS, bukan satu angka buat seluruh tabel', () {
      final tabel = bentukTurbidi()
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      // Ini inti alat ini: 1 NTU dibaca sampai 0,01, 1000 NTU dibulatin ke
      // satuan. Dipaksa satu angka buat semuanya, titik 100 kecetak `101,00`
      // di sertifikat — cacat angka penting, bukan cuma jelek dilihat.
      expect(tabel.baris.map((b) => b.titikUkur), [1.0, 100.0, 1000.0]);
      expect(tabel.baris.map((b) => b.desimal), [2, 1, 0]);
      expect(tabel.baris.map((b) => b.resolusi), [0.01, 0.1, 1.0]);
    });

    test('pH SEBALIKNYA nggak bawa desimal per baris — resolusinya seragam', () {
      final tabel = LembarKerja.fromJson(contohBentukLembarKerja())
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      // Kalau suatu hari pH ikut bawa `desimal`, yang berubah bukan cuma
      // sertifikatnya — jalur "null = seragam" di [BarisTabelHasil] ikut mati.
      expect(tabel.baris.map((b) => b.desimal), [null, null, null]);
    });

    test('STANDARD-nya larutan turbidity, bukan buffer pH', () {
      final standar =
          bentukTurbidi().bagian.firstWhere((b) => b.kode == 'usage_check');

      expect(standar.baris.map((b) => b.label), [
        'Turbidity Standard 1 NTU',
        'Turbidity Standard 100 NTU',
        'Turbidity Standard 1000 NTU',
        'RTD Sensor/SH1/20',
        'Victor 14+/992613877',
      ]);

      // Aturan yang sama kayak pH: standar yang belum kedaftar TETAP jadi
      // baris, tanpa id.
      expect(standar.baris.last.terdaftar, isFalse);
      expect(standar.baris.last.standardId, isNull);
    });

    test('kolom tabelnya NTU, bukan pH yang lupa diganti', () {
      final tabel = bentukTurbidi()
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      expect(tabel.kolom.map((k) => k.label), ['NTU', '°C']);
      expect(tabel.kolom.first.satuan, 'NTU');
    });

    test('satu halaman — sama kayak pH & Chlorine sekarang', () {
      expect(bentukTurbidi().halaman, [1]);
      expect(LembarKerja.fromJson(contohBentukLembarKerja()).halaman, [1]);
    });

    test('kolom admin tetap disaring sama kayak pH', () {
      Iterable<String> kode(LembarKerja lk) =>
          lk.bagian.expand((b) => b.field).map((f) => f.kode);

      expect(kode(bentukTurbidi()), isNot(contains('calibration_method_id')));
      expect(
        kode(bentukTurbidi(untukAdmin: true)),
        contains('calibration_method_id'),
      );
    });
  });

  group('Turbidimeter di layar', () {
    testWidgets('tabel hasil langsung kelihatan, nggak ada balik halaman', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'turbidimeter'),
      );

      expect(find.text('SIDIK-FM-CAL-0530_Rev.2'), findsOneWidget);
      expect(find.text('Turbidity Standard 1 NTU'), findsOneWidget);

      // Beda paling kerasa dari pH: nggak ada halaman 2, jadi tombol lanjutnya
      // nggak boleh nongol sama sekali.
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);
      expect(find.text('Before adjustment Reading'), findsOneWidget);
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);
    });

    testWidgets('tiga titik NTU ikut terkirim, sel kosong tetap null', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'turbidimeter'));

      await _pilihAlat(tester, alat: 'Turbidimeter Hach · HC-2100Q-114');

      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Baris pertama = titik 1 NTU. Repeat 1 & 3 diisi, Repeat 2 dilewat.
      await tester.enterText(kotak.at(0), '1,01');
      await tester.enterText(kotak.at(1), '22.2');
      await tester.enterText(kotak.at(4), '0,99');
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [1.0, 100.0, 1000.0],
      );

      final titik1 = measurements.first as Map<String, dynamic>;
      expect(titik1['pembacaan'], [1.01, null, 0.99, null, null]);
      expect(titik1['suhu'], [22.2, null, null, null, null]);
      expect(titik1['satuan'], 'NTU');
    });

    /// Dua tabel diisi PENUH pakai angka master — yang dijaga di sini pemetaan
    /// baris & tahap, bukan "angka bisa masuk".
    ///
    /// Turbidimeter paling rawan dari tiga alat: tiga titik yang skalanya beda
    /// jauh (1 / 100 / 1.000 NTU) dengan resolusi beda-beda (0,01 / 0,1 / 1).
    /// Kalau angkanya nyasar baris, `1.001` yang mendarat di baris 100 NTU tetap
    /// kelihatan wajar — nggak ada yang error, dan ketahuannya baru waktu
    /// pelanggan mbandingin sertifikat sama kertas lab.
    ///
    /// Before & After sengaja dikasih angka BEDA (99,8 vs 100 · 999 vs 1.000),
    /// beda dari lembar Chlorine yang dua tabelnya kembar. Itu yang bikin
    /// kebocoran antar-tahap kelihatan: kalau tabel Before nulis ke kolom
    /// After, angkanya langsung nggak cocok.
    testWidgets('tiga titik keisi penuh: baris & tahapnya nggak ketuker', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'turbidimeter'));

      await _pilihAlat(tester, alat: 'Turbidimeter Hach · HC-2100Q-114');

      // Angka master `Master Data TurbidiMeter_CSV/INPUT_DATA.csv`:
      // Before baris 38–42, After baris 47–51. Rata-rata After-nya yang jadi
      // Unit Under Test di sertifikat asli: 1,004 · 100,02 · 1.000,6.
      const after = [
        ['1', '1', '1', '1', '1,02'],
        ['100', '100', '100', '100', '100,1'],
        ['1000', '1000', '1001', '1001', '1001'],
      ];
      const before = [
        ['1', '1', '1', '1', '1'],
        ['99,8', '99,8', '99,8', '99,8', '99,8'],
        ['999', '999', '999', '999', '999'],
      ];
      const suhu = ['23,3', '23,4', '23,4'];

      Finder kotakTabel(String judul) => find.descendant(
        of: find
            .ancestor(of: find.text(judul), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      );

      // Satu baris = 5 Repeat × 2 kotak (NTU, °C); baris urut 1 → 100 → 1000.
      for (var titik = 0; titik < 3; titik++) {
        for (var r = 0; r < 5; r++) {
          final sel = titik * 10 + r * 2;
          await tester.enterText(
            kotakTabel('After adjustment Reading').at(sel),
            after[titik][r],
          );
          await tester.enterText(
            kotakTabel('After adjustment Reading').at(sel + 1),
            suhu[titik],
          );
          await tester.enterText(
            kotakTabel('Before adjustment Reading').at(sel),
            before[titik][r],
          );
          await tester.enterText(
            kotakTabel('Before adjustment Reading').at(sel + 1),
            suhu[titik],
          );
        }
      }
      await tester.pumpAndSettle();

      await _kirimKeAdmin(tester);

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [1.0, 100.0, 1000.0],
      );

      final titik1 = measurements[0] as Map<String, dynamic>;
      final titik100 = measurements[1] as Map<String, dynamic>;
      final titik1000 = measurements[2] as Map<String, dynamic>;

      expect(titik1['pembacaan'], [1.0, 1.0, 1.0, 1.0, 1.02]);
      expect(titik100['pembacaan'], [100.0, 100.0, 100.0, 100.0, 100.1]);
      expect(titik1000['pembacaan'], [1000.0, 1000.0, 1001.0, 1001.0, 1001.0]);

      expect(titik1['pembacaan_sebelum'], [1.0, 1.0, 1.0, 1.0, 1.0]);
      expect(titik100['pembacaan_sebelum'], [99.8, 99.8, 99.8, 99.8, 99.8]);
      expect(titik1000['pembacaan_sebelum'], [999.0, 999.0, 999.0, 999.0, 999.0]);

      expect(titik1['suhu'], [23.3, 23.3, 23.3, 23.3, 23.3]);
      expect(titik100['suhu_sebelum'], [23.4, 23.4, 23.4, 23.4, 23.4]);

      // Rata-rata After inilah yang jadi Unit Under Test di sertifikat. Dihitung
      // backend, tapi kalau angkanya udah nyasar dari sini, hitungan sebener
      // apa pun nggak nolong — jadi dicek di sisi ini juga.
      double rata(List<dynamic> n) =>
          n.cast<double>().reduce((a, b) => a + b) / n.length;

      expect(rata(titik1['pembacaan'] as List<dynamic>), closeTo(1.004, 1e-9));
      expect(rata(titik100['pembacaan'] as List<dynamic>), closeTo(100.02, 1e-9));
      expect(rata(titik1000['pembacaan'] as List<dynamic>), closeTo(1000.6, 1e-9));
    });

    testWidgets('sesi baru masuk antrean sebagai Turbidimeter, bukan pH Meter', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'turbidimeter'),
      );

      await _pilihAlat(tester, alat: 'Turbidimeter Hach · HC-2100Q-114');
      await _kirimKeAdmin(tester);

      // Nama sesi di USE_MOCK dulu dipatok 'pH Meter (sesi baru)' — admin yang
      // nyoba alur turbidimeter offline lihat pH di antrean approval dan nggak
      // punya cara buat sadar itu salah.
      expect(
        MockStore.instance.sesi.first.namaAlat,
        'Turbidimeter Hach (sesi baru)',
      );
    });
  });
}

/// Konfirmasi angka sebelum KIRIM KE ADMIN.
///
/// Ini penjaga terakhir buat salah ketik yang angkanya WAJAR — kasus 6 Agt 2026
/// (`0189-CAL-624`): standar 1,83 kecatat 1,90, padahal kertasnya 1,86. Nggak
/// ada pemeriksaan otomatis yang bisa nangkep itu, jadi yang dijaga di sini
/// bukan "angkanya bener", tapi "angkanya sempat dilihat teknisi".
void _testKonfirmasiKirim() {
  group('konfirmasi angka sebelum kirim', () {
    /// Kotak-kotak tabel After adjustment: 5 Repeat × 2 kolom per baris titik,
    /// urutannya sama kayak `_testChlorine`.
    Finder kotakAfter() => find.descendant(
      of: find
          .ancestor(
            of: find.text('After adjustment Reading'),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byType(TextField),
    );

    testWidgets('rata-rata tiap larutan ditunjukin sebelum kekirim', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');

      // Persis angka yang lolos 6 Agt: titik 1,83 kebaca 1,90 rata.
      final kotak = kotakAfter();
      for (var r = 0; r < 5; r++) {
        await tester.enterText(kotak.at(r * 2), '1,76');
        await tester.enterText(kotak.at(10 + r * 2), '1,90');
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Larutan standar & rata-ratanya berdampingan — yang salah ketik
      // kelihatan sendiri waktu diadu ke lembar kerja kertas.
      expect(find.text('Cek dulu angkanya sebelum dikirim'), findsOneWidget);
      expect(find.text('1,74 mg/L'), findsOneWidget);
      expect(find.text('5 dari 5 kotak · rata-rata 1,76'), findsOneWidget);
      expect(find.text('1,83 mg/L'), findsOneWidget);
      expect(find.text('5 dari 5 kotak · rata-rata 1,90'), findsOneWidget);

      // Belum kekirim apa-apa: dialognya nanya, bukan ngabarin.
      expect(service.jumlahKirim, 0);
    });

    testWidgets('Periksa lagi → nggak kekirim & isiannya utuh', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');
      await tester.enterText(kotakAfter().at(10), '1,90');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Periksa lagi'));
      await tester.pumpAndSettle();

      expect(service.jumlahKirim, 0);

      // Balik ke formulir yang sama, bukan formulir kosong — teknisi mundur
      // buat MBENERIN satu angka, bukan buat ngetik ulang semuanya.
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);
      expect(
        (tester.widget(kotakAfter().at(10)) as TextField).controller!.text,
        '1,90',
      );
    });

    testWidgets('Kirim sekarang → angkanya kekirim apa adanya', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');
      await tester.enterText(kotakAfter().at(10), '1,90');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim sekarang'));
      await tester.pumpAndSettle();

      expect(service.jumlahKirim, 1);
      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;
      expect((measurements.last as Map)['pembacaan'], [
        1.90,
        null,
        null,
        null,
        null,
      ]);
    });

    /// Yang dirata-rata cuma After adjustment — itu yang jadi Unit Under Test
    /// di sertifikat. Kalau Before ikut kehitung, angka di dialog beda dari
    /// yang nanti kecetak, dan dialognya malah nyesatin.
    testWidgets('rata-rata cuma dari After adjustment, Before nggak ikut', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'chlorine_meter'),
      );

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');

      final kotakBefore = find.descendant(
        of: find
            .ancestor(
              of: find.text('Before adjustment Reading'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      );
      // As-found sengaja dibikin jauh: kalau kebawa ke rata-rata, angkanya
      // meleset jauh dan test ini gagal keras.
      await tester.enterText(kotakBefore.at(10), '9,00');
      await tester.enterText(kotakAfter().at(10), '1,86');
      await tester.enterText(kotakAfter().at(12), '1,88');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      expect(find.text('2 dari 5 kotak · rata-rata 1,87'), findsOneWidget);
      // Baris yang nggak disentuh sama sekali dibilang apa adanya, bukan 0,00.
      expect(find.text('Belum diisi'), findsOneWidget);
    });

    /// Turbidimeter satu-satunya yang resolusinya beda per titik (0,01 / 0,1 /
    /// 1) — dan itu jalur kode sendiri di `RingkasanTitik.desimal`. Angka di
    /// dialog harus sebentuk sama yang nanti kecetak di sertifikat: teknisi
    /// mbandingin baris ini ke kertas di tangannya, jadi `1.003` yang kebaca
    /// `1003.0` aja udah bikin dia ragu-ragu di titik yang salah.
    testWidgets('Turbidimeter: desimalnya ngikut resolusi tiap titik', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'turbidimeter'),
      );

      await _pilihAlat(tester, alat: 'Turbidimeter Hach · HC-2100Q-114');

      // Satu baris = 5 Repeat × 2 kotak, urutannya 1 / 100 / 1000 NTU.
      final kotak = kotakAfter();
      await tester.enterText(kotak.at(0), '1,02');
      await tester.enterText(kotak.at(2), '1,04');
      await tester.enterText(kotak.at(10), '100,2');
      await tester.enterText(kotak.at(20), '1002');
      await tester.enterText(kotak.at(22), '1004');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      expect(find.text('1 NTU'), findsOneWidget);
      expect(find.text('2 dari 5 kotak · rata-rata 1,03'), findsOneWidget);

      expect(find.text('100 NTU'), findsOneWidget);
      expect(find.text('1 dari 5 kotak · rata-rata 100,2'), findsOneWidget);

      // Titik 1.000 NTU resolusinya 1 — nol desimal, dan ribuannya pakai titik
      // persis kayak `formatSertifikat` di PDF.
      expect(find.text('1000 NTU'), findsOneWidget);
      expect(find.text('2 dari 5 kotak · rata-rata 1.003'), findsOneWidget);
    });

    testWidgets('lembar yang belum diisi nggak usah dikonfirmasi', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Nggak ada angka yang perlu dicek ulang — dialognya cuma jadi satu
      // ketukan sia-sia, dan sesi tabel-nyusul tetap boleh dikirim.
      expect(find.text('Cek dulu angkanya sebelum dikirim'), findsNothing);
      expect(service.jumlahKirim, 1);
    });

    /// Draft itu justru dipakai buat nyimpen kerjaan setengah jadi. Nanyain
    /// "yakin angkanya?" tiap kali teknisi nyimpen di tengah jalan cuma bikin
    /// dialognya diklik tanpa dibaca — pas beneran penting, nggak kebaca lagi.
    testWidgets('simpan draft nggak ditanyain angkanya', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'chlorine_meter'));

      await _pilihAlat(tester, alat: 'Chlorine Meter Hanna · 905320134111');
      await tester.enterText(kotakAfter().at(10), '1,90');
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      expect(find.text('Cek dulu angkanya sebelum dikirim'), findsNothing);
      expect(service.payloadTerakhir!['status'], 'draft');
    });

    /// Dialognya dilihat di HP, bukan di viewport raksasa yang dipakai test
    /// lain. pH punya 3 baris titik, dan teknisi lapangan banyak yang naikin
    /// ukuran huruf HP-nya — dua-duanya nambah tinggi isi dialog.
    ///
    /// Formulirnya diisi di viewport gede dulu (di layar 640 px, dropdown &
    /// tombol kirimnya belum ke-build sama `ListView`, jadi nggak bisa
    /// dipencet). Layarnya baru dikecilkan sesudah dialognya kebuka — yang
    /// diuji emang cuma dialognya.
    ///
    /// Hurufnya 1,3×, bukan lebih: dari 1,5× ke atas TABELNYA sendiri yang
    /// meluber (header "Repeat" tingginya dipatok) — bug lama yang beda
    /// urusan, dan kalau ikut kesenggol di sini kegagalannya jadi nunjuk
    /// tempat yang salah. 1,3× udah cukup: tanpa `scrollable: true` di
    /// dialognya, test ini gagal.
    testWidgets('muat di layar HP dengan huruf gede', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _app(service),
        ),
      );

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);

      final kotak = find.descendant(
        of: find
            .ancestor(
              of: find.text('After adjustment Reading'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      );
      await tester.enterText(kotak.first, '4,01');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();

      // Yang dijaga: dialognya nggak overflow (test gagal sendiri kalau iya)
      // dan tombolnya masih bisa dipencet — bukan cuma "widget-nya ada".
      expect(find.text('Kirim sekarang'), findsOneWidget);
      await tester.tap(find.text('Kirim sekarang'));
      await tester.pumpAndSettle();

      expect(service.jumlahKirim, 1);
    });
  });
}

void _testRevisi() {
  group('revisi: kolom yang ditandai admin', () {
    test('isian teknisi + kode kolom kebaca dari respons sesi', () {
      final isi = IsianTeknisi.fromJson(const {
        'alat_serial_number': 'HN-2211-05',
        'pemilik_nama': 'PT Maju Jaya',
        'suhu_awal': 19.8,
        'revisi_field': ['alat_serial_number', 'suhu_awal'],
      });

      expect(isi.alatSerialNumber, 'HN-2211-05');
      expect(isi.revisiField, {'alat_serial_number', 'suhu_awal'});
    });

    test('formulir keisi ulang dari sesi — teknisi nggak ngetik dari nol', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {
          'alat_serial_number': 'HN-2211-05',
          'alat_merk': 'Hanna',
          'suhu_awal': 19.8,
          'revisi_field': ['alat_serial_number'],
        }),
      );

      expect(state.teks['alat_serial_number']!.text, 'HN-2211-05');
      expect(state.teks['alat_merk']!.text, 'Hanna');
      expect(state.teks['suhu_awal']!.text, '19.8');
      expect(state.revisiField, {'alat_serial_number'});
    });

    test('catatan admin kebaca utuh, bukan cuma kode kolomnya', () {
      final isi = IsianTeknisi.fromJson(const {
        'revisi_field': ['suhu_awal'],
        'catatan_revisi': 'Suhu awal 19,8 nggak masuk rentang IK (20±2). '
            'Ulangi pembacaannya sesudah alatnya settle 15 menit.',
      });

      // Kolom bergaris merah cuma jawab MANA yang salah. Yang bikin teknisi
      // ngerti harus ngapain itu alasannya — dan itu mesti utuh, nggak
      // dipotong kayak di notifikasi.
      expect(isi.catatanRevisi, contains('settle 15 menit'));
    });

    test('catatan admin dibawa ke state, kebaca di layar betulannya', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {
          'revisi_field': ['suhu_awal'],
          'catatan_revisi': 'Ulangi pembacaan suhu awal.',
        }),
      );

      expect(state.catatanRevisi, 'Ulangi pembacaan suhu awal.');
      expect(state.adaRevisi, isTrue);
    });

    test('ditolak dengan catatan TAPI tanpa nandain kolom tetap kelihatan', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      // `revisi_field` boleh null di backend — admin sah nolak cuma pakai
      // catatan. Dulu banner-nya digantung ke `revisiField.isNotEmpty`, jadi
      // teknisi dapat lembar yang kelihatan normal padahal udah dikembaliin.
      state.muatDariSesi(
        IsianTeknisi.fromJson(const {
          'catatan_revisi': 'Lembarnya ketuker sama sesi lain, kirim ulang.',
        }),
      );

      expect(state.revisiField, isEmpty);
      expect(state.adaRevisi, isTrue);
    });

    test('sesi normal (nggak ditolak) nggak munculin banner apa pun', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {'alat_merk': 'Hanna'}),
      );

      expect(state.adaRevisi, isFalse);
    });

    test('catatan kosong/spasi doang nggak dianggap revisi', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {'catatan_revisi': '   '}),
      );

      expect(state.adaRevisi, isFalse);
    });

    test('yang udah diketik teknisi NGGAK ketimpa data lama', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      // Layar bisa kebuka duluan & teknisi langsung ngetik sebelum detail
      // sesinya nyampe dari jaringan yang lelet. Kalau data lama nimpa, koreksi
      // teknisi ilang di depan matanya sendiri.
      state.teks['alat_serial_number']!.text = 'HN-BARU-DIKETIK';

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {'alat_serial_number': 'HN-LAMA'}),
      );

      expect(state.teks['alat_serial_number']!.text, 'HN-BARU-DIKETIK');
    });

    test('pilih alat → identitas & pemilik keisi sendiri dari master', () async {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      final daftar = await MockEquipmentLookupService().cari('');
      state.alat = daftar.firstWhere(
        (a) => a.pelangganNama.isNotEmpty,
      );
      state.isiDariAlat();

      // Data master udah ada waktu pelanggannya didaftarin — nyuruh teknisi
      // ngetik ulang di lapangan itu kerja dobel yang bikin salah ketik.
      expect(state.teks['pemilik_nama']!.text, isNotEmpty);
      expect(state.teks['alat_serial_number']!.text, isNotEmpty);
    });

    test('yang udah diketik NGGAK keganti waktu ganti alat', () async {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      // Teknisi baca serial dari badan alat — beda dari master, dan ITU yang
      // sah di dokumen kalibrasi.
      state.teks['alat_serial_number']!.text = 'DIBACA-DARI-ALAT';
      state.alat = (await MockEquipmentLookupService().cari('')).first;
      state.isiDariAlat();

      expect(state.teks['alat_serial_number']!.text, 'DIBACA-DARI-ALAT');
    });

    test('sesi tanpa revisi_field nggak nyorot apa-apa', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(IsianTeknisi.fromJson(const {'alat_merk': 'Hanna'}));

      expect(state.revisiField, isEmpty);
    });
  });
}
