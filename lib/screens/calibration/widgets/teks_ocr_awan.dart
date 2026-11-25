import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/usulan_ocr_awan.dart';
import '../../../services/saran_ocr_awan.dart';

/// Teks layar usulan OCR awan. Semua kalimat datang dari `lib/l10n/*.arb`
/// (kunci berawalan `ocrAwan`); kelas ini hanya memilih kalimat yang tepat
/// untuk sebuah kode atau sebab, jadi tampilan tidak membawa string sendiri.
///
/// Dibuat per-`build` lewat [TeksOcrAwan.dari]: murah (hanya memegang
/// [AppLocalizations]) dan ikut berganti bahasa.
class TeksOcrAwan {
  const TeksOcrAwan(this._l);

  factory TeksOcrAwan.dari(BuildContext context) =>
      TeksOcrAwan(AppLocalizations.of(context));

  final AppLocalizations _l;

  String get judul => _l.ocrAwanJudul;
  String get penjelasan => _l.ocrAwanPenjelasan;

  String sisa(int menunggu) => _l.ocrAwanSisa(menunggu);

  String get sebagian => _l.ocrAwanSebagian;

  String dilewati(int jumlah) => _l.ocrAwanDilewati(jumlah);

  String get labelAwan => _l.ocrAwanLabelAwan;
  String get labelNormal => _l.ocrAwanLabelNormal;
  String get labelUsulan => _l.ocrAwanLabelUsulan;
  String get duaBentukBeda => _l.ocrAwanDuaBentukBeda;

  String get pakai => _l.ocrAwanPakai;
  String get ubah => _l.ocrAwanUbah;
  String get tolak => _l.ocrAwanTolak;
  String get batalkan => _l.ocrAwanBatalkan;
  String get simpan => _l.ocrAwanSimpan;
  String get batal => _l.ocrAwanBatal;

  String get perluDicek => _l.ocrAwanPerluDicek;
  String get dipakai => _l.ocrAwanDipakai;
  String get diubah => _l.ocrAwanDiubah;
  String get ditolak => _l.ocrAwanDitolak;

  String get labelIsian => _l.ocrAwanLabelIsian;
  String get galatIsian => _l.ocrAwanGalatIsian;

  String nilaiPegangan(String teks) => _l.ocrAwanNilaiPegangan(teks);

  String get judulTanpaUsulan => _l.ocrAwanJudulTanpaUsulan;

  String tanpaUsulan(AlasanTanpaUsulan sebab) => switch (sebab) {
    AlasanTanpaUsulan.merah => _l.ocrAwanTanpaMerah,
    AlasanTanpaUsulan.kosong => _l.ocrAwanTanpaKosong,
    AlasanTanpaUsulan.bentukTidakDikenal => _l.ocrAwanTanpaBentukTakDikenal,
    AlasanTanpaUsulan.selIdentitas => _l.ocrAwanTanpaIdentitas,
  };

  /// Alasan sel dalam kalimat manusia. Daftar dari
  /// `docs/perintah-frontend-ocr-lembar-kerja.md` (aturan layar review).
  /// Kode yang tidak dikenal TIDAK ditampilkan mentah dan tidak ditebak.
  String alasan(String kode) => switch (kode) {
    'teks_meluber_dari_sel' => _l.ocrAwanAlasanTeksMeluber,
    'di_luar_rentang' => _l.ocrAwanAlasanDiLuarRentang,
    'magnitudo_meleset' => _l.ocrAwanAlasanMagnitudoMeleset,
    'ada_koreksi_karakter' => _l.ocrAwanAlasanAdaKoreksiKarakter,
    'desimal_kebanyakan' => _l.ocrAwanAlasanDesimalKebanyakan,
    'bukan_kelipatan_resolusi' => _l.ocrAwanAlasanBukanKelipatanResolusi,
    'jauh_dari_repeat_lain' => _l.ocrAwanAlasanJauhDariRepeatLain,
    'sebar_repeat_tidak_diuji' => _l.ocrAwanAlasanSebarRepeatTidakDiuji,
    'terlalu_banyak_substitusi' => _l.ocrAwanAlasanTerlaluBanyakSubstitusi,
    'karakter_di_luar_whitelist' => _l.ocrAwanAlasanKarakterDiLuarWhitelist,
    'spasi_di_dalam_angka' => _l.ocrAwanAlasanSpasiDiDalamAngka,
    'pemisah_ribuan_tidak_didukung' => _l.ocrAwanAlasanPemisahRibuan,
    'bentuk_angka_tidak_wajar' => _l.ocrAwanAlasanBentukAngkaTidakWajar,
    'digit_kebanyakan' => _l.ocrAwanAlasanDigitKebanyakan,
    'pemisah_desimal_tidak_wajar' => _l.ocrAwanAlasanPemisahDesimalTidakWajar,
    'desimal_ambigu' => _l.ocrAwanAlasanDesimalAmbigu,
    'minus_di_tengah' => _l.ocrAwanAlasanMinusDiTengah,
    'minus_tidak_diizinkan' => _l.ocrAwanAlasanMinusTidakDiizinkan,
    _ => _l.ocrAwanAlasanTakDikenal,
  };

  // ---- Layar review foto ----

  String get minta => _l.ocrAwanMinta;
  String meminta(int selesai, int total) => _l.ocrAwanMeminta(selesai, total);
  String get keterangan => _l.ocrAwanKeterangan;

  String tertahanDiHp(int jumlah) => _l.ocrAwanTertahanDiHp(jumlah);
  String belumTerkirim(int jumlah) => _l.ocrAwanBelumTerkirim(jumlah);

  /// Kalimat fallback untuk [sebab]. `null` = tidak ada yang perlu ditampilkan
  /// (sakelar klien mati: tombolnya sendiri tidak ada).
  ///
  /// Semuanya berakhir sama: lanjut dengan pembaca di HP atau isi sendiri.
  String? gagal(SebabGagalSaranAwan sebab) => switch (sebab) {
    SebabGagalSaranAwan.dimatikan => null,
    SebabGagalSaranAwan.tidakAdaSel => _l.ocrAwanGagalTidakAdaSel,
    SebabGagalSaranAwan.fiturMati => _l.ocrAwanGagalFiturMati,
    SebabGagalSaranAwan.awanBelumSiap => _l.ocrAwanGagalAwanBelumSiap,
    SebabGagalSaranAwan.jatahHabis => _l.ocrAwanGagalJatahHabis,
    SebabGagalSaranAwan.terlaluSering => _l.ocrAwanGagalTerlaluSering,
    SebabGagalSaranAwan.awanGagal => _l.ocrAwanGagalAwanGagal,
    SebabGagalSaranAwan.ditolakServer => _l.ocrAwanGagalDitolakServer,
    SebabGagalSaranAwan.akses => _l.ocrAwanGagalAkses,
    SebabGagalSaranAwan.jaringan => _l.ocrAwanGagalJaringan,
    SebabGagalSaranAwan.lainnya => _l.ocrAwanGagalLainnya,
  };
}
