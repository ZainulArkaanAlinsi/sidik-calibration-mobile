import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Draf yang barusan disimpen harus langsung nongol di layar Draf.
///
/// **Sebelum ini invalidasinya NOL.** Teknisi mencet SIMPAN DRAF, lembarnya
/// ketutup, dia buka layar Draf — dan drafnya nggak ada di situ sampai
/// daftarnya ditarik-segarkan manual. Yang kebaca bukan "daftarnya basi", tapi
/// "simpanan saya nggak kesimpen": dua penjelasan yang sama masuk akal buat
/// orang yang lagi berdiri di depan alat, dan yang salah justru yang bikin dia
/// ngetik ulang semuanya.
///
/// Dijaga di level provider, bukan lewat layar: yang mesti bener itu jalur
/// simpannya, dan layar mana pun yang manggil `kirim()` — lembar kerja hari
/// ini, apa pun besok — dapat perilaku yang sama tanpa harus inget-inget.
class _ServisDraf implements HistoryService {
  int tarikan = 0;

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) async {
    tarikan++;
    return const [];
  }

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async =>
      const [];

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => const [];

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) =>
      MockHistoryService().ambilDetail(token, id);

  @override
  Future<CalibrationDetail> verifikasiPembacaan(String token, int id) =>
      MockHistoryService().verifikasiPembacaan(token, id);
}

Future<void> _kirim(ProviderContainer container, {required bool draft}) async {
  await container
      .read(kirimLembarKerjaProvider.notifier)
      .kirim(
        LembarKerjaSubmission(
          equipmentId: 7,
          clientRequestId: 'uji-${draft ? 'draf' : 'kirim'}',
          simpanSebagaiDraft: draft,
        ),
      );
}

void main() {
  late _ServisDraf servis;
  late ProviderContainer container;

  setUp(() async {
    servis = _ServisDraf();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-2'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(servis),
        lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      ],
    );

    // `DrafController.build` nge-`watch` auth, jadi auth yang baru kelar itu
    // sendiri mancing satu tarikan lagi. Diselesein duluan biar tarikan yang
    // kehitung di bawah cuma yang datang dari invalidasi.
    await container.read(authProvider.future);
  });

  tearDown(() => container.dispose());

  test('simpan draf → daftar draf ditarik ulang', () async {
    await container.read(drafProvider.future);
    final sebelum = servis.tarikan;

    await _kirim(container, draft: true);

    await container.read(drafProvider.future);
    expect(servis.tarikan, greaterThan(sebelum));
  });

  /// Kirim-ke-admin juga ngubah daftar draf, cuma arahnya kebalik: barisnya
  /// KELUAR (statusnya pindah ke `menunggu_approval`). Kalau invalidasinya
  /// dijaga `if (draft)`, layar Draf nyisain lembar yang udah nggak ada di
  /// sana — dan teknisi mbukanya lagi ngira lembarnya belum kekirim.
  test('kirim ke admin → daftar draf ikut ditarik ulang', () async {
    await container.read(drafProvider.future);
    final sebelum = servis.tarikan;

    await _kirim(container, draft: false);

    await container.read(drafProvider.future);
    expect(servis.tarikan, greaterThan(sebelum));
  });
}
