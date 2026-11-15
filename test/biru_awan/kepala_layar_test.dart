// KepalaTab dan KepalaAnak.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/biru_awan/kepala_layar.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';

import '../support/uji_biru_awan.dart';

KepalaTab _tab({List<Widget> aksi = const []}) => KepalaTab(
  judul: 'SIDIK Lab',
  subjudul: 'Admin, Master Data',
  aksi: aksi,
  // Logo diganti kotak: tes ini tidak menguji dekode gambar.
  logo: const SizedBox(width: 30, height: 42),
);

void main() {
  setUpAll(muatFontUji);

  group('KepalaTab', () {
    testWidgets('judul 16/800, keterangan 12 tinta kedua, tinggi minimum 48', (
      tester,
    ) async {
      await tester.pumpWidget(aplikasiUji(_tab()));
      final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
      final judul = tester.widget<Text>(find.text('SIDIK Lab')).style!;
      final sub = tester.widget<Text>(find.text('Admin, Master Data')).style!;
      expect(
        (judul.fontSize, judul.fontWeight, judul.color),
        (16, FontWeight.w800, m.tinta),
      );
      expect((sub.fontSize, sub.color), (12, m.tinta2));
      expect(
        tester.getSize(find.byType(KepalaTab)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('logo bawaan: aset PT SIDIK 30 x 42, hiasan', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          const KepalaTab(
            judul: 'SIDIK Lab',
            subjudul: 'Kalibrasi terakreditasi KAN',
          ),
        ),
      );
      final gambar = tester.widget<Image>(find.byType(Image));
      expect((gambar.width, gambar.height), (30, 42));
      expect(gambar.excludeFromSemantics, isTrue);
      semantik.dispose();
    });

    testWidgets('aksi di kanan: lonceng dan menu, tiap satu berlabel dan 48', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          _tab(
            aksi: [
              TombolBulat(
                ikon: Icons.notifications_none,
                label: 'Notifikasi, 12 belum dibaca',
                onPressed: () => n++,
              ),
              TombolBulat(
                ikon: Icons.menu,
                label: 'Buka menu',
                ragam: RagamTombolBulat.navy,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final judul = tester.getRect(find.text('SIDIK Lab'));
      final lonceng = tester.getRect(
        find.bySemanticsLabel('Notifikasi, 12 belum dibaca'),
      );
      expect(lonceng.left, greaterThan(judul.right));
      expect(lonceng.size, const Size(48, 48));
      tester.semantics.tap(
        find.semantics.byLabel('Notifikasi, 12 belum dibaca'),
      );
      expect(n, 1);
      await periksaPedomanSentuh(tester);
      semantik.dispose();
    });

    testWidgets('judul ditandai sebagai kepala bagian', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(aplikasiUji(_tab()));
      expect(
        tester
            .getSemantics(find.text('SIDIK Lab'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantik.dispose();
    });

    testWidgets('320 dp x huruf 1,3: keterangan panjang membungkus', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        KepalaTab(
          judul: 'SIDIK Lab',
          subjudul:
              'Super admin, Master Data, dan teknisi kalibrasi terakreditasi',
          logo: const SizedBox(width: 30, height: 42),
          aksi: [
            TombolBulat(
              ikon: Icons.notifications_none,
              label: 'Notifikasi',
              onPressed: () {},
            ),
            TombolBulat(ikon: Icons.menu, label: 'Menu', onPressed: () {}),
          ],
        ),
      );
    });
  });

  testWidgets('kurangi gerak: kepala statis, tanpa animasi', (tester) async {
    await tester.pumpWidget(
      aplikasiUji(
        kurangiGerak(
          Column(
            children: [
              _tab(),
              const KepalaAnak(judul: 'Antrean persetujuan'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('SIDIK Lab'), findsOneWidget);
  });

  group('KepalaAnak', () {
    testWidgets('kembali bulat 48, judul 20/26 800, nomor mono 12', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          const KepalaAnak(judul: 'Periksa sesi', nomor: 'KAL/2026/11/0001'),
        ),
      );
      final judul = tester.widget<Text>(find.text('Periksa sesi')).style!;
      final nomor = tester.widget<Text>(find.text('KAL/2026/11/0001')).style!;
      expect((judul.fontSize, judul.fontWeight), (20, FontWeight.w800));
      expect(nomor.fontFamily, 'IBMPlexMono');
      expect(tester.getSize(find.byType(TombolBulat)), const Size(48, 48));
    });

    testWidgets('kembali dibaca "Kembali" (id) dan "Back" (en)', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(aplikasiUji(const KepalaAnak(judul: 'Judul')));
      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
      await tester.pumpWidget(
        aplikasiUji(const KepalaAnak(judul: 'Title'), bahasa: 'en'),
      );
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      semantik.dispose();
    });

    testWidgets('kembali bawaan menutup halaman (Navigator.maybePop)', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: SafeArea(child: KepalaAnak(judul: 'Halaman anak')),
                  ),
                ),
              ),
              child: const Text('Buka'),
            ),
          ),
          bergulir: false,
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman anak'), findsOneWidget);
      await tester.tap(find.byType(TombolBulat));
      await tester.pumpAndSettle();
      expect(find.text('Halaman anak'), findsNothing);
    });

    testWidgets('onKembali dan aksi kanan dari pemanggil', (tester) async {
      var kembali = 0;
      var tambah = 0;
      await tester.pumpWidget(
        aplikasiUji(
          KepalaAnak(
            judul: 'Standar acuan',
            onKembali: () => kembali++,
            aksi: TombolBulat(
              ikon: Icons.add,
              label: 'Tambah standar',
              ragam: RagamTombolBulat.primer,
              onPressed: () => tambah++,
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.tap(find.bySemanticsLabel('Tambah standar'));
      expect((kembali, tambah), (1, 1));
    });

    testWidgets('judul kepala bagian; judul panjang membungkus maks 2 baris', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          const KepalaAnak(
            judul:
                'Jadwal kalibrasi ulang untuk seluruh pelanggan dan alat ukur',
          ),
          skala: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSemantics(find.textContaining('Jadwal kalibrasi'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantik.dispose();
    });

    testWidgets('320 dp x huruf 1,3 dan pedoman sentuh, dua tema', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        KepalaAnak(
          judul: 'Antrean persetujuan',
          nomor: 'KAL/2026/11/0001',
          aksi: TombolBulat(
            ikon: Icons.add,
            label: 'Tambah',
            ragam: RagamTombolBulat.primer,
            onPressed: () {},
          ),
        ),
      );
      for (final gelap in [false, true]) {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(const KepalaAnak(judul: 'Antrean'), gelap: gelap),
        );
        await periksaPedomanSentuh(tester);
        expect(
          pelanggaranKontrasTeks(tester, find.byType(KepalaAnak)),
          isEmpty,
        );
        semantik.dispose();
      }
    });
  });
}
