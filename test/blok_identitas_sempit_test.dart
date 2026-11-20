import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show equipmentLookupServiceProvider;
import 'package:sidik_calibration/providers/equipment_provider.dart'
    show equipmentServiceProvider;
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/pindai/blok_identitas_foto.dart';
import 'package:sidik_calibration/screens/pindai/identitas_foto_isian.dart';
import 'package:sidik_calibration/screens/pindai/lembar_bawah_alat_baru.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show contohBentukLembarKerja;
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/layanan_alat_uji.dart';

/// Panel "Alat baru" di layar SEMPIT = lembar bawah; di layar lega tetap inline.
/// Yang dijaga: pilihan sempit/lega menurut ukuran dan skala huruf, isi dan
/// perilaku lembar bawah IDENTIK dengan panel inline (kotak, saran kuning, seri
/// wajib, PT mirip, galat server, tidak menimpa isian teknisi), tidak ada
/// overflow, tombol utama selalu terlihat (juga saat papan ketik terbuka), dan
/// dapat diakses (header, urutan fokus, sasaran sentuh).

const _bekal = BekalAlatBaru(
  kategori: 'instrumen-analitik',
  namaAlatKemampuan: 'pH Meter',
);

const _kertas = IdentitasKertas(
  namaAlat: 'pH Meter',
  merk: 'Mettler',
  seri: 'B628755900',
  pemilik: 'PT Tirta Contoh Mandiri',
  alamat: 'Jl. Contoh Primer A-10',
);

const _ptMirip = [
  CustomerLookup(id: 3, nama: 'PT Tirta Contoh Abadi Nusantara Sejahtera'),
  CustomerLookup(id: 4, nama: 'PT Tirta Contoh Makmur'),
];

const _tinggiPapan = 280.0;

const _sempit = (w: 320.0, h: 640.0, huruf: 2.0);
const _sempitSedang = (w: 360.0, h: 640.0, huruf: 1.3);
const _lega = (w: 392.0, h: 852.0, huruf: 1.0);
const _tablet = (w: 600.0, h: 900.0, huruf: 1.0);

typedef _Layar = ({double w, double h, double huruf});

class _Harness {
  _Harness({
    this.identitas = _kertas,
    List<EquipmentLookup>? alat,
    PtUji? pt,
    this.bekal = _bekal,
  }) : pencari = PencariAlatUji(alat ?? const []),
       pt = pt ?? PtUji(),
       layanan = LayananAlatUji(),
       penyimpan = InMemoryTokenStorage('mock-token-2') {
    isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uuid-uji',
      tanggalKalibrasiAwal: DateTime(2026, 11, 15),
    );
  }

  final IdentitasKertas identitas;
  final BekalAlatBaru? bekal;
  final PencariAlatUji pencari;
  final PtUji pt;
  final LayananAlatUji layanan;
  final InMemoryTokenStorage penyimpan;
  late final LembarKerjaState isian;
  int berubah = 0;

  /// Layar sungguhan: bilah status 24 dp, bilah gestur 16 dp, papan ketik lewat
  /// `viewInsets` (Scaffold menyempitkan badannya seperti di lembar kerja).
  Future<void> pasang(
    WidgetTester tester, {
    _Layar layar = _sempit,
    bool tenang = true,
  }) async {
    tester.view.physicalSize = Size(layar.w * 2, layar.h * 2);
    tester.view.devicePixelRatio = 2.0;
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 32);
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
    addTearDown(tester.view.reset);
    isian.terapkanIdentitasKertas(identitas);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(penyimpan),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          equipmentLookupServiceProvider.overrideWithValue(pencari),
          customerLookupServiceProvider.overrideWithValue(pt),
          equipmentServiceProvider.overrideWithValue(layanan),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: layar.huruf,
            maxScaleFactor: layar.huruf,
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => LayoutBuilder(
                builder: (context, c) => Column(
                  children: [
                    BlokIdentitasFoto(
                      identitas: identitas,
                      isian: isian,
                      profil: 'ph_meter',
                      bekalAlatBaru: bekal,
                      tinggiMaks: c.maxHeight,
                      onBerubah: () {
                        berubah++;
                        set(() {});
                      },
                    ),
                    const Expanded(child: SizedBox.expand()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (tenang) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void papanKetik(WidgetTester tester, {required bool buka}) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: buka ? _tinggiPapan * 2 : 0,
    );
    tester.view.padding = FakeViewPadding(top: 48, bottom: buka ? 0 : 32);
  }
}

Finder get _lembarBawah => find.byType(BottomSheet);

Finder get _panelDiLembarBawah => find.descendant(
  of: _lembarBawah,
  matching: find.byKey(BlokIdentitasFoto.kunciPanelBaru),
);

Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Buka panel "Alat baru" dari kartu ringkas (layar sempit).
Future<void> _bukaLembar(WidgetTester tester) =>
    _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBukaAlatBaru));

