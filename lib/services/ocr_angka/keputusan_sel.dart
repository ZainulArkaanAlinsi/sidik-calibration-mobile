import 'aturan_format_sel.dart';
import 'dekoder_ctc.dart';

/// Status satu sel angka sesudah mesin membaca.
enum StatusSelAngka {
  /// Tidak ada tulisan (pagar tinta, atau model tidak mengeluarkan karakter).
  /// Sel TETAP KOSONG dan tidak ikut review.
  kosong,

  /// Ada bacaan, tapi DITAHAN: skor `jalur` di bawah ambang atau format tidak
  /// cocok dengan aturan sel. Kotak tetap kosong, teknisi mengetik sendiri;
  /// bacaan mentah hanya untuk pratinjau.
  ///
  /// Juga dipakai untuk sel yang BERTINTA (lolos pagar tinta) tetapi tidak
  /// menghasilkan bacaan sama sekali: model tidak mengeluarkan karakter
  /// ([AlasanSelAngka.tintaTebalTakTerbaca], mis. CORET/TIMPA/STRIP) atau
  /// pemotong tidak yakin ([AlasanSelAngka.pemotongTakYakin]), atau tinta
  /// terlalu pudar untuk pagar ([AlasanSelAngka.tintaPudar]). [HasilSelAngka.bacaanMentah]
  /// kosong; sel ini TIDAK boleh dianggap kosong (lihat
  /// [HasilSelAngka.perluCekTanpaBacaan]).
  perluCek,

  /// Bacaan lolos ambang dan gerbang format: dijadikan USULAN (kuning). Tetap
  /// WAJIB diperiksa teknisi satu per satu — tulisan tangan tidak pernah hijau,
  /// dan skor mentah tidak terkalibrasi.
  usulanKeyakinanTinggi,
}

/// Kenapa bacaan ditahan atau sel dianggap kosong.
enum AlasanSelAngka {
  tintaKosong,
  teksKosong,
  jalurRendah,
  formatTidakCocok,

  /// Keluaran model NaN/tak hingga: bukan bacaan. Pembaca jatuh ke ML Kit untuk
  /// sel ini; tidak pernah jadi usulan.
  keluaranTakValid,

  /// Crop terlalu besar atau terlalu pipih untuk sel angka, atau lebih lebar
  /// dari kanvas model berlebar tetap (TFLite: hasil resize > 320 piksel). Model
  /// tidak dijalankan. `PembacaSelOnnx` mengalihkan sel ini ke ML Kit (ada
  /// tinta, tidak boleh hilang diam-diam dari review); hanya layar diagnostik
  /// yang melihatnya sebagai `kosong`.
  ukuranTakWajar,

  /// Sel lolos pagar tinta (ada tulisan) tetapi model tidak mengeluarkan satu
  /// karakter pun. Dulu `kosong` + [teksKosong] sehingga tidak ikut review;
  /// padahal CORET/TIMPA/STRIP bertinta tebal dibaca kosong. Sekarang
  /// [StatusSelAngka.perluCek]: teknisi yang memutuskan.
  tintaTebalTakTerbaca,

  /// `PemotongSel` tidak yakin bagian mana yang milik baris ini (tulisan
  /// menempel di tepi jendela, komponen terlalu tinggi, garis datar di tengah,
  /// kotak terlalu kecil). Model tidak dijalankan; [StatusSelAngka.perluCek].
  pemotongTakYakin,

  /// `PemotongSel` menemukan tulisan (crop ada) tetapi pagar tinta menolaknya
  /// (`gelap` di bawah ambang): tinta pudar, rasio tinta/kertas ±0,70–0,78.
  /// Pemotong memakai ambang tinta 0,78, pagar `gelap` memakai 0,70; tanpa
  /// alasan ini sel itu jadi `kosong` diam-diam. Model tidak dijalankan;
  /// [StatusSelAngka.perluCek] tanpa bacaan, teknisi yang memutuskan.
  tintaPudar,
}

/// Putusan satu sel + bahan pratinjau.
class HasilSelAngka {
  const HasilSelAngka({
    required this.status,
    required this.bacaanMentah,
    required this.jalur,
    this.alasan,
  });

