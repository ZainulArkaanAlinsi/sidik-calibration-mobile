import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/inti/sesi_studio.dart';
import 'package:sidik_studio/layar/beranda/beranda_screen.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/layar/workbook/daftar_workbook_screen.dart';
import 'package:sidik_studio/layar/workbook/workbook_screen.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu/studio_uji.dart';

/// Workbook Alat (S1b, tampilan Tahap A) — layar daftar & workbook dengan
/// `MockWorkbookService` (nilai dari CSV master Micrometer 0-25mm & Height
/// Gauge 600 mm; lihat docblock mock-nya).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('daftar', () {
    testWidgets('kelompok per keluarga, "Belum dipetakan" paling bawah; '
        '.xlsm berlencana "Excel asli", ekspor CSV alat yang sama di bawah '
        '"Sumber lain"; cari menyaring di server (server sebelum K-49-13: '
        'daftar memuat kembaran CSV, tanpa kunci jenis)', (tester) async {
      final mock = MockWorkbookService(serverLama: true);
      await _bukaDaftar(tester, mock);
      // Tanpa kunci jenis: tidak ada "Impor #n" maupun "Riwayat (n)".
      expect(find.textContaining('Impor #'), findsNothing);
      expect(find.textContaining('Riwayat ('), findsNothing);

      final dimensi = find.byKey(const ValueKey('kelompok-Dimensi'));
      final belum = find.byKey(const ValueKey('kelompok--'));
      expect(dimensi, findsOneWidget);
      expect(belum, findsOneWidget);
      expect(
        tester.getTopLeft(dimensi).dy,
        lessThan(tester.getTopLeft(belum).dy),
      );
      expect(
        find.descendant(
          of: belum,
          matching: find.text('Master_olda_Height_Gauge_600_mm_2026'),
        ),
        findsOneWidget,
      );
      expect(find.text('Excel asli'), findsOneWidget);
      expect(find.text('4 lembar'), findsOneWidget);
      // CSV kembaran Micrometer tersembunyi; CSV Height Gauge (tanpa .xlsm)
      // tetap tampil biasa.
      expect(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometerCsv}'),
        ),
        findsNothing,
      );
      expect(find.text('CSV'), findsOneWidget);
      expect(
        find.byTooltip(
          'Dari ekspor CSV: nilai tersimpan saja — tanpa rumus, tanpa tata '
          'letak.',
        ),
        findsOneWidget,
      );

      final sumberLain = find.byKey(
        const ValueKey('sumber-lain-${MockWorkbookService.idMicrometer}'),
      );
      expect(
        find.descendant(of: sumberLain, matching: find.text('Sumber lain (1)')),
        findsOneWidget,
      );
      await tester.tap(sumberLain);
      await tenang(tester);
      expect(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometerCsv}'),
        ),
        findsOneWidget,
      );
      expect(find.text('CSV'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'height');
      await tester.pump(const Duration(milliseconds: 350));
      await tenang(tester);
      expect(find.byKey(const ValueKey('workbook-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('workbook-1')), findsNothing);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump(const Duration(milliseconds: 350));
      await tenang(tester);
      expect(
        find.text('Tidak ada workbook yang cocok dengan “xyz”.'),
        findsOneWidget,
      );
    });

    test('pasangan sumber: nama dinormalkan seperti server; tanpa .xlsm '
        'semua tetap tampil', () {
      expect(
        normalkanNamaWorkbook('Master_Olah_Data_Micrometer_0-25mm'),
        normalkanNamaWorkbook('Master Olah Data Micrometer 0-25mm.xlsm'),
      );
      WorkbookRingkas wb(int id, String nama, String sumber) =>
          WorkbookRingkas.fromJson({'id': id, 'nama': nama, 'sumber': sumber});
      final baris = pasangkanSumberWorkbook([
        wb(1, 'Alat_A', 'csv'),
        wb(2, 'Alat A.xlsm', 'xlsm'),
        wb(3, 'Alat B', 'csv'),
        wb(4, 'Alat_B', 'csv'),
      ]);
      expect(
        baris.map((b) => '${b.utama.id}:${b.lain.map((l) => l.id).join(',')}'),
        ['2:1', '3:', '4:'],
      );
    });

    testWidgets('gagal dimuat → pesan + coba lagi', (tester) async {
      await _bukaDaftar(tester, MockWorkbookService(gagal: true));
      expect(find.text('Workbook gagal dimuat.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Coba lagi'), findsOneWidget);
    });
  });

  group('workbook (meja 1440 × 900)', () {
    testWidgets('SATU bilah layar penuh, bilah rumus selebar layar, tab '
        'lembar & bilah status di bawah; kotak nama, bilah rumus & inspektur '
        'mengikuti sel aktif; NILAI PERSIS ≠ teks tampil', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);

      // Layar penuh di atas cangkang: bilah & navigasi cangkang tidak
      // tampil (bukan header ganda).
      expect(find.text('Workbook Alat'), findsNothing);
      expect(navigasi(SeksiStudio.beranda), findsNothing);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      expect(find.byType(GridSel), findsOneWidget);
      // Lanskap lebar: inspektur terbuka bawaan, di samping grid.
      expect(find.byType(InspekturSelWorkbook), findsOneWidget);
      expect(find.text('Budget Ketidakpastian Micrometer'), findsWidgets);

      final grid = tester.getRect(find.byType(GridSel));
      final rumus = tester.getRect(
        find.byKey(const ValueKey('isi-bilah-rumus')),
      );
      final panel = tester.getRect(
        find.byKey(const ValueKey('panel-inspektur')),
      );
      final tab = tester.getRect(
        find.byKey(
          const ValueKey('tab-lembar-${MockWorkbookService.idLembarU95}'),
        ),
      );
      final kaki = tester.getRect(find.byKey(const ValueKey('kaki-sel')));
      expect(tester.getRect(find.byKey(const ValueKey('kotak-nama'))).left, 0);
      expect(rumus.right, greaterThan(1430)); // di atas grid DAN inspektur
      expect(panel.top, greaterThanOrEqualTo(rumus.bottom));
      expect(panel.left, greaterThanOrEqualTo(grid.right));
      expect(tab.top, greaterThanOrEqualTo(grid.bottom));
      expect(kaki.top, greaterThanOrEqualTo(tab.bottom));

      // N6 = √3 di CSV master; format sel 0.0000.
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('N6')!)));
      await tenang(tester);
      expect(_teksKunci(tester, 'kotak-nama'), 'N6');
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '=SQRT(3)');
      expect(_selectable(tester, 'inspektur-nilai'), '1.7320508075688772');
      expect(_selectable(tester, 'inspektur-teks'), '1.7321');
      expect(_selectable(tester, 'inspektur-rumus'), '=SQRT(3)');

      // K6 tanpa rumus: bilah rumus menampilkan NILAI, bukan teks berformat.
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('K6')!)));
      await tenang(tester);
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '0.127');
      expect(_selectable(tester, 'inspektur-rumus'), '—');

      // Teks panjang B8 meluber (tidak digabung) — tetap utuh di bilah rumus.
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('B8')!)));
      await tenang(tester);
      expect(
        _teksKunci(tester, 'isi-bilah-rumus'),
        'Perubahan suhu terhadap suhu acuan 200c',
      );

      // Panah ke T6 (di luar layar) → digulir masuk; J tersembunyi dilewati.
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('N6')!)));
      await tenang(tester);
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tenang(tester);
      expect(_teksKunci(tester, 'kotak-nama'), 'T6');
      expect(find.byKey(kunciSelGrid(AlamatSel.urai('T6')!)), findsOneWidget);
      expect(_selectable(tester, 'inspektur-nilai'), '0.07332348418708248');
      expect(_selectable(tester, 'inspektur-teks'), '0.07332');
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '=K6/N6');

      // Tombol "tampilkan rumus" = Ctrl+`.
      final diGrid = find.descendant(
        of: find.byType(GridSel),
        matching: find.text('=K6/N6'),
      );
      expect(diGrid, findsNothing);
      await tester.tap(find.byKey(const ValueKey('tombol-rumus')));
      await tenang(tester);
      expect(diGrid, findsOneWidget);

      // Pilihan rentang disebut di kaki.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tenang(tester);
      expect(_teksKunci(tester, 'kaki-pilihan'), 'Pilihan T6:T7 (2 sel)');

      // Inspektur bisa ditutup & dibuka lagi; grid melebar mengisi ruangnya.
      await tester.tap(find.byKey(const ValueKey('tutup-inspektur')));
      await tenang(tester);
      expect(find.byType(InspekturSelWorkbook), findsNothing);
      expect(tester.getRect(find.byType(GridSel)).right, greaterThan(1430));
      await tester.tap(find.byTooltip('Inspektur sel'));
      await tenang(tester);
      expect(find.byType(InspekturSelWorkbook), findsOneWidget);
    });

    testWidgets('zoom di bilah status: −/+ selangkah 10 %, menu persen & '
        '"pas lebar"; kolom ikut melebar', (tester) async {
      await _bukaWorkbook(
        tester,
        MockWorkbookService(),
        MockWorkbookService.idMicrometer,
      );
      final k6 = find.byKey(kunciSelGrid(AlamatSel.urai('K6')!));
      final lebar = tester.getSize(k6).width;
      expect(_teksKunci(tester, 'zoom-persen'), '100%');

      await tester.tap(find.byKey(const ValueKey('zoom-perbesar')));
      await tenang(tester);
      expect(_teksKunci(tester, 'zoom-persen'), '110%');
      expect(tester.getSize(k6).width, (lebar * 1.1).roundToDouble());

      await tester.tap(find.byKey(const ValueKey('zoom-perkecil')));
      await tester.tap(find.byKey(const ValueKey('zoom-perkecil')));
      await tenang(tester);
      expect(_teksKunci(tester, 'zoom-persen'), '90%');

      await tester.tap(find.byKey(const ValueKey('zoom-nilai')));
      await tenang(tester);
      await tester.tap(find.text('150%').last);
      await tenang(tester);
      expect(_teksKunci(tester, 'zoom-persen'), '150%');

      await tester.tap(find.byKey(const ValueKey('zoom-nilai')));
      await tenang(tester);
      await tester.tap(find.byKey(const ValueKey('zoom-pas-lebar')));
      await tenang(tester);
      // 38 kolom tidak muat di ±1140 dp → diperkecil.
      expect(_teksKunci(tester, 'zoom-persen'), isNot('150%'));
      final persen = int.parse(
        _teksKunci(tester, 'zoom-persen')!.replaceAll('%', ''),
      );
      expect(persen, lessThan(100));
      expect(persen, greaterThanOrEqualTo(50));
    });

    testWidgets('lembar tersembunyi TIDAK di tab sampai ditampilkan lewat '
        'klik kanan bilah tab → "Tampilkan lembar tersembunyi…" (seperti '
        'Unhide Excel), lalu ditandai; DATABASE BERISI (K-49-12) → grid + '
        'chip "juga di tabel customers"; SERTIFIKAT dikecualikan → panel, '
        'selnya tidak pernah diminta', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);

      final tabStandar = find.byKey(
        const ValueKey('tab-lembar-${MockWorkbookService.idLembarStandar}'),
      );
      expect(tabStandar, findsNothing);
      await tester.tapAt(
        tester.getCenter(
          find.byKey(
            const ValueKey('tab-lembar-${MockWorkbookService.idLembarU95}'),
          ),
        ),
        buttons: kSecondaryButton,
      );
      await tenang(tester);
      await tester.tap(find.byKey(const ValueKey('menu-tampilkan-lembar')));
      await tenang(tester);
      expect(
        find.byKey(const ValueKey('dialog-tampilkan-lembar')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('pilih-lembar-${MockWorkbookService.idLembarStandar}'),
        ),
      );
      await tenang(tester);
      // Ditampilkan (sesi layar ini saja) & langsung dibuka.
      expect(tabStandar, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GridSel),
          matching: find.text('STANDAR GAUGE BLOCK'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tabStandar,
          matching: find.byIcon(Icons.visibility_off_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Lembar tersembunyi di Excel'), findsOneWidget);
      final namaStandar = tester.widget<Text>(
        find.descendant(of: tabStandar, matching: find.text('Standar_GB')),
      );
      expect(namaStandar.style?.fontStyle, FontStyle.italic);

      // DATABASE: isinya tampil sebagai grid biasa + chip tautan tabel.
      await tester.tap(
        find.byKey(
          const ValueKey('tab-lembar-${MockWorkbookService.idLembarDatabase}'),
        ),
      );
      await tenang(tester);
      expect(find.byType(GridSel), findsOneWidget);
      expect(find.byType(PanelLembarDikecualikan), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GridSel),
          matching: find.text(' COMMON DATA '),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chip-tautan-tabel')),
          matching: find.text('Juga di tabel customers'),
        ),
        findsOneWidget,
      );

      // SERTIFIKAT (impor lama): panel penanda, BUKAN grid.
      await tester.tap(
        find.byKey(
          const ValueKey(
            'tab-lembar-${MockWorkbookService.idLembarSertifikat}',
          ),
        ),
      );
      await tenang(tester);
      expect(
        find.text(
          'Isi lembar ini data pelanggan/sertifikat — dikelola di tabel '
          'certificates',
        ),
        findsOneWidget,
      );
      expect(find.byType(PanelLembarDikecualikan), findsOneWidget);
      expect(find.byType(GridSel), findsNothing);
      expect(find.byType(InspekturSelWorkbook), findsNothing);
      expect(find.byKey(const ValueKey('kaki-sel')), findsNothing);
      expect(find.byKey(const ValueKey('chip-tautan-tabel')), findsNothing);
      expect(
        mock.panggilanSel.where(
          (p) => p.contains('/${MockWorkbookService.idLembarSertifikat}/'),
        ),
        isEmpty,
      );

      // Lembar tersembunyi tetap bisa dibaca; nomor seri berawalan nol =
      // TEKS (rata kiri), bukan angka.
      await tester.tap(tabStandar);
      await tenang(tester);
      expect(
        find.descendant(
          of: find.byType(GridSel),
          matching: find.text('STANDAR GAUGE BLOCK'),
        ),
        findsOneWidget,
      );
      final a11 = tester.getRect(find.byKey(kunciSelGrid(AlamatSel(11, 1))));
      expect(
        tester.getRect(find.text('07427')).left - a11.left,
        closeTo(2, 0.01),
      );
      expect(_teksKunci(tester, 'kaki-sel'), '19 sel · 0 rumus');
      expect(find.text('Sumber XLSM'), findsOneWidget);
      expect(find.text('sha256 9c1b6a4f0e2d'), findsOneWidget);
    });

    testWidgets('CSV: sel dimuat per halaman 200 baris saat dibutuhkan, '
        'halaman yang sudah termuat tidak diminta ulang', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idHeightGauge);

      expect(mock.panggilanSel, ['2/21/1-200']);
      expect(find.text('ALL STANDARDS ARE VALID'), findsOneWidget);

      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('B10')!)));
      await tenang(tester);
      await _ctrl(tester, LogicalKeyboardKey.end);
      expect(_teksKunci(tester, 'kotak-nama'), 'Z300');
      expect(mock.panggilanSel, ['2/21/1-200', '2/21/201-400']);

      await _ctrl(tester, LogicalKeyboardKey.home);
      expect(_teksKunci(tester, 'kotak-nama'), 'A1');
      expect(mock.panggilanSel, ['2/21/1-200', '2/21/201-400']);
    });

    testWidgets('CSV dengan lebar kolom perkiraan server: chip "Lebar '
        'perkiraan" di bilah status', (tester) async {
      // Server lama: CSV kembaran dibuka dari "Sumber lain" (server K-49-13:
      // dari Riwayat — `workbook_riwayat_test.dart`).
      final mock = MockWorkbookService(serverLama: true);
      await _bukaDaftar(tester, mock);
      await tester.tap(
        find.byKey(
          const ValueKey('sumber-lain-${MockWorkbookService.idMicrometer}'),
        ),
      );
      await tenang(tester);
      await tester.tap(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometerCsv}'),
        ),
      );
      await tenang(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chip-lebar-perkiraan')),
          matching: find.text('Lebar perkiraan'),
        ),
        findsOneWidget,
      );
      // Sel CSV: `s` yang SUDAH teks Excel dipakai apa adanya (K6 `0.127`);
      // `s` angka MENTAH tulisan skrip (N6 `1.7320508075688772`, 17 digit —
      // Excel tak pernah menulis > 15) dibangun General dari `n` untuk
      // lebar kolomnya, bukan `####`.
      String teksSel(String a) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(kunciSelGrid(AlamatSel.urai(a)!)),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(teksSel('N6'), '1.732050808');
      expect(teksSel('K6'), '0.127');
    });

    testWidgets('workbook lab lain / tidak ada → pesan 404 jujur', (
      tester,
    ) async {
      await _bukaDaftar(tester, MockWorkbookService());
      Navigator.of(tester.element(find.byType(DaftarWorkbookScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => const WorkbookScreen(workbookId: 999, judul: 'X'),
        ),
      );
      await tenang(tester);
      expect(
        find.text('Workbook tidak ditemukan, atau bukan milik lab ini.'),
        findsOneWidget,
      );
    });

    testWidgets('xlsm: angka General (f kosong) digambar dari n untuk lebar '
        'kolomnya seperti Excel; bilah rumus 15 digit; inspektur tetap n '
        'persis & s server', (tester) async {
      await _bukaWorkbook(
        tester,
        MockWorkbookService(),
        MockWorkbookService.idMicrometer,
      );
      // V8 = 6.0001600000000005e-05, kolom bawaan 64 dp. `s` server
      // (PhpSpreadsheet) tak muat → dulu `########`; Excel: `6E-05`.
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('N6')!)));
      await tenang(tester);
      for (final k in [
        for (var i = 0; i < 8; i++) LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await tester.sendKeyEvent(k);
      }
      await tenang(tester);
      expect(_teksKunci(tester, 'kotak-nama'), 'V8');
      final v8 = find.byKey(kunciSelGrid(AlamatSel.urai('V8')!));
      expect(
        find.descendant(of: v8, matching: find.text('6E-05')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: v8, matching: find.textContaining('#')),
        findsNothing,
      );
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '0.0000600016');
      expect(_selectable(tester, 'inspektur-nilai'), '0.000060001600000000005');
      expect(_selectable(tester, 'inspektur-teks'), '0.000060001600000000005');

      // Format eksplisit tetap `s` server: T6 `0.00000` → 0.07332.
      expect(
        find.descendant(
          of: find.byKey(kunciSelGrid(AlamatSel.urai('T6')!)),
          matching: find.text('0.07332'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('426 SUDAH tercatat saat layar workbook dibangun → layar '
        'langsung menutup (listen tidak menembak untuk nilai awal)', (
      tester,
    ) async {
      await _bukaDaftar(tester, MockWorkbookService());
      wadahDari(tester).read(klienKedaluwarsaProvider.notifier).tandai();
      await tenang(tester);
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
        rootNavigator: true,
      ).push(
        MaterialPageRoute<void>(
          builder: (_) => const WorkbookScreen(
            workbookId: MockWorkbookService.idMicrometer,
            judul: 'X',
          ),
        ),
      );
      await tenang(tester);
      expect(find.byType(WorkbookScreen), findsNothing);
    });

    testWidgets('keluar akun saat workbook terbuka: layar workbook (rute '
        'akar) ikut tertutup, bukan tertinggal di atas layar masuk', (
      tester,
    ) async {
      await _bukaWorkbook(
        tester,
        MockWorkbookService(),
        MockWorkbookService.idMicrometer,
      );
      // Keluar menunggu timer — dipompa dulu, baru ditunggu.
      final keluar = keluarStudio(wadahDari(tester));
      await tenang(tester);
      await keluar;
      await tenang(tester);
      expect(find.byType(WorkbookScreen), findsNothing);
      expect(find.text('Masuk ke Studio'), findsOneWidget);
    });
  });

  group('workbook (tablet)', () {
    testWidgets('potret: inspektur TERTUTUP bawaan; tekan lama sel → panel '
        'geser dari kanan MENUTUPI grid (grid tidak menyempit); tombol × '
        'menutupnya', (tester) async {
      await _bukaWorkbook(
        tester,
        MockWorkbookService(),
        MockWorkbookService.idMicrometer,
        ukuran: const Size(711, 1138),
        meja: false,
      );
      expect(find.byType(InspekturSelWorkbook), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      final lebarGrid = tester.getSize(find.byType(GridSel)).width;
      expect(lebarGrid, 711);

      await tester.longPress(find.byKey(kunciSelGrid(AlamatSel.urai('K6')!)));
      await tenang(tester);
      expect(find.byType(InspekturSelWorkbook), findsOneWidget);
      expect(_selectable(tester, 'inspektur-nilai'), '0.127');
      expect(tester.getSize(find.byType(GridSel)).width, lebarGrid);
      final panel = tester.getRect(
        find.byKey(const ValueKey('panel-inspektur')),
      );
      expect(panel.right, 711);
      expect(panel.width, lessThanOrEqualTo(300));

      await tester.tap(find.byKey(const ValueKey('tutup-inspektur')));
      await tenang(tester);
      expect(find.byType(InspekturSelWorkbook), findsNothing);

      // Tombol di bilah atas membukanya juga.
      await tester.tap(find.byTooltip('Inspektur sel'));
      await tenang(tester);
      expect(find.byType(InspekturSelWorkbook), findsOneWidget);
    });

    testWidgets('lanskap: inspektur terbuka bawaan di samping grid; '
        'ditutup → grid selebar layar', (tester) async {
      await _bukaWorkbook(
        tester,
        MockWorkbookService(),
        MockWorkbookService.idMicrometer,
        ukuran: const Size(1138, 711),
        meja: false,
      );
      expect(find.byType(InspekturSelWorkbook), findsOneWidget);
      expect(tester.getSize(find.byType(GridSel)).width, lessThan(1138 - 290));
      await tester.tap(find.byTooltip('Tutup inspektur').first);
      await tenang(tester);
      expect(find.byType(InspekturSelWorkbook), findsNothing);
      expect(tester.getSize(find.byType(GridSel)).width, 1138);
    });
  });

  group('gerbang & Beranda', () {
    testWidgets('tanpa workbook.lihat: seksi & kartu tidak tampil, server '
        'tidak ditembak', (tester) async {
      final mock = MockWorkbookService();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, token: 'mock-token-1', workbook: mock),
      );
      await tenang(tester);

      expect(navigasi(SeksiStudio.workbookAlat), findsNothing);
      expect(find.byKey(const ValueKey('kartu-workbook')), findsNothing);
      expect(mock.panggilanDaftar, 0);
    });

    testWidgets('dengan izin: kartu Beranda menghitung workbook; Buka → '
        'seksi Workbook Alat', (tester) async {
      final mock = MockWorkbookService();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          izin: _izin,
          workbook: mock,
        ),
      );
      await tenang(tester);

      final kartu = find.byKey(const ValueKey('kartu-workbook'));
      expect(kartu, findsOneWidget);
      // K-49-13: master aktif saja (CSV kembaran Micrometer = riwayat).
      expect(
        find.descendant(
          of: kartu,
          matching: find.text('2 workbook · 1 belum dipetakan'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 dari CSV · 1 dari .xlsm'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: kartu,
          matching: find.widgetWithText(TextButton, 'Buka'),
        ),
      );
      await tenang(tester);
      expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
      expect(find.byType(BerandaScreen), findsNothing);
    });

    testWidgets('ganti akun: daftar workbook DITARIK ULANG untuk akun '
        'berikutnya, bukan sisa akun sebelumnya', (tester) async {
      final mock = MockWorkbookService();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, izin: _izin, workbook: mock),
      );
      await tenang(tester);
      await masukLewatLayar(tester, 'SDK-0001', 'rahasia123');
      expect(mock.panggilanDaftar, 1);

      await tester.tap(find.byTooltip('Keluar'));
      await tenang(tester);
      await masukLewatLayar(tester, 'SDK-0002', 'rahasia123');

      expect(mock.panggilanDaftar, 2);
      expect(find.text('2 workbook · 1 belum dipetakan'), findsOneWidget);
    });
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

