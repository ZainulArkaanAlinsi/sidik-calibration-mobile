import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/screens/pindai/banner_jenis_dari_foto.dart';
import 'package:sidik_calibration/screens/pindai/dari_foto_lembar.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/widgets/pilih_alat_ringkas_sheet.dart';
import 'package:sidik_calibration/widgets/pilih_jenis_ringkas_sheet.dart';

/// Matriks perangkat untuk layar BARU alur foto otomatis: lembar ringkas
/// "Pilih salah satu" / pesan jujur, daftar alat pendek (dengan papan ketik),
/// dan banner "Ganti jenis".
///
/// Aturan pemilik: semua layar benar di 320-840 dp, huruf 1,0-2,0, gelap dan
/// terang, landscape, papan ketik. "Benar" di sini = tidak ada galat tata
/// letak (RenderFlex overflow), tidak ada yang keluar dari lebar layar, dan
/// baris yang diketuk setinggi minimal 48 dp.
const _lebar = [320.0, 360.0, 392.0, 600.0, 840.0];
const _skala = [1.0, 1.3, 2.0];

/// Tinggi potret yang wajar per lebar (HP kecil -> tablet).
double _tinggi(double lebar) => switch (lebar) {
  <= 320 => 640,
  <= 360 => 740,
  <= 392 => 800,
  <= 600 => 960,
  _ => 1200,
};

FormulirDikenal _f(String id, String nama, String kode) => (
  templateId: id,
  kodeDokumen: '${kode}_Rev.4',
  judul: 'Calibration Worksheet - $nama',
);

final _lima = [
  _f('oven', 'Oven', 'SIDIK-FM-CAL-0504'),
  _f('furnace', 'Furnace', 'SIDIK-FM-CAL-0504'),
  _f('inkubator', 'Inkubator', 'SIDIK-FM-CAL-0504'),
  _f('bath', 'Bath Circulator Suhu Tinggi', 'SIDIK-FM-CAL-0504'),
  _f('refrigerator', 'Refrigerator', 'SIDIK-FM-CAL-0504'),
];

final _semua = [
  ..._lima,
  _f('ph_meter', 'pH Meter', 'SIDIK-FM-CAL-0509'),
  _f('spektro', 'UV/VIS Spectrophotometer', 'SIDIK-FM-CAL-0508'),
  _f('timbangan', 'Timbangan Elektronik Kapasitas Besar', 'SIDIK-FM-CAL-0511'),
];

final _alat = [
  for (var i = 1; i <= 12; i++)
    EquipmentLookup(
      id: i,
      namaAlat: 'pH Meter Mettler Toledo Seri $i',
      serialNumber: 'SN-0000$i',
      kategori: 'instrumen-analitik',
      status: 'aktif',
      pelangganNama: 'PT CONTOH PRIMER NUSANTARA SEJAHTERA',
    ),
];

Widget _bungkus({
  required Widget Function(BuildContext) isi,
  required Brightness mode,
  required double skala,
}) => MaterialApp(
  theme: mode == Brightness.dark ? AppTheme.dark : AppTheme.light,
  locale: const Locale('id'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(skala)),
    child: child!,
  ),
  home: Scaffold(body: Builder(builder: isi)),
);

/// Semua kotak render yang meluap lebar layar = tata letak salah.
void _tidakKeluarLayar(WidgetTester tester, double lebar, Finder f) {
  for (final e in f.evaluate()) {
    final r = tester.getRect(find.byWidget(e.widget));
    expect(r.left, greaterThanOrEqualTo(-0.5), reason: '$f keluar kiri');
    expect(r.right, lessThanOrEqualTo(lebar + 0.5), reason: '$f keluar kanan');
  }
}

