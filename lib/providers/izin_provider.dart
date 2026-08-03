import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/izin.dart';
import '../models/user.dart';
import '../services/izin_service.dart';
import 'auth_provider.dart';

final izinServiceProvider = Provider<IzinService>((ref) {
  if (AppConfig.useMock) return MockIzinService();
  return ApiIzinService(ref.watch(apiClientProvider));
});

/// Matriks peran user yang lagi login (`GET /api/me/permissions`).
///
/// **Satu provider aja, bukan `FutureProvider` yang dibungkus `Provider`
/// turunan.** Pernah dibikin begitu dan hasilnya `setState() called during
/// build`: transisi loading→data-nya bikin provider turunannya kehitung ulang
/// di tengah build layar yang lagi mbaca dia. Layar mbaca `AsyncValue`-nya
/// langsung, dan itu memang cara yang aman.
final izinProvider = FutureProvider<Izin>((ref) async {
  // Ikut user yang lagi login: ganti akun → izinnya ditarik ulang.
  final user = ref.watch(authProvider).value;
  if (user == null) return Izin.kosong;

  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) return Izin.kosong;

  return ref.read(izinServiceProvider).ambil(token);
});

/// Jalan pintas buat layar: "boleh nggak, dengan cadangan aturan lama?"
///
/// Selama izinnya belum nyampe, nilainya [Izin.kosong] dan pertanyaannya
/// dijawab pakai [cadangan]. Layar **nggak nunggu** — kalau ditunggu, tiap
/// layar bakal ada kedipan spinner cuma buat mutusin satu tombol muncul apa
/// nggak, dan itu kerasa lebih rusak daripada tombol yang nongol sepersekian
/// detik belakangan.
///
/// ```dart
/// final bolehTambah = ref.bolehkah(
///   NamaIzin.alatTambah,
///   cadangan: user?.role.bisaMenulis ?? false,
/// );
/// ```
extension IzinRef on WidgetRef {
  bool bolehkah(String izin, {required bool cadangan}) {
    final sekarang = watch(izinProvider).value ?? Izin.kosong;
    return sekarang.bolehkah(izin, cadangan: cadangan);
  }
}

/// Cadangan siap pakai buat pola yang paling sering. Dipisah biar nama
/// aturannya kebaca di tempat panggil, bukan `?? false` yang nggak jelas
/// asalnya.
extension CadanganPeran on UserRole? {
  bool get adminSaja => this?.isAdmin ?? false;
  bool get bisaMenulis => this?.bisaInput ?? false;
}
