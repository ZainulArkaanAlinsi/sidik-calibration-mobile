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
  String get loginIdentifierHint => 'SDK-0001 atau nama@pt-sidik.com';

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
  String get profTandaTangan => 'Tanda Tangan Sertifikat';

  @override
  String get profTandaTanganSub =>
      'Tanda tangan yang dicetak di sertifikat terbit';

  @override
  String get profCustomers => 'Pelanggan';

  @override
  String get profCustomersSub => 'Kelola daftar pelanggan lab';

  @override
  String get profStandards => 'Standar Acuan';

  @override
  String get profStandardsSub => 'Kelola alat standar/acuan lab';

  @override
  String get profPreferensi => 'Preferensi';

  @override
  String get profTema => 'Tema';

  @override
  String get profTemaTerang => 'Terang';

  @override
  String get profTemaGelap => 'Gelap';

  @override
  String get profTemaSistem => 'Ikut sistem';

  @override
  String get profBahasa => 'Bahasa';

  @override
  String get rumusTitle => 'Rumus Kalibrasi';

  @override
  String get rumusKetBatasan =>
      'Yang bisa diubah di sini parameter dan versinya — cara menghitungnya sendiri ada di program dan tidak diubah dari aplikasi. Setiap perubahan jadi versi baru supaya hasil hitung lama tetap bisa dijelaskan.';

  @override
  String get rumusKosong => 'Belum ada rumus yang tercatat.';

  @override
  String get rumusCobaLagi => 'Coba lagi';

  @override
  String rumusVersiBerlaku(int nomor) {
    return 'Versi $nomor berlaku';
  }

  @override
  String get rumusTanpaVersiBerlaku => 'Belum ada versi berlaku';

  @override
  String rumusJumlahVersi(int jumlah) {
    return '$jumlah versi';
  }

  @override
  String rumusVersiKe(int nomor) {
    return 'Versi $nomor';
  }

  @override
  String get rumusStatusAktif => 'Aktif';

  @override
  String get rumusStatusDraft => 'Draft';

  @override
  String get rumusStatusArsip => 'Arsip';

  @override
  String rumusBerlakuSejak(String mulai) {
    return 'Berlaku sejak $mulai sampai sekarang';
  }

  @override
  String rumusBerlakuRentang(String mulai, String selesai) {
    return 'Berlaku $mulai – $selesai';
  }

  @override
  String get rumusDibuatSistem => 'Dibuat sistem';

  @override
  String rumusDibuatOleh(String nama) {
    return 'Diterbitkan oleh $nama';
  }

  @override
  String get rumusTerbitkanVersi => 'Terbitkan versi baru';

  @override
  String get rumusTerbitkan => 'TERBITKAN';

  @override
  String get rumusBatal => 'Batal';

  @override
  String get rumusAktifkan => 'Aktifkan';

  @override
  String get rumusAktifkanJudul => 'Aktifkan versi ini?';

  @override
  String get rumusAktifkanKet =>
      'Versi ini akan dipakai menghitung mulai tanggal berlakunya, dan versi sebelumnya ditutup rentangnya.';

  @override
  String get rumusFormKet =>
      'Versi baru diterbitkan, bukan menimpa yang lama. Hasil hitung yang sudah terbit tetap menunjuk ke versi yang dipakai waktu itu.';

  @override
  String get rumusBerlakuDari => 'Berlaku dari';

  @override
  String get rumusParameter => 'Parameter';

  @override
  String get rumusCatatan => 'Catatan perubahan';

  @override
  String get rumusCatatanHint =>
      'Kenapa aturannya berubah — ini yang dibaca waktu diaudit.';

  @override
  String get rumusLangsungAktif => 'Langsung aktifkan';

  @override
  String get rumusLangsungAktifKet =>
      'Kalau dimatikan, versinya disimpan sebagai draft dulu — belum dipakai menghitung, jadi aman untuk dicoba.';

  @override
  String rumusVersiTerbit(int nomor) {
    return 'Versi $nomor diterbitkan.';
  }

  @override
  String get profRumus => 'Rumus Kalibrasi';

  @override
  String get profRumusSub => 'Parameter & riwayat versi perhitungan';

  @override
  String get ruanganTitle => 'Ruangan Lab';

  @override
  String get ruanganTambah => 'Tambah ruangan';

  @override
  String get ruanganUbah => 'Ubah ruangan';

  @override
  String get ruanganKosong =>
      'Belum ada ruangan yang tercatat. Selama kosong, sesi lab jalan tanpa ruangan — jadi tidak bisa dijawab dikerjakan di mana dan apakah kondisinya masuk syarat.';

  @override
  String get ruanganKode => 'Kode';

  @override
  String get ruanganNama => 'Nama ruangan';

  @override
  String get ruanganLokasi => 'Lokasi';

  @override
  String get ruanganSyarat => 'Syarat kondisi lingkungan';

  @override
  String get ruanganSuhuMin => 'Suhu min (°C)';

  @override
  String get ruanganSuhuMaks => 'Suhu maks (°C)';

  @override
  String get ruanganRhMin => 'RH min (%)';

  @override
  String get ruanganRhMaks => 'RH maks (%)';

  @override
  String get ruanganAktif => 'Aktif';

  @override
  String get ruanganAktifKet =>
      'Yang nonaktif tetap tersimpan, bukan dihapus — sesi lama menunjuk ke sini.';

  @override
  String get ruanganNonaktif => 'Nonaktif';

  @override
  String get ruanganWajib => 'Kode dan nama wajib diisi.';

  @override
  String get ruanganRentangKebalik =>
      'Nilai minimum tidak boleh lebih besar dari maksimum.';

  @override
  String get ruanganBatal => 'Batal';

  @override
  String get ruanganSimpan => 'SIMPAN';

  @override
  String get metodeTitle => 'Metode Kalibrasi';

  @override
  String get metodeTambah => 'Tambah metode';

  @override
  String get metodeUbah => 'Ubah metode';

  @override
  String get metodeKosong => 'Belum ada metode kalibrasi (IK) yang tercatat.';

  @override
  String get metodeKode => 'Kode IK';

  @override
  String get metodeRevisi => 'Revisi';

  @override
  String get metodeRevisiKet =>
      'Yang tercetak di sertifikat adalah revisi yang berlaku saat kalibrasi dikerjakan.';

  @override
  String get metodeNama => 'Nama metode';

  @override
  String get metodeBerlaku => 'Berlaku mulai';

  @override
  String get metodeBerlakuKosong => 'Belum diisi';

  @override
  String metodeBerlakuMulai(String tanggal) {
    return 'Berlaku mulai $tanggal';
  }

  @override
  String get metodeAktifKet =>
      'Yang nonaktif tetap tersimpan — sertifikat lama menyebut metode ini.';

  @override
  String get profRuangan => 'Ruangan Lab';

  @override
  String get profRuanganSub => 'Daftar ruangan & syarat kondisi lingkungan';

  @override
  String get profMetode => 'Metode Kalibrasi';

  @override
  String get profMetodeSub => 'Instruksi Kerja (IK) & revisinya';

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
  String get equipRentangOtomatis =>
      'Terisi otomatis dari data PT Sidik. Ganti manual kalau alat pelanggannya beda.';

  @override
  String get equipRentangPilihan =>
      'Rentang dari data PT Sidik — pencet yang sesuai alat pelanggannya:';

  @override
  String equipRentangChip(String min, String maks, String satuan) {
    return '$min–$maks $satuan';
  }

  @override
  String equipRentangChipBerparameter(
    String parameter,
    String min,
    String maks,
    String satuan,
  ) {
    return '$parameter · $min–$maks $satuan';
  }

  @override
  String get equipResolusi => 'Resolusi';

  @override
  String get equipResolusiRentang => 'Resolusi per titik';

  @override
  String get equipResolusiRentangHint =>
      'Isi kalau alat ini TIDAK seragam — resolusi atau satuannya berubah antar titik. Kosongkan kalau resolusi tunggal di atas sudah mewakili. Isian ini yang nentuin satuan tiap baris lembar kerja dan jumlah desimal yang kecetak di sertifikat.';

  @override
  String get equipResolusiBentukTitik => 'Titik standar';

  @override
  String get equipResolusiBentukMaks => 'Batas atas';

  @override
  String get equipResolusiTitik => 'Titik standar';

  @override
  String get equipResolusiMaks => 'Batas atas';

  @override
  String get equipResolusiMaksKosong => 'kosong = golongan terakhir';

  @override
  String get equipResolusiTambahBaris => 'TAMBAH BARIS RESOLUSI';

  @override
  String get equipResolusiHapusBaris => 'Hapus baris';

  @override
  String get equipResolusiBarisWajib => 'Wajib diisi, lebih besar dari 0.';

  @override
  String get equipResolusiTitikWajib => 'Wajib diisi.';

  @override
  String get equipResolusiBarisAdaYangSalah =>
      'Ada baris resolusi yang belum bener di bawah.';

  @override
  String get equipToleransi => 'Toleransi';

  @override
  String get equipToleransiWajib => 'Toleransi wajib diisi.';

  @override
  String get equipToleransiWajibHint =>
      'Alat tanpa toleransi nggak bisa dikalibrasi — PASS/FAIL-nya nggak bisa diputusin.';

  @override
  String get equipToleransiTidakDivonisHint =>
      'Jenis alat ini nggak divonis PASS/FAIL — masternya berhenti di U95%. Boleh dikosongin.';

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
  String get authServerTakTerjangkau => 'Nggak bisa menghubungi server.';

  @override
  String get authServerTakTerjangkauPesan =>
      'Sesi kamu masih tersimpan — nggak perlu masuk ulang. Cek koneksi, lalu coba lagi.';

  @override
  String get historyLoadFailed => 'Gagal memuat riwayat.';

  @override
  String get historySessionExpired => 'Sesi kamu habis. Login ulang ya.';

  @override
  String get historyRetry => 'COBA LAGI';

  @override
  String get historySegarkan => 'Segarkan daftar';

  @override
  String get historyPeringatanJudul => 'Periksa dulu sebelum disetujui';

  @override
  String get historyPeringatanBody =>
      'Sistem ngitung ulang sesi ini dan nemu hal yang perlu dilihat lagi. Kamu tetap boleh menyetujui — tapi sertifikatnya bakal terbit di atas data ini.';

  @override
  String get historyPeringatanBatal => 'PERIKSA LAGI';

  @override
  String get historyPeringatanLanjut => 'SETUJUI TETAP';

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
  String get certQrJudul => 'QR Verifikasi';

  @override
  String get certQrIsi =>
      'Scan buat ngecek sertifikat ini ke catatan kami. Bisa tanpa login.';

  @override
  String get certQrBelumAda =>
      'QR-nya belum ada — server belum nerbitin token verifikasi buat sertifikat ini.';

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
  String get detailPaneEmptyTitle => 'Belum ada sesi yang dipilih';

  @override
  String get detailPaneEmptyBody =>
      'Pilih satu sesi di sebelah kiri buat lihat titik ukurnya di sini.';

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
  String get detailProsesHitung => 'Proses hitung';

  @override
  String get detailProsesCatatan =>
      'Rumusnya disalin dari master Excel lab; angkanya dihitung server, bukan di HP.';

  @override
  String get detailRumusTypeA => '= STDEV / pembagi keterulangan';

  @override
  String get detailRumusTypeB => '= AKAR(jumlah kuadrat komponen di bawah)';

  @override
  String get detailVeff => 'Derajat kebebasan efektif';

  @override
  String get detailJumlahPengulangan => 'Jumlah pembacaan';

  @override
  String get detailKolStandard => 'Standar';

  @override
  String get detailKolU95 => 'U95%';

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
  String get detailAlatBantu => 'Alat bantu';

  @override
  String get detailTipePencelupan => 'Tipe pencelupan';

  @override
  String get detailTipeSensor => 'Tipe sensor standar';

  @override
  String get bannerStandarTanpaNama => 'Standar tanpa nama';

  @override
  String bannerStandarLewat(String nama, int hari) {
    return '$nama — sertifikatnya lewat $hari hari';
  }

  @override
  String bannerStandarSegera(String nama, int hari) {
    return '$nama — sertifikatnya habis $hari hari lagi';
  }

  @override
  String get detailUjiTitikEs => 'Uji titik es (30 menit)';

  @override
  String detailTitikEsKe(Object ke) {
    return 'X$ke';
  }

  @override
  String get detailRentangTitikEs => 'Rentang (Tmaks − Tmin)';

  @override
  String get detailPembacaanStandar => 'Pembacaan standard (probe lab)';

  @override
  String get detailPembacaanUut => 'Pembacaan UUT (alat pelanggan)';

  @override
  String get detailAsFoundCatatan =>
      'Dokumentasi kondisi alat waktu diterima — nggak ikut hasil yang disertifikasi.';

  @override
  String get detailPerluVerifikasi =>
      'Masih ada pembacaan OCR yang belum dikonfirmasi — sesi ini belum bisa di-approve.';

  @override
  String get detailVerifikasiTombol => 'Saya sudah cek angkanya';

  @override
  String get detailVerifikasiSukses =>
      'Pembacaan dikonfirmasi. Sesi ini sekarang bisa diperiksa admin.';

  @override
  String detailVerifikasiGagal(String pesan) {
    return 'Gagal mengonfirmasi: $pesan';
  }

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
  String get certSuksesJudul => 'Sertifikat berhasil dibuat';

  @override
  String get certSuksesNomor => 'Nomor sertifikat';

  @override
  String get certAksiPdf => 'Unduh PDF';

  @override
  String get certAksiExcel => 'Ekspor Excel';

  @override
  String get certAksiQr => 'Kode QR';

  @override
  String get certAksiSalinTautan => 'Salin tautan verifikasi';

  @override
  String get certAksiEmail => 'Kirim email';

  @override
  String get certAksiWhatsapp => 'Bagikan lewat WhatsApp';

  @override
  String get certAksiTutup => 'Selesai';

  @override
  String get certQrModalJudul => 'QR Sertifikat';

  @override
  String get certQrScanUntukVerifikasi => 'Scan buat verifikasi';

  @override
  String get certQrSimpanPng => 'Simpan PNG';

  @override
  String get certTautanDisalin => 'Tautan verifikasi disalin.';

  @override
  String certPngDisimpan(String lokasi) {
    return 'QR disimpan di $lokasi';
  }

  @override
  String certGagalBuka(String tujuan) {
    return 'Nggak bisa buka $tujuan di perangkat ini.';
  }

  @override
  String get certBelumAdaTautan =>
      'Backend belum nerbitin token verifikasi, jadi belum ada tautan yang bisa dibagiin.';

  @override
  String certPesanBagikan(String nomor, String tautan) {
    return 'Halo,\n\nSertifikat kalibrasi Anda sudah terbit.\n\nNomor Sertifikat:\n$nomor\n\nTautan Verifikasi:\n$tautan\n\nSilakan scan kode QR atau buka tautan di atas.\n\nTerima kasih.';
  }

  @override
  String certSubjekEmail(String nomor) {
    return 'Sertifikat Kalibrasi $nomor';
  }

  @override
  String get alurTitle => 'Alur Kerja';

  @override
  String get alurSub =>
      'Dari isian teknisi sampai sertifikatnya nyampe ke pelanggan.';

  @override
  String get alurPilihSesi =>
      'Pilih sesi di kiri buat lihat posisinya sekarang.';

  @override
  String get alurCari => 'Cari alat atau teknisi...';

  @override
  String get alurKosong => 'Belum ada sesi kalibrasi.';

  @override
  String get alurSesiBaru => 'Kalibrasi baru';

  @override
  String get alurTahapLembarKerja => 'Lembar kerja';

  @override
  String get alurTahapPerhitungan => 'Perhitungan & approval';

  @override
  String get alurTahapSertifikat => 'Sertifikat terbit';

  @override
  String get alurTahapKirim => 'Kekirim ke pelanggan';

  @override
  String get alurBukaLembarKerja => 'Buka lembar kerja';

  @override
  String get alurBukaPerhitungan => 'Buka lembar perhitungan';

  @override
  String get alurLihatSertifikat => 'Lihat sertifikat';

  @override
  String get alurKirimPelanggan => 'Kirim ke pelanggan';

  @override
  String get alurDetailSesi => 'Detail sesi';

  @override
  String get alurStatusDisetujui => 'Disetujui';

  @override
  String get alurSertifikatDigenerate =>
      'Sertifikatnya masih dibikin di server. Muat ulang sebentar lagi.';

  @override
  String alurCatatanRevisi(String catatan) {
    return 'Dibalikin admin: $catatan';
  }

  @override
  String get alurLangkahSekarang => 'Lagi di sini';

  @override
  String get alurLangkahSelesai => 'Beres';

  @override
  String get panelSeksiOperasional => 'Operasional';

  @override
  String get panelSeksiDokumen => 'Dokumen';

  @override
  String get panelSeksiSistem => 'Sistem';

  @override
  String get panelCariMenu => 'Cari menu...';

  @override
  String get panelMenuKosong => 'Nggak ada menu yang cocok.';

  @override
  String get panelSinkronAktif => 'Sinkron langsung aktif';

  @override
  String get panelSinkronMati => 'Sinkron langsung mati';

  @override
  String get panelTema => 'Ganti tema';

  @override
  String panelSubjudul(String akreditasi) {
    return 'Desktop · $akreditasi';
  }

  @override
  String get panelRingkasan => 'Ringkasan';

  @override
  String get panelRingkasanSub => 'Posisi lab saat ini.';

  @override
  String get panelBukaAntrean => 'Buka antrean approval';

  @override
  String get panelSebaranStatus => 'Sebaran status sesi';

  @override
  String get panelPerluTindakLanjut => 'TINDAK LANJUT';

  @override
  String panelSesiSelesai(int count) {
    return '$count sesi selesai';
  }

  @override
  String panelMasihDraft(int count) {
    return 'Plus $count masih draft';
  }

  @override
  String panelTotalSepanjangMasa(int count) {
    return 'Total sepanjang masa $count';
  }

  @override
  String get panelStatusBelumLengkap =>
      '\"Perlu revisi\" belum ada di respons dashboard — masih nunggu backend.';

  @override
  String get arsipPetunjukPindah => 'Tahan item-nya buat mindahin.';

  @override
  String get arsipTakBisaDipindah =>
      'Folder otomatis — tempatnya ngikut PT/tahun.';

  @override
  String arsipFolderDipindah(String tujuan) {
    return 'Folder dipindah ke \"$tujuan\".';
  }

  @override
  String arsipBerkasDipindah(String tujuan) {
    return 'Berkas dipindah ke \"$tujuan\".';
  }

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
  String get calibTambahAlatCta =>
      'Alatnya nggak ada di daftar? Tambah sendiri.';

  @override
  String calibTambahAlatDariCari(String nama) {
    return 'Tambah \"$nama\" sebagai alat baru';
  }

  @override
  String get calibTambahAlatJudul => 'Tambah Jenis Alat';

  @override
  String get calibTambahAlatLabel => 'NAMA ALAT';

  @override
  String get calibTambahAlatHint =>
      'Tulis persis kayak yang tertulis di alatnya';

  @override
  String get calibTambahAlatKosong => 'Nama alatnya diisi dulu.';

  @override
  String get calibTambahAlatPeringatanJudul => 'Baca dulu sebelum disimpan';

  @override
  String get calibTambahAlatPeringatanIsi =>
      'Alat yang kamu tambah sendiri belum punya angka batas dari lampiran akreditasi lab. Sesinya tetap bisa jalan dan sertifikatnya tetap terbit — tapi angka ± yang keluar dihitung pakai jalur umum, dan bisa lebih KECIL daripada angka yang biasa kita cetak buat alat yang udah terdaftar. Nggak ada error yang bunyi; angkanya cuma kelihatan terlalu bagus. Tetap boleh lanjut, tapi kabarin admin biar alat ini didaftarin resmi.';

  @override
  String get calibTambahAlatSimpan => 'SIMPAN & PAKAI';

  @override
  String get calibTambahAlatBatal => 'BATAL';

  @override
  String calibTambahAlatBerhasil(String nama) {
    return '\"$nama\" udah masuk daftar — langsung bisa dipilih.';
  }

  @override
  String calibTambahAlatKembar(String nama) {
    return '\"$nama\" udah ada di kategori ini. Tutup kotak ini terus cari di daftarnya.';
  }

  @override
  String calibTambahAlatGagal(String pesan) {
    return 'Gagal nambah alat: $pesan';
  }

  @override
  String get calibInstrumenTanpaCmc => 'Belum ada rentang CMC';

  @override
  String get calibTiNama => 'Temperatur Indikator';

  @override
  String get calibTiKartuRingkas =>
      'Dua jenis — pilih dulu sensornya ikut dikalibrasi atau nggak';

  @override
  String get calibTiGerbangPengantar =>
      'Pilih dulu sensornya ikut dikalibrasi atau nggak. Seluruh isi lembar berikutnya ngikut pilihan ini — titik ukurnya, standar acuannya, sampai rumus ketidakpastiannya. Salah pilih nggak bikin error apa pun, jadi pastiin di sini.';

  @override
  String get calibTiTanpaSensorJudul => 'Tanpa Sensor';

  @override
  String get calibTiTanpaSensorKeterangan =>
      'Sensornya NGGAK ikut dikalibrasi. Kalibrator disambung ke terminal indikator dan berperan jadi sensor tiruan, jadi yang diperiksa cuma bacaan indikatornya.';

  @override
  String get calibTiDenganSensorJudul => 'Dengan Sensor';

  @override
  String get calibTiDenganSensorKeterangan =>
      'Sensornya IKUT dikalibrasi. Sensor & indikator diperiksa sebagai satu rangkaian — sensornya dicelup bareng termometer acuan, jadi yang keluar bacaan rangkaian utuhnya.';

  @override
  String get calibTiBelumSiap => 'Belum ada di server ini';

  @override
  String calibTiBelumSiapPesan(String varian) {
    return 'Lembar kerja \"$varian\" belum ada di server yang lagi dipakai. Kabarin admin dulu — kalau dipaksa buka sekarang, yang kebuka lembar alat lain dan nggak ada satu pun error yang bunyi.';
  }

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
  String phCalibFotoHeaderHasil(int jumlah) {
    return 'Plus $jumlah kolom di luar tabel (kondisi, catatan, standar dipakai) — tolong dicek.';
  }

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
  String get certKirimEmail => 'KIRIM KE PELANGGAN';

  @override
  String get emailTitle => 'Kirim Sertifikat';

  @override
  String get emailHanyaAdmin => 'Cuma admin yang bisa ngirim sertifikat.';

  @override
  String get emailKeLabel => 'Ke';

  @override
  String get emailKeHint => 'pelanggan@perusahaan.com';

  @override
  String get emailCcLabel => 'Cc (opsional)';

  @override
  String emailPisahKoma(int maks) {
    return 'Pisahin pakai koma kalau lebih dari satu. Maks $maks masing-masing.';
  }

  @override
  String get emailKirim => 'KIRIM SEKARANG';

  @override
  String get emailMengirim =>
      'Lagi ngirim — ini nunggu sampai server email beneran nerima.';

  @override
  String get emailTerkirim => 'Sertifikat terkirim.';

  @override
  String get emailKeKosong => 'Isi minimal satu penerima.';

  @override
  String emailAlamatSalah(String alamat) {
    return 'Bukan alamat email yang sah: $alamat';
  }

  @override
  String emailKebanyakan(int maks) {
    return 'Maks $maks alamat.';
  }

  @override
  String get emailRiwayatJudul => 'Riwayat kirim';

  @override
  String get emailRiwayatKosong => 'Belum pernah dikirim.';

  @override
  String get emailRiwayatBerhasil => 'Terkirim';

  @override
  String get emailRiwayatGagal => 'Gagal';

  @override
  String emailRiwayatOleh(String nama) {
    return 'oleh $nama';
  }

  @override
  String get emailGagalMuat => 'Gagal memuat riwayat kirim.';

  @override
  String get emailRetry => 'COBA LAGI';

  @override
  String get emailFormatJudul => 'Yang dikirim';

  @override
  String get emailFormatPdf => 'PDF';

  @override
  String get emailFormatExcel => 'Excel';

  @override
  String get emailFormatTautan => 'Tautan';

  @override
  String get emailFormatPdfKet => 'Dokumen resminya, dilampirkan di email.';

  @override
  String get emailFormatExcelKet =>
      'Versi lembar kerja, dilampirkan — buat pelanggan yang ngolah datanya lagi.';

  @override
  String get emailFormatTautanKet =>
      'Cuma tautan verifikasi, tanpa lampiran. Pelanggan yang unduh sendiri dari halaman itu.';

  @override
  String get ttdTitle => 'Tanda Tangan Sertifikat';

  @override
  String get ttdHanyaAdmin =>
      'Cuma admin yang bisa ngatur tanda tangan sertifikat.';

  @override
  String get ttdBelumAda => 'Belum ada tanda tangan';

  @override
  String get ttdBelumAdaIsi =>
      'Sertifikat bakal kecetak tanpa tanda tangan sampai ada yang diunggah.';

  @override
  String get ttdUnggah => 'UNGGAH TANDA TANGAN';

  @override
  String get ttdGanti => 'Ganti';

  @override
  String get ttdHapus => 'Hapus';

  @override
  String get ttdHapusKonfirmJudul => 'Hapus tanda tangannya?';

  @override
  String get ttdHapusKonfirmIsi =>
      'Sertifikat baru bakal kecetak tanpa tanda tangan sampai kamu unggah lagi. Sertifikat yang udah terbit tetap bawa punyanya sendiri.';

  @override
  String get ttdHanyaPng =>
      'PNG doang — JPG nggak punya latar transparan, jadi kecetak sebagai kotak putih yang nutupin garis tanda tangan.';

  @override
  String get ttdPosisiJudul => 'Posisi cetak';

  @override
  String get ttdPosisiIsi =>
      'Berlaku buat SEMUA sertifikat, bukan satu-satu. Sertifikat yang udah terbit tetap pakai posisi waktu dia dicetak.';

  @override
  String ttdGeserX(String nilai) {
    return 'Mendatar ($nilai mm)';
  }

  @override
  String ttdGeserY(String nilai) {
    return 'Tegak ($nilai mm)';
  }

  @override
  String ttdLebar(String nilai) {
    return 'Lebar ($nilai mm)';
  }

  @override
  String get ttdArahX => 'negatif = ke kiri';

  @override
  String get ttdArahY => 'positif = NAIK';

  @override
  String get ttdSimpanPosisi => 'SIMPAN POSISI';

  @override
  String get ttdPosisiTersimpan => 'Posisi cetak tersimpan.';

  @override
  String get ttdTerunggah => 'Tanda tangan terunggah.';

  @override
  String get ttdTerhapus => 'Tanda tangan dihapus.';

  @override
  String get ttdGagalMuat => 'Gagal memuat pengaturan tanda tangan.';

  @override
  String get ttdRetry => 'COBA LAGI';

  @override
  String get teknisiResetPassword => 'Reset password';

  @override
  String get teknisiEdit => 'Edit akun';

  @override
  String teknisiEditJudul(String nama) {
    return 'Edit $nama';
  }

  @override
  String get teknisiEditNama => 'Nama lengkap';

  @override
  String get teknisiEditEmail => 'Email';

  @override
  String get teknisiEditEmployeeId => 'ID pegawai';

  @override
  String get teknisiEditDepartment => 'Departemen (opsional)';

  @override
  String get teknisiEditRole => 'Role';

  @override
  String get teknisiEditSimpan => 'Simpan';

  @override
  String get teknisiEditNamaKosong => 'Nama nggak boleh kosong.';

  @override
  String get teknisiEditEmailKosong => 'Email nggak boleh kosong.';

  @override
  String get teknisiEditEmailSalah => 'Ini kelihatannya bukan alamat email.';

  @override
  String get teknisiEditEmployeeIdKosong =>
      'ID pegawai nggak boleh kosong — itu yang dipakai buat login.';

  @override
  String get teknisiDiubah => 'Data akun diperbarui.';

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

  @override
  String get dashSummaryOrg => 'Ringkasan organisasi';

  @override
  String get dashSummaryYours => 'Ringkasan kamu';

  @override
  String get snackAddDeviceSoon => 'Tambah alat digarap minggu 3.';

  @override
  String get dashStartPhCalibration => 'KALIBRASI pH METER';

  @override
  String get lkTitle => 'Lembar Kerja';

  @override
  String get lkSubtitleDraft => 'Lanjut draft';

  @override
  String get lkSubtitleRevisi => 'Perbaiki — dikembalikan admin';

  @override
  String get lkLoadGagal => 'Gagal memuat bentuk lembar kerja.';

  @override
  String get lkRetry => 'COBA LAGI';

  @override
  String get lkPilihAlat => 'Pilih alat';

  @override
  String get lkAlatKosong => 'Belum ada alat.';

  @override
  String get lkRuanganGagal => 'Gagal memuat daftar ruangan.';

  @override
  String get lkContohNamaTempat => 'Contoh: PT. LDC';

  @override
  String get lkBelumPilihAlat =>
      'Pilih alatnya dulu — kolom identitas & pemilik keisi otomatis.';

  @override
  String get lkOtomatis => 'Keisi otomatis';

  @override
  String get lkKosong => '—';

  @override
  String get lkPilihTanggal => 'Pilih tanggal';

  @override
  String get lkHapusTanggal => 'Kosongkan tanggal';

  @override
  String get lkKondisiLingkungan => 'Environment Condition';

  @override
  String get lkWaktu => 'Time';

  @override
  String get lkSuhu => 'Temperature';

  @override
  String get lkKelembaban => 'Humidity';

  @override
  String get lkTekanan => 'Pressure';

  @override
  String get lkAwal => 'First';

  @override
  String get lkAkhir => 'End';

  @override
  String get lkPindaiGagalFoto => 'Foto tidak bisa dibaca. Coba jepret ulang.';

  @override
  String get lkPindaiTanpaGeometri =>
      'Koordinat sel lembar ini belum ada di server.';

  @override
  String get lkPindaiMarkerHilang =>
      'Empat penanda sudut tidak ketemu. Pastikan seluruh lembar masuk frame dan cukup terang.';

  @override
  String get lkPindaiTerlaluMiring =>
      'Fotonya terlalu miring. Jepret lebih tegak lurus di atas lembar.';

  @override
  String get lkFotoTabel => 'FOTO TABEL INI';

  @override
  String get lkFotoTabelGagal => 'Foto tidak bisa dibaca. Coba jepret ulang.';

  @override
  String get lkFotoTabelTanpaJangkar =>
      'Nggak ada angka yang bisa dipastikan tempatnya. Pastikan kolom nilai standar (kiri) dan kepala kolom Repeat (nomor 1..5, atau X1 / Repeat 1) ikut kefoto — semuanya, jangan ada yang kepotong. Kolomnya tetap bisa diketik manual.';

  @override
  String get lkTabelBelumDisimpan =>
      'Angka di tabel ini tercatat di lembar, tapi BELUM dikirim ke server — belum ada kolom yang menampungnya. Kertasnya jangan dibuang.';

  @override
  String get lkMatriksFotoTanpaJangkar =>
      'Nggak ada angka yang bisa dipastikan tempatnya. Pastikan kolom nama besaran di kiri (Temp. Disk 1, Indikator Pressure, …) dan kepala kolom titik waktu di atas ikut kefoto — semuanya, jangan ada yang kepotong. Baris yang namanya nggak kebaca nggak pernah keisi.';

  @override
  String get lkGridFotoTanpaJangkar =>
      'Nggak ada angka yang bisa dipastikan tempatnya. Pastikan kolom No. (nomor termokopel, di kiri) dan kepala kolom pengulangan di atas ikut kefoto — semuanya, jangan ada yang kepotong. Baris yang nomornya belum diketik nggak pernah keisi dari foto.';

  @override
  String lkGridFotoNomorKembar(String nomor) {
    return 'Set point ini nggak bisa difoto: nomor termokopel $nomor kepakai di lebih dari satu baris, jadi angkanya nggak bisa dipastikan masuk baris yang mana. Betulin dulu nomor kembarnya.';
  }

  @override
  String lkFotoTabelKolomHilang(String kolom) {
    return 'Label kolom $kolom nggak kebaca di foto, jadi nggak ada yang diisi — kalau dipaksa, angkanya bisa mendarat di kolom sebelah tanpa ketahuan. Jepret ulang dengan baris satuan di kepala tabel ikut masuk frame.';
  }

  @override
  String lkFotoTabelBarisKembar(String baris) {
    return 'Tabel lembar ini nggak bisa difoto: baris $baris kepakai lebih dari sekali sebagai penanda baris, jadi angkanya nggak bisa dipastikan masuk baris yang mana. Ini bentuk lembarnya, bukan fotonya — jepret ulang nggak nolong. Isi manual aja.';
  }

  @override
  String get lkFotoTabelKosong =>
      'Tabelnya kebaca, tapi kotak isiannya masih kosong — nggak ada angka tulisan tangan yang ketemu di dalamnya. Isi dulu kertasnya, baru difoto.';

  @override
  String get lkFotoTabelTanpaJangkarKeBawah =>
      'Nggak ada angka yang bisa dipastikan tempatnya. Pastikan kolom Repeat (kiri) dan kepala kolom larutan (baris paling atas) ikut kefoto — tanpa itu angkanya nggak bisa ditaruh dengan aman. Kolomnya tetap bisa diketik manual.';

  @override
  String lkFotoTabelTerisi(int terisi) {
    return '$terisi sel keisi dari foto. Semuanya ditandai perlu dicek — cocokin sama kertasnya.';
  }

  @override
  String lkFotoTabelSebagian(int terisi, int terbuang) {
    return '$terisi sel keisi, $terbuang angka dilewat karena tempatnya nggak bisa dipastikan. Yang kosong ketik manual.';
  }

  @override
  String lkFotoTabelError(String pesan) {
    return 'Foto tabel gagal: $pesan';
  }

  @override
  String lkPindaiTemplateGagal(String pesan) {
    return 'Bentuk lembar buat pindai gagal diambil: $pesan';
  }

  @override
  String get lkPindaiTemplateMemuat => 'Menyiapkan pindai…';

  @override
  String get lkPindaiQrHilang =>
      'Kode QR versi lembar nggak kebaca. Formulir lama tanpa QR nggak bisa dipindai — cetak ulang lembarnya, atau ketik manual.';

  @override
  String get lkPindaiQrLembarLain =>
      'QR yang kebaca punya lembar/versi lain. Foto ulang nggak nolong — pastikan lembarnya yang bener.';

  @override
  String get lkPindaiBuram =>
      'Fotonya buram. Tahan HP lebih diam, lalu foto ulang.';

  @override
  String get lkPindaiGelap =>
      'Terlalu gelap. Cari cahaya yang lebih terang, lalu foto ulang.';

  @override
  String get lkPindaiSilau =>
      'Terlalu terang sampai angkanya pudar. Kurangi cahaya langsung, lalu foto ulang.';

  @override
  String get lkPindaiPantulan =>
      'Ada pantulan cahaya di lembar. Geser sedikit posisinya, lalu foto ulang.';

  @override
  String get lkPindaiKejauhan =>
      'Fotonya kejauhan — angkanya kekecilan buat dibaca. Dekatkan HP, lalu foto ulang.';

  @override
  String lkPindaiTerpakai(int terisi) {
    return '$terisi sel keisi dari hasil pindai. Sel yang udah ada isinya nggak ditimpa.';
  }

  @override
  String lkPindaiBugAplikasi(String pesan) {
    return 'Pindai ditolak server: $pesan Ini kesalahan aplikasi, bukan fotonya — laporkan ke tim, dan ketik manual dulu.';
  }

  @override
  String get lkRepeat => 'Repeat';

  @override
  String get lkUsageCheckKosong => 'Belum ada standar acuan di master data.';

  @override
  String get lkUsageCheckKeterangan => 'Keterangan';

  @override
  String get lkStandarPerTitik => 'Standar titik';

  @override
  String get lkStandarKadaluarsa => 'sertifikat kadaluarsa';

  @override
  String lkStandarTitikDipakai(String label, String standar) {
    return 'Titik $label — $standar';
  }

  @override
  String get lkStandarTitikGanti => 'Ganti';

  @override
  String lkStandarSemuaTitikDipakai(String standar) {
    return 'Semua titik — $standar';
  }

  @override
  String get lkStandarTitikTercetak => 'Sesuai lembar kerja';

  @override
  String antreanSemuaPt(int jumlah) {
    return 'Semua PT ($jumlah)';
  }

  @override
  String get kirimLewatJudul => 'Kirim lewat';

  @override
  String get kirimLewatEmail => 'Email';

  @override
  String get kirimLewatWa => 'WhatsApp';

  @override
  String get waKeLabel => 'Nomor WhatsApp';

  @override
  String get waKeHint => '08123456789';

  @override
  String get waKeKosong => 'Isi minimal satu nomor WhatsApp.';

  @override
  String get waNomorSalah => 'Ada nomor yang formatnya nggak kebaca.';

  @override
  String get waKirim => 'BUKA WHATSAPP';

  @override
  String get waTercatat => 'Pengiriman tercatat di riwayat.';

  @override
  String get waTakBisaDibuka => 'WhatsApp nggak bisa dibuka di perangkat ini.';

  @override
  String get waKetPdf =>
      'WhatsApp nggak bisa dititipin lampiran, jadi yang dikirim tautan unduh PDF-nya langsung.';

  @override
  String get waKetExcel =>
      'Yang dikirim tautan unduh berkas Excel-nya langsung.';

  @override
  String get waKetTautan =>
      'Yang dikirim tautan halaman verifikasi — pelanggan lihat sertifikatnya di situ dan bisa unduh sendiri.';

  @override
  String get tolakJudul => 'Kembalikan ke teknisi';

  @override
  String get tolakPetunjuk =>
      'Pilih apa yang perlu dibetulin. Kolom yang kamu tandai bakal kesorot di lembar kerja teknisi, jadi dia nggak perlu nyari sendiri.';

  @override
  String get tolakDariPemeriksaan => 'Dari hasil pemeriksaan';

  @override
  String get tolakAlasanUmum => 'Alasan lain';

  @override
  String get tolakAlasanSerial => 'Serial number nggak cocok';

  @override
  String get tolakAlasanIdentitas => 'Identitas alat nggak lengkap';

  @override
  String get tolakAlasanPemilik => 'Data pemilik salah';

  @override
  String get tolakAlasanEnv => 'Env. Condition belum lengkap';

  @override
  String get tolakAlasanThermohygro => 'Thermohygro belum dipilih';

  @override
  String get tolakAlasanPembacaan => 'Pembacaan meragukan, ulangi';

  @override
  String get tolakAlasanUsageCheck => 'Usage Check belum dicentang';

  @override
  String get tolakCatatanTambahan => 'Catatan tambahan (opsional)';

  @override
  String get tolakCatatanHint => 'Jelasin kenapa, biar nggak keulang lagi.';

  @override
  String get tolakPratinjau => 'Yang bakal diterima teknisi';

  @override
  String get tolakKirim => 'KEMBALIKAN KE TEKNISI';

  @override
  String get lkPerluDibetulin => 'Diminta admin dibetulin';

  @override
  String get lkBannerRevisiTanpaKolom =>
      'Admin ngembaliin lembar kerja ini. Baca catatannya di bawah.';

  @override
  String get lkCatatanAdmin => 'CATATAN ADMIN';

  @override
  String lkRevisiJumlahKolom(int jumlah) {
    return '$jumlah kolom ditandai perlu dibetulin.';
  }

  @override
  String get lkBannerRevisi =>
      'Admin ngembaliin lembar kerja ini. Kolom yang ditandai di bawah yang perlu dibetulin.';

  @override
  String get lkStandarBelumTerdaftar => 'belum terdaftar di master standar';

  @override
  String antreanMasukBaru(int jumlah) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: '$jumlah lembar kerja baru masuk antrean approval',
      one: '1 lembar kerja baru masuk antrean approval',
    );
    return '$_temp0';
  }

  @override
  String get lkThermohygroKosong => 'Belum ada unit thermohygro terdaftar.';

  @override
  String lkHalamanKe(int nomor, int dari) {
    return 'Halaman $nomor dari $dari';
  }

  @override
  String get lkHalamanLanjut => 'LANJUT KE HALAMAN BERIKUTNYA';

  @override
  String get lkHalamanKembali => 'KEMBALI';

  @override
  String get lkPilih => 'Pilih';

  @override
  String get lkKirim => 'KIRIM KE ADMIN';

  @override
  String get lkSimpanDraft => 'SIMPAN SEBAGAI DRAFT';

  @override
  String get lkBerhasilKirim => 'Lembar kerja terkirim ke admin.';

  @override
  String get lkBerhasilDraft => 'Tersimpan sebagai draft.';

  @override
  String lkGagalKirim(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String get lkSemuaOpsional =>
      'Kolom yang belum bisa diisi di lapangan boleh dikosongin — lembar kerjanya tetap bisa dikirim.';

  @override
  String get lkBagianBelumBisaDiisi => 'BELUM BISA DIISI';

  @override
  String get pindaiReviewJudul => 'Cek Hasil Pindai';

  @override
  String pindaiRingkasan(int total, int kuning, int merah, int kosong) {
    return '$total sel dibaca · $kuning perlu dicek · $merah nggak kebaca · $kosong kosong';
  }

  @override
  String get pindaiCatatanKuning =>
      'Tulisan tangan nggak pernah ditandai aman otomatis — jadi wajar kalau hampir semuanya perlu dicek. Cocokin angkanya sama potongan foto di sebelahnya.';

  @override
  String get pindaiPakaiAngka => 'PAKAI ANGKA INI';

  @override
  String get pindaiDitahanServer =>
      'Masih ada sel yang nggak kebaca. Betulin dulu, atau ketik manual di lembar kerjanya.';

  @override
  String pindaiRepeat(int nomor) {
    return 'Repeat $nomor';
  }

  @override
  String pindaiTerbaca(String teks) {
    return 'Terbaca: $teks';
  }

  @override
  String pindaiNormalisasi(String catatan) {
    return 'Dibetulkan server: $catatan';
  }

  @override
  String pindaiKoreksiGagal(String pesan) {
    return 'Angkanya kepakai, tapi catatan koreksinya gagal dikirim: $pesan';
  }

  @override
  String get pindaiAlasanMeluber =>
      'tulisannya keluar dari kotak, bisa jadi kebaca dari kolom sebelah';

  @override
  String get pindaiAlasanLuarRentang =>
      'angkanya di luar rentang wajar titik ini';

  @override
  String get pindaiAlasanMagnitudo =>
      'angkanya jauh dari nilai standar titik ini';

  @override
  String get pindaiAlasanKoreksiKarakter => 'ada huruf yang ditebak jadi angka';

  @override
  String get pindaiAlasanDesimalBanyak =>
      'desimalnya lebih banyak dari resolusi alat';

  @override
  String get pindaiAlasanBukanKelipatan =>
      'angkanya nggak mungkin keluar dari alat dengan resolusi ini';

  @override
  String get pindaiAlasanJauhDariRepeat =>
      'angkanya jauh beda dari Repeat lain di baris ini';

  @override
  String get pindaiAlasanSebarTakDiuji =>
      'Repeat yang kebaca terlalu sedikit buat dibandingin';

  @override
  String get pindaiAlasanBanyakSubstitusi =>
      'terlalu banyak huruf yang harus ditebak';

  @override
  String get pindaiAlasanKarakterAsing => 'ada karakter yang bukan angka';

  @override
  String get pindaiAlasanBentukTakWajar => 'bentuk angkanya nggak masuk akal';

  @override
  String get pindaiAlasanDigitBanyak => 'digitnya kebanyakan buat kolom ini';

  @override
  String get pindaiAlasanPemisahTakWajar => 'letak koma/titiknya nggak wajar';

  @override
  String get pindaiAlasanDesimalAmbigu =>
      'nggak jelas titik itu koma desimal atau pemisah ribuan';

  @override
  String get pindaiAlasanMinusTengah => 'ada tanda minus di tengah angka';

  @override
  String get pindaiAlasanMinusTakBoleh =>
      'kolom ini nggak boleh bernilai negatif';

  @override
  String lkRepeatMenyimpang(String titik) {
    return 'Di titik $titik ada satu pembacaan yang jauh beda dari Repeat lainnya — cek lagi, kemungkinan ada digit yang ketuker waktu ngetik. Satu angka begini bisa bikin ketidakpastian di sertifikat meleset ratusan kali lipat.';
  }

  @override
  String lkPenentuAngkaKosong(String field) {
    return '$field belum dipilih. Tanpa itu server nggak bisa ngitung satu titik pun — semua baris pulang belum dihitung. Tetap kirim?';
  }

  @override
  String get lkPindaiBelumDiukur =>
      'Lembar ini belum punya berkas ukuran kotaknya, jadi pindainya belum bisa dipakai. Isi manual seperti biasa.';

  @override
  String get lkPindaiBelumDiverifikasi =>
      'Lembar cetaknya belum pernah diadu ke foto nyata, jadi pindainya masih ditahan. Isi manual seperti biasa.';

  @override
  String lkPindaiKurangKotak(int jumlah) {
    return 'Ada $jumlah kotak yang belum punya koordinat, jadi pindainya ditahan supaya nggak ada angka yang mendarat di kotak sebelah.';
  }

  @override
  String get lkPindaiLembar => 'PINDAI LEMBAR KERJA';

  @override
  String lkPindaiBelumSiap(String alasan) {
    return 'Belum bisa dipindai: $alasan';
  }

  @override
  String get lkPratinjauJudul => 'HASIL HITUNG SEMENTARA';

  @override
  String get lkPratinjauCatatan =>
      'Dihitung server dari isian yang sekarang, bukan di HP. Angkanya bisa berubah kalau baris lain ikut diisi.';

  @override
  String get lkPratinjauKolomTitik => 'Titik';

  @override
  String get lkPratinjauKolomRata => 'Rata-rata';

  @override
  String get lkPratinjauKolomKoreksi => 'Koreksi';

  @override
  String get lkPratinjauKolomU95 => 'U95';

  @override
  String get lkPratinjauBelumDihitung => 'BELUM BISA DIHITUNG';

  @override
  String lkPratinjauTitikKe(int nomor) {
    return 'Titik ke-$nomor';
  }

  @override
  String get lkKeluarTanpaSimpan => 'Keluar tanpa menyimpan?';

  @override
  String get lkKeluarTanpaSimpanBody => 'Yang udah kamu ketik bakal ilang.';

  @override
  String get lkKeluarBatal => 'LANJUT ISI';

  @override
  String get lkKeluarLanjut => 'KELUAR';

  @override
  String lkSuhuDiLuarRentang(String min, String max) {
    return 'Di luar rentang ruangan ini ($min–$max).';
  }

  @override
  String get navFolderManager => 'Folder';

  @override
  String get folderTitle => 'Folder Manager';

  @override
  String get folderEmptyTitle => 'Belum ada folder';

  @override
  String get folderEmptyBody =>
      'Folder kebentuk otomatis per PT seiring sertifikat terbit.';

  @override
  String get folderLoadFailed => 'Gagal memuat folder.';

  @override
  String get folderRetry => 'COBA LAGI';

  @override
  String get folderIsiKosong => 'Folder ini masih kosong.';

  @override
  String folderJumlahFolder(int jumlah) {
    return '$jumlah folder';
  }

  @override
  String folderJumlahFile(int jumlah) {
    return '$jumlah file';
  }

  @override
  String get folderOtomatis => 'Kebentuk otomatis';

  @override
  String get folderUnduh => 'Unduh';

  @override
  String get folderSertifikatBelumSiap => 'PDF sertifikatnya masih dibikin.';

  @override
  String get folderBukaBerkas => 'Buka berkas';

  @override
  String get folderBagikanBerkas => 'Bagikan sertifikat';

  @override
  String folderUnduhGagal(String pesan) {
    return 'Gagal mengunduh: $pesan';
  }

  @override
  String get notifTandaiSemua => 'Tandai semua dibaca';

  @override
  String get notifSemuaDibaca => 'Semua notifikasi ditandai udah dibaca.';

  @override
  String get notifKategoriJatuhTempo => 'Jatuh tempo';

  @override
  String get notifKategoriMenungguApproval => 'Nunggu approval';

  @override
  String get notifKategoriDisetujui => 'Disetujui';

  @override
  String get notifKategoriPerluRevisi => 'Perlu revisi';

  @override
  String get notifKategoriSertifikat => 'Sertifikat terbit';

  @override
  String get notifKategoriUmum => 'Info';

  @override
  String get phCalibCaraScan => 'Pindai langsung';

  @override
  String get phCalibCaraScanKeterangan =>
      'Arahkan kamera — angkanya muncul mengambang di layar';

  @override
  String get folderBuat => 'Folder baru';

  @override
  String get folderBuatJudul => 'Folder baru';

  @override
  String get folderNamaLabel => 'Nama folder';

  @override
  String get folderGantiNama => 'Ganti nama';

  @override
  String get folderGantiNamaJudul => 'Ganti nama folder';

  @override
  String get folderHapus => 'Hapus';

  @override
  String get folderHapusJudul => 'Hapus folder ini?';

  @override
  String folderHapusBody(String nama) {
    return '\"$nama\" bakal dibuang. Nggak bisa dibalikin.';
  }

  @override
  String get folderBatal => 'BATAL';

  @override
  String get folderSimpan => 'SIMPAN';

  @override
  String get folderHapusLanjut => 'HAPUS';

  @override
  String get folderSistemDikunci =>
      'Kebentuk otomatis — namanya ngikut PT/tahun, nggak bisa diubah.';

  @override
  String get folderNamaKosong => 'Isi nama foldernya dulu.';

  @override
  String get antreanTitle => 'Antrean Approval';

  @override
  String get antreanKosong => 'Nggak ada yang nunggu disetujui';

  @override
  String get antreanKosongBody =>
      'Lembar kerja yang dikirim teknisi bakal muncul di sini.';

  @override
  String get antreanGagal => 'Gagal memuat antrean.';

  @override
  String antreanOleh(String nama) {
    return 'oleh $nama';
  }

  @override
  String get waktuHariIni => 'Hari ini';

  @override
  String get waktuKemarin => 'Kemarin';

  @override
  String get tanggalKosong => '—';

  @override
  String get waktuBaruSaja => 'Baru saja';

  @override
  String waktuMenitLalu(int menit) {
    return '$menit menit lalu';
  }

  @override
  String waktuJamLalu(int jam) {
    return '$jam jam lalu';
  }

  @override
  String waktuHariLalu(int hari) {
    return '$hari hari lalu';
  }

  @override
  String get drafTitle => 'Draf';

  @override
  String get drafSubjudul => 'Lembar kerja yang disimpen, belum dikirim';

  @override
  String get drafCariHint => 'Cari nama alat atau pelanggan';

  @override
  String drafGrupJumlah(int jumlah) {
    return '$jumlah draf';
  }

  @override
  String drafDisimpan(String waktu) {
    return 'Disimpan $waktu';
  }

  @override
  String get drafKosongJudul => 'Belum ada draf';

  @override
  String get drafKosongBody =>
      'Lembar kerja yang kamu simpen lewat SIMPAN DRAF nunggu di sini.';

  @override
  String get drafCariKosong => 'Nggak ada draf yang cocok.';

  @override
  String get drafGagal => 'Gagal memuat daftar draf.';

  @override
  String get perhitTitle => 'Lembar perhitungan';

  @override
  String get perhitIdentitasAlat => 'IDENTITAS ALAT';

  @override
  String get perhitIdentitasCustomer => 'IDENTITAS CUSTOMER';

  @override
  String get perhitKondisi => 'PERHITUNGAN KONDISI LINGKUNGAN';

  @override
  String get perhitHasil => 'DATA HASIL KALIBRASI';

  @override
  String get perhitNamaAlat => 'Nama Alat';

  @override
  String get perhitMerk => 'Merk';

  @override
  String get perhitType => 'Type';

  @override
  String get perhitNoSeri => 'No. Seri';

  @override
  String get perhitRentang => 'Rentang Ukur';

  @override
  String get perhitKapasitas => 'Kapasitas Max.';

  @override
  String get perhitResolusi => 'Resolusi Alat';

  @override
  String get perhitCustNama => 'Nama Customer';

  @override
  String get perhitCustAlamat => 'Alamat Customer';

  @override
  String get perhitTglTerima => 'Tanggal Terima';

  @override
  String get perhitTglKalibrasi => 'Tanggal Kalibrasi';

  @override
  String get perhitSuhuRuangan => 'Suhu Ruangan';

  @override
  String get perhitKelembaban => 'Kelembaban';

  @override
  String get perhitAwal => 'Awal';

  @override
  String get perhitAkhir => 'Akhir';

  @override
  String get perhitAverage => 'Average';

  @override
  String get perhitObserved => 'dibaca (sebelum koreksi suhu)';

  @override
  String get perhitIndexed => 'Indexed Value';

  @override
  String get perhitCorrection => 'Correction';

  @override
  String get perhitDelta => 'Δ';

  @override
  String get perhitU95Std => 'U95% Std TH';

  @override
  String get perhitU95Sertifikat => 'U95% Sertifikat';

  @override
  String get perhitThermohygro => 'Thermohygro Used';

  @override
  String get perhitThermohygroKosong =>
      'Belum dipilih — koreksi & U95% bakal tetap kosong sampai diisi.';

  @override
  String get perhitStandard => 'Standard';

  @override
  String get perhitRepeat => 'Repeat';

  @override
  String get perhitStdev => 'STDEV';

  @override
  String get perhitMaxStdev => 'MAX STDEV';

  @override
  String get perhitCorrectionCatatan =>
      'Di lembar ini Correction = Average − Standard. Di sertifikat tandanya kebalikan.';

  @override
  String get perhitStandardCatatan =>
      'Standard itu nilai buffer pada suhu larutan, bukan nilai nominal.';

  @override
  String get perhitGagal => 'Gagal memuat lembar perhitungan.';

  @override
  String get perhitPeriksa => 'PERIKSA';

  @override
  String get perhitSetujui => 'SETUJUI';

  @override
  String get perhitTolak => 'TOLAK';

  @override
  String get perhitMemeriksa => 'Lagi ngitung ulang dari pembacaan mentah…';

  @override
  String get perhitTemuanJudul => 'Hasil pemeriksaan';

  @override
  String get perhitTemuanBersih => 'Nggak ada temuan. Aman disetujui.';

  @override
  String get perhitTingkatError => 'Nahan penerbitan';

  @override
  String get perhitTingkatPeringatan => 'Butuh konfirmasi';

  @override
  String get perhitTingkatInfo => 'Info';

  @override
  String get perhitApproveDiblokir =>
      'Ada temuan yang nahan penerbitan. Tombol setujui dimatiin.';

  @override
  String get perhitKonfirmasiJudul => 'Hasil hitung ulang beda. Lanjut?';

  @override
  String get perhitKonfirmasiBody =>
      'Angka hasil hitung ulang beda dari yang tersimpan. Kalau tetap disetujui, sertifikatnya terbit pakai angka yang tersimpan.';

  @override
  String get perhitKonfirmasiBatal => 'PERIKSA LAGI';

  @override
  String get perhitKonfirmasiLanjut => 'TETAP SETUJUI';

  @override
  String get perhitTolakJudul => 'Kembalikan buat direvisi';

  @override
  String get perhitTolakLabel => 'Apa yang harus dibenerin?';

  @override
  String get perhitTolakKosong =>
      'Tulis dulu apa yang harus dibenerin teknisi.';

  @override
  String get perhitTolakKirim => 'KEMBALIKAN';

  @override
  String get perhitDisetujui => 'Disetujui. Sertifikatnya lagi dibikin.';

  @override
  String get perhitDitolak => 'Dikembalikan ke teknisi.';

  @override
  String get perhitKolomAdmin => 'KOLOM ADMINISTRATIF';

  @override
  String get perhitNomorOrder => 'Order Number';

  @override
  String get perhitPilihThermohygro => 'Thermohygro used';

  @override
  String get perhitSimpanAdmin => 'SIMPAN';

  @override
  String get perhitAdminTersimpan => 'Kolom administratif tersimpan.';

  @override
  String get sertPratinjau => 'Pratinjau sertifikat';

  @override
  String get sertHasilJudul => 'Tabel Hasil Kalibrasi';

  @override
  String get sertKolStandard => 'Standard Value';

  @override
  String get sertKolUut => 'Unit Under Test';

  @override
  String get sertKolCorrection => 'Correction';

  @override
  String get sertKolU95 => 'U95%, k=2';

  @override
  String get sertU95Baris => 'Uncertainty U95% = ±';

  @override
  String sertFaktorCakupan(String k) {
    return 'Faktor cakupan (k) = $k, tingkat kepercayaan 95 %';
  }

  @override
  String get sertKolRemark => 'Remark';

  @override
  String get sertStandarJudul => 'Standar yang Digunakan';

  @override
  String get sertKolName => 'Name';

  @override
  String get sertKolMerk => 'Merk/Type';

  @override
  String get sertKolSerial => 'Serial Number';

  @override
  String get sertKolTraceable => 'Traceable to SI through';

  @override
  String get sertFooterTerbit => 'Tanggal terbit';

  @override
  String get sertFooterTtd => 'Penandatangan';

  @override
  String get sertFooterJabatan => 'Jabatan';

  @override
  String get sertFooterKode => 'Kode dokumen';

  @override
  String get sertUnduhPdf => 'PDF';

  @override
  String get sertUnduhExcel => 'EXCEL';

  @override
  String get sertLihatQr => 'QR CODE';

  @override
  String get sertBelumTerbit => 'File sertifikatnya belum siap.';

  @override
  String get sertGagalMuat => 'Gagal memuat sertifikat.';

  @override
  String sertUnduhGagal(String pesan) {
    return 'Gagal mengunduh: $pesan';
  }

  @override
  String get sertQrJudul => 'QR Sertifikat';

  @override
  String get sertQrBody => 'Scan buat buka halaman verifikasi sertifikat ini.';

  @override
  String get sertCorrectionCatatan =>
      'Di sertifikat Correction = Standard − Average — kebalikan dari lembar perhitungan.';

  @override
  String get importTitle => 'Import Excel';

  @override
  String get importPilihTipe => 'Mau import apa?';

  @override
  String get importTipeCustomers => 'Pelanggan / PT';

  @override
  String get importTipeStandards => 'Standar acuan';

  @override
  String get importTipeEquipments => 'Alat';

  @override
  String get importUrutanCatatan =>
      'Urutan import: pelanggan → standar → alat. Alat butuh PT-nya sudah ada duluan.';

  @override
  String get importPilihFile => 'PILIH FILE';

  @override
  String importFileTerpilih(String nama) {
    return 'File: $nama';
  }

  @override
  String get importUjiCoba => 'UJI COBA';

  @override
  String get importTerapkan => 'TERAPKAN SEKARANG';

  @override
  String get importUlangi => 'PILIH FILE LAIN';

  @override
  String get importBelumAdaFile => 'Pilih file .xlsx dulu.';

  @override
  String get importSedangJalan => 'Lagi baca filenya…';

  @override
  String get importRingkasan => 'Ringkasan';

  @override
  String get importDibaca => 'dibaca';

  @override
  String get importDibuat => 'dibuat';

  @override
  String get importDiperbarui => 'diperbarui';

  @override
  String get importDilewati => 'dilewati';

  @override
  String get importUjiCobaCatatan =>
      'Uji coba — belum ada yang disimpan. Periksa barisnya di bawah, baru terapkan.';

  @override
  String get importSelesai => 'Import diterapkan.';

  @override
  String get importTanpaPerubahan =>
      'Nggak ada yang berubah — nggak perlu diterapkan.';

  @override
  String get importKolomDikenal => 'Kolom yang dikenali';

  @override
  String get importKolomDiabaikan => 'Kolom yang diabaikan';

  @override
  String importBarisKe(int nomor) {
    return 'Baris $nomor';
  }

  @override
  String importGagal(String pesan) {
    return 'Import gagal: $pesan';
  }

  @override
  String get lkKirimAdmin => 'KIRIM';

  @override
  String get lkScanMemproses => 'AI lagi baca tabel…';

  @override
  String lkPengulanganRingkas(int n) {
    return '${n}x';
  }

  @override
  String get lkPengulanganTooltip => 'Jumlah kolom pengulangan';

  @override
  String lkPengulanganPilihan(int n) {
    return '$n kali pengulangan';
  }

  @override
  String get lkUbahPengulanganJudul => 'Ubah jumlah pengulangan?';

  @override
  String lkUbahPengulanganPesan(int n) {
    return 'Tabel hasil dibangun ulang jadi $n kolom, dan angka yang udah diketik di tabel akan hilang. Kolom identitas & kondisi ruangan tetap aman.';
  }

  @override
  String get lkUbahPengulanganLanjut => 'Ubah';

  @override
  String get lkPengulanganBatal => 'Batal';

  @override
  String lkSuhuWajib(String titik) {
    return 'Ada pembacaan tanpa suhu larutan di titik $titik. Suhunya wajib diisi — nilai acuannya digeser ikut suhu.';
  }

  @override
  String lkJamTidakTerbaca(String kolom) {
    return 'Kolom Time ke-$kolom bentuknya belum kebaca. Ketik angkanya aja — titik duanya muncul sendiri (mis. 0830 jadi 08:30). Kosongkan kalau titik waktu itu emang nggak diambil.';
  }

  @override
  String lkStandarBelumDicentang(String titik) {
    return 'Titik $titik udah diisi angkanya tapi standar acuannya belum dicentang — angkanya nggak bisa dihitung. Centang standarnya, atau kosongkan barisnya kalau alat ini emang nggak pakai titik itu.';
  }

  @override
  String lkSetPointKosong(String titik) {
    return 'Titik $titik udah diisi angkanya tapi kotak Setpoint-nya masih kosong atau nggak kebaca sebagai angka — SELURUH barisnya, termasuk kotak pembacaan yang udah diisi, nggak bakal ikut terkirim. Isi Setpoint-nya dulu, atau kosongkan barisnya kalau titik itu emang nggak dipakai.';
  }

  @override
  String lkPembacaanTakTerpulih(int jumlah) {
    return '$jumlah pembacaan tersimpan nggak ketemu barisnya di lembar ini dan nggak ikut dipulihkan. Cek tabelnya sebelum dikirim.';
  }

  @override
  String lkPembacaanJauhDariTitik(String titik) {
    return 'Pembacaan di titik $titik melesetnya lebih dari 10× dari nilai titiknya — cek satuannya, atau posisi komanya. Kalau angkanya emang segitu, pindah ke baris satuan yang benar dulu.';
  }

  @override
  String get detailTanpaVonis => 'TANPA VONIS';

  @override
  String get statusTanpaKeputusan => 'Tanpa PASS/FAIL';

  @override
  String get detailEditAdmin => 'EDIT LEMBAR';

  @override
  String get detailPerbaikiRevisi => 'PERBAIKI LEMBAR KERJA';

  @override
  String get detailLanjutkanDraft => 'LANJUTKAN DRAFT';

  @override
  String get lkTitikAlternatifSatuan => 'Terkunci: alternatif satuan';

  @override
  String get lkTitikAlternatifSatuanBantuan =>
      'Baris ini alternatif satuan dari botol yang sama, jadi cuma salah satu yang diisi. Mau pakai satuan ini? Kosongkan dulu semua isian di baris satunya — baris ini kebuka sendiri.';

  @override
  String get lkResolusiKosong => 'Resolusi: ( )';

  @override
  String lkResolusiNilai(String nilai, String satuan) {
    return 'Resolusi: $nilai $satuan';
  }

  @override
  String get lkSlotTanpaLarutan => 'belum ada larutannya';

  @override
  String lkIsianTitikKebuang(int jumlah) {
    String _temp0 = intl.Intl.pluralLogic(
      jumlah,
      locale: localeName,
      other: '$jumlah titik tidak ada di lembar alat ini — isiannya dibuang',
    );
    return '$_temp0';
  }

  @override
  String get lkKonfirmasiJudul => 'Cek dulu angkanya sebelum dikirim';

  @override
  String get lkKonfirmasiCatatan =>
      'Rata-rata pembacaan After adjustment. Koreksi & ketidakpastian dihitung server sesudah ini dikirim.';

  @override
  String get lkKonfirmasiDariFoto =>
      'Sebagian angka di tabel ini datang dari foto. Dengan mengirim, kamu menyatakan sudah mencocokkannya dengan yang tertera di alat.';

  @override
  String lkKonfirmasiGagalTandai(String pesan) {
    return 'Terkirim, tapi penandaan \"sudah dicek\" gagal: $pesan. Buka sesinya di Riwayat dan tekan \"Saya sudah cek angkanya\".';
  }

  @override
  String lkKonfirmasiBaris(int terisi, int total, String rata) {
    return '$terisi dari $total kotak · rata-rata $rata';
  }

  @override
  String get lkKonfirmasiBarisKosong => 'Belum diisi';

  @override
  String get lkKonfirmasiPeriksaLagi => 'Periksa lagi';

  @override
  String get lkKonfirmasiKirim => 'Kirim sekarang';

  @override
  String get lkPeringatanAngkaJudul => 'Angkanya kelihatan nggak wajar';

  @override
  String get lkPeringatanAngkaLanjut => 'Angkanya emang segitu — kirim';

  @override
  String get lkGantiSatuanJudul => 'Ganti satuan bakal ngosongin tabel';

  @override
  String lkGantiSatuanPesan(String dari, String ke) {
    return '$dari pakai larutan standar yang beda dari $ke, jadi baris tabelnya ikut ganti dan pembacaan yang udah diisi kehapus. Angka $dari nggak bisa dipakai sebagai $ke.';
  }

  @override
  String get lkGantiSatuanBatal => 'Batal';

  @override
  String get lkGantiSatuanLanjut => 'Ganti & kosongin';

  @override
  String get emailRiwayatBelumKeluar => 'Belum keluar';

  @override
  String emailKontakKosong(String pt) {
    return 'Email $pt belum diisi di data pelanggan. Isi lewat panel admin → Pelanggan, biar nanti tinggal pilih.';
  }

  @override
  String emailKontakKosongWa(String pt) {
    return 'Nomor WhatsApp $pt belum diisi di data pelanggan. Isi lewat panel admin → Pelanggan, biar nanti tinggal pilih.';
  }

  @override
  String get dashLiveWorkspace => 'Ruang kerja aktif';

  @override
  String dashGreetingName(String name) {
    return 'Halo, $name';
  }

  @override
  String dashActiveTasks(int count) {
    return '$count tugas aktif';
  }

  @override
  String get dashSpin3d => 'Geser bendanya buat muter';

  @override
  String get onbSkip => 'Lewati';

  @override
  String get onbNext => 'LANJUT';

  @override
  String get onbEnter => 'MASUK WORKSPACE';

  @override
  String get onbStep1Title => 'Semua alat, satu tempat.';

  @override
  String get onbStep1Body =>
      'Pilih alat, mulai kalibrasi, dan lihat statusnya tanpa nunggu laporan orang lain.';

  @override
  String get onbStep2Title => 'Lembar kerja tinggal difoto.';

  @override
  String get onbStep2Body =>
      'Angka di kertas kebaca langsung dari kamera. Nggak ada ketik ulang, dan fotonya nggak keluar dari HP kamu.';

  @override
  String get onbStep3Title => 'Sertifikat terbit lebih cepat.';

  @override
  String get onbStep3Body =>
      'Kirim ke admin begitu datanya lengkap. Approval dan penerbitan jalan di app yang sama.';

  @override
  String get profSwipeHint => 'Geser buat bagian berikutnya';

  @override
  String get profSectionWorkspace => 'RUANG KERJA';

  @override
  String get profSectionSystem => 'SISTEM';

  @override
  String get profSectionAccount => 'AKUN';

  @override
  String get profPreferensiSub => 'Atur cara perangkat ini kerja buat kamu.';

  @override
  String get profAdminMenuSub => 'Kelola data inti lab.';

  @override
  String get profLabSettings => 'Pengaturan lab';

  @override
  String get profLabSettingsSub => 'Metode, ruangan, dan rumus kerja.';

  @override
  String get profSecuritySub => 'Status perangkat dan akses akun.';

  @override
  String profSectionOf(int current, int total) {
    return 'Bagian $current dari $total';
  }

  @override
  String get profChangePhoto => 'Ganti foto profil';

  @override
  String get profChangePhotoSub => 'Diambil dari galeri atau kamera kamu';

  @override
  String get profTechnicianCode => 'Kode teknisi';

  @override
  String get profTechnicianCodeSub =>
      'Kecetak di sertifikat yang kamu tanda tangani';

  @override
  String get acHitung => 'Hitung';

  @override
  String get acSimpanKirim => 'Simpan & Kirim';

  @override
  String get acHasilOlahData => 'Hasil Olah Data';

  @override
  String get acCatatan => 'Catatan:';

  @override
  String get acSetPointWajib => 'Set Point wajib diisi.';

  @override
  String get acPilihAlatDulu =>
      'Pilih Alat (Equipment) dulu sebelum menyimpan.';

  @override
  String get acIsiMinimalSatuBlok =>
      'Isi minimal satu blok: data Suhu (disk/indikator) atau Tekanan.';

  @override
  String get acSesiLoginHabis => 'Sesi login habis, masuk lagi.';

  @override
  String get acTerkirimKeAdmin => 'Sesi Autoklaf terkirim ke admin.';

  @override
  String acGagalMenyimpan(String pesan) {
    return 'Gagal menyimpan: $pesan';
  }

  @override
  String acGagalMenghitung(String pesan) {
    return 'Gagal menghitung: $pesan';
  }

  @override
  String acGagalMuatAlat(String pesan) {
    return 'Gagal muat daftar alat: $pesan';
  }

  @override
  String get acDiLuarKertas => 'Di luar kertas — unduhan Pressure Disk Logger';

  @override
  String get acPetunjukDiskLogger =>
      'Angkanya diunduh dari disk logger, bukan ditulis di lapangan. Boleh dikosongin: lembarnya tetap kekirim, olah data tekanannya nunggu angka ini lengkap.';

  @override
  String get acNamaOtomatis => 'Name: (otomatis dari akun teknisi)';

  @override
  String get acPetunjukPilihAlat => 'pilih alat';

  @override
  String get lkAlatBaru => 'Alat baru';

  @override
  String get lkAlatKosongAjakan =>
      'Belum ada alat untuk lembar ini. Daftarkan alatnya dulu — jenis & kategorinya sudah terisi.';

  @override
  String lkAlatBaruTersimpan(String nama) {
    return 'Alat \"$nama\" tersimpan dan langsung dipakai di lembar ini.';
  }

  @override
  String get dinamisPerluDiperiksa => 'Perlu diperiksa';

  @override
  String dinamisPerluDiperiksaKeyakinan(int persen) {
    return 'Perlu diperiksa — keyakinan $persen%';
  }

  @override
  String dinamisPerluDiperiksaJumlah(int count) {
    return '$count nilai perlu diperiksa sebelum disimpan';
  }

  @override
  String get dinamisTercetak => 'Tercetak';

  @override
  String get dinamisBelumTerbaca => 'Belum terbaca';

  @override
  String get dinamisTanpaLabel => 'Tanpa label';

  @override
  String get dinamisTanpaJudulKolom => 'Kolom';

  @override
  String get dinamisLihatAsal => 'Lihat asalnya di foto';

  @override
  String get dokBacaJudul => 'Baca lembar kerja';

  @override
  String get dokBacaAjakan =>
      'Foto lembar kerjanya. Bentuk formnya ngikutin isi lembar — nggak perlu template.';

  @override
  String get dokBacaTombolFoto => 'Foto lembar';

  @override
  String get dokBacaSedang => 'Lagi membaca lembarnya…';

  @override
  String get dokBacaUlangFoto => 'Foto ulang';

  @override
  String get dokBacaMulaiLagi => 'Mulai lagi';

  @override
  String get dokBacaNamaAlatLabel => 'Nama alat (opsional)';

  @override
  String get dokBacaNamaAlatBantuan =>
      'Cuma petunjuk buat AI. Kalau isi lembarnya beda, yang dipakai lembarnya.';
}
