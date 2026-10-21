import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_studio/data/simulasi_provider.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/layar/workbook/daftar_workbook_screen.dart';
import 'package:sidik_studio/layar/workbook/workbook_screen.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu/studio_uji.dart';

/// Tahap C di layar: mode edit seperti Excel + simulasi `/hitung` + overlay,
/// lembar tersembunyi, gambar. Layanan = `MockWorkbookService` (menggemakan
/// sel yang diedit — TIDAK menghitung). Angka "hasil hitung" di test ini
/// SINTETIS: yang diuji jalurnya (kiriman → overlay → tampilan), bukan
/// kebenaran hitungannya (itu milik server + harness paritas Excel).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('mode edit (meja 1440 × 900, peran admin)', () {
    testWidgets('ketik langsung → Enter: simpan & turun, "Menghitung…", sel '
        'sementara abu, lalu hasil server DITIMPAKAN (format sel sama dengan '
        'GET lembar); spanduk + Reset mengembalikan snapshot', (tester) async {
      final mock = MockWorkbookService(
        jawabanHitung: (_, edit) async => {
          'data': {
            'lembar': [
              {
                'lembar_id': MockWorkbookService.idLembarU95,
                'sel': [
                  {
                    'a': 'K6',
                    't': 'n',
                    'n': 0.25,
                    's': '0.250',
                    'f': '0.000',
                    'g': {
                      'border': {
                        'atas': 'thin',
                        'kanan': 'thin',
                        'bawah': 'thin',
                        'kiri': 'thin',
                      },
                    },
                  },
                  // Sel turunan yang berubah (nilai sintetis).
                  {
                    'a': 'T6',
                    't': 'f',
                    'n': 0.1443375672974065,
                    's': '0.14434',
                    'r': '=K6/N6',
                    'f': '0.00000',
                  },
                ],
              },
            ],
            'jumlah_dihitung': 2683,
            'durasi_ms': 950,
            'galat': <Object>[],
          },
        },
      );
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);
      expect(find.byKey(const ValueKey('penanda-simulasi')), findsOneWidget);
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsNothing);

      await _ketukSel(tester, 'K6');
      await _ketikHuruf(tester, LogicalKeyboardKey.digit0, '0');
      expect(find.byKey(kunciEditorSel), findsOneWidget);
      expect(_isiEditor(tester), '0');
      // Bilah rumus mengikuti ketikan di sel.
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '0');

      await tester.enterText(find.byKey(kunciEditorSel), '0.25');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(kunciEditorSel), findsNothing);
      expect(_teksKunci(tester, 'kotak-nama'), 'K7');
      expect(find.byKey(const ValueKey('status-menghitung')), findsOneWidget);
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsOneWidget);
      final sementara = _teksDiSel(tester, 'K6');
      expect(sementara.data, '0.25');
      expect(
        sementara.style!.color,
        isNot(_teksDiSel(tester, 'K7').style!.color),
      );

      await _hitung(tester);
      expect(find.byKey(const ValueKey('status-menghitung')), findsNothing);
      expect(_kiriman(mock.panggilanHitung.single), ['11!K6=0.25']);
      expect(_teksDiSel(tester, 'K6').data, '0.250');
      expect(_teksDiSel(tester, 'T6').data, '0.14434');
      expect(
        find.text('Simulasi — tidak disimpan · 1 sel diubah'),
        findsOneWidget,
      );

      // Bilah rumus: isi edit untuk sel yang diedit; inspektur: nilai
      // persis dari jawaban server.
      await _ketukSel(tester, 'K6');
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '0.25');
      expect(_selectable(tester, 'inspektur-simulasi'), '0.25');
      // T6 di balik panel inspektur: dicapai dengan panah (grid menggulir).
      await _kanan(tester, 9);
      expect(_teksKunci(tester, 'kotak-nama'), 'T6');
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '=K6/N6');
      expect(_selectable(tester, 'inspektur-nilai'), '0.1443375672974065');

      await tester.tap(find.byKey(const ValueKey('tombol-reset-simulasi')));
      await tenang(tester);
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsNothing);
      expect(_teksDiSel(tester, 'K6').data, '0.127');
      expect(_teksDiSel(tester, 'T6').data, '0.07332');
      expect(mock.panggilanHitung, hasLength(1));
    });

    testWidgets('Tab kanan & Shift+Tab kiri menyimpan; Esc batal tanpa '
        'kiriman; F2 = edit isi yang ada (rumus tampil sebagai rumus); '
        'Backspace = edit dari kosong; SEMUA edit dikirim', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);

      await _ketukSel(tester, 'K6');
      await _ketikHuruf(tester, LogicalKeyboardKey.keyX, 'x');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_teksKunci(tester, 'kotak-nama'), 'L6');

      await _ketikHuruf(tester, LogicalKeyboardKey.keyY, 'y');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_teksKunci(tester, 'kotak-nama'), 'K6');

      // Esc: ketikan dibuang, sel tetap, tidak ada edit baru.
      await _ketikHuruf(tester, LogicalKeyboardKey.keyZ, 'z');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(kunciEditorSel), findsNothing);
      expect(_teksKunci(tester, 'kotak-nama'), 'K6');

      // F2 di T6: rumusnya, bukan nilainya.
      await _kanan(tester, 9);
      expect(_teksKunci(tester, 'kotak-nama'), 'T6');
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      expect(_isiEditor(tester), '=K6/N6');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Backspace di N6: edit dimulai kosong; Enter = kosongkan.
      await _kiri(tester, 6);
      expect(_teksKunci(tester, 'kotak-nama'), 'N6');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(_isiEditor(tester), '');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _hitung(tester);
      expect(_kiriman(mock.panggilanHitung.last), [
        '11!K6=x',
        '11!L6=y',
        '11!N6=',
      ]);
      expect(_teksDiSel(tester, 'K6').data, 'x');
    });

    testWidgets('Delete mengosongkan rentang terpilih (SATU langkah); Ctrl+Z '
        'mengembalikan snapshot tanpa kiriman, Ctrl+Y mengulang; tombol '
        'urung/ulang di bilah atas', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);
      await _ketukSel(tester, 'K6');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await _hitung(tester);
      expect(_kiriman(mock.panggilanHitung.single), ['11!K6=', '11!K7=']);
      expect(_teksDiSelAtauKosong(tester, 'K6'), isNull);

      await _ctrl(tester, LogicalKeyboardKey.keyZ);
      await _hitung(tester);
      expect(_teksDiSel(tester, 'K6').data, '0.127');
      expect(_teksDiSel(tester, 'K7').data, '0.184');
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsNothing);
      expect(mock.panggilanHitung, hasLength(1));

      await _ctrl(tester, LogicalKeyboardKey.keyY);
      await _hitung(tester);
      expect(mock.panggilanHitung, hasLength(2));
      expect(_teksDiSelAtauKosong(tester, 'K7'), isNull);

      await tester.tap(find.byKey(const ValueKey('tombol-urungkan')));
      await _hitung(tester);
      expect(_teksDiSel(tester, 'K7').data, '0.184');
      await tester.tap(find.byKey(const ValueKey('tombol-ulangi')));
      await _hitung(tester);
      expect(_teksDiSelAtauKosong(tester, 'K7'), isNull);
    });

    testWidgets('dobel ketuk = edit isi yang ada; bilah rumus: ketuk = edit '
        'di bilah, ✓ simpan TANPA pindah, ✕ batal', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);

      final k6 = find.byKey(kunciSelGrid(AlamatSel.urai('K6')!));
      await tester.tap(k6);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(k6);
      await tester.pump();
      expect(_isiEditor(tester), '0.127');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tenang(tester);

      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('tombol-simpan-edit')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('ketuk-bilah-rumus')));
      await tester.pump();
      final bilah = find.byKey(const ValueKey('isian-bilah-rumus'));
      expect(bilah, findsOneWidget);
      expect(find.byKey(kunciEditorSel), findsNothing);
      await tester.enterText(bilah, '0.5');
      await tester.tap(find.byKey(const ValueKey('tombol-simpan-edit')));
      await _hitung(tester);
      expect(_teksKunci(tester, 'kotak-nama'), 'K6');
      expect(_kiriman(mock.panggilanHitung.single), ['11!K6=0.5']);

      await tester.tap(find.byKey(const ValueKey('ketuk-bilah-rumus')));
      await tester.pump();
      await tester.enterText(bilah, '9');
      await tester.tap(find.byKey(const ValueKey('tombol-batal-edit')));
      await _hitung(tester);
      expect(bilah, findsNothing);
      expect(mock.panggilanHitung, hasLength(1));
      expect(_teksKunci(tester, 'isi-bilah-rumus'), '0.5');
    });

    testWidgets('sel gabungan (B6:H6) diedit di sel kiri-atasnya', (
      tester,
    ) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);
      await _ketukSel(tester, 'B6');
      expect(_teksKunci(tester, 'kotak-nama'), 'B6');
      await _ketikHuruf(tester, LogicalKeyboardKey.keyR, 'R');
      await tester.enterText(find.byKey(kunciEditorSel), 'Resolusi alat');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _hitung(tester);
      expect(_kiriman(mock.panggilanHitung.single), ['11!B6=Resolusi alat']);
      // Turun dari gabungan B6:H6 ke gabungan B7:H7 (jangkar B7).
      expect(_teksKunci(tester, 'kotak-nama'), 'B7');
    });

    testWidgets('422 ditolak → pesan jelas + "Batalkan edit terakhir"; 504 → '
        '"Coba lagi"; 409 → berkas asli tidak ada', (tester) async {
      ApiException? galat;
      final mock = MockWorkbookService();
      mock.jawabanHitung = (_, _) async => throw galat!;
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);

      galat = ApiException(
        'Data tidak valid.',
        status: 422,
        body: {
          'message': 'Data tidak valid.',
          'errors': {
            'edit.0.isi': ['Fungsi INDIRECT tidak diizinkan.'],
          },
        },
      );
      await _ketukSel(tester, 'K6');
      await _ketikHuruf(tester, LogicalKeyboardKey.equal, '=');
      await tester.enterText(find.byKey(kunciEditorSel), '=INDIRECT("A1")');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _hitung(tester);
      expect(
        _teksKunci(tester, 'galat-simulasi'),
        'Edit ditolak server: Fungsi INDIRECT tidak diizinkan.',
      );
      expect(find.byKey(const ValueKey('tombol-hitung-ulang')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tombol-batalkan-terakhir')));
      await _hitung(tester);
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsNothing);
      expect(_teksDiSel(tester, 'K6').data, '0.127');

      galat = ApiException(
        'Hitung terlalu lama.',
        status: 504,
        body: {'kode': 'hitung_terlalu_lama'},
      );
      await _ketukSel(tester, 'Q6');
      await _ketikHuruf(tester, LogicalKeyboardKey.digit5, '5');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _hitung(tester);
      expect(
        _teksKunci(tester, 'galat-simulasi'),
        'Hitung terlalu lama (batas server 20 detik) dan dibatalkan.',
      );
      expect(find.byKey(const ValueKey('tombol-hitung-ulang')), findsOneWidget);

      galat = ApiException(
        'Berkas asli tidak ada.',
        status: 409,
        body: {'kode': 'berkas_asli_tidak_ada'},
      );
      await tester.tap(find.byKey(const ValueKey('tombol-hitung-ulang')));
      await _hitung(tester);
      expect(
        _teksKunci(tester, 'galat-simulasi'),
        'Workbook ini tidak punya berkas Excel asli di server — simulasi '
        'tidak bisa dihitung.',
      );
    });

    testWidgets('409 perlu_sandi → pesan untuk admin (studio:siapkan-hitung '
        '<id>), BUKAN "tidak punya berkas asli"; tanpa "Coba lagi"', (
      tester,
    ) async {
      final mock = MockWorkbookService(
        jawabanHitung: (_, _) async => throw const ApiException(
          'Model hitung workbook bersandi belum disiapkan.',
          status: 409,
          body: {
            'message':
                'Model hitung workbook bersandi belum disiapkan. Admin '
                'menjalankan: php artisan studio:siapkan-hitung <id workbook> '
                '(sandi diminta).',
            'kode': 'perlu_sandi',
          },
        ),
      );
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);
      await _ketukSel(tester, 'Q6');
      await _ketikHuruf(tester, LogicalKeyboardKey.digit5, '5');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _hitung(tester);
      expect(
        _teksKunci(tester, 'galat-simulasi'),
        'Model hitung workbook bersandi ini belum disiapkan di server — '
        'simulasi belum bisa dihitung. Minta admin menjalankan php artisan '
        'studio:siapkan-hitung ${MockWorkbookService.idMicrometer} (sandi '
        'diminta) atau mengimpor ulang berkas .xlsm-nya dengan sandi.',
      );
      expect(find.byKey(const ValueKey('tombol-hitung-ulang')), findsNothing);
      expect(
        find.byKey(const ValueKey('tombol-batalkan-terakhir')),
        findsOneWidget,
      );
    });
  });

  group('peran & sumber', () {
    testWidgets('K-50-12: satu akun Studio, tanpa penyaring peran di klien — '
        'peran apa pun yang tercatat, edit/hitung tetap terbuka (server yang '
        'menolak)', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(
        tester,
        mock,
        MockWorkbookService.idMicrometer,
        izin: const Izin(
          role: UserRole.viewer,
          boleh: {NamaIzin.dataAcuanLihat, izinWorkbookLihat},
        ),
      );
      expect(find.byKey(const ValueKey('penanda-simulasi')), findsOneWidget);
      expect(find.byKey(const ValueKey('penanda-baca')), findsNothing);
    });

    testWidgets('workbook CSV: baca-saja walau admin (server pasti 409)', (
      tester,
    ) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idHeightGauge);
      expect(find.byKey(const ValueKey('penanda-baca')), findsOneWidget);
      await _ketukSel(tester, 'E10');
      await _ketikHuruf(tester, LogicalKeyboardKey.keyA, 'a');
      expect(find.byKey(kunciEditorSel), findsNothing);
    });

    testWidgets('xlsm TANPA berkas asli tersimpan: baca-saja walau admin '
        '(server pasti 409 berkas_asli_tidak_ada)', (tester) async {
      final mock = _MockTanpaBerkasAsli();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);
      expect(find.byKey(const ValueKey('penanda-baca')), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-urungkan')), findsNothing);
      await _ketukSel(tester, 'K6');
      await _ketikHuruf(tester, LogicalKeyboardKey.digit1, '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await _hitung(tester);
      expect(find.byKey(kunciEditorSel), findsNothing);
      expect(mock.panggilanHitung, isEmpty);
    });
  });

  group('tablet', () {
    testWidgets('potret: dobel ketuk → editor + keyboard lunak; tombol '
        '"selesai" keyboard = Enter; ✓/✕ di bilah rumus', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(
        tester,
        mock,
        MockWorkbookService.idMicrometer,
        ukuran: const Size(711, 1138),
        meja: false,
      );
      final k6 = find.byKey(kunciSelGrid(AlamatSel.urai('K6')!));
      await tester.tap(k6);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(k6);
      await tester.pump();
      expect(find.byKey(kunciEditorSel), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byKey(const ValueKey('tombol-simpan-edit')), findsOneWidget);

      await tester.enterText(find.byKey(kunciEditorSel), '0.3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _hitung(tester);
      expect(_kiriman(mock.panggilanHitung.single), ['11!K6=0.3']);
      expect(_teksKunci(tester, 'kotak-nama'), 'K7');
    });

    testWidgets('tekan lama bilah tab → "Tampilkan lembar tersembunyi…" → '
        'lembar Standar_GB tampil & terbuka (tampilan saja)', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(
        tester,
        mock,
        MockWorkbookService.idMicrometer,
        ukuran: const Size(1138, 711),
        meja: false,
      );
      const tab = ValueKey('tab-lembar-${MockWorkbookService.idLembarStandar}');
      expect(find.byKey(tab), findsNothing);
      await tester.longPress(
        find.byKey(
          const ValueKey('tab-lembar-${MockWorkbookService.idLembarU95}'),
        ),
      );
      await tenang(tester);
      await tester.tap(find.text('Tampilkan lembar tersembunyi…'));
      await tenang(tester);
      expect(
        find.text('Tampilan saja — tidak disimpan ke workbook.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Standar_GB'));
      await tenang(tester);
      expect(find.byKey(tab), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GridSel),
          matching: find.text('STANDAR GAUGE BLOCK'),
        ),
        findsOneWidget,
      );

      // Semua sudah tampil: butir menu nonaktif.
      await tester.longPress(find.byKey(tab));
      await tenang(tester);
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.byKey(const ValueKey('menu-tampilkan-lembar')),
            )
            .enabled,
        isFalse,
      );
    });
  });

  group('gambar', () {
    testWidgets('png digambar di jangkarnya (K18 + 3/2 px, 96 × 48) dan ikut '
        'zoom; panel beku: EMF di A1 diam saat digulir mendatar, png ikut '
        'sel; EMF = kotak abu berlabel, tidak diminta; byte di-cache', (
      tester,
    ) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock, MockWorkbookService.idMicrometer);
      final png = find.byKey(kunciGambarGrid('u95-png-1'));
      final emf = find.byKey(kunciGambarGrid('u95-emf-1'));
      Rect sel(String a) =>
          tester.getRect(find.byKey(kunciSelGrid(AlamatSel.urai(a)!)));

      var k18 = sel('K18');
      var r = tester.getRect(png);
      expect(r.topLeft, k18.topLeft + const Offset(3, 2));
      expect(r.size, const Size(96, 48));
      expect(tester.getRect(emf).topLeft, sel('A1').topLeft);
      expect(
        find.descendant(of: emf, matching: find.text('EMF')),
        findsOneWidget,
      );
      expect(mock.panggilanGambar, ['u95-png-1']);

      // Gulir mendatar: png ikut kolom K, EMF (kolom A beku) tetap.
      final emfSebelum = tester.getRect(emf);
      await tester.drag(find.byType(GridSel), const Offset(-150, 0));
      await tenang(tester);
      final geser = sel('K18').left - k18.left;
      expect(geser, lessThan(0));
      expect(tester.getRect(png).left, r.left + geser);
      expect(tester.getRect(emf), emfSebelum);

      // Zoom 150 %: posisi & ukuran ikut skala.
      await tester.tap(find.byKey(const ValueKey('zoom-nilai')));
      await tenang(tester);
      await tester.tap(find.text('150%').last);
      await tenang(tester);
      k18 = sel('K18');
      r = tester.getRect(png);
      expect(r.left, closeTo(k18.left + 3 * 1.5, 0.001));
      expect(r.top, closeTo(k18.top + 2 * 1.5, 0.001));
      expect(r.size, const Size(144, 72));
      expect(mock.panggilanGambar, ['u95-png-1']);
    });
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

