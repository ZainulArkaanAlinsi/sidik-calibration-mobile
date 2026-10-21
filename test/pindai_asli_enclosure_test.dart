import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_enclosure.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/registrasi_jangkar_teks.dart';

/// "Foto lembar kerja" untuk ENCLOSURE (form 0504: bath, furnace, oven,
/// inkubator, refrigerator) dengan foto SINTETIS.
///
/// Template = respons nyata server (`FormulirAsli::cari('oven')`, repo API) di
/// `test/assets/template-asli-oven-0504.json`: 55 sel `grid|baris|repeat|
/// pembacaan` (9 termokopel + Indikator + Suhu Ruang, 5 pembacaan), 2 isian
/// Env. Fotonya buatan; ML Kit diganti bacaan palsu. Yang diuji sungguhan:
/// pencocokan jangkar, perataan, pemotongan per kotak, layar review, dan
/// penuangan ke GRID (set point x posisi sensor x pembacaan).
void main() {
  late WorksheetTemplate template;
  late ({double w, double h}) halaman;
  late Homografi benar;
  late int lebar, tinggi;

  setUpAll(() {
    template = WorksheetTemplate.fromJson(
      jsonDecode(
            File('test/assets/template-asli-oven-0504.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    halaman = template.halamanPt!;

    const s = 2.2;
    final c = math.cos(2 * math.pi / 180) * s;
    final n = math.sin(2 * math.pi / 180) * s;
    benar = Homografi([c, -n, 60, n, c, 80, 1e-5, -5e-6, 1]);
    lebar = (halaman.w * s + 220).round();
    tinggi = (halaman.h * s + 260).round();
  });

  LembarKerjaState buatState() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaOven()),
    clientRequestId: 'uuid-test',
  );

  Titik proyeksi(double xPt, double yPt) => benar.terapkan((x: xPt, y: yPt))!;

  Rect kotakFoto(KotakSel kotak) {
    final a = proyeksi(kotak.x * halaman.w, kotak.y * halaman.h);
    final b = proyeksi(
      (kotak.x + kotak.w) * halaman.w,
      (kotak.y + kotak.h) * halaman.h,
    );

    return Rect.fromPoints(Offset(a.x, a.y), Offset(b.x, b.y));
  }

  List<TeksTerbaca> kataCetak() {
    final hasil = <TeksTerbaca>[
      for (final j in template.jangkarTeks)
        (teks: j.teks, kotak: kotakFoto(j.kotak), keyakinan: null),
    ];

    final rev = template.jangkarTeks.where(
      (j) => const {'Revise', 'Revisi'}.contains(j.teks),
    );
    if (rev.length == 1 && template.revisi != null) {
      final r = rev.single.kotak;
      final y = (r.y + r.h / 2) * halaman.h;
      final x = (r.x + r.w) * halaman.w;
      for (final (dx, t) in [(4.0, ':'), (12.0, template.revisi!)]) {
        final p = proyeksi(x + dx, y);
        hasil.add((
          teks: t,
          kotak: Rect.fromCenter(
            center: Offset(p.x, p.y),
            width: 10,
            height: 18,
          ),
          keyakinan: null,
        ));
      }
    }

    return hasil;
  }

  List<Titik> sudutFoto(KotakSel kotak) {
    final x0 = kotak.x * halaman.w, y0 = kotak.y * halaman.h;
    final x1 = (kotak.x + kotak.w) * halaman.w;
    final y1 = (kotak.y + kotak.h) * halaman.h;

    return [
      proyeksi(x0, y0),
      proyeksi(x1, y0),
      proyeksi(x1, y1),
      proyeksi(x0, y1),
    ];
  }

  img.Image foto() {
    final c = img.Image(width: lebar, height: tinggi);
    final b = c.toUint8List();
    var s = 12345;
    for (var i = 0; i < lebar * tinggi; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final v = 175 + s % 61;
      b[i * 3] = v;
      b[i * 3 + 1] = v;
      b[i * 3 + 2] = v;
    }

    final tinta = img.ColorRgb8(25, 25, 30);
    void bingkai(KotakSel kotak) {
      final p = sudutFoto(kotak);
      for (var i = 0; i < 4; i++) {
        final a = p[i], bb = p[(i + 1) % 4];
        img.drawLine(
          c,
          x1: a.x.round(),
          y1: a.y.round(),
          x2: bb.x.round(),
          y2: bb.y.round(),
          color: tinta,
        );
      }
    }

    for (final s in template.selAsli) {
      bingkai(s.kotak!);
    }
    for (final i in template.isian) {
      bingkai(i.kotak!);
    }

    return c;
  }

  /// Bacaan palsu urut server: sel dulu, lalu isian. Nilai sel = 120 + baris,
  /// desimal = Repeat (mis. baris 3 Repeat 2 -> 123,2); [merah] = alamat sel
  /// yang tulisannya bukan angka.
  List<String> bacaan({int tambah = 0, String? merah}) => [
    for (final s in template.selAsli)
      '${s.barisKe}-${s.repeatNo}' == merah
          ? 'x'
          : '${120 + tambah + s.barisKe},${s.repeatNo}',
    for (final i in template.isian)
      i.kode.startsWith('kelembaban_') ? '55,5' : '25,5',
  ];

  Future<void> fotoSekali(
    WidgetTester tester, {
    required LembarKerjaState isian,
    required List<String> teks,
    required Future<void> Function(WidgetTester) tinjau,
  }) async {
    final mesin = JalankanPindaiAsli(
      halaman: MockPembacaHalaman(kataCetak()),
      pembaca: MockPembacaSel(bacaan: teks),
    );

    final dir = Directory.systemTemp.createTempSync('foto-asli-enclosure');
    final berkas = File('${dir.path}/lembar.png');
    await tester.runAsync(() async {
      berkas.writeAsBytesSync(img.encodePng(foto()));
    });

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sumberFotoProvider.overrideWithValue(MockSumberFoto(file: berkas)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => pindaiFormulirAsli(
                  context: context,
                  ref: ref,
                  isian: isian,
                  template: template,
                  mesin: mesin,
                ),
                child: const Text('foto'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('foto'));
    for (var i = 0; i < 600; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(SnackBar).evaluate().isNotEmpty ||
          find.byType(FilledButton).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(
      find.byType(FilledButton),
      findsOneWidget,
      reason: 'layar review tidak muncul (pesan gagal?)',
    );

    await tinjau(tester);
  }

  /// Tulisan tangan tidak pernah hijau: semua baris dicek satu per satu, baru
  /// "masukkan" menyala.
  Future<void> cekSemuaLaluMasukkan(WidgetTester tester) async {
    final masukkan = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(masukkan).onPressed, isNull);

    final cek = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('cek-'),
    );
    final n = cek.evaluate().length;
    for (var i = 0; i < n; i++) {
      await tester.tap(cek.at(i));
    }
    await tester.pump();
    expect(tester.widget<FilledButton>(masukkan).onPressed, isNotNull);

    await tester.tap(masukkan);
    await tester.pumpAndSettle();
  }

  test(
    'template nyata 0504: grid 11 baris x 5 pembacaan, siap lewat mode uji',
    () {
      expect(template.kertasAsli, isTrue);
      expect(template.kodeDokumen, startsWith('SIDIK-FM-CAL-0504'));
      expect(template.bolehDipindaiAsli, isTrue);
      expect(template.selAsli, hasLength(55));
      expect(template.isian, hasLength(2));
      expect(template.kotakAsliHilang, 0);
      expect({for (final s in template.selAsli) s.tabelId}, {'grid'});
    },
  );

  test('pintu foto Enclosure: lembar ber-grid menerima, lembar lain tidak', () {
    expect(buatState().bisaMenerimaFotoAsli(template), isTrue);

    final tids = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaTids()),
      clientRequestId: 'uuid-test',
    );
    expect(tids.bisaMenerimaFotoAsli(template), isFalse);
  });

  test('alamat grid: baris 1-9 termokopel, 10 Indikator, 11 Suhu Ruang', () {
    final g = buatState().grid!;
    expect(barisKertasGrid(g.bentuk, 1)!.jenis, JenisBarisKertas.termokopel);
    expect(barisKertasGrid(g.bentuk, 9)!.urutan, 9);
    expect(barisKertasGrid(g.bentuk, 10)!.jenis, JenisBarisKertas.indikator);
    expect(barisKertasGrid(g.bentuk, 11)!.jenis, JenisBarisKertas.suhuRuang);
    expect(barisKertasGrid(g.bentuk, 12), isNull);
    expect(barisKertasGrid(g.bentuk, 0), isNull);
  });

  testWidgets('alur penuh: review lalu tiap bacaan mendarat di set point x '
      'posisi sensor x pembacaan yang benar', (tester) async {
    tester.view.physicalSize = const Size(1000, 60000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final isian = buatState();
    await fotoSekali(
      tester,
      isian: isian,
      teks: bacaan(),
      tinjau: cekSemuaLaluMasukkan,
    );

    final g = isian.grid!;
    expect(g.setPoint, hasLength(1), reason: 'set point kosong dipakai dulu');
    final sp = g.setPoint.single;

    for (var baris = 1; baris <= 9; baris++) {
      final b = sp.sensor[baris - 1];
      for (var r = 1; r <= 5; r++) {
        expect(b.pembacaan[r - 1], double.parse('${120 + baris}.$r'));
        expect(b.dariFoto, contains(r - 1));
        expect(b.bacaanMesin[r - 1]!.teksMentah, '${120 + baris},$r');
      }
      // Nomor termokopel TIDAK ditebak dari posisi kertas.
      expect(b.no, isNull, reason: 'baris $baris diberi nomor tanpa dasar');
    }
    for (var r = 1; r <= 5; r++) {
      expect(sp.indikator.nilai[r - 1], double.parse('130.$r'));
      expect(sp.indikator.dariFoto, contains(r - 1));
      expect(sp.suhuRuang.nilai[r - 1], double.parse('131.$r'));
      expect(sp.suhuRuang.dariFoto, contains(r - 1));
    }

    expect(isian.adaIsianDariFoto, isTrue);
    // Baris tanpa nomor belum dikirim: teknisi wajib mengisi nomornya.
    expect(sp.sensorTerisi, isEmpty);
  });

  testWidgets('merah (bukan angka) wajib diketik; kotak yang sudah berisi tidak '
      'ditimpa; foto kedua masuk set point BARU', (tester) async {
    tester.view.physicalSize = const Size(1000, 60000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final isian = buatState();
    // Teknisi sudah mengetik satu angka di kotak yang juga ada di foto.
    isian.grid!.setPoint.single.sensor[0].pembacaanCtl[0].text = '99,9';

    await fotoSekali(
      tester,
      isian: isian,
      teks: bacaan(merah: '3-2'),
      tinjau: (tester) async {
        final masukkan = find.byType(FilledButton);
        expect(tester.widget<FilledButton>(masukkan).onPressed, isNull);

        // Baris merah mulai KOSONG dan wajib diketik; sisanya wajib dicek.
        final kotak = find.byType(TextField);
        expect(tester.widget<TextField>(kotak.first).controller!.text, isEmpty);
        await tester.enterText(kotak.first, '123,9');
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );

        final cek = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith('cek-'),
        );
        for (var i = 0; i < cek.evaluate().length; i++) {
          await tester.tap(cek.at(i));
        }
        await tester.pump();
        expect(tester.widget<FilledButton>(masukkan).onPressed, isNotNull);
        await tester.tap(masukkan);
        await tester.pumpAndSettle();
      },
    );

    var g = isian.grid!;
    // Set point pertama sudah berisi (ketikan teknisi) -> BUKAN set point kosong
    // lagi, jadi foto ini mendarat di set point baru. Ketikan lama utuh.
    expect(g.setPoint, hasLength(2));
    expect(g.setPoint[0].sensor[0].pembacaanCtl[0].text, '99,9');
    expect(g.setPoint[0].sensor[0].dariFoto, isNot(contains(0)));
    final baru = g.setPoint[1];
    expect(baru.sensor[0].pembacaan[0], 121.1);
    expect(baru.sensor[2].pembacaan[1], 123.9, reason: 'merah diketik 123,9');

    // Foto kedua (lembar set point berikutnya) -> set point ketiga.
    await fotoSekali(
      tester,
      isian: isian,
      teks: bacaan(tambah: 50),
      tinjau: cekSemuaLaluMasukkan,
    );
    g = isian.grid!;
    expect(g.setPoint, hasLength(3));
    expect(g.setPoint[2].sensor[0].pembacaan[0], 171.1);
    expect(
      g.setPoint[1].sensor[0].pembacaan[0],
      121.1,
      reason: 'tidak ditimpa',
    );
  });

  testWidgets('layar lembar Oven menampilkan pintu "Foto lembar kerja"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          lembarKerjaServiceProvider.overrideWithValue(
            MockLembarKerjaService(),
          ),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
          formulirAsliProvider.overrideWith((ref, kunci) async => template),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LembarKerjaScreen(profil: 'oven'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsOneWidget);
  });
}
