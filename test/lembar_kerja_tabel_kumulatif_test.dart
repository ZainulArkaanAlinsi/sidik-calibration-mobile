import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_piston.dart';

/// Tabel massa KUMULATIF piston volume wajib menggambar selisih
/// `M_i − M_{i−1}` di bawah tiap kotak.
///
/// Tanpa selisih, salah ketik satu digit di angka kumulatif tidak kelihatan:
/// 30,1368 → 30,7368 tidak menggeser rata-rata sepuluh pemindahan sama sekali
/// (selisih berurutan saling meniadakan), dan yang membengkak cuma simpangan
/// bakunya — angka yang baru terlihat di sertifikat. Dengan selisih, dua kotak bertetangga langsung melenceng
/// 0,6 g ke arah berlawanan di layar.
///
/// Bentuknya diambil dari fixture yang DIGENERATE server
/// (`contoh_lembar_kerja_piston.dart`), bukan diketik ulang di sini, supaya
/// test ini ikut merah kalau server berhenti mengirim `kumulatif: true`.
void main() {
  const merah = Color(0xFFC62828);

  LembarKerja bentukPipet() =>
      LembarKerja.fromJson(contohBentukLembarKerjaPistonPipette());

  TabelHasil tabelKumulatif(LembarKerja bentuk) =>
      bentuk.bagian.expand((b) => b.tabel).firstWhere((t) => t.kumulatif);

  TabelHasil tabelSuhu(LembarKerja bentuk) => bentuk.bagian
      .expand((b) => b.tabel)
      .firstWhere((t) => t.simpanKe == 'measurements[].piston_suhu_air');

  Future<void> render(
    WidgetTester tester,
    LembarKerjaState isian,
    TabelHasil tabel,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LembarKerjaTabel(
                tabel: tabel,
                isian: isian,
                onBerubah: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Kotak ke-[i] (0 = kotak pertama) di baris pertama [tabel].
  TextEditingController kotak(
    LembarKerjaState isian,
    TabelHasil tabel,
    int i,
  ) => isian.titik[isian.kunciBaris(isian.barisTabel(tabel), 0, tabel)]!
      .kotak(tabel.kunciTabel, 'pembacaan', i);

  test('server menandai tabel massa sebagai kumulatif, tabel suhu tidak', () {
    final bentuk = bentukPipet();

    expect(tabelKumulatif(bentuk).simpanKe, 'measurements[].piston_kumulatif');
    expect(tabelKumulatif(bentuk).pengulangan, hasLength(11));
    expect(tabelSuhu(bentuk).kumulatif, isFalse);
  });

  testWidgets('selisih tiap kotak digambar, sepresisi angka yang diketik', (
    tester,
  ) async {
    final bentuk = bentukPipet();
    final tabel = tabelKumulatif(bentuk);
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'tes-kum');

    const massa = ['0', '10.0768', '20.1327', '30.1368'];
    for (var i = 0; i < massa.length; i++) {
      kotak(isian, tabel, i).text = massa[i];
    }

    await render(tester, isian, tabel);

    expect(tester.takeException(), isNull);
    expect(find.text('Δ 10,0768'), findsOneWidget);
    expect(find.text('Δ 10,0559'), findsOneWidget);
    expect(find.text('Δ 10,0041'), findsOneWidget);
  });

  testWidgets('salah ketik satu digit menggeser DUA selisih berlawanan arah', (
    tester,
  ) async {
    final bentuk = bentukPipet();
    final tabel = tabelKumulatif(bentuk);
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'tes-kum');

    const massa = ['0', '10.0768', '20.1327', '30.1368', '40.1319'];
    for (var i = 0; i < massa.length; i++) {
      kotak(isian, tabel, i).text = massa[i];
    }

    await render(tester, isian, tabel);
    expect(find.text('Δ 10,0041'), findsOneWidget);
    expect(find.text('Δ 9,9951'), findsOneWidget);

    // Diketik ulang lewat layar, bukan disetel ke controller: selisih kotak
    // SEBELAHNYA juga harus ikut bergeser tanpa kotak itu disentuh.
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller == kotak(isian, tabel, 3),
      ),
      '30.7368',
    );
    await tester.pump();

    expect(find.text('Δ 10,6041'), findsOneWidget);
    expect(find.text('Δ 9,3951'), findsOneWidget);
  });

  testWidgets('massa kumulatif yang TURUN digambar merah', (tester) async {
    final bentuk = bentukPipet();
    final tabel = tabelKumulatif(bentuk);
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'tes-kum');

    kotak(isian, tabel, 0).text = '10.0768';
    kotak(isian, tabel, 1).text = '5';

    await render(tester, isian, tabel);

    final teks = tester.widget<Text>(find.text('Δ -5,0768'));
    expect(teks.style?.color, merah);
  });

  testWidgets('kotak kosong tidak menggambar selisih tebakan', (tester) async {
    final bentuk = bentukPipet();
    final tabel = tabelKumulatif(bentuk);
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'tes-kum');

    kotak(isian, tabel, 0).text = '0';

    await render(tester, isian, tabel);

    expect(find.textContaining('Δ'), findsNothing);
  });

  testWidgets('tabel suhu air tidak menggambar selisih', (tester) async {
    final bentuk = bentukPipet();
    final tabel = tabelSuhu(bentuk);
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'tes-kum');

    kotak(isian, tabel, 0).text = '27.1';
    kotak(isian, tabel, 1).text = '27.3';

    await render(tester, isian, tabel);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Δ'), findsNothing);
  });
}
