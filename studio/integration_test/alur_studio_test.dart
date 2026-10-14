import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/data_acuan/daftar_paket_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/studio_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/widgets/keadaan_acuan.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/l10n/studio_l10n.dart';
import 'package:sidik_studio/layar/beranda/beranda_screen.dart';
import 'package:sidik_studio/layar/cangkang_studio.dart';
import 'package:sidik_studio/layar/masuk_screen.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/layar/workbook/daftar_workbook_screen.dart';
import 'package:sidik_studio/layar/workbook/workbook_screen.dart';
import 'package:sidik_studio/main.dart' as app;
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu_e2e.dart';

/// E2E Studio: app SUNGGUHAN (`main()`) melawan server API lokal SUNGGUHAN.
///
/// Masuk (admin) → Beranda → Data acuan (daftar + studio paket, setiap tab)
/// → Workbook Alat (daftar ≥ 40, buka 5 workbook, SETIAP lembar: sel termuat,
/// lembar dikecualikan terbuka tanpa galat, gulir jauh ke bawah/kanan, mode
/// rumus) → keluar → layar masuk.
///
/// Gagal bila: FlutterError / exception tak tertangkap, `ErrorWidget`, pesan
/// galat Studio di layar, halaman sel gagal dimuat, atau sel cacat.
///
/// Jalankan lewat `sidik-studio-lokal\uji-e2e.ps1`, atau langsung:
/// ```
/// cd studio
/// flutter test integration_test/alur_studio_test.dart -d windows \
///   --dart-define=API_BASE_URL=http://127.0.0.1:8000/api \
///   --dart-define=E2E_ID=<id admin uji> --dart-define=E2E_SANDI=<sandi>
/// ```
/// Server lokal hanya DIBACA (masuk membuat token — itu alur normal).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'alur Studio: masuk, data acuan, workbook alat, keluar',
    (tester) async {
      if (e2eId.isEmpty || e2eSandi.isEmpty) {
        fail('E2E_ID / E2E_SANDI belum diberikan lewat --dart-define');
      }
      final c = CatatanE2E('studio', tester);

      await c.langkah(tester, 'buka aplikasi', () async {
        await app.main();
        await tunggu(
          tester,
          () =>
              ada(find.byType(MasukStudioScreen)) ||
              ada(find.byType(CangkangStudio)),
          alasan: 'layar masuk atau cangkang tampil',
        );
        // Sisa sesi uji yang terputus: keluar dulu supaya alurnya utuh.
        if (ada(find.byType(CangkangStudio))) {
          await _keluar(tester);
        }
      });

      final l10n = StudioL10n.of(
        tester.element(find.byType(MasukStudioScreen)),
      );
      final galatStudio = [
        l10n.workbookGagalMuat,
        l10n.lembarGagalMuat,
        l10n.izinGagalJudul,
        l10n.workbookTidakDitemukan,
        l10n.gagalJaringan,
        l10n.lembarTidakAda,
      ];

      await c.langkah(tester, 'masuk sebagai admin', () async {
        await c.potret(tester, 'layar-masuk');
        await tester.enterText(
          find.widgetWithText(TextField, l10n.isianIdentitas),
          e2eId,
        );
        await tester.enterText(
          find.widgetWithText(TextField, l10n.isianSandi),
          e2eSandi,
        );
        await tester.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await ketuk(
          tester,
          find.widgetWithText(FilledButton, l10n.tombolMasuk),
        );
        await tunggu(
          tester,
          () =>
              ada(find.byType(CangkangStudio)) ||
              ada(find.byIcon(Icons.error_outline)),
          alasan: 'cangkang Studio tampil sesudah masuk',
          batas: const Duration(seconds: 120),
        );
        if (!ada(find.byType(CangkangStudio))) {
          throw TestFailure('Masuk ditolak: ${teksTerlihat().join(' | ')}');
        }
      });

      await c.langkah(tester, 'Beranda tampil', () async {
        await tunggu(
          tester,
          () => ada(find.byType(BerandaScreen)),
          alasan: 'izin termuat dan Beranda tampil',
        );
        // "Masuk sebagai {nama} · {peran}" — awalannya diambil dari l10n.
        final awalan = l10n
            .berandaMasukSebagai('\u0000', '')
            .split('\u0000')
            .first;
        await tunggu(
          tester,
          () => ada(find.textContaining(awalan.trim())),
          alasan: 'teks "$awalan…" di Beranda',
        );
        await jeda(tester, 1500);
        pastikanTanpaTeks('Beranda', galatStudio);
        await c.potret(tester, 'beranda');
      });

      await c.langkah(tester, 'Data acuan: daftar paket', () async {
        await _bukaSeksi(tester, SeksiStudio.dataAcuan);
        await tunggu(
          tester,
          () =>
              ada(find.byType(DaftarPaketAcuanScreen)) &&
              !ada(find.byType(KerangkaDaftarAcuan)),
          alasan: 'daftar paket acuan termuat',
        );
        if (ada(find.byType(GalatAcuan))) {
          throw TestFailure('Galat data acuan: ${teksTerlihat().join(' | ')}');
        }
        await c.potret(tester, 'data-acuan-daftar');
      });

      final pintuPaket = find.descendant(
        of: find.byType(DaftarPaketAcuanScreen),
        matching: find.byIcon(Icons.chevron_right),
      );
      if (ada(pintuPaket)) {
        await c.langkah(
          tester,
          'Data acuan: studio paket + setiap tab',
          () async {
            await ketuk(tester, pintuPaket.first);
            await tunggu(
              tester,
              () =>
                  ada(find.byType(StudioAcuanScreen)) &&
                  !ada(find.byType(KerangkaGridAcuan)),
              alasan: 'studio paket acuan termuat',
            );
            if (ada(find.byType(GalatAcuan))) {
              throw TestFailure(
                'Galat studio acuan: ${teksTerlihat().join(' | ')}',
              );
            }
            final acuan = AppLocalizations.of(
              tester.element(find.byType(StudioAcuanScreen)),
            );
            final tab = find.descendant(
              of: find.byType(StudioAcuanScreen),
              matching: find.byType(Tab),
            );
            final jumlahTab = tab.evaluate().length;
            for (var i = 0; i < jumlahTab; i++) {
              await tester.ensureVisible(tab.at(i));
              await ketuk(tester, tab.at(i));
              await jeda(tester, 700);
              pastikanTanpaGalat(tester, 'tab acuan ${i + 1}');
              if (ada(find.byType(GalatAcuan))) {
                throw TestFailure('Galat di tab acuan ${i + 1}');
              }
              pastikanTanpaTeks('tab acuan ${i + 1}', [acuan.acuanGagalMuat]);
            }
            // ignore: avoid_print
            print('E2E|info|studio|tab data acuan dibuka: $jumlahTab');
            await c.potret(tester, 'data-acuan-studio');
            // Tombol kembali AppBar bawaan (ikon panah; tipe widgetnya bukan
            // `BackButton` publik di versi Flutter ini, jadi `pageBack` buta).
            await ketuk(
              tester,
              find
                  .descendant(
                    of: find.byType(StudioAcuanScreen),
                    matching: find.byIcon(Icons.arrow_back),
                  )
                  .first,
            );
            await tunggu(
              tester,
              () => !ada(find.byType(StudioAcuanScreen)),
              alasan: 'kembali ke daftar paket',
            );
          },
        );
      }

      late List<WorkbookRingkas> semuaWorkbook;
      await c.langkah(tester, 'Workbook Alat: daftar >= 40', () async {
        await _bukaSeksi(tester, SeksiStudio.workbookAlat);
        await tunggu(
          tester,
          () => ada(find.byType(DaftarWorkbookScreen)),
          alasan: 'layar daftar workbook',
        );
        final wadah = ProviderScope.containerOf(
          tester.element(find.byType(DaftarWorkbookScreen)),
        );
        const KunciDaftarWorkbook kunci = (kodeProfil: null, cari: '');
        final dengar = wadah.listen(daftarWorkbookProvider(kunci), (_, _) {});
        try {
          await tunggu(
            tester,
            () => !dengar.read().isLoading,
            alasan: 'daftar workbook termuat',
          );
          final hasil = dengar.read();
          if (hasil.hasError) {
            throw TestFailure('daftar workbook galat: ${hasil.error}');
          }
          semuaWorkbook = hasil.requireValue;
        } finally {
          dengar.close();
        }
        // ignore: avoid_print
        print('E2E|info|studio|jumlah workbook: ${semuaWorkbook.length}');
        expect(semuaWorkbook.length, greaterThanOrEqualTo(40));
        await tunggu(
          tester,
          () => ada(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('workbook-'),
            ),
          ),
          alasan: 'baris workbook tampil',
        );
        pastikanTanpaTeks('daftar workbook', galatStudio);
        await c.potret(tester, 'workbook-daftar');
        // Gulir seluruh daftar sampai bawah dan kembali — semua baris pernah
        // dibangun.
        final daftar = find.descendant(
          of: find.byType(DaftarWorkbookScreen),
          matching: find.byWidgetPredicate((w) => w is Scrollable),
        );
        final gulir = tester.state<ScrollableState>(daftar.last);
        gulir.position.jumpTo(gulir.position.maxScrollExtent);
        await jeda(tester, 600);
        pastikanTanpaGalat(tester, 'daftar workbook digulir');
        gulir.position.jumpTo(0);
        await jeda(tester, 300);
      });

      // Lima workbook beda keluarga: panjang, volume, suhu, kimia, massa.
      const sasaran = [
        'Micrometer_0-25mm',
        'Fixed_Volumetric_Glassware',
        'Suhu_Thermometer_Glass',
        'pH_meter',
        'Timbangan_gram',
      ];
      var lembarDibuka = 0;
      for (final pola in sasaran) {
        final cocok = [
          for (final w in semuaWorkbook)
            if (w.nama.toLowerCase().contains(pola.toLowerCase())) w,
        ];
        if (cocok.isEmpty) {
          throw TestFailure('workbook "$pola" tidak ada di server');
        }
        // Alat yang punya `.xlsm` DAN CSV: daftar menampilkan `.xlsm`, CSV-nya
        // di balik tombol "sumber lain" (`pasangkanSumberWorkbook`).
        final utama = cocok.firstWhere(
          (w) => w.sumber == SumberWorkbook.xlsm,
          orElse: () => cocok.first,
        );
        lembarDibuka += await _ujiWorkbook(
          tester,
          c,
          utama,
          pola,
          galatStudio,
          l10n,
        );
        // Kembaran CSV dibuka juga — sekali (workbook pertama), cukup untuk
        // jalur "sumber lain".
        final kembar = cocok.where((w) => w.id != utama.id).firstOrNull;
        if (pola == sasaran.first &&
            kembar != null &&
            utama.sumber == SumberWorkbook.xlsm) {
          lembarDibuka += await _ujiWorkbook(
            tester,
            c,
            kembar,
            pola,
            galatStudio,
            l10n,
            lewatUtama: utama,
          );
        }
      }
      // ignore: avoid_print
      print('E2E|info|studio|lembar dibuka total: $lembarDibuka');

      await c.langkah(tester, 'keluar', () async {
        await _keluar(tester);
        await c.potret(tester, 'sesudah-keluar');
      });

      c.selesai();
    },
    timeout: const Timeout(Duration(minutes: 40)),
  );
}

