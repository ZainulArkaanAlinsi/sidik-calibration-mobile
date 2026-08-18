import 'package:sidik_calibration/providers/onboarding_provider.dart';

/// Override buat tes lama yang nggak lagi nguji `OnboardingScreen` — bikin
/// akun tes langsung dianggap udah pernah lewat panduan, biar mereka nyampe
/// ke layar yang mereka uji, bukan nyangkut di onboarding.
///
/// `SharedPreferences` di test environment nggak throw (beda dari asumsi di
/// `OnboardingNotifier.build`), jadi tiap akun tes yang belum pernah nyimpen
/// status dianggap "akun baru" dan dilempar ke onboarding — nyangkutin semua
/// tes yang ngarepin langsung nyampe di app.
final lewatiOnboarding = onboardingProvider.overrideWith(
  _OnboardingLangsungSelesai.new,
);

class _OnboardingLangsungSelesai extends OnboardingNotifier {
  @override
  Future<StatusOnboarding> build() async =>
      const StatusOnboarding(selesai: <int>{}, simpananJalan: false);
}
