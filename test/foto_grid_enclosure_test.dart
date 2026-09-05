import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_grid.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Kamera buat lembar ber-GRID (kelima Enclosure: Oven, Bath, Inkubator,
/// Furnace, Refrigerator).
///
/// ## Kenapa gridnya butuh jalur sendiri
///
/// Kertas grid bersumbu **TIGA** — set point × termokopel × pengulangan —
/// sementara satu foto cuma sanggup memberi dua. Sumbu ketiganya karena itu
/// TIDAK ditebak dari citra: dia datang dari blok set point tempat tombolnya
/// ditekan. Aturan yang sama sudah dipakai lembar Conductivity buat slot yang
/// bersatuan dobel.
///
/// Dua sumbu sisanya dijangkar dari citranya, dan yang penting **nomor
/// termokopelnya DIBACA DARI FOTO**, bukan dicocokkan ke layar. Pemilik lab
/// memutuskan urutan kerjanya motret dulu, nomornya belakangan (27 Agt 2026) —
/// jadi waktu tombolnya ditekan, layarnya memang masih kosong.
///
/// Yang dijamin utuh **kebersamaan satu baris**, bukan ketepatan nomornya:
/// nomornya ikut ditaruh di kotaknya sendiri dan ikut ditandai kuning, jadi
/// salah baca kelihatan dan bisa dibetulkan di satu tempat — dan
/// membetulkannya memindahkan barisnya utuh.
void main() {
  const xNo = 60.0;
  const lebarKolom = 280.0;
  const yKepala = 100.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
    keyakinan: keyakinan,
  );

  double xKolom(int k) => 420.0 + k * lebarKolom;

  /// Nomor termokopel SENGAJA nggak urut dan nggak mulai dari 1: kalau
  /// pemetanya diam-diam memakai urutan baris, test yang nomornya 1-2-3 bakal
  /// tetap hijau sambil menyembunyikannya.
  const nomorSensor = [7, 3, 5];

  /// Beda tiap sel — angka yang mendarat di baris/kolom yang salah ketahuan
  /// dari NILAINYA, bukan cuma dari jumlah selnya (yang tetap pas waktu
  /// angkanya cuma ketuker).
  String bacaan(int baris, int kolom) => '12${baris}0,${kolom}1';

  List<TeksTerbaca> fotoGrid({
    Set<String> hilang = const {},
    List<int> nomor = nomorSensor,
  }) {
    final hasil = <TeksTerbaca>[
      for (var k = 0; k < 5; k++)
        if (!hilang.contains('X${k + 1}'))
          kata('X${k + 1}', xKolom(k), yKepala),
    ];

    // Kolom kiri: nomor termokopel apa adanya, lalu dua baris deret yang di
    // kertas ditandai TULISAN, bukan angka.
    final kiri = <String>[
      for (final n in nomor) '$n',
      SetPointGridState.labelIndikator,
      SetPointGridState.labelSuhuRuang,
    ];

    for (var b = 0; b < kiri.length; b++) {
      final y = yBarisPertama + b * tinggiBaris;

      if (!hilang.contains(kiri[b])) {
        // Label dua kata datang sebagai DUA element — begitu ML Kit
        // memulangkannya, dan itu yang bikin `Suhu Ruang` dulu nggak pernah
        // kejangkar.
        var x = xNo;

        for (final potong in kiri[b].split(' ')) {
          hasil.add(kata(potong, x, y));
          x += potong.length * 14 + 6;
        }
      }

      for (var k = 0; k < 5; k++) {
        hasil.add(kata(bacaan(b, k), xKolom(k), y));
      }
    }

    return hasil;
  }

  GridSensorBentuk bentuk() => GridSensorBentuk.fromJson({
    'jumlah_sensor_saran': 3,
    'pengulangan': [1, 2, 3, 4, 5],
    'butuh_channel_untuk': 'recorder',
    'baris_indikator': true,
    'baris_suhu_ruang': true,
    'catatan_sensor_acuan': 'Sensor Acuan = nomor terkecil yang terisi.',
  })!;

  /// Blok set point KOSONG — persis keadaan waktu teknisi menekan tombol foto:
  /// dia baru pulang dari chamber dan belum mengetik apa pun.
  SetPointGridState blok({int barisAwal = 3}) =>
      SetPointGridState(bentuk: bentuk(), jumlahSensorAwal: barisAwal);

  /// Rantai yang dijalankan tombolnya: baca nomor dari foto → petakan.
  HasilPetaTabel petakan(SetPointGridState sp, List<TeksTerbaca> terbaca) {
    const peta = PetaTabelFoto();
    final penanda = sp.penandaBarisFoto(peta.nomorBarisTerbaca(terbaca));

    return peta.petakan(
      terbaca: terbaca,
      titikUkur: penanda.penanda,
      pengulangan: sp.bentuk.pengulangan,
      fieldPerRepeat: const ['pembacaan'],
      labelTercetak: penanda.label,
    );
  }

  group('menemukan nomor termokopel dari kolom kiri', () {
    const peta = PetaTabelFoto();

    test('kepala kolom bernomor polos nggak direbut jadi kolom No.', () {
      // Kertas yang kepala kolomnya `1`..`5` polos, bukan `X1`. Kelimanya
      // bilangan bulat persis seperti nomor termokopel — tapi mereka berjajar
      // MENDATAR, jadi tiap nomornya jatuh di kolomnya sendiri dan nggak pernah
      // punya anggota kedua. Yang menang tetap kolom paling kiri.
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 5; k++) kata('${k + 1}', xKolom(k), yKepala),
        for (var b = 0; b < nomorSensor.length; b++) ...[
          kata('${nomorSensor[b]}', xNo, yBarisPertama + b * tinggiBaris),
          for (var k = 0; k < 5; k++)
            kata(bacaan(b, k), xKolom(k), yBarisPertama + b * tinggiBaris),
        ],
      ];

      expect(peta.nomorBarisTerbaca(terbaca), nomorSensor);
    });

    test('pembacaan berkoma nggak pernah dianggap nomor', () {
      // `121,5` bukan bilangan bulat, jadi dia nggak pernah masuk daftar calon.
      // Ini yang bikin kolom pembacaan nggak bisa menyamar jadi kolom No.
      final terbaca = <TeksTerbaca>[
        for (var b = 0; b < 3; b++)
          kata('12${b}0,5', xNo, yBarisPertama + b * tinggiBaris),
      ];

      expect(peta.nomorBarisTerbaca(terbaca), isEmpty);
    });

    test('angka bulat besar di kolom kiri dibuang', () {
      // Pembacaan yang kebetulan bulat (`1210`) jauh lebih mungkin daripada
      // termokopel bernomor 1210. Batasnya dipatok, bukan dibiarkan terbuka.
      final terbaca = <TeksTerbaca>[
        for (var b = 0; b < 3; b++)
          kata('${1210 + b}', xNo, yBarisPertama + b * tinggiBaris),
      ];

      expect(peta.nomorBarisTerbaca(terbaca), isEmpty);
    });

    test('kolom Channel di sebelahnya nggak menang atas kolom No.', () {
      // Lembar berkalibrator Recorder punya DUA kolom bilangan bulat di kiri:
      // No. termokopel lalu Channel. Yang dipakai yang paling kiri.
      final terbaca = <TeksTerbaca>[
        for (var b = 0; b < nomorSensor.length; b++) ...[
          kata('${nomorSensor[b]}', xNo, yBarisPertama + b * tinggiBaris),
          kata('${b + 11}', xNo + 90, yBarisPertama + b * tinggiBaris),
        ],
      ];

      expect(peta.nomorBarisTerbaca(terbaca), nomorSensor);
    });
  });

  group('pemetaan foto satu blok set point', () {
    test('25 sel mendarat di termokopel & pengulangan yang benar', () {
      final sp = blok();
      addTearDown(sp.dispose);

      final hasil = petakan(sp, fotoGrid());

      expect(hasil.angkaTakTerpetakan, 0);
      expect(hasil.sel, hasLength(25), reason: '5 baris × 5 pengulangan');

      final peta = {
        for (final s in hasil.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
      };

      for (var b = 0; b < nomorSensor.length; b++) {
        for (var k = 0; k < 5; k++) {
          expect(
            peta['${nomorSensor[b]}.0|${k + 1}'],
            bacaan(b, k),
            reason: 'Termokopel no. ${nomorSensor[b]} kolom ${k + 1} salah.',
          );
        }
      }
    });

    test('baris `Indikator` & `Suhu Ruang` kejangkar dari TULISANNYA', () {
      // Dua baris ini nggak punya angka di kolom kiri. Sebelum jalur label
      // dipakai di sini, keduanya nggak pernah keisi — dan baris Indikator itu
      // satu-satunya bahan budget ketidakpastian set point ini.
      final sp = blok();
      addTearDown(sp.dispose);

      final peta = {
        for (final s in petakan(sp, fotoGrid()).sel)
          '${s.titikUkur}|${s.repeatNo}': s.teks,
      };

      for (var k = 0; k < 5; k++) {
        expect(
          peta['${SetPointGridState.kunciIndikator}|${k + 1}'],
          bacaan(3, k),
        );
        expect(
          peta['${SetPointGridState.kunciSuhuRuang}|${k + 1}'],
          bacaan(4, k),
        );
      }
    });

    test(
      'termokopel yang cuma ada di kertas ikut kebaca, barisnya ditambah',
      () {
        // Kertas memuat empat termokopel, layar cuma disediakan tiga baris.
        // Barisnya ditambah — bukan angkanya dibuang, dan bukan ditarik ke baris
        // terdekat (yang bikin dia mendarat di termokopel yang salah).
        final sp = blok();
        addTearDown(sp.dispose);

        final terbaca = fotoGrid(nomor: const [7, 3, 5, 9]);

        expect(
          const PetaTabelFoto().nomorBarisTerbaca(terbaca),
          const [7, 3, 5, 9],
          reason: 'urut dari ATAS, apa adanya — bukan diurutkan naik',
        );

        sp.terapkanHasilFoto(petakan(sp, terbaca).sel);

        expect(sp.sensor, hasLength(4));
        expect(sp.sensorTerisi.map((s) => s.no).toList()..sort(), [3, 5, 7, 9]);
      },
    );

    test('kepala kolom yang kepotong nggak nyedot kolom sebelahnya', () {
      final sp = blok();
      addTearDown(sp.dispose);

      final hasil = petakan(sp, fotoGrid(hilang: const {'X4', 'X5'}));

      expect(hasil.repeatKetemu..sort(), const [1, 2, 3]);
      expect(hasil.sel.any((s) => s.repeatNo > 3), isFalse);

      final peta = {
        for (final s in hasil.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
      };

      // Yang kejangkar tetap membawa angkanya sendiri — bukan ikut kehapus
      // gara-gara bentrok dengan angka kolom yang nggak kejangkar.
      for (var b = 0; b < nomorSensor.length; b++) {
        for (var k = 0; k < 3; k++) {
          expect(peta['${nomorSensor[b]}.0|${k + 1}'], bacaan(b, k));
        }
      }
    });
  });

  group('menempelkan hasilnya ke kotak isian', () {
    test('angkanya masuk ke baris & kolom yang benar, dan ditandai', () {
      final sp = blok();
      addTearDown(sp.dispose);

      final terisi = sp.terapkanHasilFoto(petakan(sp, fotoGrid()).sel);

      expect(terisi, 25);

      for (var b = 0; b < nomorSensor.length; b++) {
        final baris = sp.sensor.firstWhere((s) => s.no == nomorSensor[b]);

        expect(
          baris.noDariFoto,
          isTrue,
          reason:
              'nomornya juga dibaca dari foto — kotak yang PALING penting '
              'diadu ke kertas, karena salah baca di sini memindahkan seluruh '
              'barisnya',
        );

        for (var k = 0; k < 5; k++) {
          expect(baris.pembacaanCtl[k].text, bacaan(b, k));
          expect(
            baris.dariFoto.contains(k),
            isTrue,
            reason: 'sel dari foto wajib ditandai buat dicek',
          );
        }
      }

      expect(sp.indikator.ctl[0].text, bacaan(3, 0));
      expect(sp.suhuRuang.ctl[4].text, bacaan(4, 4));
    });

    test('nilai yang SUDAH diketik nggak pernah ditimpa', () {
      // Foto itu jalan pintas; angka yang sudah diketik orang keputusan orang.
      // Menimpanya diam-diam menghapus koreksi yang baru saja dibetulkan
      // teknisi, tanpa satu pun tanda.
      final sp = blok();
      addTearDown(sp.dispose);

      // Teknisi sudah mengetik baris no. 3 duluan — nomornya DAN satu selnya.
      final baris = sp.sensor.first;
      baris.noCtl.text = '3';
      baris.pembacaanCtl[2].text = '999,99';

      sp.terapkanHasilFoto(petakan(sp, fotoGrid()).sel);

      expect(baris.pembacaanCtl[2].text, '999,99');
      expect(baris.dariFoto.contains(2), isFalse);
      expect(
        baris.noDariFoto,
        isFalse,
        reason: 'nomor yang diketik orang nggak ditimpa maupun ditandai',
      );
    });

    test('`pembacaan` ikut terurai, bukan cuma teks di kotaknya', () {
      // Kotak teks terisi tapi nilai di baliknya belum itu jebakan yang sudah
      // pernah kejadian di grid ini: `sensorTerisi`, lencana Sensor Acuan, dan
      // daftar peringatan semuanya membaca `pembacaan`, bukan controller-nya.
      // Teknisi diberi tahu "belum ada termokopel yang diisi" sambil menatap
      // grid yang penuh.
      final sp = blok();
      addTearDown(sp.dispose);

      sp.terapkanHasilFoto(petakan(sp, fotoGrid()).sel);

      expect(sp.sensorTerisi, hasLength(3));
      expect(sp.nomorAcuan, 3, reason: 'nomor terkecil yang terisi');
      expect(sp.peringatan('Constant'), isEmpty);
    });
  });

  group('tombolnya di layar', () {
    Future<GridSensorState> pasang(WidgetTester tester) async {
      final state = GridSensorState(bentuk: bentuk());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: LembarKerjaGrid(
              pemilik: 'uji',
                  state: state,
                  satuanSuhu: '°C',
                  onBerubah: () {},
                  merkKalibrator: 'Constant',
                ),
              ),
            ),
          ),
        ),
      );

      return state;
    }

    testWidgets('tiap blok set point punya tombol fotonya sendiri', (
      tester,
    ) async {
      final state = await pasang(tester);

      expect(find.byKey(const Key('grid_foto_1')), findsOneWidget);

      final tambah = find.byKey(const Key('grid_tambah_set_point'));
      await tester.ensureVisible(tambah);
      await tester.pump();
      await tester.tap(tambah);
      await tester.pump();

      expect(state.setPoint, hasLength(2));
      expect(find.byKey(const Key('grid_foto_2')), findsOneWidget);
    });

    testWidgets('saklar mati → tombolnya nggak digambar', (tester) async {
      final state = GridSensorState(bentuk: bentuk());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: LembarKerjaGrid(
              pemilik: 'uji',
                  state: state,
                  satuanSuhu: '°C',
                  onBerubah: () {},
                  pindaiAktif: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('grid_foto_1')), findsNothing);
    });

    testWidgets('tombolnya bisa ditekan walau layarnya masih kosong', (
      tester,
    ) async {
      // Itu justru keadaan normalnya: teknisi baru pulang dari chamber, motret
      // dulu, nomornya belakangan. Nggak boleh ada penjagaan yang menahannya
      // sampai dia mengetik sesuatu.
      final state = await pasang(tester);

      expect(state.setPoint.first.sensorTerisi, isEmpty);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('grid_foto_1')))
            .onPressed,
        isNotNull,
      );
    });
  });

  /// **Nomor pengulangan yang TERCETAK, bukan posisinya.**
  ///
  /// `terapkanHasilFoto` dulu memakai `repeatNo - 1` sebagai posisi kolom —
  /// pengandaian diam-diam bahwa deretnya selalu `1, 2, 3, …`.
  /// `GridSensorBentuk.fromJson` nerima deret angka apa pun, jadi pengandaian
  /// itu nggak dijamin siapa-siapa.
  ///
  /// Kertas bernomor `2, 4, 6` bikin DUA hal salah sekaligus, dan yang pertama
  /// yang lebih mahal:
  ///
  ///  1. Angka kolom `2` mendarat di posisi 1 — itu kolom `4`. Angkanya wajar,
  ///     kolomnya bukan miliknya, dan nggak ada yang gagal.
  ///  2. Kolom `4` & `6` jatuh di luar batas lalu dilewat diam-diam.
  ///
  /// Sekarang posisinya dicari lewat `bentuk.pengulangan`, jadi yang menentukan
  /// urutan TERCETAKnya.
  group('nomor pengulangan yang nggak mulai dari 1', () {
    SetPointGridState blokBernomor(List<int> pengulangan) => SetPointGridState(
      bentuk: GridSensorBentuk.fromJson({
        'jumlah_sensor_saran': 1,
        'pengulangan': pengulangan,
        'butuh_channel_untuk': 'recorder',
        'baris_indikator': false,
        'baris_suhu_ruang': false,
        'catatan_sensor_acuan': '',
      })!,
      jumlahSensorAwal: 1,
    );

    List<SelTabelFoto> sel(List<int> repeat) => [
      for (var i = 0; i < repeat.length; i++)
        (
          titikUkur: 7.0,
          repeatNo: repeat[i],
          fieldId: 'pembacaan',
          teks: '120,${i + 1}',
          keyakinan: null,
        ),
    ];

    test('deret `2, 4, 6`: ketiganya mendarat di kolomnya sendiri', () {
      final sp = blokBernomor(const [2, 4, 6]);

      expect(
        sp.terapkanHasilFoto(sel(const [2, 4, 6])),
        3,
        reason:
            'Dengan `repeatNo - 1`, cuma kolom `2` yang keisi — di posisi yang '
            'salah — dan dua sisanya kebuang di pemeriksaan batas.',
      );

      expect(sp.sensor.first.pembacaanCtl.map((c) => c.text).toList(), [
        '120,1',
        '120,2',
        '120,3',
      ]);
    });

    test('deret `1..5` biasa nggak bergeser sedikit pun', () {
      // Penjaga arah sebaliknya: sembilan belas lembar lain deretnya memang
      // `1..5`, dan `indexOf` wajib memulangkan angka yang sama persis dengan
      // pengurangan satu.
      final sp = blokBernomor(const [1, 2, 3, 4, 5]);

      expect(sp.terapkanHasilFoto(sel(const [1, 3, 5])), 3);

      expect(sp.sensor.first.pembacaanCtl.map((c) => c.text).toList(), [
        '120,1',
        '',
        '120,2',
        '',
        '120,3',
      ]);
    });

    test('nomor yang nggak ada di kertasnya dilewat, bukan dipaksa masuk', () {
      final sp = blokBernomor(const [2, 4, 6]);

      expect(sp.terapkanHasilFoto(sel(const [3])), 0);
      expect(sp.sensor.first.pembacaanCtl.every((c) => c.text.isEmpty), isTrue);
    });
  });

  group('label buat contoh latih grid', () {
    // Nomor pengulangannya diterjemahkan lewat `bentuk.pengulangan` yang SAMA
    // dipakai `terapkanHasilFoto`. Dua cara yang beda bikin labelnya menempel
    // di potongan sel yang salah — jenis kesalahan yang nggak pernah
    // kelihatan, karena yang salah cuma data latihnya.

    test('labelnya angka yang beneran ada di sel itu', () {
      final sp = blok();

      sp.terapkanHasilFoto(petakan(sp, fotoGrid()).sel);

      for (final s in petakan(sp, fotoGrid()).sel) {
        expect(
          sp.labelSelFoto(s.titikUkur, s.repeatNo),
          s.teks,
          reason: 'titik ${s.titikUkur} Repeat ${s.repeatNo}',
        );
      }
    });

    test('Repeat yang nggak ada di daftar pengulangan balik null', () {
      final sp = blok();

      expect(
        sp.labelSelFoto(petakan(sp, fotoGrid()).sel.first.titikUkur, 9999),
        isNull,
      );
    });
  });
}
