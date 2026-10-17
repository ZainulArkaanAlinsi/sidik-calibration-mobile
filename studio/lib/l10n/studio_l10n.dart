import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'studio_l10n_en.dart';
import 'studio_l10n_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of StudioL10n
/// returned by `StudioL10n.of(context)`.
///
/// Applications need to include `StudioL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/studio_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: StudioL10n.localizationsDelegates,
///   supportedLocales: StudioL10n.supportedLocales,
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
/// be consistent with the languages listed in the StudioL10n.supportedLocales
/// property.
abstract class StudioL10n {
  StudioL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static StudioL10n of(BuildContext context) {
    return Localizations.of<StudioL10n>(context, StudioL10n)!;
  }

  static const LocalizationsDelegate<StudioL10n> delegate =
      _StudioL10nDelegate();

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

  /// Product name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Sidik Studio'**
  String get namaAplikasi;

  /// No description provided for @slogan.
  ///
  /// In en, this message translates to:
  /// **'Data & calculation control center'**
  String get slogan;

  /// No description provided for @masukJudul.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Studio'**
  String get masukJudul;

  /// No description provided for @masukKet.
  ///
  /// In en, this message translates to:
  /// **'Use your PT Sidik lab account.'**
  String get masukKet;

  /// No description provided for @isianIdentitas.
  ///
  /// In en, this message translates to:
  /// **'Employee ID or email'**
  String get isianIdentitas;

  /// No description provided for @isianSandi.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get isianSandi;

  /// No description provided for @isianIdentitasWajib.
  ///
  /// In en, this message translates to:
  /// **'Employee ID or email is required.'**
  String get isianIdentitasWajib;

  /// No description provided for @isianSandiWajib.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get isianSandiWajib;

  /// No description provided for @tombolMasuk.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get tombolMasuk;

  /// No description provided for @tampilkanSandi.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get tampilkanSandi;

  /// No description provided for @sembunyikanSandi.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get sembunyikanSandi;

  /// No description provided for @gagalJaringan.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Try again.'**
  String get gagalJaringan;

  /// No description provided for @gagalDiPerangkat.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed on this device: {detail}'**
  String gagalDiPerangkat(String detail);

  /// No description provided for @devJudul.
  ///
  /// In en, this message translates to:
  /// **'DEV BUILD — test accounts'**
  String get devJudul;

  /// No description provided for @devServer.
  ///
  /// In en, this message translates to:
  /// **'Server: {alamat}'**
  String devServer(String alamat);

  /// No description provided for @seksiDataAcuan.
  ///
  /// In en, this message translates to:
  /// **'Reference data'**
  String get seksiDataAcuan;

  /// No description provided for @seksiKelolaData.
  ///
  /// In en, this message translates to:
  /// **'Manage data'**
  String get seksiKelolaData;

  /// No description provided for @seksiLembarHitung.
  ///
  /// In en, this message translates to:
  /// **'Calculation sheets'**
  String get seksiLembarHitung;

  /// No description provided for @tahapKode.
  ///
  /// In en, this message translates to:
  /// **'Stage {kode}'**
  String tahapKode(String kode);

  /// No description provided for @tahapBelumTersedia.
  ///
  /// In en, this message translates to:
  /// **'Not available yet — built in stage {kode}.'**
  String tahapBelumTersedia(String kode);

  /// No description provided for @keluar.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get keluar;

  /// No description provided for @temaGelap.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get temaGelap;

  /// No description provided for @temaTerang.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get temaTerang;

  /// No description provided for @bukaMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get bukaMenu;

  /// No description provided for @izinGagalJudul.
  ///
  /// In en, this message translates to:
  /// **'Account permissions couldn\'t be loaded.'**
  String get izinGagalJudul;

  /// No description provided for @cobaLagi.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get cobaLagi;

  /// No description provided for @memuat.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get memuat;

  /// No description provided for @seksiBeranda.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get seksiBeranda;

  /// No description provided for @seksiPengesahan.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get seksiPengesahan;

  /// No description provided for @seksiImpor.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get seksiImpor;

  /// No description provided for @seksiPengaturan.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get seksiPengaturan;

  /// No description provided for @peranAdmin.
  ///
  /// In en, this message translates to:
  /// **'Master Data'**
  String get peranAdmin;

