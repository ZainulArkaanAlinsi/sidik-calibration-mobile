import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/garis_waktu_arsip.dart';
import 'package:sidik_calibration/models/pencarian_arsip.dart';
import 'package:sidik_calibration/screens/arsip/garis_waktu_arsip_screen.dart';
import 'package:sidik_calibration/screens/arsip/widgets/kartu_arsip.dart';
import 'package:sidik_calibration/services/arsip_cari_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/widgets/skeleton.dart';
import 'package:sidik_calibration/widgets/status_badge.dart';

import 'support/arsip_cari_uji.dart';

/// Gerbang desain layar Arsip menurut waktu (standar kualitas desain Sidik,
/// 13 Nov 2026): token tema saja, tangguh di semua ukuran, semua keadaan
/// dirancang, sasaran sentuh, kontras, Semantics, dan pencarian yang terasa
/// cepat. Semua deterministik — tes merah kalau salah satunya dirusak.
///
/// Ukuran yang dicakup (lebar × tinggi dp, skala huruf):
///   HP 320×640 ×1,0 · HP 320×640 ×1,3 · HP 360×760 ×1,3 ·
///   tablet 840×1180 ×1,0 · tablet 840×1180 ×1,3 ·
///   tablet lanskap 1280×800 · HP lanskap 800×360,
/// masing-masing terang dan gelap.
///
/// Yang TIDAK terbukti di sini: tampilan di tablet/HP sungguhan, keyboard di
/// lanskap, dan golden macOS (CI golden berjalan di macOS; lihat catatan
/// laporan).

/// Seperti `testWidgets`, dengan semantics menyala SELAMA tes dan dimatikan
/// sebelum tes berakhir (pemeriksaan akhir tes menolak handle yang tersisa).
void testSemantik(
  String nama,
  Future<void> Function(WidgetTester tester) isi,
) => testWidgets(nama, (tester) async {
  final handle = tester.ensureSemantics();
  try {
    await isi(tester);
  } finally {
    handle.dispose();
  }
});

// ── 1. Token saja: tidak ada warna/ukuran/radius mentah di layar ──────────

const _berkasLayar = [
  'lib/screens/arsip/garis_waktu_arsip_screen.dart',
  'lib/screens/arsip/widgets/kartu_arsip.dart',
];

String _tanpaKomentar(String kode) => [
  for (final baris in kode.split('\n'))
    baris.replaceFirst(RegExp(r'//.*$'), ''),
].join('\n');

/// Isi kurung yang dibuka di [awal] (indeks `(`), sampai pasangannya.
String _isiKurung(String s, int awal) {
  var dalam = 0;
  for (var i = awal; i < s.length; i++) {
    if (s[i] == '(') dalam++;
    if (s[i] == ')' && --dalam == 0) return s.substring(awal + 1, i);
  }
  return s.substring(awal + 1);
}

/// Pelanggaran aturan "tema saja" pada [kode] Dart (komentar diabaikan).
List<String> pelanggaranToken(String kode) {
  final bersih = _tanpaKomentar(kode);
  final hasil = <String>[];

  void cari(String aturan, RegExp pola) {
    for (final m in pola.allMatches(bersih)) {
      hasil.add('$aturan: ${m.group(0)}');
    }
  }

  cari('warna heksa', RegExp(r'Color\(\s*0x'));
  cari('warna bawaan Material', RegExp(r'\bColors\.'));
  cari('fontSize mentah', RegExp(r'fontSize\s*:'));
  cari(
    'ukuran mentah',
    RegExp(
      r'\b(width|height|size|thickness|strokeWidth|maxWidth|maxHeight|'
      r'minWidth|minHeight|radius)\s*:\s*[0-9]',
    ),
  );
  cari('radius mentah', RegExp(r'Radius\.circular\(\s*[0-9]'));
  cari('Size mentah', RegExp(r'\bSize(\.\w+)?\(\s*[0-9]'));

  for (final m in RegExp(r'EdgeInsets\.\w+\(').allMatches(bersih)) {
    final isi = _isiKurung(bersih, m.end - 1);
    for (final angka in RegExp(
      r'(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])',
    ).allMatches(isi)) {
      if (double.parse(angka.group(1)!) != 0) {
        hasil.add('EdgeInsets mentah: ${m.group(0)}$isi)');
      }
    }
  }
  return hasil;
}

