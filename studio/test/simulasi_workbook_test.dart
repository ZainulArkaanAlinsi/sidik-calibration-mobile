import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pendaftaran_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/data/simulasi_provider.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/inti/penimpaan.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

/// Keadaan simulasi (Tahap C): edit terkumpul, SEMUA edit dikirim tiap
/// hitung, jawaban lama dibuang, urung/ulang, reset, galat. Layanan =
/// `MockWorkbookService` (menggemakan edit, TIDAK menghitung) atau jawaban
/// sintetis per test — yang diuji alurnya, bukan angkanya.
///
/// `testWidgets` dipakai demi jam palsu (jeda kirim [jedaKirimHitung]).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const wb = MockWorkbookService.idMicrometer;
  const u95 = MockWorkbookService.idLembarU95;
  final k6 = kunciEdit(u95, AlamatSel.urai('K6')!);
  final q6 = kunciEdit(u95, AlamatSel.urai('Q6')!);

  ProviderContainer wadah(MockWorkbookService mock, {AuthService? auth}) {
    final c = ProviderContainer(
      overrides: [
        ...penimpaanStudio,
        pendaftaranPushServiceProvider.overrideWithValue(MockPendaftaranPush()),
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(
          auth ?? MockAuthService(jeda: Duration.zero),
        ),
        workbookServiceProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(c.dispose);
    // Akun & layar workbook yang menahannya hidup.
    c.listen(authProvider, (_, _) {});
    c.listen(simulasiWorkbookProvider(wb), (_, _) {});
    return c;
  }

  /// Lewati jeda kirim DAN jarak minimum antar-kiriman — kiriman yang
  /// antre ikut berangkat, tidak ada timer tersisa.
  Future<void> lewatiJeda(WidgetTester tester) async {
    await tester.pump(
      jedaKirimHitung + jarakMinKirimHitung + const Duration(milliseconds: 20),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  /// Tunggu [f] sambil memutar jam palsu (layanan tiruan menunda lewat
  /// timer nol).
  Future<T> tunggu<T>(WidgetTester tester, Future<T> f) async {
    var selesai = false;
    f.whenComplete(() => selesai = true).ignore();
    for (var i = 0; i < 100 && !selesai; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return f;
  }

  /// Wadah dengan akun SUDAH terbaca — seperti saat layar workbook dibuka.
  /// (Simulasi ikut akun: akun yang baru terbaca = simulasi baru.)
  Future<ProviderContainer> siap(
    WidgetTester tester,
    MockWorkbookService mock,
  ) async {
    final c = wadah(mock);
    await tunggu(tester, c.read(authProvider.future));
    return c;
  }

  SimulasiWorkbook sim(ProviderContainer c) =>
      c.read(simulasiWorkbookProvider(wb).notifier);
  KeadaanSimulasi keadaan(ProviderContainer c) =>
      c.read(simulasiWorkbookProvider(wb));
  List<String> isiKiriman(List<EditSel> e) => [
    for (final x in e) '${x.lembarId}!${x.alamat.a1}=${x.isi}',
  ];

  testWidgets('edit → menghitung → SEMUA edit dikirim → hasil server jadi '
      'overlay; sebelum dijawab sel tampil sementara (abu)', (tester) async {
    final mock = MockWorkbookService();
    final c = await siap(tester, mock);

    expect(sim(c).terapkan({k6: '0.2'}), isTrue);
    var s = keadaan(c);
    expect(s.menghitung, isTrue);
    expect(s.adaEdit, isTrue);
    expect(mock.panggilanHitung, isEmpty); // masih dalam jeda kirim
    final sementara = s.overlayUntuk(u95).selGrid(6, 11, SelGrid.kosong);
    expect(sementara!.teks, '0.2');
    expect(sementara.warnaTeks, warnaTeksSementara);

    await lewatiJeda(tester);
    s = keadaan(c);
    expect(s.menghitung, isFalse);
    expect(isiKiriman(mock.panggilanHitung.single), ['11!K6=0.2']);
    // Gema mock: format sel asal `0.000` ikut.
    final hasil = s.overlayUntuk(u95).pada(6, 11)!;
    expect(hasil.nilai, 0.2);
    expect(hasil.teks, '0.200');
    expect(s.overlayUntuk(u95).sementara, isEmpty);

    sim(c).terapkan({q6: '150'});
    await lewatiJeda(tester);
    expect(isiKiriman(mock.panggilanHitung.last), ['11!K6=0.2', '11!Q6=150']);
  });

  testWidgets('urungkan menghapus edit terakhir & menghitung ulang sisanya; '
      'ulangi mengembalikannya; edit baru membuang riwayat ulang; isi sama '
      '= bukan langkah baru', (tester) async {
    final mock = MockWorkbookService();
    final c = await siap(tester, mock);
    sim(c).terapkan({k6: '0.2'});
    sim(c).terapkan({q6: '150'});
    await lewatiJeda(tester);
    // Dua edit dalam satu jeda = SATU kiriman.
    expect(mock.panggilanHitung, hasLength(1));

    sim(c).urungkan();
    expect(keadaan(c).edit.keys, [k6]);
    expect(keadaan(c).bisaUlangi, isTrue);
    // Q6 diurungkan: sementara = sel snapshot sampai server menjawab.
    expect(keadaan(c).overlayUntuk(u95).pada(6, 17), isNull);
    await lewatiJeda(tester);
    expect(isiKiriman(mock.panggilanHitung.last), ['11!K6=0.2']);

    sim(c).ulangi();
    expect(keadaan(c).edit.keys, [k6, q6]);
    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(3));

    sim(c).urungkan();
    sim(c).terapkan({k6: '0.3'});
    expect(keadaan(c).bisaUlangi, isFalse);
    expect(keadaan(c).edit, {k6: '0.3'});

    final sebelum = keadaan(c);
    expect(sim(c).terapkan({k6: '0.3'}), isTrue);
    expect(identical(keadaan(c), sebelum), isTrue);

    // Urungkan sampai habis: tanpa edit = tanpa kiriman, overlay kosong.
    sim(c)
      ..urungkan()
      ..urungkan();
    await lewatiJeda(tester);
    expect(keadaan(c).adaEdit, isFalse);
    expect(keadaan(c).overlay, isEmpty);
    expect(keadaan(c).menghitung, isFalse);
    expect(mock.panggilanHitung, hasLength(3));
  });

  testWidgets('request lama dibatalkan: jawabannya yang tiba belakangan TIDAK '
      'menimpa hasil edit yang lebih baru', (tester) async {
    final antre = <Completer<Map<String, Object?>>>[];
    Map<String, Object?> jawab(String s) => {
      'data': {
        'lembar': [
          {
            'lembar_id': u95,
            'sel': [
              {'a': 'K6', 't': 'n', 'n': 0, 's': s},
            ],
          },
        ],
        'galat': <Object>[],
      },
    };
    final mock = MockWorkbookService(
      jawabanHitung: (_, _) {
        final c = Completer<Map<String, Object?>>();
        antre.add(c);
        return c.future;
      },
    );
    final c = await siap(tester, mock);

    sim(c).terapkan({k6: '1'});
    await lewatiJeda(tester);
    sim(c).terapkan({k6: '2'});
    await lewatiJeda(tester);
    expect(antre, hasLength(2));

    // Jawaban LAMA tiba dulu: dibuang, masih menghitung.
    antre[0].complete(jawab('lama'));
    await lewatiJeda(tester);
    expect(keadaan(c).menghitung, isTrue);
    expect(keadaan(c).overlayUntuk(u95).sel, isEmpty);

    antre[1].complete(jawab('baru'));
    await lewatiJeda(tester);
    expect(keadaan(c).menghitung, isFalse);
    expect(keadaan(c).overlayUntuk(u95).pada(6, 11)!.teks, 'baru');

    // Urutan terbalik: yang baru dulu, yang lama menyusul — tetap yang baru.
    sim(c).terapkan({k6: '3'});
    await lewatiJeda(tester);
    sim(c).terapkan({k6: '4'});
    await lewatiJeda(tester);
    antre[3].complete(jawab('empat'));
    await lewatiJeda(tester);
    antre[2].complete(jawab('tiga'));
    await lewatiJeda(tester);
    expect(keadaan(c).overlayUntuk(u95).pada(6, 11)!.teks, 'empat');
  });

  testWidgets('reset: semua edit, riwayat & overlay hilang tanpa kiriman; '
      'jawaban yang masih di jalan dibuang', (tester) async {
    final tunda = Completer<Map<String, Object?>>();
    final mock = MockWorkbookService(jawabanHitung: (_, _) => tunda.future);
    final c = await siap(tester, mock);
    sim(c).terapkan({k6: '0.2'});
    await lewatiJeda(tester);
    sim(c).reset();
    expect(keadaan(c).adaEdit, isFalse);
    expect(keadaan(c).bisaUrungkan, isFalse);
    expect(keadaan(c).menghitung, isFalse);
    tunda.complete({
      'data': {
        'lembar': [
          {
            'lembar_id': u95,
            'sel': [
              {'a': 'K6', 't': 'n', 'n': 0.2, 's': '0.200'},
            ],
          },
        ],
      },
    });
    await lewatiJeda(tester);
    expect(keadaan(c).overlay, isEmpty);
    expect(mock.panggilanHitung, hasLength(1));
  });

  testWidgets('galat 422/504: dicatat, edit & overlay sebelumnya tetap, '
      'sel yang belum terjawab tetap sementara; urungkan = batalkan edit '
      'terakhir; hitung ulang mengirim lagi', (tester) async {
    var gagal = 0;
    final mock = MockWorkbookService();
    mock.jawabanHitung = (_, edit) async {
      if (gagal == 422) {
        throw ApiException(
          'Data tidak valid.',
          status: 422,
          body: {
            'message': 'Data tidak valid.',
            'errors': {
              'edit.1.isi': ['Fungsi INDIRECT tidak diizinkan.'],
            },
          },
        );
      }
      if (gagal == 504) {
        throw ApiException(
          'Hitung terlalu lama.',
          status: 504,
          body: {'kode': 'hitung_terlalu_lama'},
        );
      }
      return {
        'data': {
          'lembar': [
            {
              'lembar_id': u95,
              'sel': [
                {'a': 'K6', 't': 'n', 'n': 0.2, 's': '0.200'},
              ],
            },
          ],
        },
      };
    };
    final c = await siap(tester, mock);
    sim(c).terapkan({k6: '0.2'});
    await lewatiJeda(tester);

    gagal = 422;
    sim(c).terapkan({q6: '=INDIRECT("A1")'});
    await lewatiJeda(tester);
    var s = keadaan(c);
    expect(s.galat!.jenis, JenisGalatSimulasi.ditolak);
    expect(s.galat!.pesan, 'Fungsi INDIRECT tidak diizinkan.');
    expect(s.galat!.bisaDiulang, isFalse);
    expect(s.overlayUntuk(u95).pada(6, 11)!.teks, '0.200');
    expect(s.overlayUntuk(u95).sementara.keys, [kunciSel(6, 17)]);

    gagal = 0;
    sim(c).urungkan();
    await lewatiJeda(tester);
    s = keadaan(c);
    expect(s.galat, isNull);
    expect(s.edit, {k6: '0.2'});

    gagal = 504;
    sim(c).terapkan({q6: '9'});
    await lewatiJeda(tester);
    expect(keadaan(c).galat!.jenis, JenisGalatSimulasi.terlaluLama);
    expect(keadaan(c).galat!.bisaDiulang, isTrue);
    final jumlah = mock.panggilanHitung.length;
    gagal = 0;
    sim(c).hitungUlang();
    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(jumlah + 1));
    expect(keadaan(c).galat, isNull);
  });

  testWidgets('workbook CSV → 409 berkas asli tidak ada (mock seperti '
      'server)', (tester) async {
    final mock = MockWorkbookService();
    final c = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        workbookServiceProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(c.dispose);
    const csv = MockWorkbookService.idMicrometerCsv;
    c.listen(authProvider, (_, _) {});
    await tunggu(tester, c.read(authProvider.future));
    c.listen(simulasiWorkbookProvider(csv), (_, _) {});
    c.read(simulasiWorkbookProvider(csv).notifier).terapkan({
      kunciEdit(MockWorkbookService.idLembarU95Csv, AlamatSel.urai('K6')!): '1',
    });
    await lewatiJeda(tester);
    expect(
      c.read(simulasiWorkbookProvider(csv)).galat!.jenis,
      JenisGalatSimulasi.berkasAsliTidakAda,
    );
  });

  testWidgets('jarak minimum antar-kiriman (jatah server 30/menit): edit '
      'yang lebih rapat menunggu lalu dikirim SEKALI dengan edit terbaru', (
    tester,
  ) async {
    final mock = MockWorkbookService();
    final c = await siap(tester, mock);
    const lewatJeda = Duration(milliseconds: 20);

    sim(c).terapkan({k6: '1'});
    await tester.pump(jedaKirimHitung + lewatJeda);
    await tester.pump();
    expect(mock.panggilanHitung, hasLength(1));

    // Edit kedua & ketiga masih di dalam jarak kiriman pertama: jedanya
    // lewat, tapi tidak ada yang berangkat.
    sim(c).terapkan({k6: '2'});
    await tester.pump(jedaKirimHitung + lewatJeda);
    sim(c).terapkan({q6: '3'});
    await tester.pump(jedaKirimHitung + lewatJeda);
    expect(mock.panggilanHitung, hasLength(1));
    expect(keadaan(c).menghitung, isTrue);

    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(2));
    expect(isiKiriman(mock.panggilanHitung.last), ['11!K6=2', '11!Q6=3']);
    expect(keadaan(c).menghitung, isFalse);
    // Jarak kiriman kedua habis tanpa kiriman baru.
    await tester.pump(jarakMinKirimHitung);
    expect(mock.panggilanHitung, hasLength(2));
  });

  testWidgets('429: edit berikutnya TIDAK dikirim otomatis (tetap sementara, '
      'galat tetap tampil); "Coba lagi" mengirim sekali & melepas tahanan; '
      'tanpa edit = tahanan lepas', (tester) async {
    var tolak = true;
    final mock = MockWorkbookService();
    mock.jawabanHitung = (_, _) async {
      if (tolak) {
        throw ApiException(
          'Kebanyakan percobaan. Tunggu sebentar, terus coba lagi.',
          status: 429,
          body: {
            'message':
                'Kebanyakan percobaan. Tunggu sebentar, terus coba lagi.',
          },
        );
      }
      return {
        'data': {
          'lembar': [
            {
              'lembar_id': u95,
              'sel': [
                {'a': 'K6', 't': 'n', 'n': 1, 's': '1.000'},
              ],
            },
          ],
        },
      };
    };
    final c = await siap(tester, mock);

    sim(c).terapkan({k6: '1'});
    await lewatiJeda(tester);
    expect(keadaan(c).galat!.jenis, JenisGalatSimulasi.terlaluSering);
    expect(keadaan(c).galat!.bisaDiulang, isTrue);
    expect(mock.panggilanHitung, hasLength(1));

    sim(c).terapkan({q6: '2'});
    await lewatiJeda(tester);
    var s = keadaan(c);
    expect(mock.panggilanHitung, hasLength(1));
    expect(s.menghitung, isFalse);
    expect(s.galat!.jenis, JenisGalatSimulasi.terlaluSering);
    expect(
      s.overlayUntuk(u95).sementara.keys,
      unorderedEquals([kunciSel(6, 11), kunciSel(6, 17)]),
    );

    tolak = false;
    sim(c).hitungUlang();
    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(2));
    expect(isiKiriman(mock.panggilanHitung.last), ['11!K6=1', '11!Q6=2']);
    expect(keadaan(c).galat, isNull);

    // Tahanan lepas: edit berikutnya otomatis lagi.
    sim(c).terapkan({k6: '5'});
    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(3));

    // Ditahan lagi, lalu semua edit dibuang: edit baru dikirim biasa.
    tolak = true;
    sim(c).terapkan({k6: '6'});
    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(4));
    sim(c).reset();
    tolak = false;
    sim(c).terapkan({k6: '7'});
    await lewatiJeda(tester);
    expect(mock.panggilanHitung, hasLength(5));
    expect(keadaan(c).galat, isNull);
  });

  testWidgets('batas $batasEditSimulasi edit: yang melewatinya DITOLAK utuh, '
      'tanpa perubahan & tanpa kiriman', (tester) async {
    final mock = MockWorkbookService();
    final c = await siap(tester, mock);
    final banyak = {
      for (var b = 1; b <= batasEditSimulasi; b++)
        kunciEdit(u95, AlamatSel(b, 40)): '$b',
    };
    expect(sim(c).terapkan(banyak), isTrue);
    expect(
      sim(c).terapkan({kunciEdit(u95, const AlamatSel(1, 41)): 'x'}),
      isFalse,
    );
    expect(keadaan(c).edit, hasLength(batasEditSimulasi));
    await lewatiJeda(tester);
    expect(mock.panggilanHitung.single, hasLength(batasEditSimulasi));
  });

  testWidgets('ganti akun: simulasi akun sebelumnya tidak ikut ke akun '
      'berikutnya', (tester) async {
    final mock = MockWorkbookService();
    final c = await siap(tester, mock);
    sim(c).terapkan({k6: '0.2'});
    await lewatiJeda(tester);
    expect(keadaan(c).adaEdit, isTrue);

    await tunggu(tester, c.read(authProvider.notifier).logout());
    await tunggu(
      tester,
      c
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123'),
    );
    expect(c.read(authProvider).value?.employeeId, 'SDK-0002');
    await lewatiJeda(tester);
    expect(keadaan(c).adaEdit, isFalse);
    expect(keadaan(c).overlay, isEmpty);
    expect(keadaan(c).bisaUrungkan, isFalse);
  });

  test('overlay: edit belum terjawab = sementara (konstanta seperti diketik, '
      'rumus = nilai lama + rumusnya), diurungkan = sel snapshot abu', () {
    const dasar = SelGrid(
      teks: '0.127',
      jenis: JenisSelGrid.angka,
      nilai: 0.127,
      tebal: true,
    );
    final ov = susunOverlay(
      null,
      {
        kunciEdit(1, const AlamatSel(1, 1)): '12.5',
        kunciEdit(1, const AlamatSel(1, 2)): '=A1*2',
        kunciEdit(1, const AlamatSel(1, 3)): 'true',
        kunciEdit(1, const AlamatSel(1, 4)): '',
      },
      {kunciEdit(1, const AlamatSel(1, 5)): '7'},
    )[1]!;
    final a1 = ov.selGrid(1, 1, dasar)!;
    expect((a1.teks, a1.jenis, a1.tebal), ('12.5', JenisSelGrid.angka, true));
    final b1 = ov.selGrid(1, 2, dasar)!;
    expect((b1.teks, b1.rumus), ('0.127', '=A1*2'));
    expect(ov.selGrid(1, 3, dasar)!.teks, 'TRUE');
    expect(ov.selGrid(1, 4, dasar)!.tanpaIsi, isTrue);
    final e1 = ov.selGrid(1, 5, dasar)!;
    expect((e1.teks, e1.warnaTeks), ('0.127', warnaTeksSementara));
    // Halaman snapshot belum termuat + edit diurungkan = tunggu.
    expect(ov.selGrid(1, 5, null), isNull);
    expect((ov.barisMaks, ov.kolomMaks), (1, 5));
  });
}