  /// No description provided for @peranTeknisi.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get peranTeknisi;

  /// No description provided for @peranViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get peranViewer;

  /// No description provided for @peranSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get peranSuperAdmin;

  /// No description provided for @menuAkun.
  ///
  /// In en, this message translates to:
  /// **'Account & server status'**
  String get menuAkun;

  /// No description provided for @bilahStatus.
  ///
  /// In en, this message translates to:
  /// **'Status bar'**
  String get bilahStatus;

  /// No description provided for @statusServer.
  ///
  /// In en, this message translates to:
  /// **'Server {alamat}'**
  String statusServer(String alamat);

  /// No description provided for @statusMemeriksa.
  ///
  /// In en, this message translates to:
  /// **'Checking server…'**
  String get statusMemeriksa;

  /// No description provided for @statusTersambung.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusTersambung;

  /// No description provided for @statusTerputus.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusTerputus;

  /// No description provided for @statusRealtimeNyala.
  ///
  /// In en, this message translates to:
  /// **'Realtime on'**
  String get statusRealtimeNyala;

  /// No description provided for @statusRealtimeMati.
  ///
  /// In en, this message translates to:
  /// **'Realtime off'**
  String get statusRealtimeMati;

  /// No description provided for @statusRealtimeTakDiketahui.
  ///
  /// In en, this message translates to:
  /// **'Realtime unknown'**
  String get statusRealtimeTakDiketahui;

  /// No description provided for @statusVersiApi.
  ///
  /// In en, this message translates to:
  /// **'API {versi}'**
  String statusVersiApi(String versi);

  /// No description provided for @berandaMasukSebagai.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {nama} · {peran}'**
  String berandaMasukSebagai(String nama, String peran);

  /// No description provided for @berandaKosong.
  ///
  /// In en, this message translates to:
  /// **'No summary for this account yet.'**
  String get berandaKosong;

  /// No description provided for @berandaKosongKet.
  ///
  /// In en, this message translates to:
  /// **'Home cards follow the account\'s permissions and the modules already available.'**
  String get berandaKosongKet;

  /// No description provided for @kartuBuka.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get kartuBuka;

  /// No description provided for @kartuDataAcuanKosong.
  ///
  /// In en, this message translates to:
  /// **'No reference data packages yet.'**
  String get kartuDataAcuanKosong;

  /// No description provided for @kolomPaket.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get kolomPaket;

  /// No description provided for @kolomVersiAktif.
  ///
  /// In en, this message translates to:
  /// **'Active version'**
  String get kolomVersiAktif;

  /// No description provided for @kolomDraf.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get kolomDraf;

  /// No description provided for @tanpaVersiAktif.
  ///
  /// In en, this message translates to:
  /// **'No active version'**
  String get tanpaVersiAktif;

  /// No description provided for @belumDiimpor.
  ///
  /// In en, this message translates to:
  /// **'Not imported'**
  String get belumDiimpor;

  /// No description provided for @sesiBerakhirJudul.
  ///
  /// In en, this message translates to:
  /// **'Session ended — sign in again'**
  String get sesiBerakhirJudul;

  /// No description provided for @sesiBerakhirKet.
  ///
  /// In en, this message translates to:
  /// **'The server no longer accepts this session. Enter your password to continue as {nama} ({identitas}). Your screen and inputs stay where they are.'**
  String sesiBerakhirKet(String nama, String identitas);

  /// No description provided for @sesiBerakhirKeluar.
  ///
  /// In en, this message translates to:
  /// **'Sign out & switch account'**
  String get sesiBerakhirKeluar;

  /// No description provided for @sesiAkunBerbeda.
  ///
  /// In en, this message translates to:
  /// **'The server returned a different account. Sign out, then sign in with the right account.'**
  String get sesiAkunBerbeda;

  /// No description provided for @kedaluwarsaJudul.
  ///
  /// In en, this message translates to:
  /// **'This Studio version is too old for the server.'**
  String get kedaluwarsaJudul;

  /// No description provided for @kedaluwarsaKet.
  ///
  /// In en, this message translates to:
  /// **'Install the latest Sidik Studio, then open it again.'**
  String get kedaluwarsaKet;

