import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_analitik.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_panjang.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_tekanan.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/registrasi_jangkar_teks.dart';

/// "Foto lembar kerja" generik (K-50-11): satu formulir dari tiap kelompok —
/// kimia (Conductivity 0510), suhu (TIDS 0506), mekanik (Pressure 0507),
/// dimensi (Micrometer 0522.A) — dengan foto SINTETIS.
///
/// Geometrinya NYATA: template yang disajikan server
/// (`FormulirAsli::cari()`, repo API) untuk peta formulir itu, disimpan di
/// `test/assets/template-asli-*.json`. Fotonya buatan: kertas berderau, kotak
/// sel & isian digambar lewat homography yang diketahui (miring + perspektif).
/// ML Kit dimatikan (bacaan palsu berurutan); yang diuji sungguhan: pencocokan
/// jangkar, RANSAC, perataan, pemotongan per kotak, urutan baca sel + isian,
/// dan penuangan hasil ke lembar lewat layar review.
///
/// Yang dibuktikan, per formulir:
/// 1. tiap sel & tiap isian Env. dibaca dari kotaknya sendiri (potongan sel
///    yang kotaknya diberi tinta lebih gelap daripada potongan yang tidak);
/// 2. kotak centang tidak dibaca (manual);
/// 3. setiap bacaan mendarat di sel lembar yang benar — alamat
///    (tabel, baris, Repeat, kolom), bukan titik ukur (di lembar bertitik
///    ketik-sendiri semua titik 0);
/// 4. tabel lain tidak ikut terisi.
class _Kasus {
  const _Kasus(this.nama, this.aset, this.bentuk, this.kodeFm);

  final String nama;
  final String aset;
  final Map<String, dynamic> Function() bentuk;
  final String kodeFm;
}

final _kasus = <_Kasus>[
  _Kasus(
    'kimia · Conductivity 0510 (dua tabel Before/After, kolom pembacaan+suhu)',
    'test/assets/template-asli-conductivity_meter-0510.json',
    contohBentukLembarKerjaConductivity,
    'SIDIK-FM-CAL-0510',
  ),
  _Kasus(
    'suhu · TIDS 0506 (Standard + UUT berpasangan, kunci kotak ≠ tabel_id)',
    'test/assets/template-asli-tids-0506.json',
    contohBentukLembarKerjaTids,
    'SIDIK-FM-CAL-0506',
  ),
  _Kasus(
    'mekanik · Pressure Gauge 0507 (Up/Down, titik diketik teknisi)',
    'test/assets/template-asli-pressure_gauge-0507.json',
    contohBentukLembarKerjaPressureGauge,
    'SIDIK-FM-CAL-0507',
  ),
  _Kasus(
    'dimensi · Micrometer 0522.A (dua tabel, titik diketik teknisi)',
    'test/assets/template-asli-micrometer-0522A.json',
    contohBentukLembarKerjaMicrometer,
    'SIDIK-FM-CAL-0522.A',
  ),
];

void main() {
  for (final k in _kasus) {
    group(k.nama, () => _uji(k));
  }

  test(
    'pintu foto: tabel yang bukan tabel lembar (grid Enclosure) tidak diterima',
    () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaTids()),
        clientRequestId: 'uuid-test',
      );
      WorksheetTemplate dengan(String tabelId, int baris) =>
          WorksheetTemplate.fromJson({
            'data': {
              'kertas': 'asli',
              'template_id': 'x',
              'sel': {
                'k': {
                  'kunci': 'k',
                  'tabel_id': tabelId,
                  'baris_ke': baris,
                  'repeat_no': 1,
                  'field_id': 'pembacaan',
                },
              },
            },
          });

      expect(state.bisaMenerimaFotoAsli(dengan('pembacaan_uut', 1)), isTrue);
      // Tabel yang tidak ada di lembar (grid Enclosure) dan baris di luar lembar.
      expect(state.bisaMenerimaFotoAsli(dengan('grid', 1)), isFalse);
      expect(state.bisaMenerimaFotoAsli(dengan('pembacaan_uut', 99)), isFalse);
    },
  );

  test(
    'pita wajar isian lingkungan: suhu, kelembaban, tekanan; lainnya tolak',
    () {
      expect(wajarIsianLingkungan('suhu_awal', 25.0), isTrue);
      expect(wajarIsianLingkungan('suhu_awal', 250.0), isFalse);
      expect(wajarIsianLingkungan('kelembaban_akhir', 55.0), isTrue);
      expect(wajarIsianLingkungan('kelembaban_akhir', 5.0), isFalse);
      expect(wajarIsianLingkungan('tekanan_awal', 1013.0), isTrue);
      expect(wajarIsianLingkungan('tekanan_awal', 101.3), isFalse);
      expect(wajarIsianLingkungan('spesifikasi_alat.suhu_awal', 25.0), isTrue);
      expect(wajarIsianLingkungan('alat_serial_number', 25.0), isFalse);
    },
  );
}

