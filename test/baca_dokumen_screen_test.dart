import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/skema_dinamis.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dokumen_generik_provider.dart';
import 'package:sidik_calibration/screens/dokumen/baca_dokumen_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/dokumen_generik_service.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/widgets/dinamis/sorot_kotak_foto.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Alur layar: tekan tombol foto -> kamera -> layanan -> form yang bentuknya
/// ngikutin lembar -> teknisi mengoreksi.
///
/// ## Kenapa dipalsukan di lapisan LAYANAN, bukan HTTP
///
/// `ApiClient.unggahFile` memanggil `MultipartFile.fromPath` — baca berkas
/// asinkron SUNGGUHAN. Di `testWidgets`, I/O sungguhan nggak digerakkan jam
/// palsu milik framework: requestnya nggak pernah berangkat dan layarnya
/// mandek di "lagi membaca" selamanya. Itu batas harness-nya, bukan bug
/// aplikasinya.
///
/// Jalur HTTP + unggah berkasnya sudah diuji sungguhan di
/// `dokumen_generik_service_test.dart` — uji biasa, bukan widget test, jadi
/// I/O aslinya jalan. Yang diuji DI SINI mesin keadaan layarnya dan apa yang
/// digambar, termasuk kapan tombol "foto ulang" boleh muncul.
class _LayananPalsu extends DokumenGenerikService {
  // ApiClient-nya nggak pernah kepakai: `baca` di-override total.
  _LayananPalsu(this._jawab) : super(ApiClient());

  final HasilBacaDokumen Function() _jawab;

  int dipanggil = 0;
  String? namaAlatTerakhir;

  int? bacaanIdKoreksi;
  Map<String, String>? koreksiTerkirim;
  HasilKirimKoreksi jawabKoreksi = const HasilKirimKoreksi.berhasil(
    cocok: 1,
    meleset: 1,
    kunciTidakDikenal: [],
  );

  @override
  Future<HasilKirimKoreksi> koreksi({
    required int bacaanId,
    required Map<String, String> nilai,
    String? token,
  }) async {
    bacaanIdKoreksi = bacaanId;
    koreksiTerkirim = Map.of(nilai);
    return jawabKoreksi;
  }

  @override
  Future<HasilBacaDokumen> baca({
    required File foto,
    String? namaAlat,
    String? token,
  }) async {
    dipanggil++;
    namaAlatTerakhir = namaAlat;
    return _jawab();
  }
}

/// `SecureTokenStorage` asli nembak Keychain lewat platform channel yang
/// nggak pernah nyaut di widget test — dan `fotoLaluBaca` nunggu tokennya
/// SEBELUM manggil layanan, jadi tanpa ini layarnya mandek di "lagi membaca".
class _TokenPalsu implements TokenStorage {
  @override
  Future<String?> read() async => 'token-uji';

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

class _FotoPalsu implements SumberFoto {
  _FotoPalsu(this.berkas);

  final File? berkas;
  int dipanggil = 0;

