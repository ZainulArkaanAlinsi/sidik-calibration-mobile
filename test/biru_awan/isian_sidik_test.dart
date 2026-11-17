// IsianSidik: label di atas, kotak 56 sudut 16; biasa, fokus, galat, mati.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/isian_sidik.dart';

import '../support/uji_biru_awan.dart';

/// Kotak berbingkai di dalam [IsianSidik].
BoxDecoration _kotak(WidgetTester tester) {
  final w = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(IsianSidik),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return w.decoration! as BoxDecoration;
}

Border _tepi(WidgetTester tester) => _kotak(tester).border! as Border;

void main() {
  setUpAll(muatFontUji);

  group('bentuk', () {
    testWidgets('label di ATAS kotak; kotak >= 56 dp, sudut 16', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(const IsianSidik(label: 'Nama lengkap')),
      );
      final label = tester.getRect(find.text('Nama lengkap'));
      final kotak = tester.getRect(
        find.descendant(
          of: find.byType(IsianSidik),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(label.bottom, lessThanOrEqualTo(kotak.top));
      expect(kotak.height, greaterThanOrEqualTo(56));
      expect(
        _kotak(tester).borderRadius,
        BorderRadius.circular(BentukBiruAwan.isian),
      );
    });

    testWidgets('petunjuk (placeholder) BUKAN label', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          const IsianSidik(label: 'Email', petunjuk: 'nama@perusahaan.id'),
        ),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('nama@perusahaan.id'), findsOneWidget);
    });

    testWidgets('wajib menambah "(wajib)" di label, bukan bintang', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(const IsianSidik(label: 'Nama lengkap', wajib: true)),
      );
      expect(find.text('Nama lengkap (wajib)'), findsOneWidget);
      expect(find.textContaining('*'), findsNothing);
    });

    testWidgets(
      'tema app tidak bocor: tanpa tepi atau isi bawaan InputDecorator',
      (tester) async {
        await tester.pumpWidget(aplikasiUji(const IsianSidik(label: 'Kode')));
        final dek = tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration;
        for (final b in [
          dek.border,
          dek.enabledBorder,
          dek.focusedBorder,
          dek.errorBorder,
          dek.disabledBorder,
        ]) {
          expect(b, InputBorder.none);
        }
        expect(dek.filled, isFalse);
      },
    );

    testWidgets('mono: IBM Plex Mono untuk kode', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(const IsianSidik(label: 'Kode teknisi', mono: true)),
      );
      final gaya = tester.widget<TextField>(find.byType(TextField)).style!;
      expect(gaya.fontFamily, 'IBMPlexMono');
      expect(gaya.fontSize, 16);
    });
  });

  group('keadaan', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';

      testWidgets('biasa: tepi kontrol 1 dp ($nama)', (tester) async {
        await tester.pumpWidget(
          aplikasiUji(const IsianSidik(label: 'Nama'), gelap: gelap),
        );
        final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
        expect(_tepi(tester).top.color, m.garisTegas);
        expect(_tepi(tester).top.width, 1);
        expect(_kotak(tester).color, m.kertas);
      });

      testWidgets('fokus: tepi primer 2 dp ($nama)', (tester) async {
        await tester.pumpWidget(
          aplikasiUji(const IsianSidik(label: 'Nama'), gelap: gelap),
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
        expect(_tepi(tester).top.color, m.biru);
        expect(_tepi(tester).top.width, 2);
      });

      testWidgets('galat: tepi koral batang 2 dp + ikon + kalimat ($nama)', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            const IsianSidik(
              label: 'Email',
              galat: 'Format email belum lengkap',
            ),
            gelap: gelap,
          ),
        );
        final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
        expect(_tepi(tester).top.color, w.tepiGalat);
        expect(_tepi(tester).top.width, 2);
        expect(find.text('Format email belum lengkap'), findsOneWidget);
        expect(
          find.byIcon(Icons.warning_amber_rounded),
          findsOneWidget,
          reason: 'galat tidak hanya warna: ikon + kata',
        );
      });

      testWidgets('mati: latar latar, tepi halus, tidak bisa difokus ($nama)', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            const IsianSidik(label: 'Organisasi', enabled: false),
            gelap: gelap,
          ),
        );
        final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
        expect(_kotak(tester).color, m.meja);
        expect(_tepi(tester).top.color, m.kertasTepi);
        // Mati sungguhan: TextField-nya sendiri mati (tidak bisa difokus dan
        // tidak bisa diketik), bukan hanya tampilannya.
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
        final sunting = tester.widget<EditableText>(find.byType(EditableText));
        expect(sunting.focusNode.canRequestFocus, isFalse);
        await tester.tap(find.byType(TextField), warnIfMissed: false);
        await tester.pump();
        expect(_tepi(tester).top.width, 1, reason: 'tidak ikut fokus');
        expect(sunting.focusNode.hasFocus, isFalse);
        expect(
          tester.testTextInput.isVisible,
          isFalse,
          reason: 'tanpa papan ketik',
        );
      });

      testWidgets('ketuk bantalan kotak (di luar area teks) memfokuskan '
          'isian; mati tetap tidak ($nama)', (tester) async {
        for (final enabled in [true, false]) {
          await tester.pumpWidget(
            aplikasiUji(
              IsianSidik(label: 'Nama lengkap', enabled: enabled),
              gelap: gelap,
            ),
          );
          final kotak = tester.getRect(
            find.descendant(
              of: find.byType(IsianSidik),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final area = tester.getRect(find.byType(TextField));
          // Bantalan kiri 17 dp: di dalam kotak, di luar TextField.
          final bantalan = Offset(kotak.left + 6, kotak.center.dy);
          expect(area.contains(bantalan), isFalse, reason: 'bukan area teks');
          await tester.tapAt(bantalan);
          await tester.pump(const Duration(milliseconds: 300));
          final sunting = tester.widget<EditableText>(
            find.byType(EditableText),
          );
          expect(
            sunting.focusNode.hasFocus,
            enabled,
            reason: 'enabled $enabled',
          );
          expect(_tepi(tester).top.width, enabled ? 2 : 1);
        }
      });

      testWidgets('kontras teks >= 4,5:1 di tiap keadaan ($nama)', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            const Column(
              children: [
                IsianSidik(label: 'Biasa', petunjuk: 'contoh isi'),
                IsianSidik(
                  label: 'Galat',
                  galat: 'Format belum lengkap',
                  wajib: true,
                ),
                IsianSidik(label: 'Mati', enabled: false),
                IsianSidik(label: 'Bantuan', bantuan: 'Kecetak di sertifikat'),
              ],
            ),
            gelap: gelap,
          ),
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(Column).first),
          isEmpty,
        );
      });
    }

    testWidgets('galat menggantikan bantuan', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          const IsianSidik(
            label: 'Kode',
            bantuan: 'Kecetak di sertifikat',
            galat: 'Kode sudah dipakai',
          ),
        ),
      );
      expect(find.text('Kecetak di sertifikat'), findsNothing);
      expect(find.text('Kode sudah dipakai'), findsOneWidget);
    });

    testWidgets(
      'isi yang diketik tetap terbaca saat mati (tinta kedua, bukan pudar)',
      (tester) async {
        for (final gelap in [false, true]) {
          await tester.pumpWidget(
            aplikasiUji(
              IsianSidik(
                label: 'Organisasi',
                enabled: false,
                controller: TextEditingController(
                  text: 'PT Sistem Dirgantara Inovasi Teknologi',
                ),
              ),
              gelap: gelap,
            ),
          );
          final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
          final gaya = tester
              .widget<EditableText>(find.byType(EditableText))
              .style;
          expect(gaya.color, m.tinta2);
          expect(
            rasioKontras(gaya.color!, m.meja),
            greaterThanOrEqualTo(4.5),
            reason: gelap ? 'gelap' : 'terang',
          );
        }
      },
    );

    testWidgets('kurangi gerak: perpindahan tepi tanpa animasi', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(kurangiGerak(const IsianSidik(label: 'Nama'))),
      );
      final w = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(IsianSidik),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(w.duration, Duration.zero);
    });
  });

  group('perilaku', () {
    testWidgets('mengetik memanggil onChanged dan mengisi controller', (
      tester,
    ) async {
      final c = TextEditingController();
      final isi = <String>[];
      await tester.pumpWidget(
        aplikasiUji(
          IsianSidik(label: 'Nama', controller: c, onChanged: isi.add),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Rekan');
      expect(c.text, 'Rekan');
      expect(isi, ['Rekan']);
    });

    testWidgets('fokus eksternal ikut: focusNode milik pemanggil', (
      tester,
    ) async {
      final f = FocusNode();
      addTearDown(f.dispose);
      await tester.pumpWidget(
        aplikasiUji(IsianSidik(label: 'Nama', focusNode: f)),
      );
      f.requestFocus();
      await tester.pump();
      expect(_tepi(tester).top.width, 2);
      f.unfocus();
      await tester.pump();
      expect(_tepi(tester).top.width, 1);
    });

    testWidgets('semantik: label (+ wajib) dan petunjuk galat di kolomnya', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          const IsianSidik(
            label: 'Email',
            wajib: true,
            galat: 'Format email belum lengkap',
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(data.label, contains('Email (wajib)'));
      expect(data.hint, contains('Galat: Format email belum lengkap'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantik.dispose();
    });

    testWidgets('bahasa Inggris: "(required)" dan "Error:"', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          const IsianSidik(label: 'Email', wajib: true, galat: 'Invalid'),
          bahasa: 'en',
        ),
      );
      expect(find.text('Email (required)'), findsOneWidget);
      final data = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(data.hint, contains('Error: Invalid'));
      semantik.dispose();
    });

    testWidgets('akhir (aksi di ujung kotak) tampil dan bisa diketuk', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          IsianSidik(
            label: 'Sandi',
            obscureText: true,
            akhir: TextButton(
              onPressed: () => n++,
              child: const Text('Tampilkan'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tampilkan'));
      expect(n, 1);
    });
  });

  group('tangguh', () {
    testWidgets('320 dp x huruf 1,3: label, galat, dan aksi panjang', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        Column(
          children: [
            IsianSidik(
              label: 'Nama lengkap sesuai kartu identitas pelanggan',
              wajib: true,
              bantuan: 'Kalimat bantu yang cukup panjang untuk membungkus',
              petunjuk: 'mis. Rekan Teknisi',
              akhir: TextButton(onPressed: () {}, child: const Text('Hapus')),
            ),
            const IsianSidik(
              label: 'Email',
              galat:
                  'Format email belum lengkap, tambahkan nama domain setelah @',
            ),
            const IsianSidik(label: 'Organisasi', enabled: false),
          ],
        ),
        tinggi: 1200,
      );
    });

    testWidgets('kotak tumbuh bersama huruf (bukan terpotong)', (tester) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(const IsianSidik(label: 'Kode'), skala: 1.3),
      );
      final kotak = tester.getSize(
        find.descendant(
          of: find.byType(IsianSidik),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(kotak.height, greaterThanOrEqualTo(56));
    });

    for (final gelap in [false, true]) {
      testWidgets('pedoman sentuh dan label (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            const Column(
              children: [
                IsianSidik(label: 'Nama'),
                IsianSidik(label: 'Email', galat: 'Format belum lengkap'),
                IsianSidik(label: 'Organisasi', enabled: false),
              ],
            ),
            gelap: gelap,
          ),
        );
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });
}
