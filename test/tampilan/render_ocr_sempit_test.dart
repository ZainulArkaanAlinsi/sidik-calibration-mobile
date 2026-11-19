// Paket OCR-SEMPIT: PNG untuk persetujuan pemilik.
//
// Panel "Alat baru" di lembar yang dibuka dari foto: pada layar SEMPIT dibuka
// sebagai lembar bawah, pada layar lega tetap inline di blok identitas. Merender
// LembarKerjaScreen sungguhan (kerangka beku) tiap keadaan pada 320 x 640 huruf
// 2,0 (terang dan gelap), 360 x 640 huruf 1,3, dan 392 x 852 huruf 1,0 (terang
// dan gelap; pembanding "tidak berubah"). Data = Mock*Service dan teks
// sintetis; tidak ada foto asli lab. Papan ketik digambar kotak abu-abu
// bertulisan "papan ketik (sistem)" (sistem yang menggambarnya, bukan Flutter).
//
// PNG hanya ditulis bila `SIDIK_PNG_DIR` diisi (folder di LUAR repo):
//
//   SIDIK_PNG_DIR=<folder> flutter test test/tampilan/render_ocr_sempit_test.dart
//
// Tanpa itu semua tes di sini dilewati. Satu keadaan saja: `SIDIK_KEADAAN=
// 03-mengetik`. Nama berkas: `<keadaan>.<ukuran>-<tema>.png`.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/pindai/blok_identitas_foto.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';

import '../support/dunia_lembar_foto_uji.dart';
import '../support/layanan_alat_uji.dart';
import '../support/simpanan_tiruan.dart';

const _ukuran = <UkuranUji>[
  UkuranUji('320-huruf2', 320, 640, 2.0),
  UkuranUji('320-huruf2', 320, 640, 2.0, gelap: true),
  UkuranUji('360-huruf1,3', 360, 640, 1.3),
  UkuranUji('392', 392, 852, 1.0),
  UkuranUji('392', 392, 852, 1.0, gelap: true),
];

/// Tinggi papan ketik yang digambar (dp), dan bilah status/gestur.
const _tinggiPapan = 280.0;

const _kertasTanpaSeri = IdentitasKertas(
  namaAlat: 'pH Meter',
  merk: 'Mettler',
  pemilik: 'PT Tirta Contoh Mandiri',
);

const _ptMirip = [
  CustomerLookup(
    id: 3,
    nama: 'PT Tirta Contoh Abadi',
    alamat: 'Jl. Contoh Primer A-12',
  ),
  CustomerLookup(id: 4, nama: 'PT Tirta Contoh Makmur'),
];

