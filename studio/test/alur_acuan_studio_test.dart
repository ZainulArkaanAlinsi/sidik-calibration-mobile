import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/alur_versi_acuan_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_studio/data/pemilih_berkas.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';

import 'pembantu/studio_uji.dart';

/// Studio × alur versi data acuan (§54 repo API): impor master berpeta sel →
/// draf data acuan; alurnya BACA SAJA di Studio karena rute tulis alur
/// memakai `aplikasi:internal` dan token Studio ditolak (`bukan_aplikasi_ini`).
///
/// Bentuk JSON = `ImporWorkbook::ringkasan` + `DrafAcuanMaster::buat` dan
/// pesan `PemeriksaMaster::periksa` (repo API, branch
/// `feat/studio-kendali-olah-data`).

/// Izin yang SENGAJA melebihi `PETA_STUDIO` (server tidak pernah mengirim
/// izin tulis alur ke Studio) — membuktikan tombol tetap tidak muncul karena
/// Studio baca saja, bukan cuma karena izinnya kebetulan absen.
const _izin = Izin(
  role: UserRole.superAdmin,
  boleh: {
    NamaIzin.dataAcuanLihat,
    NamaIzin.workbookLihat,
    NamaIzin.dataAcuanAjukan,
    NamaIzin.dataAcuanSimulasi,
    NamaIzin.dataAcuanAktifkan,
  },
);

/// Pesan server persis bentuk `PemeriksaMaster` (isi butir peraga).
const _pesanStruktur =
    "Master ditolak: struktur tidak cocok dengan peta sel 'micrometer' "
    '(database/data/peta-sel/micrometer.json). '
    "1) Lembar 'Standar_GB' tidak ada. "
    "2) Jangkar 'Nominal' di 'PERHITUNGAN U95%'!B4 bergeser (ditemukan 'Nom').";

const _hasilDraf = {
  'data': {
    'status': 'baru',
    'id': 41,
    'nama': 'Master Olah Data Micrometer 0-25mm',
    'sumber': 'xlsm',
    'sha256': 'abc',
    'kode_profil': 'micrometer',
    'keluarga': 'dimensi',
    'diganti': 0,
    'kunci_jenis': 'dimensi:micrometer-0-25mm',
    'versi': 3,
    'status_jenis': 'aktif',
    'menggantikan': 40,
    'peta_sel': 'tervalidasi',
    'acuan': {
      'status': 'draf_dibuat',
      'versi_id': 2,
      'nomor_versi': 2,
      'sel_berubah': 4,
      'isi_sha256': 'def',
      'varian': '0-25',
      'dasar': 'versi berlaku v1 (#1)',
      'sama_dengan_dasar': false,
    },
    'lembar': 4,
    'sel': 100,
    'rumus': 10,
    'dikecualikan': 0,
  },
};

