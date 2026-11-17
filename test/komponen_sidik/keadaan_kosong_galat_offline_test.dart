// KeadaanKosongGalatOffline (satu komponen, tiga ragam) dan BannerOffline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/sidik/keadaan_kosong_galat_offline.dart';

import '../support/komponen_uji.dart';

Widget _keadaan(
  RagamKeadaan ragam, {
  String judul = 'Belum ada draf',
  String penjelasan = 'Mulai lembar baru dari tombol di bawah.',
  String? aksi = 'Mulai kalibrasi',
  VoidCallback? onAksi,
  bool utama = false,
}) => KeadaanKosongGalatOffline(
  ragam: ragam,
  judul: judul,
  penjelasan: penjelasan,
  labelAksi: aksi,
  onAksi: aksi == null ? null : (onAksi ?? () {}),
  aksiUtama: utama,
);

void main() {
  setUpAll(muatFontUji);

  group('KeadaanKosongGalatOffline', () {
    testWidgets(
      'kosong: judul + penjelasan + tindakan, tanpa ikon dan ilustrasi',
      (tester) async {
        var n = 0;
        await tester.pumpWidget(
          aplikasiUji(_keadaan(RagamKeadaan.kosong, onAksi: () => n++)),
        );
        expect(find.text('Belum ada draf'), findsOneWidget);
        expect(
          find.text('Mulai lembar baru dari tombol di bawah.'),
          findsOneWidget,
        );
        expect(find.byType(Icon), findsNothing);
        expect(find.byType(Image), findsNothing);
        await tester.tap(find.text('Mulai kalibrasi'));
        expect(n, 1);
      },
    );

    testWidgets('galat dan offline membawa ikon penanda jenis + kata', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          _keadaan(
            RagamKeadaan.galat,
            judul: 'Daftar tidak bisa dimuat',
            penjelasan:
                'Server tidak menjawab. Periksa sambungan, lalu coba lagi.',
            aksi: 'Coba lagi',
          ),
        ),
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Daftar tidak bisa dimuat'), findsOneWidget);
      await tester.pumpWidget(
        aplikasiUji(
          _keadaan(
            RagamKeadaan.offline,
            judul: 'Tidak ada sambungan',
            penjelasan: 'Daftar ini belum pernah dimuat.',
            aksi: 'Coba lagi',
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
      'galat: ikon merah tema; offline dan teks mengikuti tinta kedua',
      (tester) async {
        final m = SidikMaterial.terangDefault;
        await tester.pumpWidget(
          aplikasiUji(_keadaan(RagamKeadaan.galat, aksi: null)),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
          m.gagal,
        );
        await tester.pumpWidget(
          aplikasiUji(_keadaan(RagamKeadaan.offline, aksi: null)),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.cloud_off_outlined)).color,
          m.tinta2,
        );
      },
    );

    testWidgets('tanpa tindakan: tidak ada tombol', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(_keadaan(RagamKeadaan.kosong, aksi: null)),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'tindakan: tombol sekunder 48 dp; aksiUtama: tombol utama 56 dp',
      (tester) async {
        await tester.pumpWidget(aplikasiUji(_keadaan(RagamKeadaan.kosong)));
        expect(tester.getSize(find.byType(OutlinedButton)).height, 48);
        expect(find.byType(FilledButton), findsNothing);
        await tester.pumpWidget(
          aplikasiUji(_keadaan(RagamKeadaan.kosong, utama: true)),
        );
        expect(tester.getSize(find.byType(FilledButton)).height, 56);
        expect(find.byType(OutlinedButton), findsNothing);
      },
    );

    testWidgets('rata kiri, bukan tengah', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(aplikasiUji(_keadaan(RagamKeadaan.kosong)));
      final judul = tester.getRect(find.text('Belum ada draf'));
      final tombol = tester.getRect(find.byType(OutlinedButton));
      expect(judul.left, 16);
      expect(tombol.left, 16);
      expect(
        tombol.width,
        lessThan(392 / 2),
        reason: 'tombol tidak selebar layar',
      );
    });

    testWidgets('labelAksi dan onAksi harus diisi bersama', (tester) async {
      expect(
        () => KeadaanKosongGalatOffline(
          ragam: RagamKeadaan.kosong,
          judul: 'a',
          penjelasan: 'b',
          labelAksi: 'Coba lagi',
        ),
        throwsAssertionError,
      );
    });

    testWidgets('pembaca layar: judul sebagai header; galat dibacakan segera', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(_keadaan(RagamKeadaan.galat, judul: 'Gagal memuat')),
      );
      var data = tester
          .getSemantics(find.text('Gagal memuat'))
          .getSemanticsData();
      expect(data.flagsCollection.isHeader, isTrue);
      expect(data.flagsCollection.isLiveRegion, isTrue);
      await tester.pumpWidget(
        aplikasiUji(_keadaan(RagamKeadaan.kosong, judul: 'Belum ada draf')),
      );
      data = tester
          .getSemantics(find.text('Belum ada draf'))
          .getSemanticsData();
      expect(data.flagsCollection.isHeader, isTrue);
      expect(data.flagsCollection.isLiveRegion, isFalse);
      semantik.dispose();
    });

    for (final gelap in [false, true]) {
      testWidgets('teks panjang, 320 dp x 1,3: tanpa luapan; kontras; sentuh '
          '(${gelap ? 'gelap' : 'terang'})', (tester) async {
        layarUji(tester, lebar: 320, tinggi: 640);
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                _keadaan(
                  RagamKeadaan.galat,
                  judul:
                      'Lembar kerja Termometer Digital Presisi Tinggi tidak '
                      'bisa dibuka karena versi aplikasi lebih lama',
                  penjelasan:
                      'Perbarui aplikasi dari pesan pembaruan yang muncul, '
                      'lalu buka kembali lembar ini.',
                  aksi: 'Coba lagi dengan sambungan yang lebih baik',
                ),
                const BannerOffline(
                  teks:
                      'Tanpa sambungan. Draf tetap tersimpan di perangkat; '
                      'pengiriman ditahan sampai tersambung.',
                ),
              ],
            ),
            gelap: gelap,
            skala: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(pelanggaranKontrasTeks(tester, find.byType(Scaffold)), isEmpty);
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });

  group('BannerOffline', () {
    testWidgets('ikon + kata pada latar tipis nada awas, selebar induk', (
      tester,
    ) async {
      layarUji(tester);
      final m = SidikMaterial.terangDefault;
      await tester.pumpWidget(
        aplikasiUji(
          const BannerOffline(teks: 'Tanpa sambungan. Draf tetap tersimpan.'),
        ),
      );
      expect(
        find.text('Tanpa sambungan. Draf tetap tersimpan.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(BannerOffline)).width, 392);
      final kotak = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(BannerOffline),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(kotak.color, m.awasTipis);
      expect(
        tester
            .widget<Text>(find.text('Tanpa sambungan. Draf tetap tersimpan.'))
            .style!
            .color,
        m.awas,
      );
    });

    testWidgets('pembaca layar: dibacakan begitu muncul (live region)', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(const BannerOffline(teks: 'Tanpa sambungan.')),
      );
      final data = tester
          .getSemantics(find.byType(BannerOffline))
          .getSemanticsData();
      expect(data.label, 'Tanpa sambungan.');
      expect(data.flagsCollection.isLiveRegion, isTrue);
      semantik.dispose();
    });

    testWidgets('kontras >= 4,5:1 di dua tema', (tester) async {
      for (final gelap in [false, true]) {
        await tester.pumpWidget(
          aplikasiUji(
            const BannerOffline(teks: 'Tanpa sambungan.'),
            gelap: gelap,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          pelanggaranKontrasTeks(tester, find.byType(BannerOffline)),
          isEmpty,
          reason: gelap ? 'gelap' : 'terang',
        );
      }
    });
  });
}
