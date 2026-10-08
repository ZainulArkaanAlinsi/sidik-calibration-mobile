import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/calibration_detail.dart';
import '../models/calibration_history_item.dart';
import '../services/approval_service.dart';
import '../services/history_service.dart';
import '../services/pdf_downloader.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'riwayat_persetujuan_provider.dart';
import 'riwayat_tersembunyi_provider.dart';

/// `GET /api/calibrations` live sejak 14 Jul (`docs/kontrak-api.md` §4) —
/// beda sama Notifikasi, ini nembak API asli.
final historyServiceProvider = Provider<HistoryService>((ref) {
  if (AppConfig.useMock) return MockHistoryService();
  return ApiHistoryService(ref.watch(apiClientProvider));
});

/// Live — dicek langsung ke `CalibrationController`/`CertificateController`
/// di repo `sidik-calibration-api` (18 Jul). `approve`/`reject`/`retry`
/// cocok persis sama yang mobile tulis di sini.
final approvalServiceProvider = Provider<ApprovalService>((ref) {
  if (AppConfig.useMock) return MockApprovalService();
  return ApiApprovalService(ref.watch(apiClientProvider));
});

final pdfDownloaderProvider = Provider<PdfDownloader>((ref) => HttpPdfDownloader());

final historyProvider =
    AsyncNotifierProvider<HistoryController, List<CalibrationHistoryItem>>(
      HistoryController.new,
      retry: (retryCount, error) => null,
    );

class HistoryController extends AsyncNotifier<List<CalibrationHistoryItem>> {
  @override
  Future<List<CalibrationHistoryItem>> build() async {
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const TokenHilangException();
    }

    return ref.read(historyServiceProvider).ambilRiwayat(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Approve satu sesi. Optimistic: status berubah duluan di UI, baru
  /// nembak server — kalau gagal dibalikin ke semula.
  Future<void> approve(int id, {bool abaikanPeringatan = false}) async {
    final sebelum = state.value;
    if (sebelum == null) return;

    state = AsyncValue.data([
      for (final item in sebelum)
        if (item.id == id)
          item.copyWith(status: CalibrationStatus.disetujui)
        else
          item,
    ]);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    try {
      final certificateId = await ref
          .read(approvalServiceProvider)
          .approve(token, id, abaikanPeringatan: abaikanPeringatan);
      // Riwayat persetujuan sesi ini bertambah satu peristiwa — buang yang
      // tersimpan supaya dibuka berikutnya tidak basi (tinjauan 6 Okt 2026).
      ref.invalidate(riwayatPersetujuanProvider(id));
      final terkini = state.value;
      if (terkini == null) return;
      state = AsyncValue.data([
        for (final item in terkini)
          if (item.id == id)
            item.copyWith(certificateId: certificateId)
          else
            item,
      ]);
    } catch (_) {
      state = AsyncValue.data(sebelum);
      rethrow;
    }
  }

  /// Sembunyikan satu sesi dari Riwayat akun ini. Datanya TIDAK dihapus —
  /// lihat `RiwayatTersembunyiService`.
  ///
  /// Optimistic kayak [approve]: barisnya ilang duluan dari layar, baru nembak
  /// server. Gagal → penandanya dibalikin dan galatnya dilempar ke layar.
  Future<void> sembunyikan(int id) => _aturTersembunyi(id, tersembunyi: true);

  /// Kebalikan [sembunyikan] — dipakai tombol "Urungkan" dan "Tampilkan lagi".
  Future<void> tampilkanLagi(int id) =>
      _aturTersembunyi(id, tersembunyi: false);

  Future<void> _aturTersembunyi(int id, {required bool tersembunyi}) async {
    final baris = state.value?.where((e) => e.id == id).firstOrNull;
    if (baris == null) return;
    final sebelumnya = baris.tersembunyi;

    // Token dibaca SEBELUM layarnya diubah. Kebalikannya ninggalin baris yang
    // kelihatan sudah disembunyikan padahal server nggak pernah dihubungi.
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    _tandai(id, tersembunyi);

    try {
      final service = ref.read(riwayatTersembunyiServiceProvider);
      final kataServer = tersembunyi
          ? await service.sembunyikan(token, id)
          : await service.tampilkanLagi(token, id);
      // Jawaban server yang menang — ditulis ulang walau sama dengan yang
      // diminta: daftar bisa saja ditarik ulang (realtime/resume) selagi
      // permintaan ini jalan, dan tarikan itu membawa penanda yang basi.
      _tandai(id, kataServer);
    } catch (_) {
      // Yang dibalikin cuma penanda baris INI, bukan seluruh daftar dari
      // salinan lama: kalau dua baris disembunyikan beruntun dan yang pertama
      // gagal, yang kedua nggak boleh ikut nongol lagi.
      _tandai(id, sebelumnya);
      rethrow;
    }
  }

  void _tandai(int id, bool tersembunyi) {
    final terkini = state.value;
    if (terkini == null) return;
    state = AsyncValue.data([
      for (final item in terkini)
        if (item.id == id) item.copyWith(tersembunyi: tersembunyi) else item,
    ]);
  }

  /// Reject satu sesi dengan catatan revisi. Nunggu server (bukan
  /// optimistic) — beda sama approve, penolakan butuh alasan yang harus
  /// tervalidasi (nggak boleh kosong) sebelum status berubah di UI.
  Future<void> reject(int id, String catatanRevisi) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref
        .read(approvalServiceProvider)
        .reject(token, id, catatanRevisi);
    ref.invalidate(riwayatPersetujuanProvider(id));

    final sebelum = state.value;
    if (sebelum == null) return;

    state = AsyncValue.data([
      for (final item in sebelum)
        if (item.id == id)
          item.copyWith(
            status: CalibrationStatus.perluRevisi,
            catatanRevisi: catatanRevisi,
          )
        else
          item,
    ]);
  }
}