void main() {
  group('urai', () {
    test('struktur_master_berubah: kepala + butir bernomor', () {
      final g = uraiStrukturBerubah(_pesanStruktur);
      expect(g.kepala, startsWith('Master ditolak'));
      expect(g.butir, [
        "Lembar 'Standar_GB' tidak ada.",
        "Jangkar 'Nominal' di 'PERHITUNGAN U95%'!B4 bergeser (ditemukan 'Nom').",
      ]);
      expect(
        GalatUnggahMaster.dari({'kode': 'struktur_master_berubah'}, ''),
        GalatUnggahMaster.strukturBerubah,
      );
    });

    test('pesan tanpa nomor → kepala saja', () {
      final g = uraiStrukturBerubah('Struktur berubah.');
      expect(g.kepala, 'Struktur berubah.');
      expect(g.butir, isEmpty);
    });

    test('hasil impor: peta_sel + acuan, toleran kunci hilang', () {
      final h = HasilUnggahMaster.fromJson(_hasilDraf);
      expect(h.kodeProfil, 'micrometer');
      expect(h.petaSel, 'tervalidasi');
      expect(h.acuan!.status, 'draf_dibuat');
      expect(h.acuan!.nomorVersi, 2);
      expect(h.acuan!.selBerubah, 4);

      final lama = HasilUnggahMaster.fromJson({
        'data': {'id': 5, 'peta_sel': null, 'acuan': 'bukan peta'},
      });
      expect(lama.acuan, isNull);
      expect(lama.petaSel, isNull);
    });
  });

  group('layar Unggah master × peta sel', () {
    Future<MockWorkbookService> unggah(
      WidgetTester tester, {
      Object? galat,
      HasilUnggahMaster? hasil,
    }) async {
      final mock = MockWorkbookService()..galatUnggah = galat;
      if (hasil != null) mock.hasilUnggah = hasil;
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-5',
          izin: _izin,
          workbook: mock,
          tambahan: [
            pemilihBerkasMasterProvider.overrideWithValue(
              () async => (jalur: '/tmp/M.xlsm', nama: 'M.xlsm'),
            ),
          ],
        ),
      );
      await tenang(tester);
      await bukaSeksi(tester, SeksiStudio.workbookAlat);
      await tester.tap(find.byKey(const ValueKey('tombol-unggah-master')));
      await tenang(tester);
      await tester.tap(find.byKey(const ValueKey('unggah-pilih')));
      await tenang(tester);
      await tester.enterText(
        find.byKey(const ValueKey('unggah-alasan')),
        'Master revisi 2027',
      );
      await tester.tap(find.byKey(const ValueKey('unggah-kirim')));
      await tenang(tester);
      return mock;
    }

    testWidgets('422 struktur_master_berubah: daftar butir jelas', (
      tester,
    ) async {
      await unggah(
        tester,
        galat: const ApiException(
          _pesanStruktur,
          status: 422,
          body: {'kode': 'struktur_master_berubah', 'message': _pesanStruktur},
        ),
      );
      expect(
        find.byKey(const ValueKey('unggah-galat-struktur')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Struktur master tidak cocok lagi dengan peta selnya — tidak ada '
          'yang diimpor:',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('unggah-struktur-butir-0')), findsOne);
      expect(find.byKey(const ValueKey('unggah-struktur-butir-1')), findsOne);
      expect(find.text("Lembar 'Standar_GB' tidak ada."), findsOneWidget);
      expect(find.byKey(const ValueKey('unggah-sukses')), findsNothing);
    });

    testWidgets('berhasil berpeta: draf v2 + buka alur → baca saja', (
      tester,
    ) async {
      await unggah(tester, hasil: HasilUnggahMaster.fromJson(_hasilDraf));

      expect(
        find.byKey(const ValueKey('unggah-peta-tervalidasi')),
        findsOneWidget,
      );
      expect(find.textContaining('Draf data acuan v2 dibuat (4 sel'), findsOne);

      await tester.tap(find.byKey(const ValueKey('unggah-buka-alur')));
      await tenang(tester);

      expect(find.byType(AlurVersiAcuanScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-baca-saja')), findsOneWidget);
      expect(find.text('v2'), findsOneWidget);
      for (final k in ['ajukan', 'simulasi', 'tolak', 'aktifkan']) {
        expect(find.byKey(ValueKey('alur-$k-2')), findsNothing, reason: k);
      }
    });

    testWidgets('belum terpetakan: peringatan isi tidak dipakai olah data', (
      tester,
    ) async {
      await unggah(
        tester,
        hasil: HasilUnggahMaster.fromJson({
          'data': {
            'status': 'baru',
            'id': 42,
            'kode_profil': 'height_gauge',
            'peta_sel': 'belum_terpetakan',
            'acuan': null,
          },
        }),
      );
      expect(
        find.byKey(const ValueKey('unggah-belum-terpetakan')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('unggah-buka-alur')), findsNothing);
    });
  });

  testWidgets('penimpaan Studio: alur data acuan baca saja', (tester) async {
    await pasangUkuran(tester, const Size(1440, 900));
    await tester.pumpWidget(studioUji(meja: true, token: 'mock-token-5'));
    await tenang(tester);
    expect(wadahDari(tester).read(alurAcuanBacaSajaProvider), isTrue);
  });
}
