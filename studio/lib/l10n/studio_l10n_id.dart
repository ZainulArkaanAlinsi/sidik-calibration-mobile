// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'studio_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class StudioL10nId extends StudioL10n {
  StudioL10nId([String locale = 'id']) : super(locale);

  @override
  String get namaAplikasi => 'Sidik Studio';

  @override
  String get slogan => 'Pusat kendali data & olah data';

  @override
  String get masukJudul => 'Masuk ke Studio';

  @override
  String get masukKet => 'Pakai akun lab PT Sidik.';

  @override
  String get isianIdentitas => 'ID pegawai atau email';

  @override
  String get isianSandi => 'Kata sandi';

  @override
  String get isianIdentitasWajib => 'ID pegawai atau email wajib diisi.';

  @override
  String get isianSandiWajib => 'Kata sandi wajib diisi.';

  @override
  String get tombolMasuk => 'Masuk';

  @override
  String get tampilkanSandi => 'Tampilkan kata sandi';

  @override
  String get sembunyikanSandi => 'Sembunyikan kata sandi';

  @override
  String get gagalJaringan => 'Tidak bisa terhubung ke server. Coba lagi.';

  @override
  String gagalDiPerangkat(String detail) {
    return 'Masuk gagal di perangkat ini: $detail';
  }

  @override
  String get devJudul => 'BUILD DEV — akun uji';

  @override
  String devServer(String alamat) {
    return 'Server: $alamat';
  }

  @override
  String get seksiDataAcuan => 'Data acuan';

  @override
  String get seksiKelolaData => 'Kelola data';

  @override
  String get seksiLembarHitung => 'Lembar hitung';

  @override
  String tahapKode(String kode) {
    return 'Tahap $kode';
  }

  @override
  String tahapBelumTersedia(String kode) {
    return 'Belum tersedia — dibangun di Tahap $kode.';
  }

  @override
  String get keluar => 'Keluar';

  @override
  String get temaGelap => 'Tema gelap';

  @override
  String get temaTerang => 'Tema terang';

  @override
  String get bukaMenu => 'Buka menu';

  @override
  String get izinGagalJudul => 'Izin akun gagal dimuat.';

  @override
  String get cobaLagi => 'Coba lagi';

  @override
  String get memuat => 'Memuat…';

  @override
  String get seksiBeranda => 'Beranda';

  @override
  String get seksiPengesahan => 'Pengesahan';

  @override
  String get seksiImpor => 'Impor';

  @override
  String get seksiPengaturan => 'Pengaturan';

  @override
  String get peranAdmin => 'Master Data';

  @override
  String get peranTeknisi => 'Teknisi';

  @override
  String get peranViewer => 'Viewer';

  @override
  String get peranSuperAdmin => 'Super Admin';

  @override
  String get menuAkun => 'Akun & status server';

  @override
  String get bilahStatus => 'Bilah status';

  @override
  String statusServer(String alamat) {
    return 'Server $alamat';
  }

  @override
  String get statusMemeriksa => 'Memeriksa server…';

  @override
  String get statusTersambung => 'Tersambung';

  @override
  String get statusTerputus => 'Tidak tersambung';

  @override
  String get statusRealtimeNyala => 'Realtime nyala';

  @override
  String get statusRealtimeMati => 'Realtime mati';

  @override
  String get statusRealtimeTakDiketahui => 'Realtime tidak diketahui';

  @override
  String statusVersiApi(String versi) {
    return 'API $versi';
  }

  @override
  String berandaMasukSebagai(String nama, String peran) {
    return 'Masuk sebagai $nama · $peran';
  }

  @override
  String get berandaKosong => 'Belum ada ringkasan untuk akun ini.';

  @override
  String get berandaKosongKet =>
      'Kartu Beranda mengikuti izin akun dan modul yang sudah tersedia.';

  @override
  String get kartuBuka => 'Buka';

  @override
  String get kartuDataAcuanKosong => 'Belum ada paket data acuan.';

  @override
  String get kolomPaket => 'Paket';

  @override
  String get kolomVersiAktif => 'Versi aktif';

  @override
  String get kolomDraf => 'Draf';

  @override
  String get tanpaVersiAktif => 'Belum ada versi aktif';

  @override
  String get belumDiimpor => 'Belum diimpor';

  @override
  String get sesiBerakhirJudul => 'Sesi berakhir, masuk lagi';

  @override
  String sesiBerakhirKet(String nama, String identitas) {
    return 'Server tidak lagi menerima sesi ini. Masukkan kata sandi untuk melanjutkan sebagai $nama ($identitas). Layar dan isian Anda tetap di tempatnya.';
  }

  @override
  String get sesiBerakhirKeluar => 'Keluar & ganti akun';

  @override
  String get sesiAkunBerbeda =>
      'Server mengembalikan akun lain. Keluar, lalu masuk dengan akun yang benar.';

  @override
  String get kedaluwarsaJudul => 'Versi Studio ini terlalu lama untuk server.';

  @override
  String get kedaluwarsaKet =>
      'Pasang versi terbaru Sidik Studio, lalu buka lagi.';

  @override
  String kedaluwarsaVersi(String versi, String alamat) {
    return 'Studio $versi · server $alamat';
  }

  @override
  String get bukanAkunLab =>
      'Akun ini bukan akun lab. Studio hanya untuk orang lab.';

  @override
  String masukServerVersi(String alamat, String versi) {
    return 'Server $alamat · Studio $versi';
  }

  @override
  String get seksiWorkbookAlat => 'Workbook Alat';

  @override
  String kartuWorkbookRingkas(int jumlah, int belum) {
    return '$jumlah workbook · $belum belum dipetakan';
  }

  @override
  String kartuWorkbookSumber(int csv, int xlsm) {
    return '$csv dari CSV · $xlsm dari .xlsm';
  }

  @override
  String get workbookKet =>
      'Mode Asli Excel — baca saja. Sel persis seperti tersimpan di workbook master.';

  @override
  String get workbookCari => 'Cari nama workbook atau kode profil';

  @override
  String get workbookBelumDipetakan => 'Belum dipetakan';

  @override
  String get workbookBelumDipetakanKet =>
      'Belum punya profil kalibrasi — menunggu keputusan peta workbook.';

  @override
  String workbookJumlahLembar(int jumlah) {
    return '$jumlah lembar';
  }

  @override
  String get workbookKosong => 'Belum ada workbook yang diimpor.';

  @override
  String get workbookKosongKet =>
      'Workbook diimpor di server lewat perintah studio:impor-workbook.';

  @override
  String workbookTidakCocok(String cari) {
    return 'Tidak ada workbook yang cocok dengan “$cari”.';
  }

  @override
  String get workbookGagalMuat => 'Workbook gagal dimuat.';

  @override
  String get workbookTidakDitemukan =>
      'Workbook tidak ditemukan, atau bukan milik lab ini.';

  @override
  String workbookDiimpor(String tanggal) {
    return 'Diimpor $tanggal';
  }

  @override
  String get workbookSumberCsv =>
      'Dari ekspor CSV: nilai tersimpan saja — tanpa rumus, tanpa tata letak.';

  @override
  String get workbookSumberXlsm =>
      'Dari .xlsm master: nilai, rumus, dan tata letak.';

  @override
  String get workbookBerkasAsli => 'Berkas asli tersimpan di server';

  @override
  String get kembali => 'Kembali';

  @override
  String get workbookBacaSaja => 'Baca saja';

  @override
  String get workbookTampilkanRumus => 'Tampilkan rumus (Ctrl+`)';

  @override
  String get workbookTampilkanNilai => 'Tampilkan nilai (Ctrl+`)';

  @override
  String get workbookInspektur => 'Inspektur sel';

  @override
  String get workbookMuatUlang => 'Muat ulang';

  @override
  String get lembarTersembunyi => 'Lembar tersembunyi di Excel';

  @override
  String get lembarSangatTersembunyi =>
      'Lembar sangat tersembunyi (veryHidden) di Excel';

  @override
  String get lembarDikecualikanTab =>
      'Dikecualikan dari impor — data pelanggan/sertifikat';

  @override
  String lembarDikecualikanJudul(String tabel) {
    return 'Isi lembar ini data pelanggan/sertifikat — dikelola di tabel $tabel';
  }

  @override
  String get lembarDikecualikanTanpaTautan =>
      'Isi lembar ini data pelanggan/sertifikat — tidak diimpor ke Studio';

  @override
  String get lembarDikecualikanKet =>
      'Isinya tidak pernah dikirim ke Studio. Ubah datanya di tabelnya, bukan di workbook.';

  @override
  String get lembarKosong => 'Lembar ini kosong.';

  @override
  String get lembarTidakAda => 'Workbook ini tidak punya lembar.';

  @override
  String get lembarGagalMuat => 'Isi lembar gagal dimuat.';

  @override
  String kakiSel(int sel, int rumus) {
    return '$sel sel · $rumus rumus';
  }

  @override
  String kakiSumber(String sumber) {
    return 'Sumber $sumber';
  }

  @override
  String kakiPilihan(String rentang, int jumlah) {
    return 'Pilihan $rentang ($jumlah sel)';
  }

  @override
  String kakiSelCacat(int jumlah) {
    return '$jumlah sel tidak terbaca Studio versi ini';
  }

  @override
  String get inspekturAlamat => 'Alamat';

  @override
  String get inspekturGabungan => 'Gabungan';

  @override
  String get inspekturTipe => 'Tipe';

  @override
  String get inspekturNilai => 'Nilai persis (n)';

  @override
  String get inspekturTeks => 'Teks tampil (s)';

  @override
  String get inspekturRumus => 'Rumus (r)';

  @override
  String get inspekturFormat => 'Format angka (f)';

  @override
  String get inspekturGaya => 'Gaya';

  @override
  String get inspekturKet =>
      'Nilai persis = angka yang disimpan workbook, tanpa pembulatan. Teks tampil mengikuti format angka sel.';

  @override
  String get inspekturKosong => 'Sel kosong';

  @override
  String get tipeAngka => 'Angka';

  @override
  String get tipeTeks => 'Teks';

  @override
  String get tipeLogika => 'Logika';

  @override
  String get tipeGalat => 'Galat';

  @override
  String get tipeRumus => 'Rumus';

  @override
  String get tipeKosong => 'Kosong';

  @override
  String get gayaTebal => 'tebal';

  @override
  String get gayaMiring => 'miring';

  @override
  String gayaIsi(String warna) {
    return 'isi $warna';
  }

  @override
  String gayaWarnaTeks(String warna) {
    return 'teks $warna';
  }

  @override
  String gayaRata(String rata) {
    return 'rata $rata';
  }

  @override
  String get gayaGaris => 'bergaris';

  @override
  String gridDisalin(int baris, int kolom) {
    return '$baris × $kolom sel disalin';
  }

  @override
  String gridSalinTerlaluBesar(int jumlah, int batas) {
    return '$jumlah sel terlalu banyak untuk disalin (maks. $batas).';
  }

  @override
  String get gridSalinGagalMuat =>
      'Sebagian sel belum termuat — salin dibatalkan. Coba lagi.';

  @override
  String get devAlamatServer => 'Alamat server (dev)';

  @override
  String get devAlamatServerContoh => 'contoh http://192.168.1.10:8000/api';

  @override
  String get devAlamatServerSimpan => 'Simpan';

  @override
  String get devAlamatServerBawaan => 'Pakai bawaan';

  @override
  String get devAlamatServerTidakSah =>
      'Pakai http:// atau https:// dengan host.';

  @override
  String get devAlamatServerTersimpan =>
      'Tersimpan — dipakai sekarang & saat Studio dibuka lagi.';

  @override
  String devAlamatServerGagalSimpan(String detail) {
    return 'Gagal menyimpan di perangkat ini: $detail';
  }

  @override
  String devAlamatServerKet(String bawaan) {
    return 'Bawaan build: $bawaan';
  }

  @override
  String get workbookTutupInspektur => 'Tutup inspektur';

  @override
  String get workbookLencanaExcelAsli => 'Excel asli';

  @override
  String workbookSumberLain(int jumlah) {
    return 'Sumber lain ($jumlah)';
  }

  @override
  String get workbookSumberLainKet =>
      'Ekspor dari workbook alat yang sama. Excel aslinya ditampilkan di atas.';

  @override
  String lembarJugaDiTabel(String tabel) {
    return 'Juga di tabel $tabel';
  }

  @override
  String lembarJugaDiTabelKet(String tabel) {
    return 'Lembar ini tampil apa adanya dari workbook; data yang sama dikelola di tabel $tabel.';
  }

  @override
  String get kakiLebarPerkiraan => 'Lebar perkiraan';

  @override
  String get kakiLebarPerkiraanKet =>
      'Ekspor CSV tidak membawa lebar kolom; lebarnya diperkirakan server dari isi.';

  @override
  String get zoomPerkecil => 'Perkecil (Ctrl+−)';

  @override
  String get zoomPerbesar => 'Perbesar (Ctrl+=)';

  @override
  String get zoomPilih => 'Zoom';

  @override
  String get zoomPasLebar => 'Pas lebar';

  @override
  String get gayaBungkus => 'dibungkus';

  @override
  String gayaVertikal(String posisi) {
    return 'vertikal $posisi';
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
  String get workbookSimulasi => 'Simulasi';

  @override
  String get workbookSimulasiKet =>
      'Ubah sel untuk menghitung ulang workbook di server. Tidak ada yang disimpan.';

  @override
  String get simulasiSpanduk => 'Simulasi — tidak disimpan';

  @override
  String simulasiJumlahEdit(int jumlah) {
    return '$jumlah sel diubah';
  }

  @override
  String get simulasiReset => 'Reset';

  @override
  String get simulasiResetKet => 'Hapus semua edit — kembali ke isi workbook';

  @override
  String get simulasiMenghitung => 'Menghitung…';

  @override
  String get simulasiBatalkanTerakhir => 'Batalkan edit terakhir';

  @override
  String get simulasiGalatBerkasAsli =>
      'Workbook ini tidak punya berkas Excel asli di server — simulasi tidak bisa dihitung.';

  @override
  String simulasiGalatPerluSandi(String id) {
    return 'Model hitung workbook bersandi ini belum disiapkan di server — simulasi belum bisa dihitung. Minta admin menjalankan php artisan studio:siapkan-hitung $id (sandi diminta) atau mengimpor ulang berkas .xlsm-nya dengan sandi.';
  }

  @override
  String simulasiGalatDitolak(String pesan) {
    return 'Edit ditolak server: $pesan';
  }

  @override
  String get simulasiGalatLama =>
      'Hitung terlalu lama (batas server 20 detik) dan dibatalkan.';

  @override
  String get simulasiGalatSering =>
      'Terlalu sering menghitung — jatah server habis sementara. Edit berikutnya tetap tercatat tapi tidak dikirim otomatis; tunggu sebentar, lalu coba lagi.';

  @override
  String get simulasiGalatDilarang =>
      'Peran Anda tidak boleh menjalankan simulasi.';

  @override
  String simulasiGalatLain(String pesan) {
    return 'Simulasi gagal dihitung: $pesan';
  }

  @override
  String simulasiGalatHitung(int jumlah) {
    return '$jumlah galat mesin hitung';
  }

  @override
  String simulasiBatasEdit(int batas) {
    return 'Paling banyak $batas sel diubah dalam satu simulasi.';
  }

  @override
  String get simulasiUrungkan => 'Urungkan (Ctrl+Z)';

  @override
  String get simulasiUlangi => 'Ulangi (Ctrl+Y)';

  @override
  String get bilahSimpanEdit => 'Masukkan (Enter)';

  @override
  String get bilahBatalEdit => 'Batal (Esc)';

  @override
  String get lembarTampilkanTersembunyi => 'Tampilkan lembar tersembunyi…';

  @override
  String get lembarTampilkanJudul => 'Tampilkan lembar';

  @override
  String get lembarTampilkanKet =>
      'Tampilan saja — tidak disimpan ke workbook.';

  @override
  String get gambarGagalMuat => 'Gambar gagal dimuat';

  @override
  String get inspekturSimulasi => 'Isi simulasi';

  @override
  String get inspekturGalatHitung => 'Galat mesin hitung';

  @override
  String workbookImpor(int versi) {
    return 'Impor #$versi';
  }

  @override
  String workbookImporKet(int versi) {
    return 'Impor ke-$versi di jenis master ini — urutan impor, bukan penanda versi terbaru.';
  }

  @override
  String workbookRiwayat(int jumlah) {
    return 'Riwayat ($jumlah)';
  }

  @override
  String get workbookRiwayatKet =>
      'Versi lama master ini — tersembunyi dari daftar, tetap bisa dibuka (baca saja).';

  @override
  String riwayatJudul(String nama) {
    return 'Riwayat — $nama';
  }

  @override
  String get riwayatKet =>
      'Studio memegang satu master aktif per jenis. Impor master baru menggantikan yang aktif; yang lama disimpan di sini, tidak dihapus. Versi lama dibuka baca saja.';

  @override
  String get riwayatKosong => 'Belum ada riwayat untuk master ini.';

  @override
  String get riwayatGagalMuat => 'Riwayat gagal dimuat.';

  @override
  String get workbookStatusAktif => 'Master aktif';

  @override
  String get workbookStatusRiwayat => 'Riwayat';

  @override
  String get workbookRiwayatSpanduk => 'Riwayat — bukan master aktif';

  @override
  String get workbookRiwayatSpandukKet =>
      'Versi lama yang sudah digantikan. Tampil baca saja — tidak bisa diedit atau dihitung ulang.';

  @override
  String workbookDigantikanOleh(int id) {
    return 'digantikan #$id';
  }

  @override
  String get workbookDiarsipkan => 'Master ini sudah diarsipkan/diganti.';

  @override
  String get workbookKembaliKeDaftar => 'Kembali ke daftar';

  @override
  String get unggahMasterTombol => 'Unggah master';

  @override
  String get unggahMasterJudul => 'Unggah master';

  @override
  String get unggahMasterKet =>
      'Impor workbook master (.xlsm, .xlsx, atau .csv). Server mengekstraknya dan mencatat siapa yang melakukan serta alasannya.';

  @override
  String get unggahMasterPilihBerkas => 'Pilih berkas';

  @override
  String get unggahMasterBelumDipilih => 'Belum ada berkas';

  @override
  String get unggahMasterSandi => 'Sandi berkas (bila bersandi)';

  @override
  String get unggahMasterSandiKet =>
      'Dikirim sekali bersama unggahan. Tidak pernah disimpan.';

  @override
  String get unggahMasterAlasan => 'Alasan';

  @override
  String get unggahMasterAlasanKet =>
      'Mengapa master ini diimpor atau diganti (masuk jejak audit).';

  @override
  String get unggahMasterAlasanWajib => 'Alasan wajib diisi.';

  @override
  String get unggahMasterGantikan => 'Gantikan master (opsional)';

  @override
  String get unggahMasterGantikanTidak =>
      'Master baru (tidak menggantikan apa pun)';

  @override
  String get unggahMasterKirim => 'Unggah';

  @override
  String get unggahMasterMengirim => 'Mengunggah…';

  @override
  String get unggahMasterBerhasil =>
      'Master terunggah. Daftar sudah disegarkan.';

  @override
  String get unggahMasterBerkasWajib => 'Pilih berkas dulu.';

  @override
  String get unggahMasterFormatBerkas =>
      'Hanya berkas .xlsm, .xlsx, atau .csv yang diterima.';

  @override
  String get unggahMasterSandiSalah => 'Sandi berkas salah.';

  @override
  String get unggahMasterSandiDiperlukan =>
      'Berkas ini bersandi — isi sandinya.';

  @override
  String get unggahMasterFormatTidakDikenal =>
      'Server tidak mengenali format berkas ini.';

  @override
  String get unggahMasterGagal => 'Unggahan gagal.';
}