  /// No description provided for @kedaluwarsaVersi.
  ///
  /// In en, this message translates to:
  /// **'Studio {versi} · server {alamat}'**
  String kedaluwarsaVersi(String versi, String alamat);

  /// No description provided for @bukanAkunLab.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a lab account. Studio is for lab staff only.'**
  String get bukanAkunLab;

  /// No description provided for @masukServerVersi.
  ///
  /// In en, this message translates to:
  /// **'Server {alamat} · Studio {versi}'**
  String masukServerVersi(String alamat, String versi);

  /// No description provided for @seksiWorkbookAlat.
  ///
  /// In en, this message translates to:
  /// **'Instrument workbooks'**
  String get seksiWorkbookAlat;

  /// No description provided for @kartuWorkbookRingkas.
  ///
  /// In en, this message translates to:
  /// **'{jumlah, plural, =1{1 workbook} other{{jumlah} workbooks}} · {belum} not mapped yet'**
  String kartuWorkbookRingkas(int jumlah, int belum);

  /// No description provided for @kartuWorkbookSumber.
  ///
  /// In en, this message translates to:
  /// **'{csv} from CSV · {xlsm} from .xlsm'**
  String kartuWorkbookSumber(int csv, int xlsm);

  /// No description provided for @workbookKet.
  ///
  /// In en, this message translates to:
  /// **'Original Excel mode — read-only. Cells exactly as stored in the master workbook.'**
  String get workbookKet;

  /// No description provided for @workbookCari.
  ///
  /// In en, this message translates to:
  /// **'Search workbook name or profile code'**
  String get workbookCari;

  /// No description provided for @workbookBelumDipetakan.
  ///
  /// In en, this message translates to:
  /// **'Not mapped yet'**
  String get workbookBelumDipetakan;

  /// No description provided for @workbookBelumDipetakanKet.
  ///
  /// In en, this message translates to:
  /// **'No calibration profile assigned yet — waiting for the workbook map decision.'**
  String get workbookBelumDipetakanKet;

  /// No description provided for @workbookJumlahLembar.
  ///
  /// In en, this message translates to:
  /// **'{jumlah, plural, =1{1 sheet} other{{jumlah} sheets}}'**
  String workbookJumlahLembar(int jumlah);

  /// No description provided for @workbookKosong.
  ///
  /// In en, this message translates to:
  /// **'No workbooks imported yet.'**
  String get workbookKosong;

  /// No description provided for @workbookKosongKet.
  ///
  /// In en, this message translates to:
  /// **'Workbooks are imported on the server with the studio:impor-workbook command.'**
  String get workbookKosongKet;

  /// No description provided for @workbookTidakCocok.
  ///
  /// In en, this message translates to:
  /// **'No workbook matches “{cari}”.'**
  String workbookTidakCocok(String cari);

  /// No description provided for @workbookGagalMuat.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load workbooks.'**
  String get workbookGagalMuat;

  /// No description provided for @workbookTidakDitemukan.
  ///
  /// In en, this message translates to:
  /// **'Workbook not found, or not from this lab.'**
  String get workbookTidakDitemukan;

  /// No description provided for @workbookDiimpor.
  ///
  /// In en, this message translates to:
  /// **'Imported {tanggal}'**
  String workbookDiimpor(String tanggal);

  /// No description provided for @workbookSumberCsv.
  ///
  /// In en, this message translates to:
  /// **'From the CSV export: stored values only — no formulas, no layout.'**
  String get workbookSumberCsv;

  /// No description provided for @workbookSumberXlsm.
  ///
  /// In en, this message translates to:
  /// **'From the master .xlsm: values, formulas, and layout.'**
  String get workbookSumberXlsm;

  /// No description provided for @workbookBerkasAsli.
  ///
  /// In en, this message translates to:
  /// **'Original file stored on the server'**
  String get workbookBerkasAsli;

  /// No description provided for @kembali.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get kembali;

  /// No description provided for @workbookBacaSaja.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get workbookBacaSaja;

  /// No description provided for @workbookTampilkanRumus.
  ///
  /// In en, this message translates to:
  /// **'Show formulas (Ctrl+`)'**
  String get workbookTampilkanRumus;

