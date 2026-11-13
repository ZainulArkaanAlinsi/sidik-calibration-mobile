import '../../models/worksheet_template.dart' show AturanSelAsli;

/// Aturan format SATU sel angka, diambil dari templat server — gerbang yang
/// menentukan apakah bacaan mesin boleh jadi usulan.
///
/// Rig uji (12 Nov 2026, data SINTETIS) menunjukkan tanpa gerbang ini tidak ada
/// mesin yang layak: PP-OCR mengisi 11–24% sel kosong biasa karena garis tabel
/// terbaca `.` atau `-`. Dengan gerbang, isi-palsu pada sel kosong biasa 0,0–0,3%.
///
/// Aturannya sama persis dengan `lolos_format` di rig (`sidik_ocr/alfabet.py`):
/// satu sampai delapan digit bagian bulat, pemisah `.` atau `,` bila ada
/// desimal, tepat [desimal] digit sesudahnya, tanda minus hanya bila
/// [bolehNegatif], total paling banyak [maksKarakter] karakter.
class AturanFormatSel {
  AturanFormatSel({
    required this.desimal,
    required this.bolehNegatif,
    this.nolBulat = false,
  }) : assert(desimal >= 0 && desimal <= desimalMaks),
       _pola = RegExp(
         desimal == 0
             ? '^${bolehNegatif ? '-?' : ''}\\d{1,8}\$'
             : '^${bolehNegatif ? '-?' : ''}\\d{1,8}[.,]\\d{$desimal}\$',
       );

  /// Jumlah angka di belakang pemisah; 0 = bilangan bulat tanpa pemisah.
  final int desimal;

  /// Sel ini boleh bertanda minus.
  final bool bolehNegatif;

  /// Tulisan "0" polos (tanpa pemisah dan tanpa desimal) juga lolos. Hanya bila
  /// templat server MENYATAKANNYA per sel lewat `boleh_bulat` (kasus: baris M0
  /// timbangan Piston, teknisi menulis "0", bukan "0.0000"). Field itu BELUM
  /// ada di server (usulan), jadi sekarang selalu `false`. Dulu diturunkan dari
  /// `nominal == 0`, dicabut: server mengirim `nominal = 0` untuk SEMUA baris
  /// grid Enclosure/Autoklaf, sehingga "0" polos lolos di sel suhu. Tanpa
  /// penanda, "0" di sel berdesimal ditahan (`perluCek`), arah yang aman. Hanya
  /// string persis "0" yang diloloskan: nilainya sama dengan 0,0000.
  final bool nolBulat;

  final RegExp _pola;

  /// Batas yang DIUKUR rig: nilai 1–8 karakter. Lebih panjang belum pernah
  /// dievaluasi, jadi ditolak (teknisi mengetik sendiri).
  static const maksKarakter = 8;

  /// Jumlah desimal terbanyak yang ada di set uji rig (format `d4`). Sel
  /// dengan desimal lebih banyak TIDAK dibaca mesin ini: tidak ada buktinya.
  static const desimalMaks = 4;

  /// Aturan dari `aturan` sel di templat server, atau `null` bila templat
  /// belum menyebut format sel ini — jangan ditebak.
  ///
  /// `null` terjadi bila: sel tanpa `aturan` desimal (jam, suhu), `desimal`
  /// kosong (server tidak tahu resolusi alat), atau desimal di luar jangkauan
  /// yang diukur. Rig menunjukkan gerbang umum (tanpa jumlah desimal) jauh lebih
  /// longgar: sisa tulisan tetangga lolos ±19% lawan ±3% dengan desimal
  /// diketahui. Maka tanpa desimal mesin ini tidak dipakai.
  ///
  /// [bolehNegatif]: server mengirim `izinkan_minus` (kini selalu `false` untuk
  /// pembacaan alat) dan `min`. Minus dianggap boleh bila server mengizinkannya
  /// ATAU rentang `min` memang menjangkau bilangan negatif.
  static AturanFormatSel? dari(AturanSelAsli? aturan) {
    final d = aturan?.desimal;
    if (aturan == null || d == null || d < 0 || d > desimalMaks) return null;

    return AturanFormatSel(
      desimal: d,
      bolehNegatif: aturan.izinkanMinus == true || (aturan.min ?? 0) < 0,
      nolBulat: aturan.bolehBulat == true,
    );
  }

  /// Teks hasil mesin cocok dengan aturan sel ini?
  bool lolos(String teks) =>
      teks.length <= maksKarakter &&
      (_pola.hasMatch(teks) || (nolBulat && teks == '0'));
}