  const HasilSelAngka.kosong(AlasanSelAngka alasan)
    : this(
        status: StatusSelAngka.kosong,
        bacaanMentah: '',
        jalur: 0,
        alasan: alasan,
      );

  final StatusSelAngka status;

  /// Teks mentah mesin, apa adanya — juga bila ditahan. Bukan nilai: jangan
  /// dimasukkan ke kotak isian kecuali [status] = [StatusSelAngka.usulanKeyakinanTinggi].
  final String bacaanMentah;

  /// Skor `jalur` (0 bila kosong). Bukan persen; lihat [HasilDekodeCtc.jalur].
  final double jalur;

  final AlasanSelAngka? alasan;

  /// Teks yang boleh jadi USULAN di kotak isian, atau `null`.
  String? get usulan =>
      status == StatusSelAngka.usulanKeyakinanTinggi ? bacaanMentah : null;

  /// Sel ini harus dicek teknisi walau TIDAK ada bacaan untuk ditampilkan
  /// (tinta tebal tak terbaca, pemotong tak yakin). Pemanggil wajib meneruskan
  /// ini ke review (merah, kotak kosong); sel TIDAK boleh diperlakukan kosong.
  bool get perluCekTanpaBacaan =>
      status == StatusSelAngka.perluCek &&
      (alasan == AlasanSelAngka.tintaTebalTakTerbaca ||
          alasan == AlasanSelAngka.pemotongTakYakin ||
          alasan == AlasanSelAngka.tintaPudar);
}

/// Ambang awal skor `jalur` (B-en, gerbang format). Sintetis: lihat
/// `docs/ocr-angka-onnx.md`. Dihitung ulang dari foto nyata di runtime final.
const ambangJalurAwal = 0.990;

/// Putuskan status sel dari hasil dekode, aturan format sel, dan ambang.
///
/// Urutan pemeriksaan sama dengan `jawab` di rig (`sidik_ocr/ukur.py`): teks
/// kosong → ambang → gerbang format. Semuanya harus lolos untuk jadi usulan.
///
/// [bertinta]: pemanggil sudah memastikan crop LOLOS pagar tinta (ada tulisan).
/// Bila model lalu tidak mengeluarkan karakter, hasilnya BUKAN `kosong`
/// melainkan [StatusSelAngka.perluCek] ([AlasanSelAngka.tintaTebalTakTerbaca]):
/// ada tinta yang tidak terbaca, teknisi yang memutuskan. Bawaan `false` =
/// perilaku lama (dipakai pemanggil yang belum menjalankan pagar tinta).
HasilSelAngka putuskanSelAngka({
  required HasilDekodeCtc dekode,
  required AturanFormatSel aturan,
  double ambang = ambangJalurAwal,
  bool bertinta = false,
}) {
  if (!dekode.valid || !dekode.jalur.isFinite) {
    return const HasilSelAngka(
      status: StatusSelAngka.perluCek,
      bacaanMentah: '',
      jalur: 0,
      alasan: AlasanSelAngka.keluaranTakValid,
    );
  }

  if (dekode.teks.isEmpty) {
    if (bertinta) {
      return const HasilSelAngka(
        status: StatusSelAngka.perluCek,
        bacaanMentah: '',
        jalur: 0,
        alasan: AlasanSelAngka.tintaTebalTakTerbaca,
      );
    }

    return const HasilSelAngka.kosong(AlasanSelAngka.teksKosong);
  }

  AlasanSelAngka? alasan;
  // Ditulis `!(>=)`, bukan `<`: skor atau ambang NaN harus MENAHAN, tidak lolos.
  if (!(dekode.jalur >= ambang)) {
    alasan = AlasanSelAngka.jalurRendah;
  } else if (!aturan.lolos(dekode.teks)) {
    alasan = AlasanSelAngka.formatTidakCocok;
  }

  return HasilSelAngka(
    status: alasan == null
        ? StatusSelAngka.usulanKeyakinanTinggi
        : StatusSelAngka.perluCek,
    bacaanMentah: dekode.teks,
    jalur: dekode.jalur,
    alasan: alasan,
  );
}
