import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_scan.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pembaca_qr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Jalur pindai dari TOMBOL sampai FORMULIR, dijalanin lewat layar aslinya.
///
/// ## Kenapa ini ada
///
/// Potongannya masing-masing udah dijaga: `pindai_lembar_cetakan_test`
/// menjaga geometrinya, `jalankan_pindai_test` menjaga payloadnya,
/// `pindai_review_test` menjaga layar reviewnya. Yang nggak dijaga siapa pun
/// justru SAMBUNGANNYA — dan di situ kegagalannya paling sunyi:
///
///  - angka yang nyampe layar review tapi nggak pernah mendarat di kotak
///    isian, karena hasil `Navigator.pop`-nya dibuang;
///  - sesi hasil pindai yang dikirim TANPA ditandai butuh verifikasi
///    pembacaan, jadi sesinya diam-diam nge-blok admin
///    (`ocr_belum_diverifikasi`) tanpa teknisi pernah dikasih tahu. Ini bukan
///    kekhawatiran karangan: tiga sesi berturut-turut mentok begitu (7 Agt
///    2026), dan yang bikin ketahuan cuma admin yang ngeluh.
///
/// Semua yang butuh perangkat diganti tiruan — kamera, ML Kit, dan server —
/// tapi LEMBAR YANG DIFOTO citra cetakan asli, dan geometrinya berkas yang
/// sama yang dipakai server. Jadi yang diuji sambungannya, bukan tiruannya.
/// Nunggu sampai [target] muncul, dengan frame yang dipompa satu-satu.
///
/// `pumpAndSettle` nggak bisa dipakai di sini: selama pindai jalan, tombolnya
/// nampilin `CircularProgressIndicator` yang animasinya nggak pernah berhenti
/// — jadi yang kejadian bukan "nunggu selesai", tapi timeout 10 menit.
Future<void> _tunggu(
  WidgetTester tester,
  Finder target, {
  int maksFrame = 300,
}) async {
  for (var i = 0; i < maksFrame; i++) {
    await tester.pump(const Duration(milliseconds: 50));

    if (target.evaluate().isNotEmpty) return;
  }

  fail('Nggak muncul sesudah $maksFrame frame: $target');
}

/// Kebalikan [_tunggu]: nunggu sampai [target] NGGAK ada lagi.
///
/// Dipakai buat nunggu layar review ketutup. Nunggu munculnya widget layar di
/// bawahnya nggak bisa: route yang ketutup tetap kebangun di pohon widget, jadi
/// `find` nemuin dia walau layarnya nggak kelihatan.
Future<void> _tungguHilang(
  WidgetTester tester,
  Finder target, {
  int maksFrame = 300,
}) async {
  for (var i = 0; i < maksFrame; i++) {
    await tester.pump(const Duration(milliseconds: 50));

    if (target.evaluate().isEmpty) return;
  }

  fail('Masih ada sesudah $maksFrame frame: $target');
}

