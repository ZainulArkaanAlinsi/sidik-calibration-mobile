import 'jenis_lembar.dart';

/// KEPUTUSAN alur foto beranda sesudah foto dikenali (`identifikasiLembar`):
/// buka lembar sendiri, minta SATU ketukan, atau jujur bilang tidak yakin.
/// Murni fungsi (tanpa kamera, jaringan, atau state), jadi seluruh aturannya
/// bisa diuji satu per satu.
///
/// Keputusan pemilik 18 Nov 2026 (membalik aturan 12 Nov "pilih manual selalu
/// tampil" HANYA untuk kode formulir yang unik): foto -> jenis dikenali
/// otomatis -> lembar yang tepat terbuka -> terisi sebagai saran. Yang
/// dijaga tetap:
///
///  - Auto-buka hanya bila SEMUA ini terpenuhi: kode formulir terbaca BERSIH
///    dan cocok persis tepat satu jenis (`AlasanPetunjuk.praPilihKode`), tidak
///    ada kandidat lain di peringkat, skor gabungan >= [ambangAutoBuka], dan
///    jenis itu memang boleh dipindai (`siap_pindai` / mode uji, bukan
///    `perlu_konfirmasi_lab`, bukan Temperatur Indikator). Bacaan samar, judul
///    saja, dan kode yang dipakai beberapa jenis TIDAK pernah membuka lembar
///    sendiri.
///  - Kandidat lebih dari satu = [PilihSatu]: teknisi mengetuk SATU kali.
///    Tidak pernah dipilihkan.
///  - Tidak yakin / tidak terbaca = [TakDikenali]: pesan jujur, tanpa tebakan.
///  - Ambang identifikasi BELUM dikalibrasi dengan foto nyata (target 26 Nov
///    2026), sehingga [ambangAutoBuka] sengaja di atas ambang pilih-awal mesin
///    (0,70) dan banner "Ganti jenis" di lembar wajib ada. Mesin identifikasi
///    TIDAK diubah di sini; ini hanya lapisan keputusan di atasnya.
///  - Hasil apa pun tetap hanya usulan: yang terisi sesudahnya berwarna kuning
///    dan wajib diperiksa teknisi (lihat `pindai_formulir_asli_flow.dart`).

/// Skor gabungan minimal untuk membuka lembar tanpa bertanya. Kode bersih
/// tepat = 0,92 (`identifikasi_lembar.dart`), 0,98 bila judul ikut sepakat; ke
/// bawah 0,90 hanya terjadi bila revisi tercetak beda dari yang dipegang
/// server (denda 0,20 -> 0,72/0,78), dan itu justru alasan untuk bertanya.
const ambangAutoBuka = 0.90;

/// Paling banyak kandidat per ketukan (arahan pemilik: tiga). Yang lain tetap
/// terjangkau lewat "Jenis lain..." di lembar yang sama. Kode bersama 0504
/// dipakai lima jenis, jadi dua di antaranya ada di "Jenis lain...".
const maksKandidatRingkas = 3;

/// Mengapa kandidatnya tampil (menentukan kalimat di atas daftar).
enum AlasanPilih {
  /// Satu kode bersih dipakai beberapa jenis.
  kodeBersama,

  /// Satu kandidat atau lebih dari bacaan samar yang belum cukup untuk dibuka
  /// sendiri.
  samar,

  /// Kode menunjuk satu jenis, judul jenis lain.
  bertentangan,

  /// Bukti satu lapis yang lemah (bacaan kode samar yang belum cukup kuat).
  lemah,

  /// Hanya judul tercetak yang terbaca (judul bukan pengenal).
  judulSaja,

  /// Kode bersih cocok satu jenis tetapi skornya di bawah [ambangAutoBuka]
  /// (mis. revisi tercetak beda).
  perluKonfirmasi,
}

/// Mengapa tidak ada yang bisa dibuka atau ditawarkan.
enum AlasanTakDikenali {
  /// Tidak ada bukti sama sekali di teks yang terbaca.
  tidakTerbaca,

  /// Kode 05xx terbaca bersih tetapi tidak ada di daftar server.
  kodeTakDikenal,

  /// Jenisnya dikenali, tetapi belum boleh dipindai (belum siap, menunggu
  /// konfirmasi lab, atau Temperatur Indikator).
  belumBisaDipindai,
}

sealed class KeputusanPindai {
  const KeputusanPindai();
}

