import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/skema_dokumen.dart';
import 'package:sidik_calibration/screens/calibration/peta_kolom_screen.dart';
import 'package:sidik_calibration/services/peta_kolom_titik.dart';

/// Langkah manusia di jalur generik: teknisi menetapkan arti tiap kolom.
///
/// Yang dijaga di sini bukan tata letaknya, tapi **penolakannya**. Layar ini
/// satu-satunya penjaga antara "aplikasi nggak tahu kolom mana apa" dan angka
/// yang masuk ke sertifikat, jadi tiap jalan pintas yang bikin teknisi bisa
/// menekan terapkan tanpa memilih itu lubang yang tembus ke data.
void main() {
  /// Layar ini `ListView`, dan widget di luar viewport nggak dibangun sama
  /// sekali — tombol terapkannya jatuh di bawah lipatan begitu catatan
  /// statusnya nambah. Diadu di viewport bawaan 800x600, test-nya merah karena
  /// tombolnya nggak ada, bukan karena keadaannya salah.
  void layarPanjang(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 5200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  TabelSkema tabel(List<String> kepala, List<List<String>> baris) =>
      (kepala: kepala, baris: baris, kotak: Rect.zero);

  TabelSkema torque() => tabel(
    ['No', 'Target', 'Uji 1', 'Uji 2'],
    [
      ['1', '50', '49,8', '50,1'],
      ['2', '100', '99,5', '100,2'],
    ],
  );

  Future<PetaKolomTerpakai?> buka(WidgetTester tester, TabelSkema t) async {
    PetaKolomTerpakai? hasil;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              hasil = await Navigator.of(context).push<PetaKolomTerpakai>(
                MaterialPageRoute(builder: (_) => PetaKolomScreen(tabel: t)),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return hasil;
  }

  /// Tetapkan peran kolom ke-[i] lewat dropdown-nya.
  Future<void> tetapkan(WidgetTester tester, int i, String peran) async {
    // Tipe generiknya WAJIB persis: `byType` nggak nyocokin
    // `DropdownButton<dynamic>` ke `DropdownButton<PeranKolom>`.
    await tester.tap(find.byType(DropdownButton<PeranKolom>).at(i));
    await tester.pumpAndSettle();
    // Item dropdown yang kebuka muncul sebagai teks kedua dengan label sama.
    await tester.tap(find.text(peran).last);
    await tester.pumpAndSettle();
  }

  Finder tombolTerapkan() => find.widgetWithText(FilledButton, 'ISI TITIK UKUR');

  testWidgets('kepala kolom dari KERTASNYA yang dipajang', (tester) async {
    layarPanjang(tester);
    await buka(tester, torque());

    for (final k in ['No', 'Target', 'Uji 1', 'Uji 2']) {
      expect(find.text(k), findsOneWidget, reason: 'kepala kolom $k');
    }
  });

  testWidgets('contoh isi ikut dipajang — kepala kolom bisa nggak kebaca', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, torque());

    expect(
      find.textContaining('50'),
      findsWidgets,
      reason: 'Kepala kolom bisa nggak kebaca OCR atau emang nggak dicetak. '
          'Waktu itu terjadi, angkanya sendiri yang ngasih tau teknisi kolom '
          'mana yang dia lihat.',
    );
  });

  testWidgets('kolom tanpa kepala disebut nomornya, bukan dikosongin', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, tabel([], [
      ['50', '49,8', '50,1'],
    ]));

    expect(find.text('Kolom 1'), findsOneWidget);
    expect(find.text('Kolom 3'), findsOneWidget);
  });

  testWidgets('semua kolom mulai ABAIKAN — nggak ada yang dipilihkan', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, torque());

    expect(
      find.text('Abaikan'),
      findsNWidgets(4),
      reason: 'Nyetel tebakan awal bikin teknisi yang buru-buru nekan terapkan '
          'tanpa melihat, dan tebakan itu mendarat di data seolah dia yang '
          'milih.',
    );
    expect(tester.widget<FilledButton>(tombolTerapkan()).onPressed, isNull);
  });

  testWidgets('tombol MATI sampai acuan, pembacaan, DAN satuan lengkap', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, torque());

    expect(find.text('Belum ada kolom yang ditunjuk sebagai nilai acuan.'),
        findsOneWidget);

    await tetapkan(tester, 1, 'Nilai acuan');
    expect(
      tester.widget<FilledButton>(tombolTerapkan()).onPressed,
      isNull,
      reason: 'Acuan doang belum cukup — sebaran Type A butuh dua pembacaan.',
    );

    await tetapkan(tester, 2, 'Pembacaan');
    await tetapkan(tester, 3, 'Pembacaan');
    expect(
      tester.widget<FilledButton>(tombolTerapkan()).onPressed,
      isNull,
      reason: 'Satuannya masih kosong, dan satuan yang salah mengubah arti '
          'seluruh angkanya.',
    );

    await tester.enterText(find.byType(TextField), 'Nm');
    await tester.pump();

    expect(tester.widget<FilledButton>(tombolTerapkan()).onPressed, isNotNull);
  });

  testWidgets('dua kolom acuan ditolak, dan sebabnya disebut', (tester) async {
    layarPanjang(tester);
    await buka(tester, torque());

    await tetapkan(tester, 1, 'Nilai acuan');
    await tetapkan(tester, 2, 'Nilai acuan');

    expect(
      find.textContaining('Dua kolom ditunjuk jadi nilai acuan'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(tombolTerapkan()).onPressed, isNull);
  });

  testWidgets('berapa titik yang bakal lahir ditulis SEBELUM ditekan', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, torque());

    await tetapkan(tester, 1, 'Nilai acuan');
    await tetapkan(tester, 2, 'Pembacaan');
    await tetapkan(tester, 3, 'Pembacaan');

    expect(
      find.textContaining('2 titik ukur akan diisi'),
      findsOneWidget,
      reason: 'Sesudah ditekan, teknisi harus ngadu ke kertas buat tau ada '
          'yang hilang apa nggak.',
    );
  });

  testWidgets('baris yang dilewat DISEBUT, bukan hilang diam-diam', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, tabel(
      ['Target', 'R1', 'R2'],
      [
        ['50', '49,8', '50,1'],
        ['', '', ''],
      ],
    ));

    await tetapkan(tester, 0, 'Nilai acuan');
    await tetapkan(tester, 1, 'Pembacaan');
    await tetapkan(tester, 2, 'Pembacaan');

    expect(find.textContaining('1 baris dilewat'), findsOneWidget);
  });

  testWidgets('yang pulang: titik terpetakan + satuan yang DIKETIK teknisi', (
    tester,
  ) async {
    layarPanjang(tester);
    PetaKolomTerpakai? hasil;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              hasil = await Navigator.of(context).push<PetaKolomTerpakai>(
                MaterialPageRoute(
                  builder: (_) => PetaKolomScreen(tabel: torque()),
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

    await tetapkan(tester, 1, 'Nilai acuan');
    await tetapkan(tester, 2, 'Pembacaan');
    await tetapkan(tester, 3, 'Pembacaan');
    await tester.enterText(find.byType(TextField), 'Nm');
    await tester.pump();

    await tester.tap(tombolTerapkan());
    await tester.pumpAndSettle();

    expect(hasil!.satuan, 'Nm');
    expect(hasil!.titik, hasLength(2));
    expect(hasil!.titik[0].nilaiAcuan, '50');
    expect(hasil!.titik[0].pembacaan, ['49,8', '50,1']);
    expect(hasil!.titik[1].nilaiAcuan, '100');
    expect(
      hasil!.titik[1].pembacaan,
      ['99,5', '100,2'],
      reason: 'Kolom `No` sengaja diabaikan dan nggak boleh ikut jadi '
          'pembacaan — nomor urut bukan hasil ukur.',
    );
  });
}