void main() {
  late File fotoLembar;
  late WorksheetTemplate template;

  setUpAll(() {
    // Lembar cetaknya dibikin mirip JEPRETAN dulu. Berkas rendernya putih 255
    // pekat — kecerahan rata-ratanya 247, di atas ambang server (225) — jadi
    // dipakai apa adanya dia ditolak gerbang mutu sebagai "terlalu terang",
    // dan yang keuji cuma bahwa berkas ujinya bukan foto.
    final cetakan = img.decodePng(
      File('test/assets/lembar-conductivity-v1.png').readAsBytesSync(),
    )!;

    for (var y = 0; y < cetakan.height; y++) {
      for (var x = 0; x < cetakan.width; x++) {
        final p = cetakan.getPixel(x, y);
        cetakan.setPixelRgb(
          x,
          y,
          (p.r * 0.62).round(),
          (p.g * 0.62).round(),
          (p.b * 0.62).round(),
        );
      }
    }

    fotoLembar = File(
      '${Directory.systemTemp.createTempSync('pindai').path}/jepretan.png',
    )..writeAsBytesSync(img.encodePng(cetakan));

    final geometri =
        jsonDecode(
              File('test/assets/geometri-conductivity-v1.json')
                  .readAsStringSync(),
            )
            as Map<String, dynamic>;

    final sel = <String, dynamic>{};
    final tabel = <Map<String, dynamic>>[];

    for (final t in geometri['tabel'] as List<dynamic>) {
      final m = t as Map<String, dynamic>;
      sel.addAll(m['sel'] as Map<String, dynamic>);

      tabel.add({
        'tabel_id': m['tabel_id'],
        'judul': m['judul'],
        'baris': [
          for (var i = 1; i <= 4; i++)
            {'baris_ke': i, 'titik_ukur': 25.0 * i, 'standard_id': i},
        ],
        'kolom': [
          {'field_id': 'pembacaan', 'label': 'Reading'},
          {'field_id': 'suhu', 'label': '°C'},
        ],
        'pengulangan': [1, 2, 3, 4, 5],
      });
    }

    template = WorksheetTemplate.fromJson({
      'template_id': geometri['template_id'],
      'versi': geometri['versi'],
      'kode_dokumen': geometri['kode_dokumen'],
      'judul': 'Calibration Worksheet - Conductivity Meter',
      // Lembar yang geometrinya UDAH diverifikasi lab. Selama masih `false`
      // tombolnya mati, dan itu dijaga di `lembar_kerja_test`.
      'siap_pindai': true,
      'tabel': tabel,
      'sel': sel,
      'jangkar': geometri['jangkar'],
      'geometri': geometri,
    });
  });

  testWidgets('pindai → review → angkanya masuk formulir, sesi ditandai', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final lembarKerja = MockLembarKerjaService();
    final riwayat = MockHistoryService();
    final pindai = MockWorksheetScanService(
      siapPindai: true,
      templateLengkap: template,
      hasil: _hasilPindai,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          lembarKerjaServiceProvider.overrideWithValue(lembarKerja),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
          historyServiceProvider.overrideWithValue(riwayat),
          worksheetScanServiceProvider.overrideWithValue(pindai),
          // Kameranya balikin CITRA LEMBAR CETAK yang asli — marker, QR, dan
          // gerbang mutunya beneran dilewati, bukan dilangkahi.
          sumberFotoProvider.overrideWithValue(
            MockSumberFoto(file: fotoLembar),
          ),
          // ML Kit butuh perangkat; yang diuji di sini sambungannya.
          pabrikPembacaPindaiProvider.overrideWithValue((
            sel: () => _PembacaLembar(),
            qr: () => MockPembacaQr(isi: 'conductivity_meter|v1'),
          )),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Lembar di layar: mock pH (satu-satunya bentuk yang ada tiruannya).
          // Yang DIFOTO tetap cetakan Conductivity asli — itu satu-satunya
          // lembar bermarker yang kita punya sebagai aset. Pasangan itu
          // disengaja: yang diuji sambungannya, dan marker, QR, serta gerbang
          // mutunya tetap dilewati beneran.
          home: const LembarKerjaScreen(profil: 'ph_meter'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Alatnya dipilih dulu — tanpa itu lembarnya nggak bisa dikirim, dan
    // resolusi alatnya juga yang nentuin angka hasil pindai dipadin ke berapa
    // desimal waktu masuk kotak.
    await tester.tap(find.text('Pilih alat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
    await tester.pumpAndSettle();

    // Lembarnya dua halaman di layar sempit; tabelnya di halaman terakhir.
    while (find.text('SELANJUTNYA').evaluate().isNotEmpty) {
      await tester.tap(find.text('SELANJUTNYA'));
      await tester.pumpAndSettle();
    }

    // Tombolnya jauh di bawah dalam `ListView` — tanpa digulung ke layar,
    // `tap` mendarat di ruang kosong dan diam-diam nggak ngapa-ngapain.
    await tester.ensureVisible(find.text('PINDAI LEMBAR KERJA').first);
    await tester.pump();
    // `runAsync` WAJIB: di widget test, timer & I/O aslinya dipalsukan, jadi
    // `File.readAsBytes()` (fotonya) nggak pernah selesai dan pindainya
    // menggantung selamanya di dalam `pump` biasa. Yang dijalanin di sini
    // kerjaan berat aslinya — warp 1654×2339 plus 85 potongan.
    await tester.runAsync(() async {
      await tester.tap(find.text('PINDAI LEMBAR KERJA').first);

      final jam = Stopwatch()..start();

      while (pindai.terkirim.isEmpty && jam.elapsed.inSeconds < 60) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });

    await _tunggu(tester, find.text('Cek Hasil Pindai'));

    // Layar review kebuka dengan hasil dari server.
    expect(find.text('Cek Hasil Pindai'), findsOneWidget);

    // Yang dikirim ke server: SEMUA sel template, plus jangkar yang kebaca.
    final terkirim = pindai.terkirim.single;
    expect((terkirim['sel'] as List<dynamic>), hasLength(80));
    expect((terkirim['sel_jangkar'] as List<dynamic>), hasLength(5));
    expect((terkirim['qr'] as Map)['isi'], 'conductivity_meter|v1');

    // Sama seperti waktu memindai: sisa jalur `_pindai` (nunggu layar review
    // ditutup, lalu nuang angkanya ke formulir) hidup di zona async ASLI
    // karena dimulai di dalam `runAsync`. Kalau tombolnya ditekan di luar,
    // layarnya ketutup tapi lanjutannya nggak pernah kebagian giliran jalan —
    // dan angkanya nggak mendarat ke mana-mana tanpa satu pun error.
    await tester.runAsync(() async {
      await tester.tap(find.text('PAKAI ANGKA INI'));

      final jam = Stopwatch()..start();

      while (pindai.koreksiTerkirim.isEmpty && jam.elapsed.inSeconds < 30) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Napas buat lanjutan sesudah `Navigator.pop`.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    await _tungguHilang(tester, find.text('PAKAI ANGKA INI'));

    // Balik ke lembar kerja, dan angkanya mendarat di kotak isian.
    expect(find.text('Cek Hasil Pindai'), findsNothing);
    // Dua sel yang disetujui mendarat di kotaknya: pembacaan & suhu Repeat 1
    // di titik 4,00. Pembacaannya dipadin ke resolusi alatnya (`1,50`), suhu
    // nggak — aturan yang sama kayak isian manual.
    expect(
      find.widgetWithText(TextField, '1,50'),
      findsOneWidget,
      reason: 'Angka yang disetujui teknisi nggak nyampe kotak isiannya.',
    );
    expect(find.widgetWithText(TextField, '25'), findsOneWidget);

    // Koreksinya disetor — satu-satunya sumber data akurasi sistem.
    expect(pindai.koreksiTerkirim.single, hasLength(2));

    await tester.ensureVisible(find.text('KIRIM KE ADMIN'));
    await tester.pump();
    await tester.tap(find.text('KIRIM KE ADMIN'));
    await tester.pumpAndSettle();

    // Dialog konfirmasinya nyebut angka hasil foto secara EKSPLISIT — dulu
    // penandaannya langkah terpisah di layar Riwayat, dan teknisi nggak pernah
    // dikasih tahu dia mesti balik ke sana.
    final konfirmasi = find.text('Kirim sekarang');

    expect(
      konfirmasi,
      findsOneWidget,
      reason: 'Sesi hasil pindai WAJIB lewat dialog konfirmasi.',
    );

    if (konfirmasi.evaluate().isNotEmpty) {
      expect(
        find.textContaining('datang dari foto'),
        findsOneWidget,
        reason: 'Kalimat itu yang bikin teknisi natap angkanya sekali lagi.',
      );

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
    }

    expect(lembarKerja.jumlahKirim, 1);
    expect(
      lembarKerja.payloadTerakhir!['input_method'],
      'ocr',
      reason: 'Asal-usul angkanya kudu kecatat, bukan nyamar jadi ketikan.',
    );
    expect(
      riwayat.diverifikasi,
      isNotEmpty,
      reason: 'Tanpa ini sesinya nge-blok admin tanpa teknisi tau.',
    );
  });
}

/// Hasil pindai dari server: dua sel kebaca di titik 4,00, sisanya kosong.
///
/// Titiknya ngikut lembar yang lagi kebuka di layar (mock pH), karena itu yang
/// nentuin angkanya mendarat di kotak yang mana.
///
/// Bentuknya ngikut `PemrosesScanLembarKerja` — `tabel[].baris[].
/// pengulangan[].kolom[field_id]`, tanpa `pengulangan` di level tabel.
final _hasilPindai = HasilPindai.fromJson(const <String, dynamic>{
  'scan_id': 77,
  'status': 'perlu_review',
  'ringkasan': {
    'total_sel': 80,
    'hijau': 0,
    'kuning': 2,
    'merah': 0,
    'kosong': 78,
  },
  // Server yang mutusin tombol simpannya boleh aktif — bukan dihitung ulang
  // dari jumlah sel merah di HP.
  'boleh_auto_isi': true,
  'wajib_dicek': true,
  'tabel': [
    {
      'tabel_id': 'sesudah_adjustment',
      'tahap': 'sesudah_adjustment',
      'judul': 'After adjustment Reading',
      'baris': [
        {
          'baris_ke': 1,
          'titik_ukur': 4.0,
          'label': '4,00',
          'pengulangan': [
            {
              'repeat_no': 1,
              'kolom': {
                'pembacaan': {
                  'kunci': 'sesudah_adjustment|1|1|pembacaan',
                  'teks_mentah': '1,50',
                  'nilai': 1.5,
                  'status': 'kuning',
                  'alasan': <String>[],
                  'normalisasi': <String>[],
                },
                'suhu': {
                  'kunci': 'sesudah_adjustment|1|1|suhu',
                  'teks_mentah': '25,0',
                  'nilai': 25.0,
                  'status': 'kuning',
                  'alasan': <String>[],
                  'normalisasi': <String>[],
                },
              },
            },
          ],
        },
      ],
    },
  ],
});

/// Pembaca sel palsu: sel dibiarin kosong, label Repeat dibaca `X1..X5`.
///
/// Yang dibedakan tingginya — kotak sel 100 px, kotak label 39 px — persis
/// seperti ML Kit beneran, yang juga cuma nerima citra tanpa tahu itu sel atau
/// label.
class _PembacaLembar implements PembacaSel {
  int _jangkarKe = 0;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    if (potongan.height < 60) {
      _jangkarKe++;

      return (teks: 'X$_jangkarKe', keyakinan: null, didalamKotak: true);
    }

    return (teks: null, keyakinan: null, didalamKotak: true);
  }

  @override
  Future<void> tutup() async {}
}
