import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/autoclave_hasil.dart';
import '../services/autoclave_service.dart';
import 'auth_provider.dart';

final autoclaveServiceProvider = Provider<AutoclaveService>((ref) {
  return ApiAutoclaveService(ref.watch(apiClientProvider));
});

/// Keadaan panel hasil Autoklaf.
///
/// Bukan `AsyncValue`: hasil terakhir tetap kepegang selama permintaan
/// berikutnya jalan — sama alasannya kayak [StatusPratinjau] di
/// `lembar_kerja_provider`: teknisi ngutak-ngatik angka, panel nggak boleh
/// kedip kosong tiap kali "Hitung" ditekan.
class StatusAutoclave {
  const StatusAutoclave({this.hasil, this.menghitung = false, this.gagal});

  final AutoclaveHasil? hasil;
  final bool menghitung;
  final Object? gagal;
}

/// Olah data Autoklaf (`POST /calibrations/autoclave/preview`). Bukan jalur
/// kirim — gagalnya cuma dikabarin di panel, nggak nahan apa pun.
class AutoclaveController extends Notifier<StatusAutoclave> {
  @override
  StatusAutoclave build() => const StatusAutoclave();

  int _terakhir = 0;

  Future<void> hitung(Map<String, dynamic> payload) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final nomor = ++_terakhir;
    state = StatusAutoclave(hasil: state.hasil, menghitung: true);

    try {
      final hasil =
          await ref.read(autoclaveServiceProvider).pratinjau(token, payload);
      if (nomor != _terakhir) return;
      state = StatusAutoclave(hasil: hasil);
    } catch (e) {
      if (nomor != _terakhir) return;
      state = StatusAutoclave(hasil: state.hasil, gagal: e);
    }
  }
}

final autoclavePratinjauProvider =
    NotifierProvider<AutoclaveController, StatusAutoclave>(
  AutoclaveController.new,
);
