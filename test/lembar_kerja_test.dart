import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/worksheet_ocr.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Lembar kerjanya panjang banget (2 tabel x 3 baris x 5 repeat x 2 kolom =
/// 60 kotak angka doang). `ListView` cuma nge-build yang deket viewport, jadi
/// index widget-nya berubah-ubah tiap discroll — viewport test dibikin raksasa
/// biar seluruh formulir ke-build sekaligus & index-nya stabil.
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 14000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(MockLembarKerjaService service) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(service),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(),
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
Future<void> _pilihAlat(WidgetTester tester) async {
  await tester.tap(find.text('Pilih alat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
  await tester.pumpAndSettle();
}

void main() {
  group('bentuk formulir datang dari backend', () {
    testWidgets('bagian & kolom digambar dari respons, bukan di-hardcode', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Enam bagian lembar kerja SIDIK-FM-CAL-0509_Rev.4.
      expect(find.text('EQUIPMENT IDENTITY AND CUSTOMER DATA'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('STANDARD CALIBRATION DATA'), findsOneWidget);
      expect(find.text('STANDARD NAME / USAGE CHECK'), findsOneWidget);
      expect(find.text('CALIBRATION RESULT'), findsOneWidget);

      // Dua tabel hasil.
      expect(find.text('Before adjustment Reading'), findsOneWidget);
      expect(find.text('After adjustment Reading'), findsOneWidget);

      expect(find.text('SIDIK-FM-CAL-0509_Rev.4'), findsOneWidget);
    });

    testWidgets('teknisi nggak lihat satu pun kolom administratif', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Backend nggak ngirim kolom ini ke teknisi sama sekali (bukan cuma
      // disembunyiin) — kalau sampai kelihatan, penyaringan per-role bocor.
      expect(find.text('6. Thermohygro used'), findsNothing);
      expect(find.text('2. Calibration Methode'), findsNothing);
      expect(find.textContaining('Order Number'), findsNothing);
    });

    testWidgets('kolom otomatis keisi dari alat & jadi read-only', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      await _pilihAlat(tester);

      // Tujuh kolom yang ketarik otomatis begitu alatnya dipilih.
      expect(find.text('Mettler Toledo'), findsWidgets);
      expect(find.text('Five Easy'), findsWidgets);
      // Pemisah rentangnya en-dash (`–`), bukan hyphen — itu format yang
      // dipakai `EquipmentLookup.rentangTeks` di seluruh layar worksheet.
      expect(find.text('0–14 pH / 0.01 pH'), findsOneWidget);
      expect(
        find.text('PT TIRTA GRACIA SEMESTA MANDIRI'),
        findsOneWidget,
      );
    });
  });

  group('tombol kirim nggak pernah dikunci', () {
    testWidgets('formulir kosong melompong tetap bisa dikirim', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      // Cuma alat yang dipilih. Nol pembacaan, nol kondisi lingkungan.
      await _pilihAlat(tester);

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['status'], 'menunggu_approval');
    });

    testWidgets('simpan draft kirim status draft', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
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

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

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

    testWidgets('titik yang sama sekali kosong tetap ikut terkirim', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

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

      final kotak = find.byType(TextField);
      // Formulir kertasnya pakai koma desimal — teknisi ngetik sesuai yang
      // dia lihat, dan itu nggak boleh jadi angka hilang.
      await tester.enterText(kotak.at(0), '21,3');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Gagal → layarnya TETAP kebuka, isian nggak ilang, teknisi bisa coba lagi.
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

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

      expect(kode(teknisi), isNot(contains('thermohygro_standard_id')));
      expect(kode(teknisi), isNot(contains('calibration_method_id')));
      expect(kode(admin), contains('thermohygro_standard_id'));
      expect(admin.untukAdmin, isTrue);
      expect(teknisi.untukAdmin, isFalse);
    });
  });

  group('OCR tabel worksheet', () {
    /// `baris` itu **Repeat**, isinya satu angka per larutan standar. Dua sumbu
    /// ini gampang kebalik, dan kalau kebalik angkanya nyasar ke buffer yang
    /// salah tanpa ada yang error — makanya diuji eksplisit.
    HasilTabelOcr contohHasil() => const HasilTabelOcr(
      baris: [
        BarisTabel(ph: [4.01, 7.02, 10.11], suhu: [22.2, 22.3, 22.1]),
        BarisTabel(ph: [4.02, 7.03, 10.12], suhu: [22.2, 22.3, 22.1]),
      ],
      teksMentah: '',
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
      final terisi = isian.terapkanHasilOcr(
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

      final terisi = isian.terapkanHasilOcr(
        contohHasil(),
        tahap: 'sesudah_adjustment',
      );

      // Foto boleh dipakai berkali-kali buat nambal yang kurang; yang udah
      // dibetulin manusia harus menang.
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4.00');
      expect(terisi, 11, reason: 'satu sel dilewat karena udah keisi');
    });

    test('foto tabel Before nggak nyentuh tabel After', () {
      final isian = buatState();
      isian.terapkanHasilOcr(contohHasil(), tahap: 'sebelum_adjustment');

      final titik4 = isian.titik[4.00]!;
      expect(titik4.kotak('sebelum_adjustment', 'pembacaan', 0).text, '4.01');
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, isEmpty);
    });

    test('hasil OCR ikut kekirim lewat payload, sel sisanya tetap null', () {
      final isian = buatState()..alat = null;
      isian.terapkanHasilOcr(contohHasil(), tahap: 'sesudah_adjustment');

      final titik4 = isian.titik[4.00]!.toSubmission().toJson();

      // Dua Repeat keisi dari foto, tiga sisanya tetap null di posisinya.
      expect(titik4['pembacaan'], [4.01, 4.02, null, null, null]);
    });
  });
}
