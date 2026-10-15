import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/core/utils/angka.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/data_acuan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/banding_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/daftar_paket_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/garis_waktu_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/riwayat_sel_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/studio_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/widgets/grid_acuan.dart';
import 'package:sidik_calibration/screens/shell/desktop_shell.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/data_acuan_contoh_micrometer.dart';
import 'package:sidik_calibration/services/data_acuan_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/penugasan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/lewati_onboarding.dart';

/// Layar Studio Data Acuan (CR-48 M2, BACA saja): S1 daftar paket, S2 studio,
/// S3 banding, S7 garis waktu & riwayat sel. Pintu masuk menunya hidup di
/// aplikasi Sidik Studio (`studio/`, re-scope 9 Okt 2026); di sini dijaga
/// bahwa app lapangan TIDAK lagi memuatnya.
///
/// ## Sumber angka
///
/// - Isi & skema Micrometer = `MockDataAcuanService`, yang memakai
///   `data_acuan_contoh_micrometer.dart` — dicetak mesin dari kode server
///   (`JsonKanonik` atas `database/data/tabel-standar-micrometer.json`,
///   `MicrometerProfile::skemaAcuan()`), bukan diketik tangan.
/// - Contoh banding berubah (19.00011 → 19.00211, selisih
///   `0.0019999999999988916`) disalin dari `docs/kontrak-api.md` §15 repo API
///   (kontrak menyebutnya "angka uji", bukan data lab).
/// - Skema "alat lain" di grup `tab dari skema` adalah FIXTURE STRUKTUR
///   sintetis — bukan angka lab; gunanya membuktikan tab tidak dikodekan per
///   alat.
///
/// ## Aturan peran yang dicerminkan (repo API)
///
/// `DataAcuanController::bolehLihatSemua()` = peran ≠ teknisi. Teknisi:
/// banding → 404, riwayat sel → 404, garis waktu → versi aktif saja.
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
void main() {
  setUpAll(_muatFont);

  group('angka persis', () {
    test('int, float berpecahan nol, dan float panjang tidak diubah', () {
      expect(teksAngkaPersis(jsonDecode('20.0') as num), '20.0');
      expect(teksAngkaPersis(jsonDecode('200') as num), '200');
      expect(teksAngkaPersis(1.00011), '1.00011');
      expect(teksAngkaPersis(0.111803398875), '0.111803398875');
      // Kontrak §15: presisi penuh float apa adanya.
      expect(teksAngkaPersis(0.0019999999999988916), '0.0019999999999988916');
    });

    test('notasi eksponen diurai tanpa mengubah digit', () {
      // `delta_alpha_per_c` Micrometer = 1.0e-5 di isi kanonik.
      expect(teksAngkaPersis(jsonDecode('1.0e-5') as num), '0.00001');
      expect(teksAngkaPersis(1e-7), '0.0000001');
      expect(teksAngkaPersis(-2.5e-8), '-0.000000025');
      expect(teksAngkaPersis(1.2345e21), '1234500000000000000000.0');
      expect(double.parse(teksAngkaPersis(1.5e-9)), 1.5e-9);
    });

    test('nilai sel: daftar angka, teks, null', () {
      expect(teksNilaiAcuan(jsonDecode('[20.0, 5.0]')), '[20.0, 5.0]');
      expect(teksNilaiAcuan(<Object?>[]), '[]');
      expect(teksNilaiAcuan('LK-410-IDN'), 'LK-410-IDN');
      expect(teksNilaiAcuan(null), isNull);
    });
  });

  group('baris tampil', () {
    test('lembar `baris` berkunci angka diurut numerik, kunci tetap teks', () {
      final skema = _skemaMicrometer();
      final balok = skema.lembar.firstWhere((l) => l.kode == 'balok_ukur');
      final baris = barisLembarAcuan(balok, jsonDecode(contohIsiMicrometerV1));

      // Isi kanonik terurut TEKS: 100.0 sebelum 11.0.
      expect(baris.keys.take(12).last, '11.0');

      final tampil = urutBarisTampilAcuan(balok, baris);
      expect(tampil.first.key, '1.0');
      expect(tampil.last.key, '200.0');
      expect(tampil.length, baris.length);
      // Kunci kolom tetap teks apa adanya (server: `(string) $k`).
      expect(tampil.first.value['nominal_mm'], '1.0');
      expect(tampil.first.value['nilai_terkoreksi_mm'], 1.00011);
    });

    test('lembar `daftar` tidak diurut ulang (posisi bermakna)', () {
      final skema = _skemaMicrometer();
      final titik = skema.lembar.firstWhere((l) => l.kode == 'titik_pra_cetak');
      final baris = barisLembarAcuan(titik, jsonDecode(contohIsiMicrometerV1));

      expect(urutBarisTampilAcuan(titik, baris).map((e) => e.key), baris.keys);
    });

    test('kunci daftar berangka bulat ditulis seperti `(string)` PHP', () {
      final lembar = LembarSkemaAcuan.fromJson(_lembarDaftarSintetis);
      final baris = barisLembarAcuan(lembar, jsonDecode(_isiSintetis));

      expect(baris.keys, ['25', '50']);
      // Nilainya tetap float apa adanya.
      expect(baris['25']!['nominal'], 25.0);
    });
  });

  group('S1 daftar paket', () {
    testWidgets('data: versi aktif + tanggal, jumlah lembar, belum diimpor', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      await _pasang(tester, const DaftarPaketAcuanScreen());

      expect(find.text('Paket data acuan'), findsOneWidget);
      expect(find.text('Micrometer'), findsOneWidget);
      expect(find.text('micrometer'), findsOneWidget);
      expect(find.text('v1 · berlaku sejak 1 Jan 2024'), findsOneWidget);
      // Panjang skema detail paket (8 lembar Micrometer).
      expect(find.text('8 lembar'), findsOneWidget);
      // Admin & server menyebut 0 draf: angka nol TIDAK ditulis.
      expect(find.textContaining('draf'), findsNothing);

      expect(find.text('Height Gauge'), findsOneWidget);
      expect(find.text('Belum diimpor'), findsOneWidget);
    });

    testWidgets('ketuk paket membuka Studio; paket belum diimpor tanpa aksi', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan();
      await _pasang(tester, const DaftarPaketAcuanScreen(), layanan: layanan);

      await tester.tap(find.text('Height Gauge'));
      await _tenang(tester);
      expect(find.byType(StudioAcuanScreen), findsNothing);
      expect(layanan.hitung('paket:height_gauge'), 0);

      await tester.tap(find.text('Micrometer'));
      await _tenang(tester);
      expect(find.byType(StudioAcuanScreen), findsOneWidget);
      expect(find.text('Balok ukur — nilai terkoreksi'), findsOneWidget);
    });

    testWidgets('kosong: petunjuk impor hanya untuk super admin', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      await _pasang(
        tester,
        const DaftarPaketAcuanScreen(),
        token: 'mock-token-1',
        layanan: _Layanan(kosong: true),
      );
      expect(find.text('Belum ada paket data acuan.'), findsOneWidget);
      expect(find.textContaining('acuan:impor-awal'), findsNothing);

      await _pasang(
        tester,
        const DaftarPaketAcuanScreen(),
        token: 'mock-token-5',
        layanan: _Layanan(kosong: true),
      );
      expect(find.text('Belum ada paket data acuan.'), findsOneWidget);
      expect(find.textContaining('acuan:impor-awal'), findsOneWidget);
    });

    testWidgets('galat → Coba lagi menarik ulang', (tester) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan(gagalDaftar: 1);
      await _pasang(tester, const DaftarPaketAcuanScreen(), layanan: layanan);

      // Pesan exception mentah tidak dibocorkan ke layar.
      expect(find.text('Data acuan gagal dimuat.'), findsOneWidget);
      expect(find.textContaining('jaringan putus'), findsNothing);
      expect(find.text('Micrometer'), findsNothing);

      await tester.tap(find.text('Coba lagi'));
      await _tenang(tester);

      expect(layanan.hitung('daftarPaket'), 2);
      expect(find.text('Micrometer'), findsOneWidget);
    });

    testWidgets('teknisi: kunci draf tidak dikirim → tidak ada "0 draf"', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      await _pasang(
        tester,
        const DaftarPaketAcuanScreen(),
        token: 'mock-token-2',
        layanan: _Layanan(sebagaiTeknisi: true),
      );

      expect(find.text('Micrometer'), findsOneWidget);
      expect(find.textContaining('draf'), findsNothing);
    });
  });

  group('S2 studio', () {
    testWidgets('tab dibangun dari skema server (8 lembar Micrometer)', (
      tester,
    ) async {
      await _ukuran(tester, const Size(1138, 711));
      await _bukaStudio(tester);

      final skema = _skemaMicrometer();
      expect(skema.lembar, hasLength(8));
      expect(find.byType(Tab), findsNWidgets(skema.lembar.length));
      for (final l in skema.lembar) {
        expect(find.text(l.label), findsOneWidget, reason: l.kode);
      }
      // Tidak ada aksi tulis (P2 belum ada).
      for (final kata in ['Sunting', 'Buat draf', 'Ajukan', 'Sahkan']) {
        expect(find.textContaining(kata), findsNothing, reason: kata);
      }
    });

    testWidgets('tab alat lain muncul tanpa kode khusus alat', (tester) async {
      await _ukuran(tester, const Size(1138, 711));
      await _pasang(
        tester,
        const StudioAcuanScreen(kode: 'alat_sintetis'),
        layanan: _LayananAlatLain(),
      );

      expect(find.byType(Tab), findsNWidgets(2));
      expect(find.text('Identitas sintetis'), findsOneWidget);
      expect(find.text('Daftar berkunci angka'), findsOneWidget);
    });

    testWidgets('angka tampil persis: balok ukur, kunci teks, satuan', (
      tester,
    ) async {
      await _ukuran(tester, const Size(1138, 711));
      await _bukaStudio(tester);
      await _bukaTab(tester, 'Balok ukur — nilai terkoreksi');

      // Kepala kolom = label + satuan dari skema.
      expect(find.text('Nominal'), findsOneWidget);
      expect(find.text('Nilai terkoreksi'), findsOneWidget);
      expect(find.text('mm'), findsNWidgets(2));

      // Urut numerik, nilai persis.
      expect(find.text('1.0'), findsOneWidget);
      expect(find.text('1.00011'), findsOneWidget);
      expect(find.text('1.5999'), findsOneWidget);

      // Baris terakhir ada di luar layar — virtualisasi; gulir ke sana.
      expect(find.text('200.00017'), findsNothing);
      await tester.dragUntilVisible(
        find.text('200.00017'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('200.00017'), findsOneWidget);
      expect(
        find.text(
          '32 baris · nilai tampil persis seperti tersimpan, '
          'tidak dibulatkan',
        ),
        findsOneWidget,
      );
    });

    testWidgets('konstanta: 20.0 tetap 20.0, 200 tetap 200, 1.0e-5 tanpa '
        'eksponen, perlu konfirmasi ditandai', (tester) async {
      await _ukuran(tester, const Size(1138, 711));
      await _bukaStudio(tester);
      await _bukaTab(tester, 'Konstanta metode');

      expect(find.text('20.0'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('0.00001'), findsOneWidget);
      expect(find.text('0.111803398875'), findsOneWidget);
      // Δα dan vi_type_b ber-`perlu_konfirmasi: true` di skema.
      expect(find.byTooltip('Perlu konfirmasi lab'), findsNWidgets(2));
    });

    testWidgets('pita CMC: daftar angka apa adanya', (tester) async {
      await _ukuran(tester, const Size(1138, 711));
      await _bukaStudio(tester);
      await _bukaTab(tester, 'Pita CMC & varian kertas');

      expect(find.text('[20.0, 5.0]'), findsOneWidget);
      expect(find.text('0.83'), findsOneWidget);
      expect(find.text('SIDIK-FM-CAL-0522.A_Rev.1'), findsOneWidget);
    });

    testWidgets('admin: ketuk sel → rincian → riwayat sel', (tester) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan();
      await _bukaStudio(tester, layanan: layanan);
      await _bukaTab(tester, 'Balok ukur — nilai terkoreksi');

      await tester.dragUntilVisible(
        find.text('19.00011'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('19.00011'));
      await _tenang(tester);

      expect(find.text('Nilai terkoreksi · mm'), findsOneWidget);
      expect(find.text('Standar_GB!R10:R132'), findsOneWidget);
      expect(find.text('19.0'), findsWidgets);

      await tester.tap(find.text('Riwayat sel'));
      await _tenang(tester);

      expect(find.byType(RiwayatSelAcuanScreen), findsOneWidget);
      expect(layanan.hitung('riwayatSel'), 1);
      expect(layanan.selTerakhir, (
        versiId: MockDataAcuanService.idVersi1,
        lembar: 'balok_ukur',
        kunci: '19.0',
        kolom: 'nilai_terkoreksi_mm',
      ));
      expect(find.text('NILAI DI TIAP VERSI'), findsOneWidget);
      expect(find.text('19.00011'), findsWidgets);
      expect(
        find.text('Belum ada suntingan tercatat untuk sel ini.'),
        findsOneWidget,
      );
    });

    testWidgets('teknisi: rincian sel TANPA tombol riwayat (server 404)', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan(sebagaiTeknisi: true);
      await _bukaStudio(tester, token: 'mock-token-2', layanan: layanan);
      await _bukaTab(tester, 'Balok ukur — nilai terkoreksi');

      await tester.tap(find.text('1.00011'));
      await _tenang(tester);

      expect(find.text('Nilai terkoreksi · mm'), findsOneWidget);
      expect(find.text('Riwayat sel'), findsNothing);
      expect(layanan.hitung('riwayatSel'), 0);
    });

    testWidgets('info versi: sha dipendekkan, tanpa pengesah karangan', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      await _bukaStudio(tester);

      await tester.tap(find.byTooltip('Info versi'));
      await _tenang(tester);

      expect(find.text('ba1fa153…f585'), findsOneWidget);
      expect(find.text('Belum ada pengesahan tercatat'), findsOneWidget);
      expect(find.text('sejak 1 Jan 2024, tanpa batas akhir'), findsOneWidget);
    });
  });

  group('S7 garis waktu & S3 banding', () {
    testWidgets('admin: garis waktu v1 → banding v1↔v1 = Tidak ada perbedaan', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan();
      await _pasang(
        tester,
        const GarisWaktuAcuanScreen(kode: 'micrometer', nama: 'Micrometer'),
        layanan: layanan,
      );

      expect(find.text('v1'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('ba1fa153…f585'), findsOneWidget);

      await tester.tap(find.byTooltip('Bandingkan versi'));
      await _tenang(tester);

      expect(find.byType(BandingAcuanScreen), findsOneWidget);
      expect(find.text('Tidak ada perbedaan'), findsOneWidget);
      expect(
        find.text('Isi v1 dan v1 sama persis di semua lembar.'),
        findsOneWidget,
      );
      expect(layanan.hitung('banding'), 1);
    });

    testWidgets('teknisi: garis waktu tanpa tombol banding', (tester) async {
      await _ukuran(tester, const Size(711, 1138));
      await _pasang(
        tester,
        const GarisWaktuAcuanScreen(kode: 'micrometer'),
        token: 'mock-token-2',
        layanan: _Layanan(sebagaiTeknisi: true),
      );

      expect(find.text('v1'), findsOneWidget);
      expect(find.byTooltip('Bandingkan versi'), findsNothing);
    });

    testWidgets('teknisi lewat rute langsung: banding & riwayat tidak '
        'memanggil server', (tester) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan(sebagaiTeknisi: true);

      await _pasang(
        tester,
        const BandingAcuanScreen(kode: 'micrometer'),
        token: 'mock-token-2',
        layanan: layanan,
      );
      expect(
        find.text('Banding versi tidak tersedia untuk peran teknisi.'),
        findsOneWidget,
      );

      await _pasang(
        tester,
        const RiwayatSelAcuanScreen(
          sel: (
            versiId: MockDataAcuanService.idVersi1,
            lembar: 'balok_ukur',
            kunci: '19.0',
            kolom: 'nilai_terkoreksi_mm',
          ),
        ),
        token: 'mock-token-2',
        layanan: layanan,
      );
      expect(
        find.text('Riwayat sel tidak tersedia untuk peran teknisi.'),
        findsOneWidget,
      );

      expect(layanan.hitung('banding'), 0);
      expect(layanan.hitung('riwayatSel'), 0);
    });

    testWidgets('banding berubah: lama, baru, selisih bertanda presisi penuh', (
      tester,
    ) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _LayananDuaVersi();
      await _pasang(
        tester,
        const BandingAcuanScreen(kode: 'micrometer'),
        layanan: layanan,
      );

      // Bawaan: dua versi data terakhir, lama → baru.
      expect(layanan.pasangan, [(12, 15)]);
      expect(
        find.text(
          '1 lembar berubah · 1 sel · 0 baris ditambah · 0 baris '
          'dihapus',
        ),
        findsOneWidget,
      );
      expect(find.text('Nilai terkoreksi · mm'), findsOneWidget);
      expect(find.text('19.00011'), findsOneWidget);
      expect(find.text('19.00211'), findsOneWidget);
      expect(find.text('+0.0019999999999988916'), findsOneWidget);
      expect(find.text('+0.00010526254847992415'), findsOneWidget);
    });
  });

  group('gerbang izin', () {
    testWidgets('rute langsung tanpa izin → "Butuh izin", server tidak '
        'dipanggil', (tester) async {
      await _ukuran(tester, const Size(711, 1138));
      final layanan = _Layanan();
      await _pasang(
        tester,
        const DaftarPaketAcuanScreen(),
        izin: const Izin(role: UserRole.admin, boleh: {'lain.lain'}),
        layanan: layanan,
      );

      expect(find.text('Butuh izin data-acuan.lihat'), findsOneWidget);
      expect(layanan.hitung('daftarPaket'), 0);
    });

    // Keputusan pemilik 9 Okt 2026 (re-scope "Sidik Studio"): data acuan
    // hidup di aplikasi TERPISAH `studio/`, bukan di app lapangan. Layar M2
    // tetap di `lib/` karena Studio memakainya lewat paket ini; pintu
    // masuknya dari app lapangan dicabut. Dua test di bawah menjaga supaya
    // menunya tidak kembali diam-diam — WALAU izinnya ada. Gerbang izin
    // menu Studio diuji di `studio/test/studio_test.dart`.
    testWidgets('app lapangan: drawer tanpa menu Data acuan walau izin ada', (
      tester,
    ) async {
      for (final token in ['mock-token-1', 'mock-token-3', 'mock-token-5']) {
        await _bukaDrawer(tester, token: token, denganIzin: true);
        expect(find.byType(Drawer), findsOneWidget, reason: token);
        expect(_diDrawer('Data acuan'), findsNothing, reason: token);
      }
      // Teknisi tidak punya menu samping sama sekali (K-50-14: dua tab saja).
      await tester.pumpWidget(_shell(token: 'mock-token-2', denganIzin: true));
      await _tenang(tester);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('app lapangan: desktop tanpa seksi Data Acuan walau izin ada', (
      tester,
    ) async {
      // Tinggi: sidebar `ListView` tidak membangun seksi di bawah lipatan.
      await _ukuran(tester, const Size(1440, 1600));

      await tester.pumpWidget(
        _shell(token: 'mock-token-1', denganIzin: true, desktop: true),
      );
      await _tenang(tester);
      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.text('DATA ACUAN'), findsNothing);
      expect(find.text('Paket data acuan'), findsNothing);
    });
  });

  group('tata letak tidak pecah', () {
    // HP kecil, tablet 25040RP0AG potret (bottom nav) & lanskap (rail).
    const ukuran = [Size(360, 800), Size(711, 1138), Size(1138, 711)];

    for (final u in ukuran) {
      for (final skala in [1.0, 1.3]) {
        testWidgets('${u.width.toInt()}x${u.height.toInt()} teks $skala', (
          tester,
        ) async {
          await _ukuran(tester, u);

          await _pasang(tester, const DaftarPaketAcuanScreen(), skala: skala);
          expect(find.text('Micrometer'), findsOneWidget);

          await _bukaStudio(tester, skala: skala);
          for (final l in _skemaMicrometer().lembar) {
            await _bukaTab(tester, l.label);
          }
          // Lembar memanjang + rincian sel.
          await _bukaTab(tester, 'Konstanta metode');
          await tester.tap(find.text('0.00001'));
          await _tenang(tester);
          expect(
            find.text('Asal-usul nilai ini belum dikonfirmasi lab.'),
            findsOneWidget,
          );
          await tester.tapAt(const Offset(4, 4));
          await _tenang(tester);
          await tester.tap(find.byTooltip('Info versi'));
          await _tenang(tester);
          expect(find.text('ba1fa153…f585'), findsOneWidget);

          await _pasang(
            tester,
            const GarisWaktuAcuanScreen(kode: 'micrometer'),
            skala: skala,
          );
          await _pasang(
            tester,
            const BandingAcuanScreen(kode: 'micrometer'),
            layanan: _LayananDuaVersi(),
            skala: skala,
          );
          expect(find.text('+0.0019999999999988916'), findsOneWidget);
          await _pasang(
            tester,
            const RiwayatSelAcuanScreen(
              sel: (
                versiId: MockDataAcuanService.idVersi1,
                lembar: 'konstanta',
                kunci: '0',
                kolom: 'delta_alpha_per_c',
              ),
              labelLembar: 'Konstanta metode',
            ),
            skala: skala,
          );
          expect(find.text('0.00001'), findsWidgets);
        });
      }
    }
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

Future<void> _muatFont() async {
  const berkas = {
    'Inter': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'IBMPlexMono': ['Regular', 'Medium', 'SemiBold', 'Bold'],
  };
  for (final MapEntry(key: keluarga, value: ragam) in berkas.entries) {
    final pemuat = FontLoader(keluarga);
    for (final r in ragam) {
      final bytes = File('assets/fonts/$keluarga-$r.ttf').readAsBytesSync();
      pemuat.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await pemuat.load();
  }
}

/// `pumpAndSettle` berhenti begitu tidak ada frame terjadwal, padahal mock
/// masih memegang timer `Future.delayed(Duration.zero)` untuk muatan
/// berikutnya (auth → izin → detail paket → versi). Waktunya dimajukan
/// beberapa langkah sampai rantainya habis.
Future<void> _tenang(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
  }
}

Future<void> _ukuran(WidgetTester tester, Size ukuran) async {
  tester.view.physicalSize = ukuran;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

SkemaAcuan _skemaMicrometer() => SkemaAcuan.fromJson(
  jsonDecode(contohSkemaMicrometer) as Map<String, dynamic>,
);

UserRole _peranToken(String token) => switch (token) {
  'mock-token-2' => UserRole.teknisi,
  'mock-token-3' => UserRole.viewer,
  'mock-token-5' => UserRole.superAdmin,
  _ => UserRole.admin,
};

/// Jawaban `/me/permissions` server hari ini: semua peran lab punya
/// `data-acuan.lihat` (`IzinDataAcuanTest::test_izin_lihat_ada_di_matriks_semua_role_lab`).
Izin _izinLab(String token) =>
    Izin(role: _peranToken(token), boleh: const {NamaIzin.dataAcuanLihat});

Future<void> _pasang(
  WidgetTester tester,
  Widget layar, {
  String token = 'mock-token-1',
  Izin? izin,
  DataAcuanService? layanan,
  double skala = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Kunci baru tiap pasang: ProviderScope lama dibuang, cache provider
      // tidak terbawa antar-kasus dalam satu test.
      key: UniqueKey(),
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        izinServiceProvider.overrideWithValue(
          MockIzinService(izin: izin ?? _izinLab(token)),
        ),
        dataAcuanServiceProvider.overrideWithValue(
          layanan ?? _Layanan(sebagaiTeknisi: token == 'mock-token-2'),
        ),
      ],
      child: MaterialApp(
        theme: SidikTheme.terang,
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(skala)),
          child: child!,
        ),
        home: layar,
      ),
    ),
  );
  await _tenang(tester);
}

