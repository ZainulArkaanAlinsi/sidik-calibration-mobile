// LajurBacaan: panel gelap untuk sel yang sedang diisi (angka besar Plex Mono,
// keypad besar, "Berikutnya" tinggi). Tanpa selisih, vonis, atau hijau/merah.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/palet_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_lajur.dart';
import 'package:sidik_calibration/widgets/sidik/lajur_bacaan.dart';

import '../support/komponen_uji.dart';

/// Tuan rumah: menyimpan nilai dan mencatat setiap panggilan.
class _Tuan extends StatefulWidget {
  const _Tuan({
    this.awal = '',
    this.mode,
    this.onBerikutnya,
    this.berikutnyaMati = false,
    this.alasan,
    this.satuan = '°C',
    this.catatan,
    this.pengulangan = (ke: 3, dari: 5),
    this.onPapanKetik,
    this.onKeypad,
    this.judul = 'Set point 150 °C',
    this.perubahan,
  });

  final String awal;
  final ModeLajur? mode;
  final VoidCallback? onBerikutnya;
  final bool berikutnyaMati;
  final String? alasan;
  final String? satuan;
  final String? catatan;
  final ({int ke, int dari})? pengulangan;
  final VoidCallback? onPapanKetik;
  final VoidCallback? onKeypad;
  final String judul;
  final List<String>? perubahan;

  @override
  State<_Tuan> createState() => _TuanState();
}

class _TuanState extends State<_Tuan> {
  late String nilai = widget.awal;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: LajurBacaan(
      mode: widget.mode,
      judul: widget.judul,
      subjudul: 'Detik ke-20',
      posisi: (ke: 8, dari: 30),
      pengulangan: widget.pengulangan,
      nilai: nilai,
      satuan: widget.satuan,
      catatan: widget.catatan,
      alasanMati: widget.alasan,
      onPakaiPapanKetik: widget.onPapanKetik,
      onPakaiKeypad: widget.onKeypad,
      onUbah: (v) {
        widget.perubahan?.add(v);
        setState(() => nilai = v);
      },
      onBerikutnya: widget.berikutnyaMati
          ? null
          : (widget.onBerikutnya ?? () {}),
    ),
  );
}

Future<void> _pasang(
  WidgetTester tester,
  Widget tuan, {
  double lebar = 392,
  double tinggi = 852,
  double skala = 1.0,
  bool gelap = false,
}) async {
  layarUji(tester, lebar: lebar, tinggi: tinggi);
  await tester.pumpWidget(
    aplikasiUji(tuan, bergulir: false, gelap: gelap, skala: skala),
  );
  await tester.pumpAndSettle();
}

Finder _kunci(String k) => find.byKey(Key('keypad-$k'));

Future<void> _ketik(WidgetTester tester, String urutan) async {
  for (final c in urutan.split('')) {
    final kunci = switch (c) {
      ',' => 'koma',
      '-' => 'minus',
      '<' => 'hapus',
      _ => c,
    };
    await tester.tap(_kunci(kunci));
    await tester.pump();
  }
}

String _nilaiTampil(WidgetTester tester) {
  final f = find.byKey(const Key('lajur-nilai'));
  return f.evaluate().isEmpty ? '' : tester.widget<Text>(f).data!;
}

