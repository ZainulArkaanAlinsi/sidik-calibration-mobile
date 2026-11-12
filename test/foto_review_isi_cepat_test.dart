import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Isi cepat di layar review: urutan kertas, keypad angka dengan koma dan
/// minus, "Konfirmasi dan lanjut" satu ketukan per sel, auto-lanjut. Aturan lama
/// tidak boleh bergeser: tidak ada "terima semua", merah wajib diketik, kuning
/// wajib dicek, sel kosong tidak ikut, tidak ada nilai disalin antar sel.
void main() {
  BarisReviewFoto baris(
    String teks, {
    double? keyakinan,
    required double titikUkur,
    String? judul,
  }) => (
    titikUkur: titikUkur,
    repeatNo: 1,
    fieldId: 'pembacaan',
    judul: judul ?? 'Sel ${titikUkur.round()}',
    teks: teks,
    keyakinan: keyakinan,
    vonis: NilaiVonisFoto.dari(keyakinan),
    potongan: null,
  );

  late List<SelTabelFoto>? hasil;

  Future<void> buka(
    WidgetTester tester,
    List<BarisReviewFoto> isi, {
    Set<String> skorMentah = const {},
    double tinggi = 2400,
  }) async {
    hasil = null;
    // Layar tinggi: daftar dibangun malas, dan tes ini menunjuk baris lewat
    // urutan kotak. (Tes daftar panjang memakai layar biasa.)
    tester.view.physicalSize = Size(800, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              hasil = await Navigator.of(context).push<List<SelTabelFoto>>(
                MaterialPageRoute(
                  builder: (_) =>
                      FotoReviewScreen(baris: isi, kunciSkorMentah: skorMentah),
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  Finder tombol(String kunci) => find.byKey(ValueKey('keypad-$kunci'));
  final konfirmasi = find.byKey(const ValueKey('konfirmasi-lanjut'));
  final mulai = find.byKey(const ValueKey('mulai-isi-cepat'));

  Future<void> ketik(WidgetTester tester, String teks) async {
    for (final c in teks.split('')) {
      await tester.tap(tombol(c == ',' ? 'koma' : (c == '-' ? 'minus' : c)));
      await tester.pump();
    }
  }

  String judulAktif(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('keypad-judul'))).data!;

  String isiKotak(WidgetTester tester, int i) =>
      tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text;

  testWidgets('keypad tersembunyi sampai Isi cepat / ketuk kotak', (
    tester,
  ) async {
    await buka(tester, [baris('4,01', keyakinan: 0.99, titikUkur: 1)]);

    expect(mulai, findsOneWidget);
    expect(konfirmasi, findsNothing);
    expect(tombol('7'), findsNothing);

    await tester.tap(mulai);
    await tester.pumpAndSettle();

    expect(konfirmasi, findsOneWidget);
    expect(mulai, findsNothing, reason: 'sudah berjalan');
    expect(tombol('koma'), findsOneWidget);
    expect(tombol('minus'), findsOneWidget);
    expect(tombol('hapus'), findsOneWidget);
    for (var d = 0; d <= 9; d++) {
      expect(tombol('$d'), findsOneWidget, reason: 'digit $d');
    }
  });

  testWidgets('mengetuk kotak sebuah sel membuka keypad untuk sel itu', (
    tester,
  ) async {
    await buka(tester, [
      baris('4,01', keyakinan: 0.99, titikUkur: 1),
      baris('7,02', keyakinan: 0.99, titikUkur: 2),
    ]);

    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();

    expect(judulAktif(tester), 'Sel 2');
    // Keypad layar aktif: papan ketik sistem ditekan.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).keyboardType,
      TextInputType.none,
    );
  });

  testWidgets(
    'Konfirmasi dan lanjut: periksa sel aktif lalu pindah ke berikutnya',
    (tester) async {
      await buka(tester, [
        baris('4,01', keyakinan: 0.99, titikUkur: 1),
        baris('7,02', keyakinan: 0.99, titikUkur: 2),
        baris('9,00', keyakinan: 0.99, titikUkur: 3),
      ]);

      await tester.tap(mulai);
      await tester.pumpAndSettle();
      expect(judulAktif(tester), 'Sel 1');

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      expect(judulAktif(tester), 'Sel 2');
      expect(find.byKey(const ValueKey('cek-1.0|1|pembacaan')), findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('cek-1.0|1|pembacaan')),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        Icons.check_circle,
        reason: 'sel 1 tercatat sudah dicek',
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('cek-2.0|1|pembacaan')),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        Icons.check_circle_outline,
        reason: 'sel 2 BELUM dicek: satu ketukan hanya untuk satu sel',
      );
    },
  );

  testWidgets(
    'alur penuh: merah diketik lewat keypad, kuning dikonfirmasi, hasil utuh',
    (tester) async {
      await buka(tester, [
        baris('4,01', keyakinan: 0.99, titikUkur: 1),
        baris('7,2', keyakinan: 0.0, titikUkur: 2), // merah: kotak mulai kosong
        baris('7,02', keyakinan: 0.99, titikUkur: 3),
        baris('9,00', titikUkur: 4), // keyakinan tidak diketahui
      ]);

      await tester.tap(mulai);
      await tester.pumpAndSettle();

      // 1: kuning, satu ketukan.
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();

      // 2: merah. Kotak KOSONG (tidak disalin dari sel 1 maupun bacaan mentah),
      // dan konfirmasi mati sampai diketik.
      expect(judulAktif(tester), 'Sel 2');
      expect(isiKotak(tester, 1), isEmpty);
      expect(tester.widget<FilledButton>(konfirmasi).onPressed, isNull);

      await ketik(tester, '-7,03');
      expect(isiKotak(tester, 1), '-7,03');
      expect(tester.widget<FilledButton>(konfirmasi).onPressed, isNotNull);

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();

      // 3 dan 4: kuning/tidak diketahui, masing-masing satu ketukan.
      expect(judulAktif(tester), 'Sel 3');
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      expect(judulAktif(tester), 'Sel 4');
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();

      // Semua beres: keypad menutup sendiri, Masukkan terbuka.
      expect(konfirmasi, findsNothing);
      final masukkan = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(masukkan).onPressed, isNotNull);

      await tester.tap(masukkan);
      await tester.pumpAndSettle();

      expect(hasil!.map((s) => s.teks).toList(), [
        '4,01',
        '-7,03',
        '7,02',
        '9,00',
      ]);
    },
  );

  testWidgets('Konfirmasi tidak pernah mengisi sel merah dari sel lain', (
    tester,
  ) async {
    await buka(tester, [
      baris('4,01', keyakinan: 0.99, titikUkur: 1),
      baris('4,01', keyakinan: 0.0, titikUkur: 2),
    ]);

    await tester.tap(mulai);
    await tester.pumpAndSettle();
    await tester.tap(konfirmasi);
    await tester.pumpAndSettle();

    expect(isiKotak(tester, 1), isEmpty);
    expect(tester.widget<FilledButton>(konfirmasi).onPressed, isNull);
  });

  testWidgets(
    'konfirmasi memutar ke sel yang masih butuh, merah tidak dilewati',
    (tester) async {
      await buka(tester, [
        baris('1,00', keyakinan: 0.99, titikUkur: 1),
        baris('2,00', keyakinan: 0.0, titikUkur: 2),
        baris('3,00', keyakinan: 0.99, titikUkur: 3),
      ]);

      // Mulai langsung dari sel 3 (ketuk kotaknya).
      await tester.tap(find.byType(TextField).at(2));
      await tester.pumpAndSettle();
      expect(judulAktif(tester), 'Sel 3');

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      expect(
        judulAktif(tester),
        'Sel 1',
        reason: 'ujung daftar: memutar ke sel pertama yang belum dicek',
      );

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      expect(judulAktif(tester), 'Sel 2', reason: 'merah masih kosong');
      expect(tester.widget<FilledButton>(konfirmasi).onPressed, isNull);
    },
  );

  testWidgets('tidak ada tombol terima/konfirmasi SEMUA, di keadaan apa pun', (
    tester,
  ) async {
    await buka(tester, [
      baris('4,01', keyakinan: 0.99, titikUkur: 1),
      baris('7,02', keyakinan: 0.99, titikUkur: 2),
    ]);

    void periksa() {
      for (final kata in [
        'terima semua',
        'setujui semua',
        'konfirmasi semua',
        'terima semua usulan',
        'semua usulan',
        'accept all',
      ]) {
        expect(
          find.textContaining(kata, findRichText: true),
          findsNothing,
          reason: '"$kata" melewati pemeriksaan per sel',
        );
      }
    }

    periksa();
    await tester.tap(mulai);
    await tester.pumpAndSettle();
    periksa();

    // Satu ketukan konfirmasi hanya menyentuh SATU sel.
    await tester.tap(konfirmasi);
    await tester.pumpAndSettle();
    final masukkanTerkunci = find.byType(FilledButton);
    expect(
      masukkanTerkunci,
      findsOneWidget,
      reason: 'keypad masih terbuka: hanya tombol konfirmasi',
    );
    expect(tester.widget<FilledButton>(konfirmasi).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('keypad-tutup')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'sel 2 belum dicek: Masukkan tetap mati',
    );
  });

  testWidgets('skor mesin angka tidak tampil sebagai persen', (tester) async {
    await buka(
      tester,
      [
        baris('4,01', keyakinan: 0.995, titikUkur: 1),
        baris('7,2', keyakinan: 0.0, titikUkur: 2),
      ],
      skorMentah: {
        kunciSelFoto(1, 1, 'pembacaan'),
        kunciSelFoto(2, 1, 'pembacaan'),
      },
    );

    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('99'), findsNothing);
    expect(find.textContaining('Usulan mesin'), findsOneWidget);
  });

  testWidgets(
    'label usulan mesin hanya di baris mesin angka, bukan baris ML Kit',
    (tester) async {
      // Sel 1 dari mesin angka (skor mentah); sel 2 punya keyakinan tapi dari
      // jalur lain (mis. ML Kit): tetap tampil seperti biasa, tanpa label mesin.
      await buka(
        tester,
        [
          baris('4,01', keyakinan: 0.995, titikUkur: 1),
          baris('7,02', keyakinan: 0.82, titikUkur: 2),
          baris('9,00', titikUkur: 3),
        ],
        skorMentah: {kunciSelFoto(1, 1, 'pembacaan')},
      );

      expect(find.textContaining('Usulan mesin'), findsOneWidget);
      expect(find.textContaining('82%'), findsOneWidget);
      expect(find.textContaining('tidak dilaporkan'), findsOneWidget);
    },
  );

  testWidgets('bawaan: keyakinan tetap tampil sebagai persen (ML Kit)', (
    tester,
  ) async {
    await buka(tester, [baris('4,01', keyakinan: 0.82, titikUkur: 1)]);

    expect(find.textContaining('82%'), findsOneWidget);
    expect(find.textContaining('Usulan mesin'), findsNothing);
  });

  testWidgets('daftar panjang: sel aktif digulir ke layar', (tester) async {
    final isi = [
      for (var i = 1; i <= 60; i++)
        baris('$i,00', keyakinan: 0.99, titikUkur: i.toDouble()),
    ];
    await buka(tester, isi, tinggi: 900);

    await tester.tap(mulai);
    await tester.pumpAndSettle();
    for (var i = 0; i < 40; i++) {
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
    }

    expect(judulAktif(tester), 'Sel 41');
    // Barisnya dibangun (terlihat) dan di dalam layar.
    final baris41 = find.text('Sel 41');
    expect(baris41, findsWidgets);
    final atas = tester.getTopLeft(baris41.first).dy;
    expect(atas, greaterThanOrEqualTo(0));
    expect(
      atas,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  });

  testWidgets(
    'PENGAMAN urutan kertas: Masukkan mati selama ada merah kosong atau kuning '
    'belum dicek; penghitung sisa terlihat saat keypad terbuka',
    (tester) async {
      await buka(tester, [
        baris('1,00', keyakinan: 0.99, titikUkur: 1),
        baris('2,00', keyakinan: 0.0, titikUkur: 2), // merah, kotak kosong
        baris('3,00', keyakinan: 0.99, titikUkur: 3),
      ]);
      final sisa = find.byKey(const ValueKey('keypad-sisa'));
      String teksSisa() => tester.widget<Text>(sisa).data!;
      FilledButton masukkan() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      // Panel tertutup: Masukkan mati dan kedua penghitung lama tampil.
      expect(masukkan().onPressed, isNull);
      expect(find.textContaining('1 sel masih kosong'), findsOneWidget);
      expect(find.textContaining('2 angka kuning belum dicek'), findsOneWidget);

      await tester.tap(mulai);
      await tester.pumpAndSettle();
      expect(teksSisa(), 'Sisa 3 sel', reason: 'penghitung ikut panel');

      await tester.tap(konfirmasi); // sel 1 beres
      await tester.pumpAndSettle();
      expect(teksSisa(), 'Sisa 2 sel');

      // Tutup panel di tengah jalan: merah masih kosong, sel 3 belum dicek.
      await tester.tap(find.byKey(const ValueKey('keypad-tutup')));
      await tester.pumpAndSettle();
      expect(masukkan().onPressed, isNull);

      // Merah diketik tapi sel 3 belum dicek: tetap mati.
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();
      await ketik(tester, '2,05');
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      expect(teksSisa(), 'Sisa 1 sel');
      await tester.tap(find.byKey(const ValueKey('keypad-tutup')));
      await tester.pumpAndSettle();
      expect(masukkan().onPressed, isNull, reason: 'sel 3 belum dicek');

      // Sel 3 dicek: semua beres, baru Masukkan terbuka.
      await tester.tap(find.byKey(const ValueKey('cek-3.0|1|pembacaan')));
      await tester.pump();
      expect(masukkan().onPressed, isNotNull);
    },
  );
}