/// Detail satu sesi kalibrasi — dibuka dari kartu Riwayat (mana pun
/// statusnya), nampilin breakdown per titik ukur kalau udah dihitung backend.
final calibrationDetailProvider =
    FutureProvider.family<CalibrationDetail, int>((ref, id) async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref.read(historyServiceProvider).ambilDetail(token, id);
    }, retry: (retryCount, error) => null);

/// Antrean approval admin — semua kiriman dari semua teknisi
/// (`GET /api/calibrations?status=menunggu_approval`).
///
/// Dipisah dari [historyProvider]: dua pertanyaan yang
/// beda ("kerjaan saya" vs "apa yang nunggu saya periksa"), dan admin bolak
/// balik antara keduanya.
final antreanApprovalProvider =
    AsyncNotifierProvider<AntreanApprovalController, List<CalibrationHistoryItem>>(
      AntreanApprovalController.new,
      retry: (retryCount, error) => null,
    );

class AntreanApprovalController
    extends AsyncNotifier<List<CalibrationHistoryItem>> {
  @override
  Future<List<CalibrationHistoryItem>> build() async {
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(historyServiceProvider).ambilAntreanApproval(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Draf teknisi — lembar yang disimpen setengah jadi
/// (`GET /api/calibrations?status=draft`).
///
/// Dipisah dari [historyProvider] & [antreanApprovalProvider] dengan alasan
/// yang sama kayak keduanya dipisah: tiga pertanyaan yang beda ("apa yang
/// pernah saya kerjakan" · "apa yang nunggu saya periksa" · "lembar mana yang
/// saya tinggal setengah jadi"), dan yang ketiga dibuka paling sering justru
/// sama teknisi yang lagi berdiri di depan alat.
///
/// **Wajib di-`invalidate` sesudah lembar kerja berhasil disimpen** — lihat
/// [KirimLembarKerjaController.kirim] & `_kirimMatriks` di
/// `lembar_kerja_screen.dart`. Tanpa itu draf yang barusan disimpen nggak
/// nongol sampai layarnya ditarik-segarkan, dan teknisi ngira simpanannya
/// nggak kesimpen.
final drafProvider =
    AsyncNotifierProvider<DrafController, List<CalibrationHistoryItem>>(
      DrafController.new,
      retry: (retryCount, error) => null,
    );

class DrafController extends AsyncNotifier<List<CalibrationHistoryItem>> {
  @override
  Future<List<CalibrationHistoryItem>> build() async {
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref.read(historyServiceProvider).ambilDraf(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
