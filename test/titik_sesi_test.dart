import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/titik_sesi.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/titik_sesi_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/pengatur_titik_sesi.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_tekanan.dart';

/// Titik ukur SESI (PRD §55, `docs/perintah-frontend-titik-ukur-sesi.md` di
/// repo API): set disimpan server, titik tidak pernah dihapus, pembacaan
/// titik nonaktif tidak pernah dikosongkan, 409 diganti set server tanpa
/// kirim ulang otomatis.
void main() {
  const nominalTimer = [60, 300, 600, 900, 1800, 2400, 3600, 120, 180, 240];

  Map<String, dynamic> batasTimer() => {
    'didukung': true,
    'alasan': null,
    'tabel': [
      {
        'kode': 'utama',
        'judul': 'Set point',
        'min': 1,
        'maks': 10,
        'boleh_tambah': true,
        'boleh_nonaktif': true,
        'alasan_tambah': null,
        'alasan_nonaktif': null,
        'nominal': 'saran',
        'bawaan': nominalTimer,
        'fase': ['sesudah'],
        'satuan': 's',
        'pengulangan': {'min': 2, 'maks': 10, 'bawaan': 3},
        'kunci_masa_depan': {'x': 1},
      },
    ],
  };

  List<Map<String, dynamic>> bawaanTimer() => [
    for (var i = 0; i < nominalTimer.length; i++)
      {
        'id': 'profil-utama-${i + 1}',
        'tabel': 'utama',
        'nominal': nominalTimer[i],
        'satuan': 's',
        'fase': ['sesudah'],
        'aktif': true,
        'asal': 'profil',
        'alasan': null,
        'justifikasi_cmc': null,
        'tambahan': false,
      },
  ];

  Map<String, dynamic> bentukTimer({Object? batas}) {
    final m =
        jsonDecode(
              File(
                'test/fixtures/lembar-kerja-timer_stopwatch.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    m['batas_titik'] = batas ?? batasTimer();
    m['titik_sesi_bawaan'] = bawaanTimer();
    return m;
  }

  const alat = EquipmentLookup(
    id: 7,
    namaAlat: 'Stopwatch Uji',
    serialNumber: 'SW-1',
    kategori: 'waktu',
    status: 'aktif',
    satuan: 's',
    rangeMax: 3600,
  );

  LembarKerjaState isianTimer({Object? batas}) {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentukTimer(batas: batas)),
      clientRequestId: 'uji-titik-sesi',
    );
    isian.alat = alat;
    return isian;
  }

  TabelHasil tabelStandar(LembarKerjaState isian) => isian.bentuk.bagian
      .expand((b) => b.tabel)
      .firstWhere((t) => t.deretStandar);

  /// TitikState baris bernominal [n] di tabel standar.
  TitikState baris(LembarKerjaState isian, double n) {
    final t = tabelStandar(isian);
    final b = isian.barisTabel(t);
    final i = b.indexWhere((x) => x.titikUkur == n);
    expect(i, isNot(-1), reason: 'baris $n tidak ada');
    return isian.titikUntukBaris(b, i, t)!;
  }

  List<double> nominalBaris(LembarKerjaState isian) => [
    for (final b in isian.barisTabel(tabelStandar(isian))) b.titikUkur,
  ];

  Map<String, dynamic> kirim(LembarKerjaState isian) =>
      isian.toSubmission(draft: true).toJson();

  group('model', () {
    test('batas & titik terbaca, kunci asing dilewat, koma diterima', () {
      final b = BatasTitik.dariJson(batasTimer())!;
      expect(b.didukung, isTrue);
      expect(b.tabel.single.maks, 10);
      expect(b.tabel.single.nominal, JenisNominal.saran);
      expect(b.tabel.single.pengulangan!.bawaan, 3);

      final set = SetTitikSesi.dariJson({
        'revisi': '2',
        'titik': [
          {
            'id': 'a',
            'nominal': '0,5',
            'aktif': false,
            'alasan': 'macet di sini',
          },
          {'id': 'b'}, // tanpa nominal → dilewat
          'bukan-peta',
          {'id': 'c', 'nominal': 75, 'asal': 'pelanggan', 'alasan': 'PO-123'},
        ],
        'pengulangan': {'utama': 3, 'rusak': 'x'},
        'diubah_oleh': 7,
      }, tabelBawaan: 'utama')!;

      expect(set.revisi, 2);
      expect(set.titik.map((t) => t.id), ['a', 'c']);
      expect(set.titik.first.nominal, 0.5);
      expect(set.titik.first.aktif, isFalse);
      expect(set.titik.last.asal, AsalTitik.pelanggan);
      expect(set.pengulangan, {'utama': 3});
    });

    test('didukung tanpa tabel = tidak didukung; meta rusak = null', () {
      expect(
        BatasTitik.dariJson({'didukung': true, 'tabel': []})!.didukung,
        isFalse,
      );
      expect(MetaTitikSesi.dariJson('x'), isNull);
      expect(MetaTitikSesi.dariJson({'set': null}), isNull);

      final meta = MetaTitikSesi.dariJson({
        'batas': batasTimer(),
        'set': null,
        'bawaan': bawaanTimer(),
        'di_luar_cmc': ['profil-utama-7'],
      })!;
      expect(meta.set, isNull);
      expect(meta.bawaan, hasLength(10));
      expect(meta.diLuarCmc, ['profil-utama-7']);
    });

    test('lembar kosong membaca batas_titik & titik_sesi_bawaan', () {
      final b = LembarKerja.fromJson(bentukTimer());
      expect(b.batasTitik!.didukung, isTrue);
      expect(b.titikSesiBawaan, hasLength(10));
      expect(b.titikSesiBawaan.first.id, 'profil-utama-1');
    });
  });

  group('aturan set', () {
    TitikSesiState setTekanan() {
      final s = TitikSesiState();
      s.pasangBatasLembar(
        BatasTitik.dariJson({
          'didukung': true,
          'tabel': [
            {
              'kode': 'utama',
              'min': 1,
              'maks': 14,
              'boleh_tambah': true,
              'boleh_nonaktif': true,
              'pertama_wajib_aktif': true,
              'alasan_pertama': 'zero error dari titik pertama',
              'nominal': 'bebas',
              'bawaan': [],
              'fase': ['sesudah'],
              'pengulangan': {'min': 3, 'maks': 3, 'bawaan': 3},
            },
          ],
        }),
        const [],
      );
      return s;
    }

    test('titik pelanggan wajib beralasan ≥ 5 huruf', () {
      final s = setTekanan();
      expect(
        s.tambah(tabel: 'utama', nominal: 5, asal: AsalTitik.pelanggan),
        GalatTitikSesi.alasanPelanggan,
      );
      expect(
        s.tambah(
          tabel: 'utama',
          nominal: 5,
          asal: AsalTitik.pelanggan,
          alasan: 'PO',
        ),
        GalatTitikSesi.alasanPelanggan,
      );
      expect(
        s.tambah(
          tabel: 'utama',
          nominal: 5,
          asal: AsalTitik.pelanggan,
          alasan: 'PO-123',
        ),
        isNull,
      );
      expect(s.titik.single.asal, AsalTitik.pelanggan);
      expect(s.titik.single.toJson()['alasan'], 'PO-123');
    });

    test('Tekanan: titik pertama tidak bisa dinonaktifkan', () {
      final s = setTekanan();
      s.tambah(tabel: 'utama', nominal: 0, id: 'p1');
      s.tambah(tabel: 'utama', nominal: 5, id: 'p2');

      expect(
        s.nonaktifkan('p1', 'alasan panjang'),
        GalatTitikSesi.pertamaTerkunci,
      );
      expect(s.titikDenganId('p1')!.aktif, isTrue);
      expect(s.nonaktifkan('p2', 'abc'), GalatTitikSesi.alasanPendek);
      expect(s.nonaktifkan('p2', 'alat macet'), isNull);
      expect(s.titikDenganId('p2')!.aktif, isFalse);
    });

    test('nominal kembar, batas aktif, dan nominal berpembacaan ditolak', () {
      final s = setTekanan();
      s.tambah(tabel: 'utama', nominal: 0, id: 'p1');
      s.tambah(tabel: 'utama', nominal: 5, id: 'p2');

      expect(
        s.tambah(tabel: 'utama', nominal: 5),
        GalatTitikSesi.nominalKembar,
      );
      expect(
        s.ubahNominal('p2', 6, punyaPembacaan: true),
        GalatTitikSesi.punyaPembacaan,
      );
      expect(s.ubahNominal('p2', 6, punyaPembacaan: false), isNull);
      expect(s.titikDenganId('p2')!.nominal, 6);
    });

    test('payload memuat seluruh set termasuk nonaktif, kosong = null', () {
      final s = setTekanan();
      expect(s.payload(), isNull, reason: 'titik kosong ditolak server');

      s.tambah(tabel: 'utama', nominal: 0, id: 'p1');
      s.tambah(tabel: 'utama', nominal: 5, id: 'p2');
      s.nonaktifkan('p2', 'alat macet');

      final p = s.payload()!;
      expect(p['revisi'], 0);
      expect((p['titik'] as List).map((t) => (t as Map)['id']), ['p1', 'p2']);
      expect(((p['titik'] as List)[1] as Map)['aktif'], isFalse);
      expect(((p['titik'] as List)[1] as Map)['alasan'], 'alat macet');
    });
  });

  group('lembar kerja (Timer, tabel berpasangan)', () {
    test('lembar baru: titik_sesi dikirim dari bawaan, revisi 0', () {
      final isian = isianTimer();
      expect(isian.titikSesiAktif, isTrue);

      final ts = kirim(isian)['titik_sesi'] as Map<String, dynamic>;
      expect(ts['revisi'], 0);
      expect(ts['titik'], hasLength(10));
      // Jumlah kolom lembar (3) di dalam batas 2–10.
      expect(ts['pengulangan'], {'utama': isian.bentuk.jumlahPengulangan});
    });

    test('profil tidak didukung: tanpa titik_sesi, perilaku lama', () {
      final isian = isianTimer(
        batas: {'didukung': false, 'alasan': 'belum diverifikasi', 'tabel': []},
      );
      expect(isian.titikSesiAktif, isFalse);
      expect(kirim(isian).containsKey('titik_sesi'), isFalse);

      final hasil = isian.bentuk.bagian.firstWhere(
        (b) => b.tabel.any((t) => t.deretStandar),
      );
      expect(isian.alasanTitikSesiDi(hasil), 'belum diverifikasi');
      expect(isian.tabelTitikSesiDi(hasil), isNull);
    });

    test('server lama tanpa batas_titik: tanpa titik_sesi', () {
      final m = bentukTimer()
        ..remove('batas_titik')
        ..remove('titik_sesi_bawaan');
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson(m),
        clientRequestId: 'uji',
      )..alat = alat;
      expect(isian.titikSesiAktif, isFalse);
      expect(kirim(isian).containsKey('titik_sesi'), isFalse);
    });

    test('nonaktifkan: pembacaan TETAP ada dan tetap terkirim', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      baris(isian, 300).kotak(t.kunciTabel, 'menit', 0).text = '5';

      final id = isian.titikSesi.titikDenganNominal(300)!.id;
      expect(isian.nonaktifkanTitikSesi(id, 'alat macet di 300 s'), isNull);

      expect(baris(isian, 300).kotak(t.kunciTabel, 'menit', 0).text, '5');
      expect(
        isian.titikBisaDiisi(
          isian.kunciBaris(
            isian.barisTabel(t),
            isian.barisTabel(t).indexWhere((b) => b.titikUkur == 300),
            t,
          ),
        ),
        isFalse,
        reason: 'baris titik nonaktif dikunci',
      );

      final json = kirim(isian);
      final m = (json['measurements'] as List).cast<Map<String, dynamic>>();
      expect(m.any((x) => x['titik_ukur'] == 300), isTrue);

      final ts = json['titik_sesi'] as Map<String, dynamic>;
      final t300 = (ts['titik'] as List).cast<Map>().firstWhere(
        (x) => x['nominal'] == 300,
      );
      expect(t300['aktif'], isFalse);
      expect(t300['alasan'], 'alat macet di 300 s');
    });

    test('muat meta: titik pelanggan dapat baris, pembacaan tidak geser', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      baris(isian, 300).kotak(t.kunciTabel, 'menit', 0).text = '5';

      final titik =
          [
            for (final p in bawaanTimer())
              {
                ...p,
                if (p['nominal'] == 300) 'aktif': false,
                if (p['nominal'] == 300) 'alasan': 'macet sekali',
              },
          ]..insert(1, {
            'id': 'pel-1',
            'tabel': 'utama',
            'nominal': 75,
            'asal': 'pelanggan',
            'alasan': 'PO-123',
          });
      // Batas maks 10 aktif: 300 nonaktif, 75 aktif → 10 aktif.
      isian.muatTitikSesi(
        MetaTitikSesi.dariJson({
          'batas': batasTimer(),
          'set': {
            'revisi': 4,
            'titik': titik,
            'pengulangan': {'utama': 3},
          },
          'bawaan': null,
          'di_luar_cmc': ['pel-1'],
        }),
      );

      expect(nominalBaris(isian).take(3), [60, 75, 300]);
      expect(baris(isian, 300).kotak(t.kunciTabel, 'menit', 0).text, '5');
      expect(isian.titikSesi.revisi, 4);
      expect(isian.titikSesi.diLuarCmc, ['pel-1']);
      expect((kirim(isian)['titik_sesi'] as Map)['revisi'], 4);
    });

    test('409: set diganti dari server, pembacaan teknisi dipertahankan', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      baris(isian, 60).kotak(t.kunciTabel, 'menit', 0).text = '1';

      // Titik lokal baru yang SUDAH diisi — tidak boleh hilang.
      isian.nonaktifkanTitikSesi(
        isian.titikSesi.titikDenganNominal(240)!.id,
        'tidak dipakai',
      );
      expect(isian.tambahTitikSesi(tabel: 'utama', nominal: 75), isNull);
      baris(isian, 75).kotak(t.kunciTabel, 'menit', 0).text = '1';

      final server = {
        'revisi': 3,
        'titik': [
          for (final p in bawaanTimer())
            {
              ...p,
              if (p['nominal'] == 600) 'aktif': false,
              if (p['nominal'] == 600) 'alasan': 'dari HP lain',
            },
        ],
      };

      expect(isian.terapkanSetServer(server), isTrue);
      expect(isian.titikSesi.revisi, 3);
      expect(isian.titikSesi.titikDenganNominal(600)!.aktif, isFalse);
      expect(
        isian.titikSesi.titikDenganNominal(240)!.aktif,
        isTrue,
        reason: 'perubahan lokal yang bentrok diganti set server',
      );
      expect(baris(isian, 60).kotak(t.kunciTabel, 'menit', 0).text, '1');
      expect(
        isian.titikSesi.titikDenganNominal(75),
        isNotNull,
        reason: 'titik lokal berisi pembacaan dipertahankan',
      );
      expect(baris(isian, 75).kotak(t.kunciTabel, 'menit', 0).text, '1');
      expect(isian.titikSesi.diubahLokal, isTrue);
    });

    test('ubah nominal titik berpembacaan ditolak', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      baris(isian, 60).kotak(t.kunciTabel, 'menit', 0).text = '1';
      final id = isian.titikSesi.titikDenganNominal(60)!.id;

      expect(isian.ubahNominalTitikSesi(id, 61), GalatTitikSesi.punyaPembacaan);
      final kosong = isian.titikSesi.titikDenganNominal(900)!.id;
      expect(isian.ubahNominalTitikSesi(kosong, 950), isNull);
      expect(nominalBaris(isian), contains(950));
    });

    test('salinan HP memulihkan set & revisi', () {
      final isian = isianTimer();
      isian.nonaktifkanTitikSesi(
        isian.titikSesi.titikDenganNominal(240)!.id,
        'tidak dipakai',
      );
      isian.titikSesi.revisi = 5;
      final salinan = isian.salinanLokal();

      final pulih = isianTimer();
      pulih.pulihkanSalinanLokal(
        jsonDecode(jsonEncode(salinan)) as Map<String, dynamic>,
      );
      expect(pulih.titikSesi.revisi, 5);
      expect(pulih.titikSesi.titikDenganNominal(240)!.aktif, isFalse);
      expect(pulih.titikSesi.diubahLokal, isTrue);
    });
  });

  group('lembar Tekanan (set point diketik)', () {
    Map<String, dynamic> batasTekanan() => {
      'didukung': true,
      'tabel': [
        {
          'kode': 'utama',
          'judul': 'Set point',
          'min': 1,
          'maks': 14,
          'boleh_tambah': true,
          'boleh_nonaktif': true,
          'pertama_wajib_aktif': true,
          'nominal': 'bebas',
          'bawaan': [],
          'fase': ['sesudah'],
          'satuan': 'bar',
          'pengulangan': {'min': 3, 'maks': 3, 'bawaan': 3},
        },
      ],
    };

    LembarKerjaState isianTekanan() {
      final m = contohBentukLembarKerjaPressureGauge()
        ..['batas_titik'] = batasTekanan()
        ..['titik_sesi_bawaan'] = <Object>[];
      return LembarKerjaState(
          bentuk: LembarKerja.fromJson(m),
          clientRequestId: 'uji-tekanan',
        )
        ..alat = const EquipmentLookup(
          id: 9,
          namaAlat: 'Pressure Gauge',
          serialNumber: 'PG-1',
          kategori: 'tekanan',
          status: 'aktif',
          satuan: 'bar',
          rangeMax: 10,
        );
    }

    test('set mengikuti urutan baris; titik pertama terkunci', () {
      final isian = isianTekanan();
      expect(isian.titikSesiAktif, isTrue);
      expect(isian.modeTitikSesi('utama'), ModeBarisTitikSesi.ketik);
      expect(
        kirim(isian).containsKey('titik_sesi'),
        isFalse,
        reason: 'belum ada set point diketik',
      );

      expect(isian.tambahTitikSesi(tabel: 'utama', nominal: 0), isNull);
      expect(isian.tambahTitikSesi(tabel: 'utama', nominal: 5), isNull);
      expect(isian.tambahTitikSesi(tabel: 'utama', nominal: 10), isNull);

      final ts = kirim(isian)['titik_sesi'] as Map<String, dynamic>;
      expect((ts['titik'] as List).map((t) => (t as Map)['nominal']), [
        0,
        5,
        10,
      ]);
      expect(
        ts.containsKey('pengulangan'),
        isFalse,
        reason: 'pengulangan Tekanan dipatok — tidak dikirim',
      );

      final pertama = isian.titikSesi.titik.first;
      expect(
        isian.nonaktifkanTitikSesi(pertama.id, 'alasan cukup'),
        GalatTitikSesi.pertamaTerkunci,
      );

      // Pembacaan di baris pertama & ketiga (tabel UP) — baris tanpa angka
      // tidak ikut `measurements`.
      final up = isian.bentuk.bagian
          .expand((b) => b.tabel)
          .firstWhere((t) => t.simpanKe == 'measurements[].tekanan_up');
      final barisUp = isian.barisTabel(up);
      for (final i in [0, 2]) {
        isian
                .titikUntukBaris(barisUp, i, up)!
                .kotak(up.kunciTabel, 'pembacaan', 0)
                .text =
            '${i * 2.5}';
      }

      final m = (kirim(isian)['measurements'] as List).cast<Map>();
      expect(m.map((x) => x['titik_ukur']), [0, 10]);
      expect(m.first['titik_ukur'], 0, reason: 'baris pertama = titik pertama');
    });
  });

  group('pengatur titik sesi (widget)', () {
    Future<LembarKerjaState> pasang(WidgetTester tester) async {
      final isian = isianTimer();
      final tabel = isian.titikSesi.batas!.tabel.single;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => PengaturTitikSesi(
                  isian: isian,
                  tabel: tabel,
                  onBerubah: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      return isian;
    }

    testWidgets('nonaktifkan lewat dialog beralasan — bukan hapus', (
      tester,
    ) async {
      final isian = await pasang(tester);
      final id = isian.titikSesi.titikDenganNominal(300)!.id;

      expect(find.byTooltip('Hapus titik 300'), findsNothing);

      await tester.tap(find.byKey(ValueKey('titik-sesi-menu-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nonaktifkan').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('titik-sesi-alasan')),
        'ab',
      );
      await tester.tap(find.byKey(const ValueKey('titik-sesi-alasan-simpan')));
      await tester.pumpAndSettle();
      expect(isian.titikSesi.titikDenganNominal(300)!.aktif, isTrue);
      expect(find.text('Alasan wajib diisi, minimal 5 huruf.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('titik-sesi-alasan')),
        'alat macet',
      );
      await tester.tap(find.byKey(const ValueKey('titik-sesi-alasan-simpan')));
      await tester.pumpAndSettle();

      expect(isian.titikSesi.titikDenganNominal(300)!.aktif, isFalse);
      expect(
        isian.titikSesi.titik,
        hasLength(10),
        reason: 'tidak ada yang dihapus',
      );
      expect(find.textContaining('nonaktif — alat macet'), findsOneWidget);
    });

    testWidgets('titik pelanggan tanpa alasan ditahan di dialog', (
      tester,
    ) async {
      final isian = await pasang(tester);
      // Kosongkan satu slot aktif dulu (maks 10).
      isian.nonaktifkanTitikSesi(
        isian.titikSesi.titikDenganNominal(240)!.id,
        'tidak dipakai',
      );

      await tester.tap(find.byKey(const ValueKey('titik-sesi-tambah')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('titik-sesi-nominal')),
        '75',
      );
      await tester.tap(find.text('Permintaan pelanggan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('titik-sesi-simpan')));
      await tester.pumpAndSettle();

      expect(isian.titikSesi.titikDenganNominal(75), isNull);
      expect(find.textContaining('wajib menyebut dasarnya'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('titik-sesi-alasan-tambah')),
        'PO-123',
      );
      await tester.tap(find.byKey(const ValueKey('titik-sesi-simpan')));
      await tester.pumpAndSettle();

      final t = isian.titikSesi.titikDenganNominal(75)!;
      expect(t.asal, AsalTitik.pelanggan);
      expect(t.alasan, 'PO-123');
    });
  });

  group('temuan peninjau PR #213', () {
    Map<String, dynamic> setServer(int revisi, {double? nonaktif}) => {
      'revisi': revisi,
      'titik': [
        for (final p in bawaanTimer())
          {
            ...p,
            if (p['nominal'] == nonaktif) 'aktif': false,
            if (p['nominal'] == nonaktif) 'alasan': 'dari HP lain',
          },
      ],
    };

    MetaTitikSesi meta(int revisi, {double? nonaktif}) =>
        MetaTitikSesi.dariJson({
          'batas': batasTimer(),
          'set': setServer(revisi, nonaktif: nonaktif),
          'di_luar_cmc': <String>[],
        })!;

    test('foto/OCR tidak mengisi kotak kosong titik nonaktif', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      isian.nonaktifkanTitikSesi(
        isian.titikSesi.titikDenganNominal(300)!.id,
        'alat macet',
      );

      final terisi = isian.terapkanHasilFotoTabel([
        (
          titikUkur: 300,
          repeatNo: t.pengulangan.first,
          fieldId: 'menit',
          teks: '5',
          keyakinan: 0.99,
        ),
        (
          titikUkur: 60,
          repeatNo: t.pengulangan.first,
          fieldId: 'menit',
          teks: '1',
          keyakinan: 0.99,
        ),
      ], tabel: t);

      expect(terisi, 1);
      expect(baris(isian, 300).kotak(t.kunciTabel, 'menit', 0).text, isEmpty);
      expect(baris(isian, 60).kotak(t.kunciTabel, 'menit', 0).text, '1');
    });

    test('409 menonaktifkan titik berisi angka belum tersimpan → wajib '
        'dipilih; "buang" mengembalikan isian server', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      isian.muatTitikSesi(meta(2));
      baris(isian, 600).kotak(t.kunciTabel, 'menit', 0).text = '10';
      isian.tandaiIsianTersimpan(); // 10 = tersimpan di server

      baris(isian, 600).kotak(t.kunciTabel, 'menit', 1).text = '11'; // baru
      baris(isian, 900).kotak(t.kunciTabel, 'menit', 0).text = '15'; // baru

      expect(isian.terapkanSetServer(setServer(3, nonaktif: 600)), isTrue);

      final bentrok = isian.titikNonaktifBerisiBelumTersimpan();
      expect(bentrok.map((x) => x.nominal), [600]);
      // Tidak ada yang dibuang diam-diam.
      expect(baris(isian, 600).kotak(t.kunciTabel, 'menit', 1).text, '11');

      isian.pulihkanIsianTersimpan(600);
      expect(baris(isian, 600).kotak(t.kunciTabel, 'menit', 0).text, '10');
      expect(baris(isian, 600).kotak(t.kunciTabel, 'menit', 1).text, isEmpty);
      expect(baris(isian, 900).kotak(t.kunciTabel, 'menit', 0).text, '15');
      expect(isian.titikNonaktifBerisiBelumTersimpan(), isEmpty);
    });

    test('409 → "aktifkan lagi" menyimpan angkanya dan membuka barisnya', () {
      final isian = isianTimer();
      final t = tabelStandar(isian);
      isian.muatTitikSesi(meta(2));
      isian.tandaiIsianTersimpan();
      baris(isian, 600).kotak(t.kunciTabel, 'menit', 0).text = '10';

      isian.terapkanSetServer(setServer(3, nonaktif: 600));
      final id = isian.titikNonaktifBerisiBelumTersimpan().single.id;

      expect(isian.aktifkanTitikSesi(id), isNull);
      expect(isian.titikNonaktifBerisiBelumTersimpan(), isEmpty);
      expect(baris(isian, 600).kotak(t.kunciTabel, 'menit', 0).text, '10');
      expect(isian.titikSesi.diubahLokal, isTrue);
      expect(
        ((kirim(isian)['titik_sesi'] as Map)['titik'] as List)
            .cast<Map>()
            .firstWhere((x) => x['nominal'] == 600)['aktif'],
        isTrue,
      );
    });

    test('salinan HP lebih lama dari set server: set server menang, '
        'angka salinan tetap', () {
      final lama = isianTimer();
      final t = tabelStandar(lama);
      lama.muatTitikSesi(meta(2));
      lama.nonaktifkanTitikSesi(
        lama.titikSesi.titikDenganNominal(240)!.id,
        'lokal saja',
      );
      baris(lama, 60).kotak(t.kunciTabel, 'menit', 0).text = '1';
      final salinan =
          jsonDecode(jsonEncode(lama.salinanLokal())) as Map<String, dynamic>;

      final baru = isianTimer();
      baru.muatTitikSesi(meta(5, nonaktif: 600));
      baru.pulihkanSalinanLokal(salinan);

      expect(baru.titikSesi.revisi, 5);
      expect(baru.titikSesi.titikDenganNominal(600)!.aktif, isFalse);
      expect(baru.titikSesi.titikDenganNominal(240)!.aktif, isTrue);
      expect(baris(baru, 60).kotak(t.kunciTabel, 'menit', 0).text, '1');

      // Salinan yang SAMA baru dengan server: salinan (perubahan lokal) menang.
      final sama = isianTimer();
      sama.muatTitikSesi(meta(2));
      sama.pulihkanSalinanLokal(salinan);
      expect(sama.titikSesi.titikDenganNominal(240)!.aktif, isFalse);
    });

    test('set server tetap mengunci baris walau tabelnya tak terpetakan '
        '(TIDS)', () {
      final m =
          jsonDecode(
                File('test/fixtures/lembar-kerja-tids.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson((m['data'] ?? m) as Map<String, dynamic>),
        clientRequestId: 'uji-tids',
      )..alat = alat;
      isian.muatTitikSesi(
        MetaTitikSesi.dariJson({
          'batas': {
            'didukung': true,
            'tabel': [
              {
                'kode': 'utama',
                'min': 1,
                'maks': 7,
                'nominal': 'bebas',
                'boleh_tambah': true,
              },
            ],
          },
          'set': {
            'revisi': 1,
            'titik': [
              {'id': 'a', 'nominal': 50, 'aktif': false, 'alasan': 'rusak'},
              {'id': 'b', 'nominal': 100},
            ],
          },
        }),
      );
      expect(isian.titikSesiAktif, isFalse, reason: 'tabel tak terpetakan');

      final tabel = isian.bentuk.bagian
          .expand((b) => b.tabel)
          .firstWhere((t) => t.berpasangan);
      final b = isian.barisTabel(tabel);
      final r0 = isian.titikUntukBaris(b, 0, tabel)!;
      final r1 = isian.titikUntukBaris(b, 1, tabel)!;
      r0.titikCtl.text = '50';
      r1.titikCtl.text = '100';

      expect(isian.alasanNonaktifUntuk(r0), 'rusak');
      expect(isian.titikBisaDiisi(isian.kunciBaris(b, 0, tabel)), isFalse);
      expect(isian.alasanNonaktifUntuk(r1), isNull);
      expect(
        isian.toSubmission(draft: true).toJson().containsKey('titik_sesi'),
        isFalse,
      );
    });
  });
}