// ── 2. Harness render: ukuran × tema × keadaan ────────────────────────────

typedef _Ukuran = ({String nama, double lebar, double tinggi, double skala});

const _ukuranUji = <_Ukuran>[
  (nama: 'HP 320 dp', lebar: 320, tinggi: 640, skala: 1.0),
  (nama: 'HP 320 dp huruf 1,3x', lebar: 320, tinggi: 640, skala: 1.3),
  (nama: 'HP 360 dp huruf 1,3x', lebar: 360, tinggi: 760, skala: 1.3),
  (nama: 'tablet 840 dp', lebar: 840, tinggi: 1180, skala: 1.0),
  (nama: 'tablet 840 dp huruf 1,3x', lebar: 840, tinggi: 1180, skala: 1.3),
  (nama: 'tablet lanskap 1280 dp', lebar: 1280, tinggi: 800, skala: 1.0),
  (nama: 'HP lanskap 800x360 dp', lebar: 800, tinggi: 360, skala: 1.0),
];

/// Data berteks panjang — yang paling mungkin membuat baris meluap.
const _alatPanjang =
    'Pressure Transmitter Differential Wika Tipe Lanjutan 0-100 bar';
const _ptPanjang = 'PT Industri Presisi Nusantara Mandiri Sejahtera Abadi';
const _seriPanjang = 'SN-PT-2026-00099-ABCDEFGHIJKLMNOP';

List<CalibrationHistoryItem> _sesiPanjang() => [
  sesiUji(
    9,
    alat: _alatPanjang,
    seri: _seriPanjang,
    sertifikat: 'CAL/2026/11/0009/REV-02-PANJANG',
    pt: _ptPanjang,
  ),
  sesiUji(
    8,
    alat: _alatPanjang,
    seri: _seriPanjang.toLowerCase(),
    sertifikat: 'CAL/2025/11/0008',
    pt: _ptPanjang,
    status: 'dibatalkan',
  ),
  const CalibrationHistoryItem(
    id: 7,
    namaAlat: 'Timbangan Analitik Ohaus Pioneer',
    namaTeknisi: 'Dr. Arch Schaefer Pratama',
    status: CalibrationStatus.menungguApproval,
    nomorSeri: 'SN-TA-1',
    namaPelanggan: 'PT Contoh Beta',
    nomorOrder: 'PO-2026-0042-PANJANG',
  ),
];

const _keadaan = [
  'akar',
  'hari',
  'hasil',
  'kosong',
  'galat',
  'offline',
  'tanpa-hasil',
  'server-lama',
  'memuat',
  'pilih-pt',
];