  /// No description provided for @workbookTampilkanNilai.
  ///
  /// In en, this message translates to:
  /// **'Show values (Ctrl+`)'**
  String get workbookTampilkanNilai;

  /// No description provided for @workbookInspektur.
  ///
  /// In en, this message translates to:
  /// **'Cell inspector'**
  String get workbookInspektur;

  /// No description provided for @workbookMuatUlang.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get workbookMuatUlang;

  /// No description provided for @lembarTersembunyi.
  ///
  /// In en, this message translates to:
  /// **'Hidden sheet in Excel'**
  String get lembarTersembunyi;

  /// No description provided for @lembarSangatTersembunyi.
  ///
  /// In en, this message translates to:
  /// **'Very hidden sheet (veryHidden) in Excel'**
  String get lembarSangatTersembunyi;

  /// No description provided for @lembarDikecualikanTab.
  ///
  /// In en, this message translates to:
  /// **'Excluded from import — customer/certificate data'**
  String get lembarDikecualikanTab;

  /// No description provided for @lembarDikecualikanJudul.
  ///
  /// In en, this message translates to:
  /// **'This sheet holds customer/certificate data — managed in the {tabel} table'**
  String lembarDikecualikanJudul(String tabel);

  /// No description provided for @lembarDikecualikanTanpaTautan.
  ///
  /// In en, this message translates to:
  /// **'This sheet holds customer/certificate data — not imported into Studio'**
  String get lembarDikecualikanTanpaTautan;

  /// No description provided for @lembarDikecualikanKet.
  ///
  /// In en, this message translates to:
  /// **'Its contents are never sent to Studio. Change that data in its table, not in the workbook.'**
  String get lembarDikecualikanKet;

  /// No description provided for @lembarKosong.
  ///
  /// In en, this message translates to:
  /// **'This sheet is empty.'**
  String get lembarKosong;

  /// No description provided for @lembarTidakAda.
  ///
  /// In en, this message translates to:
  /// **'This workbook has no sheets.'**
  String get lembarTidakAda;

  /// No description provided for @lembarGagalMuat.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the sheet\'s cells.'**
  String get lembarGagalMuat;

  /// No description provided for @kakiSel.
  ///
  /// In en, this message translates to:
  /// **'{sel} cells · {rumus} formulas'**
  String kakiSel(int sel, int rumus);

  /// No description provided for @kakiSumber.
  ///
  /// In en, this message translates to:
  /// **'Source {sumber}'**
  String kakiSumber(String sumber);

  /// No description provided for @kakiPilihan.
  ///
  /// In en, this message translates to:
  /// **'Selection {rentang} ({jumlah} cells)'**
  String kakiPilihan(String rentang, int jumlah);

  /// No description provided for @kakiSelCacat.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} cells couldn\'t be read by this Studio version'**
  String kakiSelCacat(int jumlah);

  /// No description provided for @inspekturAlamat.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get inspekturAlamat;

  /// No description provided for @inspekturGabungan.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get inspekturGabungan;

  /// No description provided for @inspekturTipe.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get inspekturTipe;

  /// No description provided for @inspekturNilai.
  ///
  /// In en, this message translates to:
  /// **'Exact value (n)'**
  String get inspekturNilai;

  /// No description provided for @inspekturTeks.
  ///
  /// In en, this message translates to:
  /// **'Displayed text (s)'**
  String get inspekturTeks;

  /// No description provided for @inspekturRumus.
  ///
  /// In en, this message translates to:
  /// **'Formula (r)'**
  String get inspekturRumus;

  /// No description provided for @inspekturFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format (f)'**
  String get inspekturFormat;

  /// No description provided for @inspekturGaya.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get inspekturGaya;

  /// No description provided for @inspekturKet.
  ///
  /// In en, this message translates to:
  /// **'Exact value = the number stored in the workbook, unrounded. Displayed text follows the cell\'s number format.'**
  String get inspekturKet;

  /// No description provided for @inspekturKosong.
  ///
  /// In en, this message translates to:
  /// **'Empty cell'**
  String get inspekturKosong;

  /// No description provided for @tipeAngka.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get tipeAngka;

  /// No description provided for @tipeTeks.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get tipeTeks;

  /// No description provided for @tipeLogika.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get tipeLogika;

  /// No description provided for @tipeGalat.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get tipeGalat;

