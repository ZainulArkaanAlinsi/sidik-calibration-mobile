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
  String get dashLabScope => 'Lab-wide';

  @override
  String get dashTotalCerts => 'Certificates';

  @override
  String dashCertsThisMonthSub(int count) {
    return '$count this month';
  }

  @override
  String get dashCalibrationMine => 'My calibrations';

  @override
  String get dashCalibrationLab => 'Lab calibrations';

  @override
  String dashTrendUp(int count) {
    return '$count more completed than last period';
  }

  @override
  String dashTrendDown(int count) {
    return '$count fewer completed than last period';
  }

  @override
  String get dashTrendFlat => 'Same as last period';

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
  String get profOrgData => 'Organization Data';

  @override
  String get profOrgDataSub =>
      'Name, address & accreditation no. printed on certificates';

  @override
  String get profCustomers => 'Customers';

  @override
  String get profCustomersSub => 'Manage the lab\'s customer list';

  @override
  String get profStandards => 'Reference Standards';

  @override
  String get profStandardsSub =>
      'Manage the lab\'s reference/standard equipment';

  @override
  String get profArsip => 'Archive';

  @override
  String get profArsipSub => 'Company folders, instruments & certificate files';

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
  String get equipLoadFailed => 'Couldn\'t load the device list.';

  @override
  String get equipSearchHint => 'Search device name';

  @override
  String get equipFilterKategoriHint => 'Category';

  @override
  String get equipFilterStatusHint => 'Status';

  @override
  String get equipFilterSemua => 'All';

  @override
  String get equipStatusAktif => 'Active';

  @override
  String get equipStatusOverdue => 'Overdue';

  @override
  String get equipStatusNonaktif => 'Inactive';

  @override
  String get equipEmptyTitle => 'No devices yet';

  @override
  String get equipEmptyBody => 'Add your first device using the button below.';

  @override
  String get equipRetry => 'RETRY';

  @override
  String get equipAdd => 'ADD DEVICE';

  @override
  String get equipEdit => 'Edit device';

  @override
  String get equipMuatLebihBanyak => 'LOAD MORE';

  @override
  String get equipDeleteConfirmTitle => 'Delete device?';

  @override
  String equipDeleteConfirmBody(String nama) {
    return '\"$nama\" will be permanently deleted.';
  }

  @override
  String equipDeleteFailed(String pesan) {
    return 'Couldn\'t delete: $pesan';
  }

  @override
  String get equipNamaAlat => 'Device name';

  @override
  String get equipSerialNumber => 'Serial number';

  @override
  String get equipKategori => 'Category';

  @override
  String get equipKategoriHint => 'Choose a device category';

  @override
  String get equipPelanggan => 'Customer';

  @override
  String get equipPelangganHint => 'Choose a customer';

  @override
  String get equipPelangganCariHint => 'Search company name';

  @override
  String get equipPelangganGagal => 'Couldn\'t load the customer list.';

  @override
  String get equipPelangganKosong => 'No customer found.';

  @override
  String get equipNamaAlatKemampuan => 'Device Type (Calibration Capability)';

  @override
  String get equipNamaAlatKemampuanHint =>
      'Choose device type (optional, for accurate CMC)';

  @override
  String get equipNamaAlatKemampuanKosong =>
      'This category has no calibration capabilities yet';

  @override
  String get equipNamaAlatKemampuanGagal =>
      'Couldn\'t load calibration capabilities.';

  @override
  String get equipCatatan => 'Notes';

  @override
  String get equipMerk => 'Brand';

  @override
  String get equipModel => 'Model/Type';

  @override
  String get equipNoIdentifikasi => 'Identification no.';

  @override
  String get equipRangeMin => 'Range min.';

  @override
  String get equipRangeMax => 'Range max.';

  @override
  String get equipSatuan => 'Unit';

  @override
  String get equipResolusi => 'Resolution';

  @override
  String get equipToleransi => 'Tolerance';

  @override
  String get equipToleransiWajib => 'Tolerance is required.';

  @override
  String get equipToleransiWajibHint =>
      'A device without a tolerance can\'t be calibrated — there\'s no way to decide PASS/FAIL.';

  @override
  String get equipLokasi => 'Location';

  @override
  String get equipStatus => 'Status';

  @override
  String get equipSave => 'SAVE';

  @override
  String equipSaveFailed(String pesan) {
    return 'Couldn\'t save: $pesan';
  }

  @override
  String get historyEmptyTitle => 'No history yet';

  @override
  String get historyEmptyBody =>
      'Completed calibration sessions will show up here.';

  @override
  String get historyLoadFailed => 'Couldn\'t load history.';

  @override
  String get historySessionExpired =>
      'Your session expired. Please sign in again.';

  @override
  String get historyRetry => 'RETRY';

  @override
  String historyCertNumber(String nomor) {
    return 'Certificate no. $nomor';
  }

  @override
  String get historyStatusPass => 'PASS';

  @override
  String get historyStatusFail => 'FAIL';

  @override
  String get historyStatusDraft => 'Draft';

  @override
  String get historyStatusMenungguApproval => 'Pending approval';

  @override
  String get historyStatusPerluRevisi => 'Needs revision';

  @override
  String get historyApprove => 'APPROVE';

  @override
  String get historyReject => 'REJECT';

  @override
  String historyApproveFailed(String pesan) {
    return 'Couldn\'t approve: $pesan';
  }

  @override
  String get historyRejectDialogTitle => 'Reject this calibration session?';

  @override
  String get historyRejectDialogHint =>
      'Rejection reason (required, the technician will see this)';

  @override
  String get historyRejectDialogSubmit => 'REJECT SESSION';

  @override
  String get historyRejectDialogCancel => 'Cancel';

  @override
  String get historyRejectDialogEmpty => 'Rejection reason is required.';

  @override
  String historyRejectFailed(String pesan) {
    return 'Couldn\'t reject: $pesan';
  }

  @override
  String historyCatatanRevisi(String catatan) {
    return 'Revision note: $catatan';
  }

  @override
  String get historyViewCertificate => 'View certificate';

  @override
  String get certTitle => 'Certificate';

  @override
  String get certLoadFailed => 'Couldn\'t load certificate.';

  @override
  String get certStatusMenungguGenerate => 'Still generating, hang on';

  @override
  String get certStatusGagal => 'Generation failed';

  @override
  String get certRetry => 'RETRY GENERATE';

  @override
  String get certOpenPdf => 'VIEW PDF';

  @override
  String certOpenFailed(String message) {
    return 'No app found to open the PDF: $message';
  }

  @override
  String get certBelumTerbit => 'Certificate not issued yet';

  @override
  String certQrToken(String token) {
    return 'QR token: $token';
  }

  @override
  String get certRingkasanTitle => 'Result Summary';

  @override
  String get certIdentitasTitle => 'Session Details';

  @override
  String get certTanggalKalibrasi => 'Calibration date';

  @override
  String get certTeknisi => 'Technician';

  @override
  String get certLokasi => 'Calibration location';

  @override
  String get certMetode => 'Calibration method';

  @override
  String get certReportTitle => 'Calibration Report';

  @override
  String get certColStandard => 'Standard Value';

  @override
  String get certColUut => 'Unit Under Test';

  @override
  String get certColKoreksi => 'Correction';

  @override
  String get certColU95 => 'U95% (±)';

  @override
  String get certStandarDipakai => 'Standard used';

  @override
  String get certBelumDihitung =>
      'The measurement points haven\'t been calculated by the backend yet, so the report table can\'t be shown.';

  @override
  String get certDisclaimer =>
      '— Calibration results are not to be announced and only apply to related tools —';

  @override
  String get certLihatDetail => 'VIEW CALCULATION DETAIL';

  @override
  String get detailTitle => 'Calibration Result Detail';

  @override
  String get detailLoadFailed => 'Couldn\'t load calibration detail.';

  @override
  String detailNomorSesi(String nomor) {
    return 'Session no. $nomor';
  }

  @override
  String get detailKondisiLingkungan => 'Environmental Condition & Standard';

  @override
  String get detailStandarAcuan => 'Reference standard';

  @override
  String get detailSuhuRuang => 'Room temperature';

  @override
  String get detailKelembaban => 'Humidity';

  @override
  String get detailLokasi => 'Calibration location';

  @override
  String get detailLokasiLab => 'At the lab';

  @override
  String get detailLokasiOnsite => 'At customer site (onsite)';

  @override
  String get detailTitikUkurTitle => 'Measurement Points';

  @override
  String get detailBelumDihitung =>
      'This session hasn\'t been calculated by the server yet — results will show up once it\'s processed.';

  @override
  String get detailLihatSertifikat => 'VIEW CERTIFICATE';

  @override
  String detailTitikLabel(int index, String nilai) {
    return 'Point $index · $nilai';
  }

  @override
  String get detailRataRata => 'Average';

  @override
  String get detailError => 'Error';

  @override
  String get detailKoreksi => 'Correction';

  @override
  String get detailStandarDeviasi => 'Standard deviation';

  @override
  String get detailMaxStdev => 'Max STDEV';

  @override
  String get detailMaxStdevSebelum => 'Before adjustment';

  @override
  String get detailTypeA => 'Type A';

  @override
  String get detailTypeB => 'Type B';

  @override
  String get detailKomponenTypeB => 'Type B component breakdown';

  @override
  String get detailToleransi => 'Tolerance';

  @override
  String get detailKetidakpastianGabungan => 'Combined uncertainty (uc)';

  @override
  String get detailFaktorCakupan => 'Coverage factor (k)';

  @override
  String get detailU95 => 'Expanded uncertainty (U95%)';

  @override
  String get detailAwal => 'Start';

  @override
  String get detailAkhir => 'End';

  @override
  String get detailNilaiTerkoreksi => 'Corrected value';

  @override
  String get detailU95Lingkungan => 'U95%';

  @override
  String get detailThermohygro => 'Thermohygrometer';

  @override
  String get detailMetode => 'Method';

  @override
  String get detailSuhuLarutan => 'Solution temp.';

  @override
  String get detailSebelumAdjustment => 'Before adjustment (as found)';

  @override
  String get detailSesudahAdjustment => 'After adjustment (certified)';

  @override
  String get detailAsFoundCatatan =>
      'Documents the state the instrument arrived in — not part of the certified result.';

  @override
  String get detailPerluVerifikasi =>
      'Some OCR readings still need confirming — this session can\'t be approved yet.';

  @override
  String get arsipTitle => 'Archive';

  @override
  String get arsipCariPerusahaan => 'Search company...';

  @override
  String get arsipPerusahaanKosong => 'No companies yet.';

  @override
  String get arsipFolderKosong => 'This folder is empty.';

  @override
  String get arsipLoadGagal => 'Couldn\'t load the archive.';

  @override
  String get arsipRetry => 'RETRY';

  @override
  String arsipRingkasPerusahaan(int alat, int sertifikat) {
    return '$alat instruments · $sertifikat certificates';
  }

  @override
  String arsipRingkasFolder(int subfolder, int berkas) {
    return '$subfolder folders · $berkas files';
  }

  @override
  String get arsipFolderBaru => 'New folder';

  @override
  String get arsipNamaFolder => 'Folder name';

  @override
  String get arsipNamaFolderHint => 'e.g. 2026';

  @override
  String get arsipBuat => 'CREATE';

  @override
  String get arsipBatal => 'CANCEL';

  @override
  String get arsipSimpan => 'SAVE';

  @override
  String get arsipGantiNama => 'Rename';

  @override
  String get arsipHapus => 'Delete';

  @override
  String get arsipHapusJudul => 'Delete this folder?';

  @override
  String arsipHapusIsi(String nama) {
    return 'Folder \"$nama\" will be removed. Only empty folders can be deleted.';
  }

  @override
  String get arsipTakBisaHapus => 'Move or delete its contents first.';

  @override
  String get arsipFolderSistem => 'Company folder — managed automatically.';

  @override
  String get arsipBerkasTanpaSertifikat => 'No certificate yet';

  @override
  String get arsipDibuat => 'Folder created.';

  @override
  String get arsipDiubah => 'Folder renamed.';

  @override
  String get arsipDihapus => 'Folder deleted.';

  @override
  String get orgTitle => 'Organization Data';

  @override
  String get orgNama => 'Company name';

  @override
  String get orgAlamat => 'Address';

  @override
  String get orgTelepon => 'Phone';

  @override
  String get orgEmail => 'Email';

  @override
  String get orgNoAkreditasi => 'Accreditation no.';

  @override
  String get orgAkreditasi => 'Accreditation Status';

  @override
  String get orgAkreditasiBerlaku => 'Valid';

  @override
  String get orgAkreditasiKadaluarsa => 'Expired';

  @override
  String get orgStandarAkreditasi => 'Accreditation standard';

  @override
  String get orgStandarAkreditasiHint => 'e.g. ISO/IEC 17025:2017';

  @override
  String get orgAkreditasiMulai => 'Valid from';

  @override
  String get orgAkreditasiBerakhir => 'Valid until';

  @override
  String get orgPilihTanggal => 'Choose a date';

  @override
  String get orgSave => 'SAVE';

  @override
  String get orgSaved => 'Organization data saved.';

  @override
  String orgSaveFailed(String pesan) {
    return 'Couldn\'t save: $pesan';
  }

  @override
  String get orgLoadFailed => 'Couldn\'t load organization data.';

  @override
  String get orgRetry => 'RETRY';

  @override
  String get standarTitle => 'Reference Standards';

  @override
  String get standarLoadFailed => 'Couldn\'t load reference standards.';

  @override
  String get standarAdd => 'ADD STANDARD';

  @override
  String get standarEdit => 'Edit standard';

  @override
  String get standarEmptyTitle => 'No reference standards yet';

  @override
  String get standarEmptyBody =>
      'Add your first standard using the button below.';

  @override
  String get standarRetry => 'RETRY';

  @override
  String get standarBerlaku => 'Valid';

  @override
  String get standarKadaluarsa => 'Expired';

  @override
  String get standarDeleteConfirmTitle => 'Delete reference standard?';

  @override
  String standarDeleteConfirmBody(String nama) {
    return '\"$nama\" will be permanently deleted.';
  }

  @override
  String standarDeleteFailed(String pesan) {
    return 'Couldn\'t delete: $pesan';
  }

  @override
  String standarSaveFailed(String pesan) {
    return 'Couldn\'t save: $pesan';
  }

  @override
  String get standarFaktorCakupanInvalid =>
      'Coverage factor (k) must be at least 1 — usually 2.';

  @override
  String get standarNama => 'Standard name';

  @override
  String get standarMerk => 'Brand';

  @override
  String get standarModel => 'Model/Type';

  @override
  String get standarSerialNumber => 'Serial number';

  @override
  String get standarNoSertifikat => 'Certificate no.';

  @override
  String get standarTertelusurKe => 'Traceable to';

  @override
  String get standarTertelusurKeHint => 'e.g. SNSU-BSN';

  @override
  String get standarBerlakuSampai => 'Valid until';

  @override
  String get standarKetidakpastianTitle =>
      'Uncertainty (from the standard\'s certificate)';

  @override
  String get standarKetidakpastian => 'Uncertainty (expanded)';

  @override
  String get standarSatuanKetidakpastian => 'Unit';

  @override
  String get standarFaktorCakupan => 'Coverage factor (k)';

  @override
  String get standarDrift => 'Annual drift';

  @override
  String get standarSave => 'SAVE';

  @override
  String get custTitle => 'Customers';

  @override
  String get custSearchHint => 'Search customer name';

  @override
  String get custEmptyTitle => 'No customers yet';

  @override
  String get custEmptyBody => 'Add your first customer using the button below.';

  @override
  String get custLoadFailed => 'Couldn\'t load customers.';

  @override
  String get custRetry => 'RETRY';

  @override
  String get custAdd => 'ADD CUSTOMER';

  @override
  String get custEdit => 'Edit customer';

  @override
  String get custNama => 'Customer name';

  @override
  String get custAlamat => 'Address';

  @override
  String get custContactPerson => 'Contact person';

  @override
  String get custTelepon => 'Phone';

  @override
  String get custEmail => 'Email';

  @override
  String get custSave => 'SAVE';

  @override
  String get custCancel => 'Cancel';

  @override
  String get custDelete => 'Delete';

  @override
  String get custDeleteConfirmTitle => 'Delete customer?';

  @override
  String custDeleteConfirmBody(String nama) {
    return '\"$nama\" will be permanently deleted.';
  }

  @override
  String custDeleteFailed(String pesan) {
    return 'Couldn\'t delete: $pesan';
  }

  @override
  String custSaveFailed(String pesan) {
    return 'Couldn\'t save: $pesan';
  }

  @override
  String custEquipmentCount(int jumlah) {
    return '$jumlah devices';
  }

  @override
  String get custFieldRequired => 'Required.';

  @override
  String get calibTitle => 'Calibration Input';

  @override
  String get calibKategori => 'Category';

  @override
  String get calibKategoriHint => 'Choose a device category';

  @override
  String get calibAlat => 'Device';

  @override
  String get calibAlatHint => 'Choose a device';

  @override
  String get calibAlatKosong => 'No devices in this category.';

  @override
  String get calibStandar => 'Reference Standard';

  @override
  String get calibStandarHint => 'Choose a reference standard';

  @override
  String get calibStandarKadaluarsa => 'expired';

  @override
  String get calibTanggal => 'Calibration date';

  @override
  String get calibNomorOrder => 'Order number';

  @override
  String get calibNomorOrderHint => 'e.g. 2405.13.A (optional)';

  @override
  String get calibTanggalTerima => 'Equipment received date';

  @override
  String get calibLokasi => 'Calibration location';

  @override
  String get calibLokasiLab => 'At the lab';

  @override
  String get calibLokasiOnsite => 'At customer site (onsite)';

  @override
  String get calibSuhuRuang => 'Room temperature (°C)';

  @override
  String get calibKelembaban => 'Humidity (%)';

  @override
  String calibTitikUkur(int index) {
    return 'Measurement point $index';
  }

  @override
  String get calibNilaiTarget => 'Target value';

  @override
  String get calibSatuan => 'Unit';

  @override
  String calibPembacaan(int index) {
    return 'Reading $index';
  }

  @override
  String get calibTambahTitik => 'ADD MEASUREMENT POINT';

  @override
  String get calibHapusTitik => 'Remove measurement point';

  @override
  String get calibTambahPembacaan => '+ Add reading';

  @override
  String get calibValidasiKategori => 'Choose a category first.';

  @override
  String get calibValidasiAlat => 'Choose a device first.';

  @override
  String get calibValidasiStandar => 'Choose a reference standard first.';

  @override
  String get calibValidasiAngka => 'Enter a valid number.';

  @override
  String get calibValidasiPembacaan =>
      'Each measurement point needs at least 2 numeric readings.';

  @override
  String get calibSimpanDraft => 'SAVE DRAFT';

  @override
  String get calibKirimApproval => 'SUBMIT FOR APPROVAL';

  @override
  String get calibBerhasilDraft => 'Calibration draft saved.';

  @override
  String get calibBerhasilApproval =>
      'Calibration session submitted for approval.';

  @override
  String calibGagal(String pesan) {
    return 'Couldn\'t save: $pesan';
  }

  @override
  String get calibLoadPilihanGagal =>
      'Couldn\'t load category/standard options.';

  @override
  String get calibRetry => 'RETRY';

  @override
  String get calibPilihKategoriTitle => 'Choose Equipment Category';

  @override
  String get calibPilihKategoriSubtitle =>
      'Pick the measurement group first, then the specific instrument type.';

  @override
  String get calibKategoriKosong => 'No categories yet.';

  @override
  String calibJumlahAlat(int jumlah) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$jumlah instrument type$_temp0';
  }

  @override
  String get calibPilihInstrumenTitle => 'Choose Instrument Type';

  @override
  String get calibInstrumenKosong =>
      'This category doesn\'t have any calibration capability data yet.';

  @override
  String get calibInstrumenMetodeLabel => 'Method';

  @override
  String get calibCariInstrumenHint => 'Search instrument type...';

  @override
  String get calibInstrumenTidakDitemukan => 'No matching instrument type.';

  @override
  String get phCalibTitle => 'pH Meter Calibration';

  @override
  String get phCalibThermohygro => 'Thermohygrometer used';

  @override
  String get phCalibThermohygroHint => 'e.g. TH-3';

  @override
  String get phCalibThermohygroCustom => 'Other (enter manually)';

  @override
  String get phCalibStandarSesi => 'Reference Standard (Thermometer & Sensor)';

  @override
  String get phCalibStandarSesiHint =>
      'Used for environmental conditions (temp/humidity)';

  @override
  String get phCalibStandarBuffer => 'Buffer standard for this point';

  @override
  String get phCalibStandarBufferHint => 'Choose a buffer solution';

  @override
  String get phCalibValidasiStandarBuffer =>
      'Choose a buffer standard for every point (4, 7, 10) first.';

  @override
  String get phCalibKondisiLingkungan => 'Environmental Conditions';

  @override
  String get phCalibSuhuAwal => 'Start temperature (°C)';

  @override
  String get phCalibSuhuAkhir => 'End temperature (°C)';

  @override
  String get phCalibKelembabanAwal => 'Start humidity (%)';

  @override
  String get phCalibKelembabanAkhir => 'End humidity (%)';

  @override
  String phCalibTitikBuffer(String label) {
    return 'pH $label buffer';
  }

  @override
  String get phCalibNilaiStandar => 'Reference value (temp-corrected)';

  @override
  String get phCalibNilaiStandarHelper =>
      'Copy from the worksheet — the buffer value after temperature correction, not the round number.';

  @override
  String get phCalibNilaiStandarSebelum => 'As-found reference value';

  @override
  String get phCalibSebelumAdjustment => 'Before adjustment (as found)';

  @override
  String get phCalibSesudahAdjustment => 'After adjustment (as left)';

  @override
  String get phCalibIdMerk => 'Brand';

  @override
  String get phCalibIdType => 'Type';

  @override
  String get phCalibIdNoSeri => 'Serial no.';

  @override
  String get phCalibIdRentang => 'Measuring range';

  @override
  String get phCalibIdResolusi => 'Resolution';

  @override
  String get phCalibIdCustomer => 'Customer name';

  @override
  String get phCalibFotoMembaca => 'Reading the numbers from your photo…';

  @override
  String get phCalibIdentitasCustomer => 'Customer Details';

  @override
  String get phCalibIdNamaAlat => 'Device name';

  @override
  String get phCalibIdKapasitasMax => 'Max. capacity';

  @override
  String get phCalibIdAlamatCustomer => 'Customer address';

  @override
  String get phCalibIdCertificateNumber => 'Certificate no.';

  @override
  String get phCalibIdOrderNumber => 'Order no.';

  @override
  String get phCalibIdTechnicianId => 'Technician ID';

  @override
  String get phCalibIdCalibrationMethod => 'Calibration method';

  @override
  String get phCalibPengesahan => 'Authorisation';

  @override
  String get phCalibIssuanceDate => 'Issuance date';

  @override
  String get phCalibCalculatedBy => 'Calculated by (initials)';

  @override
  String get phCalibCalculatedByHint => 'e.g. NR';

  @override
  String get phCalibSignedBy => 'Signed by (full name)';

  @override
  String get phCalibSignedByHint => 'e.g. Alex Misramto';

  @override
  String get phCalibLiveJudul => 'Point at the table';

  @override
  String get phCalibLivePetunjuk =>
      'Point the camera at the worksheet table. Numbers that are recognised will float on screen.';

  @override
  String get phCalibLivePakai => 'USE THESE NUMBERS';

  @override
  String get phCalibLiveTanpaKamera =>
      'No camera found on this phone. You can still type the values in.';

  @override
  String get phCalibCaraJudul => 'How do you want to fill this in?';

  @override
  String get phCalibCaraSub =>
      'Pick once. You can still use the camera button later on the data page.';

  @override
  String get phCalibCaraFoto => 'Photograph the worksheet';

  @override
  String get phCalibCaraFotoKeterangan =>
      'Snap the filled-in table — the fields populate automatically';

  @override
  String get phCalibCaraManual => 'Type it in';

  @override
  String get phCalibCaraManualKeterangan => 'Fill each field yourself';

  @override
  String get phCalibCaraCatatan =>
      'Values from a photo must still be checked before submitting. An issued certificate cannot be changed.';

  @override
  String get phCalibScanTooltip => 'Photograph the pH meter display';

  @override
  String get phCalibScanGagal =>
      'Couldn\'t read the number clearly. Try a closer photo, or type it in.';

  @override
  String get phCalibScanError => 'Couldn\'t open the camera.';

  @override
  String get phCalibFotoTabel => 'PHOTO TABLE';

  @override
  String get phCalibFotoTabelSesudah => 'After adjustment';

  @override
  String get phCalibFotoTabelSebelum => 'Before adjustment';

  @override
  String get phCalibFotoTabelJudul => 'Which table are you photographing?';

  @override
  String get phCalibFotoTabelInfo =>
      'One shot fills the whole table for all three buffers. Cells you already filled are never overwritten — reshoot as many times as you need.';

  @override
  String phCalibFotoTabelHasil(int terisi, int total) {
    return '$terisi of $total cells filled.';
  }

  @override
  String get phCalibFotoTabelTakTerbaca =>
      'No numbers could be read at all. The photo is probably dark, blurry, or too far away — try closer and brighter. You can still type the values in.';

  @override
  String phCalibFotoTabelPosisiKacau(int jumlah) {
    return '$jumlah numbers were read, but they don\'t line up as a table. Usually the photo is skewed or shows the whole sheet — try photographing just the TABLE, straight from above. You can still type the values in.';
  }

  @override
  String get phCalibFotoTabelKosong =>
      'Couldn\'t read the numbers yet. Tips: photograph just the TABLE (not the whole sheet), straight from above, even light with no hand shadow. Or type it in.';

  @override
  String get phCalibFotoTabelSisa =>
      'Empty cells: type them in or reshoot — nothing you already entered will be replaced.';

  @override
  String get phCalibOcrBelumDikonfirmasi => 'From camera — please check';

  @override
  String get phCalibOcrKonfirmasi => 'CONFIRM';

  @override
  String phCalibPembacaanKe(int index) {
    return 'Reading $index';
  }

  @override
  String get phCalibSuhu => 'Temp.';

  @override
  String get phCalibValidasiLingkungan =>
      'Fill in the environmental conditions (temperature & humidity) first.';

  @override
  String phCalibValidasiPembacaan(int minimum) {
    return 'Each buffer point needs at least $minimum valid after-adjustment readings.';
  }

  @override
  String get phCalibValidasiNilaiAcuan =>
      'Fill in the temperature-corrected reference value for every buffer point.';

  @override
  String get phCalibLangkahIdentitas => 'Identity & conditions';

  @override
  String get phCalibLangkahHasil => 'Calibration results';

  @override
  String phCalibLangkahKe(int nomor, int total) {
    return 'Step $nomor of $total';
  }

  @override
  String get phCalibIdentitasAlat => 'Instrument Identity';

  @override
  String get phCalibPengerjaan => 'Job Details';

  @override
  String get phCalibPelangganOtomatis =>
      'Customer details follow the selected instrument — the certificate is filed under the right company automatically.';

  @override
  String get phCalibKoreksiSuhu => 'Temperature correction (°C)';

  @override
  String get phCalibKoreksiKelembaban => 'Humidity correction (%)';

  @override
  String get phCalibU95Suhu => 'Temperature U95%';

  @override
  String get phCalibU95Kelembaban => 'Humidity U95%';

  @override
  String get phCalibDariSertifikatTh =>
      'From the thermohygrometer certificate — the server derives the environmental U95% from these.';

  @override
  String get phCalibLanjutkan => 'CONTINUE';

  @override
  String get phCalibKembali => 'BACK';

  @override
  String get phCalibDisertifikasi => 'Certified';

  @override
  String get phCalibDokumentasi => 'Documentation';

  @override
  String get phCalibDihitungServer =>
      'Averages, uncertainty budget, environmental U95% and the PASS/FAIL call are all computed by the server.';

  @override
  String get phCalibOpsional => 'Optional';

  @override
  String get notifEmptyTitle => 'No notifications yet';

  @override
  String get notifEmptyBody =>
      'Due-date reminders & approval updates will show up here.';

  @override
  String get notifLoadFailed => 'Couldn\'t load notifications.';

  @override
  String get notifSessionExpired =>
      'Your session expired. Please sign in again.';

  @override
  String get notifRetry => 'RETRY';

  @override
  String get notifMarkedRead => 'Marked as read.';

  @override
  String get notifTypeDueDate => 'Due date';

  @override
  String get notifTypeApproval => 'Approval';

  @override
  String get notifTypeRevision => 'Revision';

  @override
  String get teknisiTitle => 'Technicians';

  @override
  String get teknisiFilterSemua => 'All';

  @override
  String get teknisiFilterPending => 'Pending';

  @override
  String get teknisiFilterAktif => 'Active';

  @override
  String get teknisiFilterNonaktif => 'Inactive';

  @override
  String get teknisiKosong => 'No accounts in this filter yet.';

  @override
  String get teknisiLoadGagal => 'Could not load accounts.';

  @override
  String get teknisiRetry => 'Try again';

  @override
  String get teknisiSetujui => 'Approve';

  @override
  String get teknisiTolak => 'Deactivate';

  @override
  String get teknisiResetPassword => 'Reset password';

  @override
  String get teknisiPilihRole => 'Choose a role for this account';

  @override
  String get teknisiPilihRoleBatal => 'Cancel';

  @override
  String get teknisiDisetujui => 'Account approved.';

  @override
  String get teknisiDitolak => 'Account deactivated.';

  @override
  String get teknisiPasswordDireset =>
      'Password reset. Tell the new password to the account owner directly.';

  @override
  String get teknisiResetPasswordJudul => 'Reset account password';

  @override
  String teknisiResetPasswordIsi(String nama) {
    return 'Set a new password for $nama. Their sessions on every device will be revoked.';
  }

  @override
  String get teknisiResetPasswordLabel => 'New password';

  @override
  String get teknisiResetPasswordHelper =>
      'At least 8 characters. The backend sends no email — tell them directly.';

  @override
  String get teknisiResetPasswordTerlaluPendek =>
      'Password must be at least 8 characters.';

  @override
  String get teknisiGagal => 'Action failed. Please try again.';

  @override
  String get teknisiKonfirmTolakJudul => 'Deactivate this account?';

  @override
  String get teknisiKonfirmTolakIsi =>
      'They will be signed out of every device and can no longer sign in. Past calibration records stay intact.';

  @override
  String get teknisiTanpaEmployeeId => 'No employee ID';

  @override
  String get teknisiHanyaAdmin => 'Only admins can manage accounts.';

  @override
  String get menuUtama => 'Main menu';

  @override
  String get menuMasterData => 'Master Data';

  @override
  String get menuPengaturan => 'Settings';

  @override
  String get sheetTutup => 'CLOSE';

  @override
  String get sheetCobaLagi => 'TRY AGAIN';

  @override
  String get sheetKirimBerhasil => 'Sent!';

  @override
  String get sheetKirimBerhasilPesan =>
      'The session is now in the admin approval queue.';

  @override
  String get sheetKirimGagal => 'There is a problem';

  @override
  String get sheetDraftBerhasil => 'Draft saved';

  @override
  String get sheetDraftBerhasilPesan =>
      'You can pick it up again anytime from history.';

  @override
  String get phCalibTitikLengkap => 'This point is complete';

  @override
  String get dashCalibrationDone => 'Calibrations done';

  @override
  String get dashWorkChart => 'Workload trend';

  @override
  String get tugasTitle => 'My Tasks';

  @override
  String get tugasKosong => 'No equipment assigned to you yet.';

  @override
  String get tugasLoadGagal => 'Could not load your task queue.';

  @override
  String get tugasRetry => 'TRY AGAIN';

  @override
  String tugasJumlahAlat(int jumlah) {
    return '$jumlah items';
  }

  @override
  String get tugasTelat => 'Past due date';

  @override
  String get tugasMasuk => 'Received';

  @override
  String get tugasJanji => 'Due';

  @override
  String get tugasBelumDitugaskan => 'Unassigned';

  @override
  String get dashSummaryOrg => 'Organization summary';

  @override
  String get dashSummaryYours => 'Your summary';

  @override
  String get snackAddDeviceSoon => 'Adding devices is planned for week 3.';

  @override
  String get dashStartPhCalibration => 'PH METER CALIBRATION';

  @override
  String get lkTitle => 'Calibration Worksheet';

  @override
  String get lkSubtitleDraft => 'Continue draft';

  @override
  String get lkSubtitleRevisi => 'Revise — returned by admin';

  @override
  String get lkLoadGagal => 'Couldn\'t load the worksheet form.';

  @override
  String get lkRetry => 'RETRY';

  @override
  String get lkPilihAlat => 'Choose equipment';

  @override
  String get lkAlatKosong => 'No equipment available yet.';

  @override
  String get lkBelumPilihAlat =>
      'Choose the equipment first — the identity and owner fields fill in automatically.';

  @override
  String get lkOtomatis => 'Filled automatically';

  @override
  String get lkKosong => '—';

  @override
  String get lkPilihTanggal => 'Choose date';

  @override
  String get lkHapusTanggal => 'Clear date';

  @override
  String get lkRepeat => 'Repeat';

  @override
  String get lkUsageCheckKosong => 'No reference standards in master data yet.';

  @override
  String get lkUsageCheckKeterangan => 'Notes';

  @override
  String get lkStandarPerTitik => 'Buffer standard';

  @override
  String get lkStandarKadaluarsa => 'certificate expired';

  @override
  String get lkPilih => 'Choose';

  @override
  String get lkKirim => 'SUBMIT TO ADMIN';

  @override
  String get lkSimpanDraft => 'SAVE AS DRAFT';

  @override
  String get lkBerhasilKirim => 'Worksheet submitted to admin.';

  @override
  String get lkBerhasilDraft => 'Saved as draft.';

  @override
  String lkGagalKirim(String pesan) {
    return 'Couldn\'t save: $pesan';
  }

  @override
  String get lkSemuaOpsional =>
      'Any field you can\'t fill in the field may be left blank — the worksheet can still be submitted.';

  @override
  String get lkKeluarTanpaSimpan => 'Leave without saving?';

  @override
  String get lkKeluarTanpaSimpanBody => 'What you\'ve typed will be lost.';

  @override
  String get lkKeluarBatal => 'KEEP EDITING';

  @override
  String get lkKeluarLanjut => 'LEAVE';

  @override
  String lkSuhuDiLuarRentang(String min, String max) {
    return 'Outside this room\'s range ($min–$max).';
  }

  @override
  String get navFolderManager => 'Folders';

  @override
  String get folderTitle => 'Folder Manager';

  @override
  String get folderEmptyTitle => 'No folders yet';

  @override
  String get folderEmptyBody =>
      'Folders are created automatically per client as certificates are issued.';

  @override
  String get folderLoadFailed => 'Couldn\'t load folders.';

  @override
  String get folderRetry => 'RETRY';

  @override
  String get folderIsiKosong => 'This folder is empty.';

  @override
  String folderJumlahFolder(int jumlah) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$jumlah folder$_temp0';
  }

  @override
  String folderJumlahFile(int jumlah) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$jumlah file$_temp0';
  }

  @override
  String get folderOtomatis => 'Created automatically';

  @override
  String get folderUnduh => 'Download';

  @override
  String get folderSertifikatBelumSiap =>
      'The certificate PDF is still being generated.';

  @override
  String folderUnduhGagal(String pesan) {
    return 'Couldn\'t download: $pesan';
  }

  @override
  String get notifTandaiSemua => 'Mark all as read';

  @override
  String get notifSemuaDibaca => 'All notifications marked as read.';

  @override
  String get notifKategoriJatuhTempo => 'Due date';

  @override
  String get notifKategoriMenungguApproval => 'Waiting for approval';

  @override
  String get notifKategoriDisetujui => 'Approved';

  @override
  String get notifKategoriPerluRevisi => 'Needs revision';

  @override
  String get notifKategoriSertifikat => 'Certificate issued';

  @override
  String get notifKategoriUmum => 'Info';

  @override
  String get phCalibCaraScan => 'Live scan';

  @override
  String get phCalibCaraScanKeterangan =>
      'Point the camera — numbers float over the preview';
}