/// Buka seksi lewat navigasi (sidebar / rail / drawer).
Future<void> _bukaSeksi(WidgetTester tester, SeksiStudio seksi) async {
  final tombol = find.byKey(kunciNavigasi(seksi));
  if (!ada(tombol)) {
    final l10n = StudioL10n.of(tester.element(find.byType(CangkangStudio)));
    await ketuk(tester, find.byTooltip(l10n.bukaMenu));
    await jeda(tester, 600);
  }
  await ketuk(tester, tombol);
  await jeda(tester, 500);
}

Future<void> _keluar(WidgetTester tester) async {
  final l10n = StudioL10n.of(tester.element(find.byType(CangkangStudio)));
  final keluar = find.byTooltip(l10n.keluar);
  if (ada(keluar)) {
    await ketuk(tester, keluar.first);
  } else if (ada(find.byTooltip(l10n.menuAkun))) {
    await ketuk(tester, find.byTooltip(l10n.menuAkun));
    await jeda(tester, 600);
    await ketuk(tester, find.text(l10n.keluar).last);
  } else {
    await ketuk(tester, find.byTooltip(l10n.bukaMenu));
    await jeda(tester, 600);
    await ketuk(tester, find.byTooltip(l10n.keluar).first);
  }
  // Selama `POST /logout` berjalan layar masuk sudah tampil dengan tombol
  // berputar (auth `isLoading`); "selesai keluar" = tombol Masuk siap.
  await tunggu(
    tester,
    () =>
        ada(find.byType(MasukStudioScreen)) &&
        ada(find.widgetWithText(FilledButton, l10n.tombolMasuk)),
    alasan: 'kembali ke layar masuk (tombol Masuk siap) sesudah keluar',
    batas: const Duration(seconds: 60),
  );
}

