import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status onboarding, disimpan lokal per akun **di perangkat ini**. Nggak
/// nyentuh profil atau data backend: dia cuma nentuin apakah panduan tiga
/// layar itu perlu muncul.
class StatusOnboarding {
  const StatusOnboarding({required this.selesai, required this.simpananJalan});

  /// Id user yang udah pernah nyelesaiin panduan di perangkat ini.
  final Set<int> selesai;

  /// Apakah penyimpanan lokalnya beneran bisa dipakai.
  ///
  /// Kalau `false`, panduannya **dilewati**, bukan ditampilin. Alasannya:
  /// tanpa penyimpanan, "udah selesai" nggak akan pernah kecatat — jadi
  /// pilihannya bukan antara "tampil sekali" dan "nggak tampil", tapi antara
  /// "TIAP KALI app dibuka nongol lagi" dan "nggak tampil". Ngadang orang
  /// masuk kerja tiap pagi gara-gara storage-nya rewel itu ongkos yang jauh
  /// lebih mahal daripada panduan yang kelewat.
  final bool simpananJalan;

  bool perluTampil(int userId) => simpananJalan && !selesai.contains(userId);
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, StatusOnboarding>(
      OnboardingNotifier.new,
    );

class OnboardingNotifier extends AsyncNotifier<StatusOnboarding> {
  static const _key = 'onboarding_completed_user_ids_v1';

  @override
  Future<StatusOnboarding> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StatusOnboarding(
        selesai:
            prefs
                .getStringList(_key)
                ?.map(int.tryParse)
                .whereType<int>()
                .toSet() ??
            <int>{},
        simpananJalan: true,
      );
    } catch (_) {
      return const StatusOnboarding(selesai: <int>{}, simpananJalan: false);
    }
  }

  Future<void> selesai(int userId) async {
    final sebelum = state.value;
    final sekarang = {...?sebelum?.selesai, userId};
    state = AsyncData(
      StatusOnboarding(
        selesai: sekarang,
        simpananJalan: sebelum?.simpananJalan ?? true,
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        sekarang.map((id) => '$id').toList(growable: false),
      );
    } catch (_) {
      // Status sesi udah berubah; gagal nyimpen paling banter bikin panduannya
      // nongol lagi lain kali — bukan alasan buat ngegagalin masuk app.
    }
  }
}