/// Buka lembar [formulir] tanpa layar pilihan.
class BukaOtomatis extends KeputusanPindai {
  const BukaOtomatis(this.formulir, this.skor);

  final FormulirDikenal formulir;
  final double skor;
}

/// Tampilkan [kandidat] (urut skor turun); teknisi mengetuk satu.
class PilihSatu extends KeputusanPindai {
  const PilihSatu(this.kandidat, this.alasan);

  final List<FormulirDikenal> kandidat;
  final AlasanPilih alasan;
}

/// Tidak ada yang boleh dibuka atau ditawarkan. [kode] = kode formulir yang
/// terbaca (bila ada), [jenis] = nama jenis yang dikenali tetapi belum boleh.
class TakDikenali extends KeputusanPindai {
  const TakDikenali(this.alasan, {this.kode, this.jenis});

  final AlasanTakDikenali alasan;
  final String? kode;
  final String? jenis;
}

/// Menimbang [hasil] pengenal menjadi [KeputusanPindai].
///
/// [boleh] = `kesiapan.bolehDipindai`: satu-satunya gerbang kesiapan, dipakai
/// APA ADANYA (saklar `siap_pindai`, mode uji, `perlu_konfirmasi_lab`, dan
/// daftar tanpa Temperatur Indikator semuanya sudah terwakili di sana).
KeputusanPindai putuskanPindaiLembar(
  HasilJenisLembar? hasil, {
  required bool Function(String templateId) boleh,
  double ambang = ambangAutoBuka,
}) {
  if (hasil == null) {
    return const TakDikenali(AlasanTakDikenali.tidakTerbaca);
  }
  if (hasil.alasan == AlasanPetunjuk.kodeTakDikenal) {
    return TakDikenali(
      AlasanTakDikenali.kodeTakDikenal,
      kode: hasil.kodeFormulir,
    );
  }

  final peringkat = hasil.peringkat;
  if (peringkat.isEmpty) {
    return TakDikenali(
      AlasanTakDikenali.tidakTerbaca,
      kode: hasil.kodeFormulir,
    );
  }

  final dipilihAwal = hasil.praPilihTemplateId;
  final tunggal = peringkat.length == 1 ? peringkat.single : null;

  // ---- 1. buka sendiri: kode bersih, unik, skor tinggi ----------------------
  if (hasil.alasan == AlasanPetunjuk.praPilihKode &&
      hasil.sumber == SumberJenisLembar.kodeFormulir &&
      tunggal != null &&
      dipilihAwal == tunggal.formulir.templateId &&
      tunggal.skor >= ambang) {
    if (!boleh(tunggal.formulir.templateId)) {
      return TakDikenali(
        AlasanTakDikenali.belumBisaDipindai,
        kode: hasil.kodeFormulir,
        jenis: namaPendekJudul(tunggal.formulir.judul),
      );
    }

    return BukaOtomatis(tunggal.formulir, tunggal.skor);
  }

  // ---- 2. satu ketukan: hanya yang boleh dipindai ---------------------------
  final dapat = <KandidatJenis>[
    for (final k in peringkat)
      if (boleh(k.formulir.templateId)) k,
  ];
  if (dapat.isEmpty) {
    return TakDikenali(
      AlasanTakDikenali.belumBisaDipindai,
      kode: hasil.kodeFormulir,
      jenis: namaPendekJudul(peringkat.first.formulir.judul),
    );
  }

  return PilihSatu([
    for (final k in dapat.take(maksKandidatRingkas)) k.formulir,
  ], _alasanPilih(hasil));
}

AlasanPilih _alasanPilih(HasilJenisLembar h) => switch (h.alasan) {
  AlasanPetunjuk.kodeBersama => AlasanPilih.kodeBersama,
  AlasanPetunjuk.bertentangan => AlasanPilih.bertentangan,
  AlasanPetunjuk.lemah => AlasanPilih.lemah,
  AlasanPetunjuk.judulSaja => AlasanPilih.judulSaja,
  AlasanPetunjuk.praPilihKode => AlasanPilih.perluKonfirmasi,
  AlasanPetunjuk.praPilihKodeSamar ||
  AlasanPetunjuk.praPilihBerlapis ||
  AlasanPetunjuk.beberapaKandidat => AlasanPilih.samar,
  // Dicegat di atas; tidak pernah sampai sini.
  AlasanPetunjuk.kodeTakDikenal || null => AlasanPilih.lemah,
};
