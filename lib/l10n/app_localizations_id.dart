// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTagline => 'Manajemen Kalibrasi Presisi';

  @override
  String get loginIdentifierLabel => 'ID Pegawai / Email';

  @override
  String get loginIdentifierHint => 'ASM-0001 atau nama@pt-sidik.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPasswordLink => 'Lupa Password?';

  @override
  String get loginSubmit => 'MASUK';

  @override
  String get loginNoAccount => 'Belum punya akun?';

  @override
  String get loginRegisterLink => 'Daftar';

  @override
  String get loginIdentifierRequired => 'ID pegawai atau email wajib diisi.';

  @override
  String get passwordRequired => 'Password wajib diisi.';

  @override
  String get errorNoConnection => 'Nggak bisa nyambung ke server. Coba lagi.';

  @override
  String get registerTitle => 'Daftar Akun';

  @override
  String get registerSubtitle => 'Buat profil teknisi kamu';

  @override
  String get nameLabel => 'Nama Lengkap';

  @override
  String get nameHint => 'mis. Andi Pratama';

  @override
  String get employeeIdLabel => 'ID Pegawai';

  @override
  String get departmentLabel => 'Departemen';

  @override
  String get departmentHint => 'Pilih departemen';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'nama@pt-sidik.com';

  @override
  String get passwordHelper => 'Minimal 8 karakter';

  @override
  String get registerSubmit => 'DAFTAR';

  @override
  String get registerHaveAccount => 'Sudah punya akun?';

  @override
  String get registerLoginLink => 'Masuk';

  @override
  String get nameRequired => 'Nama wajib diisi.';

  @override
  String get employeeIdRequired => 'ID pegawai wajib diisi.';

  @override
  String get departmentRequired => 'Pilih departemen dulu.';

  @override
  String get emailRequired => 'Email wajib diisi.';

  @override
  String get emailInvalid => 'Format email nggak valid.';

  @override
  String get passwordTooShort => 'Password minimal 8 karakter.';

  @override
  String get registerSuccessTitle => 'Pendaftaran terkirim';

  @override
  String get registerSuccessBody =>
      'Akun kamu masih menunggu persetujuan admin. Kamu belum bisa masuk sampai admin nyetujuin dan nentuin role kamu.\n\nHubungi admin kalau kelamaan nggak ada kabar.';

  @override
  String get registerSuccessDismiss => 'MENGERTI';

  @override
  String get forgotTitle => 'Lupa Password';

  @override
  String get forgotSubtitle => 'Kami kirim link reset ke email kamu';

  @override
  String get forgotBody =>
      'Masukin email yang kamu pakai waktu daftar. Reset password lewat email, bukan lewat ID pegawai — biar yang bisa ganti password cuma orang yang megang emailnya.';

  @override
  String get forgotSubmit => 'KIRIM LINK RESET';

  @override
  String get backToLogin => 'Balik ke Login';

  @override
  String get forgotSuccessTitle => 'Link reset terkirim';

  @override
  String forgotSuccessBody(String email) {
    return 'Kami udah kirim link reset password ke $email.\n\nCek juga folder spam kalau nggak nemu. Link-nya berlaku terbatas, jadi jangan kelamaan.';
  }

  @override
  String get backToLoginCaps => 'BALIK KE LOGIN';

  @override
  String get languageLabel => 'Bahasa';
}
