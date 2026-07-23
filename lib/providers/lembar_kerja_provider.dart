import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lembar_kerja.dart';
import '../models/lembar_kerja_submission.dart';
import '../models/room.dart';
import '../services/lembar_kerja_service.dart';
import '../services/room_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final lembarKerjaServiceProvider = Provider<LembarKerjaService>(
  (ref) => ApiLembarKerjaService(ref.watch(apiClientProvider)),
);

final roomServiceProvider = Provider<RoomService>(
  (ref) => ApiRoomService(ref.watch(apiClientProvider)),
);

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Bentuk formulir lembar kerja. Di-`watch` ke [authProvider] supaya ganti
/// akun (teknisi → admin) ngambil bentuk yang beda — bukan nyisain formulir
/// punya role sebelumnya.
final lembarKerjaProvider = FutureProvider<LembarKerja>((ref) async {
  ref.watch(authProvider);
  final token = await _token(ref);
  return ref.read(lembarKerjaServiceProvider).ambilBentuk(token);
}, retry: (retryCount, error) => null);

final roomListProvider = FutureProvider<List<Room>>((ref) async {
  final token = await _token(ref);
  return ref.read(roomServiceProvider).daftar(token);
}, retry: (retryCount, error) => null);

/// Hasil submit lembar kerja — dibedain dari sekadar id supaya layar bisa
/// bilang "tersimpan sebagai draft" vs "terkirim ke admin" tanpa nebak.
class HasilKirimLembarKerja {
  const HasilKirimLembarKerja({required this.id, required this.draft});

  final int id;
  final bool draft;
}

/// Nembak `POST`/`PUT /api/calibrations` sekali, nggak nyimpen daftar.
class KirimLembarKerjaController
    extends Notifier<AsyncValue<HasilKirimLembarKerja?>> {
  @override
  AsyncValue<HasilKirimLembarKerja?> build() => const AsyncValue.data(null);

  /// [sesiId] null = sesi baru (`POST`), keisi = lanjut draft / perbaiki yang
  /// dikembalikan admin (`PUT`).
  ///
  /// Balikin null kalau gagal — pesan errornya dibaca layar dari `state`.
  Future<HasilKirimLembarKerja?> kirim(
    LembarKerjaSubmission isian, {
    int? sesiId,
  }) async {
    state = const AsyncValue.loading();

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      state = AsyncValue.error(const TokenHilangException(), StackTrace.current);
      return null;
    }

    try {
      final service = ref.read(lembarKerjaServiceProvider);
      final id = sesiId == null
          ? await service.kirim(token, isian)
          : await service.perbarui(token, sesiId, isian);

      final hasil = HasilKirimLembarKerja(
        id: id,
        draft: isian.simpanSebagaiDraft,
      );
      state = AsyncValue.data(hasil);
      return hasil;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final kirimLembarKerjaProvider =
    NotifierProvider<
      KirimLembarKerjaController,
      AsyncValue<HasilKirimLembarKerja?>
    >(KirimLembarKerjaController.new);