  /// No description provided for @tipeRumus.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get tipeRumus;

  /// No description provided for @tipeKosong.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get tipeKosong;

  /// No description provided for @gayaTebal.
  ///
  /// In en, this message translates to:
  /// **'bold'**
  String get gayaTebal;

  /// No description provided for @gayaMiring.
  ///
  /// In en, this message translates to:
  /// **'italic'**
  String get gayaMiring;

  /// No description provided for @gayaIsi.
  ///
  /// In en, this message translates to:
  /// **'fill {warna}'**
  String gayaIsi(String warna);

  /// No description provided for @gayaWarnaTeks.
  ///
  /// In en, this message translates to:
  /// **'text {warna}'**
  String gayaWarnaTeks(String warna);

  /// No description provided for @gayaRata.
  ///
  /// In en, this message translates to:
  /// **'align {rata}'**
  String gayaRata(String rata);

  /// No description provided for @gayaGaris.
  ///
  /// In en, this message translates to:
  /// **'bordered'**
  String get gayaGaris;

  /// No description provided for @gridDisalin.
  ///
  /// In en, this message translates to:
  /// **'Copied {baris} × {kolom} cells'**
  String gridDisalin(int baris, int kolom);

  /// No description provided for @gridSalinTerlaluBesar.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} cells is too many to copy (max {batas}).'**
  String gridSalinTerlaluBesar(int jumlah, int batas);

  /// No description provided for @gridSalinGagalMuat.
  ///
  /// In en, this message translates to:
  /// **'Some cells aren\'t loaded — copy cancelled. Try again.'**
  String get gridSalinGagalMuat;

  /// No description provided for @devAlamatServer.
  ///
  /// In en, this message translates to:
  /// **'Server address (dev)'**
  String get devAlamatServer;

  /// No description provided for @devAlamatServerContoh.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://192.168.1.10:8000/api'**
  String get devAlamatServerContoh;

  /// No description provided for @devAlamatServerSimpan.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get devAlamatServerSimpan;

  /// No description provided for @devAlamatServerBawaan.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get devAlamatServerBawaan;

  /// No description provided for @devAlamatServerTidakSah.
  ///
  /// In en, this message translates to:
  /// **'Use http:// or https:// with a host.'**
  String get devAlamatServerTidakSah;

  /// No description provided for @devAlamatServerTersimpan.
  ///
  /// In en, this message translates to:
  /// **'Saved — used now and next time Studio opens.'**
  String get devAlamatServerTersimpan;

  /// No description provided for @devAlamatServerGagalSimpan.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save on this device: {detail}'**
  String devAlamatServerGagalSimpan(String detail);

  /// No description provided for @devAlamatServerKet.
  ///
  /// In en, this message translates to:
  /// **'Build default: {bawaan}'**
  String devAlamatServerKet(String bawaan);

  /// No description provided for @workbookTutupInspektur.
  ///
  /// In en, this message translates to:
  /// **'Close inspector'**
  String get workbookTutupInspektur;

  /// No description provided for @workbookLencanaExcelAsli.
  ///
  /// In en, this message translates to:
  /// **'Original Excel'**
  String get workbookLencanaExcelAsli;

  /// No description provided for @workbookSumberLain.
  ///
  /// In en, this message translates to:
  /// **'Other sources ({jumlah})'**
  String workbookSumberLain(int jumlah);

  /// No description provided for @workbookSumberLainKet.
  ///
  /// In en, this message translates to:
  /// **'Exports of the same instrument workbook. The original Excel is shown above.'**
  String get workbookSumberLainKet;

  /// No description provided for @lembarJugaDiTabel.
  ///
  /// In en, this message translates to:
  /// **'Also in the {tabel} table'**
  String lembarJugaDiTabel(String tabel);

  /// No description provided for @lembarJugaDiTabelKet.
  ///
  /// In en, this message translates to:
  /// **'This sheet is shown as-is from the workbook; the same data is managed in the {tabel} table.'**
  String lembarJugaDiTabelKet(String tabel);

  /// No description provided for @kakiLebarPerkiraan.
  ///
  /// In en, this message translates to:
  /// **'Estimated widths'**
  String get kakiLebarPerkiraan;