Future<void> _bukaStudio(
  WidgetTester tester, {
  String token = 'mock-token-1',
  DataAcuanService? layanan,
  double skala = 1.0,
}) => _pasang(
  tester,
  const StudioAcuanScreen(kode: 'micrometer', nama: 'Micrometer'),
  token: token,
  layanan: layanan,
  skala: skala,
);

Future<void> _bukaTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(Tab), matching: find.text(label));
  await tester.ensureVisible(tab);
  await _tenang(tester);
  await tester.tap(tab);
  await _tenang(tester);
}

Widget _shell({
  required String token,
  required bool denganIzin,
  bool desktop = false,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    lewatiOnboarding,
    pakaiPanelDesktopProvider.overrideWithValue(desktop),
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    dashboardServiceProvider.overrideWithValue(
      MockDashboardService(jeda: Duration.zero),
    ),
    notificationServiceProvider.overrideWithValue(
      MockNotificationService(jeda: Duration.zero),
    ),
    equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
    izinServiceProvider.overrideWithValue(
      MockIzinService(
        izin: denganIzin
            ? _izinLab(token)
            : Izin(role: _peranToken(token), boleh: const {'lain.lain'}),
      ),
    ),
    pelacakanServiceProvider.overrideWithValue(MockPelacakanService()),
    penugasanServiceProvider.overrideWithValue(MockPenugasanService()),
    dataAcuanServiceProvider.overrideWithValue(
      _Layanan(sebagaiTeknisi: token == 'mock-token-2'),
    ),
  ],
  child: const SidikApp(),
);

