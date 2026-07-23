import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/calibration_detail.dart';
import '../models/calibration_history_item.dart';
import '../services/approval_service.dart';
import '../services/history_service.dart';
import '../services/pdf_downloader.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// `GET /api/calibrations` live sejak 14 Jul (`docs/kontrak-api.md` §4) —
/// beda sama Notifikasi, ini nembak API asli.
final historyServiceProvider = Provider<HistoryService>((ref) {
  if (AppConfig.useMock) return MockHistoryService();
  return ApiHistoryService(ref.watch(apiClientProvider));
});

/// Live — dicek langsung ke `CalibrationController`/`CertificateController`
/// di repo `sidik-calibration-api` (18 Jul). `approve`/`reject`/`retry`
/// cocok persis sama yang mobile tulis di sini.
final approvalServiceProvider = Provider<ApprovalService>(
  (ref) => ApiApprovalService(ref.watch(apiClientProvider)),
);

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
  Future<void> approve(int id) async {
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
          .approve(token, id);
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

  /// Reject satu sesi dengan catatan revisi. Nunggu server (bukan
  /// optimistic) — beda sama approve, penolakan butuh alasan yang harus
  /// tervalidasi (nggak boleh kosong) sebelum status berubah di UI.
  Future<void> reject(int id, String catatanRevisi) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    await ref
        .read(approvalServiceProvider)
        .reject(token, id, catatanRevisi);

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
/// Dipisah dari [historyProvider] yang pakai `mine=true`: dua pertanyaan yang
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
