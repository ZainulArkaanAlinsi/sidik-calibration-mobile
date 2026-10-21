import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';

import 'status_server_service.dart';

final layananStatusServerProvider = Provider<LayananStatusServer>((ref) {
  if (AppConfig.useMock) return MockLayananStatusServer();
  return ApiLayananStatusServer(ref.watch(apiClientProvider));
});

/// Jeda tarikan ulang status server untuk bilah status.
const jedaStatusServer = Duration(seconds: 60);

/// Status server untuk bilah status / menu akun (FR-STU-013).
///
/// `autoDispose`: cuma ditarik selama bilah status (atau menu akun) tampil.
/// Ditarik ulang tiap [jedaStatusServer] — cukup untuk "server ini hidup?",
/// tanpa menggempur `/health` yang publik dan dibatasi per IP. Ini BUKAN
/// pendeteksi offline (pita offline ST-90 milik ST-T-016).
///
/// `retry: null`: galat = jawaban ("tidak tersambung"), bukan alasan untuk
/// menembak berulang di luar jadwal.
final statusServerProvider = FutureProvider.autoDispose<StatusServer>((
  ref,
) async {
  final jadwal = Timer(jedaStatusServer, ref.invalidateSelf);
  ref.onDispose(jadwal.cancel);

  return ref.read(layananStatusServerProvider).ambil();
}, retry: (_, _) => null);