Future<void> _bukaDrawer(
  WidgetTester tester, {
  required String token,
  required bool denganIzin,
}) async {
  // Tinggi: menu admin panjang dan `ListView` drawer tidak membangun baris
  // di bawah lipatan (pola `menu_per_peran_test.dart`).
  await _ukuran(tester, const Size(400, 1400));
  await tester.pumpWidget(_shell(token: token, denganIzin: denganIzin));
  await _tenang(tester);
  bukaMenuUtama();
  await _tenang(tester);
}

Finder _diDrawer(String teks) =>
    find.descendant(of: find.byType(Drawer), matching: find.text(teks));

/// Mock kontrak §15 + penghitung panggilan (bukti tombol yang disembunyikan
/// memang tidak menembak server).
class _Layanan extends MockDataAcuanService {
  _Layanan({super.sebagaiTeknisi, this.kosong = false, this.gagalDaftar = 0});

  final bool kosong;
  int gagalDaftar;
  final _panggilan = <String, int>{};
  KunciSelAcuan? selTerakhir;

  int hitung(String nama) => _panggilan[nama] ?? 0;
  void _catat(String nama) => _panggilan[nama] = hitung(nama) + 1;

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) async {
    _catat('daftarPaket');
    if (gagalDaftar > 0) {
      gagalDaftar--;
      throw Exception('jaringan putus');
    }
    if (kosong) return const [];
    return super.daftarPaket(token);
  }

  @override
  Future<PaketAcuan> paket(String token, String kode) {
    _catat('paket:$kode');
    return super.paket(token, kode);
  }

  @override
  Future<BandingAcuan> banding(String token, int lamaId, int baruId) {
    _catat('banding');
    return super.banding(token, lamaId, baruId);
  }

  @override
  Future<RiwayatSelAcuan> riwayatSel(
    String token, {
    required int versiId,
    required String lembar,
    required String kunci,
    required String kolom,
  }) {
    _catat('riwayatSel');
    selTerakhir = (
      versiId: versiId,
      lembar: lembar,
      kunci: kunci,
      kolom: kolom,
    );
    return super.riwayatSel(
      token,
      versiId: versiId,
      lembar: lembar,
      kunci: kunci,
      kolom: kolom,
    );
  }
}

