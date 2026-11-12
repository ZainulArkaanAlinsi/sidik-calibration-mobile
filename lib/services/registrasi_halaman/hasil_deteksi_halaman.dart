import 'geometri_halaman.dart';

/// Kenapa halaman TIDAK diluruskan. Urutan nilai = urutan tahap: makin besar
/// indeks, makin jauh deteksi sempat berjalan (dipakai memilih alasan yang
/// dilaporkan bila dua strategi sama-sama gagal).
///
/// Kegagalan SELALU berarti "jangan menebak": pemanggil jatuh ke foto asli +
/// input manual (atau meminta foto ulang), tidak pernah ke sudut perkiraan.
/// Teks untuk teknisi diambil dari l10n saat UI menyambung; [petunjuk] hanya
/// arah isi pesannya.
enum AlasanGagalRegistrasi {
  /// Berkas bukan gambar yang bisa dibaca, atau terlalu kecil.
  fotoTidakTerbaca('Foto tidak bisa dibaca; ambil ulang.'),

  /// Halaman dan alas hampir sama terang (alas putih/terang), atau tidak ada
  /// ambang yang memisahkan keduanya.
  kontrasKurang('Alas terlalu terang; taruh lembar di atas alas yang gelap.'),

  /// Tidak ada bidang terang yang cukup besar (halaman terpecah bayangan,
  /// terlalu jauh, atau tertutup tangan).
  halamanTidakTerdeteksi('Lembar tidak terlihat utuh; foto seluruh lembar.'),

  /// Halaman terdeteksi tetapi menempati kurang dari seperempat foto.
  halamanTerlaluKecil('Lembar terlalu kecil di foto; dekatkan kamera.'),

  /// Halaman keluar dari foto (sudut atau satu sisi terpotong).
  tepiTerpotong('Tepi lembar terpotong; foto seluruh lembar.'),

  /// Salah satu sisi tidak punya cukup titik, atau tidak ada kontras antara
  /// dalam dan luar garis tepi.
  sisiTidakJelas('Tepi lembar tidak jelas; perbaiki cahaya/alas.'),

  /// Tepi halaman tidak lurus (kertas melengkung/terlipat).
  sisiTidakLurus('Tepi lembar melengkung; ratakan kertas.'),

  /// Keempat sudut tidak membentuk segi empat yang wajar (tidak cembung,
  /// sudut di luar 60°–120°, atau tak ada homografi).
  bentukTidakWajar('Bentuk lembar tidak wajar; foto ulang dari atas.'),

  /// Rasio sisi hasil deteksi jauh dari rasio halaman formulir.
  rasioTidakCocok('Ukuran lembar tidak cocok dengan formulir ini.');

  const AlasanGagalRegistrasi(this.petunjuk);

  /// Arah pesan untuk teknisi (bukan teks l10n).
  final String petunjuk;
}

/// Ambang deteksi & sanity. Semuanya dalam pecahan atau piksel pada lebar
/// kerja, supaya tidak bergantung pada resolusi foto.
class OpsiRegistrasiHalaman {
  const OpsiRegistrasiHalaman({
    this.lebarKerja = 640,
    this.penutupRadius = 3,
    this.luasMinKomponen = 0.25,
    this.luasMaksKomponen = 0.97,
    this.pisahMinOtsu = 50,
    this.pisahMinKroma = 30,
    this.toleransiSudutLuar = 0.03,
    this.sisiDiBingkaiMaks = 0.5,
    this.sudutDalamMinDeg = 60,
    this.sudutDalamMaksDeg = 120,
    this.rmsSisiMaksPx = 1.6,
    this.rmsHalusMaksPx = 1.2,
    this.kontrasTepiMin = 20,
    this.toleransiRasio = 0.12,
  });

  /// Lebar citra kerja. 640 adalah patokan prototipe Python, yang melaporkan
  /// 1280 menurunkan deteksi (garis tabel/bingkai memecah komponen) dan dua
  /// foto salah sudut ~9,5% diagonal. Di port Dart, penutupan garis
  /// ([penutupRadius]) dan pemeriksaan kontras luar-jauh menghilangkan
  /// masalah itu (1280: 26/26, galat maks 0,06%), tetapi 1280 ≈ 3,5× lebih
  /// lambat (JIT, laptop): 640 tetap bawaan.
  final int lebarKerja;

  /// Radius penutupan abu-abu sebelum ambang (jendela `2r+1`): garis dan teks
  /// gelap yang lebih tipis dari jendela dihapus dari mask halaman. 0 = mati.
  /// Pada lebar kerja 640, 3 menghapus garis sampai ±6 px.
  final int penutupRadius;