/// Cari lewat kolom cari, buka, uji SETIAP lembar, kembali. Mengembalikan
/// jumlah lembar yang dibuka.
Future<int> _ujiWorkbook(
  WidgetTester tester,
  CatatanE2E c,
  WorkbookRingkas wb,
  String kataCari,
  List<String> galatStudio,
  StudioL10n l10n, {
  WorkbookRingkas? lewatUtama,
}) async {
  late WorkbookDetail detail;
  late ProviderContainer wadah;
  final sumber = wb.sumber.name.toUpperCase();

  await c.langkah(tester, 'buka workbook ${wb.nama} ($sumber)', () async {
    final cari = find.descendant(
      of: find.byType(DaftarWorkbookScreen),
      matching: find.byType(TextField),
    );
    // Ketuk dulu: `enterText` hanya memasang fokus bila kolomnya BERBEDA dari
    // kolom terakhir; kolom cari yang sama sesudah `unfocus` tidak tersambung
    // lagi ke input dan ketikannya hilang diam-diam.
    await ketuk(tester, cari);
    await tester.pump();
    await tester.enterText(cari, kataCari);
    FocusManager.instance.primaryFocus?.unfocus();
    final baris = find.byKey(ValueKey('workbook-${wb.id}'));
    if (lewatUtama != null) {
      final lain = find.byKey(ValueKey('sumber-lain-${lewatUtama.id}'));
      await tunggu(
        tester,
        () => ada(lain),
        alasan: 'tombol "sumber lain" di baris ${lewatUtama.nama}',
      );
      if (!ada(baris)) await ketuk(tester, lain);
    }
    await tunggu(tester, () => ada(baris), alasan: 'hasil cari ${wb.nama}');
    await ketuk(tester, baris);
    await tunggu(
      tester,
      () => ada(find.byType(WorkbookScreen)),
      alasan: 'layar workbook terbuka',
    );
    wadah = ProviderScope.containerOf(
      tester.element(find.byType(WorkbookScreen)),
    );
    final dengar = wadah.listen(detailWorkbookProvider(wb.id), (_, _) {});
    try {
      await tunggu(
        tester,
        () => !dengar.read().isLoading,
        alasan: 'detail workbook termuat',
      );
      final hasil = dengar.read();
      if (hasil.hasError) throw TestFailure('detail galat: ${hasil.error}');
      detail = hasil.requireValue;
    } finally {
      dengar.close();
    }
    expect(detail.lembar, isNotEmpty);
    await jeda(tester, 400);
    pastikanTanpaTeks('buka ${wb.nama}', galatStudio);
  });

  var dibuka = 0;
  var inspekturDicoba = false;
  // Lembar tersembunyi tidak punya tab (seperti Excel); dibuka lewat menu
  // "Tampilkan lembar" — di luar cakupan putaran tab ini.
  final tampil = [
    for (final l in detail.lembar)
      if (!l.tersembunyi.disembunyikan) l,
  ];
  for (final lembar in tampil) {
    await c.langkah(tester, '${wb.nama} ($sumber) › ${lembar.nama}', () async {
      final tab = find.byKey(ValueKey('tab-lembar-${lembar.id}'));
      // Bilah tab = satu-satunya ListView horizontal di layar workbook.
      final bilahTab = find.descendant(
        of: find.descendant(
          of: find.byType(WorkbookScreen),
          matching: find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal,
          ),
        ),
        matching: find.byWidgetPredicate((w) => w is Scrollable),
      );
      await tester.scrollUntilVisible(
        tab,
        150,
        scrollable: bilahTab.first,
        maxScrolls: 80,
      );
      await ketuk(tester, tab);
      await jeda(tester, 400);
      dibuka++;

      if (lembar.dikecualikan) {
        // Cukup "terbuka tanpa galat": K-49-12 (13 Okt) — DATABASE/SERTIFIKAT
        // akan ditampilkan sebagai grid sesudah impor ulang, jadi panel
        // dikecualikan TIDAK diwajibkan.
        await tunggu(
          tester,
          () =>
              ada(find.byType(PanelLembarDikecualikan)) ||
              ada(find.byKey(ValueKey('grid-${lembar.id}'))),
          alasan: 'lembar dikecualikan terbuka (panel atau grid)',
        );
        await jeda(tester, 300);
        pastikanTanpaTeks(lembar.nama, galatStudio);
        if (lembar == detail.lembar.firstWhere((l) => l.dikecualikan)) {
          await c.potret(tester, 'dikecualikan-${wb.id}-${lembar.nama}');
        }
        return;
      }
      if (lembar.jumlahBaris < 1 || lembar.jumlahKolom < 1) {
        await tunggu(
          tester,
          () => ada(find.text(l10n.lembarKosong)),
          alasan: 'keadaan lembar kosong',
        );
        return;
      }

      await tunggu(
        tester,
        () => ada(find.byKey(ValueKey('grid-${lembar.id}'))),
        alasan: 'grid lembar ${lembar.nama}',
      );
      final halamanTerakhir = halamanUntukBaris(lembar.jumlahBaris);
      final dengar = [
        for (var h = 0; h <= halamanTerakhir; h++)
          wadah.listen(
            halamanSelWorkbookProvider((
              workbookId: wb.id,
              lembarId: lembar.id,
              halaman: h,
            )),
            (_, _) {},
          ),
      ];
      try {
        // Halaman pertama dari layar.
        await tunggu(
          tester,
          () => !dengar.first.read().isLoading,
          alasan: 'halaman sel pertama ${lembar.nama}',
        );
        if (dengar.first.read().hasError) {
          throw TestFailure('halaman 1 galat: ${dengar.first.read().error}');
        }
        pastikanTanpaTeks(lembar.nama, galatStudio);
        if (dibuka <= 1 || lembar == tampil.last) {
          await c.potret(tester, 'lembar-${wb.id}-${lembar.nama}');
        }

        // Pilih A1 (kotak nama mengikuti), lalu inspektur sekali per
        // workbook: buka (bila tertutup) → tutup lewat X → kembalikan ke
        // keadaan awal. Bawaan terbuka/tertutup ikut ukuran layar.
        final a1 = find
            .byKey(kunciSelGrid(const AlamatSel(1, 1)))
            .hitTestable();
        if (ada(a1)) {
          await ketuk(tester, a1);
          await jeda(tester, 200);
          final kotak = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('kotak-nama')),
              matching: find.byType(Text),
            ),
          );
          expect(kotak.data, 'A1');
        }
        final tombolInspektur = find.byKey(const ValueKey('tombol-inspektur'));
        final isiInspektur = find.byKey(const ValueKey('inspektur-sel'));
        if (!inspekturDicoba && ada(tombolInspektur)) {
          inspekturDicoba = true;
          final awalTerbuka = ada(isiInspektur);
          if (!awalTerbuka) {
            await ketuk(tester, tombolInspektur);
            await tunggu(
              tester,
              () => ada(isiInspektur),
              alasan: 'inspektur sel terbuka',
            );
          }
          await jeda(tester, 400);
          await c.potret(tester, 'inspektur-${wb.id}');
          await ketuk(tester, find.byKey(const ValueKey('tutup-inspektur')));
          await tunggu(
            tester,
            () => !ada(isiInspektur),
            alasan: 'inspektur sel tertutup',
          );
          if (awalTerbuka) {
            await ketuk(tester, tombolInspektur);
            await tunggu(
              tester,
              () => ada(isiInspektur),
              alasan: 'inspektur sel dibuka lagi',
            );
          }
        }

        // Gulir jauh ke bawah & kanan: offset ke ujung, lalu seret sungguhan.
        final grid = find.byKey(ValueKey('grid-${lembar.id}'));
        final gulirGrid = find.descendant(
          of: grid,
          matching: find.byWidgetPredicate((w) => w is Scrollable),
        );
        for (final e in gulirGrid.evaluate()) {
          final s = (e as StatefulElement).state as ScrollableState;
          s.position.jumpTo(s.position.maxScrollExtent);
        }
        await jeda(tester, 300);
        // Seret sungguhan (gestur) sedikit kembali dari ujung.
        await tester.drag(grid, const Offset(120, 160));
        await jeda(tester, 300);
        for (var i = 0; i < dengar.length; i++) {
          await tunggu(
            tester,
            () => !dengar[i].read().isLoading,
            alasan: 'halaman sel ${i + 1} ${lembar.nama}',
          );
        }
        var sel = 0;
        var cacat = 0;
        for (var i = 0; i < dengar.length; i++) {
          final h = dengar[i].read();
          if (h.hasError) {
            throw TestFailure('halaman sel ${i + 1} galat: ${h.error}');
          }
          sel += h.requireValue.sel.length;
          cacat += h.requireValue.jumlahCacat;
        }
        // ignore: avoid_print
        print(
          'E2E|info|studio|${wb.nama}|${lembar.nama}|'
          '${lembar.jumlahBaris}x${lembar.jumlahKolom}|sel $sel/${lembar.jumlahSel}|'
          'cacat $cacat|halaman ${dengar.length}',
        );
        if (lembar.jumlahSel > 0 && sel == 0) {
          throw TestFailure(
            'lembar berisi ${lembar.jumlahSel} sel tapi tak satu pun termuat',
          );
        }
        if (cacat > 0) {
          throw TestFailure('$cacat sel cacat (tak terbaca klien)');
        }
        if (ada(find.byKey(const ValueKey('peringatan-sel-cacat')))) {
          throw TestFailure('peringatan sel cacat tampil');
        }
        pastikanTanpaTeks('${lembar.nama} digulir', galatStudio);

        // Mode tampilkan rumus: nyala → periksa → mati.
        final tombolRumus = find.byKey(const ValueKey('tombol-rumus'));
        await ketuk(tester, tombolRumus);
        await jeda(tester, 300);
        expect(tester.widget<IconButton>(tombolRumus).isSelected, isTrue);
        if (lembar == tampil.lastWhere((l) => !l.dikecualikan)) {
          await c.potret(tester, 'rumus-digulir-${wb.id}-${lembar.nama}');
        }
        await ketuk(tester, tombolRumus);
        await jeda(tester, 200);
        expect(tester.widget<IconButton>(tombolRumus).isSelected, isFalse);

        // Kembali ke awal lembar.
        for (final e in gulirGrid.evaluate()) {
          final s = (e as StatefulElement).state as ScrollableState;
          s.position.jumpTo(0);
        }
        await jeda(tester, 200);
      } finally {
        for (final d in dengar) {
          d.close();
        }
      }
    });
  }

  await c.langkah(tester, 'tutup workbook ${wb.nama} ($sumber)', () async {
    await ketuk(tester, find.byTooltip(l10n.kembali).first);
    await tunggu(
      tester,
      () => !ada(find.byType(WorkbookScreen)),
      alasan: 'kembali ke daftar workbook',
    );
    final cari = find.descendant(
      of: find.byType(DaftarWorkbookScreen),
      matching: find.byType(TextField),
    );
    await ketuk(tester, cari);
    await tester.pump();
    await tester.enterText(cari, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await jeda(tester, 500);
  });
  return dibuka;
}