/// Dua versi data (v1 aktif id 12, v2 draf id 15) dan jawaban banding contoh
/// `docs/kontrak-api.md` §15 (repo API), disalin apa adanya.
class _LayananDuaVersi extends _Layanan {
  final pasangan = <(int, int)>[];

  static Map<String, dynamic> _versi(int id, int nomor, String status) => {
    'id': id,
    'paket': 'micrometer',
    'jenis': 'data',
    'nomor': nomor,
    'status': status,
    'berlaku_mulai': status == 'aktif' ? '2024-01-01' : null,
    'berlaku_sampai': null,
    'isi_sha256': status == 'aktif' ? contohSha256MicrometerV1 : null,
  };

  @override
  Future<List<VersiAcuan>> garisWaktu(String token, String kode) async => [
    VersiAcuan.fromJson(_versi(12, 1, 'aktif')),
    VersiAcuan.fromJson(_versi(15, 2, 'draf')),
  ];

  @override
  Future<BandingAcuan> banding(String token, int lamaId, int baruId) async {
    pasangan.add((lamaId, baruId));
    final json =
        jsonDecode(r'''
{
  "data": {
    "paket": "micrometer", "skema_versi": 1,
    "lama": { "id": 12, "nomor": 1, "status": "aktif" },
    "baru": { "id": 15, "nomor": 2, "status": "draf" },
    "lembar": [
      { "kode": "balok_ukur", "label": "Balok ukur — nilai terkoreksi",
        "sel_berubah": [
          { "lembar": "balok_ukur", "kunci": "19.0", "kolom": "nilai_terkoreksi_mm",
            "lama": 19.00011, "baru": 19.00211,
            "selisih_absolut": 0.0019999999999988916, "selisih_relatif": 0.00010526254847992415 }
        ],
        "baris_tambah": [], "baris_hapus": [] }
    ],
    "ringkasan": { "lembar_berubah": 1, "sel_berubah": 1, "baris_tambah": 0, "baris_hapus": 0 }
  }
}
''')
            as Map<String, dynamic>;
    return BandingAcuan.fromJson(json['data'] as Map<String, dynamic>);
  }
}