  /// No description provided for @kakiLebarPerkiraanKet.
  ///
  /// In en, this message translates to:
  /// **'A CSV export carries no column widths; the server estimated them from the contents.'**
  String get kakiLebarPerkiraanKet;

  /// No description provided for @zoomPerkecil.
  ///
  /// In en, this message translates to:
  /// **'Zoom out (Ctrl+−)'**
  String get zoomPerkecil;

  /// No description provided for @zoomPerbesar.
  ///
  /// In en, this message translates to:
  /// **'Zoom in (Ctrl+=)'**
  String get zoomPerbesar;

  /// No description provided for @zoomPilih.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoomPilih;

  /// No description provided for @zoomPasLebar.
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get zoomPasLebar;

  /// No description provided for @gayaBungkus.
  ///
  /// In en, this message translates to:
  /// **'wrapped'**
  String get gayaBungkus;

  /// No description provided for @gayaVertikal.
  ///
  /// In en, this message translates to:
  /// **'vertical {posisi}'**
  String gayaVertikal(String posisi);

  /// No description provided for @gayaFont.
  ///
  /// In en, this message translates to:
  /// **'font {nama}'**
  String gayaFont(String nama);

  /// No description provided for @gayaUkuran.
  ///
  /// In en, this message translates to:
  /// **'{ukuran} pt'**
  String gayaUkuran(String ukuran);

  /// No description provided for @workbookSimulasi.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get workbookSimulasi;

  /// No description provided for @workbookSimulasiKet.
  ///
  /// In en, this message translates to:
  /// **'Edit cells to recalculate the workbook on the server. Nothing is saved.'**
  String get workbookSimulasiKet;

  /// No description provided for @simulasiSpanduk.
  ///
  /// In en, this message translates to:
  /// **'Simulation — not saved'**
  String get simulasiSpanduk;

  /// No description provided for @simulasiJumlahEdit.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} cells changed'**
  String simulasiJumlahEdit(int jumlah);

  /// No description provided for @simulasiReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get simulasiReset;

  /// No description provided for @simulasiResetKet.
  ///
  /// In en, this message translates to:
  /// **'Discard all edits — back to the workbook contents'**
  String get simulasiResetKet;

  /// No description provided for @simulasiMenghitung.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get simulasiMenghitung;

  /// No description provided for @simulasiBatalkanTerakhir.
  ///
  /// In en, this message translates to:
  /// **'Undo last edit'**
  String get simulasiBatalkanTerakhir;

  /// No description provided for @simulasiGalatBerkasAsli.
  ///
  /// In en, this message translates to:
  /// **'This workbook has no original Excel file on the server — the simulation can\'t be calculated.'**
  String get simulasiGalatBerkasAsli;

  /// No description provided for @simulasiGalatPerluSandi.
  ///
  /// In en, this message translates to:
  /// **'This password-protected workbook\'s calculation model hasn\'t been prepared on the server — the simulation can\'t be calculated yet. Ask an admin to run php artisan studio:siapkan-hitung {id} (asks for the password) or re-import the .xlsm file with its password.'**
  String simulasiGalatPerluSandi(String id);

  /// No description provided for @simulasiGalatDitolak.
  ///
  /// In en, this message translates to:
  /// **'Edit rejected by the server: {pesan}'**
  String simulasiGalatDitolak(String pesan);

  /// No description provided for @simulasiGalatLama.
  ///
  /// In en, this message translates to:
  /// **'Calculation took too long (server limit 20 s) and was cancelled.'**
  String get simulasiGalatLama;

  /// No description provided for @simulasiGalatSering.
  ///
  /// In en, this message translates to:
  /// **'Too many calculations — the server quota is used up for now. New edits are kept but not sent automatically; wait a moment, then try again.'**
  String get simulasiGalatSering;

  /// No description provided for @simulasiGalatDilarang.
  ///
  /// In en, this message translates to:
  /// **'Your role may not run simulations.'**
  String get simulasiGalatDilarang;

  /// No description provided for @simulasiGalatLain.
  ///
  /// In en, this message translates to:
  /// **'Simulation failed: {pesan}'**
  String simulasiGalatLain(String pesan);

  /// No description provided for @simulasiGalatHitung.
  ///
  /// In en, this message translates to:
  /// **'{jumlah} calculation engine errors'**
  String simulasiGalatHitung(int jumlah);

