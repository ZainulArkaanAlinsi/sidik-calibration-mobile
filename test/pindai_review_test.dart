import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_scan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/pindai_review_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Layar review hasil pindai lembar kerja (OCR lokal).
///
/// Bentuk responsnya disalin dari `PemrosesScanLembarKerja` di repo API —
/// termasuk hal yang paling gampang kelewat: respons pindai **nggak** ngirim
/// `pengulangan` di level tabel, cuma di dalam tiap baris.
void main() {
  group('baca respons pindai', () {
    test('sel dibaca berkunci, urut nomor Repeat — bukan urutan array', () {
      // Array `pengulangan` sengaja DIACAK. Kalau layar ngandelin urutan
      // array, Repeat 3 bakal digambar di kolom pertama — dan itu persis
      // kegagalan "angka pindah kolom" yang mau dicegah fitur ini.
      final hasil = HasilPindai.fromJson(_responsAcak);
      final sel = hasil.tabel.first.baris.first.sel;

      expect([for (final s in sel) s.repeatNo], [1, 2, 3]);
      expect(
        [for (final s in sel) s.kunci],
        [
          'holmium|1|1|pembacaan',
          'holmium|1|2|pembacaan',
          'holmium|1|3|pembacaan',
        ],
      );
    });

    test('vonis & alasan kebaca apa adanya', () {
      final hasil = HasilPindai.fromJson(_responsAcak);
      final sel = hasil.tabel.first.baris.first.sel;

      expect(sel[0].vonis, VonisSel.kuning);
      expect(sel[0].nilai, 280.0);
      expect(sel[1].vonis, VonisSel.merah);
      expect(sel[1].alasan, contains('teks_meluber_dari_sel'));
      expect(sel[1].normalisasi, contains('O→0'));

      // Server yang mutusin tombol simpan boleh aktif atau nggak — bukan
      // dihitung ulang dari jumlah sel merah di HP.
      expect(hasil.bolehAutoIsi, isFalse);
      expect(hasil.wajibDicek, isTrue);
      expect(hasil.semuaSel, hasLength(3));
    });
  });

  group('layar review', () {
    testWidgets('sel merah dikosongin, bukan diisi bacaan yang diragukan', (
      tester,
    ) async {
      await _buka(tester);

      // Sel kuning keisi hasil bacanya; sel merah KOSONG walau server sempat
      // baca angkanya — vonis merah artinya bacaannya nggak bisa dipercaya,
      // dan nampilin angkanya duluan bikin teknisi cuma nyetujuin yang ada.
      final kotak = find.byType(TextField);

      expect(tester.widget<TextField>(kotak.at(0)).controller!.text, '280');
      expect(tester.widget<TextField>(kotak.at(1)).controller!.text, '');
    });

    testWidgets('alasan tampil sebagai kalimat, bukan kode mentah', (
      tester,
    ) async {
      await _buka(tester);

      expect(
        find.textContaining('tulisannya keluar dari kotak'),
        findsOneWidget,
      );
      expect(find.textContaining('teks_meluber_dari_sel'), findsNothing);

      // Teknisi berhak tahu angka yang dia lihat udah ditebak-tebak sampai
      // mana.
      expect(find.textContaining('O→0'), findsOneWidget);
      expect(find.textContaining('Terbaca: 28O'), findsOneWidget);
    });

    testWidgets('tombol simpan ditahan waktu server bilang belum boleh', (
      tester,
    ) async {
      await _buka(tester);

      final tombol = find.widgetWithText(FilledButton, 'PAKAI ANGKA INI');

      expect(tester.widget<FilledButton>(tombol).onPressed, isNull);
      expect(
        find.textContaining('Masih ada sel yang nggak kebaca'),
        findsOneWidget,
      );
    });

    testWidgets('simpan ngirim SEMUA sel, bukan cuma yang diubah', (
      tester,
    ) async {
      final service = MockWorksheetScanService(hasil: _hasilBolehSimpan);
      await _buka(tester, hasil: _hasilBolehSimpan, service: service);

      // Cuma satu sel yang dibetulin teknisi.
      await tester.enterText(find.byType(TextField).at(1), '280,5');
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAKAI ANGKA INI'));
      await tester.pumpAndSettle();

      final koreksi = service.koreksiTerkirim.single;

      // Ketiganya ikut — termasuk yang bacanya udah bener. Ini satu-satunya
      // sumber data akurasi sistem: sel yang dilewat berarti nggak ada bukti
      // bacanya bener.
      expect(koreksi, hasLength(3));
      expect(
        [for (final k in koreksi) k.kunci],
        [
          'holmium|1|1|pembacaan',
          'holmium|1|2|pembacaan',
          'holmium|1|3|pembacaan',
        ],
      );
      expect(koreksi[1].nilaiFinal, 280.5);
    });

    /// Yang dibalikin ke lembar kerja itu ALAMAT KOTAKNYA, bukan kunci sel.
    ///
    /// Kunci sel (`holmium|1|2|pembacaan`) bahasa server: `baris_ke` di situ
    /// nomor baris di lembar cetak, bukan titik ukurnya. Nerjemahin kunci jadi
    /// alamat kotak dengan mecah stringnya berarti nebak baris ke-1 itu titik
    /// yang mana — persis tebakan yang bikin angka mendarat di baris sebelah.
    /// Terjemahannya diambil dari respons server, yang emang ngirim
    /// `titik_ukur` per baris.
    testWidgets('yang dibalikin ke formulir: tahap + titik + Repeat + kolom', (
      tester,
    ) async {
      List<SelDipakaiPindai>? dipakai;

      await _buka(
        tester,
        hasil: _hasilBolehSimpan,
        service: MockWorksheetScanService(hasil: _hasilBolehSimpan),
        onKembali: (h) => dipakai = h,
      );

      await tester.enterText(find.byType(TextField).at(1), '280,5');
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAKAI ANGKA INI'));
      await tester.pumpAndSettle();

      // Sel yang kotaknya dikosongin (Repeat 3, memang kosong di kertasnya)
      // NGGAK ikut — yang kosong di kertas tetap kosong di formulir.
      expect(dipakai, hasLength(2));

      expect(dipakai!.first.tahap, 'sesudah_adjustment');
      expect(dipakai!.first.titikUkur, 279.6);
      expect(dipakai!.first.repeatNo, 1);
      expect(dipakai!.first.fieldId, 'pembacaan');
      expect(dipakai!.first.nilai, 280.0);

      // Vonis kuning/merah dibawa terus sebagai "perlu dicek": teknisi udah
      // lihat sekali di layar ini, dan tandanya yang bikin dia lihat sekali
      // lagi sebelum lembarnya dikirim.
      expect(dipakai!.every((s) => s.perluDicek), isTrue);
      expect(dipakai!.last.repeatNo, 2);
      expect(dipakai!.last.nilai, 280.5);
    });
  });
}