const _izin = Izin(
  role: UserRole.admin,
  boleh: {NamaIzin.dataAcuanLihat, izinWorkbookLihat},
);

Future<void> _bukaDaftar(
  WidgetTester tester,
  MockWorkbookService mock, {
  Size ukuran = const Size(1440, 900),
  bool meja = true,
}) async {
  await pasangUkuran(tester, ukuran);
  await tester.pumpWidget(
    studioUji(meja: meja, token: 'mock-token-1', izin: _izin, workbook: mock),
  );
  await tenang(tester);
  await bukaSeksi(tester, SeksiStudio.workbookAlat);
  expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
}

Future<void> _bukaWorkbook(
  WidgetTester tester,
  MockWorkbookService mock,
  int id, {
  Size ukuran = const Size(1440, 900),
  bool meja = true,
}) async {
  await _bukaDaftar(tester, mock, ukuran: ukuran, meja: meja);
  await tester.tap(find.byKey(ValueKey('workbook-$id')));
  await tenang(tester);
  expect(find.byType(WorkbookScreen), findsOneWidget);
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey tombol) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(tombol);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tenang(tester);
}

String? _teksKunci(WidgetTester tester, String kunci) {
  final w = tester.widget(find.byKey(ValueKey(kunci)));
  if (w is Text) return w.data;
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(kunci)),
          matching: find.byType(Text),
        ),
      )
      .data;
}

String? _selectable(WidgetTester tester, String kunci) =>
    tester.widget<SelectableText>(find.byKey(ValueKey(kunci))).data;