void _uji(_Kasus k) {
  late WorksheetTemplate template;
  late ({double w, double h}) halaman;
  late Homografi benar;
  late int lebar, tinggi;

  setUpAll(() {
    template = WorksheetTemplate.fromJson(
      jsonDecode(File(k.aset).readAsStringSync()) as Map<String, dynamic>,
    );
    halaman = template.halamanPt!;

    const s = 2.2;
    final c = math.cos(2 * math.pi / 180) * s;
    final n = math.sin(2 * math.pi / 180) * s;
    benar = Homografi([c, -n, 60, n, c, 80, 1e-5, -5e-6, 1]);
    lebar = (halaman.w * s + 220).round();
    tinggi = (halaman.h * s + 260).round();
  });

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

    // Revisi tercetak ("Revise : 4"), kalau formulirnya mencetaknya.
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

  /// Kotak [KotakSel] ternormal → empat sudut foto.
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

  /// Foto sintetis: kertas berderau, bingkai tiap sel & isian, dan kotak
  /// [bertinta] DIISI tinta gelap (buat membuktikan potongan diambil dari
  /// kotak yang benar).
  img.Image foto({required Set<String> bertinta}) {
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

    void gambar(KotakSel kotak, {required bool isi}) {
      final p = sudutFoto(kotak);
      if (isi) {
        img.fillPolygon(
          c,
          vertices: [for (final t in p) img.Point(t.x.round(), t.y.round())],
          color: tinta,
        );
        return;
      }
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
      gambar(s.kotak!, isi: bertinta.contains(s.kunci));
    }
    for (final i in template.isian) {
      gambar(i.kotak!, isi: bertinta.contains(kunciPotonganIsian(i.kode)));
    }

    return c;
  }

  /// Bacaan palsu berurutan: sel dulu (urut server), lalu isian (urut server).
  /// Isian dibaca sebagai angka wajar menurut keluarganya.
  List<String> bacaan() => [
    for (var i = 0; i < template.selAsli.length; i++)
      '${10 + i ~/ 10},${i % 10}',
    for (final i in template.isian)
      switch (i.kode.split('.').last) {
        final c when c.startsWith('kelembaban_') => '55,5',
        final c when c.startsWith('tekanan_') => '1013',
        _ => '25,5',
      },
  ];

  test(
    'geometri server memuat sel, isian Env., dan centang untuk formulir ini',
    () {
      expect(template.kertasAsli, isTrue);
      expect(template.kodeDokumen, startsWith(k.kodeFm));
      expect(template.modeUji, isTrue);
      expect(template.bolehDipindaiAsli, isTrue);
      expect(template.selAsli, isNotEmpty);
      expect(template.isian, isNotEmpty, reason: 'peta ini punya isian Env.');
      expect(template.kotakAsliHilang, 0);
      // Tabel lebih dari satu → alamat sel membawa tabel_id.
      expect(
        {for (final s in template.selAsli) s.tabelId}.length,
        greaterThan(1),
      );
    },
  );

  test(
    'engine: tiap sel & isian dibaca dari kotaknya sendiri, centang tidak dibaca',
    () async {
      final sel0 = template.selAsli.first.kunci;
      final selTengah = template.selAsli[template.selAsli.length ~/ 2].kunci;
      final selAkhir = template.selAsli.last.kunci;
      final isian0 = kunciPotonganIsian(template.isian.first.kode);
      final bertinta = {sel0, selTengah, selAkhir, isian0};

      final pembaca = MockPembacaSel(bacaan: bacaan());
      final hasil = await JalankanPindaiAsli(
        halaman: MockPembacaHalaman(kataCetak()),
        pembaca: pembaca,
      ).baca(foto(bertinta: bertinta), template: template);

      expect(hasil.kodeTerbaca, startsWith(k.kodeFm));
      expect(hasil.sel, hasLength(template.selAsli.length));
      expect(hasil.isian, hasLength(template.isian.length));
      // Hanya sel + isian: kotak centang (template.centang) tidak dibaca.
      expect(
        pembaca.jumlahDibaca,
        template.selAsli.length + template.isian.length,
      );
      expect(hasil.sel.first.sel.kunci, sel0);
      expect(hasil.isian.first.isian.kode, template.isian.first.kode);

      double gelap(String kunci) {
        final png = hasil.potongan[kunci]!;
        final c = img.decodePng(png)!;
        var jumlah = 0.0;
        var n = 0;
        // Bagian tengah potongan: bingkai sel ikut terpotong di tepinya.
        for (var y = c.height ~/ 4; y < c.height * 3 ~/ 4; y++) {
          for (var x = c.width ~/ 4; x < c.width * 3 ~/ 4; x++) {
            jumlah += c.getPixel(x, y).luminance;
            n++;
          }
        }

        return jumlah / n;
      }

      final terang = gelap(template.selAsli[1].kunci);
      for (final kunci in bertinta) {
        expect(
          gelap(kunci),
          lessThan(terang - 80),
          reason: 'potongan $kunci tidak diambil dari kotaknya',
        );
      }
      // Sel yang tidak diberi tinta tetap terang: potongan tidak menyebar.
      expect(gelap(template.selAsli[2].kunci), greaterThan(terang - 40));
    },
  );

  testWidgets('alur penuh: review → semua bacaan mendarat di sel yang benar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 60000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(k.bentuk()),
      clientRequestId: 'uuid-test',
    );
    final teksBacaan = bacaan();
    final mesin = JalankanPindaiAsli(
      halaman: MockPembacaHalaman(kataCetak()),
      pembaca: MockPembacaSel(bacaan: teksBacaan),
    );

    final dir = Directory.systemTemp.createTempSync('foto-asli-kelompok');
    final berkas = File('${dir.path}/lembar.png');
    await tester.runAsync(() async {
      berkas.writeAsBytesSync(img.encodePng(foto(bertinta: {})));
    });
    final sumber = MockSumberFoto(file: berkas);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberFotoProvider.overrideWithValue(sumber)],
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

    // Tulisan tangan tidak pernah hijau: semua baris wajib dicek satu per satu.
    final masukkan = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(masukkan).onPressed, isNull);

    final cek = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('cek-'),
    );
    final jumlahBaris = cek.evaluate().length;
    expect(jumlahBaris, template.selAsli.length + template.isian.length);

    for (var i = 0; i < jumlahBaris; i++) {
      await tester.tap(cek.at(i));
    }
    await tester.pump();
    expect(tester.widget<FilledButton>(masukkan).onPressed, isNotNull);

    await tester.tap(masukkan);
    await tester.pumpAndSettle();

    // Pesan: formulir yang punya kotak centang mengingatkan bahwa centang
    // tetap manual; yang tidak punya pakai pesan biasa.
    expect(
      find.textContaining('tetap diisi manual'),
      template.centang.isEmpty ? findsNothing : findsOneWidget,
    );

    // Tiap sel mendarat di (tabel, baris, Repeat, kolom) miliknya.
    for (var i = 0; i < template.selAsli.length; i++) {
      final s = template.selAsli[i];
      final tabel = isian.tabelUntukId(s.tabelId);
      expect(
        tabel,
        isNotNull,
        reason: 'tabel ${s.tabelId} tidak ada di lembar',
      );

      final baris = isian.barisTabel(tabel!);
      final ts = isian.titikUntukBaris(baris, s.barisKe - 1, tabel);
      expect(ts, isNotNull, reason: '${s.kunci}: baris tidak ada');

      final posisi = tabel.pengulangan.indexOf(s.repeatNo);
      final teks = ts!.kotak(tabel.kunciTabel, s.fieldId, posisi).text;
      expect(
        parseAngka(teks),
        parseAngka(teksBacaan[i]),
        reason: '${s.kunci} mendarat salah ("$teks")',
      );
    }

    // Isian Env.: kotak lembar berisi bacaannya.
    for (var j = 0; j < template.isian.length; j++) {
      final kode = template.isian[j].kode;
      expect(
        isian.angka(kode),
        parseAngka(teksBacaan[template.selAsli.length + j]),
        reason: 'isian $kode tidak masuk lembar',
      );
    }

    expect(isian.adaIsianDariFoto, isTrue);
  });
}
