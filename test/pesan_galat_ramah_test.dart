import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/validasi.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pengirim_draf_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/pesan_penolakan_draf.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Pesan galat ramah: draf yang diarsipkan admin dan sesi yang hilang dari
/// server tidak boleh tampil sebagai nama kelas model Eloquent.
///
/// Bukti kejadian nyata: uji kontrak app-API 19 Nov 2026,
/// `kontrak/hasil/probe-http.json` PR-A5/PR-A6 — `PUT /calibrations/25` oleh
/// teknisi pemilik SESUDAH admin mengarsipkannya dijawab `404`
/// `{"message":"No query results for model [App\Models\CalibrationSession]
/// 25"}`, dan antrean draf lokal menampilkannya apa adanya.
const _teksServer404 =
    r'No query results for model [App\Models\CalibrationSession] 25';

const _userId = 7;

DrafLokal _draf() => DrafLokal(
  userId: _userId,
  sesiId: 25,
  clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
  profil: 'ph_meter',
  disimpanPada: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
  status: StatusDrafLokal.belumTersinkron,
  kiriman: const {'status': 'draft'},
  isian: const {},
);

/// Pengirim yang menolak `PUT` dengan galat [galat].
class _TolakPut implements PengirimDrafService {
  _TolakPut(this.galat);

  final Object galat;
  int put = 0;

  @override
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  }) async => throw galat;

  @override
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    put++;
    throw galat;
  }
}

Future<(SimpananDrafLokalMemori, _TolakPut, HasilSinkronDraf)> _tolak(
  Object galat,
) async {
  final simpanan = SimpananDrafLokalMemori();
  final pengirim = _TolakPut(galat);
  await simpanan.simpan(_draf());
  final s = SinkronDrafLokal(
    simpanan: simpanan,
    pengirim: pengirim,
    userId: _userId,
    bacaToken: () async => 'tok',
    setelahBerubah: () {},
    dengarSiklusAplikasi: false,
  );
  final hasil = await s.jalankan();
  s.dispose();
  return (simpanan, pengirim, hasil);
}

/// Periksa (validasi) dijawab 404: sesi sudah tidak ada di server.
class _PeriksaTidakAda extends MockPerhitunganService {
  @override
  Future<HasilValidasi> periksa(String token, int calibrationId) async {
    throw const ApiException(_teksServer404, status: 404);
  }
}

void main() {
  group('pesanPenolakanDraf (dari STATUS, bukan teks server)', () {
    test('404: draf diarsipkan atau dihapus admin, salinan HP tetap aman', () {
      final p = pesanPenolakanDraf(404);

      expect(p, contains('Draf ini sudah diarsipkan atau dihapus admin'));
      expect(p, contains('Salinan di HP ini tetap tersimpan'));
    });

    test('tiap status punya kalimat sendiri dan tidak ada yang kosong', () {
      final semua = {
        for (final s in [403, 404, 409, 422, 400, 410])
          s: pesanPenolakanDraf(s),
      };

      expect(
        semua.values.toSet().length,
        6,
        reason:
            'kalimat tidak boleh '
            'sama untuk status berbeda: ${semua.values}',
      );
      for (final p in semua.values) {
        expect(p.trim(), isNotEmpty);
        expect(p.toLowerCase(), isNot(contains('no query results')));
      }
      // Status tak dikenal menyebut kodenya supaya bisa dilaporkan.
      expect(pesanPenolakanDraf(410), contains('410'));
    });
  });

  group('antrean draf lokal (SinkronDrafLokal)', () {
    test('404 dengan teks Eloquent: tersimpan kalimat ramah, bukan teks '
        'server', () async {
      final (simpanan, pengirim, hasil) = await _tolak(
        const ApiException(_teksServer404, status: 404),
      );

      expect(hasil.ditolak, 1);
      final d = (await simpanan.daftar(_userId)).single;
      expect(d.status, StatusDrafLokal.perluDiperbaiki);
      expect(d.pesan, pesanPenolakanDraf(404));
      expect(d.pesan, isNot(contains('No query results')));
      expect(d.pesan, isNot(contains('CalibrationSession')));
      expect(pengirim.put, 1);
    });

    test('kalimat tidak ikut berubah bila teks server berubah (hanya status '
        'yang dibaca)', () async {
      final (a, _, _) = await _tolak(
        const ApiException('Teks lama.', status: 404),
      );
      final (b, _, _) = await _tolak(
        const ApiException('Kalimat baru dari server.', status: 404),
      );

      expect(
        (await a.daftar(_userId)).single.pesan,
        (await b.daftar(_userId)).single.pesan,
      );
    });

    test('403, 409, 422 masing-masing mendapat kalimat statusnya', () async {
      for (final status in [403, 409, 422]) {
        final (simpanan, _, _) = await _tolak(
          ApiException('The foo field is required.', status: status),
        );
        final d = (await simpanan.daftar(_userId)).single;
        expect(d.pesan, pesanPenolakanDraf(status), reason: '$status');
        expect(d.pesan, isNot(contains('field is required')));
      }
    });

    test('galat sementara (5xx, jaringan) TIDAK ditandai ditolak', () async {
      for (final galat in <Object>[
        const ApiException('boom', status: 500),
        const ApiException('boom', status: 503),
        const ApiException('lambat', status: 408),
        const ApiException('kebanyakan', status: 429),
        const KoneksiException('Server nggak nyaut. Coba lagi sebentar.'),
      ]) {
        final (simpanan, _, hasil) = await _tolak(galat);

        expect(hasil.ditolak, 0);
        final d = (await simpanan.daftar(_userId)).single;
        expect(d.status, StatusDrafLokal.belumTersinkron);
        expect(d.pesan, isNull);
      }
    });
  });

  group('layar Perhitungan: sesi hilang dari server', () {
    testWidgets('periksa dijawab 404: kalimat ramah, tanpa teks Eloquent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 4400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              InMemoryTokenStorage('mock-token-1'),
            ),
            authServiceProvider.overrideWithValue(MockAuthService()),
            perhitunganServiceProvider.overrideWithValue(_PeriksaTidakAda()),
            historyServiceProvider.overrideWithValue(MockHistoryService()),
            standardServiceProvider.overrideWithValue(MockStandardService()),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PerhitunganScreen(
              calibrationId: 25,
              statusSesi: CalibrationStatus.menungguApproval,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sesi ini sudah tidak ada di server. Mungkin diarsipkan atau '
          'dihapus admin.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No query results'), findsNothing);
    });
  });
}