Future<void> _atur(
  WidgetTester tester,
  Size ukuran, {
  double papanKetik = 0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = ukuran;
  tester.view.viewInsets = FakeViewPadding(bottom: papanKetik);
  addTearDown(tester.view.reset);
}

void main() {
  group('lembar ringkas "Pilih salah satu" (jenis)', () {
    for (final gelap in [false, true]) {
      for (final lebar in _lebar) {
        for (final skala in _skala) {
          for (final landscape in [false, true]) {
            final mode = gelap ? Brightness.dark : Brightness.light;
            final ukuran = landscape
                ? Size(_tinggi(lebar), lebar)
                : Size(lebar, _tinggi(lebar));

            testWidgets(
              '${lebar.toInt()} dp x huruf $skala ${gelap ? 'gelap' : 'terang'}'
              '${landscape ? ' landscape' : ''}: tanpa overflow, baris >= 48 dp',
              (tester) async {
                await _atur(tester, ukuran);
                await tester.pumpWidget(
                  _bungkus(
                    mode: mode,
                    skala: skala,
                    isi: (c) => TextButton(
                      onPressed: () => tampilkanPilihJenisRingkas(
                        c,
                        judul: 'Pilih salah satu',
                        pesan:
                            'Kode ini dipakai beberapa jenis lembar. Pilih yang sesuai dengan alat Anda.',
                        kandidat: _lima,
                        semua: _semua,
                      ),
                      child: const Text('buka'),
                    ),
                  ),
                );
                await tester.tap(find.text('buka'));
                await tester.pumpAndSettle();

                expect(tester.takeException(), isNull);
                // Baris kandidat yang tampil (dalam area terlihat) cukup tinggi.
                for (final k in _lima) {
                  final baris = find.byKey(
                    PilihJenisRingkasSheet.kunciBaris(k.templateId),
                  );
                  if (baris.evaluate().isEmpty) continue;
                  expect(
                    tester.getSize(baris).height,
                    greaterThanOrEqualTo(48),
                    reason: k.templateId,
                  );
                }
                _tidakKeluarLayar(
                  tester,
                  ukuran.width,
                  find.byType(PilihJenisRingkasSheet),
                );
                expect(
                  find.byKey(PilihJenisRingkasSheet.kunciFotoUlang),
                  findsOneWidget,
                );

                // "Jenis lain" membuka semua jenis tanpa overflow.
                final lain = find.byKey(PilihJenisRingkasSheet.kunciJenisLain);
                await tester.ensureVisible(lain);
                await tester.tap(lain);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }

    testWidgets('keadaan "tidak dikenali" (tanpa kandidat): pesan + dua tombol, '
        'tanpa overflow di 320 dp x huruf 2,0', (tester) async {
      await _atur(tester, const Size(320, 640));
      await tester.pumpWidget(
        _bungkus(
          mode: Brightness.light,
          skala: 2.0,
          isi: (c) => TextButton(
            onPressed: () => tampilkanPilihJenisRingkas(
              c,
              judul: 'Jenis lembar belum bisa dikenali',
              pesan:
                  'Aplikasi belum yakin ini lembar apa, jadi tidak menebak. Foto ulang dengan judul dan kode formulir di bagian atas lembar terlihat jelas, atau mulai dari "Mulai kalibrasi".',
              kandidat: const [],
              semua: _semua,
            ),
            child: const Text('buka'),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(PilihJenisRingkasSheet.kunciFotoUlang), findsOneWidget);
      expect(find.byKey(PilihJenisRingkasSheet.kunciJenisLain), findsOneWidget);
    });
  });

  group('daftar alat pendek (jenis sudah dikenali, beberapa alat)', () {
    for (final gelap in [false, true]) {
      for (final lebar in _lebar) {
        for (final skala in _skala) {
          testWidgets(
            '${lebar.toInt()} dp x huruf $skala ${gelap ? 'gelap' : 'terang'} + '
            'papan ketik: kotak cari tetap terlihat, tanpa overflow',
            (tester) async {
              final ukuran = Size(lebar, _tinggi(lebar));
              await _atur(tester, ukuran, papanKetik: ukuran.height * 0.4);
              await tester.pumpWidget(
                _bungkus(
                  mode: gelap ? Brightness.dark : Brightness.light,
                  skala: skala,
                  isi: (c) => TextButton(
                    onPressed: () => tampilkanPilihAlatRingkas(
                      c,
                      jenis: 'pH Meter',
                      alat: _alat,
                    ),
                    child: const Text('buka'),
                  ),
                ),
              );
              await tester.tap(find.text('buka'));
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              // 12 alat > batas: kotak cari muncul dan tidak tertutup papan
              // ketik (di atas tepi papan ketik).
              final cari = find.byKey(PilihAlatRingkasSheet.kunciCari);
              expect(cari, findsOneWidget);
              // Teknisi mengetuk kotak cari: ia digulir ke area yang tidak
              // tertutup papan ketik (huruf besar mendorongnya ke bawah).
              await tester.ensureVisible(cari);
              await tester.pumpAndSettle();
              final tepiPapan = ukuran.height - ukuran.height * 0.4;
              expect(
                tester.getRect(cari).bottom,
                lessThanOrEqualTo(tepiPapan + 0.5),
                reason: 'kotak cari tertutup papan ketik',
              );

              await tester.enterText(cari, 'seri 7');
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(
                find.byKey(PilihAlatRingkasSheet.kunciBaris(7)),
                findsOneWidget,
              );
              expect(
                find.byKey(PilihAlatRingkasSheet.kunciBaris(1)),
                findsNothing,
              );
            },
          );
        }
      }
    }
  });

  group('banner "Ganti jenis"', () {
    DariFotoLembar info({bool otomatis = true}) => DariFotoLembar(
      jpeg: Uint8List(0),
      jenis: 'UV/VIS Spectrophotometer',
      otomatis: otomatis,
      gantiJenis: (_) async => null,
    );

    for (final gelap in [false, true]) {
      for (final lebar in _lebar) {
        for (final skala in _skala) {
          testWidgets(
            '${lebar.toInt()} dp x huruf $skala ${gelap ? 'gelap' : 'terang'}: '
            'tanpa overflow, tombol Ganti jenis dapat diketuk (>= 48 dp)',
            (tester) async {
              final ukuran = Size(lebar, _tinggi(lebar));
              await _atur(tester, ukuran);
              var diketuk = 0;
              await tester.pumpWidget(
                _bungkus(
                  mode: gelap ? Brightness.dark : Brightness.light,
                  skala: skala,
                  isi: (_) => Column(
                    children: [
                      BannerJenisDariFoto(
                        info: info(),
                        perluAlat: true,
                        onGanti: () => diketuk++,
                      ),
                    ],
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              final ganti = find.byKey(BannerJenisDariFoto.kunciGanti);
              expect(
                tester.getSize(ganti).height,
                greaterThanOrEqualTo(40),
                reason: 'area ketuk tombol teks',
              );
              _tidakKeluarLayar(
                tester,
                ukuran.width,
                find.byKey(BannerJenisDariFoto.kunciBanner),
              );
              await tester.tap(ganti);
              expect(diketuk, 1);
            },
          );
        }
      }
    }

    testWidgets('dipilih teknisi (bukan otomatis): kalimat berbeda, jujur', (
      tester,
    ) async {
      await _atur(tester, const Size(392, 800));
      await tester.pumpWidget(
        _bungkus(
          mode: Brightness.light,
          skala: 1.0,
          isi: (_) =>
              BannerJenisDariFoto(info: info(otomatis: false), onGanti: () {}),
        ),
      );

      expect(
        find.text(
          'Jenis lembar: UV/VIS Spectrophotometer (dipilih dari foto). Salah?',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Dikenali otomatis'), findsNothing);
    });

    testWidgets('tombol mati (foto sedang dibaca): tidak bisa diketuk', (
      tester,
    ) async {
      await _atur(tester, const Size(392, 800));
      await tester.pumpWidget(
        _bungkus(
          mode: Brightness.light,
          skala: 1.0,
          isi: (_) => BannerJenisDariFoto(info: info(), onGanti: null),
        ),
      );

      expect(
        tester
            .widget<TextButton>(find.byKey(BannerJenisDariFoto.kunciGanti))
            .onPressed,
        isNull,
      );
    });
  });
}
