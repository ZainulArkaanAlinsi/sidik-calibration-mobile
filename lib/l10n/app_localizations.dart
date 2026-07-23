import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Precision Calibration Management'**
  String get appTagline;

  /// No description provided for @loginIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee ID / Email'**
  String get loginIdentifierLabel;

  /// No description provided for @loginIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'ASM-0001 or name@pt-sidik.com'**
  String get loginIdentifierHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordLink;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get loginSubmit;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginNoAccount;

  /// No description provided for @loginRegisterLink.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginRegisterLink;

  /// No description provided for @loginIdentifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Employee ID or email is required.'**
  String get loginIdentifierRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get passwordRequired;

  /// No description provided for @errorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Please try again.'**
  String get errorNoConnection;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your technician profile'**
  String get registerSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Andi Pratama'**
  String get nameHint;

  /// No description provided for @employeeIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get employeeIdLabel;

  /// No description provided for @departmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get departmentLabel;

  /// No description provided for @departmentHint.
  ///
  /// In en, this message translates to:
  /// **'Select department'**
  String get departmentHint;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@pt-sidik.com'**
  String get emailHint;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelper;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get registerSubmit;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get registerHaveAccount;

  /// No description provided for @registerLoginLink.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get registerLoginLink;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get nameRequired;

  /// No description provided for @employeeIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Employee ID is required.'**
  String get employeeIdRequired;

  /// No description provided for @departmentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a department.'**
  String get departmentRequired;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get emailInvalid;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @registerSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration submitted'**
  String get registerSuccessTitle;

  /// No description provided for @registerSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is still awaiting admin approval. You can\'t sign in until an admin approves it and assigns your role.\n\nContact an admin if you don\'t hear back for a while.'**
  String get registerSuccessBody;

  /// No description provided for @registerSuccessDismiss.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get registerSuccessDismiss;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email, then set a new password'**
  String get forgotSubtitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you used to register. If it matches, you can create a new password right here.'**
  String get forgotBody;

  /// No description provided for @forgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get forgotSubmit;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @resetNewPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get resetNewPassTitle;

  /// No description provided for @resetNewPassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for {email}'**
  String resetNewPassSubtitle(String email);

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match.'**
  String get passwordMismatch;

  /// No description provided for @resetSubmit.
  ///
  /// In en, this message translates to:
  /// **'SAVE NEW PASSWORD'**
  String get resetSubmit;

  /// No description provided for @resetDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get resetDoneTitle;

  /// No description provided for @resetDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated. Sign in with your new password now.'**
  String get resetDoneBody;

  /// No description provided for @backToLoginCaps.
  ///
  /// In en, this message translates to:
  /// **'BACK TO LOGIN'**
  String get backToLoginCaps;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get navEquipment;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @dashGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get dashGreeting;

  /// No description provided for @dashTotalDevices.
  ///
  /// In en, this message translates to:
  /// **'Total devices'**
  String get dashTotalDevices;

  /// No description provided for @dashOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dashOverdue;

  /// No description provided for @dashPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get dashPendingApproval;

  /// No description provided for @dashCalibrationDraft.
  ///
  /// In en, this message translates to:
  /// **'Calibration drafts'**
  String get dashCalibrationDraft;

  /// No description provided for @dashCertsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Certificates this month'**
  String get dashCertsThisMonth;

  /// No description provided for @dashLabScope.
  ///
  /// In en, this message translates to:
  /// **'Lab-wide'**
  String get dashLabScope;

  /// No description provided for @dashTotalCerts.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get dashTotalCerts;

  /// No description provided for @dashCertsThisMonthSub.
  ///
  /// In en, this message translates to:
  /// **'{count} this month'**
  String dashCertsThisMonthSub(int count);

  /// No description provided for @dashCalibrationMine.
  ///
  /// In en, this message translates to:
  /// **'My calibrations'**
  String get dashCalibrationMine;

  /// No description provided for @dashCalibrationLab.
  ///
  /// In en, this message translates to:
  /// **'Lab calibrations'**
  String get dashCalibrationLab;

  /// No description provided for @dashTrendUp.
  ///
  /// In en, this message translates to:
  /// **'{count} more completed than last period'**
  String dashTrendUp(int count);

  /// No description provided for @dashTrendDown.
  ///
  /// In en, this message translates to:
  /// **'{count} fewer completed than last period'**
  String dashTrendDown(int count);

  /// No description provided for @dashTrendFlat.
  ///
  /// In en, this message translates to:
  /// **'Same as last period'**
  String get dashTrendFlat;

  /// No description provided for @dashQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get dashQuickActions;

  /// No description provided for @dashStartCalibration.
  ///
  /// In en, this message translates to:
  /// **'START CALIBRATION'**
  String get dashStartCalibration;

  /// No description provided for @dashAddDevice.
  ///
  /// In en, this message translates to:
  /// **'ADD DEVICE'**
  String get dashAddDevice;

  /// No description provided for @dashRetry.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get dashRetry;

  /// No description provided for @dashSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get dashSessionExpired;

  /// No description provided for @dashLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the dashboard.'**
  String get dashLoadFailed;

  /// No description provided for @dashOverdueWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} device(s) past their calibration due date. Measurements from overdue devices can\'t be relied upon.'**
  String dashOverdueWarning(int count);

  /// No description provided for @dashEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get dashEmptyTitle;

  /// No description provided for @dashEmptyBodyInput.
  ///
  /// In en, this message translates to:
  /// **'No devices registered yet. Start by adding your first measuring device.'**
  String get dashEmptyBodyInput;

  /// No description provided for @dashEmptyBodyReadonly.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing to show yet.'**
  String get dashEmptyBodyReadonly;

  /// No description provided for @snackCalibInputSoon.
  ///
  /// In en, this message translates to:
  /// **'Calibration input is planned for week 4.'**
  String get snackCalibInputSoon;

  /// No description provided for @profAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get profAccountInfo;

  /// No description provided for @profRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profRoleLabel;

  /// No description provided for @profChangePhotoSheet.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profChangePhotoSheet;

  /// No description provided for @profChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get profChooseGallery;

  /// No description provided for @profTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profTakePhoto;

  /// No description provided for @profRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profRemovePhoto;

  /// No description provided for @profPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get profPhotoUpdated;

  /// No description provided for @profPhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Profile photo removed.'**
  String get profPhotoRemoved;

  /// No description provided for @profPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t pick the photo. Try again.'**
  String get profPhotoFailed;

  /// No description provided for @profAdminMenu.
  ///
  /// In en, this message translates to:
  /// **'Admin Menu'**
  String get profAdminMenu;

  /// No description provided for @profUserManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get profUserManagement;

  /// No description provided for @profUserManagementSub.
  ///
  /// In en, this message translates to:
  /// **'Planned for phase 3'**
  String get profUserManagementSub;

  /// No description provided for @profOrgData.
  ///
  /// In en, this message translates to:
  /// **'Organization Data'**
  String get profOrgData;

  /// No description provided for @profOrgDataSub.
  ///
  /// In en, this message translates to:
  /// **'Name, address & accreditation no. printed on certificates'**
  String get profOrgDataSub;

  /// No description provided for @profCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get profCustomers;

  /// No description provided for @profCustomersSub.
  ///
  /// In en, this message translates to:
  /// **'Manage the lab\'s customer list'**
  String get profCustomersSub;

  /// No description provided for @profStandards.
  ///
  /// In en, this message translates to:
  /// **'Reference Standards'**
  String get profStandards;

  /// No description provided for @profStandardsSub.
  ///
  /// In en, this message translates to:
  /// **'Manage the lab\'s reference/standard equipment'**
  String get profStandardsSub;

  /// No description provided for @profArsip.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get profArsip;

  /// No description provided for @profArsipSub.
  ///
  /// In en, this message translates to:
  /// **'Company folders, instruments & certificate files'**
  String get profArsipSub;

  /// No description provided for @profDesignSystem.
  ///
  /// In en, this message translates to:
  /// **'Design System'**
  String get profDesignSystem;

  /// No description provided for @profDesignSystemSub.
  ///
  /// In en, this message translates to:
  /// **'Color, typography & component catalog'**
  String get profDesignSystemSub;

  /// No description provided for @profAppInfo.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get profAppInfo;

  /// No description provided for @profEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get profEnvironment;

  /// No description provided for @profApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get profApiBaseUrl;

  /// No description provided for @profSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profSecurity;

  /// No description provided for @profLogoutAll.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices'**
  String get profLogoutAll;

  /// No description provided for @profLogoutAllSub.
  ///
  /// In en, this message translates to:
  /// **'For when your phone is lost. Every session is revoked — other phones, tablets, including this one.'**
  String get profLogoutAllSub;

  /// No description provided for @profLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profLogout;

  /// No description provided for @profLogoutAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices?'**
  String get profLogoutAllConfirmTitle;

  /// No description provided for @profLogoutAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All your sessions will be revoked, including on this phone — you\'ll be asked to sign in again.\n\nUse this if your phone is lost or stolen.'**
  String get profLogoutAllConfirmBody;

  /// No description provided for @profCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profCancel;

  /// No description provided for @profRevokeAll.
  ///
  /// In en, this message translates to:
  /// **'Revoke all sessions'**
  String get profRevokeAll;

  /// No description provided for @profSessionsRevoked.
  ///
  /// In en, this message translates to:
  /// **'{count} session(s) revoked. Please sign in again.'**
  String profSessionsRevoked(int count);

  /// No description provided for @profAllSessionsRevoked.
  ///
  /// In en, this message translates to:
  /// **'All sessions revoked. Please sign in again.'**
  String get profAllSessionsRevoked;

  /// No description provided for @profRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t revoke sessions: {message}'**
  String profRevokeFailed(String message);

  /// No description provided for @equipLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the device list.'**
  String get equipLoadFailed;

  /// No description provided for @equipSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search device name'**
  String get equipSearchHint;

  /// No description provided for @equipFilterKategoriHint.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get equipFilterKategoriHint;

  /// No description provided for @equipFilterStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get equipFilterStatusHint;

  /// No description provided for @equipFilterSemua.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get equipFilterSemua;

  /// No description provided for @equipStatusAktif.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get equipStatusAktif;

  /// No description provided for @equipStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get equipStatusOverdue;

  /// No description provided for @equipStatusNonaktif.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get equipStatusNonaktif;

  /// No description provided for @equipEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No devices yet'**
  String get equipEmptyTitle;

  /// No description provided for @equipEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first device using the button below.'**
  String get equipEmptyBody;

  /// No description provided for @equipRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get equipRetry;

  /// No description provided for @equipAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD DEVICE'**
  String get equipAdd;

  /// No description provided for @equipEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit device'**
  String get equipEdit;

  /// No description provided for @equipMuatLebihBanyak.
  ///
  /// In en, this message translates to:
  /// **'LOAD MORE'**
  String get equipMuatLebihBanyak;

  /// No description provided for @equipDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete device?'**
  String get equipDeleteConfirmTitle;

  /// No description provided for @equipDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{nama}\" will be permanently deleted.'**
  String equipDeleteConfirmBody(String nama);

  /// No description provided for @equipDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {pesan}'**
  String equipDeleteFailed(String pesan);

  /// No description provided for @equipNamaAlat.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get equipNamaAlat;

  /// No description provided for @equipSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get equipSerialNumber;

  /// No description provided for @equipKategori.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get equipKategori;

  /// No description provided for @equipKategoriHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a device category'**
  String get equipKategoriHint;

  /// No description provided for @equipPelanggan.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get equipPelanggan;

  /// No description provided for @equipPelangganHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer'**
  String get equipPelangganHint;

  /// No description provided for @equipPelangganCariHint.
  ///
  /// In en, this message translates to:
  /// **'Search company name'**
  String get equipPelangganCariHint;

  /// No description provided for @equipPelangganGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the customer list.'**
  String get equipPelangganGagal;

  /// No description provided for @equipPelangganKosong.
  ///
  /// In en, this message translates to:
  /// **'No customer found.'**
  String get equipPelangganKosong;

  /// No description provided for @equipNamaAlatKemampuan.
  ///
  /// In en, this message translates to:
  /// **'Device Type (Calibration Capability)'**
  String get equipNamaAlatKemampuan;

  /// No description provided for @equipNamaAlatKemampuanHint.
  ///
  /// In en, this message translates to:
  /// **'Choose device type (optional, for accurate CMC)'**
  String get equipNamaAlatKemampuanHint;

  /// No description provided for @equipNamaAlatKemampuanKosong.
  ///
  /// In en, this message translates to:
  /// **'This category has no calibration capabilities yet'**
  String get equipNamaAlatKemampuanKosong;

  /// No description provided for @equipNamaAlatKemampuanGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load calibration capabilities.'**
  String get equipNamaAlatKemampuanGagal;

  /// No description provided for @equipCatatan.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get equipCatatan;

  /// No description provided for @equipMerk.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get equipMerk;

  /// No description provided for @equipModel.
  ///
  /// In en, this message translates to:
  /// **'Model/Type'**
  String get equipModel;

  /// No description provided for @equipNoIdentifikasi.
  ///
  /// In en, this message translates to:
  /// **'Identification no.'**
  String get equipNoIdentifikasi;

  /// No description provided for @equipRangeMin.
  ///
  /// In en, this message translates to:
  /// **'Range min.'**
  String get equipRangeMin;

  /// No description provided for @equipRangeMax.
  ///
  /// In en, this message translates to:
  /// **'Range max.'**
  String get equipRangeMax;

  /// No description provided for @equipSatuan.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get equipSatuan;

  /// No description provided for @equipResolusi.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get equipResolusi;

  /// No description provided for @equipToleransi.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get equipToleransi;

  /// No description provided for @equipToleransiWajib.
  ///
  /// In en, this message translates to:
  /// **'Tolerance is required.'**
  String get equipToleransiWajib;

  /// No description provided for @equipToleransiWajibHint.
  ///
  /// In en, this message translates to:
  /// **'A device without a tolerance can\'t be calibrated — there\'s no way to decide PASS/FAIL.'**
  String get equipToleransiWajibHint;

  /// No description provided for @equipLokasi.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get equipLokasi;

  /// No description provided for @equipStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get equipStatus;

  /// No description provided for @equipSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get equipSave;

  /// No description provided for @equipSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {pesan}'**
  String equipSaveFailed(String pesan);

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Completed calibration sessions will show up here.'**
  String get historyEmptyBody;

  /// No description provided for @historyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load history.'**
  String get historyLoadFailed;

  /// No description provided for @historySessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get historySessionExpired;

  /// No description provided for @historyRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get historyRetry;

  /// No description provided for @historyCertNumber.
  ///
  /// In en, this message translates to:
  /// **'Certificate no. {nomor}'**
  String historyCertNumber(String nomor);

  /// No description provided for @historyStatusPass.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get historyStatusPass;

  /// No description provided for @historyStatusFail.
  ///
  /// In en, this message translates to:
  /// **'FAIL'**
  String get historyStatusFail;

  /// No description provided for @historyStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get historyStatusDraft;

  /// No description provided for @historyStatusMenungguApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get historyStatusMenungguApproval;

  /// No description provided for @historyStatusPerluRevisi.
  ///
  /// In en, this message translates to:
  /// **'Needs revision'**
  String get historyStatusPerluRevisi;

  /// No description provided for @historyApprove.
  ///
  /// In en, this message translates to:
  /// **'APPROVE'**
  String get historyApprove;

  /// No description provided for @historyReject.
  ///
  /// In en, this message translates to:
  /// **'REJECT'**
  String get historyReject;

  /// No description provided for @historyApproveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t approve: {pesan}'**
  String historyApproveFailed(String pesan);

  /// No description provided for @historyRejectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject this calibration session?'**
  String get historyRejectDialogTitle;

  /// No description provided for @historyRejectDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason (required, the technician will see this)'**
  String get historyRejectDialogHint;

  /// No description provided for @historyRejectDialogSubmit.
  ///
  /// In en, this message translates to:
  /// **'REJECT SESSION'**
  String get historyRejectDialogSubmit;

  /// No description provided for @historyRejectDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get historyRejectDialogCancel;

  /// No description provided for @historyRejectDialogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason is required.'**
  String get historyRejectDialogEmpty;

  /// No description provided for @historyRejectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reject: {pesan}'**
  String historyRejectFailed(String pesan);

  /// No description provided for @historyCatatanRevisi.
  ///
  /// In en, this message translates to:
  /// **'Revision note: {catatan}'**
  String historyCatatanRevisi(String catatan);

  /// No description provided for @historyViewCertificate.
  ///
  /// In en, this message translates to:
  /// **'View certificate'**
  String get historyViewCertificate;

  /// No description provided for @certTitle.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get certTitle;

  /// No description provided for @certLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load certificate.'**
  String get certLoadFailed;

  /// No description provided for @certStatusMenungguGenerate.
  ///
  /// In en, this message translates to:
  /// **'Still generating, hang on'**
  String get certStatusMenungguGenerate;

  /// No description provided for @certStatusGagal.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get certStatusGagal;

  /// No description provided for @certRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY GENERATE'**
  String get certRetry;

  /// No description provided for @certOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'VIEW PDF'**
  String get certOpenPdf;

  /// No description provided for @certOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'No app found to open the PDF: {message}'**
  String certOpenFailed(String message);

  /// No description provided for @certBelumTerbit.
  ///
  /// In en, this message translates to:
  /// **'Certificate not issued yet'**
  String get certBelumTerbit;

  /// No description provided for @certQrToken.
  ///
  /// In en, this message translates to:
  /// **'QR token: {token}'**
  String certQrToken(String token);

  /// No description provided for @certRingkasanTitle.
  ///
  /// In en, this message translates to:
  /// **'Result Summary'**
  String get certRingkasanTitle;

  /// No description provided for @certIdentitasTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get certIdentitasTitle;

  /// No description provided for @certTanggalKalibrasi.
  ///
  /// In en, this message translates to:
  /// **'Calibration date'**
  String get certTanggalKalibrasi;

  /// No description provided for @certTeknisi.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get certTeknisi;

  /// No description provided for @certLokasi.
  ///
  /// In en, this message translates to:
  /// **'Calibration location'**
  String get certLokasi;

  /// No description provided for @certMetode.
  ///
  /// In en, this message translates to:
  /// **'Calibration method'**
  String get certMetode;

  /// No description provided for @certReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration Report'**
  String get certReportTitle;

  /// No description provided for @certColStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard Value'**
  String get certColStandard;

  /// No description provided for @certColUut.
  ///
  /// In en, this message translates to:
  /// **'Unit Under Test'**
  String get certColUut;

  /// No description provided for @certColKoreksi.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get certColKoreksi;

  /// No description provided for @certColU95.
  ///
  /// In en, this message translates to:
  /// **'U95% (±)'**
  String get certColU95;

  /// No description provided for @certStandarDipakai.
  ///
  /// In en, this message translates to:
  /// **'Standard used'**
  String get certStandarDipakai;

  /// No description provided for @certBelumDihitung.
  ///
  /// In en, this message translates to:
  /// **'The measurement points haven\'t been calculated by the backend yet, so the report table can\'t be shown.'**
  String get certBelumDihitung;

  /// No description provided for @certDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'— Calibration results are not to be announced and only apply to related tools —'**
  String get certDisclaimer;

  /// No description provided for @certLihatDetail.
  ///
  /// In en, this message translates to:
  /// **'VIEW CALCULATION DETAIL'**
  String get certLihatDetail;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration Result Detail'**
  String get detailTitle;

  /// No description provided for @detailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load calibration detail.'**
  String get detailLoadFailed;

  /// No description provided for @detailNomorSesi.
  ///
  /// In en, this message translates to:
  /// **'Session no. {nomor}'**
  String detailNomorSesi(String nomor);

  /// No description provided for @detailKondisiLingkungan.
  ///
  /// In en, this message translates to:
  /// **'Environmental Condition & Standard'**
  String get detailKondisiLingkungan;

  /// No description provided for @detailStandarAcuan.
  ///
  /// In en, this message translates to:
  /// **'Reference standard'**
  String get detailStandarAcuan;

  /// No description provided for @detailSuhuRuang.
  ///
  /// In en, this message translates to:
  /// **'Room temperature'**
  String get detailSuhuRuang;

  /// No description provided for @detailKelembaban.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get detailKelembaban;

  /// No description provided for @detailLokasi.
  ///
  /// In en, this message translates to:
  /// **'Calibration location'**
  String get detailLokasi;

  /// No description provided for @detailLokasiLab.
  ///
  /// In en, this message translates to:
  /// **'At the lab'**
  String get detailLokasiLab;

  /// No description provided for @detailLokasiOnsite.
  ///
  /// In en, this message translates to:
  /// **'At customer site (onsite)'**
  String get detailLokasiOnsite;

  /// No description provided for @detailTitikUkurTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement Points'**
  String get detailTitikUkurTitle;

  /// No description provided for @detailBelumDihitung.
  ///
  /// In en, this message translates to:
  /// **'This session hasn\'t been calculated by the server yet — results will show up once it\'s processed.'**
  String get detailBelumDihitung;

  /// No description provided for @detailLihatSertifikat.
  ///
  /// In en, this message translates to:
  /// **'VIEW CERTIFICATE'**
  String get detailLihatSertifikat;

  /// No description provided for @detailTitikLabel.
  ///
  /// In en, this message translates to:
  /// **'Point {index} · {nilai}'**
  String detailTitikLabel(int index, String nilai);

  /// No description provided for @detailRataRata.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get detailRataRata;

  /// No description provided for @detailError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get detailError;

  /// No description provided for @detailKoreksi.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get detailKoreksi;

  /// No description provided for @detailStandarDeviasi.
  ///
  /// In en, this message translates to:
  /// **'Standard deviation'**
  String get detailStandarDeviasi;

  /// No description provided for @detailMaxStdev.
  ///
  /// In en, this message translates to:
  /// **'Max STDEV'**
  String get detailMaxStdev;

  /// No description provided for @detailMaxStdevSebelum.
  ///
  /// In en, this message translates to:
  /// **'Before adjustment'**
  String get detailMaxStdevSebelum;

  /// No description provided for @detailTypeA.
  ///
  /// In en, this message translates to:
  /// **'Type A'**
  String get detailTypeA;

  /// No description provided for @detailTypeB.
  ///
  /// In en, this message translates to:
  /// **'Type B'**
  String get detailTypeB;

  /// No description provided for @detailKomponenTypeB.
  ///
  /// In en, this message translates to:
  /// **'Type B component breakdown'**
  String get detailKomponenTypeB;

  /// No description provided for @detailToleransi.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get detailToleransi;

  /// No description provided for @detailKetidakpastianGabungan.
  ///
  /// In en, this message translates to:
  /// **'Combined uncertainty (uc)'**
  String get detailKetidakpastianGabungan;

  /// No description provided for @detailFaktorCakupan.
  ///
  /// In en, this message translates to:
  /// **'Coverage factor (k)'**
  String get detailFaktorCakupan;

  /// No description provided for @detailU95.
  ///
  /// In en, this message translates to:
  /// **'Expanded uncertainty (U95%)'**
  String get detailU95;

  /// No description provided for @detailAwal.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get detailAwal;

  /// No description provided for @detailAkhir.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get detailAkhir;

  /// No description provided for @detailNilaiTerkoreksi.
  ///
  /// In en, this message translates to:
  /// **'Corrected value'**
  String get detailNilaiTerkoreksi;

  /// No description provided for @detailU95Lingkungan.
  ///
  /// In en, this message translates to:
  /// **'U95%'**
  String get detailU95Lingkungan;

  /// No description provided for @detailThermohygro.
  ///
  /// In en, this message translates to:
  /// **'Thermohygrometer'**
  String get detailThermohygro;

  /// No description provided for @detailMetode.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get detailMetode;

  /// No description provided for @detailSuhuLarutan.
  ///
  /// In en, this message translates to:
  /// **'Solution temp.'**
  String get detailSuhuLarutan;

  /// No description provided for @detailSebelumAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Before adjustment (as found)'**
  String get detailSebelumAdjustment;

  /// No description provided for @detailSesudahAdjustment.
  ///
  /// In en, this message translates to:
  /// **'After adjustment (certified)'**
  String get detailSesudahAdjustment;

  /// No description provided for @detailAsFoundCatatan.
  ///
  /// In en, this message translates to:
  /// **'Documents the state the instrument arrived in — not part of the certified result.'**
  String get detailAsFoundCatatan;

  /// No description provided for @detailPerluVerifikasi.
  ///
  /// In en, this message translates to:
  /// **'Some OCR readings still need confirming — this session can\'t be approved yet.'**
  String get detailPerluVerifikasi;

  /// No description provided for @arsipTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get arsipTitle;

  /// No description provided for @arsipCariPerusahaan.
  ///
  /// In en, this message translates to:
  /// **'Search company...'**
  String get arsipCariPerusahaan;

  /// No description provided for @arsipPerusahaanKosong.
  ///
  /// In en, this message translates to:
  /// **'No companies yet.'**
  String get arsipPerusahaanKosong;

  /// No description provided for @arsipFolderKosong.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty.'**
  String get arsipFolderKosong;

  /// No description provided for @arsipLoadGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the archive.'**
  String get arsipLoadGagal;

  /// No description provided for @arsipRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get arsipRetry;

  /// No description provided for @arsipRingkasPerusahaan.
  ///
  /// In en, this message translates to:
  /// **'{alat} instruments · {sertifikat} certificates'**
  String arsipRingkasPerusahaan(int alat, int sertifikat);

  /// No description provided for @arsipRingkasFolder.
  ///
  /// In en, this message translates to:
  /// **'{subfolder} folders · {berkas} files'**
  String arsipRingkasFolder(int subfolder, int berkas);

  /// No description provided for @arsipFolderBaru.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get arsipFolderBaru;

  /// No description provided for @arsipNamaFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get arsipNamaFolder;

  /// No description provided for @arsipNamaFolderHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2026'**
  String get arsipNamaFolderHint;

  /// No description provided for @arsipBuat.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get arsipBuat;

  /// No description provided for @arsipBatal.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get arsipBatal;

  /// No description provided for @arsipSimpan.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get arsipSimpan;

  /// No description provided for @arsipGantiNama.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get arsipGantiNama;

  /// No description provided for @arsipHapus.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get arsipHapus;

  /// No description provided for @arsipHapusJudul.
  ///
  /// In en, this message translates to:
  /// **'Delete this folder?'**
  String get arsipHapusJudul;

  /// No description provided for @arsipHapusIsi.
  ///
  /// In en, this message translates to:
  /// **'Folder \"{nama}\" will be removed. Only empty folders can be deleted.'**
  String arsipHapusIsi(String nama);

  /// No description provided for @arsipTakBisaHapus.
  ///
  /// In en, this message translates to:
  /// **'Move or delete its contents first.'**
  String get arsipTakBisaHapus;

  /// No description provided for @arsipFolderSistem.
  ///
  /// In en, this message translates to:
  /// **'Company folder — managed automatically.'**
  String get arsipFolderSistem;

  /// No description provided for @arsipBerkasTanpaSertifikat.
  ///
  /// In en, this message translates to:
  /// **'No certificate yet'**
  String get arsipBerkasTanpaSertifikat;

  /// No description provided for @arsipDibuat.
  ///
  /// In en, this message translates to:
  /// **'Folder created.'**
  String get arsipDibuat;

  /// No description provided for @arsipDiubah.
  ///
  /// In en, this message translates to:
  /// **'Folder renamed.'**
  String get arsipDiubah;

  /// No description provided for @arsipDihapus.
  ///
  /// In en, this message translates to:
  /// **'Folder deleted.'**
  String get arsipDihapus;

  /// No description provided for @orgTitle.
  ///
  /// In en, this message translates to:
  /// **'Organization Data'**
  String get orgTitle;

  /// No description provided for @orgNama.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get orgNama;

  /// No description provided for @orgAlamat.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get orgAlamat;

  /// No description provided for @orgTelepon.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get orgTelepon;

  /// No description provided for @orgEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get orgEmail;

  /// No description provided for @orgNoAkreditasi.
  ///
  /// In en, this message translates to:
  /// **'Accreditation no.'**
  String get orgNoAkreditasi;

  /// No description provided for @orgAkreditasi.
  ///
  /// In en, this message translates to:
  /// **'Accreditation Status'**
  String get orgAkreditasi;

  /// No description provided for @orgAkreditasiBerlaku.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get orgAkreditasiBerlaku;

  /// No description provided for @orgAkreditasiKadaluarsa.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get orgAkreditasiKadaluarsa;

  /// No description provided for @orgStandarAkreditasi.
  ///
  /// In en, this message translates to:
  /// **'Accreditation standard'**
  String get orgStandarAkreditasi;

  /// No description provided for @orgStandarAkreditasiHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ISO/IEC 17025:2017'**
  String get orgStandarAkreditasiHint;

  /// No description provided for @orgAkreditasiMulai.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get orgAkreditasiMulai;

  /// No description provided for @orgAkreditasiBerakhir.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get orgAkreditasiBerakhir;

  /// No description provided for @orgPilihTanggal.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get orgPilihTanggal;

  /// No description provided for @orgSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get orgSave;

  /// No description provided for @orgSaved.
  ///
  /// In en, this message translates to:
  /// **'Organization data saved.'**
  String get orgSaved;

  /// No description provided for @orgSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {pesan}'**
  String orgSaveFailed(String pesan);

  /// No description provided for @orgLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load organization data.'**
  String get orgLoadFailed;

  /// No description provided for @orgRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get orgRetry;

  /// No description provided for @standarTitle.
  ///
  /// In en, this message translates to:
  /// **'Reference Standards'**
  String get standarTitle;

  /// No description provided for @standarLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load reference standards.'**
  String get standarLoadFailed;

  /// No description provided for @standarAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD STANDARD'**
  String get standarAdd;

  /// No description provided for @standarEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit standard'**
  String get standarEdit;

  /// No description provided for @standarEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reference standards yet'**
  String get standarEmptyTitle;

  /// No description provided for @standarEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first standard using the button below.'**
  String get standarEmptyBody;

  /// No description provided for @standarRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get standarRetry;

  /// No description provided for @standarBerlaku.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get standarBerlaku;

  /// No description provided for @standarKadaluarsa.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get standarKadaluarsa;

  /// No description provided for @standarDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete reference standard?'**
  String get standarDeleteConfirmTitle;

  /// No description provided for @standarDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{nama}\" will be permanently deleted.'**
  String standarDeleteConfirmBody(String nama);

  /// No description provided for @standarDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {pesan}'**
  String standarDeleteFailed(String pesan);

  /// No description provided for @standarSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {pesan}'**
  String standarSaveFailed(String pesan);

  /// No description provided for @standarFaktorCakupanInvalid.
  ///
  /// In en, this message translates to:
  /// **'Coverage factor (k) must be at least 1 — usually 2.'**
  String get standarFaktorCakupanInvalid;

  /// No description provided for @standarNama.
  ///
  /// In en, this message translates to:
  /// **'Standard name'**
  String get standarNama;

  /// No description provided for @standarMerk.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get standarMerk;

  /// No description provided for @standarModel.
  ///
  /// In en, this message translates to:
  /// **'Model/Type'**
  String get standarModel;

  /// No description provided for @standarSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get standarSerialNumber;

  /// No description provided for @standarNoSertifikat.
  ///
  /// In en, this message translates to:
  /// **'Certificate no.'**
  String get standarNoSertifikat;

  /// No description provided for @standarTertelusurKe.
  ///
  /// In en, this message translates to:
  /// **'Traceable to'**
  String get standarTertelusurKe;

  /// No description provided for @standarTertelusurKeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. SNSU-BSN'**
  String get standarTertelusurKeHint;

  /// No description provided for @standarBerlakuSampai.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get standarBerlakuSampai;

  /// No description provided for @standarKetidakpastianTitle.
  ///
  /// In en, this message translates to:
  /// **'Uncertainty (from the standard\'s certificate)'**
  String get standarKetidakpastianTitle;

  /// No description provided for @standarKetidakpastian.
  ///
  /// In en, this message translates to:
  /// **'Uncertainty (expanded)'**
  String get standarKetidakpastian;

  /// No description provided for @standarSatuanKetidakpastian.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get standarSatuanKetidakpastian;

  /// No description provided for @standarFaktorCakupan.
  ///
  /// In en, this message translates to:
  /// **'Coverage factor (k)'**
  String get standarFaktorCakupan;

  /// No description provided for @standarDrift.
  ///
  /// In en, this message translates to:
  /// **'Annual drift'**
  String get standarDrift;

  /// No description provided for @standarSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get standarSave;

  /// No description provided for @custTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get custTitle;

  /// No description provided for @custSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer name'**
  String get custSearchHint;

  /// No description provided for @custEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get custEmptyTitle;

  /// No description provided for @custEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first customer using the button below.'**
  String get custEmptyBody;

  /// No description provided for @custLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load customers.'**
  String get custLoadFailed;

  /// No description provided for @custRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get custRetry;

  /// No description provided for @custAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD CUSTOMER'**
  String get custAdd;

  /// No description provided for @custEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get custEdit;

  /// No description provided for @custNama.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get custNama;

  /// No description provided for @custAlamat.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get custAlamat;

  /// No description provided for @custContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get custContactPerson;

  /// No description provided for @custTelepon.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get custTelepon;

  /// No description provided for @custEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get custEmail;

  /// No description provided for @custSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get custSave;

  /// No description provided for @custCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get custCancel;

  /// No description provided for @custDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get custDelete;

  /// No description provided for @custDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete customer?'**
  String get custDeleteConfirmTitle;

  /// No description provided for @custDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{nama}\" will be permanently deleted.'**
  String custDeleteConfirmBody(String nama);

  /// No description provided for @custDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {pesan}'**
  String custDeleteFailed(String pesan);

  /// No description provided for @custSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {pesan}'**
  String custSaveFailed(String pesan);

  /// No description provided for @custEquipmentCount.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} devices'**
  String custEquipmentCount(int jumlah);

  /// No description provided for @custFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required.'**
  String get custFieldRequired;

  /// No description provided for @calibTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration Input'**
  String get calibTitle;

  /// No description provided for @calibKategori.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get calibKategori;

  /// No description provided for @calibKategoriHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a device category'**
  String get calibKategoriHint;

  /// No description provided for @calibAlat.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get calibAlat;

  /// No description provided for @calibAlatHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a device'**
  String get calibAlatHint;

  /// No description provided for @calibAlatKosong.
  ///
  /// In en, this message translates to:
  /// **'No devices in this category.'**
  String get calibAlatKosong;

  /// No description provided for @calibStandar.
  ///
  /// In en, this message translates to:
  /// **'Reference Standard'**
  String get calibStandar;

  /// No description provided for @calibStandarHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a reference standard'**
  String get calibStandarHint;

  /// No description provided for @calibStandarKadaluarsa.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get calibStandarKadaluarsa;

  /// No description provided for @calibTanggal.
  ///
  /// In en, this message translates to:
  /// **'Calibration date'**
  String get calibTanggal;

  /// No description provided for @calibNomorOrder.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get calibNomorOrder;

  /// No description provided for @calibNomorOrderHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2405.13.A (optional)'**
  String get calibNomorOrderHint;

  /// No description provided for @calibTanggalTerima.
  ///
  /// In en, this message translates to:
  /// **'Equipment received date'**
  String get calibTanggalTerima;

  /// No description provided for @calibLokasi.
  ///
  /// In en, this message translates to:
  /// **'Calibration location'**
  String get calibLokasi;

  /// No description provided for @calibLokasiLab.
  ///
  /// In en, this message translates to:
  /// **'At the lab'**
  String get calibLokasiLab;

  /// No description provided for @calibLokasiOnsite.
  ///
  /// In en, this message translates to:
  /// **'At customer site (onsite)'**
  String get calibLokasiOnsite;

  /// No description provided for @calibSuhuRuang.
  ///
  /// In en, this message translates to:
  /// **'Room temperature (°C)'**
  String get calibSuhuRuang;

  /// No description provided for @calibKelembaban.
  ///
  /// In en, this message translates to:
  /// **'Humidity (%)'**
  String get calibKelembaban;

  /// No description provided for @calibTitikUkur.
  ///
  /// In en, this message translates to:
  /// **'Measurement point {index}'**
  String calibTitikUkur(int index);

  /// No description provided for @calibNilaiTarget.
  ///
  /// In en, this message translates to:
  /// **'Target value'**
  String get calibNilaiTarget;

  /// No description provided for @calibSatuan.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get calibSatuan;

  /// No description provided for @calibPembacaan.
  ///
  /// In en, this message translates to:
  /// **'Reading {index}'**
  String calibPembacaan(int index);

  /// No description provided for @calibTambahTitik.
  ///
  /// In en, this message translates to:
  /// **'ADD MEASUREMENT POINT'**
  String get calibTambahTitik;

  /// No description provided for @calibHapusTitik.
  ///
  /// In en, this message translates to:
  /// **'Remove measurement point'**
  String get calibHapusTitik;

  /// No description provided for @calibTambahPembacaan.
  ///
  /// In en, this message translates to:
  /// **'+ Add reading'**
  String get calibTambahPembacaan;

  /// No description provided for @calibValidasiKategori.
  ///
  /// In en, this message translates to:
  /// **'Choose a category first.'**
  String get calibValidasiKategori;

  /// No description provided for @calibValidasiAlat.
  ///
  /// In en, this message translates to:
  /// **'Choose a device first.'**
  String get calibValidasiAlat;

  /// No description provided for @calibValidasiStandar.
  ///
  /// In en, this message translates to:
  /// **'Choose a reference standard first.'**
  String get calibValidasiStandar;

  /// No description provided for @calibValidasiAngka.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number.'**
  String get calibValidasiAngka;

  /// No description provided for @calibValidasiPembacaan.
  ///
  /// In en, this message translates to:
  /// **'Each measurement point needs at least 2 numeric readings.'**
  String get calibValidasiPembacaan;

  /// No description provided for @calibSimpanDraft.
  ///
  /// In en, this message translates to:
  /// **'SAVE DRAFT'**
  String get calibSimpanDraft;

  /// No description provided for @calibKirimApproval.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT FOR APPROVAL'**
  String get calibKirimApproval;

  /// No description provided for @calibBerhasilDraft.
  ///
  /// In en, this message translates to:
  /// **'Calibration draft saved.'**
  String get calibBerhasilDraft;

  /// No description provided for @calibBerhasilApproval.
  ///
  /// In en, this message translates to:
  /// **'Calibration session submitted for approval.'**
  String get calibBerhasilApproval;

  /// No description provided for @calibGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {pesan}'**
  String calibGagal(String pesan);

  /// No description provided for @calibLoadPilihanGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load category/standard options.'**
  String get calibLoadPilihanGagal;

  /// No description provided for @calibRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get calibRetry;

  /// No description provided for @calibPilihKategoriTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Equipment Category'**
  String get calibPilihKategoriTitle;

  /// No description provided for @calibPilihKategoriSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the measurement group first, then the specific instrument type.'**
  String get calibPilihKategoriSubtitle;

  /// No description provided for @calibKategoriKosong.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get calibKategoriKosong;

  /// No description provided for @calibJumlahAlat.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} instrument type{jumlah, plural, =1{} other{s}}'**
  String calibJumlahAlat(int jumlah);

  /// No description provided for @calibPilihInstrumenTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Instrument Type'**
  String get calibPilihInstrumenTitle;

  /// No description provided for @calibInstrumenKosong.
  ///
  /// In en, this message translates to:
  /// **'This category doesn\'t have any calibration capability data yet.'**
  String get calibInstrumenKosong;

  /// No description provided for @calibInstrumenMetodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get calibInstrumenMetodeLabel;

  /// No description provided for @calibCariInstrumenHint.
  ///
  /// In en, this message translates to:
  /// **'Search instrument type...'**
  String get calibCariInstrumenHint;

  /// No description provided for @calibInstrumenTidakDitemukan.
  ///
  /// In en, this message translates to:
  /// **'No matching instrument type.'**
  String get calibInstrumenTidakDitemukan;

  /// No description provided for @phCalibTitle.
  ///
  /// In en, this message translates to:
  /// **'pH Meter Calibration'**
  String get phCalibTitle;

  /// No description provided for @phCalibThermohygro.
  ///
  /// In en, this message translates to:
  /// **'Thermohygrometer used'**
  String get phCalibThermohygro;

  /// No description provided for @phCalibThermohygroHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. TH-3'**
  String get phCalibThermohygroHint;

  /// No description provided for @phCalibThermohygroCustom.
  ///
  /// In en, this message translates to:
  /// **'Other (enter manually)'**
  String get phCalibThermohygroCustom;

  /// No description provided for @phCalibStandarSesi.
  ///
  /// In en, this message translates to:
  /// **'Reference Standard (Thermometer & Sensor)'**
  String get phCalibStandarSesi;

  /// No description provided for @phCalibStandarSesiHint.
  ///
  /// In en, this message translates to:
  /// **'Used for environmental conditions (temp/humidity)'**
  String get phCalibStandarSesiHint;

  /// No description provided for @phCalibStandarBuffer.
  ///
  /// In en, this message translates to:
  /// **'Buffer standard for this point'**
  String get phCalibStandarBuffer;

  /// No description provided for @phCalibStandarBufferHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a buffer solution'**
  String get phCalibStandarBufferHint;

  /// No description provided for @phCalibValidasiStandarBuffer.
  ///
  /// In en, this message translates to:
  /// **'Choose a buffer standard for every point (4, 7, 10) first.'**
  String get phCalibValidasiStandarBuffer;

  /// No description provided for @phCalibKondisiLingkungan.
  ///
  /// In en, this message translates to:
  /// **'Environmental Conditions'**
  String get phCalibKondisiLingkungan;

  /// No description provided for @phCalibSuhuAwal.
  ///
  /// In en, this message translates to:
  /// **'Start temperature (°C)'**
  String get phCalibSuhuAwal;

  /// No description provided for @phCalibSuhuAkhir.
  ///
  /// In en, this message translates to:
  /// **'End temperature (°C)'**
  String get phCalibSuhuAkhir;

  /// No description provided for @phCalibKelembabanAwal.
  ///
  /// In en, this message translates to:
  /// **'Start humidity (%)'**
  String get phCalibKelembabanAwal;

  /// No description provided for @phCalibKelembabanAkhir.
  ///
  /// In en, this message translates to:
  /// **'End humidity (%)'**
  String get phCalibKelembabanAkhir;

  /// No description provided for @phCalibTitikBuffer.
  ///
  /// In en, this message translates to:
  /// **'pH {label} buffer'**
  String phCalibTitikBuffer(String label);

  /// No description provided for @phCalibNilaiStandar.
  ///
  /// In en, this message translates to:
  /// **'Reference value (temp-corrected)'**
  String get phCalibNilaiStandar;

  /// No description provided for @phCalibNilaiStandarHelper.
  ///
  /// In en, this message translates to:
  /// **'Copy from the worksheet — the buffer value after temperature correction, not the round number.'**
  String get phCalibNilaiStandarHelper;

  /// No description provided for @phCalibNilaiStandarSebelum.
  ///
  /// In en, this message translates to:
  /// **'As-found reference value'**
  String get phCalibNilaiStandarSebelum;

  /// No description provided for @phCalibSebelumAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Before adjustment (as found)'**
  String get phCalibSebelumAdjustment;

  /// No description provided for @phCalibSesudahAdjustment.
  ///
  /// In en, this message translates to:
  /// **'After adjustment (as left)'**
  String get phCalibSesudahAdjustment;

  /// No description provided for @phCalibIdMerk.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get phCalibIdMerk;

  /// No description provided for @phCalibIdType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get phCalibIdType;

  /// No description provided for @phCalibIdNoSeri.
  ///
  /// In en, this message translates to:
  /// **'Serial no.'**
  String get phCalibIdNoSeri;

  /// No description provided for @phCalibIdRentang.
  ///
  /// In en, this message translates to:
  /// **'Measuring range'**
  String get phCalibIdRentang;

  /// No description provided for @phCalibIdResolusi.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get phCalibIdResolusi;

  /// No description provided for @phCalibIdCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get phCalibIdCustomer;

  /// No description provided for @phCalibFotoMembaca.
  ///
  /// In en, this message translates to:
  /// **'Reading the numbers from your photo…'**
  String get phCalibFotoMembaca;

  /// No description provided for @phCalibIdentitasCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get phCalibIdentitasCustomer;

  /// No description provided for @phCalibIdNamaAlat.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get phCalibIdNamaAlat;

  /// No description provided for @phCalibIdKapasitasMax.
  ///
  /// In en, this message translates to:
  /// **'Max. capacity'**
  String get phCalibIdKapasitasMax;

  /// No description provided for @phCalibIdAlamatCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer address'**
  String get phCalibIdAlamatCustomer;

  /// No description provided for @phCalibIdCertificateNumber.
  ///
  /// In en, this message translates to:
  /// **'Certificate no.'**
  String get phCalibIdCertificateNumber;

  /// No description provided for @phCalibIdOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order no.'**
  String get phCalibIdOrderNumber;

  /// No description provided for @phCalibIdTechnicianId.
  ///
  /// In en, this message translates to:
  /// **'Technician ID'**
  String get phCalibIdTechnicianId;

  /// No description provided for @phCalibIdCalibrationMethod.
  ///
  /// In en, this message translates to:
  /// **'Calibration method'**
  String get phCalibIdCalibrationMethod;

  /// No description provided for @phCalibPengesahan.
  ///
  /// In en, this message translates to:
  /// **'Authorisation'**
  String get phCalibPengesahan;

  /// No description provided for @phCalibIssuanceDate.
  ///
  /// In en, this message translates to:
  /// **'Issuance date'**
  String get phCalibIssuanceDate;

  /// No description provided for @phCalibCalculatedBy.
  ///
  /// In en, this message translates to:
  /// **'Calculated by (initials)'**
  String get phCalibCalculatedBy;

  /// No description provided for @phCalibCalculatedByHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. NR'**
  String get phCalibCalculatedByHint;

  /// No description provided for @phCalibSignedBy.
  ///
  /// In en, this message translates to:
  /// **'Signed by (full name)'**
  String get phCalibSignedBy;

  /// No description provided for @phCalibSignedByHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alex Misramto'**
  String get phCalibSignedByHint;

  /// No description provided for @phCalibLiveJudul.
  ///
  /// In en, this message translates to:
  /// **'Point at the table'**
  String get phCalibLiveJudul;

  /// No description provided for @phCalibLivePetunjuk.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the worksheet table. Numbers that are recognised will float on screen.'**
  String get phCalibLivePetunjuk;

  /// No description provided for @phCalibLivePakai.
  ///
  /// In en, this message translates to:
  /// **'USE THESE NUMBERS'**
  String get phCalibLivePakai;

  /// No description provided for @phCalibLiveTanpaKamera.
  ///
  /// In en, this message translates to:
  /// **'No camera found on this phone. You can still type the values in.'**
  String get phCalibLiveTanpaKamera;

  /// No description provided for @phCalibCaraJudul.
  ///
  /// In en, this message translates to:
  /// **'How do you want to fill this in?'**
  String get phCalibCaraJudul;

  /// No description provided for @phCalibCaraSub.
  ///
  /// In en, this message translates to:
  /// **'Pick once. You can still use the camera button later on the data page.'**
  String get phCalibCaraSub;

  /// No description provided for @phCalibCaraFoto.
  ///
  /// In en, this message translates to:
  /// **'Photograph the worksheet'**
  String get phCalibCaraFoto;

  /// No description provided for @phCalibCaraFotoKeterangan.
  ///
  /// In en, this message translates to:
  /// **'Snap the filled-in table — the fields populate automatically'**
  String get phCalibCaraFotoKeterangan;

  /// No description provided for @phCalibCaraManual.
  ///
  /// In en, this message translates to:
  /// **'Type it in'**
  String get phCalibCaraManual;

  /// No description provided for @phCalibCaraManualKeterangan.
  ///
  /// In en, this message translates to:
  /// **'Fill each field yourself'**
  String get phCalibCaraManualKeterangan;

  /// No description provided for @phCalibCaraCatatan.
  ///
  /// In en, this message translates to:
  /// **'Values from a photo must still be checked before submitting. An issued certificate cannot be changed.'**
  String get phCalibCaraCatatan;

  /// No description provided for @phCalibScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Photograph the pH meter display'**
  String get phCalibScanTooltip;

  /// No description provided for @phCalibScanGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the number clearly. Try a closer photo, or type it in.'**
  String get phCalibScanGagal;

  /// No description provided for @phCalibScanError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera.'**
  String get phCalibScanError;

  /// No description provided for @phCalibFotoTabel.
  ///
  /// In en, this message translates to:
  /// **'PHOTO TABLE'**
  String get phCalibFotoTabel;

  /// No description provided for @phCalibFotoTabelSesudah.
  ///
  /// In en, this message translates to:
  /// **'After adjustment'**
  String get phCalibFotoTabelSesudah;

  /// No description provided for @phCalibFotoTabelSebelum.
  ///
  /// In en, this message translates to:
  /// **'Before adjustment'**
  String get phCalibFotoTabelSebelum;

  /// No description provided for @phCalibFotoTabelJudul.
  ///
  /// In en, this message translates to:
  /// **'Which table are you photographing?'**
  String get phCalibFotoTabelJudul;

  /// No description provided for @phCalibFotoTabelInfo.
  ///
  /// In en, this message translates to:
  /// **'One shot fills the whole table for all three buffers. Cells you already filled are never overwritten — reshoot as many times as you need.'**
  String get phCalibFotoTabelInfo;

  /// No description provided for @phCalibFotoTabelHasil.
  ///
  /// In en, this message translates to:
  /// **'{terisi} of {total} cells filled.'**
  String phCalibFotoTabelHasil(int terisi, int total);

  /// No description provided for @phCalibFotoTabelTakTerbaca.
  ///
  /// In en, this message translates to:
  /// **'No numbers could be read at all. The photo is probably dark, blurry, or too far away — try closer and brighter. You can still type the values in.'**
  String get phCalibFotoTabelTakTerbaca;

  /// No description provided for @phCalibFotoTabelPosisiKacau.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} numbers were read, but they don\'t line up as a table. Usually the photo is skewed or shows the whole sheet — try photographing just the TABLE, straight from above. You can still type the values in.'**
  String phCalibFotoTabelPosisiKacau(int jumlah);

  /// No description provided for @phCalibFotoTabelKosong.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the numbers yet. Tips: photograph just the TABLE (not the whole sheet), straight from above, even light with no hand shadow. Or type it in.'**
  String get phCalibFotoTabelKosong;

  /// No description provided for @phCalibFotoTabelSisa.
  ///
  /// In en, this message translates to:
  /// **'Empty cells: type them in or reshoot — nothing you already entered will be replaced.'**
  String get phCalibFotoTabelSisa;

  /// No description provided for @phCalibOcrBelumDikonfirmasi.
  ///
  /// In en, this message translates to:
  /// **'From camera — please check'**
  String get phCalibOcrBelumDikonfirmasi;

  /// No description provided for @phCalibOcrKonfirmasi.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get phCalibOcrKonfirmasi;

  /// No description provided for @phCalibPembacaanKe.
  ///
  /// In en, this message translates to:
  /// **'Reading {index}'**
  String phCalibPembacaanKe(int index);

  /// No description provided for @phCalibSuhu.
  ///
  /// In en, this message translates to:
  /// **'Temp.'**
  String get phCalibSuhu;

  /// No description provided for @phCalibValidasiLingkungan.
  ///
  /// In en, this message translates to:
  /// **'Fill in the environmental conditions (temperature & humidity) first.'**
  String get phCalibValidasiLingkungan;

  /// No description provided for @phCalibValidasiPembacaan.
  ///
  /// In en, this message translates to:
  /// **'Each buffer point needs at least {minimum} valid after-adjustment readings.'**
  String phCalibValidasiPembacaan(int minimum);

  /// No description provided for @phCalibValidasiNilaiAcuan.
  ///
  /// In en, this message translates to:
  /// **'Fill in the temperature-corrected reference value for every buffer point.'**
  String get phCalibValidasiNilaiAcuan;

  /// No description provided for @phCalibLangkahIdentitas.
  ///
  /// In en, this message translates to:
  /// **'Identity & conditions'**
  String get phCalibLangkahIdentitas;

  /// No description provided for @phCalibLangkahHasil.
  ///
  /// In en, this message translates to:
  /// **'Calibration results'**
  String get phCalibLangkahHasil;

  /// No description provided for @phCalibLangkahKe.
  ///
  /// In en, this message translates to:
  /// **'Step {nomor} of {total}'**
  String phCalibLangkahKe(int nomor, int total);

  /// No description provided for @phCalibIdentitasAlat.
  ///
  /// In en, this message translates to:
  /// **'Instrument Identity'**
  String get phCalibIdentitasAlat;

  /// No description provided for @phCalibPengerjaan.
  ///
  /// In en, this message translates to:
  /// **'Job Details'**
  String get phCalibPengerjaan;

  /// No description provided for @phCalibPelangganOtomatis.
  ///
  /// In en, this message translates to:
  /// **'Customer details follow the selected instrument — the certificate is filed under the right company automatically.'**
  String get phCalibPelangganOtomatis;

  /// No description provided for @phCalibKoreksiSuhu.
  ///
  /// In en, this message translates to:
  /// **'Temperature correction (°C)'**
  String get phCalibKoreksiSuhu;

  /// No description provided for @phCalibKoreksiKelembaban.
  ///
  /// In en, this message translates to:
  /// **'Humidity correction (%)'**
  String get phCalibKoreksiKelembaban;

  /// No description provided for @phCalibU95Suhu.
  ///
  /// In en, this message translates to:
  /// **'Temperature U95%'**
  String get phCalibU95Suhu;

  /// No description provided for @phCalibU95Kelembaban.
  ///
  /// In en, this message translates to:
  /// **'Humidity U95%'**
  String get phCalibU95Kelembaban;

  /// No description provided for @phCalibDariSertifikatTh.
  ///
  /// In en, this message translates to:
  /// **'From the thermohygrometer certificate — the server derives the environmental U95% from these.'**
  String get phCalibDariSertifikatTh;

  /// No description provided for @phCalibLanjutkan.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get phCalibLanjutkan;

  /// No description provided for @phCalibKembali.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get phCalibKembali;

  /// No description provided for @phCalibDisertifikasi.
  ///
  /// In en, this message translates to:
  /// **'Certified'**
  String get phCalibDisertifikasi;

  /// No description provided for @phCalibDokumentasi.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get phCalibDokumentasi;

  /// No description provided for @phCalibDihitungServer.
  ///
  /// In en, this message translates to:
  /// **'Averages, uncertainty budget, environmental U95% and the PASS/FAIL call are all computed by the server.'**
  String get phCalibDihitungServer;

  /// No description provided for @phCalibOpsional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get phCalibOpsional;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Due-date reminders & approval updates will show up here.'**
  String get notifEmptyBody;

  /// No description provided for @notifLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications.'**
  String get notifLoadFailed;

  /// No description provided for @notifSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get notifSessionExpired;

  /// No description provided for @notifRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get notifRetry;

  /// No description provided for @notifMarkedRead.
  ///
  /// In en, this message translates to:
  /// **'Marked as read.'**
  String get notifMarkedRead;

  /// No description provided for @notifTypeDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get notifTypeDueDate;

  /// No description provided for @notifTypeApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get notifTypeApproval;

  /// No description provided for @notifTypeRevision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get notifTypeRevision;

  /// No description provided for @teknisiTitle.
  ///
  /// In en, this message translates to:
  /// **'Technicians'**
  String get teknisiTitle;

  /// No description provided for @teknisiFilterSemua.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get teknisiFilterSemua;

  /// No description provided for @teknisiFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get teknisiFilterPending;

  /// No description provided for @teknisiFilterAktif.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get teknisiFilterAktif;

  /// No description provided for @teknisiFilterNonaktif.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get teknisiFilterNonaktif;

  /// No description provided for @teknisiKosong.
  ///
  /// In en, this message translates to:
  /// **'No accounts in this filter yet.'**
  String get teknisiKosong;

  /// No description provided for @teknisiLoadGagal.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts.'**
  String get teknisiLoadGagal;

  /// No description provided for @teknisiRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teknisiRetry;

  /// No description provided for @teknisiSetujui.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get teknisiSetujui;

  /// No description provided for @teknisiTolak.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get teknisiTolak;

  /// No description provided for @teknisiResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get teknisiResetPassword;

  /// No description provided for @teknisiPilihRole.
  ///
  /// In en, this message translates to:
  /// **'Choose a role for this account'**
  String get teknisiPilihRole;

  /// No description provided for @teknisiPilihRoleBatal.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get teknisiPilihRoleBatal;

  /// No description provided for @teknisiDisetujui.
  ///
  /// In en, this message translates to:
  /// **'Account approved.'**
  String get teknisiDisetujui;

  /// No description provided for @teknisiDitolak.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated.'**
  String get teknisiDitolak;

  /// No description provided for @teknisiPasswordDireset.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Tell the new password to the account owner directly.'**
  String get teknisiPasswordDireset;

  /// No description provided for @teknisiResetPasswordJudul.
  ///
  /// In en, this message translates to:
  /// **'Reset account password'**
  String get teknisiResetPasswordJudul;

  /// No description provided for @teknisiResetPasswordIsi.
  ///
  /// In en, this message translates to:
  /// **'Set a new password for {nama}. Their sessions on every device will be revoked.'**
  String teknisiResetPasswordIsi(String nama);

  /// No description provided for @teknisiResetPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get teknisiResetPasswordLabel;

  /// No description provided for @teknisiResetPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters. The backend sends no email — tell them directly.'**
  String get teknisiResetPasswordHelper;

  /// No description provided for @teknisiResetPasswordTerlaluPendek.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get teknisiResetPasswordTerlaluPendek;

  /// No description provided for @teknisiGagal.
  ///
  /// In en, this message translates to:
  /// **'Action failed. Please try again.'**
  String get teknisiGagal;

  /// No description provided for @teknisiKonfirmTolakJudul.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this account?'**
  String get teknisiKonfirmTolakJudul;

  /// No description provided for @teknisiKonfirmTolakIsi.
  ///
  /// In en, this message translates to:
  /// **'They will be signed out of every device and can no longer sign in. Past calibration records stay intact.'**
  String get teknisiKonfirmTolakIsi;

  /// No description provided for @teknisiTanpaEmployeeId.
  ///
  /// In en, this message translates to:
  /// **'No employee ID'**
  String get teknisiTanpaEmployeeId;

  /// No description provided for @teknisiHanyaAdmin.
  ///
  /// In en, this message translates to:
  /// **'Only admins can manage accounts.'**
  String get teknisiHanyaAdmin;

  /// No description provided for @menuUtama.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get menuUtama;

  /// No description provided for @menuMasterData.
  ///
  /// In en, this message translates to:
  /// **'Master Data'**
  String get menuMasterData;

  /// No description provided for @menuPengaturan.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuPengaturan;

  /// No description provided for @sheetTutup.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get sheetTutup;

  /// No description provided for @sheetCobaLagi.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get sheetCobaLagi;

  /// No description provided for @sheetKirimBerhasil.
  ///
  /// In en, this message translates to:
  /// **'Sent!'**
  String get sheetKirimBerhasil;

  /// No description provided for @sheetKirimBerhasilPesan.
  ///
  /// In en, this message translates to:
  /// **'The session is now in the admin approval queue.'**
  String get sheetKirimBerhasilPesan;

  /// No description provided for @sheetKirimGagal.
  ///
  /// In en, this message translates to:
  /// **'There is a problem'**
  String get sheetKirimGagal;

  /// No description provided for @sheetDraftBerhasil.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get sheetDraftBerhasil;

  /// No description provided for @sheetDraftBerhasilPesan.
  ///
  /// In en, this message translates to:
  /// **'You can pick it up again anytime from history.'**
  String get sheetDraftBerhasilPesan;

  /// No description provided for @phCalibTitikLengkap.
  ///
  /// In en, this message translates to:
  /// **'This point is complete'**
  String get phCalibTitikLengkap;

  /// No description provided for @dashCalibrationDone.
  ///
  /// In en, this message translates to:
  /// **'Calibrations done'**
  String get dashCalibrationDone;

  /// No description provided for @dashWorkChart.
  ///
  /// In en, this message translates to:
  /// **'Workload trend'**
  String get dashWorkChart;

  /// No description provided for @tugasTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get tugasTitle;

  /// No description provided for @tugasKosong.
  ///
  /// In en, this message translates to:
  /// **'No equipment assigned to you yet.'**
  String get tugasKosong;

  /// No description provided for @tugasLoadGagal.
  ///
  /// In en, this message translates to:
  /// **'Could not load your task queue.'**
  String get tugasLoadGagal;

  /// No description provided for @tugasRetry.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get tugasRetry;

  /// No description provided for @tugasJumlahAlat.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} items'**
  String tugasJumlahAlat(int jumlah);

  /// No description provided for @tugasTelat.
  ///
  /// In en, this message translates to:
  /// **'Past due date'**
  String get tugasTelat;

  /// No description provided for @tugasMasuk.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get tugasMasuk;

  /// No description provided for @tugasJanji.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get tugasJanji;

  /// No description provided for @tugasBelumDitugaskan.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get tugasBelumDitugaskan;

  /// No description provided for @dashSummaryOrg.
  ///
  /// In en, this message translates to:
  /// **'Organization summary'**
  String get dashSummaryOrg;

  /// No description provided for @dashSummaryYours.
  ///
  /// In en, this message translates to:
  /// **'Your summary'**
  String get dashSummaryYours;

  /// No description provided for @snackAddDeviceSoon.
  ///
  /// In en, this message translates to:
  /// **'Adding devices is planned for week 3.'**
  String get snackAddDeviceSoon;

  /// No description provided for @dashStartPhCalibration.
  ///
  /// In en, this message translates to:
  /// **'PH METER CALIBRATION'**
  String get dashStartPhCalibration;

  /// No description provided for @lkTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration Worksheet'**
  String get lkTitle;

  /// No description provided for @lkSubtitleDraft.
  ///
  /// In en, this message translates to:
  /// **'Continue draft'**
  String get lkSubtitleDraft;

  /// No description provided for @lkSubtitleRevisi.
  ///
  /// In en, this message translates to:
  /// **'Revise — returned by admin'**
  String get lkSubtitleRevisi;

  /// No description provided for @lkLoadGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the worksheet form.'**
  String get lkLoadGagal;

  /// No description provided for @lkRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get lkRetry;

  /// No description provided for @lkPilihAlat.
  ///
  /// In en, this message translates to:
  /// **'Choose equipment'**
  String get lkPilihAlat;

  /// No description provided for @lkAlatKosong.
  ///
  /// In en, this message translates to:
  /// **'No equipment available yet.'**
  String get lkAlatKosong;

  /// No description provided for @lkBelumPilihAlat.
  ///
  /// In en, this message translates to:
  /// **'Choose the equipment first — the identity and owner fields fill in automatically.'**
  String get lkBelumPilihAlat;

  /// No description provided for @lkOtomatis.
  ///
  /// In en, this message translates to:
  /// **'Filled automatically'**
  String get lkOtomatis;

  /// No description provided for @lkKosong.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get lkKosong;

  /// No description provided for @lkPilihTanggal.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get lkPilihTanggal;

  /// No description provided for @lkHapusTanggal.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get lkHapusTanggal;

  /// No description provided for @lkRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get lkRepeat;

  /// No description provided for @lkUsageCheckKosong.
  ///
  /// In en, this message translates to:
  /// **'No reference standards in master data yet.'**
  String get lkUsageCheckKosong;

  /// No description provided for @lkUsageCheckKeterangan.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get lkUsageCheckKeterangan;

  /// No description provided for @lkStandarPerTitik.
  ///
  /// In en, this message translates to:
  /// **'Buffer standard'**
  String get lkStandarPerTitik;

  /// No description provided for @lkStandarKadaluarsa.
  ///
  /// In en, this message translates to:
  /// **'certificate expired'**
  String get lkStandarKadaluarsa;

  /// No description provided for @lkPilih.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get lkPilih;

  /// No description provided for @lkKirim.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT TO ADMIN'**
  String get lkKirim;

  /// No description provided for @lkSimpanDraft.
  ///
  /// In en, this message translates to:
  /// **'SAVE AS DRAFT'**
  String get lkSimpanDraft;

  /// No description provided for @lkBerhasilKirim.
  ///
  /// In en, this message translates to:
  /// **'Worksheet submitted to admin.'**
  String get lkBerhasilKirim;

  /// No description provided for @lkBerhasilDraft.
  ///
  /// In en, this message translates to:
  /// **'Saved as draft.'**
  String get lkBerhasilDraft;

  /// No description provided for @lkGagalKirim.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {pesan}'**
  String lkGagalKirim(String pesan);

  /// No description provided for @lkSemuaOpsional.
  ///
  /// In en, this message translates to:
  /// **'Any field you can\'t fill in the field may be left blank — the worksheet can still be submitted.'**
  String get lkSemuaOpsional;

  /// No description provided for @lkKeluarTanpaSimpan.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get lkKeluarTanpaSimpan;

  /// No description provided for @lkKeluarTanpaSimpanBody.
  ///
  /// In en, this message translates to:
  /// **'What you\'ve typed will be lost.'**
  String get lkKeluarTanpaSimpanBody;

  /// No description provided for @lkKeluarBatal.
  ///
  /// In en, this message translates to:
  /// **'KEEP EDITING'**
  String get lkKeluarBatal;

  /// No description provided for @lkKeluarLanjut.
  ///
  /// In en, this message translates to:
  /// **'LEAVE'**
  String get lkKeluarLanjut;

  /// No description provided for @lkSuhuDiLuarRentang.
  ///
  /// In en, this message translates to:
  /// **'Outside this room\'s range ({min}–{max}).'**
  String lkSuhuDiLuarRentang(String min, String max);

  /// No description provided for @navFolderManager.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get navFolderManager;

  /// No description provided for @folderTitle.
  ///
  /// In en, this message translates to:
  /// **'Folder Manager'**
  String get folderTitle;

  /// No description provided for @folderEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get folderEmptyTitle;

  /// No description provided for @folderEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Folders are created automatically per client as certificates are issued.'**
  String get folderEmptyBody;

  /// No description provided for @folderLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load folders.'**
  String get folderLoadFailed;

  /// No description provided for @folderRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get folderRetry;

  /// No description provided for @folderIsiKosong.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty.'**
  String get folderIsiKosong;

  /// No description provided for @folderJumlahFolder.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} folder{jumlah, plural, =1{} other{s}}'**
  String folderJumlahFolder(int jumlah);

  /// No description provided for @folderJumlahFile.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} file{jumlah, plural, =1{} other{s}}'**
  String folderJumlahFile(int jumlah);

  /// No description provided for @folderOtomatis.
  ///
  /// In en, this message translates to:
  /// **'Created automatically'**
  String get folderOtomatis;

  /// No description provided for @folderUnduh.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get folderUnduh;

  /// No description provided for @folderSertifikatBelumSiap.
  ///
  /// In en, this message translates to:
  /// **'The certificate PDF is still being generated.'**
  String get folderSertifikatBelumSiap;

  /// No description provided for @folderUnduhGagal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download: {pesan}'**
  String folderUnduhGagal(String pesan);

  /// No description provided for @notifTandaiSemua.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifTandaiSemua;

  /// No description provided for @notifSemuaDibaca.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read.'**
  String get notifSemuaDibaca;

  /// No description provided for @notifKategoriJatuhTempo.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get notifKategoriJatuhTempo;

  /// No description provided for @notifKategoriMenungguApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get notifKategoriMenungguApproval;

  /// No description provided for @notifKategoriDisetujui.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get notifKategoriDisetujui;

  /// No description provided for @notifKategoriPerluRevisi.
  ///
  /// In en, this message translates to:
  /// **'Needs revision'**
  String get notifKategoriPerluRevisi;

  /// No description provided for @notifKategoriSertifikat.
  ///
  /// In en, this message translates to:
  /// **'Certificate issued'**
  String get notifKategoriSertifikat;

  /// No description provided for @notifKategoriUmum.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get notifKategoriUmum;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
