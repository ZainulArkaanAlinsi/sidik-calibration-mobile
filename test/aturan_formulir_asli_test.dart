import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/aturan_formulir_asli.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Aturan nalar formulir 0541 (Anak Timbangan). Vektor positif dari nilai
/// blok di prompt pemilik (blok 8: nominal 50, Standard 49.99992, UUT
/// 50.00012; neraca resolusi 0,00001 g). Aturan HANYA menurunkan warna.
void main() {
  const res = 0.00001; // PX85 (riset 01-riset-0541)

  SelAturanMasuk sel(
    String tabel,
    String teks, {
    int blok = 8,
    int repeat = 1,
    String? nominal = '50',
    double? resolusi = res,
    int? desimal,
    bool gagal = false,
  }) => (
    kunci: '$tabel|$blok|$repeat|pembacaan',
    tabelId: tabel,
    barisKe: blok,
    repeatNo: repeat,
    teks: teks,
    gagalDibaca: gagal,
    resolusi: resolusi,
    desimal: desimal,
    teksNominal: nominal,
  );

  List<SelAturanMasuk> blok8({
    String s1 = '49.99992',
    String t1 = '50.00012',
    String t2 = '50.00013',
    String s2 = '49.99992',
    String? nominal = '50',
  }) => [
    sel('at_s1', s1, nominal: nominal),
    sel('at_t1', t1, nominal: nominal),
    sel('at_t2', t2, nominal: nominal),
    sel('at_s2', s2, nominal: nominal),
  ];

  test('berlaku hanya untuk template anak_timbangan', () {
    expect(AturanFormulirAsli.berlakuUntuk('anak_timbangan'), isTrue);
    expect(AturanFormulirAsli.berlakuUntuk('ph_meter'), isFalse);
  });

  test('vektor blok 8 yang wajar: tidak ada yang diturunkan', () {
    expect(AturanFormulirAsli.periksa(blok8()), isEmpty);
    // Koma desimal Indonesia sama saja.
    expect(
      AturanFormulirAsli.periksa(
        blok8(s1: '49,99992', t1: '50,00012', t2: '50,00013', s2: '49,99992'),
      ),
      isEmpty,
    );
  });

  group('desimal lawan resolusi neraca', () {
    test('4.999992 untuk nominal 5 (6 desimal, neraca 5) → kuning', () {
      final p = AturanFormulirAsli.periksa([
        sel('at_s1', '4.999992', blok: 1, nominal: '5'),
      ]);
      expect(p['at_s1|1|1|pembacaan']!.vonis, VonisAturan.kuning);
      expect(
        p['at_s1|1|1|pembacaan']!.alasan,
        contains(AlasanAturan.desimalTakCocok),
      );
    });

    test('desimal eksplisit server menang atas turunan resolusi', () {
      final p = AturanFormulirAsli.periksa([
        sel('at_t1', '50.0001', desimal: 4),
      ]);
      expect(p, isEmpty);
    });

    test('tanpa resolusi & desimal: dilewati, bukan dikarang', () {
      final p = AturanFormulirAsli.periksa([
        sel('at_t1', '50.1', resolusi: null),
      ]);
      expect(p, isEmpty);
    });

    test('desimalDariResolusi sama dengan server', () {
      expect(desimalDariResolusi(0.00001), 5);
      expect(desimalDariResolusi(0.0001), 4);
      expect(desimalDariResolusi(0.01), 2);
      expect(desimalDariResolusi(1), 0);
      expect(desimalDariResolusi(null), isNull);
    });

    test('desimalTertulis', () {
      expect(desimalTertulis('49,99992'), 5);
      expect(desimalTertulis('50'), 0);
      expect(desimalTertulis('1.000,5'), isNull);
      expect(desimalTertulis('5O.1'), isNull);
    });
  });

  group('Standard lawan nominal blok', () {
    test(
      'koma geser (4.99992 di blok nominal 50) → kuning + MPE belum ada',
      () {
        final p = AturanFormulirAsli.periksa(blok8(s1: '4.99992'));
        final v = p['at_s1|8|1|pembacaan']!;
        expect(v.vonis, VonisAturan.kuning);
        expect(v.alasan, {
          AlasanAturan.standarJauhDariNominal,
          AlasanAturan.mpeBelumTersedia,
        });
      },
    );

    test('MPE dari server dipakai bila ada (tanpa tanda MPE belum ada)', () {
      // 49.99000: 0,01 g dari nominal — di dalam 1% tapi di luar MPE 0,0008.
      final p = AturanFormulirAsli.periksa(
        blok8(s1: '49.99000'),
        mpe: (_) => 0.0008,
      );
      expect(p['at_s1|8|1|pembacaan']!.alasan, {
        AlasanAturan.standarJauhDariNominal,
      });
      // Tanpa MPE, 0,01 g masih di dalam pagar kasar 1% → lolos.
      expect(AturanFormulirAsli.periksa(blok8(s1: '49.99000')), isEmpty);
    });

    test('nominal berbintang 50* = keping kedua, angkanya tetap 50', () {
      expect(uraiNominal('50*'), (nilai: 50.0, kepingKedua: true));
      expect(uraiNominal('20'), (nilai: 20.0, kepingKedua: false));
      expect(uraiNominal('2,5 *'), (nilai: 2.5, kepingKedua: true));
      expect(AturanFormulirAsli.periksa(blok8(nominal: '50*')), isEmpty);
    });

    test('nominal belum diketik: aturan nominal dilewati', () {
      expect(
        AturanFormulirAsli.periksa(blok8(s1: '4.99992', nominal: null)),
        isEmpty,
      );
    });

    test('UUT tidak diadu ke nominal (itu yang dikalibrasi)', () {
      expect(
        AturanFormulirAsli.periksa(blok8(t1: '50.40012')),
        contains('at_t1|8|1|pembacaan'),
      );
      // ... yang menurunkannya aturan dua-UUT, bukan aturan nominal:
      expect(
        AturanFormulirAsli.periksa(
          blok8(t1: '50.40012'),
        )['at_t1|8|1|pembacaan']!.alasan,
        {AlasanAturan.duaUutBerselisih},
      );
    });
  });

  group('dua UUT satu blok & pengulangan', () {
    test('selisih > 10× resolusi → kuning KEDUANYA', () {
      final p = AturanFormulirAsli.periksa(blok8(t2: '50.00112'));
      expect(p['at_t1|8|1|pembacaan']!.vonis, VonisAturan.kuning);
      expect(p['at_t2|8|1|pembacaan']!.vonis, VonisAturan.kuning);
      expect(p.containsKey('at_s1|8|1|pembacaan'), isFalse);
    });

    test('tepat 10× resolusi masih wajar', () {
      expect(AturanFormulirAsli.periksa(blok8(t2: '50.00022')), isEmpty);
    });

    test('pengulangan berbeda tidak dipasangkan', () {
      final p = AturanFormulirAsli.periksa([
        sel('at_t1', '50.00012', repeat: 1),
        sel('at_t2', '50.00912', repeat: 2),
      ]);
      expect(p, isEmpty);
    });
  });

  group('kelengkapan blok', () {
    test('blok kosong total: tidak membuat titik, tidak merah', () {
      expect(
        AturanFormulirAsli.periksa(blok8(s1: '', t1: '', t2: '', s2: '')),
        isEmpty,
      );
    });

    test('blok terisi sebagian: sel kosongnya MERAH "blok tidak lengkap"', () {
      final p = AturanFormulirAsli.periksa(blok8(t2: '', s2: ''));
      expect(p['at_t2|8|1|pembacaan']!.vonis, VonisAturan.merah);
      expect(p['at_t2|8|1|pembacaan']!.alasan, {AlasanAturan.blokTidakLengkap});
      expect(p['at_s2|8|1|pembacaan']!.vonis, VonisAturan.merah);
      expect(p.containsKey('at_s1|8|1|pembacaan'), isFalse);
    });

    test('per kolom pengulangan: X1 penuh, X2 sebagian, X3 kosong total', () {
      List<SelAturanMasuk> kolom(int r, List<String> isi) => [
        for (final (i, t) in const ['at_s1', 'at_t1', 'at_t2', 'at_s2'].indexed)
          sel(t, isi[i], repeat: r),
      ];
      final p = AturanFormulirAsli.periksa([
        ...kolom(1, ['49.99992', '50.00012', '50.00013', '49.99992']),
        ...kolom(2, ['49.99993', '50.00011', '', '']),
        ...kolom(3, ['', '', '', '']),
      ]);

      // X2: S1 & UUT1 ada, UUT2 & S2 kosong → dua-duanya merah.
      expect(p['at_t2|8|2|pembacaan']!.vonis, VonisAturan.merah);
      expect(p['at_s2|8|2|pembacaan']!.alasan, {AlasanAturan.blokTidakLengkap});
      // X1 penuh dan X3 kosong total: tidak disentuh.
      expect(p.keys.where((k) => k.endsWith('|1|pembacaan')), isEmpty);
      expect(p.keys.where((k) => k.endsWith('|3|pembacaan')), isEmpty);
      expect(p, hasLength(2));
    });

    test('dua UUT dibandingkan dalam kolom yang sama saja', () {
      final p = AturanFormulirAsli.periksa([
        sel('at_t1', '50.00012', repeat: 1),
        sel('at_t2', '50.00013', repeat: 1),
        sel('at_t1', '50.00912', repeat: 2),
        sel('at_t2', '50.00012', repeat: 2),
      ]);
      expect(p.keys.toSet(), {'at_t1|8|2|pembacaan', 'at_t2|8|2|pembacaan'});
    });

    test('sel gagal dibaca dihitung "ada", bukan kosong', () {
      final p = AturanFormulirAsli.periksa([
        sel('at_s1', '', gagal: true),
        sel('at_t1', ''),
      ]);
      expect(p['at_t1|8|1|pembacaan']!.vonis, VonisAturan.merah);
      expect(p.containsKey('at_s1|8|1|pembacaan'), isFalse);
    });
  });

  group('terapkan: hanya menurunkan', () {
    const a = AmbangKeyakinan.bawaan;

    test('kuning memotong keyakinan ke pita kuning, tidak menaikkan', () {
      final k = AturanFormulirAsli.terapkan(
        VonisAturan.kuning,
        teks: '50.00012',
        keyakinan: 0.97,
      );
      expect(k, (teks: '50.00012', keyakinan: a.kuning));
      expect(NilaiVonisFoto.dari(k.keyakinan), VonisFoto.kuning);

      // Sudah merah (0.0) tetap merah; null tetap null (tak diketahui).
      expect(
        AturanFormulirAsli.terapkan(
          VonisAturan.kuning,
          teks: '',
          keyakinan: 0.0,
        ).keyakinan,
        0.0,
      );
      expect(
        AturanFormulirAsli.terapkan(
          VonisAturan.kuning,
          teks: 'x',
          keyakinan: null,
        ).keyakinan,
        isNull,
      );
    });

    test('merah mengosongkan, tetap tidak mengubah apa pun', () {
      expect(
        AturanFormulirAsli.terapkan(
          VonisAturan.merah,
          teks: '50.00012',
          keyakinan: 0.97,
        ),
        (teks: '', keyakinan: 0.0),
      );
      expect(
        AturanFormulirAsli.terapkan(
          VonisAturan.tetap,
          teks: '50.00012',
          keyakinan: 0.5,
        ),
        (teks: '50.00012', keyakinan: 0.5),
      );
    });

    test('vonis gabungan memilih yang lebih parah', () {
      // Blok sebagian (merah untuk kosong) + desimal salah (kuning) di sel lain.
      final p = AturanFormulirAsli.periksa(blok8(s1: '49.9999', s2: ''));
      expect(p['at_s1|8|1|pembacaan']!.vonis, VonisAturan.kuning);
      expect(p['at_s2|8|1|pembacaan']!.vonis, VonisAturan.merah);
    });
  });

  test('AturanSelAsli membaca resolusi & desimal dari JSON server', () {
    final a = AturanSelAsli.dari({
      'tipe': 'desimal',
      'nominal': 50,
      'resolusi': 0.00001,
      'desimal': 5,
    })!;
    expect(a.resolusi, 0.00001);
    expect(a.desimal, 5);
    expect(TandaCoretan.values, [TandaCoretan.belumDiperiksa]);
  });

  test('nominal blok dibaca dari baris S1 lembar (boleh berbintang)', () {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAnakTimbangan()),
      clientRequestId: 'uji-aturan-0541',
    );
    final tabel = isian.bentuk.bagian
        .firstWhere((b) => b.kode == 'hasil')
        .tabel;
    final t0 = tabel.first;
    isian.titikUntukBaris(isian.barisTabel(t0), 1, t0)!.titikCtl.text = '50*';

    expect(
      isian.teksNominalFotoAsli(AturanFormulirAsli.tabelNominal, 2),
      '50*',
    );
    expect(isian.teksNominalFotoAsli('at_s1', 1), isNull);
    expect(isian.teksNominalFotoAsli('at_s1', 99), isNull);
  });
}