  /// No description provided for @simulasiBatasEdit.
  ///
  /// In en, this message translates to:
  /// **'At most {batas} cells can be changed in one simulation.'**
  String simulasiBatasEdit(int batas);

  /// No description provided for @simulasiUrungkan.
  ///
  /// In en, this message translates to:
  /// **'Undo (Ctrl+Z)'**
  String get simulasiUrungkan;

  /// No description provided for @simulasiUlangi.
  ///
  /// In en, this message translates to:
  /// **'Redo (Ctrl+Y)'**
  String get simulasiUlangi;

  /// No description provided for @bilahSimpanEdit.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get bilahSimpanEdit;

  /// No description provided for @bilahBatalEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel (Esc)'**
  String get bilahBatalEdit;

  /// No description provided for @lembarTampilkanTersembunyi.
  ///
  /// In en, this message translates to:
  /// **'Unhide…'**
  String get lembarTampilkanTersembunyi;

  /// No description provided for @lembarTampilkanJudul.
  ///
  /// In en, this message translates to:
  /// **'Unhide sheet'**
  String get lembarTampilkanJudul;

  /// No description provided for @lembarTampilkanKet.
  ///
  /// In en, this message translates to:
  /// **'Display only — not saved to the workbook.'**
  String get lembarTampilkanKet;

  /// No description provided for @gambarGagalMuat.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get gambarGagalMuat;

  /// No description provided for @inspekturSimulasi.
  ///
  /// In en, this message translates to:
  /// **'Simulated input'**
  String get inspekturSimulasi;

  /// No description provided for @inspekturGalatHitung.
  ///
  /// In en, this message translates to:
  /// **'Calculation engine error'**
  String get inspekturGalatHitung;

  /// No description provided for @workbookImpor.
  ///
  /// In en, this message translates to:
  /// **'Import #{versi}'**
  String workbookImpor(int versi);

  /// No description provided for @workbookImporKet.
  ///
  /// In en, this message translates to:
  /// **'Import number {versi} within this master type — import order, not an indicator of the newest version.'**
  String workbookImporKet(int versi);

  /// No description provided for @workbookRiwayat.
  ///
  /// In en, this message translates to:
  /// **'History ({jumlah})'**
  String workbookRiwayat(int jumlah);

  /// No description provided for @workbookRiwayatKet.
  ///
  /// In en, this message translates to:
  /// **'Older versions of this master — hidden from the list, still viewable (read-only).'**
  String get workbookRiwayatKet;

  /// No description provided for @riwayatJudul.
  ///
  /// In en, this message translates to:
  /// **'History — {nama}'**
  String riwayatJudul(String nama);

  /// No description provided for @riwayatKet.
  ///
  /// In en, this message translates to:
  /// **'Studio keeps one active master per type. Importing a new master replaces the active one; the old one is kept here, never deleted. Old versions open read-only.'**
  String get riwayatKet;

  /// No description provided for @riwayatKosong.
  ///
  /// In en, this message translates to:
  /// **'This master has no history yet.'**
  String get riwayatKosong;

  /// No description provided for @riwayatGagalMuat.
  ///
  /// In en, this message translates to:
  /// **'History failed to load.'**
  String get riwayatGagalMuat;

  /// No description provided for @workbookStatusAktif.
  ///
  /// In en, this message translates to:
  /// **'Active master'**
  String get workbookStatusAktif;

  /// No description provided for @workbookStatusRiwayat.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get workbookStatusRiwayat;

  /// No description provided for @workbookRiwayatSpanduk.
  ///
  /// In en, this message translates to:
  /// **'History — not the active master'**
  String get workbookRiwayatSpanduk;

  /// No description provided for @workbookRiwayatSpandukKet.
  ///
  /// In en, this message translates to:
  /// **'An older version that has been replaced. Read-only — it cannot be edited or recalculated.'**
  String get workbookRiwayatSpandukKet;

  /// No description provided for @workbookDigantikanOleh.
  ///
  /// In en, this message translates to:
  /// **'replaced by #{id}'**
  String workbookDigantikanOleh(int id);

  /// No description provided for @workbookDiarsipkan.
  ///
  /// In en, this message translates to:
  /// **'This master has been archived/replaced.'**
  String get workbookDiarsipkan;

