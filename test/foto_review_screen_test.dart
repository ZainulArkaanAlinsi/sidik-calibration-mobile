import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Layar review jalur FOTO — pintu terakhir sebelum angka hasil OCR mendarat
/// di lembar kerja.
///
/// Sampai 28 Agt 2026 pintu ini **nggak ada**: hasil OCR ditulis langsung ke
/// form. Berkas ini menjaga bahwa dia nggak diam-diam dibuka lagi, dan bahwa
/// tiga aturannya tetap berdiri.
void main() {
  BarisReviewFoto baris(
    String teks, {
    double? keyakinan,
    double titikUkur = 60,
    int repeatNo = 1,
    String judul = 'Set point 60 · Repeat 1 · Pembacaan',
  }) => (
    titikUkur: titikUkur,
    repeatNo: repeatNo,
    fieldId: 'pembacaan',
    judul: judul,
    teks: teks,
    keyakinan: keyakinan,
    vonis: NilaiVonisFoto.dari(keyakinan),
    potongan: null,
  );

  Future<List<SelTabelFoto>?> buka(
    WidgetTester tester,
    List<BarisReviewFoto> isi,
  ) async {
    List<SelTabelFoto>? hasil;

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
                  builder: (_) => FotoReviewScreen(baris: isi),
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

    return hasil;
  }

  testWidgets('nggak ada tombol "terima semua" di layar ini', (tester) async {
    await buka(tester, [baris('7,02', keyakinan: 0.95)]);

    for (final kata in ['TERIMA SEMUA', 'Terima semua', 'SETUJUI SEMUA']) {
      expect(
        find.text(kata),
        findsNothing,
        reason: 'Aturan 1: satu tombol yang melewati pemeriksaan menghapus '
            'seluruh guna layar ini. Tulisan tangan tetap dibaca pede sama '
            'pengenal teks waktu dia salah.',
      );
    }
  });

  testWidgets('sel merah mulai KOSONG walau OCR sempat baca angkanya', (
    tester,
  ) async {
    await buka(tester, [baris('7,2', keyakinan: 0.31)]);

    final kotak = tester.widget<TextField>(find.byType(TextField));

    expect(
      kotak.controller!.text,
      isEmpty,
      reason: 'Aturan 3: vonis merah artinya bacaannya nggak bisa dipercaya. '
          'Nampilin "7,2" duluan bikin teknisi cuma menyetujui apa yang udah '
          'ada — dan itu persis salah baca yang mau ditangkap.',
    );
  });

  testWidgets('sel kuning nilainya DITAMPILKAN — yang diminta cuma dilihat', (
    tester,
  ) async {
    await buka(tester, [baris('7,02', keyakinan: 0.82)]);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '7,02',
      reason: 'Nuntut teknisi ngetik ulang 30 sel yang bacaannya udah bener '
          'bikin dia berhenti memakai fiturnya.',
    );
  });

  testWidgets('keyakinan yang nggak dilaporkan disebut apa adanya, bukan 0%', (
    tester,
  ) async {
    await buka(tester, [baris('7,02')]);

    expect(find.textContaining('tidak dilaporkan'), findsOneWidget);
    expect(
      find.textContaining('0%'),
      findsNothing,
      reason: '0% berarti "yakin banget salah" — klaim yang nggak pernah '
          'dibuat siapa pun.',
    );
  });

  testWidgets('tombol Masukkan MATI selama sel merah masih kosong', (
    tester,
  ) async {
    await buka(tester, [
      baris('7,02', keyakinan: 0.95),
      baris('9,9', keyakinan: 0.20, repeatNo: 2),
    ]);

    final tombol = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(
      tombol.onPressed,
      isNull,
      reason: 'Sel merah dikosongkan; menyetujuinya tanpa mengetik berarti '
          'memasukkan sel kosong ke lembar.',
    );
  });

  testWidgets('sesudah sel merah diisi, yang balik ANGKA YANG DIKETIK', (
    tester,
  ) async {
    List<SelTabelFoto>? hasil;

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
                  builder: (_) => FotoReviewScreen(
                    baris: [baris('7,2', keyakinan: 0.31)],
                  ),
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

    await tester.enterText(find.byType(TextField), '7,02');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(hasil, hasLength(1));
    expect(
      hasil!.single.teks,
      '7,02',
      reason: 'Yang masuk lembar koreksi teknisi, bukan bacaan OCR-nya.',
    );
    expect(
      hasil!.single.keyakinan,
      0.31,
      reason: 'Keyakinan OCR ASLINYA dibawa apa adanya. Dinaikin jadi 1.0 '
          'gara-gara diketik ulang, pengumpul data latih nggak bisa lagi '
          'membedakan mana yang dibaca mesin dan mana yang diketik orang.',
    );
  });

  testWidgets('dibatalkan = NOL angka masuk', (tester) async {
    List<SelTabelFoto>? hasil;
    var selesai = false;

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
                  builder: (_) => FotoReviewScreen(
                    baris: [baris('7,02', keyakinan: 0.95)],
                  ),
                ),
              );
              selesai = true;
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Ditutup TANPA menekan Masukkan — persis tombol kembali di HP.
    Navigator.of(tester.element(find.byType(FotoReviewScreen))).pop();
    await tester.pumpAndSettle();

    expect(selesai, isTrue, reason: 'layarnya beneran ketutup');
    expect(
      hasil,
      isNull,
      reason: 'Batal harus memulangkan null, bukan daftar kosong: pemanggil '
          'membedakan "teknisi menolak" dari "disetujui tapi nol sel", dan '
          'yang kedua nggak boleh menghapus apa pun di lembar.',
    );
  });

  testWidgets('yang paling butuh diperiksa ditaruh DULUAN', (tester) async {
    final urut = susunReviewFoto(
      sel: [
        (
          titikUkur: 10,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: 'a',
          keyakinan: 0.95,
        ),
        (
          titikUkur: 20,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: 'b',
          keyakinan: null,
        ),
        (
          titikUkur: 30,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: 'c',
          keyakinan: 0.10,
        ),
      ],
      judul: (s) => '${s.titikUkur}',
    );

    expect(
      urut.map((b) => b.vonis).toList(),
      [VonisFoto.merah, VonisFoto.tidakDiketahui, VonisFoto.kuning],
      reason: 'Layar yang ngurut menurut nomor baris bikin sel merah '
          'tenggelam di tengah tiga puluh sel yang bacaannya wajar — dan yang '
          'paling mungkin salah justru yang paling gampang kelewat.',
    );
  });
}
