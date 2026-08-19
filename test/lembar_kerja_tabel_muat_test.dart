import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';

/// Tabel lembar kerja harus MUAT — di alat yang labelnya paling panjang.
///
/// Sebelum ini nggak ada satu pun tes yang beneran nge-render
/// [LembarKerjaTabel]; yang ada cuma tes model. Jadi kolom label yang dipatok
/// 104px dan tinggi baris 56px nggak pernah diadu ke isinya.
///
/// Conductivity yang paling menekan, dan bukan kebetulan:
///
///  - Labelnya bawa SATUAN (`1,412 mS/cm`), sementara pH cuma `4` / `7` / `10`.
///  - Baris titik tengah bisa TERKUNCI, dan waktu terkunci dia nambah baris
///    keterangan di bawah label — di dalam kotak setinggi yang sama.
///
/// Dua-duanya numpuk di satu sel, dan hasilnya teks kejejal keluar kotak.
void main() {
  /// Bentuk Conductivity generik — 4 baris, titik tengah dikirim dalam dua
  /// varian satuan. Disalin dari respons API nyata, sama kayak yang dipakai
  /// `lembar_kerja_conductivity_test.dart`.
  LembarKerja lembarConductivity() => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
    'judul': 'Calibration Worksheet - Conductivity Meter',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan': null,
    'satuan_campuran': true,
    'suhu_wajib': true,
    'satuan_suhu': '°C',
    'bagian': [
      {
        'kode': 'hasil',
        'judul': 'CALIBRATION RESULT',
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'judul': 'After adjustment Reading',
            'kolom': [
              {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
              {'kode': 'suhu', 'label': '°C', 'tipe': 'angka'},
            ],
            'pengulangan': [1, 2, 3, 4, 5],
            'baris': [
              {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm', 'resolusi': 0.1, 'desimal': 1},
              {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm', 'resolusi': 1, 'desimal': 0, 'eksklusif_dengan': 1.412},
              {'titik_ukur': 1.412, 'label': '1,412', 'satuan': 'mS/cm', 'resolusi': 0.001, 'desimal': 3, 'eksklusif_dengan': 1412},
              {'titik_ukur': 111, 'label': '111', 'satuan': 'mS/cm', 'resolusi': 0.01, 'desimal': 2},
            ],
          },
        ],
      },
    ],
  });

  Future<LembarKerjaState> render(
    WidgetTester tester, {
    required Size layar,
    bool kunciTitikTengah = false,
  }) async {
    tester.view.physicalSize = layar;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bentuk = lembarConductivity();
    final isian = LembarKerjaState(
      bentuk: bentuk,
      clientRequestId: 'tes-muat',
    );

    // DIISI SEBELUM render. `LembarKerjaTabel` itu StatelessWidget — ngisi
    // controller sesudah `pumpWidget` nggak nge-rebuild apa-apa, jadi barisnya
    // bakal kelihatan "nggak terkunci" walau state-nya bilang terkunci.
    if (kunciTitikTengah) {
      isian.titik[1412]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
          '1413';
    }

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LembarKerjaTabel(
                tabel: bentuk.bagian.first.tabel.first,
                isian: isian,
                onBerubah: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return isian;
  }

  /// HP paling sempit yang realistis dipakai teknisi di lapangan.
  const layarSempit = Size(360, 800);

  testWidgets('label bersatuan muat waktu baris belum terkunci', (
    tester,
  ) async {
    await render(tester, layar: layarSempit);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('1,412 mS/cm'), findsOneWidget);
  });

  /// Ini yang paling menekan: baris terkunci nambah keterangan DI BAWAH label
  /// yang sudah dua baris sendiri.
  testWidgets('label + keterangan baris terkunci tetap muat', (tester) async {
    final isian = await render(
      tester,
      layar: layarSempit,
      kunciTitikTengah: true,
    );

    expect(isian.titikTerkunci(1.412), isTrue);

    // Keterangannya beneran kegambar, bukan cuma hidup di state.
    final keterangan = find.text(
      AppLocalizations.of(
        tester.element(find.byType(LembarKerjaTabel)),
      ).lkTitikAlternatifSatuan,
    );
    expect(keterangan, findsOneWidget);

    // Label + keterangan harus MUAT di kotaknya, bukan cuma "nggak throw".
    // Teks yang meluber diam-diam kepotong `Align`, dan itu justru gejala yang
    // dilaporin: kelihatan berantakan tanpa ada error apa pun.
    final kotak = tester.getSize(
      find
          .ancestor(of: keterangan, matching: find.byType(SizedBox))
          .first,
    );
    final isi = tester.getSize(
      find.ancestor(of: keterangan, matching: find.byType(Column)).first,
    );

    expect(
      isi.height,
      lessThanOrEqualTo(kotak.height),
      reason:
          'Label + keterangan setinggi ${isi.height}px dijejalin ke kotak '
          '${kotak.height}px — inilah yang bikin lembar Conductivity kelihatan '
          'berantakan.',
    );
    expect(
      isi.width,
      lessThanOrEqualTo(kotak.width),
      reason: 'Label bersatuan selebar ${isi.width}px di kolom ${kotak.width}px.',
    );

    expect(tester.takeException(), isNull);
  });
}