  /// No description provided for @workbookKembaliKeDaftar.
  ///
  /// In en, this message translates to:
  /// **'Back to list'**
  String get workbookKembaliKeDaftar;

  /// No description provided for @unggahMasterTombol.
  ///
  /// In en, this message translates to:
  /// **'Upload master'**
  String get unggahMasterTombol;

  /// No description provided for @unggahMasterJudul.
  ///
  /// In en, this message translates to:
  /// **'Upload master'**
  String get unggahMasterJudul;

  /// No description provided for @unggahMasterKet.
  ///
  /// In en, this message translates to:
  /// **'Import a master workbook (.xlsm, .xlsx or .csv). The server extracts it and records who did it and why.'**
  String get unggahMasterKet;

  /// No description provided for @unggahMasterPilihBerkas.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get unggahMasterPilihBerkas;

  /// No description provided for @unggahMasterBelumDipilih.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get unggahMasterBelumDipilih;

  /// No description provided for @unggahMasterSandi.
  ///
  /// In en, this message translates to:
  /// **'File password (if protected)'**
  String get unggahMasterSandi;

  /// No description provided for @unggahMasterSandiKet.
  ///
  /// In en, this message translates to:
  /// **'Sent once with the upload. Never stored.'**
  String get unggahMasterSandiKet;

  /// No description provided for @unggahMasterAlasan.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get unggahMasterAlasan;

  /// No description provided for @unggahMasterAlasanKet.
  ///
  /// In en, this message translates to:
  /// **'Why this master is being imported or replaced (recorded in the audit trail).'**
  String get unggahMasterAlasanKet;

  /// No description provided for @unggahMasterAlasanWajib.
  ///
  /// In en, this message translates to:
  /// **'Reason is required.'**
  String get unggahMasterAlasanWajib;

  /// No description provided for @unggahMasterGantikan.
  ///
  /// In en, this message translates to:
  /// **'Replace master (optional)'**
  String get unggahMasterGantikan;

  /// No description provided for @unggahMasterGantikanTidak.
  ///
  /// In en, this message translates to:
  /// **'New master (replaces nothing)'**
  String get unggahMasterGantikanTidak;

  /// No description provided for @unggahMasterKirim.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get unggahMasterKirim;

  /// No description provided for @unggahMasterMengirim.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get unggahMasterMengirim;

  /// No description provided for @unggahMasterBerhasil.
  ///
  /// In en, this message translates to:
  /// **'Master uploaded. The list has been refreshed.'**
  String get unggahMasterBerhasil;

  /// No description provided for @unggahMasterBerkasWajib.
  ///
  /// In en, this message translates to:
  /// **'Choose a file first.'**
  String get unggahMasterBerkasWajib;

  /// No description provided for @unggahMasterFormatBerkas.
  ///
  /// In en, this message translates to:
  /// **'Only .xlsm, .xlsx or .csv files are accepted.'**
  String get unggahMasterFormatBerkas;

  /// No description provided for @unggahMasterSandiSalah.
  ///
  /// In en, this message translates to:
  /// **'The file password is wrong.'**
  String get unggahMasterSandiSalah;

  /// No description provided for @unggahMasterSandiDiperlukan.
  ///
  /// In en, this message translates to:
  /// **'This file is password protected — enter its password.'**
  String get unggahMasterSandiDiperlukan;

  /// No description provided for @unggahMasterFormatTidakDikenal.
  ///
  /// In en, this message translates to:
  /// **'The server does not recognise this file format.'**
  String get unggahMasterFormatTidakDikenal;

  /// No description provided for @unggahMasterGagal.
  ///
  /// In en, this message translates to:
  /// **'Upload failed.'**
  String get unggahMasterGagal;
}

class _StudioL10nDelegate extends LocalizationsDelegate<StudioL10n> {
  const _StudioL10nDelegate();

  @override
  Future<StudioL10n> load(Locale locale) {
    return SynchronousFuture<StudioL10n>(lookupStudioL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_StudioL10nDelegate old) => false;
}

StudioL10n lookupStudioL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return StudioL10nEn();
    case 'id':
      return StudioL10nId();
  }

  throw FlutterError(
    'StudioL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
