// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'studio_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class StudioL10nEn extends StudioL10n {
  StudioL10nEn([String locale = 'en']) : super(locale);

  @override
  String get namaAplikasi => 'Sidik Studio';

  @override
  String get slogan => 'Data & calculation control center';

  @override
  String get masukJudul => 'Sign in to Studio';

  @override
  String get masukKet => 'Use your PT Sidik lab account.';

  @override
  String get isianIdentitas => 'Employee ID or email';

  @override
  String get isianSandi => 'Password';

  @override
  String get isianIdentitasWajib => 'Employee ID or email is required.';

  @override
  String get isianSandiWajib => 'Password is required.';

  @override
  String get tombolMasuk => 'Sign in';

  @override
  String get tampilkanSandi => 'Show password';

  @override
  String get sembunyikanSandi => 'Hide password';

  @override
  String get gagalJaringan => 'Can\'t reach the server. Try again.';

  @override
  String gagalDiPerangkat(String detail) {
    return 'Sign-in failed on this device: $detail';
  }

  @override
  String get devJudul => 'DEV BUILD — test accounts';

  @override
  String devServer(String alamat) {
    return 'Server: $alamat';
  }

  @override
  String get seksiDataAcuan => 'Reference data';

  @override
  String get seksiKelolaData => 'Manage data';

  @override
  String get seksiLembarHitung => 'Calculation sheets';

  @override
  String tahapKode(String kode) {
    return 'Stage $kode';
  }

  @override
  String tahapBelumTersedia(String kode) {
    return 'Not available yet — built in stage $kode.';
  }

  @override
  String get keluar => 'Sign out';

  @override
  String get temaGelap => 'Dark theme';

  @override
  String get temaTerang => 'Light theme';

  @override
  String get bukaMenu => 'Open menu';

  @override
  String get izinGagalJudul => 'Account permissions couldn\'t be loaded.';

  @override
  String get cobaLagi => 'Try again';

  @override
  String get memuat => 'Loading…';

  @override
  String get seksiBeranda => 'Home';

  @override
  String get seksiPengesahan => 'Approval';

  @override
  String get seksiImpor => 'Import';

  @override
  String get seksiPengaturan => 'Settings';

  @override
  String get peranAdmin => 'Master Data';

  @override
  String get peranTeknisi => 'Technician';

  @override
  String get peranViewer => 'Viewer';

  @override
  String get peranSuperAdmin => 'Super Admin';

  @override
  String get menuAkun => 'Account & server status';

  @override
  String get bilahStatus => 'Status bar';

  @override
  String statusServer(String alamat) {
    return 'Server $alamat';
  }

  @override
  String get statusMemeriksa => 'Checking server…';

  @override
  String get statusTersambung => 'Connected';

  @override
  String get statusTerputus => 'Not connected';

  @override
  String get statusRealtimeNyala => 'Realtime on';

  @override
  String get statusRealtimeMati => 'Realtime off';

  @override
  String get statusRealtimeTakDiketahui => 'Realtime unknown';

  @override
  String statusVersiApi(String versi) {
    return 'API $versi';
  }

  @override
  String berandaMasukSebagai(String nama, String peran) {
    return 'Signed in as $nama · $peran';
  }

  @override
  String get berandaKosong => 'No summary for this account yet.';

  @override
  String get berandaKosongKet =>
      'Home cards follow the account\'s permissions and the modules already available.';

  @override
  String get kartuBuka => 'Open';

  @override
  String get kartuDataAcuanKosong => 'No reference data packages yet.';

  @override
  String get kolomPaket => 'Package';

  @override
  String get kolomVersiAktif => 'Active version';

  @override
  String get kolomDraf => 'Drafts';

  @override
  String get tanpaVersiAktif => 'No active version';

  @override
  String get belumDiimpor => 'Not imported';

  @override
  String get sesiBerakhirJudul => 'Session ended — sign in again';

  @override
  String sesiBerakhirKet(String nama, String identitas) {
    return 'The server no longer accepts this session. Enter your password to continue as $nama ($identitas). Your screen and inputs stay where they are.';
  }

  @override
  String get sesiBerakhirKeluar => 'Sign out & switch account';

  @override
  String get sesiAkunBerbeda =>
      'The server returned a different account. Sign out, then sign in with the right account.';

  @override
  String get kedaluwarsaJudul =>
      'This Studio version is too old for the server.';

  @override
  String get kedaluwarsaKet =>
      'Install the latest Sidik Studio, then open it again.';

  @override
  String kedaluwarsaVersi(String versi, String alamat) {
    return 'Studio $versi · server $alamat';
  }

  @override
  String get bukanAkunLab =>
      'This isn\'t a lab account. Studio is for lab staff only.';

  @override
  String get bukanAkunStudio => 'This account is not a Studio account.';

  @override
  String masukServerVersi(String alamat, String versi) {
    return 'Server $alamat · Studio $versi';
  }

  @override
  String get seksiWorkbookAlat => 'Instrument workbooks';

  @override
  String kartuWorkbookRingkas(int jumlah, int belum) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: '$jumlah workbooks',
      one: '1 workbook',
    );
    return '$_temp0 · $belum not mapped yet';
  }

  @override
  String kartuWorkbookSumber(int csv, int xlsm) {
    return '$csv from CSV · $xlsm from .xlsm';
  }

  @override
  String get workbookKet =>
      'Original Excel mode — read-only. Cells exactly as stored in the master workbook.';

  @override
  String get workbookCari => 'Search workbook name or profile code';

  @override
  String get workbookBelumDipetakan => 'Not mapped yet';

  @override
  String get workbookBelumDipetakanKet =>
      'No calibration profile assigned yet — waiting for the workbook map decision.';

  @override
  String workbookJumlahLembar(int jumlah) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: '$jumlah sheets',
      one: '1 sheet',
    );
    return '$_temp0';
  }

  @override
  String get workbookKosong => 'No workbooks imported yet.';

  @override
  String get workbookKosongKet =>
      'Workbooks are imported on the server with the studio:impor-workbook command.';

  @override
  String workbookTidakCocok(String cari) {
    return 'No workbook matches “$cari”.';
  }

  @override
  String get workbookGagalMuat => 'Couldn\'t load workbooks.';

  @override
  String get workbookTidakDitemukan =>
      'Workbook not found, or not from this lab.';

  @override
  String workbookDiimpor(String tanggal) {
    return 'Imported $tanggal';
  }

  @override
  String get workbookSumberCsv =>
      'From the CSV export: stored values only — no formulas, no layout.';

  @override
  String get workbookSumberXlsm =>
      'From the master .xlsm: values, formulas, and layout.';

  @override
  String get workbookBerkasAsli => 'Original file stored on the server';

  @override
  String get kembali => 'Back';

  @override
  String get workbookBacaSaja => 'Read-only';

  @override
  String get workbookTampilkanRumus => 'Show formulas (Ctrl+`)';

  @override
  String get workbookTampilkanNilai => 'Show values (Ctrl+`)';

  @override
  String get workbookInspektur => 'Cell inspector';

  @override
  String get workbookMuatUlang => 'Reload';

  @override
  String get lembarTersembunyi => 'Hidden sheet in Excel';

  @override
  String get lembarSangatTersembunyi =>
      'Very hidden sheet (veryHidden) in Excel';

  @override
  String get lembarDikecualikanTab =>
      'Excluded from import — customer/certificate data';

  @override
  String lembarDikecualikanJudul(String tabel) {
    return 'This sheet holds customer/certificate data — managed in the $tabel table';
  }

  @override
  String get lembarDikecualikanTanpaTautan =>
      'This sheet holds customer/certificate data — not imported into Studio';

  @override
  String get lembarDikecualikanKet =>
      'Its contents are never sent to Studio. Change that data in its table, not in the workbook.';

  @override
  String get lembarKosong => 'This sheet is empty.';

  @override
  String get lembarTidakAda => 'This workbook has no sheets.';

  @override
  String get lembarGagalMuat => 'Couldn\'t load the sheet\'s cells.';

  @override
  String kakiSel(int sel, int rumus) {
    return '$sel cells · $rumus formulas';
  }

  @override
  String kakiSumber(String sumber) {
    return 'Source $sumber';
  }

  @override
  String kakiPilihan(String rentang, int jumlah) {
    return 'Selection $rentang ($jumlah cells)';
  }

  @override
  String kakiSelCacat(int jumlah) {
    return '$jumlah cells couldn\'t be read by this Studio version';
  }

  @override
  String get inspekturAlamat => 'Address';

  @override
  String get inspekturGabungan => 'Merged';

  @override
  String get inspekturTipe => 'Type';

  @override
  String get inspekturNilai => 'Exact value (n)';

  @override
  String get inspekturTeks => 'Displayed text (s)';

  @override
  String get inspekturRumus => 'Formula (r)';

  @override
  String get inspekturFormat => 'Number format (f)';

  @override
  String get inspekturGaya => 'Style';

  @override
  String get inspekturKet =>
      'Exact value = the number stored in the workbook, unrounded. Displayed text follows the cell\'s number format.';

  @override
  String get inspekturKosong => 'Empty cell';

  @override
  String get tipeAngka => 'Number';

  @override
  String get tipeTeks => 'Text';

  @override
  String get tipeLogika => 'Boolean';

  @override
  String get tipeGalat => 'Error';

  @override
  String get tipeRumus => 'Formula';

  @override
  String get tipeKosong => 'Empty';

  @override
  String get gayaTebal => 'bold';

  @override
  String get gayaMiring => 'italic';

  @override
  String gayaIsi(String warna) {
    return 'fill $warna';
  }

  @override
  String gayaWarnaTeks(String warna) {
    return 'text $warna';
  }

  @override
  String gayaRata(String rata) {
    return 'align $rata';
  }

  @override
  String get gayaGaris => 'bordered';

  @override
  String gridDisalin(int baris, int kolom) {
    return 'Copied $baris × $kolom cells';
  }

  @override
  String gridSalinTerlaluBesar(int jumlah, int batas) {
    return '$jumlah cells is too many to copy (max $batas).';
  }

  @override
  String get gridSalinGagalMuat =>
      'Some cells aren\'t loaded — copy cancelled. Try again.';

  @override
  String get devAlamatServer => 'Server address (dev)';

  @override
  String get devAlamatServerContoh => 'e.g. http://192.168.1.10:8000/api';

  @override
  String get devAlamatServerSimpan => 'Save';

  @override
  String get devAlamatServerBawaan => 'Use default';

  @override
  String get devAlamatServerTidakSah => 'Use http:// or https:// with a host.';

  @override
  String get devAlamatServerTersimpan =>
      'Saved — used now and next time Studio opens.';

  @override
  String devAlamatServerGagalSimpan(String detail) {
    return 'Couldn\'t save on this device: $detail';
  }

  @override
  String devAlamatServerKet(String bawaan) {
    return 'Build default: $bawaan';
  }

  @override
  String get workbookTutupInspektur => 'Close inspector';

  @override
  String get workbookLencanaExcelAsli => 'Original Excel';

  @override
  String workbookSumberLain(int jumlah) {
    return 'Other sources ($jumlah)';
  }

  @override
  String get workbookSumberLainKet =>
      'Exports of the same instrument workbook. The original Excel is shown above.';

  @override
  String lembarJugaDiTabel(String tabel) {
    return 'Also in the $tabel table';
  }

  @override
  String lembarJugaDiTabelKet(String tabel) {
    return 'This sheet is shown as-is from the workbook; the same data is managed in the $tabel table.';
  }

  @override
  String get kakiLebarPerkiraan => 'Estimated widths';

  @override
  String get kakiLebarPerkiraanKet =>
      'A CSV export carries no column widths; the server estimated them from the contents.';

  @override
  String get zoomPerkecil => 'Zoom out (Ctrl+−)';

  @override
  String get zoomPerbesar => 'Zoom in (Ctrl+=)';

  @override
  String get zoomPilih => 'Zoom';

  @override
  String get zoomPasLebar => 'Fit width';

  @override
  String get gayaBungkus => 'wrapped';

  @override
  String gayaVertikal(String posisi) {
    return 'vertical $posisi';
  }

  @override
  String gayaFont(String nama) {
    return 'font $nama';
  }

  @override
  String gayaUkuran(String ukuran) {
    return '$ukuran pt';
  }

  @override
  String get workbookSimulasi => 'Simulation';

  @override
  String get workbookSimulasiKet =>
      'Edit cells to recalculate the workbook on the server. Nothing is saved.';

  @override
  String get simulasiSpanduk => 'Simulation — not saved';

  @override
  String simulasiJumlahEdit(int jumlah) {
    return '$jumlah cells changed';
  }

  @override
  String get simulasiReset => 'Reset';

  @override
  String get simulasiResetKet =>
      'Discard all edits — back to the workbook contents';

  @override
  String get simulasiMenghitung => 'Calculating…';

  @override
  String get simulasiBatalkanTerakhir => 'Undo last edit';

  @override
  String get simulasiGalatBerkasAsli =>
      'This workbook has no original Excel file on the server — the simulation can\'t be calculated.';

  @override
  String simulasiGalatPerluSandi(String id) {
    return 'This password-protected workbook\'s calculation model hasn\'t been prepared on the server — the simulation can\'t be calculated yet. Ask an admin to run php artisan studio:siapkan-hitung $id (asks for the password) or re-import the .xlsm file with its password.';
  }

  @override
  String simulasiGalatDitolak(String pesan) {
    return 'Edit rejected by the server: $pesan';
  }

  @override
  String get simulasiGalatLama =>
      'Calculation took too long (server limit 20 s) and was cancelled.';

  @override
  String get simulasiGalatSering =>
      'Too many calculations — the server quota is used up for now. New edits are kept but not sent automatically; wait a moment, then try again.';

  @override
  String get simulasiGalatDilarang => 'Your role may not run simulations.';

  @override
  String simulasiGalatLain(String pesan) {
    return 'Simulation failed: $pesan';
  }

  @override
  String simulasiGalatHitung(int jumlah) {
    return '$jumlah calculation engine errors';
  }

  @override
  String simulasiBatasEdit(int batas) {
    return 'At most $batas cells can be changed in one simulation.';
  }

  @override
  String get simulasiUrungkan => 'Undo (Ctrl+Z)';

  @override
  String get simulasiUlangi => 'Redo (Ctrl+Y)';

  @override
  String get bilahSimpanEdit => 'Enter';

  @override
  String get bilahBatalEdit => 'Cancel (Esc)';

  @override
  String get lembarTampilkanTersembunyi => 'Unhide…';

  @override
  String get lembarTampilkanJudul => 'Unhide sheet';

  @override
  String get lembarTampilkanKet => 'Display only — not saved to the workbook.';

  @override
  String get gambarGagalMuat => 'Image failed to load';

  @override
  String get inspekturSimulasi => 'Simulated input';

  @override
  String get inspekturGalatHitung => 'Calculation engine error';

  @override
  String workbookImpor(int versi) {
    return 'Import #$versi';
  }

  @override
  String workbookImporKet(int versi) {
    return 'Import number $versi within this master type — import order, not an indicator of the newest version.';
  }

  @override
  String workbookRiwayat(int jumlah) {
    return 'History ($jumlah)';
  }

  @override
  String get workbookRiwayatKet =>
      'Older versions of this master — hidden from the list, still viewable (read-only).';

  @override
  String riwayatJudul(String nama) {
    return 'History — $nama';
  }

  @override
  String get riwayatKet =>
      'Studio keeps one active master per type. Importing a new master replaces the active one; the old one is kept here, never deleted. Old versions open read-only.';

  @override
  String get riwayatKosong => 'This master has no history yet.';

  @override
  String get riwayatGagalMuat => 'History failed to load.';

  @override
  String get workbookStatusAktif => 'Active master';

  @override
  String get workbookStatusRiwayat => 'History';

  @override
  String get workbookRiwayatSpanduk => 'History — not the active master';

  @override
  String get workbookRiwayatSpandukKet =>
      'An older version that has been replaced. Read-only — it cannot be edited or recalculated.';

  @override
  String workbookDigantikanOleh(int id) {
    return 'replaced by #$id';
  }

  @override
  String get workbookDiarsipkan => 'This master has been archived/replaced.';

  @override
  String get workbookKembaliKeDaftar => 'Back to list';

  @override
  String get unggahMasterTombol => 'Upload master';

  @override
  String get unggahMasterJudul => 'Upload master';

  @override
  String get unggahMasterKet =>
      'Import a master workbook (.xlsm, .xlsx or .csv). The server extracts it and records who did it and why.';

  @override
  String get unggahMasterPilihBerkas => 'Choose file';

  @override
  String get unggahMasterBelumDipilih => 'No file chosen';

  @override
  String get unggahMasterSandi => 'File password (if protected)';

  @override
  String get unggahMasterSandiKet => 'Sent once with the upload. Never stored.';

  @override
  String get unggahMasterAlasan => 'Reason';

  @override
  String get unggahMasterAlasanKet =>
      'Why this master is being imported or replaced (recorded in the audit trail).';

  @override
  String get unggahMasterAlasanWajib => 'Reason is required.';

  @override
  String get unggahMasterGantikan => 'Replace master (optional)';

  @override
  String get unggahMasterGantikanTidak => 'New master (replaces nothing)';

  @override
  String get unggahMasterKirim => 'Upload';

  @override
  String get unggahMasterMengirim => 'Uploading…';

  @override
  String get unggahMasterBerhasil =>
      'Master uploaded. The list has been refreshed.';

  @override
  String get unggahMasterBerkasWajib => 'Choose a file first.';

  @override
  String get unggahMasterFormatBerkas =>
      'Only .xlsm, .xlsx or .csv files are accepted.';

  @override
  String get unggahMasterSandiSalah => 'The file password is wrong.';

  @override
  String get unggahMasterSandiDiperlukan =>
      'This file is password protected — enter its password.';

  @override
  String get unggahMasterFormatTidakDikenal =>
      'The server does not recognise this file format.';

  @override
  String get unggahMasterGagal => 'Upload failed.';

  @override
  String get unggahMasterStrukturJudul =>
      'The master\'s structure no longer matches its cell map — nothing was imported:';

  @override
  String get unggahMasterPetaTervalidasi =>
      'Structure validated against the cell map.';

  @override
  String get unggahMasterBelumTerpetakan =>
      'Not mapped yet: this master\'s structure is not validated, and its contents are NOT used for calculations, certificates or CMC.';

  @override
  String get unggahMasterSudahAda =>
      'This exact file was already imported; nothing changed.';

  @override
  String unggahMasterDrafDibuat(int nomor, int sel) {
    return 'Draft data reference v$nomor created ($sel cells changed). It affects no calculation until it is submitted, simulated and activated from the lab app.';
  }

  @override
  String unggahMasterDrafSudahAda(String versi) {
    return 'A draft with the same contents already exists ($versi).';
  }

  @override
  String get unggahMasterSamaDasar =>
      'Contents equal the current base version; no new draft.';

  @override
  String get unggahMasterPaketBelumAda =>
      'The data reference package does not exist on the server yet (initial import first); no draft was created.';

  @override
  String get unggahMasterBukaAlur => 'Open version workflow';
}