String _isiKotak(WidgetTester tester, Key k) =>
    tester.widget<TextField>(find.byKey(k)).controller!.text;

bool _terisiKuning(WidgetTester tester, Key k) =>
    tester.widget<TextField>(find.byKey(k)).decoration!.filled ?? false;

/// Kunci kotak yang sedang berfokus (null bila fokus di luar kotak panel).
Key? _kotakBerfokus() {
  final konteks = FocusManager.instance.primaryFocus?.context;
  if (konteks == null) return null;
  Key? kunci;
  konteks.visitAncestorElements((e) {
    final w = e.widget;
    if (w is TextField) {
      kunci = w.key;

      return false;
    }

    return true;
  });

  return kunci;
}

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('ambang layar sempit (alatBaruSebagaiLembarBawah)', () {
    for (final (nama, layar, sempit) in <(String, _Layar, bool)>[
      ('320 x 640 huruf 2,0', _sempit, true),
      ('360 x 640 huruf 1,3', _sempitSedang, true),
      ('392 x 852 huruf 1,0', _lega, false),
      ('tablet 600 x 900 huruf 1,0', _tablet, false),
      ('411 x 891 huruf 1,0', (w: 411.0, h: 891.0, huruf: 1.0), false),
      ('360 x 800 huruf 1,0', (w: 360.0, h: 800.0, huruf: 1.0), true),
      ('392 x 852 huruf 1,15', (w: 392.0, h: 852.0, huruf: 1.15), true),
      ('600 x 900 huruf 1,5', (w: 600.0, h: 900.0, huruf: 1.5), true),
      (
        'lanskap HP 840 x 360 huruf 1,0',
        (w: 840.0, h: 360.0, huruf: 1.0),
        true,
      ),
    ]) {
      test('$nama -> ${sempit ? 'lembar bawah' : 'inline'}', () {
        expect(
          alatBaruSebagaiLembarBawah(
            layar: Size(layar.w, layar.h),
            skalaHuruf: layar.huruf,
          ),
          sempit,
        );
      });
    }
  });

  group('pilihan tempat panel mengikuti ukuran dan skala huruf', () {
    for (final (nama, layar) in <(String, _Layar)>[
      ('320 x 640 huruf 2,0', _sempit),
      ('360 x 640 huruf 1,3', _sempitSedang),
    ]) {
      testWidgets('sempit $nama: kartu ringkas, panel di lembar bawah', (
        tester,
      ) async {
        final h = _Harness();
        await h.pasang(tester, layar: layar);

        // Hasil pencocokan = alat baru: kartu ringkas, BELUM ada lembar bawah
        // (tidak mencuri fokus) dan tidak ada panel inline.
        expect(
          find.byKey(BlokIdentitasFoto.kunciAlatBaruRingkas),
          findsOneWidget,
        );
        expect(_lembarBawah, findsNothing);
        expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsNothing);

        await _bukaLembar(tester);

        expect(_panelDiLembarBawah, findsOneWidget);
        expect(find.byKey(BlokIdentitasFoto.kunciKotakSeri), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final (nama, layar) in <(String, _Layar)>[
      ('392 x 852 huruf 1,0', _lega),
      ('tablet 600 x 900 huruf 1,0', _tablet),
    ]) {
      testWidgets('lega $nama: panel inline, tanpa lembar bawah', (
        tester,
      ) async {
        final h = _Harness();
        await h.pasang(tester, layar: layar);

        expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);
        expect(_lembarBawah, findsNothing);
        expect(
          find.byKey(BlokIdentitasFoto.kunciAlatBaruRingkas),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"Alat baru" (identitas tak terbaca) membuka lembar bawah '
        'langsung', (tester) async {
      final h = _Harness(identitas: IdentitasKertas.kosong);
      await h.pasang(tester);
      expect(find.byKey(BlokIdentitasFoto.kunciTidakTerbaca), findsOneWidget);

      await _ketuk(tester, find.text('Alat baru'));

      expect(_panelDiLembarBawah, findsOneWidget);
    });

    testWidgets('"Bukan salah satunya" membuka lembar bawah; Batal menutupnya '
        'dan kembali ke pilihan', (tester) async {
      final h = _Harness(
        alat: [
          EquipmentLookup(
            id: 21,
            namaAlat: 'pH Meter 21',
            serialNumber: 'B628755901',
            kategori: 'instrumen-analitik',
            status: 'aktif',
          ),
        ],
      );
      await h.pasang(tester);
      expect(find.byKey(BlokIdentitasFoto.kunciMirip), findsOneWidget);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciMiripBaru));
      expect(_panelDiLembarBawah, findsOneWidget);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBatalBaru));
      expect(_lembarBawah, findsNothing);
      expect(find.byKey(BlokIdentitasFoto.kunciMirip), findsOneWidget);
    });

    testWidgets('jenis lembar tanpa kategori: tidak ada lembar bawah, pesan '
        'mengarahkan ke form Alat baru', (tester) async {
      final h = _Harness(bekal: const BekalAlatBaru(namaAlatKemampuan: 'pH'));
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciKategoriKosong), findsOneWidget);
      expect(find.byKey(BlokIdentitasFoto.kunciAlatBaruRingkas), findsNothing);
      expect(_lembarBawah, findsNothing);
    });
  });

  group('isi dan perilaku lembar bawah = panel inline', () {
    testWidgets(
      'terisi dari kertas (kuning); mengubah kotak melepas kuningnya',
      (tester) async {
        final h = _Harness();
        await h.pasang(tester);
        await _bukaLembar(tester);

        expect(
          _isiKotak(tester, BlokIdentitasFoto.kunciKotakSeri),
          'B628755900',
        );
        expect(
          _isiKotak(tester, BlokIdentitasFoto.kunciKotakPemilik),
          'PT Tirta Contoh Mandiri',
        );
        expect(find.text('Jenis: pH Meter'), findsOneWidget);
        expect(
          find.text('Diisi dari kertas. Periksa dulu, lalu buat.'),
          findsOneWidget,
        );
        expect(_terisiKuning(tester, BlokIdentitasFoto.kunciKotakSeri), isTrue);

        await tester.enterText(
          find.byKey(BlokIdentitasFoto.kunciKotakSeri),
          'B628755901',
        );
        await tester.pump();
        expect(
          _terisiKuning(tester, BlokIdentitasFoto.kunciKotakSeri),
          isFalse,
        );
        expect(_terisiKuning(tester, BlokIdentitasFoto.kunciKotakMerk), isTrue);
      },
    );

    testWidgets('"Buat dan lanjut": PT didaftarkan, alat dibuat dan dipasang, '
        'lembar bawah menutup, nilai panel yang diedit menjadi nilai lembar', (
      tester,
    ) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);

      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakMerk),
        'Mettler Toledo',
      );
      await tester.pump();
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(h.pt.didaftarkan, 1);
      final kirim = h.layanan.dikirim.single;
      expect(kirim.serialNumber, 'B628755900');
      expect(kirim.merk, 'Mettler Toledo');
      expect(kirim.kategori, 'instrumen-analitik');
      expect(kirim.namaAlatKemampuan, 'pH Meter');
      expect(kirim.pelangganId, 901);

      // Lembar terisi: alat terpasang, lembar bawah tertutup, kartu terpilih.
      expect(h.isian.alat?.serialNumber, 'B628755900');
      expect(_lembarBawah, findsNothing);
      expect(find.byKey(BlokIdentitasFoto.kunciTerpilih), findsOneWidget);
      expect(h.isian.teks['alat_merk']!.text, 'Mettler Toledo');
      expect(h.isian.isianDariFoto, isNot(contains('alat_merk')));
      expect(h.isian.isianDariFoto, contains('alat_serial_number'));
      expect(
        find.textContaining('tersimpan dan langsung dipakai'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('kotak lembar yang diketik teknisi tidak ditimpa nilai panel', (
      tester,
    ) async {
      final h = _Harness();
      // Teknisi mengetik merk di lembar sebelum membuat alat: kotak sudah terisi,
      // jadi saran kertas tidak masuk dan tanda "dari foto" tidak ada.
      h.isian.teks['alat_merk']!.text = 'Ketikan teknisi';
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(h.layanan.dikirim.single.merk, 'Mettler');
      expect(h.isian.teks['alat_merk']!.text, 'Ketikan teknisi');
    });

    testWidgets('seri kosong: pesan wajib di kotak seri (difokuskan), tanpa '
        'kueri server, tidak ada yang dibuat', (tester) async {
      final h = _Harness(
        identitas: const IdentitasKertas(
          namaAlat: 'pH Meter',
          merk: 'Mettler',
          pemilik: 'PT Tirta Contoh Mandiri',
        ),
      );
      await h.pasang(tester);
      expect(h.pencari.dipanggil, 0);
      await _bukaLembar(tester);
      expect(
        find.text('Nomor seri tidak terbaca. Ketik dari badan alat.'),
        findsOneWidget,
      );

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(h.layanan.dikirim, isEmpty);
      expect(h.pt.didaftarkan, 0, reason: 'tidak ada PT yatim');
      expect(_panelDiLembarBawah, findsOneWidget);
      // Kotak yang salah difokuskan, jadi tergulir ke layar.
      expect(_kotakBerfokus(), BlokIdentitasFoto.kunciKotakSeri);
      final kotak = tester.getRect(
        find.byKey(BlokIdentitasFoto.kunciKotakSeri),
      );
      expect(kotak.top, greaterThanOrEqualTo(0));
      expect(kotak.bottom, lessThanOrEqualTo(640));
    });

    testWidgets('nama dan pemilik wajib: kotak kosong menolak, tidak ada yang '
        'dibuat', (tester) async {
      final h = _Harness(
        identitas: const IdentitasKertas(seri: 'SN-4471'),
        bekal: const BekalAlatBaru(
          kategori: 'instrumen-analitik',
          namaAlatKemampuan: '',
        ),
      );
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(find.text('Wajib diisi.'), findsWidgets);
      expect(h.layanan.dikirim, isEmpty);
      expect(h.pt.didaftarkan, 0);
      expect(_kotakBerfokus(), BlokIdentitasFoto.kunciKotakNama);
    });

    testWidgets('PT mirip: kandidat tampil di dalam lembar bawah dan terlihat; '
        'memilih kandidat membuat alat untuk PT itu', (tester) async {
      final h = _Harness(pt: PtUji(mirip: _ptMirip));
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      final panel = find.byKey(BlokIdentitasFoto.kunciPtMirip);
      expect(panel, findsOneWidget);
      expect(h.layanan.dikirim, isEmpty);
      expect(h.pt.didaftarkan, 0);
      expect(h.isian.alat, isNull);
      // Terlihat di layar (di atas dasar lembar), bukan terkubur di bawah gulir.
      final r = tester.getRect(panel);
      final dasar = tester.getRect(
        find.byKey(BlokIdentitasFoto.kunciBuatLanjut),
      );
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.top, lessThan(dasar.top));

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPilihPt(4)));

      expect(h.layanan.dikirim.single.pelangganId, 4);
      expect(h.pt.didaftarkan, 0, reason: 'memakai PT yang sudah ada');
      expect(h.isian.alat, isNotNull);
      expect(_lembarBawah, findsNothing);
    });

    testWidgets('"Tetap buat PT baru": tetap_buat dikirim', (tester) async {
      final h = _Harness(pt: PtUji(mirip: _ptMirip));
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPtBaru));

      expect(h.pt.terakhirTetapBuat, isTrue);
      expect(h.pt.didaftarkan, 1);
      expect(h.isian.alat, isNotNull);
    });

    testWidgets('galat server saat membuat: pesan jujur terlihat, lembar tetap '
        'terbuka; "Buat dan lanjut" lagi berhasil tanpa PT kembar', (
      tester,
    ) async {
      final h = _Harness();
      var gagal = true;
      h.layanan.sebelumSimpan = (_) async {
        if (gagal) {
          gagal = false;
          throw Exception('putus');
        }
      };
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      final galat = find.byKey(BlokIdentitasFoto.kunciGalat);
      expect(galat, findsOneWidget);
      expect(find.textContaining('Periksa sinyal'), findsOneWidget);
      expect(_panelDiLembarBawah, findsOneWidget);
      expect(h.isian.alat, isNull);
      expect(h.pt.didaftarkan, 1);
      final r = tester.getRect(galat);
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(640));

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
      expect(h.isian.alat, isNotNull);
      expect(h.pt.didaftarkan, 1, reason: 'PT tidak kembar');
      expect(h.layanan.dikirim, hasLength(1));
      expect(_lembarBawah, findsNothing);
    });

    testWidgets('dua ketukan cepat "Buat dan lanjut": satu alat', (
      tester,
    ) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);

      final tombol = find.byKey(BlokIdentitasFoto.kunciBuatLanjut);
      await tester.tap(tombol);
      await tester.tap(tombol, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(h.layanan.dikirim, hasLength(1));
    });

    testWidgets('memuat: kotak terkunci, Kembali tidak menutup lembar; sesudah '
        'berhasil lembar menutup', (tester) async {
      final h = _Harness();
      final tahan = Completer<void>();
      h.layanan.sebelumSimpan = (_) => tahan.future;
      await h.pasang(tester);
      await _bukaLembar(tester);

      await tester.tap(find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Membuat…'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(BlokIdentitasFoto.kunciKotakSeri))
            .enabled,
        isFalse,
      );

      // Tombol Kembali sistem: lembar tetap (alat sedang dibuat).
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_lembarBawah, findsOneWidget);

      tahan.complete();
      await tester.pumpAndSettle();
      expect(_lembarBawah, findsNothing);
      expect(h.isian.alat, isNotNull);
    });
  });

  group('menutup lembar bawah', () {
    testWidgets('Batal tanpa pilihan lain: lembar menutup, blok hilang', (
      tester,
    ) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBatalBaru));

      expect(_lembarBawah, findsNothing);
      expect(find.byKey(BlokIdentitasFoto.kunciAlatBaruRingkas), findsNothing);
      expect(h.isian.alat, isNull);
    });

    testWidgets('tombol Tutup (x): lembar menutup', (tester) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);

      await _ketuk(
        tester,
        find.descendant(
          of: _lembarBawah,
          matching: find.byKey(BlokIdentitasFoto.kunciTutup),
        ),
      );

      expect(_lembarBawah, findsNothing);
    });

    testWidgets('Kembali sistem (tanpa Batal): lembar menutup, kartu ringkas '
        'tetap, isian teknisi terjaga dan bisa dibuka lagi', (tester) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);
      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakModel),
        'Ketikan panel',
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_lembarBawah, findsNothing);
      expect(
        find.byKey(BlokIdentitasFoto.kunciAlatBaruRingkas),
        findsOneWidget,
      );

      await _bukaLembar(tester);
      expect(
        _isiKotak(tester, BlokIdentitasFoto.kunciKotakModel),
        'Ketikan panel',
      );
    });
  });

  group('tata letak: tanpa overflow, tombol utama terlihat', () {
    for (final (nama, layar) in <(String, _Layar)>[
      ('320 x 640 huruf 2,0', _sempit),
      ('360 x 640 huruf 1,3', _sempitSedang),
    ]) {
      for (final papan in [false, true]) {
        testWidgets('panel + PT mirip + galat: $nama, papan ketik '
            '${papan ? 'terbuka' : 'tertutup'}', (tester) async {
          final h = _Harness(pt: PtUji(mirip: _ptMirip));
          await h.pasang(tester, layar: layar);
          await _bukaLembar(tester);
          if (papan) {
            h.papanKetik(tester, buka: true);
            await tester.pumpAndSettle();
            // Seperti teknisi: gulir kotak ke layar dulu, lalu ketuk.
            await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciKotakMerk));
          }

          final tombol = find.byKey(BlokIdentitasFoto.kunciBuatLanjut);
          final tinggiLayar = layar.h;
          final dasarTampak = papan ? tinggiLayar - _tinggiPapan : tinggiLayar;

          // Tombol utama terlihat penuh, di atas papan ketik, tanpa menggulir.
          expect(tombol, findsOneWidget);
          var r = tester.getRect(tombol);
          expect(r.top, greaterThanOrEqualTo(0), reason: 'terpotong di atas');
          expect(
            r.bottom,
            lessThanOrEqualTo(dasarTampak + 0.5),
            reason: 'tertutup papan ketik / di luar layar',
          );

          // Ditekan: PT mirip muncul; tombol tetap terlihat.
          await tester.tap(tombol);
          await tester.pumpAndSettle();
          expect(find.byKey(BlokIdentitasFoto.kunciPtMirip), findsOneWidget);
          r = tester.getRect(find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
          expect(r.bottom, lessThanOrEqualTo(dasarTampak + 0.5));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('galat + seri kosong di 320 x 640 huruf 2,0 dengan papan '
        'ketik: tanpa overflow', (tester) async {
      final h = _Harness(
        identitas: const IdentitasKertas(
          namaAlat: 'pH Meter',
          pemilik: 'PT Tirta Contoh Mandiri',
        ),
      );
      h.layanan.sebelumSimpan = (_) async => throw Exception('putus');
      await h.pasang(tester);
      await _bukaLembar(tester);
      h.papanKetik(tester, buka: true);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakSeri),
        'SN-1',
      );
      await tester.pump();
      await tester.tap(find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
      await tester.pumpAndSettle();

      expect(find.byKey(BlokIdentitasFoto.kunciGalat), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('layar jadi lega saat lembar terbuka (mis. skala huruf '
        'diperkecil): lembar menutup dan panel inline muncul', (tester) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);
      expect(_lembarBawah, findsOneWidget);

      await h.pasang(tester, layar: _lega);

      expect(_lembarBawah, findsNothing);
      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('aksesibilitas', () {
    testWidgets('lembar bawah: judul = header, tombol punya label dan sasaran '
        'sentuh >= 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);

      expect(
        tester.getSemantics(
          find.descendant(of: _lembarBawah, matching: find.text('Alat baru')),
        ),
        isSemantics(label: 'Alat baru', isHeader: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      for (final k in [
        BlokIdentitasFoto.kunciTutup,
        BlokIdentitasFoto.kunciBatalBaru,
        BlokIdentitasFoto.kunciBuatLanjut,
      ]) {
        // Kartu ringkas di belakang lembar juga punya tombol Tutup.
        final ukuran = tester.getSize(
          find.descendant(of: _lembarBawah, matching: find.byKey(k)),
        );
        expect(
          ukuran.height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason: '$k tingginya ${ukuran.height}',
        );
      }
      handle.dispose();
    });

    testWidgets('urutan fokus mengikuti urutan baca: nama, merk, model, seri, '
        'pemilik, alamat', (tester) async {
      final h = _Harness();
      await h.pasang(tester);
      await _bukaLembar(tester);

      await tester.tap(find.byKey(BlokIdentitasFoto.kunciKotakNama));
      await tester.pump();
      final urutan = <Key?>[_kotakBerfokus()];
      for (var i = 0; i < 5; i++) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        urutan.add(_kotakBerfokus());
      }

      expect(urutan, [
        BlokIdentitasFoto.kunciKotakNama,
        BlokIdentitasFoto.kunciKotakMerk,
        BlokIdentitasFoto.kunciKotakModel,
        BlokIdentitasFoto.kunciKotakSeri,
        BlokIdentitasFoto.kunciKotakPemilik,
        BlokIdentitasFoto.kunciKotakAlamat,
      ]);
    });

    testWidgets('panel inline (lega) tidak berubah: tetap tanpa lembar bawah', (
      tester,
    ) async {
      final h = _Harness();
      await h.pasang(tester, layar: _lega);

      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);
      expect(_lembarBawah, findsNothing);
    });
  });
}
