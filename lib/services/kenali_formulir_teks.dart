import '../models/worksheet_template.dart';
import 'identifikasi_lembar.dart';
import 'jenis_lembar.dart';
import 'pembaca_halaman.dart';
import 'registrasi_jangkar_teks.dart' show normalisasiKodeDokumen;

/// KENALI FORMULIR DARI TULISAN CETAK: apakah foto ini lembar yang benar untuk
/// [WorksheetTemplate] yang sudah dipilih? Murni fungsi teks (tanpa kamera,
/// jaringan, atau state), jadi seluruh aturannya bisa diuji satu per satu.
///
/// Dulu pintunya cuma satu: kode formulir tercetak (`SIDIK-FM-CAL-0509`) harus
/// terbaca PERSIS, kalau tidak pindai berhenti. Kode di kaki lembar sering
/// terpotong tepi foto atau salah baca, dan kode/revisi formulir terus berganti,
/// jadi lembar yang judulnya jelas pun ditolak. Sekarang bukti utamanya JUDUL /
/// nama alat tercetak ("Calibration Worksheet - UV/VIS Spectrophotometer");
/// kode formulir menjadi bukti tambahan yang menguatkan atau membantah.
///
/// Aturan (urutan bukti, bukan skor angka; ambang judul = toleransi jarak edit
/// `cocokkanJudulCetak`, BELUM DIKALIBRASI pada keluaran ML Kit nyata):
///
///  - Kode terbaca bersih dan sama dengan kode template: cocok. Kecuali judul
///    tercetak jelas milik formulir LAIN yang kodenya beda: bertentangan, ditolak.
///  - Kode terbaca bersih tetapi kode formulir LAIN: ditolak, apa pun judulnya.
///    Kode yang cuma terpotong (`SIDIK-FM-CAL-0522` untuk `0522.A`) bukan kode lain.
///  - Kode tidak terbaca: judul menentukan. Judul cocok dengan template ini dan
///    tidak ada formulir lain (kode beda) yang sama dekatnya: cocok. Beberapa
///    formulir beda kode dengan judul sama (micrometer 0522.A-D): ambigu, tidak
///    ditebak. Judul cocok formulir lain: ditolak. Judul tidak terbaca: tidak
///    terbaca.
///  - Formulir yang kodenya SAMA dengan template ini (0504: oven, furnace, bath,
///    ...) satu kertas cetak yang sama; judul mereka tidak dibedakan.
///  - Batas: yang dicocokkan adalah `judul` dari server (ekor sesudah "Worksheet
///    -"). Formulir yang judul servernya beda dari yang tercetak (oven:
///    "Enclosure (Oven)" vs "Oven/Furnace/Chiller/Water Bath") tidak bisa dikenali
///    dari judul; jalur kodenya tetap seperti dulu.
///
/// Revisi tidak diperiksa di sini: revisi beda atau tidak terbaca tidak pernah
/// menolak sendirian (lihat `StatusRevisiAsli`).
enum KeputusanKenali {
  /// Lembar ini benar: lanjut meratakan dan membaca sel.
  cocok,

  /// Kertas formulir lain (kode lain, atau judul milik formulir lain).
  formulirLain,

  /// Beberapa formulir (kode beda) sama-sama cocok dengan judulnya dan kodenya
  /// tidak terbaca: jangan menebak varian.
  ambigu,

  /// Tidak ada bukti yang cukup (judul dan kode sama-sama tidak terbaca).
  tidakTerbaca,
}

/// Dasar keputusan [KeputusanKenali.cocok].
enum DasarKenali { kode, judul, kodeDanJudul }

class HasilKenaliTeks {
  const HasilKenaliTeks(
    this.keputusan, {
    this.dasar,
    this.kodeTerbaca,
    this.terbaca,
    this.kandidat = const [],
  });

  final KeputusanKenali keputusan;
  final DasarKenali? dasar;

  /// Teks mentah kode formulir yang cocok dengan template ini (bila terbaca).
  final String? kodeTerbaca;