/// Workbook .xlsm yang berkas aslinya TIDAK tersimpan di server (mis.
/// impor lama / berkas hilang) — meta lain sama dengan Micrometer mock.
class _MockTanpaBerkasAsli extends MockWorkbookService {
  @override
  Future<WorkbookDetail> detail(String token, int workbookId) async {
    final d = await super.detail(token, workbookId);
    final m = d.meta;
    return WorkbookDetail(
      meta: WorkbookRingkas(
        id: m.id,
        nama: m.nama,
        sumber: m.sumber,
        sumberMentah: m.sumberMentah,
        sha256: m.sha256,
        ukuran: m.ukuran,
        jumlahLembar: m.jumlahLembar,
        berkasAsliTersimpan: false,
        kodeProfil: m.kodeProfil,
        keluarga: m.keluarga,
        diimporPada: m.diimporPada,
      ),
      lembar: d.lembar,
    );
  }
}

const _izinAdmin = Izin(
  role: UserRole.admin,
  boleh: {NamaIzin.dataAcuanLihat, izinWorkbookLihat},
);

Future<void> _bukaWorkbook(
  WidgetTester tester,
  MockWorkbookService mock,
  int id, {
  Size ukuran = const Size(1440, 900),
  bool meja = true,
  Izin izin = _izinAdmin,
}) async {
  await pasangUkuran(tester, ukuran);
  await tester.pumpWidget(
    studioUji(meja: meja, token: 'mock-token-1', izin: izin, workbook: mock),
  );
  await tenang(tester);
  await bukaSeksi(tester, SeksiStudio.workbookAlat);
  expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
  await tester.tap(find.byKey(ValueKey('workbook-$id')));
  await tenang(tester);
  expect(find.byType(WorkbookScreen), findsOneWidget);
}

