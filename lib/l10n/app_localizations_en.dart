// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Precision Calibration Management';

  @override
  String get loginIdentifierLabel => 'Employee ID / Email';

  @override
  String get loginIdentifierHint => 'ASM-0001 or name@pt-sidik.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPasswordLink => 'Forgot Password?';

  @override
  String get loginSubmit => 'SIGN IN';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginRegisterLink => 'Register';

  @override
  String get loginIdentifierRequired => 'Employee ID or email is required.';

  @override
  String get passwordRequired => 'Password is required.';

  @override
  String get errorNoConnection => 'Can\'t reach the server. Please try again.';

  @override
  String get registerTitle => 'Register Account';

  @override
  String get registerSubtitle => 'Create your technician profile';

  @override
  String get nameLabel => 'Full Name';

  @override
  String get nameHint => 'e.g. Andi Pratama';

  @override
  String get employeeIdLabel => 'Employee ID';

  @override
  String get departmentLabel => 'Department';

  @override
  String get departmentHint => 'Select department';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'name@pt-sidik.com';

  @override
  String get passwordHelper => 'At least 8 characters';

  @override
  String get registerSubmit => 'REGISTER';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerLoginLink => 'Log in';

  @override
  String get nameRequired => 'Name is required.';

  @override
  String get employeeIdRequired => 'Employee ID is required.';

  @override
  String get departmentRequired => 'Please select a department.';

  @override
  String get emailRequired => 'Email is required.';

  @override
  String get emailInvalid => 'Invalid email format.';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters.';

  @override
  String get registerSuccessTitle => 'Registration submitted';

  @override
  String get registerSuccessBody =>
      'Your account is still awaiting admin approval. You can\'t sign in until an admin approves it and assigns your role.\n\nContact an admin if you don\'t hear back for a while.';

  @override
  String get registerSuccessDismiss => 'GOT IT';

  @override
  String get forgotTitle => 'Forgot Password';

  @override
  String get forgotSubtitle => 'We\'ll send a reset link to your email';

  @override
  String get forgotBody =>
      'Enter the email you used to register. Password reset goes through email, not employee ID — so only whoever holds the email can change the password.';

  @override
  String get forgotSubmit => 'SEND RESET LINK';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get forgotSuccessTitle => 'Reset link sent';

  @override
  String forgotSuccessBody(String email) {
    return 'We\'ve sent a password reset link to $email.\n\nCheck your spam folder if you can\'t find it. The link is valid for a limited time, so don\'t wait too long.';
  }

  @override
  String get backToLoginCaps => 'BACK TO LOGIN';

  @override
  String get languageLabel => 'Language';
}
