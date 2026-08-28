import '../models/skema_dokumen.dart';

/// Arti satu kolom dokumen — **ditetapkan teknisi, bukan ditebak aplikasi**.
///
/// Ini titik paling rawan di seluruh jalur generik. Godaannya menebak dari
/// kepala kolomnya: yang berbunyi `Standard`/`Set Point` jadi nilai acuan, yang
/// berbunyi `Pembacaan`/`Reading` jadi pembacaan. Begitu itu ditulis, jalur
/// generiknya mati — yang tersisa daftar ejaan kepala kolom, persis bentuk yang
/// dihindari sejak awal, cuma pindah tempat.
///
/// Dan salahnya nggak berhenti di kerapian. Menebak terbalik antara acuan dan
/// pembacaan menghasilkan sertifikat dengan koreksi yang tandanya kebalik —
/// angkanya wajar, tabelnya wajar, dan yang ketahuan cuma kalau ada yang
/// membandingkannya ke kertas aslinya.
///
/// Jadi pembagian kerjanya tegas: **dokumen memberi struktur, teknisi memberi
/// arti.** Berkas ini nggak boleh tahu satu pun nama alat, nama kolom, maupun
/// ejaan kepala kolom.
enum PeranKolom {
  /// Kolomnya ada di kertas tapi bukan bagian titik ukur — nomor urut,
  /// keterangan, kolom paraf.
  abaikan,

  /// Nilai acuan yang dituju (`titikUkur` di [MeasurementPoint]).
  nilaiAcuan,

  /// Satu kali pembacaan alat. Beberapa kolom boleh berperan ini — itulah
  /// pengulangan yang jadi bahan sebaran Type A.
  pembacaan,
}

/// Satu titik ukur hasil pemetaan, **masih berupa teks**.
///
/// Sengaja belum diubah ke `double`. Yang menerimanya form yang isinya
/// `TextEditingController`, dan mengubahnya di sini berarti sel yang nggak
/// keparse (`4,O1` dengan huruf O) hilang tanpa jejak sebelum teknisi sempat
/// melihatnya. Biar dia lihat apa yang beneran tertulis di kertasnya, lalu
/// membetulkan — parsing & penolakannya sudah ada di form, di satu tempat.
typedef TitikDariDokumen = ({String nilaiAcuan, List<String> pembacaan});

/// Kenapa penetapan kolomnya belum bisa dipakai.
///
/// Dipisah biar layarnya bisa bilang APA yang kurang. "Penetapan tidak valid"
/// tanpa sebab bikin teknisi nebak-nebak kolom mana yang salah.
enum PetaBelumSah {
  /// Belum ada kolom yang ditunjuk sebagai nilai acuan.
  tanpaNilaiAcuan,

  /// Lebih dari satu kolom ditunjuk sebagai nilai acuan. Satu titik ukur punya
  /// SATU nilai yang dituju; dua kolom acuan artinya bentuk kertasnya beda dari
  /// yang bisa dipetakan di sini.
  nilaiAcuanLebihDariSatu,

  /// Kolom pembacaannya kurang dari [PetaKolomTitik.minPembacaan].
  pembacaanKurang,
}

/// Hasil pemetaan satu tabel dokumen jadi titik ukur.
typedef HasilPetaKolom = ({
  List<TitikDariDokumen> titik,

  /// Baris yang dilewat karena sel nilai acuannya kosong.
  ///
  /// Dilaporkan, bukan dibuang diam-diam: lembar yang separuh terisi itu hal
  /// biasa, tapi teknisi berhak tahu berapa baris kertasnya yang nggak ikut —
  /// kalau angkanya mengejutkan dia, yang salah pembacaannya, bukan kertasnya.
  int barisDilewat,
});

/// Ubah satu tabel yang dibaca dari dokumen jadi titik ukur, mengikuti peran
/// kolom yang **ditetapkan teknisi**.
///
/// ## Bentuk yang didukung, dan yang tidak
///
/// Satu BARIS = satu titik ukur; kolom pembacaan = pengulangannya. Itu bentuk
/// yang dipakai lembar kerja di proyek ini (titik ukur × Repeat).
///
/// Yang TIDAK didukung dan sengaja tidak ditebak: kertas yang satu barisnya
/// satu pembacaan dan set point-nya berulang ke bawah. Bentuk itu butuh
/// pengelompokan baris, dan menebaknya salah menghasilkan titik ukur yang
/// jumlah pengulangannya karangan. Kalau suatu saat perlu, dia masuk sebagai
/// pilihan bentuk yang ditunjuk teknisi juga — bukan sebagai tebakan.
class PetaKolomTitik {
  const PetaKolomTitik();

  /// Pembacaan paling sedikit per titik supaya ada sebaran yang bisa dihitung.
  ///
  /// Dua, sama dengan yang sudah dituntut form kalibrasi: Type A itu standar
  /// deviasi antar-pengulangan, dan satu angka nggak punya sebaran. Angkanya
  /// diikat ke sana biar penetapan yang lolos di sini nggak ditolak lagi di
  /// ujung jalan.
  static const minPembacaan = 2;

  /// `null` = penetapannya sah.
  PetaBelumSah? periksa(List<PeranKolom> peran) {
    final acuan = peran.where((p) => p == PeranKolom.nilaiAcuan).length;

    if (acuan == 0) return PetaBelumSah.tanpaNilaiAcuan;
    if (acuan > 1) return PetaBelumSah.nilaiAcuanLebihDariSatu;

    final bacaan = peran.where((p) => p == PeranKolom.pembacaan).length;
    if (bacaan < minPembacaan) return PetaBelumSah.pembacaanKurang;

    return null;
  }

  /// Petakan [tabel] memakai [peran]. Panggil [periksa] dulu — penetapan yang
  /// belum sah memulangkan titik kosong, bukan menebak yang kurang.
  HasilPetaKolom petakan({
    required TabelSkema tabel,
    required List<PeranKolom> peran,
  }) {
    if (periksa(peran) != null) {
      return (titik: const <TitikDariDokumen>[], barisDilewat: 0);
    }

    final iAcuan = peran.indexOf(PeranKolom.nilaiAcuan);
    final iBacaan = [
      for (var i = 0; i < peran.length; i++)
        if (peran[i] == PeranKolom.pembacaan) i,
    ];

    final titik = <TitikDariDokumen>[];
    var dilewat = 0;

    for (final baris in tabel.baris) {
      // Baris yang lebih pendek dari daftar peran bukan hal yang mustahil
      // (bentuk tabel datang dari foto, bukan dari skema tetap), dan
      // mengindeksnya buta bikin seluruh pembacaan meledak di satu sel bolong.
      String sel(int i) => i < baris.length ? baris[i].trim() : '';

      final acuan = sel(iAcuan);

      // Baris tanpa nilai acuan bukan titik ukur. Dipaksa masuk, dia jadi titik
      // bernilai kosong yang ditolak form di ujung jalan — dengan pesan yang
      // nunjuk ke isian, bukan ke barisnya di kertas.
      if (acuan.isEmpty) {
        dilewat++;
        continue;
      }

      titik.add((
        nilaiAcuan: acuan,
        // Sel pembacaan yang kosong TETAP dibawa sebagai teks kosong, nggak
        // dibuang: posisinya berarti. Dibuang, pengulangan ke-3 yang bolong
        // bikin pembacaan ke-4 naik jadi ke-3, dan angkanya mendarat di kolom
        // yang salah tanpa ada yang kelihatan hilang.
        pembacaan: [for (final i in iBacaan) sel(i)],
      ));
    }

    return (titik: titik, barisDilewat: dilewat);
  }
}