Future<void> _ketukSel(WidgetTester tester, String a) async {
  await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai(a)!)));
  await tenang(tester);
}

/// Satu ketukan tombol berhuruf di grid (keyboard fisik).
Future<void> _ketikHuruf(
  WidgetTester tester,
  LogicalKeyboardKey tombol,
  String huruf,
) async {
  await tester.sendKeyDownEvent(tombol, character: huruf);
  await tester.sendKeyUpEvent(tombol);
  await tester.pump();
}

/// Lewati jeda kirim (+ jarak minimum antar-kiriman) + jawaban tiruan.
Future<void> _hitung(WidgetTester tester) async {
  await tester.pump(
    jedaKirimHitung + jarakMinKirimHitung + const Duration(milliseconds: 50),
  );
  await tenang(tester);
}

Future<void> _kanan(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  }
  await tenang(tester);
}

Future<void> _kiri(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
  }
  await tenang(tester);
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey tombol) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(tombol);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

List<String> _kiriman(List<EditSel> edit) => [
  for (final e in edit) '${e.lembarId}!${e.alamat.a1}=${e.isi}',
];

String _isiEditor(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(kunciEditorSel)).controller!.text;

Text _teksDiSel(WidgetTester tester, String a) => tester.widget<Text>(
  find.descendant(
    of: find.byKey(kunciSelGrid(AlamatSel.urai(a)!)),
    matching: find.byType(Text),
  ),
);

String? _teksDiSelAtauKosong(WidgetTester tester, String a) {
  final f = find.descendant(
    of: find.byKey(kunciSelGrid(AlamatSel.urai(a)!)),
    matching: find.byType(Text),
  );
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
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