  /// [KeputusanKenali.formulirLain]: kode atau judul yang terbaca dan bukan
  /// milik template ini.
  final String? terbaca;

  /// [KeputusanKenali.ambigu]: kode dokumen semua varian yang sama cocok
  /// (termasuk milik template ini), terurut.
  final List<String> kandidat;
}

HasilKenaliTeks kenaliFormulirDariTeks({
  required List<TeksTerbaca> terbaca,
  required WorksheetTemplate template,
  required ({String? cocok, String? lain}) kode,
  List<FormulirDikenal> dikenal = const [],
}) {
  final kodeTarget = normalisasiKodeDokumen(template.kodeDokumen);
  final kodeCocok = kode.cocok;

  // Kode yang terbaca tetapi hanya awalan kode template (ekor/varian
  // terpotong) belum kode formulir lain.
  final lain = kode.lain;
  final kodeLain =
      lain != null && !kodeTarget.startsWith(normalisasiKodeDokumen(lain))
      ? lain
      : null;

  final baris = teksHalaman(terbaca).split('\n');

  final saingan = [
    for (final f in dikenal)
      if (f.templateId != template.templateId) f,
  ];
  bool serumpun(FormulirDikenal f) =>
      normalisasiKodeDokumen(f.kodeDokumen) == kodeTarget;

  final hit = cocokkanJudulCetak(baris, [
    (id: template.templateId, nama: namaPendekJudul(template.judul)),
    for (final f in saingan) (id: f.templateId, nama: namaPendekJudul(f.judul)),
  ]);

  final hitIni = hit.any((h) => h.id == template.templateId);
  final saingHit = {for (final f in saingan) f.templateId: f};
  final hitSerumpun = [
    for (final h in hit)
      if (h.id != template.templateId && serumpun(saingHit[h.id]!)) h,
  ];
  final hitBersaing = [
    for (final h in hit)
      if (h.id != template.templateId && !serumpun(saingHit[h.id]!)) h,
  ];

  // ---- 1. kode formulir template ini terbaca bersih -------------------------
  if (kodeCocok != null) {
    if (!hitIni && hitSerumpun.isEmpty && hitBersaing.isNotEmpty) {
      return HasilKenaliTeks(
        KeputusanKenali.formulirLain,
        kodeTerbaca: kodeCocok,
        terbaca: hitBersaing.first.terbaca,
      );
    }

    return HasilKenaliTeks(
      KeputusanKenali.cocok,
      dasar: hitIni || hitSerumpun.isNotEmpty
          ? DasarKenali.kodeDanJudul
          : DasarKenali.kode,
      kodeTerbaca: kodeCocok,
    );
  }

  // ---- 2. kode formulir LAIN terbaca bersih ---------------------------------
  if (kodeLain != null) {
    return HasilKenaliTeks(KeputusanKenali.formulirLain, terbaca: kodeLain);
  }

  // ---- 3. kode tidak terbaca: judul yang menentukan -------------------------
  if (hitIni) {
    if (hitBersaing.isNotEmpty) {
      return HasilKenaliTeks(
        KeputusanKenali.ambigu,
        kandidat: [
          kodeTarget,
          ...{
            for (final h in hitBersaing)
              normalisasiKodeDokumen(saingHit[h.id]!.kodeDokumen),
          },
        ]..sort(),
      );
    }

    return const HasilKenaliTeks(
      KeputusanKenali.cocok,
      dasar: DasarKenali.judul,
    );
  }

  if (hitBersaing.isNotEmpty) {
    return HasilKenaliTeks(
      KeputusanKenali.formulirLain,
      terbaca: hitBersaing.first.terbaca,
    );
  }

  if (hitSerumpun.isNotEmpty) {
    return const HasilKenaliTeks(
      KeputusanKenali.cocok,
      dasar: DasarKenali.judul,
    );
  }

  return const HasilKenaliTeks(KeputusanKenali.tidakTerbaca);
}
