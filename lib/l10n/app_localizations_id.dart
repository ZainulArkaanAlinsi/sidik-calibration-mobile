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
  String get forgotSubtitle =>
      'Verifikasi email dulu, terus atur password baru';

  @override
  String get forgotBody =>
      'Masukin email yang kamu pakai waktu daftar. Kalau cocok, kamu langsung bisa bikin password baru di sini.';

  @override
  String get forgotSubmit => 'LANJUT';

  @override
  String get backToLogin => 'Balik ke Login';

  @override
  String get resetNewPassTitle => 'Atur Password Baru';

  @override
  String resetNewPassSubtitle(String email) {
    return 'Bikin password baru buat $email';
  }

  @override
  String get newPasswordLabel => 'Password Baru';

  @override
  String get confirmPasswordLabel => 'Ulangi Password Baru';

  @override
  String get passwordMismatch => 'Password nggak sama.';

  @override
  String get resetSubmit => 'SIMPAN PASSWORD BARU';

  @override
  String get resetDoneTitle => 'Password berhasil diubah';

  @override
  String get resetDoneBody =>
      'Password kamu udah diperbarui. Sekarang masuk pakai password baru ya.';

  @override
  String get backToLoginCaps => 'BALIK KE LOGIN';

  @override
  String get languageLabel => 'Bahasa';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navEquipment => 'Alat';

  @override
  String get navHistory => 'Riwayat';

  @override
  String get navNotifications => 'Notifikasi';

  @override
  String get navProfile => 'Profil';

  @override
  String get dashGreeting => 'Halo,';

  @override
  String get dashTotalDevices => 'Total alat';

  @override
  String get dashOverdue => 'Jatuh tempo';

  @override
  String get dashPendingApproval => 'Menunggu approval';

  @override
  String get dashCalibrationDraft => 'Draft kalibrasi';

  @override
  String get dashCertsThisMonth => 'Sertifikat bulan ini';

  @override
  String get dashLabScope => 'Se-lab';

  @override
  String get dashTotalCerts => 'Sertifikat';

  @override
  String dashCertsThisMonthSub(int count) {
    return '$count bulan ini';
  }

  @override
  String get dashCalibrationMine => 'Kalibrasi saya';

  @override
  String get dashCalibrationLab => 'Kalibrasi lab';

  @override
  String dashTrendUp(int count) {
    return '$count lebih banyak dari periode lalu';
  }

  @override
  String dashTrendDown(int count) {
    return '$count lebih sedikit dari periode lalu';
  }

  @override
  String get dashTrendFlat => 'Sama kayak periode lalu';

  @override
  String get dashQuickActions => 'Aksi cepat';

  @override
  String get dashStartCalibration => 'MULAI KALIBRASI';

  @override
  String get dashAddDevice => 'TAMBAH ALAT';

  @override
  String get dashRetry => 'COBA LAGI';

  @override
  String get dashSessionExpired => 'Sesi kamu habis. Login ulang ya.';

  @override
  String get dashLoadFailed => 'Gagal memuat dashboard.';

  @override
  String dashOverdueWarning(int count) {
    return '$count alat lewat jatuh tempo kalibrasi. Alat yang telat kalibrasi hasil ukurnya nggak bisa dipertanggungjawabkan.';
  }

  @override
  String get dashEmptyTitle => 'Belum ada data';

  @override
  String get dashEmptyBodyInput =>
      'Belum ada alat yang terdaftar. Mulai dengan nambahin alat ukur pertama.';

  @override
  String get dashEmptyBodyReadonly => 'Belum ada data yang bisa ditampilkan.';

  @override
  String get snackCalibInputSoon => 'Input kalibrasi digarap minggu 4.';

  @override
  String get profAccountInfo => 'Info Akun';

  @override
  String get profRoleLabel => 'Role';

  @override
  String get profChangePhotoSheet => 'Foto Profil';

  @override
  String get profChooseGallery => 'Pilih dari galeri';

  @override
  String get profTakePhoto => 'Ambil dari kamera';

  @override
  String get profRemovePhoto => 'Hapus foto';

  @override
  String get profPhotoUpdated => 'Foto profil diperbarui.';

  @override
  String get profPhotoRemoved => 'Foto profil dihapus.';

  @override
  String get profPhotoFailed => 'Gagal ambil foto. Coba lagi.';

  @override
  String get profAdminMenu => 'Menu Admin';

  @override
  String get profUserManagement => 'Manajemen Pengguna';

  @override
  String get profUserManagementSub => 'Digarap fase 3';

  @override
  String get profOrgData => 'Data Organisasi';

  @override
  String get profOrgDataSub =>
      'Nama, alamat & no. akreditasi buat kop sertifikat';

  @override
  String get profCustomers => 'Pelanggan';

  @override
  String get profCustomersSub => 'Kelola daftar pelanggan lab';

  @override
  String get profStandards => 'Standar Acuan';

  @override
  String get profStandardsSub => 'Kelola alat standar/acuan lab';

  @override
  String get profArsip => 'Arsip';

  @override
  String get profArsipSub => 'Folder perusahaan, alat & berkas sertifikat';

  @override
  String get profDesignSystem => 'Design System';

  @override
  String get profDesignSystemSub => 'Katalog warna, tipografi & komponen';

  @override
  String get profAppInfo => 'Info Aplikasi';

  @override
  String get profEnvironment => 'Environment';

  @override
  String get profApiBaseUrl => 'API base URL';

  @override
  String get profSecurity => 'Keamanan';

  @override
  String get profLogoutAll => 'Keluar dari semua perangkat';

  @override
  String get profLogoutAllSub =>
      'Buat kalau HP kamu ilang. Semua sesi dicabut — HP lain, tablet, termasuk yang ini.';

  @override
  String get profLogout => 'Keluar';

  @override
  String get profLogoutAllConfirmTitle => 'Keluar dari semua perangkat?';

  @override
  String get profLogoutAllConfirmBody =>
      'Semua sesi kamu bakal dicabut, termasuk di HP ini — kamu bakal diminta login lagi.\n\nPakai ini kalau HP kamu ilang atau dicuri.';

  @override
  String get profCancel => 'Batal';

  @override
  String get profRevokeAll => 'Cabut semua sesi';

  @override
  String profSessionsRevoked(int count) {
    return '$count sesi dicabut. Login lagi ya.';
  }

  @override
  String get profAllSessionsRevoked => 'Semua sesi dicabut. Login lagi ya.';

  @override
  String profRevokeFailed(String message) {
    return 'Gagal nyabut sesi: $message';
  }

  @override
  String get equipLoadFailed => 'Gagal memuat daftar alat.';

  @override
  String get equipSearchHint => 'Cari nama alat';

  @override
  String get equipFilterKategoriHint => 'Kategori';

  @override
  String get equipFilterStatusHint => 'Status';

  @override
  String get equipFilterSemua => 'Semua';

  @override
  String get equipStatusAktif => 'Aktif';

  @override
  String get equipStatusOverdue => 'Jatuh tempo';

  @override
  String get equipStatusNonaktif => 'Nonaktif';

  @override
  String get equipEmptyTitle => 'Belum ada alat';

  @override
  String get equipEmptyBody => 'Tambah alat pertama lewat tombol di bawah.';

  @override
  String get equipRetry => 'COBA LAGI';

  @override
  String get equipAdd => 'TAMBAH ALAT';

  @override
  String get equipEdit => 'Edit alat';

  @override
  String get equipMuatLebihBanyak => 'MUAT LEBIH BANYAK';

  @override
  String get equipDeleteConfirmTitle => 'Hapus alat?';

  @override
  String equipDeleteConfirmBody(String nama) {
    return '\"$nama\" bakal dihapus permanen.';
  }

  @override
  String equipDeleteFailed(String pesan) {
    return 'Gagal menghapus: $pesan';
  }

  @override
  String get equipNamaAlat => 'Nama alat';

  @override
  String get equipSerialNumber => 'Nomor seri';

  @override
  String get equipKategori => 'Kategori';

  @override
  String get equipKategoriHint => 'Pilih kategori alat';

  @override
  String get equipPelanggan => 'Pelanggan';

  @override
  String get equipPelangganHint => 'Pilih pelanggan';

  @override
  String get equipPelangganCariHint => 'Cari nama perusahaan';

  @override
  String get equipPelangganGagal => 'Gagal memuat daftar pelanggan.';

  @override
  String get equipPelangganKosong => 'Pelanggan nggak ketemu.';

  @override
  String get equipNamaAlatKemampuan => 'Jenis Alat (Kemampuan Kalibrasi)';

  @override
  String get equipNamaAlatKemampuanHint =>
      'Pilih jenis alat (opsional, buat CMC akurat)';

  @override
  String get equipNamaAlatKemampuanKosong =>
      'Kategori ini belum ada kemampuan kalibrasinya';

  @override
  String get equipNamaAlatKemampuanGagal =>
      'Gagal memuat daftar kemampuan kalibrasi.';

  @override
  String get equipCatatan => 'Catatan';

  @override
  String get equipMerk => 'Merk';

  @override
  String get equipModel => 'Model/Type';

  @override
  String get equipNoIdentifikasi => 'No. identifikasi';

  @override
  String get equipRangeMin => 'Rentang min.';

  @override
  String get equipRangeMax => 'Rentang maks.';

  @override
  String get equipSatuan => 'Satuan';

  @override
  String get equipResolusi => 'Resolusi';

  @override
  String get equipToleransi => 'Toleransi';

  @override
  String get equipToleransiWajib => 'Toleransi wajib diisi.';

  @override
  String get equipToleransiWajibHint =>
      'Alat tanpa toleransi nggak bisa dikalibrasi — PASS/FAIL-nya nggak bisa diputusin.';

  @override
  String get equipLokasi => 'Lokasi';

  @override
  String get equipStatus => 'Status';

  @override
  String get equipSave => 'SIMPAN';

  @override
  String equipSaveFailed(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String get historyEmptyTitle => 'Belum ada riwayat';

  @override
  String get historyEmptyBody =>
      'Sesi kalibrasi yang udah kelar bakal muncul di sini.';

  @override
  String get historyLoadFailed => 'Gagal memuat riwayat.';

  @override
  String get historySessionExpired => 'Sesi kamu habis. Login ulang ya.';

  @override
  String get historyRetry => 'COBA LAGI';

  @override
  String historyCertNumber(String nomor) {
    return 'No. sertifikat $nomor';
  }

  @override
  String get historyStatusPass => 'PASS';

  @override
  String get historyStatusFail => 'FAIL';

  @override
  String get historyStatusDraft => 'Draft';

  @override
  String get historyStatusMenungguApproval => 'Menunggu approval';

  @override
  String get historyStatusPerluRevisi => 'Perlu revisi';

  @override
  String get historyApprove => 'SETUJUI';

  @override
  String get historyReject => 'TOLAK';

  @override
  String historyApproveFailed(String pesan) {
    return 'Gagal nyetujui: $pesan';
  }

  @override
  String get historyRejectDialogTitle => 'Tolak sesi kalibrasi?';

  @override
  String get historyRejectDialogHint =>
      'Alasan penolakan (wajib diisi, teknisi bakal lihat ini)';

  @override
  String get historyRejectDialogSubmit => 'TOLAK SESI';

  @override
  String get historyRejectDialogCancel => 'Batal';

  @override
  String get historyRejectDialogEmpty => 'Alasan penolakan wajib diisi.';

  @override
  String historyRejectFailed(String pesan) {
    return 'Gagal nolak: $pesan';
  }

  @override
  String historyCatatanRevisi(String catatan) {
    return 'Catatan revisi: $catatan';
  }

  @override
  String get historyViewCertificate => 'Lihat sertifikat';

  @override
  String get certTitle => 'Sertifikat';

  @override
  String get certLoadFailed => 'Gagal memuat sertifikat.';

  @override
  String get certStatusMenungguGenerate => 'Lagi digenerate, tunggu sebentar';

  @override
  String get certStatusGagal => 'Gagal digenerate';

  @override
  String get certRetry => 'COBA GENERATE LAGI';

  @override
  String get certOpenPdf => 'LIHAT PDF';

  @override
  String certOpenFailed(String message) {
    return 'Nggak nemu aplikasi buat buka PDF: $message';
  }

  @override
  String get certBelumTerbit => 'Sertifikat belum terbit';

  @override
  String certQrToken(String token) {
    return 'Token QR: $token';
  }

  @override
  String get certRingkasanTitle => 'Ringkasan Hasil';

  @override
  String get certIdentitasTitle => 'Identitas Sesi';

  @override
  String get certTanggalKalibrasi => 'Tanggal kalibrasi';

  @override
  String get certTeknisi => 'Teknisi';

  @override
  String get certLokasi => 'Lokasi kalibrasi';

  @override
  String get certMetode => 'Metode kalibrasi';

  @override
  String get certReportTitle => 'Laporan Kalibrasi';

  @override
  String get certColStandard => 'Nilai Standar';

  @override
  String get certColUut => 'Pembacaan Alat';

  @override
  String get certColKoreksi => 'Koreksi';

  @override
  String get certColU95 => 'U95% (±)';

  @override
  String get certStandarDipakai => 'Standar yang Dipakai';

  @override
  String get certBelumDihitung =>
      'Titik ukurnya belum dihitung backend, jadi tabel laporannya belum bisa ditampilkan.';

  @override
  String get certDisclaimer =>
      '— Hasil kalibrasi tidak untuk diumumkan dan hanya berlaku untuk alat terkait —';

  @override
  String get certLihatDetail => 'LIHAT DETAIL PERHITUNGAN';

  @override
  String get detailTitle => 'Detail Hasil Kalibrasi';

  @override
  String get detailLoadFailed => 'Gagal memuat detail kalibrasi.';

  @override
  String detailNomorSesi(String nomor) {
    return 'No. sesi $nomor';
  }

  @override
  String get detailKondisiLingkungan => 'Kondisi Lingkungan & Standar';

  @override
  String get detailStandarAcuan => 'Standar acuan';

  @override
  String get detailSuhuRuang => 'Suhu ruang';

  @override
  String get detailKelembaban => 'Kelembaban';

  @override
  String get detailLokasi => 'Lokasi kalibrasi';

  @override
  String get detailLokasiLab => 'Di laboratorium';

  @override
  String get detailLokasiOnsite => 'Di lokasi pelanggan (onsite)';

  @override
  String get detailTitikUkurTitle => 'Titik Ukur';

  @override
  String get detailBelumDihitung =>
      'Sesi ini belum dihitung server — hasil bakal muncul begitu sesi diproses.';

  @override
  String get detailLihatSertifikat => 'LIHAT SERTIFIKAT';

  @override
  String detailTitikLabel(int index, String nilai) {
    return 'Titik $index · $nilai';
  }

  @override
  String get detailRataRata => 'Rata-rata';

  @override
  String get detailError => 'Error';

  @override
  String get detailKoreksi => 'Koreksi';

  @override
  String get detailStandarDeviasi => 'Standar deviasi';

  @override
  String get detailMaxStdev => 'Max STDEV';

  @override
  String get detailMaxStdevSebelum => 'Sebelum adjustment';

  @override
  String get detailTypeA => 'Type A';

  @override
  String get detailTypeB => 'Type B';

  @override
  String get detailKomponenTypeB => 'Rincian komponen Type B';

  @override
  String get detailToleransi => 'Toleransi';

  @override
  String get detailKetidakpastianGabungan => 'Ketidakpastian gabungan (uc)';

  @override
  String get detailFaktorCakupan => 'Faktor cakupan (k)';

  @override
  String get detailU95 => 'Ketidakpastian diperluas (U95%)';

  @override
  String get detailAwal => 'Awal';

  @override
  String get detailAkhir => 'Akhir';

  @override
  String get detailNilaiTerkoreksi => 'Nilai terkoreksi';

  @override
  String get detailU95Lingkungan => 'U95%';

  @override
  String get detailThermohygro => 'Thermohygro';

  @override
  String get detailMetode => 'Metode';

  @override
  String get detailSuhuLarutan => 'Suhu larutan';

  @override
  String get detailSebelumAdjustment => 'Sebelum adjustment (as found)';

  @override
  String get detailSesudahAdjustment => 'Sesudah adjustment (disertifikasi)';

  @override
  String get detailAsFoundCatatan =>
      'Dokumentasi kondisi alat waktu diterima — nggak ikut hasil yang disertifikasi.';

  @override
  String get detailPerluVerifikasi =>
      'Masih ada pembacaan OCR yang belum dikonfirmasi — sesi ini belum bisa di-approve.';

  @override
  String get arsipTitle => 'Arsip';

  @override
  String get arsipCariPerusahaan => 'Cari perusahaan...';

  @override
  String get arsipPerusahaanKosong => 'Belum ada perusahaan.';

  @override
  String get arsipFolderKosong => 'Folder ini masih kosong.';

  @override
  String get arsipLoadGagal => 'Gagal memuat arsip.';

  @override
  String get arsipRetry => 'COBA LAGI';

  @override
  String arsipRingkasPerusahaan(int alat, int sertifikat) {
    return '$alat alat · $sertifikat sertifikat';
  }

  @override
  String arsipRingkasFolder(int subfolder, int berkas) {
    return '$subfolder folder · $berkas berkas';
  }

  @override
  String get arsipFolderBaru => 'Folder baru';

  @override
  String get arsipNamaFolder => 'Nama folder';

  @override
  String get arsipNamaFolderHint => 'mis. 2026';

  @override
  String get arsipBuat => 'BUAT';

  @override
  String get arsipBatal => 'BATAL';

  @override
  String get arsipSimpan => 'SIMPAN';

  @override
  String get arsipGantiNama => 'Ganti nama';

  @override
  String get arsipHapus => 'Hapus';

  @override
  String get arsipHapusJudul => 'Hapus folder ini?';

  @override
  String arsipHapusIsi(String nama) {
    return 'Folder \"$nama\" bakal dihapus. Cuma folder kosong yang bisa dihapus.';
  }

  @override
  String get arsipTakBisaHapus => 'Pindahin atau hapus isinya dulu.';

  @override
  String get arsipFolderSistem => 'Folder perusahaan — diatur sistem.';

  @override
  String get arsipBerkasTanpaSertifikat => 'Sertifikat belum terbit';

  @override
  String get arsipDibuat => 'Folder dibuat.';

  @override
  String get arsipDiubah => 'Nama folder diubah.';

  @override
  String get arsipDihapus => 'Folder dihapus.';

  @override
  String get orgTitle => 'Data Organisasi';

  @override
  String get orgNama => 'Nama PT';

  @override
  String get orgAlamat => 'Alamat';

  @override
  String get orgTelepon => 'Telepon';

  @override
  String get orgEmail => 'Email';

  @override
  String get orgNoAkreditasi => 'No. akreditasi';

  @override
  String get orgAkreditasi => 'Status Akreditasi';

  @override
  String get orgAkreditasiBerlaku => 'Berlaku';

  @override
  String get orgAkreditasiKadaluarsa => 'Kadaluarsa';

  @override
  String get orgStandarAkreditasi => 'Standar akreditasi';

  @override
  String get orgStandarAkreditasiHint => 'mis. ISO/IEC 17025:2017';

  @override
  String get orgAkreditasiMulai => 'Berlaku mulai';

  @override
  String get orgAkreditasiBerakhir => 'Berlaku sampai';

  @override
  String get orgPilihTanggal => 'Pilih tanggal';

  @override
  String get orgSave => 'SIMPAN';

  @override
  String get orgSaved => 'Data organisasi disimpan.';

  @override
  String orgSaveFailed(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String get orgLoadFailed => 'Gagal memuat data organisasi.';

  @override
  String get orgRetry => 'COBA LAGI';

  @override
  String get standarTitle => 'Standar Acuan';

  @override
  String get standarLoadFailed => 'Gagal memuat standar acuan.';

  @override
  String get standarAdd => 'TAMBAH STANDAR';

  @override
  String get standarEdit => 'Edit standar';

  @override
  String get standarEmptyTitle => 'Belum ada standar acuan';

  @override
  String get standarEmptyBody =>
      'Tambah standar pertama lewat tombol di bawah.';

  @override
  String get standarRetry => 'COBA LAGI';

  @override
  String get standarBerlaku => 'Berlaku';

  @override
  String get standarKadaluarsa => 'Kadaluarsa';

  @override
  String get standarDeleteConfirmTitle => 'Hapus standar acuan?';

  @override
  String standarDeleteConfirmBody(String nama) {
    return '\"$nama\" bakal dihapus permanen.';
  }

  @override
  String standarDeleteFailed(String pesan) {
    return 'Gagal menghapus: $pesan';
  }

  @override
  String standarSaveFailed(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String get standarFaktorCakupanInvalid =>
      'Faktor cakupan (k) minimal 1 — biasanya 2.';

  @override
  String get standarNama => 'Nama standar';

  @override
  String get standarMerk => 'Merk';

  @override
  String get standarModel => 'Model/Type';

  @override
  String get standarSerialNumber => 'Nomor seri';

  @override
  String get standarNoSertifikat => 'No. sertifikat';

  @override
  String get standarTertelusurKe => 'Tertelusur ke';

  @override
  String get standarTertelusurKeHint => 'mis. SNSU-BSN';

  @override
  String get standarBerlakuSampai => 'Berlaku sampai';

  @override
  String get standarKetidakpastianTitle =>
      'Ketidakpastian (dari sertifikat standar)';

  @override
  String get standarKetidakpastian => 'Ketidakpastian (diperluas)';

  @override
  String get standarSatuanKetidakpastian => 'Satuan';

  @override
  String get standarFaktorCakupan => 'Faktor cakupan (k)';

  @override
  String get standarDrift => 'Drift per tahun';

  @override
  String get standarSave => 'SIMPAN';

  @override
  String get custTitle => 'Pelanggan';

  @override
  String get custSearchHint => 'Cari nama pelanggan';

  @override
  String get custEmptyTitle => 'Belum ada pelanggan';

  @override
  String get custEmptyBody => 'Tambah pelanggan pertama lewat tombol di bawah.';

  @override
  String get custLoadFailed => 'Gagal memuat pelanggan.';

  @override
  String get custRetry => 'COBA LAGI';

  @override
  String get custAdd => 'TAMBAH PELANGGAN';

  @override
  String get custEdit => 'Edit pelanggan';

  @override
  String get custNama => 'Nama pelanggan';

  @override
  String get custAlamat => 'Alamat';

  @override
  String get custContactPerson => 'Contact person';

  @override
  String get custTelepon => 'Telepon';

  @override
  String get custEmail => 'Email';

  @override
  String get custSave => 'SIMPAN';

  @override
  String get custCancel => 'Batal';

  @override
  String get custDelete => 'Hapus';

  @override
  String get custDeleteConfirmTitle => 'Hapus pelanggan?';

  @override
  String custDeleteConfirmBody(String nama) {
    return '\"$nama\" bakal dihapus permanen.';
  }

  @override
  String custDeleteFailed(String pesan) {
    return 'Gagal menghapus: $pesan';
  }

  @override
  String custSaveFailed(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String custEquipmentCount(int jumlah) {
    return '$jumlah alat';
  }

  @override
  String get custFieldRequired => 'Wajib diisi.';

  @override
  String get calibTitle => 'Input Kalibrasi';

  @override
  String get calibKategori => 'Kategori';

  @override
  String get calibKategoriHint => 'Pilih kategori alat';

  @override
  String get calibAlat => 'Alat';

  @override
  String get calibAlatHint => 'Pilih alat';

  @override
  String get calibAlatKosong => 'Nggak ada alat di kategori ini.';

  @override
  String get calibStandar => 'Standar Acuan';

  @override
  String get calibStandarHint => 'Pilih standar acuan';

  @override
  String get calibStandarKadaluarsa => 'kadaluarsa';

  @override
  String get calibTanggal => 'Tanggal kalibrasi';

  @override
  String get calibNomorOrder => 'Nomor order';

  @override
  String get calibNomorOrderHint => 'mis. 2405.13.A (opsional)';

  @override
  String get calibTanggalTerima => 'Tanggal terima alat';

  @override
  String get calibLokasi => 'Lokasi kalibrasi';

  @override
  String get calibLokasiLab => 'Di laboratorium';

  @override
  String get calibLokasiOnsite => 'Di lokasi pelanggan (onsite)';

  @override
  String get calibSuhuRuang => 'Suhu ruang (°C)';

  @override
  String get calibKelembaban => 'Kelembaban (%)';

  @override
  String calibTitikUkur(int index) {
    return 'Titik ukur $index';
  }

  @override
  String get calibNilaiTarget => 'Nilai target';

  @override
  String get calibSatuan => 'Satuan';

  @override
  String calibPembacaan(int index) {
    return 'Pembacaan $index';
  }

  @override
  String get calibTambahTitik => 'TAMBAH TITIK UKUR';

  @override
  String get calibHapusTitik => 'Hapus titik ukur';

  @override
  String get calibTambahPembacaan => '+ Tambah pembacaan';

  @override
  String get calibValidasiKategori => 'Pilih kategori dulu.';

  @override
  String get calibValidasiAlat => 'Pilih alat dulu.';

  @override
  String get calibValidasiStandar => 'Pilih standar acuan dulu.';

  @override
  String get calibValidasiAngka => 'Isi angka yang valid.';

  @override
  String get calibValidasiPembacaan =>
      'Tiap titik ukur minimal 2 pembacaan angka.';

  @override
  String get calibSimpanDraft => 'SIMPAN DRAFT';

  @override
  String get calibKirimApproval => 'KIRIM UNTUK APPROVAL';

  @override
  String get calibBerhasilDraft => 'Draft kalibrasi disimpan.';

  @override
  String get calibBerhasilApproval => 'Sesi kalibrasi dikirim untuk approval.';

  @override
  String calibGagal(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String get calibLoadPilihanGagal => 'Gagal memuat pilihan kategori/standar.';

  @override
  String get calibRetry => 'COBA LAGI';

  @override
  String get calibPilihKategoriTitle => 'Pilih Kategori Alat';

  @override
  String get calibPilihKategoriSubtitle =>
      'Pilih kelompok pengukuran dulu, baru jenis alat spesifiknya.';

  @override
  String get calibKategoriKosong => 'Belum ada kategori.';

  @override
  String calibJumlahAlat(int jumlah) {
    return '$jumlah jenis alat';
  }

  @override
  String get calibPilihInstrumenTitle => 'Pilih Jenis Alat';

  @override
  String get calibInstrumenKosong =>
      'Kategori ini belum punya data kemampuan kalibrasi.';

  @override
  String get calibInstrumenMetodeLabel => 'Metode';

  @override
  String get calibCariInstrumenHint => 'Cari jenis alat...';

  @override
  String get calibInstrumenTidakDitemukan =>
      'Nggak ketemu jenis alat yang cocok.';

  @override
  String get phCalibTitle => 'Kalibrasi pH Meter';

  @override
  String get phCalibThermohygro => 'Thermohygro dipakai';

  @override
  String get phCalibThermohygroHint => 'mis. TH-3';

  @override
  String get phCalibThermohygroCustom => 'Lainnya (isi manual)';

  @override
  String get phCalibStandarSesi => 'Standar Acuan (Termometer & Sensor)';

  @override
  String get phCalibStandarSesiHint =>
      'Dipakai buat kondisi lingkungan (suhu/kelembaban)';

  @override
  String get phCalibStandarBuffer => 'Standar buffer titik ini';

  @override
  String get phCalibStandarBufferHint => 'Pilih larutan buffer';

  @override
  String get phCalibValidasiStandarBuffer =>
      'Pilih standar buffer buat tiap titik (4, 7, 10) dulu.';

  @override
  String get phCalibKondisiLingkungan => 'Kondisi Lingkungan';

  @override
  String get phCalibSuhuAwal => 'Suhu awal (°C)';

  @override
  String get phCalibSuhuAkhir => 'Suhu akhir (°C)';

  @override
  String get phCalibKelembabanAwal => 'Kelembaban awal (%)';

  @override
  String get phCalibKelembabanAkhir => 'Kelembaban akhir (%)';

  @override
  String phCalibTitikBuffer(String label) {
    return 'Buffer pH $label';
  }

  @override
  String get phCalibNilaiStandar => 'Nilai acuan (terkoreksi suhu)';

  @override
  String get phCalibNilaiStandarHelper =>
      'Salin dari worksheet — nilai buffer yang udah dikoreksi suhu, bukan angka bulatnya.';

  @override
  String get phCalibNilaiStandarSebelum => 'Nilai acuan as-found';

  @override
  String get phCalibSebelumAdjustment => 'Sebelum adjustment (as found)';

  @override
  String get phCalibSesudahAdjustment => 'Sesudah adjustment (as left)';

  @override
  String get phCalibIdMerk => 'Merk';

  @override
  String get phCalibIdType => 'Type';

  @override
  String get phCalibIdNoSeri => 'No. Seri';

  @override
  String get phCalibIdRentang => 'Rentang ukur';

  @override
  String get phCalibIdResolusi => 'Resolusi alat';

  @override
  String get phCalibIdCustomer => 'Nama customer';

  @override
  String get phCalibFotoMembaca => 'Lagi membaca angka dari foto…';

  @override
  String get phCalibIdentitasCustomer => 'Identitas Customer';

  @override
  String get phCalibIdNamaAlat => 'Nama alat';

  @override
  String get phCalibIdKapasitasMax => 'Kapasitas maks.';

  @override
  String get phCalibIdAlamatCustomer => 'Alamat customer';

  @override
  String get phCalibIdCertificateNumber => 'No. sertifikat';

  @override
  String get phCalibIdOrderNumber => 'No. order';

  @override
  String get phCalibIdTechnicianId => 'Technician ID';

  @override
  String get phCalibIdCalibrationMethod => 'Calibration method';

  @override
  String get phCalibPengesahan => 'Pengesahan';

  @override
  String get phCalibIssuanceDate => 'Issuance date';

  @override
  String get phCalibCalculatedBy => 'Calculated by (inisial)';

  @override
  String get phCalibCalculatedByHint => 'mis. NR';

  @override
  String get phCalibSignedBy => 'Signed by (nama lengkap)';

  @override
  String get phCalibSignedByHint => 'mis. Alex Misramto';

  @override
  String get phCalibLiveJudul => 'Arahkan ke tabel';

  @override
  String get phCalibLivePetunjuk =>
      'Arahkan kamera ke tabel worksheet. Angka yang kebaca bakal muncul mengambang di layar.';

  @override
  String get phCalibLivePakai => 'PAKAI ANGKA INI';

  @override
  String get phCalibLiveTanpaKamera =>
      'Kamera nggak ketemu di HP ini. Kolomnya tetap bisa diketik manual.';

  @override
  String get phCalibCaraJudul => 'Mau diisi bagaimana?';

  @override
  String get phCalibCaraSub =>
      'Pilih sekali di awal. Bisa diganti nanti lewat tombol kamera di halaman data.';

  @override
  String get phCalibCaraFoto => 'Foto worksheet';

  @override
  String get phCalibCaraFotoKeterangan =>
      'Potret tabel yang sudah diisi — kolomnya terisi otomatis';

  @override
  String get phCalibCaraManual => 'Ketik manual';

  @override
  String get phCalibCaraManualKeterangan => 'Isi sendiri tiap kolom';

  @override
  String get phCalibCaraCatatan =>
      'Angka hasil foto tetap wajib dicek sebelum dikirim. Sertifikat yang sudah terbit tidak bisa diubah.';

  @override
  String get phCalibScanTooltip => 'Foto layar pH meter';

  @override
  String get phCalibScanGagal =>
      'Angkanya nggak kebaca jelas. Coba foto ulang lebih dekat, atau ketik manual.';

  @override
  String get phCalibScanError => 'Kamera nggak bisa dibuka.';

  @override
  String get phCalibFotoTabel => 'FOTO TABEL';

  @override
  String get phCalibFotoTabelSesudah => 'Sesudah adjustment';

  @override
  String get phCalibFotoTabelSebelum => 'Sebelum adjustment';

  @override
  String get phCalibFotoTabelJudul => 'Mau foto tabel yang mana?';

  @override
  String get phCalibFotoTabelInfo =>
      'Sekali foto ngisi satu tabel penuh buat ketiga buffer. Sel yang udah keisi nggak akan ditimpa — jadi boleh foto ulang berkali-kali.';

  @override
  String phCalibFotoTabelHasil(int terisi, int total) {
    return '$terisi dari $total sel keisi.';
  }

  @override
  String get phCalibFotoTabelTakTerbaca =>
      'Nggak ada angka yang kebaca sama sekali. Fotonya kemungkinan gelap, buram, atau kejauhan — coba lebih dekat dan terang. Kolomnya tetap bisa diketik manual.';

  @override
  String phCalibFotoTabelPosisiKacau(int jumlah) {
    return '$jumlah angka kebaca, tapi belum kebentuk tabel. Biasanya karena fotonya miring atau yang kefoto selembar penuh — coba foto TABEL-nya aja, tegak lurus dari atas. Kolomnya tetap bisa diketik manual.';
  }

  @override
  String get phCalibFotoTabelKosong =>
      'Angka di foto belum kebaca. Tips: foto TABEL-nya aja (nggak usah selembar penuh), tegak lurus dari atas, cahaya rata tanpa bayangan tangan. Atau ketik manual.';

  @override
  String get phCalibFotoTabelSisa =>
      'Sel yang kosong: ketik manual atau foto ulang — yang udah keisi nggak bakal keganti.';

  @override
  String get phCalibOcrBelumDikonfirmasi => 'Dari kamera — cek dulu';

  @override
  String get phCalibOcrKonfirmasi => 'SUDAH BENAR';

  @override
  String phCalibPembacaanKe(int index) {
    return 'Bacaan $index';
  }

  @override
  String get phCalibSuhu => 'Suhu';

  @override
  String get phCalibValidasiLingkungan =>
      'Isi kondisi lingkungan (suhu & kelembaban) dulu.';

  @override
  String phCalibValidasiPembacaan(int minimum) {
    return 'Tiap titik buffer wajib minimal $minimum pembacaan sesudah adjustment.';
  }

  @override
  String get phCalibValidasiNilaiAcuan =>
      'Isi nilai acuan (terkoreksi suhu) buat tiap titik buffer.';

  @override
  String get phCalibLangkahIdentitas => 'Identitas & kondisi';

  @override
  String get phCalibLangkahHasil => 'Data hasil kalibrasi';

  @override
  String phCalibLangkahKe(int nomor, int total) {
    return 'Langkah $nomor dari $total';
  }

  @override
  String get phCalibIdentitasAlat => 'Identitas Alat';

  @override
  String get phCalibPengerjaan => 'Pengerjaan';

  @override
  String get phCalibPelangganOtomatis =>
      'Data pelanggan ikut alat yang dipilih — sertifikatnya otomatis masuk folder perusahaan yang benar.';

  @override
  String get phCalibKoreksiSuhu => 'Koreksi suhu (°C)';

  @override
  String get phCalibKoreksiKelembaban => 'Koreksi kelembaban (%)';

  @override
  String get phCalibU95Suhu => 'U95% suhu';

  @override
  String get phCalibU95Kelembaban => 'U95% kelembaban';

  @override
  String get phCalibDariSertifikatTh =>
      'Dari sertifikat thermohygro — server nurunin U95% lingkungan dari angka ini.';

  @override
  String get phCalibLanjutkan => 'LANJUTKAN';

  @override
  String get phCalibKembali => 'KEMBALI';

  @override
  String get phCalibDisertifikasi => 'Disertifikasi';

  @override
  String get phCalibDokumentasi => 'Dokumentasi';

  @override
  String get phCalibDihitungServer =>
      'Rata-rata, budget ketidakpastian, U95% lingkungan & keputusan PASS/FAIL semuanya dihitung server.';

  @override
  String get phCalibOpsional => 'Opsional';

  @override
  String get notifEmptyTitle => 'Belum ada notifikasi';

  @override
  String get notifEmptyBody =>
      'Pengingat jatuh tempo & update approval bakal muncul di sini.';

  @override
  String get notifLoadFailed => 'Gagal memuat notifikasi.';

  @override
  String get notifSessionExpired => 'Sesi kamu habis. Login ulang ya.';

  @override
  String get notifRetry => 'COBA LAGI';

  @override
  String get notifMarkedRead => 'Ditandai udah dibaca.';

  @override
  String get notifTypeDueDate => 'Jatuh tempo';

  @override
  String get notifTypeApproval => 'Approval';

  @override
  String get notifTypeRevision => 'Revisi';

  @override
  String get teknisiTitle => 'Data Teknisi';

  @override
  String get teknisiFilterSemua => 'Semua';

  @override
  String get teknisiFilterPending => 'Pending';

  @override
  String get teknisiFilterAktif => 'Aktif';

  @override
  String get teknisiFilterNonaktif => 'Nonaktif';

  @override
  String get teknisiKosong => 'Belum ada akun di filter ini.';

  @override
  String get teknisiLoadGagal => 'Gagal memuat daftar akun.';

  @override
  String get teknisiRetry => 'Coba lagi';

  @override
  String get teknisiSetujui => 'Setujui';

  @override
  String get teknisiTolak => 'Nonaktifkan';

  @override
  String get teknisiResetPassword => 'Reset password';

  @override
  String get teknisiPilihRole => 'Pilih role buat akun ini';

  @override
  String get teknisiPilihRoleBatal => 'Batal';

  @override
  String get teknisiDisetujui => 'Akun disetujui.';

  @override
  String get teknisiDitolak => 'Akun dinonaktifkan.';

  @override
  String get teknisiPasswordDireset =>
      'Password direset. Kasih tahu password barunya ke orangnya langsung.';

  @override
  String get teknisiResetPasswordJudul => 'Reset password akun';

  @override
  String teknisiResetPasswordIsi(String nama) {
    return 'Tentukan password baru buat $nama. Sesi dia di semua perangkat bakal dicabut.';
  }

  @override
  String get teknisiResetPasswordLabel => 'Password baru';

  @override
  String get teknisiResetPasswordHelper =>
      'Minimal 8 karakter. Backend nggak ngirim email — kasih tahu orangnya langsung.';

  @override
  String get teknisiResetPasswordTerlaluPendek =>
      'Password minimal 8 karakter.';

  @override
  String get teknisiGagal => 'Aksi gagal. Coba lagi.';

  @override
  String get teknisiKonfirmTolakJudul => 'Nonaktifkan akun ini?';

  @override
  String get teknisiKonfirmTolakIsi =>
      'Dia bakal dikeluarkan dari semua perangkat dan nggak bisa login lagi. Riwayat kalibrasi yang lama tetap utuh.';

  @override
  String get teknisiTanpaEmployeeId => 'Tanpa ID pegawai';

  @override
  String get teknisiHanyaAdmin => 'Cuma admin yang bisa kelola akun.';

  @override
  String get menuUtama => 'Menu utama';

  @override
  String get menuMasterData => 'Master Data';

  @override
  String get menuPengaturan => 'Pengaturan';

  @override
  String get sheetTutup => 'TUTUP';

  @override
  String get sheetCobaLagi => 'COBA LAGI';

  @override
  String get sheetKirimBerhasil => 'Kekirim!';

  @override
  String get sheetKirimBerhasilPesan =>
      'Sesi kalibrasi udah masuk antrean approval admin.';

  @override
  String get sheetKirimGagal => 'Ada masalah';

  @override
  String get sheetDraftBerhasil => 'Draft tersimpan';

  @override
  String get sheetDraftBerhasilPesan =>
      'Bisa dilanjut kapan aja dari daftar riwayat.';

  @override
  String get phCalibTitikLengkap => 'Titik ini udah lengkap';

  @override
  String get dashCalibrationDone => 'Kalibrasi selesai';

  @override
  String get dashWorkChart => 'Grafik pekerjaan';

  @override
  String get tugasTitle => 'Tugas Saya';

  @override
  String get tugasKosong => 'Belum ada alat yang ditugaskan ke kamu.';

  @override
  String get tugasLoadGagal => 'Gagal memuat antrean tugas.';

  @override
  String get tugasRetry => 'COBA LAGI';

  @override
  String tugasJumlahAlat(int jumlah) {
    return '$jumlah alat';
  }

  @override
  String get tugasTelat => 'Lewat janji selesai';

  @override
  String get tugasMasuk => 'Masuk';

  @override
  String get tugasJanji => 'Janji selesai';

  @override
  String get tugasBelumDitugaskan => 'Belum dibagi';
}