void main() {
  pasangSimpananTiruan();

  final folder = Platform.environment['SIDIK_PNG_DIR'];
  final hanya = Platform.environment['SIDIK_KEADAAN'];
  final lewati = folder == null ? 'PNG hanya bila SIDIK_PNG_DIR diisi' : null;
  if (folder != null) Directory(folder).createSync(recursive: true);

  setUpAll(() async {
    await muatFontUji();
    await initializeDateFormatting('id');
  });

  Future<void> potret(
    WidgetTester tester,
    GlobalKey kunci,
    UkuranUji u,
    String nama,
  ) async {
    if (folder == null) return;
    final batas = tester.renderObject<RenderRepaintBoundary>(find.byKey(kunci));
    await tester.runAsync(() async {
      final gambar = await batas.toImage(pixelRatio: 2.0);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$folder/$nama.${u.nama}.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  void aturLayar(WidgetTester tester, UkuranUji u, {bool papan = false}) {
    tester.view.physicalSize = Size(u.lebar * 2, u.tinggi * 2);
    tester.view.devicePixelRatio = 2.0;
    // Bilah status 24 dp di atas, bilah gestur 16 dp di bawah (hilang di bawah
    // papan ketik): sama dengan pengukur tinggi (`ukur_jatah_alat_baru_test`).
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 32);
    tester.view.padding = FakeViewPadding(top: 48, bottom: papan ? 0 : 32);
    tester.view.viewInsets = FakeViewPadding(
      bottom: papan ? _tinggiPapan * 2 : 0,
    );
    addTearDown(tester.view.reset);
  }

  Future<void> bukaPanel(WidgetTester tester) async {
    // Layar sempit: kartu ringkas -> ketuk -> lembar bawah. Layar lega: panel
    // sudah inline.
    final buka = find.byKey(BlokIdentitasFoto.kunciBukaAlatBaru);
    if (buka.evaluate().isEmpty) return;
    await tester.ensureVisible(buka);
    await tester.pump();
    await tester.tap(buka);
    await tenangUji(tester);
  }

  Future<void> ketuk(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tenangUji(tester);
  }

  /// Satu keadaan pada semua ukuran. [aksi] mulai dari lembar yang baru terbuka
  /// dan blok sudah selesai mencocokkan.
  void keadaan(
    String nama, {
    required DuniaLembarFoto Function() dunia,
    IdentitasKertas identitas = kertasUji,
    Future<void> Function(WidgetTester tester, DuniaLembarFoto d, UkuranUji u)?
    aksi,
    bool papan = false,
    bool snack = false,
  }) {
    if (hanya != null && hanya != nama) return;
    for (final u in _ukuran) {
      testWidgets('$nama - ${u.nama}', (tester) async {
        if (folder != null) debugDisableShadows = false;
        final galatAsli = FlutterError.onError;
        // Papan ketik 280 dp di layar 640 dp tidak menyisakan tempat bagi kerangka
        // lembar beku di BELAKANG lembar bawah (legenda, banner, bilah kirim):
        // `LembarKerjaScreen` meluap. Itu sudah begitu sebelum paket ini (angka di
        // `ukur_jatah_alat_baru_test`; jatah blok 0 dp) dan bukan bagian lembar
        // bawah; hanya keadaan berpapan ketik yang menoleransinya.
        if (papan) {
          FlutterError.onError = (d) {
            if (d.exceptionAsString().contains('RenderFlex overflowed')) return;
            galatAsli?.call(d);
          };
        }
        try {
          aturLayar(tester, u);
          final d = dunia();
          final kunci = GlobalKey();
          await tester.pumpWidget(
            appUji(
              home: BekuLembarKerja(
                child: LembarKerjaScreen(
                  profil: 'ph_meter',
                  judulTambahan: 'pH Meter',
                  dariFoto: bekalFotoUji(identitas),
                ),
              ),
              dunia: d,
              u: u,
              kunci: kunci,
              papanKetik: papan ? _tinggiPapan : 0,
            ),
          );
          await tungguUji(tester, () => d.mesin!.dipanggil > 0, maks: 80);
          await tungguUji(
            tester,
            () => find.byKey(BlokIdentitasFoto.kunci).evaluate().isNotEmpty,
            maks: 30,
          );
          await tenangUji(tester);
          await bersihkanSnackUji(tester);
          if (aksi != null) await aksi(tester, d, u);
          if (!snack) await bersihkanSnackUji(tester);
          await tester.pump(const Duration(milliseconds: 400));
          await potret(tester, kunci, u, nama);
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = galatAsli;
          debugDisableShadows = true;
        }
      }, skip: lewati != null);
    }
  }

  DuniaLembarFoto baru({PtUji? pt}) =>
      DuniaLembarFoto(pt: pt, mesin: MesinBacaUji());

  // 1. Hasil pencocokan "alat baru": layar sempit = kartu ringkas, lega = panel.
  keadaan('01-alat-baru-awal', dunia: baru);

  // 2. Panel terbuka (layar sempit: lembar bawah).
  keadaan('02-panel-terbuka', dunia: baru, aksi: (t, d, u) => bukaPanel(t));

  // 3. Mengetik: papan ketik terbuka, satu kotak difokuskan dan diisi.
  keadaan(
    '03-mengetik',
    dunia: baru,
    papan: true,
    aksi: (tester, d, u) async {
      await bukaPanel(tester);
      // Papan ketik muncul SESUDAH lembar terbuka (kotak diketuk).
      aturLayar(tester, u, papan: true);
      await tenangUji(tester);
      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakModel),
        'Five Easy Plus',
      );
      await tester.pump();
      await tenangUji(tester);
    },
  );

  // 4. Seri kosong: kotak seri bertanda wajib + pesan; tidak membuat.
  keadaan(
    '04-seri-kosong',
    dunia: baru,
    identitas: _kertasTanpaSeri,
    aksi: (tester, d, u) async {
      await bukaPanel(tester);
      await ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
    },
  );

  // 5. PT mirip: pilih yang ada atau "Tetap buat PT baru".
  keadaan(
    '05-pt-mirip',
    dunia: () => baru(pt: PtUji(mirip: _ptMirip)),
    aksi: (tester, d, u) async {
      await bukaPanel(tester);
      await ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
    },
  );

  // 6. Galat server saat membuat: pesan jujur; "Buat dan lanjut" = coba lagi.
  keadaan(
    '06-galat-server',
    dunia: baru,
    aksi: (tester, d, u) async {
      d.layanan.sebelumSimpan = (_) async => throw Exception('putus');
      await bukaPanel(tester);
      await ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
    },
  );

  // 7. Memuat: server belum menjawab (tombol "Membuat...", kotak terkunci).
  if (hanya == null || hanya == '07-memuat') {
    for (final u in _ukuran) {
      testWidgets('07-memuat - ${u.nama}', (tester) async {
        if (folder != null) debugDisableShadows = false;
        try {
          aturLayar(tester, u);
          final d = baru();
          final tahan = Completer<void>();
          d.layanan.sebelumSimpan = (_) => tahan.future;
          final kunci = GlobalKey();
          await tester.pumpWidget(
            appUji(
              home: BekuLembarKerja(
                child: LembarKerjaScreen(
                  profil: 'ph_meter',
                  judulTambahan: 'pH Meter',
                  dariFoto: bekalFotoUji(kertasUji),
                ),
              ),
              dunia: d,
              u: u,
              kunci: kunci,
            ),
          );
          await tungguUji(tester, () => d.mesin!.dipanggil > 0, maks: 80);
          await tungguUji(
            tester,
            () => find.byKey(BlokIdentitasFoto.kunci).evaluate().isNotEmpty,
            maks: 30,
          );
          await tenangUji(tester);
          await bersihkanSnackUji(tester);
          await bukaPanel(tester);
          final tombol = find.byKey(BlokIdentitasFoto.kunciBuatLanjut);
          await tester.ensureVisible(tombol);
          await tester.pump();
          await tester.tap(tombol);
          // Spinner berputar terus: jangan menunggu tenang.
          await tester.pump(const Duration(milliseconds: 600));
          await bersihkanSnackUji(tester);
          await tester.pump(const Duration(milliseconds: 300));
          await potret(tester, kunci, u, '07-memuat');
          expect(tester.takeException(), isNull);
          tahan.complete();
          await tenangUji(tester);
        } finally {
          debugDisableShadows = true;
        }
      }, skip: lewati != null);
    }
  }

  // 8. Berhasil: lembar bawah menutup, alat terpasang, lembar terisi.
  keadaan(
    '08-berhasil',
    dunia: baru,
    snack: true,
    aksi: (tester, d, u) async {
      await bukaPanel(tester);
      await ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
    },
  );
}