  @override
  Future<File?> ambil({int? maxWidth, int? imageQuality}) async {
    dipanggil++;
    return berkas;
  }
}

SkemaDinamis _skemaViscometer() => SkemaDinamis.fromJson({
  'dokumen': {
    'title': 'Calibration Worksheet - Viscometer Rotasi',
    'equipment_name': 'Viscometer Rotasi',
    'worksheet_code': 'SIDIK-FM-CAL-0999',
    'revision': 'Rev.2',
  },
  'bagian': [
    {
      'kunci': 'bagian-0',
      'nama': 'Spindle Measurement',
      'field': [
        {
          'kunci': 'bagian-0.field-0',
          'label': 'Spindle No',
          'tipe': 'text',
          'nilai': 'S-62',
          'status': 'OK',
          'sumber': 'handwriting',
          'bisa_diisi': true,
        },
      ],
      'tabel': [
        {
          'kunci': 'bagian-0.tabel-0',
          'kolom': [
            {'kunci': 'k0', 'judul': 'RPM', 'tipe': 'number'},
            {'kunci': 'k1', 'judul': 'Reading', 'tipe': 'number'},
          ],
          'baris': [
            [
              {
                'kunci': 'bagian-0.tabel-0.sel-0-0',
                'baris': 0,
                'kolom': 0,
                'nilai': '10',
                'status': 'OK',
                'sumber': 'static_document',
              },
              {
                'kunci': 'bagian-0.tabel-0.sel-0-1',
                'baris': 0,
                'kolom': 1,
                'nilai': '99',
                'status': 'REVIEW_REQUIRED',
                'sumber': 'handwriting',
                'keyakinan': 0.42,
                'bbox': {'x': 100, 'y': 200, 'width': 60, 'height': 24},
              },
            ],
          ],
        },
      ],
    },
  ],
  'peringatan': const [],
  'ringkasan': {'jumlah_field': 1, 'jumlah_sel': 2, 'perlu_review': 1},
});

void main() {
  late File foto;

  setUp(() {
    foto = File('${Directory.systemTemp.path}/lembar-layar-uji.jpg')
      ..writeAsBytesSync(List<int>.filled(32, 3));
  });

  tearDown(() {
    if (foto.existsSync()) foto.deleteSync();
  });

  Widget bungkus({required SumberFoto sumber, required _LayananPalsu layanan}) {
    return ProviderScope(
      overrides: [
        sumberFotoDokumenProvider.overrideWithValue(sumber),
        dokumenGenerikServiceProvider.overrideWithValue(layanan),
        tokenStorageProvider.overrideWithValue(_TokenPalsu()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: const BacaDokumenScreen(),
      ),
    );
  }

  testWidgets('foto -> form yang ngikutin lembar, lalu bisa dikoreksi', (
    t,
  ) async {
    final sumber = _FotoPalsu(foto);
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: sumber, layanan: layanan));

    // Awalnya cuma ajakan foto — belum ada form.
    expect(find.text('Foto lembar'), findsOneWidget);
    expect(find.text('Spindle Measurement'), findsNothing);

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(sumber.dipanggil, 1, reason: 'kameranya beneran dibuka');
    expect(layanan.dipanggil, 1);

    // Form-nya lahir dari jawaban layanan, bukan dari daftar tetap.
    expect(find.text('Spindle Measurement'), findsOneWidget);
    expect(find.text('SIDIK-FM-CAL-0999 · Rev.2'), findsOneWidget);
    expect(find.text('RPM'), findsOneWidget);
    expect(find.text('S-62'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);

    // Teknisi mengoreksi sel yang keyakinannya rendah.
    await t.enterText(find.widgetWithText(TextFormField, '99'), '99,4');
    await t.pump();

    expect(find.text('99,4'), findsOneWidget);
  });

  testWidgets('nama alat diteruskan sebagai konteks', (t) async {
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));

    await t.enterText(find.byType(TextField).first, 'pH Meter');
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(layanan.namaAlatTerakhir, 'pH Meter');
  });

  testWidgets('batal ambil foto BUKAN error — nggak ada pesan gagal', (
    t,
  ) async {
    final sumber = _FotoPalsu(null);
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: sumber, layanan: layanan));

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(sumber.dipanggil, 1);
    expect(
      layanan.dipanggil,
      0,
      reason: 'nggak ada foto, nggak ada yang dibaca',
    );
    // Tetap di layar ajakan, tanpa pesan gagal apa pun.
    expect(find.text('Foto lembar'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('jalur ditutup lab: TIDAK ditawari foto ulang', (t) async {
    await t.pumpWidget(
      bungkus(
        sumber: _FotoPalsu(foto),
        layanan: _LayananPalsu(
          () => const HasilBacaDokumen.gagal(
            GagalBacaDokumen.dimatikan,
            'Baca dokumen dimatikan di server (`VISION_AKTIF=false`).',
          ),
        ),
      ),
    );

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(find.textContaining('dimatikan di server'), findsOneWidget);
    expect(
      find.text('Foto ulang'),
      findsNothing,
      reason: 'foto ulang nggak bakal nolong kalau jalurnya ditutup lab',
    );
    expect(find.text('Mulai lagi'), findsOneWidget);
  });

  testWidgets('layanan sibuk: TIDAK ditawari foto ulang', (t) async {
    await t.pumpWidget(
      bungkus(
        sumber: _FotoPalsu(foto),
        layanan: _LayananPalsu(
          () => const HasilBacaDokumen.gagal(
            GagalBacaDokumen.layananBermasalah,
            'Layanan AI lagi sibuk. Tunggu beberapa menit lalu coba lagi — '
            'fotonya nggak perlu diulang.',
          ),
        ),
      ),
    );

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(find.textContaining('nggak perlu diulang'), findsOneWidget);
    expect(
      find.text('Foto ulang'),
      findsNothing,
      reason: 'motret ulang mustahil nolong sampai beban penyedianya turun',
    );
  });

  testWidgets('kunci API kosong: urusan admin, bukan disuruh foto ulang', (
    t,
  ) async {
    await t.pumpWidget(
      bungkus(
        sumber: _FotoPalsu(foto),
        layanan: _LayananPalsu(
          () => const HasilBacaDokumen.gagal(
            GagalBacaDokumen.salahSetup,
            'ANTHROPIC_API_KEY belum diisi di server.',
          ),
        ),
      ),
    );

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(find.text('Foto ulang'), findsNothing);
  });

  testWidgets('foto buram: DITAWARI foto ulang', (t) async {
    await t.pumpWidget(
      bungkus(
        sumber: _FotoPalsu(foto),
        layanan: _LayananPalsu(
          () => const HasilBacaDokumen.gagal(
            GagalBacaDokumen.takTerbaca,
            'Lembarnya nggak kebaca.',
          ),
        ),
      ),
    );

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(find.text('Foto ulang'), findsOneWidget);
  });

  testWidgets('koreksi lembar lama nggak nempel ke lembar berikutnya', (
    t,
  ) async {
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextFormField, '99'), '77,7');
    await t.pump();
    expect(find.text('77,7'), findsOneWidget);

    // Foto lembar BERIKUTNYA: kuncinya sama persis (posisi yang sama), jadi
    // koreksi lama bakal nempel kalau nggak dibersihkan.
    await t.tap(find.text('Spindle Measurement'));
    await t.pump();

    final layar = t.state<ConsumerState>(find.byType(BacaDokumenScreen));
    layar.ref.read(bacaDokumenProvider.notifier).ulangDariAwal();
    await t.pumpAndSettle();

    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(find.text('99'), findsOneWidget, reason: 'balik ke hasil baca');
    expect(find.text('77,7'), findsNothing);
  });

  testWidgets('tombol simpan mati sebelum ada yang dikoreksi', (t) async {
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    expect(find.text('Belum ada yang dikoreksi'), findsOneWidget);

    final tombol = t.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(
      tombol.onPressed,
      isNull,
      reason: 'ngirim peta kosong bakal nandain lembar sudah dikoreksi',
    );
  });

  testWidgets('simpan mengirim persis yang diketik teknisi', (t) async {
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextFormField, '99'), '99,4');
    await t.pumpAndSettle();

    await t.tap(find.text('Simpan koreksi'));
    await t.pumpAndSettle();

    expect(layanan.bacaanIdKoreksi, 42);
    expect(layanan.koreksiTerkirim, {'bagian-0.tabel-0.sel-0-1': '99,4'});
    // Yang NGGAK disentuh teknisi nggak ikut terkirim.
    expect(layanan.koreksiTerkirim!.containsKey('bagian-0.field-0'), isFalse);

    expect(find.text('2 koreksi tersimpan'), findsOneWidget);
  });

  testWidgets('gagal simpan dikabarkan, bukan didiamkan', (t) async {
    final layanan =
        _LayananPalsu(() => HasilBacaDokumen.berhasil(_skemaViscometer(), 42))
          ..jawabKoreksi = const HasilKirimKoreksi.gagal(
            'Nggak bisa nyambung ke server. Koreksinya belum tersimpan.',
          );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextFormField, '99'), '99,4');
    await t.pumpAndSettle();

    await t.tap(find.text('Simpan koreksi'));
    await t.pumpAndSettle();

    // Teknisi HARUS tahu koreksinya belum mendarat — didiamkan, dia ninggalin
    // layar percaya sudah tersimpan.
    expect(find.textContaining('belum tersimpan'), findsOneWidget);
  });

  testWidgets('foto aslinya ikut tampil di layar review', (t) async {
    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    // Foto DAN data di layar yang sama — kalau teknisi harus pindah layar buat
    // lihat coretan aslinya, dia bakal berhenti membandingkan.
    expect(find.byType(SorotKotakFoto), findsOneWidget);
    expect(find.text('Spindle Measurement'), findsOneWidget);
    expect(
      find.text('Ketuk nilainya buat lihat asalnya di foto'),
      findsOneWidget,
    );
  });

  testWidgets('ketuk sel bertkotak -> kotaknya diteruskan ke penyorot', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    final sel = find.widgetWithText(TextFormField, '99');
    await t.ensureVisible(sel);
    await t.pumpAndSettle();
    await t.tap(sel);
    await t.pumpAndSettle();

    final sorot = t.widget<SorotKotakFoto>(find.byType(SorotKotakFoto));

    expect(sorot.kotak, isNotNull);
    expect(sorot.kotak!.x, 100);
    expect(sorot.kotak!.y, 200);
    // Ajakan awalnya ilang begitu ada yang disorot.
    expect(
      find.text('Ketuk nilainya buat lihat asalnya di foto'),
      findsNothing,
    );
  });

  testWidgets('nilai tanpa kotak asal: dikasih tau, bukan didiamkan', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final layanan = _LayananPalsu(
      () => HasilBacaDokumen.berhasil(_skemaViscometer(), 42),
    );

    await t.pumpWidget(bungkus(sumber: _FotoPalsu(foto), layanan: layanan));
    await t.tap(find.text('Foto lembar'));
    await t.pumpAndSettle();

    // Sel kolom 0 sengaja nggak punya bbox di fixture.
    final sel = find.widgetWithText(TextFormField, '10');
    await t.ensureVisible(sel);
    await t.pumpAndSettle();
    await t.tap(sel);
    await t.pumpAndSettle();

    // Diketuk lalu nggak kelihatan apa-apa bikin teknisi ngira layarnya rusak.
    expect(
      find.text("Asal nilai ini nggak bisa ditunjuk di foto"),
      findsOneWidget,
    );
  });
}
