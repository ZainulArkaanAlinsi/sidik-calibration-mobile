import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_colors.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/usulan_ocr_awan.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart'
    show kuningPerluDicek;
import 'package:sidik_calibration/screens/calibration/widgets/panel_usulan_ocr_awan.dart';

import 'support/papan_usulan_contoh.dart';

/// Layar usulan OCR awan: tiap aksi menyangkut SATU sel, tidak ada "pakai
/// semua", tidak ada hijau, dua bentuk berdampingan, alasan berupa kalimat.
/// Papan palsu, tanpa jaringan.
void main() {
  Future<void> pasang(
    WidgetTester tester, {
    required ValueNotifier<PapanUsulanAwan> papan,
    Brightness mode = Brightness.light,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: mode == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ValueListenableBuilder<PapanUsulanAwan>(
              valueListenable: papan,
              builder: (_, nilai, _) => PanelUsulanOcrAwan(
                papan: nilai,
                labelSel: labelSelContoh,
                onPakai: (k) => papan.value = papan.value.pakai(k),
                onUbah: (k, t) => papan.value = papan.value.ubah(k, t),
                onTolak: (k) => papan.value = papan.value.tolak(k),
                onKembalikan: (k) => papan.value = papan.value.kembalikan(k),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  late ValueNotifier<PapanUsulanAwan> papan;

  setUp(() {
    papan = ValueNotifier(papanUsulanContoh());
    addTearDown(papan.dispose);
  });

  Finder kartu(String kunci) => find.byKey(ValueKey('usulan-$kunci'));

  testWidgets('awal: semua usulan perlu dicek, belum ada nilai', (
    tester,
  ) async {
    await pasang(tester, papan: papan);

    expect(find.text('Usulan bacaan awan'), findsOneWidget);
    expect(find.text('3 usulan belum diputuskan.'), findsOneWidget);
    expect(find.text('Perlu dicek'), findsNWidgets(3));
    expect(find.text('Dipakai'), findsNothing);
    expect(find.textContaining('Nilai:'), findsNothing);
    expect(papan.value.koreksiTerkonfirmasi, isEmpty);
  });

  testWidgets(
    'tidak ada tombol atau kata "terima/pakai semua" atau "terverifikasi"',
    (tester) async {
      await pasang(tester, papan: papan);

      final semuaTeks = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase(),
      ].join('\n');

      expect(semuaTeks, isNot(contains('terima semua')));
      expect(semuaTeks, isNot(contains('pakai semua')));
      expect(semuaTeks, isNot(contains('terverifikasi')));
      expect(semuaTeks, isNot(contains('terkonfirmasi')));
    },
  );

  testWidgets('dua bentuk berdampingan hanya bila berbeda', (tester) async {
    await pasang(tester, papan: papan);

    // Sel pertama: 4.01 -> 4,01 (dinormalkan): dua bentuk.
    final k1 = kartu(kunciDuaBentuk);
    expect(
      find.descendant(
        of: k1,
        matching: find.byKey(const ValueKey('bentuk-awan')),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: k1,
              matching: find.byKey(const ValueKey('bentuk-awan')),
            ),
          )
          .data,
      '4.01',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: k1,
              matching: find.byKey(const ValueKey('bentuk-normal')),
            ),
          )
          .data,
      '4,01',
    );
    expect(
      find.descendant(
        of: k1,
        matching: find.text(
          'Dua bentuk ini berbeda. Pilih yang sesuai dengan kertas.',
        ),
      ),
      findsOneWidget,
    );

    // Sel kedua: teks sama: satu bentuk.
    final k2 = kartu(kunciSatuBentuk);
    expect(
      find.descendant(
        of: k2,
        matching: find.byKey(const ValueKey('bentuk-usulan')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: k2,
        matching: find.byKey(const ValueKey('bentuk-awan')),
      ),
      findsNothing,
    );
  });

  testWidgets('alasan tampil sebagai kalimat, kode mentah tidak', (
    tester,
  ) async {
    await pasang(tester, papan: papan);

    expect(
      find.text('Angkanya jauh beda dari Repeat lain di baris ini.'),
      findsOneWidget,
    );
    expect(find.text('jauh_dari_repeat_lain'), findsNothing);
    expect(
      find.textContaining('_'),
      findsNothing,
      reason: 'kode snake_case bocor ke layar',
    );
  });

  testWidgets('kode alasan tak dikenal: kalimat umum, bukan kode', (
    tester,
  ) async {
    papan.value = PapanUsulanAwan.dari(
      HasilOcrAwan(
        hasil: [
          SelOcrAwan.dariJson({
            'kunci': 'a|9|1|p',
            'status': 'kuning',
            'teks_awan': '3',
            'teks_normal': '3',
            'alasan': ['kode_dari_masa_depan'],
          })!,
        ],
      ),
    );
    await pasang(tester, papan: papan);

    expect(find.textContaining('kode_dari_masa_depan'), findsNothing);
    expect(find.textContaining('belum dikenal aplikasi ini'), findsOneWidget);
  });

  testWidgets('Pakai satu sel TIDAK mengubah sel lain', (tester) async {
    await pasang(tester, papan: papan);

    await tester.tap(find.byKey(ValueKey('usulan-pakai-$kunciDuaBentuk')));
    await tester.pumpAndSettle();

    expect(find.text('Dipakai'), findsOneWidget);
    expect(find.text('Perlu dicek'), findsNWidgets(2));
    expect(find.text('2 usulan belum diputuskan.'), findsOneWidget);
    expect(
      find.byKey(ValueKey('usulan-nilai-$kunciDuaBentuk')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(ValueKey('usulan-nilai-$kunciDuaBentuk')))
          .data,
      'Nilai: 4,01',
    );

    final k = papan.value.koreksiTerkonfirmasi;
    expect(k.map((e) => e.kunci), [kunciDuaBentuk]);
    expect(k.single.nilaiFinal, 4.01);
  });

  testWidgets('Tolak: tidak ada nilai; Batalkan: kembali menunggu', (
    tester,
  ) async {
    await pasang(tester, papan: papan);

    await tester.tap(find.byKey(ValueKey('usulan-tolak-$kunciSatuBentuk')));
    await tester.pumpAndSettle();

    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.textContaining('Nilai:'), findsNothing);
    expect(papan.value.koreksiTerkonfirmasi, isEmpty);

    await tester.tap(
      find.byKey(ValueKey('usulan-kembalikan-$kunciSatuBentuk')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ditolak'), findsNothing);
    expect(find.text('Perlu dicek'), findsNWidgets(3));
  });

  testWidgets('Ubah: isian diisi usulan, bukan-angka tidak bisa disimpan', (
    tester,
  ) async {
    await pasang(tester, papan: papan);

    await tester.tap(find.byKey(ValueKey('usulan-ubah-$kunciDuaBentuk')));
    await tester.pumpAndSettle();

    final isian = find.byKey(ValueKey('usulan-isian-$kunciDuaBentuk'));
    expect(tester.widget<TextField>(isian).controller!.text, '4,01');

    // Bentuk yang lolos penyaring huruf tapi bukan angka murni.
    await tester.enterText(isian, '4,,');
    await tester.pumpAndSettle();

    expect(find.text('Hanya angka, mis. 4,01'), findsOneWidget);
    final simpan = find.byKey(ValueKey('usulan-simpan-$kunciDuaBentuk'));
    expect(tester.widget<FilledButton>(simpan).onPressed, isNull);

    // Huruf disaring di ketikan.
    await tester.enterText(isian, '4a,0b2');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(isian).controller!.text, '4,02');
    expect(tester.widget<FilledButton>(simpan).onPressed, isNotNull);

    await tester.tap(simpan);
    await tester.pumpAndSettle();

    expect(find.text('Diubah'), findsOneWidget);
    expect(find.text('Perlu dicek'), findsNWidgets(2));
    final k = papan.value.koreksiTerkonfirmasi.single;
    expect(k.kunci, kunciDuaBentuk);
    expect(k.nilaiFinal, 4.02);
  });

  testWidgets('Ubah lalu Batal: tidak ada yang berubah', (tester) async {
    await pasang(tester, papan: papan);

    await tester.tap(find.byKey(ValueKey('usulan-ubah-$kunciSatuBentuk')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('usulan-batal-$kunciSatuBentuk')));
    await tester.pumpAndSettle();

    expect(find.text('Perlu dicek'), findsNWidgets(3));
    expect(papan.value.koreksiTerkonfirmasi, isEmpty);
  });

  testWidgets('sel tanpa usulan: kalimat, tanpa tombol pakai', (tester) async {
    await pasang(tester, papan: papan);

    expect(find.text('Tanpa usulan, isi sendiri'), findsOneWidget);
    expect(
      find.text('Bacaan awan tidak dipakai. Isi sendiri dari kertas.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Awan tidak melihat tulisan di sel ini. Tetap kosong sampai diisi.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('usulan-pakai-$kunciMerah')), findsNothing);
    expect(find.byKey(ValueKey('usulan-pakai-$kunciKosong')), findsNothing);
  });

  testWidgets('sel dilewati dan sebagian disebut, tanpa mengisi apa pun', (
    tester,
  ) async {
    await pasang(tester, papan: papan);

    expect(find.text('Sebagian sel tidak sempat dibaca awan.'), findsOneWidget);
    expect(
      find.text(
        '2 sel tidak dibaca awan. Isi sendiri atau pakai pembaca di HP.',
      ),
      findsOneWidget,
    );
  });

  test(
    'penyaring hijau memang mengenali hijau tema, dan tidak salah tangkap',
    () {
      expect(_hijau(AppColors.mintDeep), isTrue);
      expect(_hijau(AppColors.success), isTrue);
      expect(_hijau(AppColors.mint), isTrue);
      expect(_hijau(kuningPerluDicek), isFalse);
      expect(_hijau(AppColors.cobalt), isFalse);
      expect(_hijau(AppColors.cobaltLight), isFalse);
      expect(_hijau(AppColors.textMuted), isFalse);
    },
  );

  for (final mode in Brightness.values) {
    testWidgets(
      'tidak ada warna hijau di tema ${mode.name}, di keadaan apa pun',
      (tester) async {
        await pasang(tester, papan: papan, mode: mode);

        // Keadaan beragam: satu dipakai, satu diubah, satu ditolak.
        papan.value = papan.value
            .pakai(kunciDuaBentuk)
            .ubah(kunciSatuBentuk, '5,5')
            .tolak(kunciBeralasan);
        await tester.pumpAndSettle();

        expect(find.text('Dipakai'), findsOneWidget);
        expect(find.text('Diubah'), findsOneWidget);
        expect(find.text('Ditolak'), findsOneWidget);

        final hijau = <String>[];
        void periksa(String dari, Color? c) {
          if (c != null && _hijau(c)) {
            hijau.add('$dari ${c.toARGB32().toRadixString(16)}');
          }
        }

        for (final i in tester.widgetList<Icon>(find.byType(Icon))) {
          periksa('ikon ${i.icon}', i.color);
        }
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          periksa('teks "${t.data}"', t.style?.color);
        }
        for (final d in tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        )) {
          final dek = d.decoration;
          if (dek is BoxDecoration) {
            periksa('latar', dek.color);
            final b = dek.border;
            if (b is Border) {
              periksa('garis', b.top.color);
            }
          }
        }

        expect(hijau, isEmpty, reason: 'warna hijau ditemukan: $hijau');
      },
    );
  }
}

/// Hijau = rona 80..190 derajat (termasuk hijau-kebiruan seperti hijau LULUS
/// tema) dan cukup jenuh. Kobalt (~220), kuning tua B8860B (~43), dan abu
/// tidak lolos. Dicoba lebih dulu dengan "kanal hijau dominan", yang meleset
/// untuk hijau tema (g hanya 0,08 di atas b): lihat tes penyaring di atas.
bool _hijau(Color c) {
  final h = HSVColor.fromColor(c);

  return h.alpha > 0 &&
      h.saturation > 0.3 &&
      h.value > 0.15 &&
      h.hue >= 80 &&
      h.hue <= 190;
}