void main() {
  setUpAll(muatFontUji);

  group('mengetik lewat keypad: aturan keypad yang sudah ada', () {
    testWidgets('digit, koma desimal, hapus', (tester) async {
      final riwayat = <String>[];
      await _pasang(tester, _Tuan(perubahan: riwayat));
      await _ketik(tester, '150,0');
      expect(_nilaiTampil(tester), '150,0');
      expect(riwayat, ['1', '15', '150', '150,', '150,0']);
      await _ketik(tester, '<');
      expect(_nilaiTampil(tester), '150,');
    });

    testWidgets('koma kedua diabaikan dan tidak memanggil onUbah', (
      tester,
    ) async {
      final riwayat = <String>[];
      await _pasang(tester, _Tuan(awal: '15', perubahan: riwayat));
      await _ketik(tester, ',');
      await _ketik(tester, ',');
      expect(_nilaiTampil(tester), '15,');
      expect(riwayat, ['15,'], reason: 'ketukan tanpa efek tidak melapor');
    });

    testWidgets('koma ditolak bila nilai sudah memakai titik', (tester) async {
      await _pasang(tester, const _Tuan(awal: '15.5'));
      await _ketik(tester, ',');
      expect(_nilaiTampil(tester), '15.5');
    });

    testWidgets('tidak ada nol yang disisipkan sendiri: koma di sel kosong', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan());
      await _ketik(tester, ',');
      expect(_nilaiTampil(tester), ',');
    });

    testWidgets('minus membalik tanda di depan; hapus pada kosong aman', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '4'));
      await _ketik(tester, '-');
      expect(_nilaiTampil(tester), '-4');
      await _ketik(tester, '-');
      expect(_nilaiTampil(tester), '4');
      await _ketik(tester, '<<<');
      expect(find.byKey(const Key('lajur-nilai')), findsNothing);
      expect(find.byKey(const Key('lajur-kosong')), findsOneWidget);
    });

    testWidgets('panjang paling banyak 12 karakter', (tester) async {
      await _pasang(tester, const _Tuan(awal: '12345678901'));
      await _ketik(tester, '2');
      await _ketik(tester, '3');
      expect(_nilaiTampil(tester), '123456789012');
    });

    testWidgets('semua digit 0-9 ada dan bekerja', (tester) async {
      await _pasang(tester, const _Tuan());
      await _ketik(tester, '7894561230');
      expect(_nilaiTampil(tester), '7894561230');
    });
  });

  group('Berikutnya', () {
    testWidgets('merentang tiga baris keypad: 3 x 52 + 2 x 8 = 172 dp', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '150,0'));
      final b = tester.getRect(find.byKey(const Key('lajur-berikutnya')));
      expect(b.height, 172);
      expect(b.height, greaterThanOrEqualTo(3 * 52));
      final hapus = tester.getRect(_kunci('hapus'));
      expect(b.top, greaterThanOrEqualTo(hapus.bottom));
      expect(b.left, hapus.left);
      expect(b.right, hapus.right);
      final koma = tester.getRect(_kunci('koma'));
      expect(b.bottom, koma.bottom, reason: 'sejajar dengan baris terbawah');
    });

    testWidgets(
      'ketuk memanggil onBerikutnya; sel kosong tidak menyalin apa pun',
      (tester) async {
        var n = 0;
        final riwayat = <String>[];
        await _pasang(
          tester,
          _Tuan(onBerikutnya: () => n++, perubahan: riwayat),
        );
        await tester.tap(find.byKey(const Key('lajur-berikutnya')));
        expect(n, 1);
        expect(riwayat, isEmpty, reason: 'sel kosong tetap kosong');
      },
    );

    testWidgets('mati: alasan tampil, ketukan diabaikan, kata tetap terbaca', (
      tester,
    ) async {
      var n = 0;
      await _pasang(
        tester,
        _Tuan(
          awal: '25',
          berikutnyaMati: true,
          onBerikutnya: () => n++,
          alasan: 'Sel terakhir. Gunakan Kirim ke admin.',
        ),
      );
      expect(
        find.text('Sel terakhir. Gunakan Kirim ke admin.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('lajur-berikutnya')),
        warnIfMissed: false,
      );
      expect(n, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lajur-berikutnya')))
            .onPressed,
        isNull,
      );
      expect(pelanggaranKontrasTeks(tester, find.byType(LajurBacaan)), isEmpty);
    });

    testWidgets('aktif: alasan tidak tampil', (tester) async {
      await _pasang(tester, const _Tuan(alasan: 'Sel terakhir.'));
      expect(find.text('Sel terakhir.'), findsNothing);
    });

    testWidgets(
      'label "Berikutnya" tampil di 392 dp; panah saja bila tak muat',
      (tester) async {
        await _pasang(tester, const _Tuan(awal: '1'));
        expect(find.text('Berikutnya'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        // 280 dp, keypad dipaksa: kolom aksi terlalu sempit untuk kata.
        await _pasang(
          tester,
          const _Tuan(awal: '1', mode: ModeLajur.keypad),
          lebar: 280,
          tinggi: 800,
        );
        expect(find.text('Berikutnya'), findsNothing);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        // Kata tetap dibacakan.
        final semantik = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Berikutnya'), findsOneWidget);
        semantik.dispose();
      },
    );
  });

  group('mode dan ukuran', () {
    test('mode otomatis mengikuti bolehKeypadLayar', () {
      ModeLajur m(Size u, double skala) => LajurBacaan.modeUntuk(
        MediaQueryData(size: u, textScaler: TextScaler.linear(skala)),
      );
      expect(m(const Size(392, 852), 1.0), ModeLajur.keypad);
      expect(m(const Size(392, 852), 1.15), ModeLajur.keypad);
      expect(m(const Size(392, 852), 1.16), ModeLajur.ringkas);
      expect(m(const Size(320, 699), 1.0), ModeLajur.ringkas);
      expect(m(const Size(320, 700), 1.0), ModeLajur.keypad);
      expect(
        m(const Size(852, 392), 1.0),
        ModeLajur.ringkas,
        reason: 'HP lanskap',
      );
      expect(m(const Size(1280, 800), 1.0), ModeLajur.keypad, reason: 'tablet');
    });

    testWidgets('otomatis: keypad di HP lega, ringkas di huruf 1,3x', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '150,0'));
      expect(_kunci('7'), findsOneWidget);
      await _pasang(tester, const _Tuan(awal: '150,0'), skala: 1.3);
      expect(_kunci('7'), findsNothing);
      expect(find.byKey(const Key('lajur-berikutnya')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('lajur-berikutnya'))).height >= 56,
        isTrue,
      );
      await _pasang(
        tester,
        const _Tuan(awal: '150,0'),
        lebar: 392,
        tinggi: 600,
      );
      expect(_kunci('7'), findsNothing, reason: 'layar pendek');
    });

    testWidgets('mode dipaksa mengalahkan otomatis', (tester) async {
      await _pasang(
        tester,
        const _Tuan(awal: '1', mode: ModeLajur.keypad),
        skala: 1.3,
        lebar: 392,
      );
      expect(_kunci('7'), findsOneWidget);
      await _pasang(tester, const _Tuan(awal: '1', mode: ModeLajur.ringkas));
      expect(_kunci('7'), findsNothing);
    });

    testWidgets('tombol keypad 52 dp di HP dan 64 dp di tablet; semua >= 48', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '1'));
      for (final k in [
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        'koma',
        'minus',
        'hapus',
      ]) {
        expect(tester.getSize(_kunci(k)).height, 52, reason: k);
        expect(
          tester.getSize(_kunci(k)).width,
          greaterThanOrEqualTo(48),
          reason: k,
        );
      }
      await _pasang(tester, const _Tuan(awal: '1'), lebar: 1280, tinggi: 800);
      for (final k in ['0', '5', '9', 'koma', 'minus', 'hapus']) {
        expect(tester.getSize(_kunci(k)).height, 64, reason: k);
      }
      expect(
        tester.getSize(find.byKey(const Key('lajur-berikutnya'))).height,
        3 * 64 + 2 * 8,
      );
    });

    testWidgets('isi dibatasi 560 dp di layar lebar, panel penuh lebar', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '1'), lebar: 1280, tinggi: 800);
      expect(tester.getSize(find.byType(LajurBacaan)).width, 1280);
      final kiri = tester.getRect(_kunci('7')).left;
      final kanan = tester
          .getRect(find.byKey(const Key('lajur-berikutnya')))
          .right;
      expect(kanan - kiri, lessThanOrEqualTo(560 - 32));
    });

    testWidgets('tinggi panel mengikuti isi, bukan memenuhi layar', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '1'));
      final tinggi = tester.getSize(find.byType(LajurBacaan)).height;
      expect(tinggi, lessThan(852 / 2));
      expect(tinggi, greaterThan(300));
    });

    testWidgets('ringkas: tanpa keypad, tombol Berikutnya 56 dp penuh lebar', (
      tester,
    ) async {
      await _pasang(
        tester,
        const _Tuan(awal: '150,0', mode: ModeLajur.ringkas),
        lebar: 320,
        tinggi: 568,
        skala: 1.3,
      );
      expect(_kunci('7'), findsNothing);
      final b = tester.getRect(find.byKey(const Key('lajur-berikutnya')));
      expect(b.height, greaterThanOrEqualTo(56));
      expect(b.width, 320 - 32);
      expect(find.text('Berikutnya'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('tampilan angka', () {
    testWidgets(
      'Plex Mono 500, 40 sp di HP dan 56 sp di tablet, digit lebar tetap',
      (tester) async {
        await _pasang(tester, const _Tuan(awal: '150,0'));
        var gaya = tester
            .widget<Text>(find.byKey(const Key('lajur-nilai')))
            .style!;
        expect(gaya.fontFamily, 'IBMPlexMono');
        expect(gaya.fontWeight, FontWeight.w500);
        expect(gaya.fontSize, 40);
        expect(gaya.fontFeatures, contains(const FontFeature.tabularFigures()));
        await _pasang(
          tester,
          const _Tuan(awal: '150,0'),
          lebar: 1280,
          tinggi: 800,
        );
        gaya = tester.widget<Text>(find.byKey(const Key('lajur-nilai'))).style!;
        expect(gaya.fontSize, 56);
      },
    );

    testWidgets('kursor kobalt terang dan satuan tampil; tanpa satuan tidak', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '150,0'));
      final w = WarnaLajur.dari(SidikMaterial.terangDefault);
      expect(
        tester.widget<Container>(find.byKey(const Key('lajur-kursor'))).color,
        w.aksen,
      );
      expect(w.aksen, PaletLab.kobalt300);
      expect(find.text('°C'), findsOneWidget);
      await _pasang(tester, const _Tuan(awal: '150,0', satuan: null));
      expect(find.byKey(const Key('lajur-satuan')), findsNothing);
    });

    testWidgets('kosong: kursor dan "Belum diisi", tanpa angka', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan());
      expect(find.byKey(const Key('lajur-nilai')), findsNothing);
      expect(find.byKey(const Key('lajur-kursor')), findsOneWidget);
      expect(find.text('Belum diisi'), findsOneWidget);
    });

    testWidgets(
      '12 karakter + satuan di 320 dp x 1,3 (keypad dipaksa): mengecil, tanpa luapan',
      (tester) async {
        await _pasang(
          tester,
          const _Tuan(
            awal: '-1234567,890',
            mode: ModeLajur.keypad,
            satuan: 'mbar',
          ),
          lebar: 320,
          tinggi: 800,
          skala: 1.3,
        );
        expect(tester.takeException(), isNull);
        final nilai = tester.getRect(find.byKey(const Key('lajur-nilai')));
        expect(nilai.right, lessThanOrEqualTo(320));
      },
    );

    testWidgets('kepala: judul, subjudul, posisi 8/30 dan tik pengulangan', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '1'));
      expect(find.text('Set point 150 °C'), findsOneWidget);
      expect(find.text('Detik ke-20'), findsOneWidget);
      expect(find.text('8/30'), findsOneWidget);
      // Pengulangan 3 dari 5: 2 lewat, 1 sekarang (lebih tinggi), 2 belum.
      int jumlah(String awalan) => find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(awalan),
          )
          .evaluate()
          .length;
      expect(jumlah('tik-ulang-lewat'), 2);
      expect(jumlah('tik-ulang-kini'), 1);
      expect(jumlah('tik-ulang-nanti'), 2);
      expect(
        tester.getSize(find.byKey(const ValueKey('tik-ulang-kini-3'))).height,
        greaterThan(
          tester
              .getSize(find.byKey(const ValueKey('tik-ulang-lewat-1')))
              .height,
        ),
        reason: 'sekarang ditandai bentuk (lebih tinggi), bukan warna saja',
      );
    });

    testWidgets(
      'pengulangan lebih dari 10: tanpa tik; tanpa pengulangan: tanpa tik',
      (tester) async {
        await _pasang(
          tester,
          const _Tuan(awal: '1', pengulangan: (ke: 3, dari: 11)),
        );
        expect(find.byKey(const ValueKey('tik-ulang-kini-3')), findsNothing);
        await _pasang(tester, const _Tuan(awal: '1', pengulangan: null));
        expect(find.byKey(const ValueKey('tik-ulang-kini-3')), findsNothing);
      },
    );

    testWidgets('judul panjang membungkus paling banyak 2 baris', (
      tester,
    ) async {
      await _pasang(
        tester,
        const _Tuan(
          awal: '1',
          judul:
              'Pembacaan UUT titik ukur 1000 mbar pada pengulangan kelima '
              'dengan nama yang sangat panjang sekali',
        ),
        lebar: 320,
        tinggi: 800,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('batas Lajur: tanpa selisih, vonis, atau hijau/merah', () {
    for (final gelap in [false, true]) {
      testWidgets(
        'tidak memakai warna lulus/gagal dan tidak menulis selisih/vonis '
        '(${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await _pasang(
            tester,
            const _Tuan(
              awal: '150,0',
              catatan: 'Saran dari foto, belum dipastikan.',
              mode: ModeLajur.keypad,
            ),
            gelap: gelap,
          );
          final dipakai = semuaWarna(tester, find.byType(LajurBacaan));
          for (final m in [
            SidikMaterial.terangDefault,
            SidikMaterial.gelapDefault,
          ]) {
            for (final (nama, w) in [
              ('lulus', m.lulus),
              ('lulusTipis', m.lulusTipis),
              ('gagal', m.gagal),
              ('gagalTipis', m.gagalTipis),
            ]) {
              expect(dipakai, isNot(contains(w.withAlpha(255))), reason: nama);
            }
          }
          final teks = semuaTeks(
            tester,
            find.byType(LajurBacaan),
          ).toLowerCase();
          for (final kata in [
            'selisih',
            'pass',
            'fail',
            'lulus',
            'gagal',
            'beda',
          ]) {
            expect(teks, isNot(contains(kata)), reason: kata);
          }
          // Hanya warna Lajur (ditambah tinta/latar tema untuk komponen dasar).
          final w = WarnaLajur.of(tester.element(find.byType(LajurBacaan)));
          final diizinkan = {
            w.panel,
            w.garisAtas,
            w.angka,
            w.redup,
            w.aksen,
            w.tombol,
            w.teksTombol,
            w.kunci,
            w.tepiKunci,
            w.peringatan,
          }.map((c) => c.withAlpha(255)).toSet();
          final lain = dipakai.difference(diizinkan);
          expect(lain, isEmpty, reason: 'warna di luar WarnaLajur: $lain');
        },
      );
    }

    testWidgets(
      'Lajur tidak punya aksi menghitung: hanya digit, koma, minus, hapus, berikutnya',
      (tester) async {
        final semantik = tester.ensureSemantics();
        await _pasang(tester, const _Tuan(awal: '1', mode: ModeLajur.keypad));
        final tombol = find.semantics.byPredicate(
          (n) => n.getSemanticsData().hasAction(SemanticsAction.tap),
        );
        final label = tombol
            .evaluate()
            .map((n) => n.getSemanticsData().label)
            .toList();
        expect(label.toSet(), {
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          'Koma desimal',
          'Tanda minus',
          'Hapus satu karakter',
          'Berikutnya',
        });
        semantik.dispose();
      },
    );
  });

  group('papan ketik sistem sebagai cadangan', () {
    testWidgets(
      'tombol beralih tampil hanya bila diberi, dan memanggil callback',
      (tester) async {
        var n = 0;
        await _pasang(tester, const _Tuan(awal: '1'));
        expect(find.text('Pakai papan ketik sistem'), findsNothing);
        await _pasang(tester, _Tuan(awal: '1', onPapanKetik: () => n++));
        expect(find.text('Pakai papan ketik sistem'), findsOneWidget);
        expect(
          tester
              .getSize(
                find.widgetWithText(TextButton, 'Pakai papan ketik sistem'),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('Pakai papan ketik sistem'));
        expect(n, 1);
      },
    );

    testWidgets('mode ringkas menawarkan kembali ke keypad', (tester) async {
      var n = 0;
      await _pasang(
        tester,
        _Tuan(
          awal: '1',
          mode: ModeLajur.ringkas,
          onKeypad: () => n++,
          onPapanKetik: () {},
        ),
      );
      expect(find.text('Pakai papan ketik sistem'), findsNothing);
      expect(find.text('Pakai keypad angka'), findsOneWidget);
      await tester.tap(find.text('Pakai keypad angka'));
      expect(n, 1);
    });
  });

  group('catatan keadaan sel', () {
    for (final gelap in [false, true]) {
      testWidgets(
        'ikon + kata amber, bukan penilaian (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await _pasang(
            tester,
            const _Tuan(
              awal: '',
              catatan: 'Saran dari foto, belum dipastikan.',
            ),
            gelap: gelap,
          );
          final w = WarnaLajur.of(tester.element(find.byType(LajurBacaan)));
          expect(find.byIcon(Icons.info_outline), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.text('Saran dari foto, belum dipastikan.'))
                .style!
                .color,
            w.peringatan,
          );
          expect(
            tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
            w.peringatan,
          );
        },
      );
    }

    testWidgets('tanpa catatan: tidak ada baris catatan', (tester) async {
      await _pasang(tester, const _Tuan(awal: '1'));
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });
  });

  group('panel', () {
    testWidgets('terang: panel gelap permukaan alat (kaca); sudut atas 20', (
      tester,
    ) async {
      await _pasang(tester, const _Tuan(awal: '1'));
      final dekor = _panel(tester);
      expect(dekor.color, SidikMaterial.terangDefault.kaca);
      expect(dekor.color, PaletLab.latarGelap);
      expect(
        dekor.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(20)),
      );
    });

    testWidgets(
      'gelap: permukaan #171D2B + garis tegas agar tak melebur dengan latar',
      (tester) async {
        await _pasang(tester, const _Tuan(awal: '1'), gelap: true);
        final dekor = _panel(tester);
        final m = SidikMaterial.gelapDefault;
        expect(dekor.color, m.kaca2);
        expect(dekor.color, PaletLab.kertasGelap);
        expect(
          dekor.color,
          isNot(m.meja),
          reason: 'beda dari latar layar gelap',
        );
        expect((dekor.border! as Border).top.color, PaletLab.garisTegasGelap);
      },
    );
  });

  group('pembaca layar', () {
    testWidgets(
      'angka dibacakan sebagai live region; tombol punya label dan aksi',
      (tester) async {
        final semantik = tester.ensureSemantics();
        final riwayat = <String>[];
        await _pasang(
          tester,
          _Tuan(awal: '150,0', mode: ModeLajur.keypad, perubahan: riwayat),
        );
        var data = tester
            .getSemantics(find.bySemanticsLabel('Nilai: 150,0 °C'))
            .getSemanticsData();
        expect(data.flagsCollection.isLiveRegion, isTrue);
        // Tombol keypad bisa diaktifkan lewat semantik (tidak hanya lewat sentuh).
        for (final label in [
          '5',
          'Koma desimal',
          'Tanda minus',
          'Hapus satu karakter',
        ]) {
          tester.semantics.tap(find.semantics.byLabel(label));
          await tester.pump();
        }
        expect(riwayat, [
          '150,05',
          '-150,05',
          '-150,0',
        ], reason: 'koma kedua tidak melapor');
        semantik.dispose();
      },
    );

    testWidgets(
      'kosong dibacakan "belum diisi"; kepala berisi posisi dan pengulangan',
      (tester) async {
        final semantik = tester.ensureSemantics();
        await _pasang(tester, const _Tuan(mode: ModeLajur.keypad));
        expect(find.bySemanticsLabel('Nilai: Belum diisi'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Set point 150 °C, Detik ke-20, 8 dari 30, Pengulangan 3 dari 5',
          ),
          findsOneWidget,
        );
        semantik.dispose();
      },
    );

    testWidgets(
      'Berikutnya: label, aksi ketuk semantik memanggil onBerikutnya',
      (tester) async {
        final semantik = tester.ensureSemantics();
        var n = 0;
        await _pasang(
          tester,
          _Tuan(awal: '1', mode: ModeLajur.keypad, onBerikutnya: () => n++),
        );
        tester.semantics.tap(find.semantics.byLabel('Berikutnya'));
        expect(n, 1);
        semantik.dispose();
      },
    );

    for (final (lebar, tinggi, skala) in [
      (392.0, 852.0, 1.0),
      (320.0, 800.0, 1.3),
    ]) {
      testWidgets(
        'pedoman sentuh + label + kontras (${lebar.toInt()} x $skala)',
        (tester) async {
          final semantik = tester.ensureSemantics();
          for (final gelap in [false, true]) {
            await _pasang(
              tester,
              const _Tuan(
                awal: '150,0',
                mode: ModeLajur.keypad,
                catatan: 'Saran dari foto, belum dipastikan.',
              ),
              lebar: lebar,
              tinggi: tinggi,
              skala: skala,
              gelap: gelap,
            );
            expect(tester.takeException(), isNull);
            await periksaPedomanSentuh(tester);
            expect(
              pelanggaranKontrasTeks(tester, find.byType(LajurBacaan)),
              isEmpty,
              reason: gelap ? 'gelap' : 'terang',
            );
          }
          semantik.dispose();
        },
      );
    }
  });

  group('Berikutnya tidak pernah lompat sendiri', () {
    testWidgets(
      'tidak dipanggil saat mengetik, di batas 12 karakter, atau saat nilai '
      'berubah; hanya oleh tombol Berikutnya',
      (tester) async {
        var n = 0;
        await _pasang(tester, _Tuan(onBerikutnya: () => n++));
        // 13 digit: batas 12 karakter tercapai, digit ke-13 ditolak.
        await _ketik(tester, '1234567890123');
        expect(_nilaiTampil(tester), '123456789012');
        await _ketik(tester, '<<<<<<<<<<<<');
        expect(find.byKey(const Key('lajur-nilai')), findsNothing);
        // Setiap jenis tombol yang mengubah nilai.
        await _ketik(tester, '150,0');
        await _ketik(tester, '-');
        await _ketik(tester, '-');
        await _ketik(tester, '<');
        await tester.pump(const Duration(seconds: 30));
        expect(n, 0, reason: 'mengetik tidak boleh pindah sel');
        await tester.tap(find.byKey(const Key('lajur-berikutnya')));
        expect(n, 1, reason: 'hanya tombol Berikutnya yang pindah sel');
        await tester.tap(find.byKey(const Key('lajur-berikutnya')));
        expect(n, 2);
      },
    );

    testWidgets('aksi semantik digit juga tidak memicu pindah sel', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await _pasang(
        tester,
        _Tuan(mode: ModeLajur.keypad, onBerikutnya: () => n++),
      );
      for (final label in ['1', '5', '0', 'Koma desimal', '0']) {
        tester.semantics.tap(find.semantics.byLabel(label));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 30));
      expect(_nilaiTampil(tester), '150,0');
      expect(n, 0);
      semantik.dispose();
    });

    testWidgets('nilai yang berubah dari luar tidak memanggil onBerikutnya', (
      tester,
    ) async {
      var n = 0;
      Widget lajur(String nilai, {ModeLajur mode = ModeLajur.keypad}) => Align(
        alignment: Alignment.bottomCenter,
        child: LajurBacaan(
          mode: mode,
          judul: 'Set point 150 °C',
          nilai: nilai,
          onUbah: (_) {},
          onBerikutnya: () => n++,
        ),
      );
      layarUji(tester);
      for (final mode in ModeLajur.values) {
        await tester.pumpWidget(
          aplikasiUji(lajur('1', mode: mode), bergulir: false),
        );
        await tester.pumpWidget(
          aplikasiUji(lajur('123456789012', mode: mode), bergulir: false),
        );
        await tester.pumpWidget(
          aplikasiUji(lajur('', mode: mode), bergulir: false),
        );
        await tester.pump(const Duration(seconds: 30));
      }
      expect(n, 0);
    });
  });

  group('urutan baca keypad: per baris', () {
    testWidgets('kelompok "Keypad angka": 7 8 9 hapus, 4 5 6 Berikutnya, ...', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _pasang(tester, const _Tuan(awal: '1', mode: ModeLajur.keypad));
      final kelompok = tester.getSemantics(
        find.bySemanticsLabel('Keypad angka'),
      );
      final urutan = kelompok
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .map((n) => n.getSemanticsData().label)
          .toList();
      expect(urutan, [
        '7',
        '8',
        '9',
        'Hapus satu karakter',
        '4',
        '5',
        '6',
        'Berikutnya',
        '1',
        '2',
        '3',
        'Tanda minus',
        '0',
        'Koma desimal',
      ]);
      semantik.dispose();
    });
  });
}

BoxDecoration _panel(WidgetTester tester) {
  final kotak = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(LajurBacaan),
          matching: find.byType(DecoratedBox),
        ),
      )
      .first;
  return kotak.decoration as BoxDecoration;
}
