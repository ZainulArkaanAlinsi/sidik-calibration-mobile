import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/ringkasan_sebelum_kirim.dart';
import 'package:sidik_calibration/screens/calibration/widgets/ringkasan_sebelum_kirim_dialog.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';
import 'package:sidik_calibration/widgets/app_button.dart';
import 'package:sidik_calibration/widgets/dekorasi_isian_wajib.dart';

/// "Ringkasan sebelum kirim" (Kirim ke admin, bukan Simpan draf).
///
/// Yang dikunci: gerbang wajib menahan (tombol kirim di dialog MATI + alasan +
/// bisa melompat), peringatan boleh "Tetap kirim", tanpa kekurangan tidak ada
/// dialog sama sekali, draf tidak pernah melihat dialog, dua ketukan beruntun
/// hanya satu request, dan warna dialog memakai palet yang sudah live di dua
/// tema. Bentuk lembarnya `contohBentukLembarKerja()` — salinan lembar pH.
void main() {
  // ----------------------------------------------------------------- bahan

  /// Alat lengkap: semua identitas pH terisi awal dari master.
  const alatLengkap = EquipmentLookup(
    id: 14,
    namaAlat: 'pH Meter Mettler Toledo',
    serialNumber: 'B628755900',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Mettler Toledo',
    model: 'Five Easy',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA CONTOH MANDIRI',
    pelangganAlamat: 'Jl. Contoh Primer A-10, Kab. Bandung',
  );

  /// Alat yang merek, tipe, dan pelanggannya belum tercatat di master.
  const alatKurang = EquipmentLookup(
    id: 15,
    namaAlat: 'pH Meter Tanpa Merek',
    serialNumber: 'KURANG-001',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
  );

  /// Lembar pH apa adanya, atau yang mewajibkan suhu (`suhu_wajib`, seperti
  /// Conductivity) — gerbang suhu hanya hidup di bentuk yang menyalakannya.
  LembarKerja bentukPh({bool suhuWajib = false}) => LembarKerja.fromJson({
    ...contohBentukLembarKerja(),
    if (suhuWajib) 'suhu_wajib': true,
  });

  LembarKerjaState isianBaru({EquipmentLookup? alat, bool suhuWajib = false}) =>
      LembarKerjaState(
          bentuk: bentukPh(suhuWajib: suhuWajib),
          clientRequestId: 'uji-ringkasan',
        )
        ..alat = alat
        ..isiDariAlat();

  void perbesarViewport(WidgetTester tester, {Size? ukuran}) {
    tester.view.physicalSize = ukuran ?? const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(
    LembarKerjaService service, {
    List<EquipmentLookup>? daftarAlat,
    Brightness tema = Brightness.light,
    Locale locale = const Locale('id'),
  }) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(service),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        daftarAlat == null
            ? MockEquipmentLookupService()
            : _DaftarAlat(daftarAlat),
      ),
      worksheetScanServiceProvider.overrideWithValue(
        MockWorksheetScanService(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(brightness: tema),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(profil: 'ph_meter'),
    ),
  );

  Future<void> muat(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> pilihAlat(WidgetTester tester, String teks) async {
    await tester.tap(find.textContaining('Pilih alat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(teks).last);
    await tester.pumpAndSettle();
  }

  Future<void> keHalamanTerakhir(WidgetTester tester) async {
    final lanjut = find.byIcon(Icons.arrow_forward);
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
  }

  final dialog = find.byKey(const ValueKey('dialog-ringkasan-sebelum-kirim'));
  final tombolKirim = find.byKey(const ValueKey('ringkasan-kirim'));
  final tombolKembali = find.byKey(const ValueKey('ringkasan-kembali'));
  final kirimDiLayar = find.text('Kirim ke admin');

  Finder kotakAfter() => find.descendant(
    of: find
        .ancestor(
          of: find.text('After adjustment Reading'),
          matching: find.byType(Column),
        )
        .first,
    matching: find.byType(TextField),
  );

  // ------------------------------------------------- susunan (tanpa layar)

  group('susunRingkasanSebelumKirim', () {
    test('alat belum dipilih: satu gerbang, tanpa deretan identitas', () {
      final r = susunRingkasanSebelumKirim(isianBaru());

      expect(r.menahan, isTrue);
      expect(r.wajib.map((b) => b.jenis), [
        JenisButirRingkasan.alatBelumDipilih,
      ]);
      expect(
        r.peringatan,
        isEmpty,
        reason: 'identitas kosong karena alat belum dipilih bukan peringatan',
      );
      expect(r.wajib.single.lompat, 'equipment_id');
    });

    test('alat lengkap, lembar kosong: tidak ada kekurangan', () {
      final r = susunRingkasanSebelumKirim(isianBaru(alat: alatLengkap));

      expect(r.adaKekurangan, isFalse);
      expect(r.menahan, isFalse);
      expect(r.titikTotal, 3, reason: 'pH 4 / 7 / 10,01');
      expect(r.titikTerisi, 0);
    });

    test('identitas kosong = peringatan amber, tidak menahan', () {
      final r = susunRingkasanSebelumKirim(isianBaru(alat: alatKurang));

      expect(r.menahan, isFalse);
      expect(r.wajib, isEmpty);

      final label = r.peringatan.map((b) => b.label).toList();
      expect(label, containsAll(['3. Type/Model', '5. Merk/Manufacture']));
      expect(label, contains('1. Name'), reason: 'nama pemilik kosong');
      expect(
        r.peringatan.every(
          (b) => b.jenis == JenisButirRingkasan.identitasKosong,
        ),
        isTrue,
      );
      // Tiap butir bisa dilompati ke kolomnya.
      expect(
        r.peringatan.map((b) => b.lompat),
        containsAll(['alat_model', 'alat_merk', 'pemilik_nama']),
      );
    });

    test('kolom netral (nomor order, ruangan, tanggal terima) tidak ikut', () {
      final r = susunRingkasanSebelumKirim(isianBaru(alat: alatKurang));
      final kode = r.peringatan.map((b) => b.lompat).toSet();

      expect(kode, isNot(contains('tanggal_terima')));
      expect(kode, isNot(contains('room_id')));
      expect(kode, isNot(contains('nomor_order')));
    });

    test('tanggal kalibrasi dikosongkan -> peringatan', () {
      final s = isianBaru(alat: alatLengkap)
        ..tanggal['tanggal_kalibrasi'] = null;
      final r = susunRingkasanSebelumKirim(s);

      expect(r.menahan, isFalse);
      expect(r.peringatan.map((b) => b.lompat), ['tanggal_kalibrasi']);
    });

    test('pembacaan tanpa suhu = gerbang yang menahan, menunjuk tabel', () {
      final s = isianBaru(alat: alatLengkap, suhuWajib: true);
      s.titik[4.0]!
        ..kotak('sesudah_adjustment', 'pembacaan', 0).text = '4.01'
        // Kotak suhunya ada (digambar layar) tapi kosong.
        ..kotak('sesudah_adjustment', 'suhu', 0);

      final r = susunRingkasanSebelumKirim(s);

      expect(r.menahan, isTrue);
      expect(r.wajib.single.jenis, JenisButirRingkasan.suhuBelumLengkap);
      expect(r.wajib.single.label, '4,00');
      expect(r.wajib.single.lompat, startsWith('bagian:'));
      expect(r.titikTerisi, 1);
      expect(r.titikTotal, 3);
    });

    test('angka terisi tanpa standar dicentang = gerbang (isian yatim)', () {
      final s = isianBaru(alat: alatLengkap);
      final t = s.titik[7.0]!;
      t.kotak('sesudah_adjustment', 'pembacaan', 0).text = '7.00';
      t.kotak('sesudah_adjustment', 'suhu', 0).text = '25';
      t.standardId = null;

      final r = susunRingkasanSebelumKirim(s);

      expect(
        r.wajib.map((b) => b.jenis),
        contains(JenisButirRingkasan.standarBelumDicentang),
      );
    });

    test('sel hasil kamera yang belum dicek = gerbang yang MENAHAN', () {
      final s = isianBaru(alat: alatLengkap);
      s.titik[4.0]!
        ..kotak('sesudah_adjustment', 'pembacaan', 1).text = '4.02'
        ..kotak('sesudah_adjustment', 'suhu', 1).text = '25';
      s.selKamera.add(
        LembarKerjaState.kunciSel(4.0, 'sesudah_adjustment', 'pembacaan', 1),
      );

      final r = susunRingkasanSebelumKirim(s);

      expect(r.menahan, isTrue);
      expect(r.peringatan, isEmpty);
      final ocr = r.wajib.single;
      expect(ocr.jenis, JenisButirRingkasan.ocrPerluDicek);
      expect(ocr.jumlah, 1);
    });

    test('sel pindai yang sudah dikosongkan teknisi tidak diperingatkan', () {
      final s = isianBaru(alat: alatLengkap);
      s.selKamera.add(
        LembarKerjaState.kunciSel(4.0, 'sesudah_adjustment', 'pembacaan', 2),
      );

      expect(susunRingkasanSebelumKirim(s).adaKekurangan, isFalse);
    });

    test('hitungan titik: terisi vs total, sel kosong tidak dihitung', () {
      final s = isianBaru(alat: alatLengkap);
      s.titik[4.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '4.01';
      s.titik[4.0]!.kotak('sesudah_adjustment', 'suhu', 0).text = '25';
      s.titik[10.01]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '10.0';
      s.titik[10.01]!.kotak('sesudah_adjustment', 'suhu', 0).text = '25';

      final r = susunRingkasanSebelumKirim(s);

      expect(r.titikTerisi, 2);
      expect(r.titikTotal, 3);
      expect(
        r.adaKekurangan,
        isFalse,
        reason: 'titik belum terisi saja bukan alasan memunculkan dialog',
      );
    });
  });

  // --------------------------------------------------------------- layar

  group('Kirim di LembarKerjaScreen', () {
    testWidgets(
      'alat belum dipilih: dialog menahan, kirim mati, alasan jelas',
      (tester) async {
        perbesarViewport(tester);
        final service = MockLembarKerjaService();
        await muat(tester, app(service));
        await keHalamanTerakhir(tester);

        await tester.tap(kirimDiLayar);
        await tester.pumpAndSettle();

        expect(dialog, findsOneWidget);
        expect(find.text('Ringkasan sebelum kirim'), findsOneWidget);
        expect(find.textContaining('Belum bisa dikirim'), findsOneWidget);
        expect(find.textContaining('Pilih alatnya dulu'), findsOneWidget);

        // Tombol kirim di dialog NONAKTIF.
        expect(tester.widget<FilledButton>(tombolKirim).onPressed, isNull);
        await tester.tap(tombolKirim, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(service.jumlahKirim, 0);

        await tester.tap(tombolKembali);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(service.jumlahKirim, 0);
      },
    );

    testWidgets(
      'mengetuk butir wajib: dialog menutup, lompat ke halaman bidangnya',
      (tester) async {
        perbesarViewport(tester, ukuran: const Size(500, 900));
        final service = MockLembarKerjaService();
        await muat(tester, app(service));
        await keHalamanTerakhir(tester);
        expect(find.text('Halaman 2 dari 2'), findsOneWidget);

        await tester.tap(kirimDiLayar);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('ringkasan-wajib-alatBelumDipilih-0')),
        );
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(service.jumlahKirim, 0);
        expect(
          find.text('Lanjut ke halaman berikutnya'),
          findsOneWidget,
          reason: 'pindah ke halaman 1: tombol kirim diganti tombol lanjut',
        );

        // Pemilih alat sekarang ada di layar.
        final rect = tester.getRect(find.textContaining('Pilih alat').first);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(900));
      },
    );

    testWidgets(
      'peringatan alamat pemilik kosong: dialog melompat ke kolom yang jauh di bawah',
      (tester) async {
        perbesarViewport(tester);
        final service = MockLembarKerjaService();
        await muat(tester, app(service));
        await pilihAlat(tester, 'pH Meter Mettler Toledo · B628755900');

        // Alamat pemilik dikosongkan teknisi.
        await tester.enterText(
          find.widgetWithText(TextField, '2. Address *'),
          '',
        );
        await tester.pumpAndSettle();
        await keHalamanTerakhir(tester);

        // Layar pendek: kolom alamat ada jauh di bawah lipatan, jadi ListView
        // belum membangunnya dan lompatnya harus mencari sambil menggulir.
        perbesarViewport(tester, ukuran: const Size(500, 600));
        await tester.pumpAndSettle();
        await tester.tap(kirimDiLayar);
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(find.textContaining('2. Address masih kosong'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('ringkasan-peringatan-identitasKosong-0')),
        );
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(service.jumlahKirim, 0);
        final kolom = find.widgetWithText(TextField, '2. Address *');
        expect(
          kolom,
          findsOneWidget,
          reason: 'kolomnya sudah dibangun & kelihatan',
        );
        final rect = tester.getRect(kolom);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(600));
      },
    );

    testWidgets(
      'pembacaan tanpa suhu: gerbang menahan walau alat sudah dipilih',
      (tester) async {
        perbesarViewport(tester);
        final service = _LembarSuhuWajib();
        await muat(tester, app(service));
        await pilihAlat(tester, 'pH Meter Mettler Toledo · B628755900');
        await keHalamanTerakhir(tester);

        await tester.enterText(kotakAfter().at(0), '4.01');
        await tester.pumpAndSettle();

        await tester.tap(kirimDiLayar);
        await tester.pumpAndSettle();

        expect(dialog, findsOneWidget);
        expect(find.textContaining('tanpa suhu larutan'), findsOneWidget);
        expect(tester.widget<FilledButton>(tombolKirim).onPressed, isNull);
        expect(find.text('Titik terisi: 1 dari 3'), findsOneWidget);
        expect(service.jumlahKirim, 0);

        // Kembali, lengkapi suhunya: kirim jalan lagi tanpa dialog ringkasan.
        await tester.tap(tombolKembali);
        await tester.pumpAndSettle();
        await tester.enterText(kotakAfter().at(1), '22.2');
        await tester.pumpAndSettle();

        await tester.tap(kirimDiLayar);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
      },
    );

    testWidgets('hanya peringatan: "Tetap kirim" meneruskan, "Kembali" tidak', (
      tester,
    ) async {
      perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await muat(tester, app(service, daftarAlat: [alatKurang]));
      await pilihAlat(tester, 'pH Meter Tanpa Merek · KURANG-001');
      await keHalamanTerakhir(tester);

      await tester.tap(kirimDiLayar);
      await tester.pumpAndSettle();

      expect(dialog, findsOneWidget);
      expect(find.textContaining('Belum bisa dikirim'), findsNothing);
      expect(find.text('Sebaiknya dicek'), findsOneWidget);
      expect(find.textContaining('masih kosong'), findsWidgets);
      expect(tester.widget<FilledButton>(tombolKirim).onPressed, isNotNull);

      await tester.tap(tombolKembali);
      await tester.pumpAndSettle();
      expect(
        service.jumlahKirim,
        0,
        reason: '"Kembali" tidak mengirim apa pun',
      );

      await tester.tap(kirimDiLayar);
      await tester.pumpAndSettle();
      await tester.tap(tombolKirim);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['status'], 'menunggu_approval');
    });

    testWidgets('tidak ada kekurangan: kirim langsung, tanpa dialog', (
      tester,
    ) async {
      perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await muat(tester, app(service));
      await pilihAlat(tester, 'pH Meter Mettler Toledo · B628755900');
      await keHalamanTerakhir(tester);

      await tester.tap(kirimDiLayar);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['status'], 'menunggu_approval');
    });

    testWidgets('Simpan draf tidak pernah memunculkan dialog', (tester) async {
      perbesarViewport(tester);
      final service = MockLembarKerjaService();
      // Alat kurang + pembacaan tanpa suhu: Kirim akan ditahan, draf tidak.
      await muat(tester, app(service, daftarAlat: [alatKurang]));
      await pilihAlat(tester, 'pH Meter Tanpa Merek · KURANG-001');
      await keHalamanTerakhir(tester);
      await tester.enterText(kotakAfter().at(0), '4.01');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan sebagai draft'));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['status'], 'draft');
    });

    testWidgets(
      'dua ketukan beruntun hanya melahirkan satu dialog dan satu request',
      (tester) async {
        perbesarViewport(tester);
        final service = MockLembarKerjaService();
        await muat(tester, app(service, daftarAlat: [alatKurang]));
        await pilihAlat(tester, 'pH Meter Tanpa Merek · KURANG-001');
        await keHalamanTerakhir(tester);

        // Dua panggilan handler dalam SATU frame — `tester.tap` tidak cukup
        // cepat untuk membuktikan penjaganya (hit-test sudah berubah di antara
        // dua ketukan), jadi handler tombolnya dipanggil langsung.
        final kirim = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Kirim ke admin'),
        );
        kirim.onPressed!();
        kirim.onPressed!();
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget, reason: 'satu dialog, bukan dua');

        // Hal yang sama untuk "Tetap kirim": dua jawaban dalam satu frame
        // tidak boleh jadi dua `pop` (yang kedua menutup layar di bawahnya)
        // atau dua pengiriman.
        final tetapKirim = tester.widget<FilledButton>(tombolKirim);
        tetapKirim.onPressed!();
        tetapKirim.onPressed!();
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(find.byType(LembarKerjaScreen), findsOneWidget);
        expect(service.jumlahKirim, 1);
      },
    );

    testWidgets('English: judul, alasan, dan tombol ikut bahasa', (
      tester,
    ) async {
      perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await muat(tester, app(service, locale: const Locale('en')));
      await keHalamanTerakhir(tester);

      await tester.tap(find.text('Submit to admin'));
      await tester.pumpAndSettle();

      expect(find.text('Summary before sending'), findsOneWidget);
      expect(
        find.textContaining("Can't send yet: 1 required item"),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Back')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Send')),
        findsOneWidget,
      );
    });
  });

  // --------------------------------------------------- warna, terang & gelap

  group('warna dialog memakai palet yang sudah live', () {
    const ringkasan = RingkasanSebelumKirim(
      butir: [
        ButirRingkasan(jenis: JenisButirRingkasan.alatBelumDipilih),
        ButirRingkasan(
          jenis: JenisButirRingkasan.identitasKosong,
          label: '5. Merk/Manufacture',
          lompat: 'alat_merk',
        ),
        ButirRingkasan(
          jenis: JenisButirRingkasan.ocrPerluDicek,
          label: '4,00',
          jumlah: 2,
          lompat: 'bagian:hasil',
        ),
      ],
      titikTerisi: 1,
      titikTotal: 3,
    );

    Future<void> tampil(WidgetTester tester, Brightness tema) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: tema),
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: DialogRingkasanSebelumKirim(ringkasan: ringkasan),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Material kartu(WidgetTester tester, String kunci) =>
        tester.widget<Material>(
          find
              .descendant(
                of: find.byKey(ValueKey(kunci)),
                matching: find.byType(Material),
              )
              .first,
        );

    double kontras(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();

      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final tema in Brightness.values) {
      testWidgets(
        'tema ${tema.name}: wajib = palet wajibKosong, peringatan = kuning',
        (tester) async {
          await tampil(tester, tema);

          final wajib = PaletIsian.untuk(tema, StatusIsian.wajibKosong)!;
          final tahan = kartu(tester, 'ringkasan-wajib-alatBelumDipilih-0');
          expect(tahan.color, wajib.latar);
          expect(
            ((tahan.shape as RoundedRectangleBorder).side).color,
            wajib.tepi,
          );

          final amber = kartu(tester, 'ringkasan-peringatan-identitasKosong-0');
          expect(
            (amber.shape as RoundedRectangleBorder).side.color,
            kuningPerluDicek,
          );
          // Beda jelas dari gerbang: tepi peringatan bukan tepi wajib.
          expect(
            (amber.shape as RoundedRectangleBorder).side.color,
            isNot(wajib.tepi),
          );

          // Teks terbaca di atas latar kartu (kontras WCAG AA untuk teks kecil).
          final teks =
              Theme.of(
                tester.element(
                  find.byKey(const ValueKey('ringkasan-pesan-status')),
                ),
              ).textTheme.bodySmall!.color ??
              Theme.of(tester.element(dialog)).colorScheme.onSurface;
          expect(kontras(teks, tahan.color!), greaterThanOrEqualTo(4.5));
        },
      );
    }

    testWidgets(
      'warna bukan satu-satunya penanda: ikon, judul kelompok, chevron',
      (tester) async {
        await tampil(tester, Brightness.light);

        expect(find.text('Wajib dibereskan'), findsOneWidget);
        expect(find.text('Sebaiknya dicek'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsWidgets);
        expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
        expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
        expect(
          find.textContaining('2 isian bacaan kamera belum dicek'),
          findsOneWidget,
          reason: 'butir kamera sekarang MENAHAN, jumlahnya tertulis',
        );
      },
    );
  });
}

/// Lembar pH yang mewajibkan suhu — hanya bentuk yang menyalakan `suhu_wajib`
/// (Conductivity, dst.) yang punya gerbang suhu.
class _LembarSuhuWajib extends MockLembarKerjaService {
  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async =>
      LembarKerja.fromJson({...contohBentukLembarKerja(), 'suhu_wajib': true});
}

class _DaftarAlat implements EquipmentLookupService {
  _DaftarAlat(this.daftar);

  final List<EquipmentLookup> daftar;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
    String? profil,
  }) async => daftar;
}
