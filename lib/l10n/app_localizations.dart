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

  /// No description provided for @snackAddDeviceSoon.
  ///
  /// In en, this message translates to:
  /// **'Adding devices is planned for week 3.'**
  String get snackAddDeviceSoon;

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

  /// No description provided for @profMasterData.
  ///
  /// In en, this message translates to:
  /// **'Company & Customer Master Data'**
  String get profMasterData;

  /// No description provided for @profMasterDataSub.
  ///
  /// In en, this message translates to:
  /// **'Planned for week 2'**
  String get profMasterDataSub;

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

  /// No description provided for @equipmentSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search device name or serial number'**
  String get equipmentSearchHint;

  /// No description provided for @equipmentCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get equipmentCategoryAll;

  /// No description provided for @equipmentStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get equipmentStatusAll;

  /// No description provided for @equipmentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the device list.'**
  String get equipmentLoadFailed;

  /// No description provided for @equipmentNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get equipmentNoResultsTitle;

  /// No description provided for @equipmentNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different keyword or filter.'**
  String get equipmentNoResultsBody;

  /// No description provided for @equipmentDueDatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get equipmentDueDatePrefix;

  /// No description provided for @equipmentFormTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get equipmentFormTitleAdd;

  /// No description provided for @equipmentFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get equipmentFormTitleEdit;

  /// No description provided for @equipmentSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Device Identity'**
  String get equipmentSectionIdentity;

  /// No description provided for @equipmentSectionAdditional.
  ///
  /// In en, this message translates to:
  /// **'Additional Details (Optional)'**
  String get equipmentSectionAdditional;

  /// No description provided for @equipmentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get equipmentNameLabel;

  /// No description provided for @equipmentNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mitutoyo Caliper'**
  String get equipmentNameHint;

  /// No description provided for @equipmentNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Device name is required.'**
  String get equipmentNameRequired;

  /// No description provided for @equipmentSerialLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get equipmentSerialLabel;

  /// No description provided for @equipmentSerialHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MT-500-196-30'**
  String get equipmentSerialHint;

  /// No description provided for @equipmentSerialRequired.
  ///
  /// In en, this message translates to:
  /// **'Serial number is required.'**
  String get equipmentSerialRequired;

  /// No description provided for @equipmentBrandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get equipmentBrandLabel;

  /// No description provided for @equipmentBrandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mitutoyo'**
  String get equipmentBrandHint;

  /// No description provided for @equipmentBrandRequired.
  ///
  /// In en, this message translates to:
  /// **'Brand is required.'**
  String get equipmentBrandRequired;

  /// No description provided for @equipmentCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get equipmentCategoryLabel;

  /// No description provided for @equipmentCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a category first.'**
  String get equipmentCategoryRequired;

  /// No description provided for @equipmentStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get equipmentStatusLabel;

  /// No description provided for @equipmentStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get equipmentStatusActive;

  /// No description provided for @equipmentStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get equipmentStatusInactive;

  /// No description provided for @equipmentToleranceLabel.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get equipmentToleranceLabel;

  /// No description provided for @equipmentToleranceHint.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get equipmentToleranceHint;

  /// No description provided for @equipmentCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get equipmentCustomerLabel;

  /// No description provided for @equipmentCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer'**
  String get equipmentCustomerHint;

  /// No description provided for @equipmentCustomerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer ID (optional)'**
  String get equipmentCustomerIdLabel;

  /// No description provided for @equipmentCustomerIdHelper.
  ///
  /// In en, this message translates to:
  /// **'Only admins can search customers by name. Fill in the ID if you know it, or leave it blank for now.'**
  String get equipmentCustomerIdHelper;

  /// No description provided for @equipmentCustomerNone.
  ///
  /// In en, this message translates to:
  /// **'No customer yet'**
  String get equipmentCustomerNone;

  /// No description provided for @equipmentSubmitAdd.
  ///
  /// In en, this message translates to:
  /// **'SAVE DEVICE'**
  String get equipmentSubmitAdd;

  /// No description provided for @equipmentSubmitEdit.
  ///
  /// In en, this message translates to:
  /// **'SAVE CHANGES'**
  String get equipmentSubmitEdit;

  /// No description provided for @equipmentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get equipmentDelete;

  /// No description provided for @equipmentDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this device?'**
  String get equipmentDeleteConfirmTitle;

  /// No description provided for @equipmentDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The device and its calibration history can\'t be recovered.'**
  String get equipmentDeleteConfirmBody;

  /// No description provided for @equipmentDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get equipmentDeleteConfirmAction;

  /// No description provided for @equipmentSaved.
  ///
  /// In en, this message translates to:
  /// **'Device saved successfully.'**
  String get equipmentSaved;

  /// No description provided for @equipmentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Device deleted successfully.'**
  String get equipmentDeleted;

  /// No description provided for @equipmentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {message}'**
  String equipmentSaveFailed(String message);

  /// No description provided for @equipmentDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {message}'**
  String equipmentDeleteFailed(String message);

  /// No description provided for @historyPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration History'**
  String get historyPlaceholderTitle;

  /// No description provided for @historyPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'History of calibration sessions & issued certificates. Planned for week 9.'**
  String get historyPlaceholderBody;

  /// No description provided for @notificationPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationPlaceholderTitle;

  /// No description provided for @notificationPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Reminders for devices approaching their calibration due date. Planned for week 9.'**
  String get notificationPlaceholderBody;
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