  /// Komponen terang terbesar harus menutup minimal pecahan ini dari foto.
  final double luasMinKomponen;

  /// Di atas ini "halaman" menutup hampir seluruh foto: itu alas terang yang
  /// ikut ke dalam mask, bukan halaman.
  final double luasMaksKomponen;

  /// Selisih rata-rata kecerahan kelas terang dan gelap di ambang Otsu
  /// (tingkat abu 0–255) untuk kanal kecerahan dan RGB-terendah.
  ///
  /// Sengaja tinggi: cahaya tak rata (gradasi, vignette, bayangan tangan)
  /// sendirian membuat dua kelas Otsu berbeda 40–60 tingkat, jadi pemisahan
  /// di bawah itu bisa berarti "terang vs redup" pada alas dan kertas yang
  /// hampir sama terang — dan tepinya sah-tampak tetapi salah. Terukur pada
  /// foto sintetis: alas gelap/sedang ≥ 71, kayu terang 43–70 (kanal
  /// terendahnya ≥ 73), krem 29–40 (satu foto terkunci 6% diagonal dari
  /// sudut sebenarnya pada pemisahan 38). Alas yang tak melewati ambang ini
  /// jatuh ke kanal berikutnya, lalu ke kroma, lalu GAGAL.
  final double pisahMinOtsu;

  /// Seperti [pisahMinOtsu] untuk kanal kroma (skala 0–255 = kroma 0,3–0).
  /// Kroma tidak terpengaruh cahaya, jadi ambangnya lebih rendah; krem
  /// terukur 56–98.
  final double pisahMinKroma;

  /// Sudut boleh jatuh sejauh ini DI LUAR foto (pecahan diagonal segi empat):
  /// ujung sudut kertas yang terpotong ditambal putih saat warp dan tidak
  /// merusak isi, karena formulir bermargin.
  final double toleransiSudutLuar;

  /// Pecahan titik siluet sebuah sisi yang menempel di bingkai foto. Sisi
  /// yang SEBAGIAN keluar foto (sudut terpotong, tertolong
  /// [toleransiSudutLuar]) hanya menyentuh bingkai di sebagian kecil
  /// panjangnya; sisi yang keluar utuh membuat garis yang dicocokkan adalah
  /// bingkai foto, bukan tepi kertas.
  final double sisiDiBingkaiMaks;

  final double sudutDalamMinDeg;
  final double sudutDalamMaksDeg;

  /// Ketidaklurusan sisi menurut SILUET mask (RMS terpangkas, piksel pada
  /// [lebarKerja]). Dipakai hanya bila perhalusan gradien tidak punya cukup
  /// data; siluet ikut tercemar bercak yang menempel di tepi, jadi ambangnya
  /// lebih longgar daripada [rmsHalusMaksPx].
  final double rmsSisiMaksPx;

  /// Ketidaklurusan sisi menurut titik puncak gradien. Ukuran yang lebih
  /// jujur untuk kertas melengkung. Diukur pada foto sintetis: tepi
  /// menggembung 1% lebar halaman → galat sudut 0,36% diagonal (diterima);
  /// 2% → RMS 1,5–1,7 px dan galat sudut 0,8% (ditolak).
  final double rmsHalusMaksPx;

  /// Selisih kecerahan dalam-luar di sepanjang tiap sisi (median, tingkat
  /// abu 0–255; dipakai juga sebagai puncak gradien minimum perhalusan).
  /// Mengenali "tepi" palsu: gradasi cahaya, atau struktur dalam halaman (pita
  /// kop berarsir) yang tampak seperti tepi bila tepi kertas sebenarnya tak
  /// terlihat di alas putih. Diukur pada foto sintetis: tepi kertas di alas
  /// gelap/kayu ≥ 60, alas krem ≥ 27, sedangkan tepi palsu di alas putih
  /// 15–19 (12 meloloskannya: salah sudut 7% diagonal).
  final double kontrasTepiMin;

  /// Selisih relatif rasio terhadap rasio halaman formulir (|r/rHalaman - 1|).
  final double toleransiRasio;
}

/// Catatan teknis satu deteksi: untuk log, laporan ukur, dan test.
class DiagnostikRegistrasi {
  const DiagnostikRegistrasi({
    this.strategi,
    this.ambangOtsu,
    this.pisahOtsu,
    this.luasKomponen,
    this.rmsSisiPx = const [],
    this.kontrasSisi = const [],
    this.sudutDalamDeg = const [],
    this.luasSegiEmpat,
    this.halusTepi = false,
    this.geserHalusPx,
    this.lebarKerjaPx,
    this.tinggiKerjaPx,
    this.durasiKecilMs,
    this.durasiDeteksiMs,
  });

