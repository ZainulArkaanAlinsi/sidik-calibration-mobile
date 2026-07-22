import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/ocr_provider.dart';
import 'package:sidik_calibration/screens/calibration/ph_calibration_input_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/ocr_service.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/app_text_field.dart';

Widget _app({
  bool submitGagal = false,
  SumberFoto? sumberFoto,
  OcrService? ocr,
}) {
  return ProviderScope(
    overrides: [
      // Cuma di-override kalau test-nya emang ngurusin kamera — sisanya biar
      // pakai implementasi asli.
      if (sumberFoto != null) sumberFotoProvider.overrideWithValue(sumberFoto),
      if (ocr != null) ocrServiceProvider.overrideWithValue(ocr),
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      calibrationServiceProvider.overrideWithValue(
        MockCalibrationService(gagal: submitGagal),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Sama kayak calibration_input_test.dart — butuh Navigator stack
      // beneran biar Navigator.pop() waktu submit sukses nggak nge-crash.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PhCalibrationInputScreen(),
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

/// Satu kartu titik buffer yang kebuka punya 11 kolom mirip semua (nilai acuan
/// + 5×[pH, suhu]). Viewport test standar 800x600 nggak muat segitu, dan
/// `ListView` cuma nge-build yang deket viewport — jadi viewport-nya dibikin
/// raksasa biar seluruh halaman ke-build sekaligus.
void _perbesarViewport(WidgetTester tester, {double lebar = 800}) {
  tester.view.physicalSize = Size(lebar, 10000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Buka layar lalu lewati gerbang "Manual / Foto".
///
/// Default-nya milih **Ketik manual**: hampir semua test di sini nguji isi
/// worksheet-nya, bukan gerbangnya. Yang nguji gerbang manggil `_bukaGerbang`
/// biar berhenti di situ.
Future<void> _bukaLayar(WidgetTester tester) async {
  await _bukaGerbang(tester);
  await tester.tap(find.text('Ketik manual'));
  await tester.pumpAndSettle();
}

/// Berhenti di gerbang pilihan, belum masuk wizard.
Future<void> _bukaGerbang(WidgetTester tester) async {
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

/// Kolom input yang labelnya persis [label]. Label di [AppTextField] dirender
/// HURUF BESAR di atas kotaknya, jadi dicari lewat widget induknya — bukan
/// lewat index `find.byType(TextField).at(n)` yang geser tiap kali form
/// berubah.
Finder _kolom(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label.toUpperCase()),
    matching: find.byType(AppTextField),
  ),
  matching: find.byType(TextField),
);

/// Kolom ke-[index] di dalam kartu titik buffer [label]. Urutannya:
/// 0 = nilai acuan, lalu berpasangan (pH, suhu) buat bacaan 1–5.
Finder _kolomTitik(String label, int index) => find
    .descendant(
      of: find.byKey(ValueKey('titik-$label')),
      matching: find.byType(TextField),
    )
    .at(index);

/// [pilihan] dicocokin sebagai potongan teks, bukan persis: item dropdown alat
/// nempelin serial number di belakang namanya ("pH Meter Mettler Toledo ·
/// B628755900").
Future<void> _pilihDropdown(
  WidgetTester tester,
  String hint,
  String pilihan,
) async {
  await tester.tap(find.text(hint), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(pilihan).last);
  await tester.pumpAndSettle();
}

/// Halaman 1 — identitas alat, standar sesi, kondisi lingkungan.
Future<void> _isiHalaman1(WidgetTester tester) async {
  await _pilihDropdown(tester, 'Pilih alat', 'pH Meter Mettler Toledo');
  await _pilihDropdown(
    tester,
    'Dipakai buat kondisi lingkungan (suhu/kelembaban)',
    'Termometer & Sensor Std.',
  );

  await tester.enterText(_kolom('Suhu awal (°C)'), '21.3');
  await tester.enterText(_kolom('Suhu akhir (°C)'), '21.5');
  await tester.enterText(_kolom('Kelembaban awal (%)'), '53');
  await tester.enterText(_kolom('Kelembaban akhir (%)'), '56');
  await tester.pumpAndSettle();
}

/// Ketiga kartu titik nampilin hint "Pilih larutan buffer" yang sama persis,
/// jadi dropdown-nya dicari di dalam kartu yang dituju — bukan lewat urutan
/// kemunculan di layar.
Future<void> _pilihBuffer(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey('titik-$label')),
      matching: find.text('Pilih larutan buffer'),
    ),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('pH Buffer Solution $label').last);
  await tester.pumpAndSettle();
}

/// Cuma titik pertama yang kebuka pas halaman 2 dibuka; sisanya harus dibuka
/// dulu, kalau nggak kolomnya belum kerender.
Future<void> _bukaSemuaTitik(WidgetTester tester) async {
  for (final titik in ['7', '10']) {
    await tester.tap(find.text('Buffer pH $titik'), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

Future<void> _lanjutKeHalaman2(WidgetTester tester) async {
  await tester.tap(find.text('LANJUTKAN'));
  await tester.pumpAndSettle();
}

/// Halaman 2 — tiga titik buffer, masing-masing standar buffernya sendiri
/// (`docs/kontrak-api.md` §4: `measurements[].standard_id`) + nilai acuan
/// terkoreksi suhu + 5 pembacaan sesudah adjustment.
Future<void> _isiHalaman2(WidgetTester tester) async {
  await _bukaSemuaTitik(tester);

  const isi = [
    ('4', '4.009244572', 4.0),
    ('7', '6.9889072', 7.0),
    ('10', '9.9789', 10.0),
  ];

  for (final (label, nilaiAcuan, ph) in isi) {
    await _pilihBuffer(tester, label);

    await tester.enterText(_kolomTitik(label, 0), nilaiAcuan);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(_kolomTitik(label, 1 + i * 2), '$ph');
      await tester.enterText(_kolomTitik(label, 2 + i * 2), '22.2');
    }
    await tester.pumpAndSettle();
  }
}

void main() {
  group('gerbang cara isi', () {
    testWidgets('muncul duluan — wizard belum kebuka sebelum dipilih', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await tester.pumpWidget(_app());
      await _bukaGerbang(tester);

      expect(find.text('Foto worksheet'), findsOneWidget);
      expect(find.text('Ketik manual'), findsOneWidget);

      // Kolom halaman 1 belum boleh kerender: keputusan cara isi diambil
      // sebelum teknisi ngetik apa pun.
      expect(find.text('Pilih alat'), findsNothing);
      expect(find.text('LANJUTKAN'), findsNothing);
    });

    testWidgets('pilih "Ketik manual" → masuk halaman 1', (tester) async {
      _perbesarViewport(tester);
      await tester.pumpWidget(_app());
      await _bukaGerbang(tester);

      await tester.tap(find.text('Ketik manual'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih alat'), findsOneWidget);
      expect(find.text('Foto worksheet'), findsNothing);
    });

    testWidgets('peringatan "wajib dicek" muncul sebelum motret, bukan sesudah', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await tester.pumpWidget(_app());
      await _bukaGerbang(tester);

      // Teknisi yang ngira hasil foto langsung sah bakal ngelewatin
      // pengecekan — dan angka salah baca itu masuk sertifikat.
      expect(find.textContaining('wajib dicek sebelum dikirim'), findsOneWidget);
    });
  });

  group('identitas alat otomatis', () {
    testWidgets('kosong sebelum alat dipilih, keisi sesudahnya', (tester) async {
      _perbesarViewport(tester);
      await tester.pumpWidget(_app());
      await _bukaLayar(tester);

      // Belum milih alat → panelnya nggak ada, bukan deretan strip kosong.
      expect(find.text('Mettler Toledo'), findsNothing);

      await _pilihDropdown(tester, 'Pilih alat', 'pH Meter Mettler Toledo');

      // Nilai-nilai ini datang dari `GET /equipments` yang emang udah dikirim
      // server — dulu dibuang parser, jadi kolomnya kosong padahal datanya ada.
      expect(find.text('Mettler Toledo'), findsOneWidget); // Merk
      expect(find.text('Five Easy'), findsOneWidget); // Type
      expect(find.text('B628755900'), findsOneWidget); // No. Seri
      expect(find.text('0–14 pH'), findsOneWidget); // Rentang ukur
      expect(find.text('0.01 pH'), findsOneWidget); // Resolusi
      expect(
        find.text('PT TIRTA GRACIA SEMESTA MANDIRI'),
        findsOneWidget,
      ); // Customer
    });
  });

  testWidgets('halaman 1 nampilin identitas & kondisi, belum titik buffer', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    expect(find.text('Pilih alat'), findsOneWidget);
    expect(
      find.text('Dipakai buat kondisi lingkungan (suhu/kelembaban)'),
      findsOneWidget,
    );
    expect(find.text('LANJUTKAN'), findsOneWidget);

    // Titik buffer baru muncul di halaman 2 — form pH dipecah dua supaya
    // halaman pertamanya nggak langsung nampilin puluhan kolom angka.
    expect(find.text('Buffer pH 4'), findsNothing);
  });

  testWidgets('lanjut tanpa pilih apa-apa → ditahan di validasi alat', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await tester.tap(find.text('LANJUTKAN'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih alat dulu.'), findsOneWidget);
    // Masih di halaman 1 — nggak boleh lolos ke pengisian angka dulu, karena
    // teknisi bisa ngisi 30 kolom baru ketahuan alatnya belum kepilih.
    expect(find.text('Buffer pH 4'), findsNothing);
  });

  testWidgets('kondisi lingkungan kosong → ditahan walau alat udah dipilih', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _pilihDropdown(tester, 'Pilih alat', 'pH Meter Mettler Toledo');
    await _pilihDropdown(
      tester,
      'Dipakai buat kondisi lingkungan (suhu/kelembaban)',
      'Termometer & Sensor Std.',
    );
    await tester.tap(find.text('LANJUTKAN'));
    await tester.pumpAndSettle();

    expect(
      find.text('Isi kondisi lingkungan (suhu & kelembaban) dulu.'),
      findsOneWidget,
    );
  });

  testWidgets('halaman 1 valid → lanjut ke titik buffer', (tester) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiHalaman1(tester);
    await _lanjutKeHalaman2(tester);

    expect(find.text('Buffer pH 4'), findsOneWidget);
    expect(find.text('Buffer pH 7'), findsOneWidget);
    expect(find.text('Buffer pH 10'), findsOneWidget);
    expect(find.text('KIRIM UNTUK APPROVAL'), findsOneWidget);
  });

  testWidgets('nilai acuan kosong → ditahan sebelum kekirim', (tester) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiHalaman1(tester);
    await _lanjutKeHalaman2(tester);

    // Standar buffer dipilih semua, tapi nilai acuannya belum diisi.
    await _bukaSemuaTitik(tester);
    for (final label in ['4', '7', '10']) {
      await _pilihBuffer(tester, label);
    }

    await tester.tap(find.text('KIRIM UNTUK APPROVAL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Isi nilai acuan (terkoreksi suhu) buat tiap titik buffer.'),
      findsOneWidget,
    );
  });

  testWidgets('isi lengkap → kirim approval sukses & layar ketutup', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiHalaman1(tester);
    await _lanjutKeHalaman2(tester);
    await _isiHalaman2(tester);

    await tester.tap(find.text('KIRIM UNTUK APPROVAL'));
    await tester.pumpAndSettle();

    // Hasilnya nongol sebagai sheet, bukan SnackBar — dan layarnya sengaja
    // BELUM ketutup: teknisi baru aja ngisi puluhan angka, jadi dia yang
    // mutusin kapan konfirmasinya udah kebaca, bukan timer 3 detik.
    expect(find.text('Kekirim!'), findsOneWidget);
    expect(find.byType(PhCalibrationInputScreen), findsOneWidget);

    await tester.tap(find.text('TUTUP'));
    await tester.pumpAndSettle();

    expect(find.byType(PhCalibrationInputScreen), findsNothing);
  });

  // Form ini penuh kolom berdampingan (suhu awal/akhir, pH/°C, dua tombol
  // tahap) dan labelnya panjang-panjang. Di lebar test bawaan (800px) semuanya
  // muat kegampangan — HP teknisi cuma ~390px. Overflow horizontal otomatis
  // bikin widget test gagal, jadi cukup dirender di lebar segitu.
  testWidgets('muat di lebar HP (390px) tanpa overflow', (tester) async {
    _perbesarViewport(tester, lebar: 390);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiHalaman1(tester);
    await _lanjutKeHalaman2(tester);
    await _isiHalaman2(tester);

    // Tahap "sebelum adjustment" ikut dibuka: tab-nya kolom paling sempit di
    // layar, dan labelnya paling panjang.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('titik-4')),
        matching: find.text('Sebelum adjustment (as found)'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KIRIM UNTUK APPROVAL'), findsOneWidget);
  });

  testWidgets('submit gagal di server → pesan error, layar tetap kebuka', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app(submitGagal: true));
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiHalaman1(tester);
    await _lanjutKeHalaman2(tester);
    await _isiHalaman2(tester);

    await tester.tap(find.text('SIMPAN DRAFT'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
    expect(find.byType(PhCalibrationInputScreen), findsOneWidget);
  });

  // Scan kamera per sel — dulu nggak bisa dites sama sekali karena
  // `MlKitOcrService()` dan `ImagePicker()` di-`new` langsung di dalam widget.
  // Sekarang dua-duanya lewat provider, jadi yang diuji bukan cuma parser
  // angkanya tapi **apa yang kejadian ke form** setelah foto kebaca.
  group('scan kamera', () {
    /// Tombol kamera di baris pembacaan ke-1 buffer 4.
    Finder tombolScan() => find.descendant(
      of: find.byKey(const ValueKey('titik-4')),
      matching: find.byIcon(Icons.photo_camera_outlined),
    );

    /// Penanda "belum dikonfirmasi" **di dalam kartu titik**.
    ///
    /// Wajib dipersempit ke kartunya: kalimat yang sama juga dipakai sebagai
    /// keterangan tetap di kartu foto-tabel setingkat halaman, jadi
    /// `find.text` polos selalu kena dua-duanya dan test-nya jadi bohong.
    Finder penanda() => find.descendant(
      of: find.byKey(const ValueKey('titik-4')),
      matching: find.text('Dari kamera — cek dulu'),
    );

    Future<void> siapkan(
      WidgetTester tester, {
      HasilOcr? hasil,
      bool dibatalkan = false,
    }) async {
      _perbesarViewport(tester);
      await tester.pumpWidget(
        _app(
          sumberFoto: MockSumberFoto(dibatalkan: dibatalkan),
          ocr: MockOcrService(hasil: hasil),
        ),
      );
      await _bukaLayar(tester);
      await _isiHalaman1(tester);
      await _lanjutKeHalaman2(tester);
    }

    testWidgets('hasil scan masuk kolom pH + suhu, ditandai belum dikonfirmasi', (
      tester,
    ) async {
      await siapkan(
        tester,
        hasil: const HasilOcr(
          nilai: 4.04,
          suhu: 22.2,
          teksMentah: '4,04 pH 22,2 C',
          keyakinan: 0.9,
        ),
      );

      await tester.tap(tombolScan().first);
      await tester.pumpAndSettle();

      // index 1 = pH bacaan ke-1, index 2 = suhunya.
      expect(tester.widget<TextField>(_kolomTitik('4', 1)).controller?.text, '4.04');
      expect(tester.widget<TextField>(_kolomTitik('4', 2)).controller?.text, '22.2');

      // Angka dari kamera nggak boleh langsung dianggap sah — backend nolak
      // approve selama masih ada pembacaan OCR yang belum dicek orang.
      expect(penanda(), findsOneWidget);
    });

    testWidgets('setelah dikonfirmasi, penandanya hilang', (tester) async {
      await siapkan(
        tester,
        hasil: const HasilOcr(
          nilai: 4.04,
          teksMentah: '4,04 pH',
          keyakinan: 0.9,
        ),
      );

      await tester.tap(tombolScan().first);
      await tester.pumpAndSettle();
      expect(penanda(), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('titik-4')),
          matching: find.text('SUDAH BENAR'),
        ).first,
      );
      await tester.pumpAndSettle();

      expect(penanda(), findsNothing);
      // Angkanya tetap tinggal — yang hilang cuma penandanya.
      expect(tester.widget<TextField>(_kolomTitik('4', 1)).controller?.text, '4.04');
    });

    testWidgets('OCR gagal baca → kolom dibiarkan kosong, bukan diisi ngawur', (
      tester,
    ) async {
      await siapkan(tester, hasil: null);

      await tester.tap(tombolScan().first);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_kolomTitik('4', 1)).controller?.text, isEmpty);
      expect(penanda(), findsNothing);
      expect(find.textContaining('nggak kebaca jelas'), findsOneWidget);
    });

    testWidgets('user batal motret → nggak ada pesan gagal', (tester) async {
      await siapkan(tester, dibatalkan: true);

      await tester.tap(tombolScan().first);
      await tester.pumpAndSettle();

      // Membatalkan itu bukan error. Nampilin "gagal baca" di sini bikin user
      // ngira ada yang rusak padahal dia sendiri yang mundur.
      expect(find.textContaining('nggak kebaca jelas'), findsNothing);
      expect(tester.widget<TextField>(_kolomTitik('4', 1)).controller?.text, isEmpty);
    });
  });
}