// FIXTURE STRUKTUR sintetis (bukan angka lab): alat lain dengan dua lembar,
// satu `objek` dan satu `daftar` berkunci angka.
const _lembarDaftarSintetis = <String, dynamic>{
  'kode': 'daftar_angka',
  'label': 'Daftar berkunci angka',
  'jalur': 'daftar',
  'jenis': 'daftar',
  'kunci': 'nominal',
  'kolom': [
    {'kode': 'nominal', 'label': 'Nominal', 'tipe': 'desimal', 'satuan': 'g'},
    {'kode': 'koreksi', 'label': 'Koreksi', 'tipe': 'desimal', 'satuan': 'mg'},
  ],
};

const _isiSintetis = '''
{
  "daftar": [ { "koreksi": 0.1, "nominal": 25.0 }, { "koreksi": -0.2, "nominal": 50.0 } ],
  "identitas": { "nama": "Standar sintetis" }
}
''';

class _LayananAlatLain extends _Layanan {
  @override
  Future<PaketAcuan> paket(String token, String kode) async =>
      PaketAcuan.fromJson({
        'kode': 'alat_sintetis',
        'nama': 'Alat sintetis',
        'skema_versi': 1,
        'diimpor': true,
        'versi_aktif': {'id': 99, 'nomor': 1, 'status': 'aktif'},
        'skema': {
          'skema_versi': 1,
          'lembar': [
            {
              'kode': 'identitas',
              'label': 'Identitas sintetis',
              'jalur': 'identitas',
              'jenis': 'objek',
              'kunci': null,
              'kolom': [
                {'kode': 'nama', 'label': 'Nama', 'tipe': 'teks'},
              ],
            },
            _lembarDaftarSintetis,
          ],
        },
      });

  @override
  Future<VersiAcuan> versi(String token, int versiId) async =>
      VersiAcuan.fromJson({
        'id': 99,
        'paket': 'alat_sintetis',
        'jenis': 'data',
        'nomor': 1,
        'status': 'aktif',
        'isi': jsonDecode(_isiSintetis),
      });
}
