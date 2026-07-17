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
  String get forgotSubtitle => 'Verify your email, then set a new password';

  @override
  String get forgotBody =>
      'Enter the email you used to register. If it matches, you can create a new password right here.';

  @override
  String get forgotSubmit => 'CONTINUE';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get resetNewPassTitle => 'Set New Password';

  @override
  String resetNewPassSubtitle(String email) {
    return 'Create a new password for $email';
  }

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmPasswordLabel => 'Confirm New Password';

  @override
  String get passwordMismatch => 'Passwords don\'t match.';

  @override
  String get resetSubmit => 'SAVE NEW PASSWORD';

  @override
  String get resetDoneTitle => 'Password changed';

  @override
  String get resetDoneBody =>
      'Your password has been updated. Sign in with your new password now.';

  @override
  String get backToLoginCaps => 'BACK TO LOGIN';

  @override
  String get languageLabel => 'Language';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navEquipment => 'Equipment';

  @override
  String get navHistory => 'History';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navProfile => 'Profile';

  @override
  String get dashGreeting => 'Hello,';

  @override
  String get dashSummaryOrg => 'Organization summary';

  @override
  String get dashSummaryYours => 'Your summary';

  @override
  String get dashTotalDevices => 'Total devices';

  @override
  String get dashOverdue => 'Overdue';

  @override
  String get dashPendingApproval => 'Pending approval';

  @override
  String get dashCalibrationDraft => 'Calibration drafts';

  @override
  String get dashCertsThisMonth => 'Certificates this month';

  @override
  String get dashQuickActions => 'Quick actions';

  @override
  String get dashStartCalibration => 'START CALIBRATION';

  @override
  String get dashAddDevice => 'ADD DEVICE';

  @override
  String get dashRetry => 'TRY AGAIN';

  @override
  String get dashSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get dashLoadFailed => 'Failed to load the dashboard.';

  @override
  String dashOverdueWarning(int count) {
    return '$count device(s) past their calibration due date. Measurements from overdue devices can\'t be relied upon.';
  }

  @override
  String get dashEmptyTitle => 'No data yet';

  @override
  String get dashEmptyBodyInput =>
      'No devices registered yet. Start by adding your first measuring device.';

  @override
  String get dashEmptyBodyReadonly => 'There\'s nothing to show yet.';

  @override
  String get snackCalibInputSoon => 'Calibration input is planned for week 4.';

  @override
  String get snackAddDeviceSoon => 'Adding devices is planned for week 3.';

  @override
  String get profAccountInfo => 'Account Info';

  @override
  String get profRoleLabel => 'Role';

  @override
  String get profChangePhotoSheet => 'Profile Photo';

  @override
  String get profChooseGallery => 'Choose from gallery';

  @override
  String get profTakePhoto => 'Take a photo';

  @override
  String get profRemovePhoto => 'Remove photo';

  @override
  String get profPhotoUpdated => 'Profile photo updated.';

  @override
  String get profPhotoRemoved => 'Profile photo removed.';

  @override
  String get profPhotoFailed => 'Couldn\'t pick the photo. Try again.';

  @override
  String get profAdminMenu => 'Admin Menu';

  @override
  String get profUserManagement => 'User Management';

  @override
  String get profUserManagementSub => 'Planned for phase 3';

  @override
  String get profMasterData => 'Company & Customer Master Data';

  @override
  String get profMasterDataSub => 'Planned for week 2';

  @override
  String get profDesignSystem => 'Design System';

  @override
  String get profDesignSystemSub => 'Color, typography & component catalog';

  @override
  String get profAppInfo => 'App Info';

  @override
  String get profEnvironment => 'Environment';

  @override
  String get profApiBaseUrl => 'API base URL';

  @override
  String get profSecurity => 'Security';

  @override
  String get profLogoutAll => 'Sign out of all devices';

  @override
  String get profLogoutAllSub =>
      'For when your phone is lost. Every session is revoked — other phones, tablets, including this one.';

  @override
  String get profLogout => 'Sign out';

  @override
  String get profLogoutAllConfirmTitle => 'Sign out of all devices?';

  @override
  String get profLogoutAllConfirmBody =>
      'All your sessions will be revoked, including on this phone — you\'ll be asked to sign in again.\n\nUse this if your phone is lost or stolen.';

  @override
  String get profCancel => 'Cancel';

  @override
  String get profRevokeAll => 'Revoke all sessions';

  @override
  String profSessionsRevoked(int count) {
    return '$count session(s) revoked. Please sign in again.';
  }

  @override
  String get profAllSessionsRevoked =>
      'All sessions revoked. Please sign in again.';

  @override
  String profRevokeFailed(String message) {
    return 'Couldn\'t revoke sessions: $message';
  }

  @override
  String get equipmentSearchHint => 'Search device name or serial number';

  @override
  String get equipmentCategoryAll => 'All Categories';

  @override
  String get equipmentStatusAll => 'All Statuses';

  @override
  String get equipmentLoadFailed => 'Couldn\'t load the device list.';

  @override
  String get equipmentNoResultsTitle => 'No matches';

  @override
  String get equipmentNoResultsBody => 'Try a different keyword or filter.';

  @override
  String get equipmentDueDatePrefix => 'Due';

  @override
  String get equipmentFormTitleAdd => 'Add Device';

  @override
  String get equipmentFormTitleEdit => 'Edit Device';

  @override
  String get equipmentSectionIdentity => 'Device Identity';

  @override
  String get equipmentSectionAdditional => 'Additional Details (Optional)';

  @override
  String get equipmentNameLabel => 'Device Name';

  @override
  String get equipmentNameHint => 'e.g. Mitutoyo Caliper';

  @override
  String get equipmentNameRequired => 'Device name is required.';

  @override
  String get equipmentSerialLabel => 'Serial Number';

  @override
  String get equipmentSerialHint => 'e.g. MT-500-196-30';

  @override
  String get equipmentSerialRequired => 'Serial number is required.';

  @override
  String get equipmentBrandLabel => 'Brand';

  @override
  String get equipmentBrandHint => 'e.g. Mitutoyo';

  @override
  String get equipmentBrandRequired => 'Brand is required.';

  @override
  String get equipmentCategoryLabel => 'Category';

  @override
  String get equipmentCategoryRequired => 'Pick a category first.';

  @override
  String get equipmentStatusLabel => 'Status';

  @override
  String get equipmentStatusActive => 'Active';

  @override
  String get equipmentStatusInactive => 'Inactive';

  @override
  String get equipmentToleranceLabel => 'Tolerance';

  @override
  String get equipmentToleranceHint => 'optional';

  @override
  String get equipmentCustomerLabel => 'Customer';

  @override
  String get equipmentCustomerHint => 'Search customer';

  @override
  String get equipmentCustomerIdLabel => 'Customer ID (optional)';

  @override
  String get equipmentCustomerIdHelper =>
      'Only admins can search customers by name. Fill in the ID if you know it, or leave it blank for now.';

  @override
  String get equipmentCustomerNone => 'No customer yet';

  @override
  String get equipmentSubmitAdd => 'SAVE DEVICE';

  @override
  String get equipmentSubmitEdit => 'SAVE CHANGES';

  @override
  String get equipmentDelete => 'Delete Device';

  @override
  String get equipmentDeleteConfirmTitle => 'Delete this device?';

  @override
  String get equipmentDeleteConfirmBody =>
      'The device and its calibration history can\'t be recovered.';

  @override
  String get equipmentDeleteConfirmAction => 'DELETE';

  @override
  String get equipmentSaved => 'Device saved successfully.';

  @override
  String get equipmentDeleted => 'Device deleted successfully.';

  @override
  String equipmentSaveFailed(String message) {
    return 'Couldn\'t save: $message';
  }

  @override
  String equipmentDeleteFailed(String message) {
    return 'Couldn\'t delete: $message';
  }

  @override
  String get historyPlaceholderTitle => 'Calibration History';

  @override
  String get historyPlaceholderBody =>
      'History of calibration sessions & issued certificates. Planned for week 9.';

  @override
  String get notificationPlaceholderTitle => 'Notifications';

  @override
  String get notificationPlaceholderBody =>
      'Reminders for devices approaching their calibration due date. Planned for week 9.';
}