  /// `luma` atau `minimum` (kanal RGB terendah) — strategi yang lolos.
  final String? strategi;
  final int? ambangOtsu;

  /// Selisih rata-rata kecerahan kelas terang dan gelap di ambang Otsu.
  final double? pisahOtsu;

  /// Pecahan foto yang ditutup komponen terbesar.
  final double? luasKomponen;

  /// Urutan sisi atas, kanan, bawah, kiri.
  final List<double> rmsSisiPx;
  final List<double> kontrasSisi;
  final List<double> sudutDalamDeg;

  /// Pecahan foto yang ditutup segi empat.
  final double? luasSegiEmpat;

  /// Sudut akhir berasal dari perhalusan puncak gradien (bukan dari siluet
  /// mask), dan geseran sudut terbesar akibatnya (piksel citra kerja).
  final bool halusTepi;
  final double? geserHalusPx;
  final int? lebarKerjaPx;
  final int? tinggiKerjaPx;
  final double? durasiKecilMs;
  final double? durasiDeteksiMs;

  DiagnostikRegistrasi salinDengan({
    double? durasiKecilMs,
    double? durasiDeteksiMs,
  }) => DiagnostikRegistrasi(
    strategi: strategi,
    ambangOtsu: ambangOtsu,
    pisahOtsu: pisahOtsu,
    luasKomponen: luasKomponen,
    rmsSisiPx: rmsSisiPx,
    kontrasSisi: kontrasSisi,
    sudutDalamDeg: sudutDalamDeg,
    luasSegiEmpat: luasSegiEmpat,
    halusTepi: halusTepi,
    geserHalusPx: geserHalusPx,
    lebarKerjaPx: lebarKerjaPx,
    tinggiKerjaPx: tinggiKerjaPx,
    durasiKecilMs: durasiKecilMs ?? this.durasiKecilMs,
    durasiDeteksiMs: durasiDeteksiMs ?? this.durasiDeteksiMs,
  );

  Map<String, Object?> toJson() => {
    'strategi': strategi,
    'ambang_otsu': ambangOtsu,
    'pisah_otsu': pisahOtsu,
    'luas_komponen': luasKomponen,
    'rms_sisi_px': rmsSisiPx,
    'kontras_sisi': kontrasSisi,
    'sudut_dalam_deg': sudutDalamDeg,
    'luas_segi_empat': luasSegiEmpat,
    'halus_tepi': halusTepi,
    'geser_halus_px': geserHalusPx,
    'lebar_kerja_px': lebarKerjaPx,
    'tinggi_kerja_px': tinggiKerjaPx,
    'durasi_kecil_ms': durasiKecilMs,
    'durasi_deteksi_ms': durasiDeteksiMs,
  };
}

/// Hasil deteksi empat sudut (tahap a+b, tanpa meluruskan).
sealed class HasilDeteksiHalaman {
  const HasilDeteksiHalaman();
}

final class DeteksiHalamanBerhasil extends HasilDeteksiHalaman {
  const DeteksiHalamanBerhasil({required this.sudut, required this.diagnostik});

  /// Urutan kiri-atas, kanan-atas, kanan-bawah, kiri-bawah, dalam piksel
  /// FOTO ASLI (bukan citra kerja) dengan konvensi tepi-piksel (piksel i
  /// menutup [i, i+1)) — langsung pakai untuk homografi ke `ratakanHalaman`.
  ///
  /// "Kiri-atas" berarti sudut yang paling dekat dengan arah itu di foto
  /// (putaran terkecil). Halaman yang difoto terputar 90°/180° tetap
  /// bertanda begitu; lihat `putaranKuadran` pada hasil registrasi.
  final List<TitikHalaman> sudut;
  final DiagnostikRegistrasi diagnostik;
}

final class DeteksiHalamanGagal extends HasilDeteksiHalaman {
  const DeteksiHalamanGagal(this.alasan, this.detail, [this.diagnostik]);

  final AlasanGagalRegistrasi alasan;

  /// Angka pemicu, untuk log (bukan untuk teknisi).
  final String detail;
  final DiagnostikRegistrasi? diagnostik;

  @override
  String toString() => 'DeteksiHalamanGagal(${alasan.name}: $detail)';
}
