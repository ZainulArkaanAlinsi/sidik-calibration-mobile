// TombolUtama (56 dp) dan BilahAksi (utama 56, lain 48; berdampingan atau
// bertumpuk menurut ruang).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/widgets/sidik/bilah_aksi.dart';
import 'package:sidik_calibration/widgets/sidik/tombol_utama.dart';

import '../support/komponen_uji.dart';

void main() {
  setUpAll(muatFontUji);

  group('TombolUtama', () {
    testWidgets('tinggi 56 dp, sudut 16, kobalt, selebar induk', (
      tester,
    ) async {
      layarUji(tester, lebar: 360, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Padding(
            padding: const EdgeInsets.all(16),
            child: TombolUtama(label: 'Lanjutkan', onPressed: () {}),
          ),
        ),
      );
      final ukuran = tester.getSize(find.byType(FilledButton));
      expect(ukuran.height, 56);
      expect(ukuran.width, 360 - 32);
      final skema = Theme.of(
        tester.element(find.byType(FilledButton)),
      ).colorScheme;
      final bahan = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FilledButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(bahan.color, skema.primary);
      expect(
        (bahan.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(BentukLab.utama),
      );
    });

    testWidgets('ketuk memanggil onPressed; ikon opsional', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          TombolUtama(
            label: 'Kirim ke admin',
            ikon: Icons.send,
            onPressed: () => n++,
          ),
        ),
      );
      expect(find.byIcon(Icons.send), findsOneWidget);
      await tester.tap(find.text('Kirim ke admin'));
      expect(n, 1);
    });

    testWidgets('mati: alasan tampil DI ATAS tombol dan ketukan diabaikan', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          const TombolUtama(
            label: 'Kirim ke admin',
            onPressed: null,
            alasanMati: 'Isi 2 sel wajib dulu.',
          ),
        ),
      );
      final alasan = tester.getRect(find.text('Isi 2 sel wajib dulu.'));
      final tombol = tester.getRect(find.byType(FilledButton));
      expect(alasan.bottom, lessThanOrEqualTo(tombol.top));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('aktif: alasan tidak tampil', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          TombolUtama(
            label: 'Kirim',
            onPressed: () {},
            alasanMati: 'Isi 2 sel wajib dulu.',
          ),
        ),
      );
      expect(find.text('Isi 2 sel wajib dulu.'), findsNothing);
    });

    testWidgets('sibuk: pemutar, ketukan ditolak, pembaca layar diberi tahu', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          TombolUtama(label: 'Simpan', onPressed: () => n++, sibuk: true),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Simpan'), warnIfMissed: false);
      expect(n, 0);
      final data = tester
          .getSemantics(find.byType(FilledButton))
          .getSemanticsData();
      expect(data.label, contains('Simpan'));
      expect(data.label, contains('sedang diproses'));
      semantik.dispose();
    });

    testWidgets('label mati tetap terbaca: >= 4,5:1', (tester) async {
      for (final gelap in [false, true]) {
        await tester.pumpWidget(
          aplikasiUji(
            const TombolUtama(label: 'Kirim ke admin', onPressed: null),
            gelap: gelap,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          pelanggaranKontrasTeks(tester, find.byType(TombolUtama)),
          isEmpty,
          reason: gelap ? 'gelap' : 'terang',
        );
      }
    });

    for (final gelap in [false, true]) {
      testWidgets(
        'label panjang membungkus di 320 dp x 1,3 dan tombol ikut tumbuh '
        '(${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          layarUji(tester, lebar: 320, tinggi: 640);
          await tester.pumpWidget(
            aplikasiUji(
              Padding(
                padding: const EdgeInsets.all(16),
                child: TombolUtama(
                  label:
                      'Kirim lembar kerja ke admin untuk diperiksa dan disetujui',
                  ikon: Icons.send,
                  onPressed: () {},
                ),
              ),
              gelap: gelap,
              skala: 1.3,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(FilledButton)).height,
            greaterThan(56),
          );
        },
      );
    }

    testWidgets('pedoman: sasaran >= 48 dp dan berlabel', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(TombolUtama(label: 'Lanjutkan', onPressed: () {})),
      );
      await periksaPedomanSentuh(tester);
      semantik.dispose();
    });
  });

  group('BilahAksi', () {
    test('aturan berdampingan: satu sekunder, >= 360 dp, huruf <= 1,15x', () {
      bool b(double lebar, double skala, int n) =>
          BilahAksi.berdampingan(lebar: lebar, skala: skala, jumlahSekunder: n);
      expect(b(392, 1.0, 1), isTrue);
      expect(b(360, 1.0, 1), isTrue);
      expect(b(359.9, 1.0, 1), isFalse);
      expect(b(392, 1.15, 1), isTrue);
      expect(b(392, 1.16, 1), isFalse);
      expect(b(392, 1.0, 0), isFalse);
      expect(b(392, 1.0, 2), isFalse);
      expect(b(320, 1.3, 1), isFalse);
    });

    BilahAksi bilah({
      bool sibuk = false,
      String? alasan,
      VoidCallback? utama,
      int sekunder = 1,
      VoidCallback? onSekunder,
    }) => BilahAksi(
      utama: AksiBilah(label: 'Kirim ke admin', onPressed: utama),
      sekunder: [
        for (var i = 0; i < sekunder; i++)
          AksiBilah(label: 'Simpan draf $i', onPressed: onSekunder ?? () {}),
      ],
      sibuk: sibuk,
      alasanMati: alasan,
    );

    testWidgets('392 dp: berdampingan, tinggi isi 56 (bilah 88 dp)', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(bilah(utama: () {}), bergulir: false, rataBawah: true),
      );
      final utama = tester.getRect(
        find.widgetWithText(FilledButton, 'Kirim ke admin'),
      );
      final sekunder = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf 0'),
      );
      expect(utama.left, greaterThan(sekunder.right));
      expect(utama.height, 56);
      expect(sekunder.height, 48);
      expect(tester.getSize(find.byType(BilahAksi)).height, 88);
    });

    testWidgets('320 dp: bertumpuk, utama di atas (bilah 144 dp)', (
      tester,
    ) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(bilah(utama: () {}), bergulir: false, rataBawah: true),
      );
      final utama = tester.getRect(
        find.widgetWithText(FilledButton, 'Kirim ke admin'),
      );
      final sekunder = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf 0'),
      );
      expect(utama.bottom, lessThan(sekunder.top));
      expect(utama.height, 56);
      expect(sekunder.height, 48);
      expect(tester.getSize(find.byType(BilahAksi)).height, 144);
    });

    testWidgets('392 dp x huruf 1,3x: bertumpuk, tanpa luapan', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          bilah(utama: () {}),
          bergulir: false,
          rataBawah: true,
          skala: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      final utama = tester.getRect(
        find.widgetWithText(FilledButton, 'Kirim ke admin'),
      );
      final sekunder = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf 0'),
      );
      expect(utama.bottom, lessThan(sekunder.top));
      expect(utama.height, greaterThanOrEqualTo(56));
      expect(sekunder.height, greaterThanOrEqualTo(48));
    });

    testWidgets('dua sekunder: selalu bertumpuk, utama 56 dan lain 48', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          bilah(utama: () {}, sekunder: 2),
          bergulir: false,
          rataBawah: true,
        ),
      );
      final a = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf 0'),
      );
      final b = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf 1'),
      );
      final u = tester.getRect(
        find.widgetWithText(FilledButton, 'Kirim ke admin'),
      );
      expect(u.bottom, lessThan(a.top));
      expect(a.bottom, lessThan(b.top));
      expect(a.height, 48);
      expect(b.height, 48);
    });

    testWidgets('tablet 1280 dp: isi dibatasi 560 dp dan dipusatkan', (
      tester,
    ) async {
      layarUji(tester, lebar: 1280, tinggi: 800);
      await tester.pumpWidget(
        aplikasiUji(bilah(utama: () {}), bergulir: false, rataBawah: true),
      );
      final utama = tester.getRect(
        find.widgetWithText(FilledButton, 'Kirim ke admin'),
      );
      final sekunder = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf 0'),
      );
      final lebarIsi = utama.right - sekunder.left;
      expect(lebarIsi, lessThanOrEqualTo(560 - 32));
      expect((sekunder.left + utama.right) / 2, closeTo(640, 1));
      expect(tester.getSize(find.byType(BilahAksi)).width, 1280);
    });

    testWidgets('hanya aksi utama: satu tombol 56 dp', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          BilahAksi(
            utama: AksiBilah(label: 'Mulai kalibrasi', onPressed: () {}),
          ),
          bergulir: false,
          rataBawah: true,
        ),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.getSize(find.byType(FilledButton)).height, 56);
    });

    testWidgets('ketuk memanggil aksi masing-masing', (tester) async {
      var utama = 0;
      var sekunder = 0;
      await tester.pumpWidget(
        aplikasiUji(
          bilah(utama: () => utama++, onSekunder: () => sekunder++),
          bergulir: false,
          rataBawah: true,
        ),
      );
      await tester.tap(find.text('Kirim ke admin'));
      await tester.tap(find.text('Simpan draf 0'));
      expect((utama, sekunder), (1, 1));
    });

    testWidgets('utama mati: alasan di atas bilah, ketukan diabaikan', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          BilahAksi(
            utama: const AksiBilah(label: 'Kirim ke admin', onPressed: null),
            sekunder: [AksiBilah(label: 'Simpan draf', onPressed: () => n++)],
            alasanMati: 'Isi 2 sel wajib dulu.',
          ),
          bergulir: false,
          rataBawah: true,
        ),
      );
      final alasan = tester.getRect(find.text('Isi 2 sel wajib dulu.'));
      final utama = tester.getRect(
        find.widgetWithText(FilledButton, 'Kirim ke admin'),
      );
      final sekunder = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Simpan draf'),
      );
      expect(alasan.bottom, lessThanOrEqualTo(utama.top));
      expect(alasan.bottom, lessThanOrEqualTo(sekunder.top));
      await tester.tap(find.text('Kirim ke admin'), warnIfMissed: false);
      await tester.tap(find.text('Simpan draf'));
      expect(n, 1, reason: 'sekunder tetap bisa; utama mati');
    });

    testWidgets('sibuk: semua aksi dimatikan supaya tidak terkirim dua kali', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          bilah(utama: () => n++, sibuk: true, onSekunder: () => n++),
          bergulir: false,
          rataBawah: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Kirim ke admin'), warnIfMissed: false);
      await tester.tap(find.text('Simpan draf 0'), warnIfMissed: false);
      expect(n, 0);
    });

    for (final gelap in [false, true]) {
      testWidgets('pedoman sentuh dan kontras, termasuk sekunder mati '
          '(${gelap ? 'gelap' : 'terang'})', (tester) async {
        layarUji(tester, lebar: 320, tinggi: 640);
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            bilah(utama: () {}, sibuk: true),
            bergulir: false,
            rataBawah: true,
            gelap: gelap,
            skala: 1.3,
          ),
        );
        await periksaPedomanSentuh(tester);
        expect(pelanggaranKontrasTeks(tester, find.byType(BilahAksi)), isEmpty);
        semantik.dispose();
      });
    }

    testWidgets('aksi sekunder membawa label dan aksi ketuk semantik', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          bilah(utama: () {}, onSekunder: () => n++),
          bergulir: false,
          rataBawah: true,
        ),
      );
      final data = tester
          .getSemantics(find.widgetWithText(OutlinedButton, 'Simpan draf 0'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Simpan draf 0'));
      expect(n, 1);
      semantik.dispose();
    });
  });
}