Future<void> _tekan(WidgetTester tester, Finder f) async {
  // Daftar dibangun malas: baris yang jauh di bawah belum ada sampai digulir.
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      100,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Bawa layar ke salah satu [_keadaan].
Future<void> _bawaKe(
  WidgetTester tester,
  String keadaan,
  _Ukuran u,
  ThemeData tema,
) async {
  Future<ProviderContainer> buka(ArsipCariService s, {bool tunggu = true}) =>
      bukaLayarArsip(
        tester,
        s,
        lebar: u.lebar,
        tinggi: u.tinggi,
        skalaTeks: u.skala,
        tema: tema,
        tungguSelesai: tunggu,
      );

  switch (keadaan) {
    case 'akar':
      await buka(ServiceLayar());
    case 'hari':
      await buka(ServiceLayar());
      await _tekan(tester, find.text('2026'));
      await _tekan(tester, find.text('November 2026'));
      await _tekan(tester, find.text('Pekan 46 (9–15 Nov 2026)'));
    case 'hasil':
      await buka(ServiceLayar(sesi: _sesiPanjang()));
      await cariDiKotak(tester, 'sn');
      await _tekan(tester, find.text('1 sesi lain alat ini'));
    case 'kosong':
      await buka(ServiceLayar(kosong: true));
    case 'galat':
      await buka(ServiceLayar(gagal: true));
    case 'offline':
      await buka(
        ServiceLayar()..galatGarisWaktu = const KoneksiException('putus'),
      );
    case 'tanpa-hasil':
      await buka(ServiceLayar(sesi: const []));
      await cariDiKotak(tester, 'zzz-9');
    case 'server-lama':
      await buka(
        ServiceLayar()
          ..galatGarisWaktu = const ServerBelumMendukungArsipException(),
      );
    case 'memuat':
      await buka(ServiceLayar(jeda: const Duration(seconds: 5)), tunggu: false);
      await tester.pump(const Duration(seconds: 1));
    case 'pilih-pt':
      await buka(ServiceLayar());
      await _tekan(tester, find.text('Semua PT'));
    default:
      fail('keadaan tak dikenal: $keadaan');
  }
}

/// Tuntaskan pemuatan yang sengaja ditahan supaya tes tidak menyisakan timer.
Future<void> _tuntaskan(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// Semua simpul yang bisa diketuk dan lebih kecil dari [minimum] dp.
///
/// Pelengkap `androidTapTargetGuideline`: pedoman bawaan SDK melewatkan target
/// di dalam wadah gulir (jejak dan daftar layar ini) — terbukti, mutasi yang
/// mengecilkan tombol jejak menjadi 22 dp tetap lolos. Di sini ukuran diukur
/// dari koordinat global; satu-satunya yang dilewati: target yang menyentuh
/// tepi wadah gulirnya (bisa saja sebagian tergulir keluar, jadi ukurannya
/// terpotong dan bukan ukuran sebenarnya).
List<String> sasaranSentuhKurang(WidgetTester tester, {double minimum = 48}) {
  final hasil = <String>[];

  Rect global(SemanticsNode simpul) {
    var kotak = simpul.rect;
    for (SemanticsNode? s = simpul; s != null; s = s.parent) {
      final t = s.transform;
      if (t != null) kotak = MatrixUtils.transformRect(t, kotak);
    }
    return kotak;
  }

  bool menyentuhTepi(Rect anak, Rect induk) =>
      anak.left - induk.left < 1 ||
      induk.right - anak.right < 1 ||
      anak.top - induk.top < 1 ||
      induk.bottom - anak.bottom < 1;

  void telusuri(SemanticsNode simpul, double rasio) {
    simpul.visitChildren((anak) {
      telusuri(anak, rasio);
      return true;
    });
    if (simpul.isMergedIntoParent) return;
    final bendera = simpul.flagsCollection;
    if (bendera.isHidden || bendera.scopesRoute) return;
    if (!simpul.getSemanticsData().hasAction(SemanticsAction.tap)) return;

    final kotak = global(simpul);
    for (SemanticsNode? s = simpul.parent; s != null; s = s.parent) {
      if (s.flagsCollection.hasImplicitScrolling &&
          menyentuhTepi(kotak, global(s))) {
        return;
      }
    }

    final ukuran = kotak.size / rasio;
    if (ukuran.width < minimum - 0.01 || ukuran.height < minimum - 0.01) {
      hasil.add('${simpul.label.isEmpty ? simpul.id : simpul.label}: $ukuran');
    }
  }

  for (final tampilan in tester.binding.renderViews) {
    telusuri(
      tampilan.owner!.semanticsOwner!.rootSemanticsNode!,
      tampilan.flutterView.devicePixelRatio,
    );
  }
  return hasil;
}

/// Pemeriksaan struktur yang berlaku di SETIAP keadaan.
void _periksaStruktur(WidgetTester tester, String label) {
  final galat = tester.takeException();
  expect(galat, isNull, reason: 'overflow/galat: $label :: $galat');

  // Tanpa kartu di dalam kartu.
  for (final kartu in find.byType(Card).evaluate()) {
    expect(
      find.descendant(
        of: find.byWidget(kartu.widget),
        matching: find.byType(Card),
      ),
      findsNothing,
      reason: 'kartu bersarang: $label',
    );
  }

  // Satu aksi utama: tidak ada tombol terisi — aksi utamanya kotak cari.
  expect(find.byType(FilledButton), findsNothing, reason: label);
  expect(find.byType(ElevatedButton), findsNothing, reason: label);
}

void main() {
  group('token saja (tanpa warna/ukuran/radius mentah di layar)', () {
    for (final berkas in _berkasLayar) {
      test('$berkas bebas literal desain', () {
        final pelanggaran = pelanggaranToken(File(berkas).readAsStringSync());

        expect(pelanggaran, isEmpty);
      });
    }

    test('pemindai benar-benar menangkap pelanggaran (bukan lolos kosong)', () {
      expect(pelanggaranToken('final c = Color(0xFF112233);'), isNotEmpty);
      expect(pelanggaranToken('final c = Colors.red;'), isNotEmpty);
      expect(pelanggaranToken('padding: EdgeInsets.all(13)'), isNotEmpty);
      expect(
        pelanggaranToken(
          'padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, 7, 0)',
        ),
        isNotEmpty,
      );
      expect(pelanggaranToken('SizedBox(width: 24)'), isNotEmpty);
      expect(pelanggaranToken('Icon(Icons.add, size: 18)'), isNotEmpty);
      expect(pelanggaranToken('BorderRadius.circular(12)'), isNotEmpty);
      expect(pelanggaranToken('TextStyle(fontSize: 14)'), isNotEmpty);
      expect(pelanggaranToken('minimumSize: Size.fromHeight(48)'), isNotEmpty);
    });

    test('pemindai tidak menandai token dan nol', () {
      expect(
        pelanggaranToken('''
          // Color(0xFF112233) di komentar tidak dihitung
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          Icon(Icons.add, size: AppUkuran.ikonSebaris),
          BorderRadius.circular(AppSpacing.radiusLg),
          SizedBox(height: AppSpacing.md)
        '''),
        isEmpty,
      );
    });
  });

  group('render tanpa overflow: ukuran × tema × keadaan', () {
    for (final u in _ukuranUji) {
      testWidgets('${u.nama}: terang dan gelap, semua keadaan', (tester) async {
        for (final (nama, tema) in [
          ('terang', AppTheme.light),
          ('gelap', AppTheme.dark),
        ]) {
          for (final keadaan in _keadaan) {
            final label = '${u.nama} · $nama · $keadaan';
            await _bawaKe(tester, keadaan, u, tema);

            // Tema yang dipakai benar-benar tema yang diminta.
            expect(
              Theme.of(
                tester.element(find.byType(GarisWaktuArsipScreen)),
              ).brightness,
              nama == 'gelap' ? Brightness.dark : Brightness.light,
              reason: label,
            );
            _periksaStruktur(tester, label);

            if (keadaan == 'memuat') await _tuntaskan(tester);
          }
        }
      });
    }
  });

  group('aksesibilitas: sasaran sentuh, label, kontras', () {
    for (final (nama, lebar, tinggi) in [
      ('HP 360', 360.0, 760.0),
      ('tablet 840', 840.0, 1180.0),
    ]) {
      for (final (tema, tm) in [
        ('terang', AppTheme.light),
        ('gelap', AppTheme.dark),
      ]) {
        for (final keadaan in ['akar', 'hari', 'hasil', 'tanpa-hasil']) {
          testSemantik('$nama · $tema · $keadaan', (tester) async {
            await _bawaKe(tester, keadaan, (
              nama: nama,
              lebar: lebar,
              tinggi: tinggi,
              skala: 1.0,
            ), tm);

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            // Pedoman SDK melewati target di dalam daftar gulir: ukur sendiri.
            expect(
              sasaranSentuhKurang(tester),
              isEmpty,
              reason: 'sasaran sentuh < 48 dp',
            );
          });
        }
      }
    }
  });

  group('Semantics dan hierarki', () {
    testSemantik(
      'judul PT dan hari adalah header; ringkasan adalah live region',
      (tester) async {
        await bukaLayarArsip(
          tester,
          ServiceLayar(
            sesi: [
              sesiUji(
                9,
                alat: 'Jangka Sorong',
                seri: 'SN-1',
                sertifikat: 'CAL/2026/11/0009',
              ),
            ],
          ),
        );
        await cariDiKotak(tester, 'sn');

        expect(
          tester.getSemantics(find.text('PT Contoh Alfa')),
          isSemantics(isHeader: true),
        );
        expect(
          tester.getSemantics(find.text('1 sesi cocok')),
          isSemantics(isLiveRegion: true),
        );
      },
    );

    testSemantik('judul hari di garis waktu juga header', (tester) async {
      await _bawaKe(tester, 'hari', _ukuranUji[3], AppTheme.light);

      expect(
        tester.getSemantics(find.text('Kamis, 12 Nov 2026')),
        isSemantics(isHeader: true),
      );
    });

    testSemantik('kotak cari berlabel; garis kemajuan berlabel "Memuat"', (
      tester,
    ) async {
      await _bawaKe(tester, 'memuat', _ukuranUji[3], AppTheme.light);

      final kotak = tester.getSemantics(find.byType(TextField).first);
      expect(
        '${kotak.label} ${kotak.hint}',
        contains('Cari no. seri, no. sertifikat, atau no. order'),
      );
      expect(
        tester.getSemantics(find.byType(LinearProgressIndicator)).label,
        'Memuat',
      );
      await _tuntaskan(tester);
    });

    testSemantik('baris yang terbuka di panel kanan bertanda "selected"', (
      tester,
    ) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar(
          sesi: [
            sesiUji(
              9,
              alat: 'Jangka Sorong',
              seri: 'SN-1',
              sertifikat: 'CAL/2026/11/0009',
            ),
          ],
        ),
        lebar: 900,
        tinggi: 800,
      );
      await cariDiKotak(tester, 'sn');
      expect(
        tester.getSemantics(find.byType(KartuInstrumenArsip)),
        isNot(isSemantics(isSelected: true)),
      );

      await tester.tap(find.text('Jangka Sorong'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(KartuInstrumenArsip)),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('skala tipografi: PT > judul kartu > keterangan', (
      tester,
    ) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar(
          sesi: [
            sesiUji(
              9,
              alat: 'Jangka Sorong',
              seri: 'SN-1',
              sertifikat: 'CAL/2026/11/0009',
            ),
          ],
        ),
      );
      await cariDiKotak(tester, 'sn');

      double ukuran(String teks) =>
          tester.widget<Text>(find.text(teks)).style!.fontSize!;
      final pt = ukuran('PT Contoh Alfa');
      final judulKartu = ukuran('Jangka Sorong');
      final keterangan = ukuran('No. Seri SN-1');

      expect(pt, greaterThan(judulKartu));
      expect(judulKartu, greaterThan(keterangan));
    });

    testWidgets('kartu kelompok tanpa ikon dekoratif di depan judul', (
      tester,
    ) async {
      await bukaLayarArsip(tester, ServiceLayar());

      final kartu = find.ancestor(
        of: find.text('2026'),
        matching: find.byType(Card),
      );
      // Hanya chevron penunjuk; tidak ada ubin/ikon hiasan di depan judul.
      final ikon = tester
          .widgetList<Icon>(
            find.descendant(of: kartu, matching: find.byType(Icon)),
          )
          .map((i) => i.icon)
          .toList();
      expect(ikon, [Icons.chevron_right]);
    });
  });

  group('informasi tidak hanya lewat warna', () {
    for (final keadaan in ['hari', 'hasil']) {
      testWidgets('$keadaan: tiap lencana membawa ikon DAN kata', (
        tester,
      ) async {
        await _bawaKe(tester, keadaan, _ukuranUji[3], AppTheme.dark);

        final lencana = tester.widgetList<StatusBadge>(
          find.byType(StatusBadge),
        );
        expect(lencana, isNotEmpty);
        for (final l in lencana) {
          expect(l.icon, isNotNull, reason: 'lencana tanpa ikon: ${l.tone}');
        }
        // Dan katanya benar-benar tertulis.
        expect(find.text('Terbit'), findsWidgets);
      });
    }

    testWidgets(
      'wakil hasil cari berstatus dibatalkan: dicoret DAN berlencana',
      (tester) async {
        await bukaLayarArsip(
          tester,
          ServiceLayar(
            sesi: [
              sesiUji(
                9,
                alat: 'Jangka Sorong',
                seri: 'SN-1',
                sertifikat: 'CAL/2026/11/0009',
                status: 'dibatalkan',
              ),
            ],
          ),
        );
        await cariDiKotak(tester, 'sn');

        expect(find.text('Dibatalkan'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('CAL/2026/11/0009')).style!.decoration,
          TextDecoration.lineThrough,
        );
      },
    );

    testWidgets('kartu garis waktu dibatalkan: dicoret DAN berlencana', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: KartuSertifikatWaktu(
              item: const ItemGarisWaktu(
                id: 1,
                nomor: 'CAL/2026/11/0001',
                status: 'dibatalkan',
              ),
              disorot: false,
              onTap: null,
            ),
          ),
        ),
      );

      expect(find.text('Dibatalkan'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('CAL/2026/11/0001')).style!.decoration,
        TextDecoration.lineThrough,
      );
    });

    testWidgets('sertifikat dibatalkan: dicoret DAN berlencana', (
      tester,
    ) async {
      await _bawaKe(tester, 'hasil', _ukuranUji[3], AppTheme.light);

      expect(find.text('Dibatalkan'), findsOneWidget);
      final nomor = tester.widget<Text>(find.text('CAL/2025/11/0008'));
      expect(nomor.style!.decoration, TextDecoration.lineThrough);
    });
  });

  group('keadaan dirancang dengan langkah berikutnya', () {
    testWidgets('tanpa koneksi: bilang jujur butuh online + Coba lagi', (
      tester,
    ) async {
      await _bawaKe(tester, 'offline', _ukuranUji[0], AppTheme.light);

      expect(
        find.textContaining('Arsip hanya bisa dibuka saat online'),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('sesi habis (401): pesan Indonesia, tanpa pesan mentah server, '
        'tanpa Coba lagi', (tester) async {
      final service = ServiceLayar()
        ..galatGarisWaktu = const ApiException('Unauthenticated.', status: 401);
      await bukaLayarArsip(tester, service);

      expect(find.text('Sesi kamu habis. Login ulang ya.'), findsOneWidget);
      expect(find.text('Unauthenticated.'), findsNothing);
      expect(find.text('Coba lagi'), findsNothing);
    });

    testWidgets('terlalu sering (429) punya kalimat sendiri', (tester) async {
      await bukaLayarArsip(
        tester,
        ServiceLayar()..galatGarisWaktu = const ApiException('x', status: 429),
      );

      expect(
        find.text(
          'Terlalu banyak permintaan. Tunggu sebentar, lalu coba lagi.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('server belum mendukung: tanpa Coba lagi (tidak akan sembuh)', (
      tester,
    ) async {
      await _bawaKe(tester, 'server-lama', _ukuranUji[0], AppTheme.light);

      expect(find.text('Coba lagi'), findsNothing);
      expect(find.textContaining('belum mendukung'), findsOneWidget);
    });
  });

  group('pencarian terasa cepat', () {
    testWidgets('pencarian baru: daftar lama TETAP tampil dengan garis '
        'kemajuan, bukan kosong/kerangka', (tester) async {
      final tahan = Completer<HalamanRiwayat>();
      final service = ServiceLayar()
        ..riwayatKhusus = (filter, halaman) {
          if (filter.kataKirim == 'sn-02') return tahan.future;
          return Future.value(
            HalamanRiwayat(
              baris: [
                sesiUji(
                  9,
                  alat: 'Jangka Sorong',
                  seri: 'SN-1',
                  sertifikat: 'CAL/2026/11/0009',
                ),
              ],
              halaman: 1,
              halamanTerakhir: 2,
              total: 2,
            ),
          );
        };
      await bukaLayarArsip(tester, service);
      await cariDiKotak(tester, 'sn');
      expect(find.text('CAL/2026/11/0009'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Muat lebih banyak'), findsOneWidget);
      final posisiAwal = tester.getTopLeft(find.text('CAL/2026/11/0009')).dy;

      await tester.enterText(find.byType(TextField).first, 'sn-02');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('CAL/2026/11/0009'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
      // Daftar lama tampil, tetapi halaman berikutnya BUKAN haknya: tombol
      // "muat lagi" ikut hilang selagi saringan baru dimuat.
      expect(find.text('Muat lebih banyak'), findsNothing);
      // Slot garis kemajuan sudah ada sebelumnya: daftar tidak melompat.
      expect(tester.getTopLeft(find.text('CAL/2026/11/0009')).dy, posisiAwal);

      tahan.complete(
        HalamanRiwayat(
          baris: [
            sesiUji(
              8,
              alat: 'Micrometer',
              seri: 'SN-2',
              sertifikat: 'CAL/2026/11/0008',
            ),
          ],
          halaman: 1,
          halamanTerakhir: 1,
          total: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CAL/2026/11/0008'), findsOneWidget);
      expect(find.text('CAL/2026/11/0009'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testSemantik('memuat halaman berikutnya: pemuat berlabel, tombol tidak '
        'ditekan dua kali', (tester) async {
      final tahan = Completer<HalamanRiwayat>();
      final service = ServiceLayar()
        ..riwayatKhusus = (filter, halaman) => halaman == 1
            ? Future.value(
                HalamanRiwayat(
                  baris: [
                    sesiUji(
                      9,
                      alat: 'Jangka Sorong',
                      seri: 'SN-1',
                      sertifikat: 'CAL/2026/11/0009',
                    ),
                  ],
                  halaman: 1,
                  halamanTerakhir: 2,
                  total: 2,
                ),
              )
            : tahan.future;
      await bukaLayarArsip(tester, service);
      await cariDiKotak(tester, 'sn');

      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Muat lebih banyak'), findsNothing);
      expect(
        tester.getSemantics(find.byType(CircularProgressIndicator)).label,
        'Memuat',
      );
      // Daftar yang sudah ada tidak hilang selama menunggu.
      expect(find.text('CAL/2026/11/0009'), findsOneWidget);

      tahan.complete(
        HalamanRiwayat(
          baris: [
            sesiUji(
              8,
              alat: 'Micrometer',
              seri: 'SN-2',
              sertifikat: 'CAL/2026/11/0008',
            ),
          ],
          halaman: 2,
          halamanTerakhir: 2,
          total: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CAL/2026/11/0008'), findsOneWidget);
    });

    testWidgets('tombol cari di papan ketik menjalankan pencarian TANPA '
        'menunggu jeda', (tester) async {
      final service = ServiceLayar();
      await bukaLayarArsip(tester, service);

      await tester.enterText(find.byType(TextField).first, 'sn-0204');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();

      expect(service.panggilanRiwayat, hasLength(1));
      expect(service.panggilanRiwayat.single.filter.kataKirim, 'sn-0204');

      // Jeda 300 ms yang masih tersisa tidak menembak lagi.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(service.panggilanRiwayat, hasLength(1));
    });
  });
}
