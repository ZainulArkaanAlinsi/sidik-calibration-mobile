import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/lembar_kerja.dart';
import '../models/lembar_kerja_submission.dart';
import '../models/pratinjau_hitung.dart';
import '../models/room.dart';
import '../services/lembar_kerja_service.dart';
import '../services/room_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final lembarKerjaServiceProvider = Provider<LembarKerjaService>((ref) {
  if (AppConfig.useMock) return MockLembarKerjaService();
  return ApiLembarKerjaService(ref.watch(apiClientProvider));
});

final roomServiceProvider = Provider<RoomService>((ref) {
  if (AppConfig.useMock) return MockRoomService();
  return ApiRoomService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Kunci [lembarKerjaProvider]: jenis alat + berapa kotak pengulangan + ALAT
/// yang lagi dipilih.
///
/// Record, bukan String gabungan: ketiganya ikut jadi identitas cache, jadi
/// ganti jumlah kotak ATAU ganti alat otomatis ngambil bentuk baru tanpa perlu
/// invalidate manual — dan `ph_meter` 3 kotak nggak ketuker sama `ph_meter` 5
/// kotak.
///
/// `equipmentId` masuk kunci karena bentuknya beneran beda per alat, bukan cuma
/// isinya: Conductivity tanpa alat keluar 4 baris (dua varian titik tengah yang
/// saling ngunci), dengan alat keluar 3 baris dengan satuan ngikut resolusi alat
/// pelanggan.
typedef KunciLembarKerja = ({String profil, int? pengulangan, int? equipmentId});

/// Bentuk formulir lembar kerja per JENIS ALAT (`ph_meter` / `turbidimeter` /
/// `chlorine_meter`).
///
/// `pengulangan` = berapa KOTAK pengulangan yang digambar; `null` = bawaan
/// profilnya (5, ngikut form kertas). Ini murni tampilan — rumusnya selalu
/// ngikut berapa kotak yang beneran diisi.
///
/// Di-`watch` ke [authProvider] supaya ganti akun (teknisi → admin) ngambil
/// bentuk yang beda — bukan nyisain formulir punya role sebelumnya.
final lembarKerjaProvider =
    FutureProvider.family<LembarKerja, KunciLembarKerja>((ref, kunci) async {
      ref.watch(authProvider);
      final token = await _token(ref);
      return ref.read(lembarKerjaServiceProvider).ambilBentuk(
        token,
        profil: kunci.profil,
        pengulangan: kunci.pengulangan,
        equipmentId: kunci.equipmentId,
      );
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

/// Keadaan panel pratinjau.
///
/// Bukan `AsyncValue`: hasil terakhir WAJIB tetap kepegang selama permintaan
/// berikutnya jalan. Teknisi ngetik terus, jadi kalau tiap permintaan
/// ngosongin panelnya, angkanya kedip-kedip dan kebacanya kayak hasilnya ilang.
class StatusPratinjau {
  const StatusPratinjau({this.hasil, this.menghitung = false, this.gagal});

  /// Hitungan terakhir yang berhasil. Tetap ditahan waktu [menghitung] atau
  /// waktu permintaan terbaru [gagal].
  final PratinjauHitung? hasil;

  final bool menghitung;

  /// Kegagalan permintaan TERAKHIR. Cuma buat dikabarin kecil di panel —
  /// pratinjau gagal nggak nahan apa pun, dan angkanya tetap dihitung ulang
  /// backend waktu lembarnya beneran dikirim.
  final Object? gagal;
}

/// Hitungan sementara buat lembar yang lagi diisi (`POST /calibrations/preview`).
///
/// **Bukan jalur kirim.** Gagalnya nggak nahan apa pun dan nggak boleh bikin
/// layar merah: ini panel bantu supaya teknisi tau angkanya mendarat di mana
/// sebelum lembarnya kekunci di antrean approval.
class PratinjauController extends Notifier<StatusPratinjau> {
  @override
  StatusPratinjau build() => const StatusPratinjau();

  /// Nomor permintaan terakhir yang dikirim.
  ///
  /// Dipakai buang balasan yang KETINGGALAN: permintaan lama bisa nyampe
  /// sesudah yang baru dan nimpa layar dengan hitungan dari isian yang udah
  /// nggak ada. Debounce ngurangin peluangnya, nggak ngilangin.
  int _terakhir = 0;

  Future<void> hitung(LembarKerjaSubmission isian) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final nomor = ++_terakhir;
    state = StatusPratinjau(hasil: state.hasil, menghitung: true);

    try {
      final hasil = await ref
          .read(lembarKerjaServiceProvider)
          .pratinjau(token, isian);
      if (nomor != _terakhir) return;
      state = StatusPratinjau(hasil: hasil);
    } catch (e) {
      if (nomor != _terakhir) return;
      state = StatusPratinjau(hasil: state.hasil, gagal: e);
    }
  }
}

final pratinjauProvider =
    NotifierProvider<PratinjauController, StatusPratinjau>(
      PratinjauController.new,
    );

final kirimLembarKerjaProvider =
    NotifierProvider<
      KirimLembarKerjaController,
      AsyncValue<HasilKirimLembarKerja?>
    >(KirimLembarKerjaController.new);