Future<void> _buka(
  WidgetTester tester, {
  HasilPindai? hasil,
  MockWorksheetScanService? service,
  void Function(List<SelDipakaiPindai>?)? onKembali,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        worksheetScanServiceProvider.overrideWithValue(
          service ?? MockWorksheetScanService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Layar review balikin hasilnya lewat `Navigator.pop`, dan route
        // paling bawah nggak bisa di-pop. Jadi waktu hasilnya yang diuji,
        // layarnya di-PUSH dari layar lain — sama kayak di aplikasi.
        home: onKembali == null
            ? PindaiReviewScreen(
                hasil: hasil ?? HasilPindai.fromJson(_responsAcak),
              )
            : _Peluncur(
                hasil: hasil ?? HasilPindai.fromJson(_responsAcak),
                onKembali: onKembali,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _hasilBolehSimpan = HasilPindai.fromJson({
  ..._responsAcak,
  'boleh_auto_isi': true,
  'wajib_dicek': true,
});

/// Respons pindai contoh, bentuknya ngikut `PemrosesScanLembarKerja` di repo
/// API: `tabel[].baris[].pengulangan[].kolom[field_id]`, **tanpa**
/// `pengulangan` di level tabel.
///
/// Urutan `pengulangan` sengaja diacak (3, 1, 2) — spec-nya bilang nggak ada
/// satu tahap pun yang boleh ngandelin urutan array, dan ini yang ngunci itu.
const _responsAcak = <String, dynamic>{
  'scan_id': 391,
  'status': 'perlu_review',
  'pipeline_versi': 'ocr-1.0.0',
  'aturan_versi': 'val-1.0.0',
  'ringkasan': {
    'total_sel': 3,
    'hijau': 0,
    'kuning': 1,
    'merah': 1,
    'kosong': 1,
  },
  'boleh_auto_isi': false,
  'wajib_dicek': true,
  'tabel': [
    {
      'tabel_id': 'holmium',
      'tahap': 'sesudah_adjustment',
      'grup': 'holmium',
      'judul': 'Wave Length ( λ ) - Filter Holmium',
      'baris': [
        {
          'baris_ke': 1,
          'titik_ukur': 279.6,
          'label': '279,6',
          'standard_id': 25,
          'satuan': 'nm',
          'desimal': 2,
          'pengulangan': [
            {
              'repeat_no': 3,
              'kolom': {
                'pembacaan': {
                  'kunci': 'holmium|1|3|pembacaan',
                  'teks_mentah': null,
                  'nilai': null,
                  'status': 'kosong',
                  'alasan': <String>[],
                  'normalisasi': <String>[],
                },
              },
            },
            {
              'repeat_no': 1,
              'kolom': {
                'pembacaan': {
                  'kunci': 'holmium|1|1|pembacaan',
                  'teks_mentah': '280',
                  'teks_normal': '280',
                  'nilai': 280,
                  'status': 'kuning',
                  'alasan': <String>[],
                  'normalisasi': <String>[],
                },
              },
            },
            {
              'repeat_no': 2,
              'kolom': {
                'pembacaan': {
                  'kunci': 'holmium|1|2|pembacaan',
                  'teks_mentah': '28O',
                  'teks_normal': '280',
                  'nilai': 280,
                  'status': 'merah',
                  'alasan': ['teks_meluber_dari_sel'],
                  'normalisasi': ['O→0'],
                },
              },
            },
          ],
        },
      ],
    },
  ],
};

/// Layar pemanggil — nangkep apa yang dibalikin layar review.
class _Peluncur extends StatefulWidget {
  const _Peluncur({required this.hasil, required this.onKembali});

  final HasilPindai hasil;
  final void Function(List<SelDipakaiPindai>?) onKembali;

  @override
  State<_Peluncur> createState() => _PeluncurState();
}

class _PeluncurState extends State<_Peluncur> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onKembali(
        await Navigator.of(context).push<List<SelDipakaiPindai>>(
          MaterialPageRoute<List<SelDipakaiPindai>>(
            builder: (_) => PindaiReviewScreen(hasil: widget.hasil),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
