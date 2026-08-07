import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';

/// Penyimpan yang menunda — niru disk yang nggak instan.
class PenyimpanLambat implements PenyimpanMockStore {
  String? isi;
  int selesai = 0;

  @override
  Future<String?> baca() async => isi;

  @override
  Future<void> tulis(String data) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    isi = data;
    selesai++;
  }
}

/// Rantai paling dasar di app ini: teknisi ngirim, admin nerima.
///
/// Kelihatannya sepele, tapi dua bug nyata lolos di sini dan dua-duanya bikin
/// teknisi ngira kerjaannya ilang.
void main() {
  setUp(MockStore.instance.reset);
  tearDown(MockStore.instance.reset);

  test('KIRIM KE ADMIN -> nongol di antrean approval', () async {
    final lk = MockLembarKerjaService();
    final riwayat = MockHistoryService();
    final sebelum = (await riwayat.ambilAntreanApproval('t')).length;

    await lk.kirim(
      't',
      const LembarKerjaSubmission(
        equipmentId: 16,
        clientRequestId: 'x',
        simpanSebagaiDraft: false,
      ),
    );

    expect((await riwayat.ambilAntreanApproval('t')).length, sebelum + 1);
  });

  /// **Bug asli:** `tambahSesi` dulu SELALU nyetempel `menungguApproval`, apa
  /// pun tombolnya. Jadi draft yang belum siap ikut nongol di antrean admin,
  /// dan teknisi nggak punya cara mbedain mana yang beneran udah dikirim —
  /// dua-duanya kelihatan sama persis.
  test('SIMPAN SEBAGAI DRAFT tetap draft, jangan nyasar ke antrean', () async {
    final lk = MockLembarKerjaService();
    final riwayat = MockHistoryService();

    await lk.kirim(
      't',
      const LembarKerjaSubmission(
        equipmentId: 16,
        clientRequestId: 'y',
        simpanSebagaiDraft: true,
      ),
    );

    final sesi = MockStore.instance.sesi.first;
    expect(sesi.status, CalibrationStatus.draft);
    expect(
      (await riwayat.ambilAntreanApproval('t')).any((s) => s.id == sesi.id),
      isFalse,
    );
  });

  /// **Bug asli:** nyimpen ke disk itu fire-and-forget, jadi `kirim()` bisa
  /// balik "berhasil" sebelum sesinya mendarat. App ditutup persis sesudah
  /// kirim = sesinya ilang, dan gejalanya persis "harusnya udah kekirim, kok
  /// nggak ada".
  test('kirim baru bilang berhasil sesudah sesinya mendarat di disk', () async {
    final disk = PenyimpanLambat();
    await MockStore.instance.pulihkan(disk);

    await MockLembarKerjaService().kirim(
      't',
      const LembarKerjaSubmission(
        equipmentId: 16,
        clientRequestId: 'z',
        simpanSebagaiDraft: false,
      ),
    );

    // Nggak ada `pump`/`delay` tambahan di sini — kalau `kirim` balik duluan,
    // ini masih 0 dan test-nya merah.
    expect(disk.selesai, greaterThan(0));
    expect(disk.isi, contains('Chlorine Meter Hanna'));
  });
}
