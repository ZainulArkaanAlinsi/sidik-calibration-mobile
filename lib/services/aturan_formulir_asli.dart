import 'dart:math' as math;

import 'vonis_sel_foto.dart' show AmbangKeyakinan;

/// Aturan NALAR formulir asli SIDIK-FM-CAL-0541 Rev.0 (Anak Timbangan) di atas
/// hasil OCR per sel — Dart murni, tanpa ML Kit dan tanpa jaringan.
///
/// ## Satu janji: aturan hanya MENURUNKAN warna
///
/// Hijau → kuning → merah, tidak pernah sebaliknya. Aturan di sini tidak
/// mengarang angka, tidak mengisi sel kosong dengan nol, dan tidak menaikkan
/// keyakinan siapa pun. Yang tidak bisa diperiksa (resolusi tidak dikirim
/// server, nominal belum diketik) DILEWATI — bukan dianggap lolos dengan
/// alasan karangan, dan bukan pula dijadikan merah tanpa dasar.
///
/// ## Bentuk kertas (riset 01-riset-0541, peta `anak_timbangan-0541`)
///
/// 10 blok (massa 1..10). Tiap blok: Standard (`at_s1`) / UUT (`at_t1`) /
/// UUT (`at_t2`) / Standard (`at_s2`) × X1..X3. Alamat sel dari server:
/// `tabelId|barisKe|repeatNo|pembacaan`; `barisKe` = nomor blok. Jumlah
/// pengulangan yang disajikan (40 lawan 120 sel) TIDAK diputuskan di sini —
/// menunggu pertanyaan lab §23.
///
/// ## TODO bernomor
///
/// - TODO(ATURAN-0541-1): deteksi coretan/tulisan ditimpa. Belum ada
///   pendeteksinya; [TandaCoretan] cuma titik sambung. JANGAN menebak dari
///   teks OCR.
/// - TODO(ATURAN-0541-2): MPE per kelas UUT. Butuh kelas UUT (order/alat) dan
///   tabel MPE dari server (`tabel-standar-anak-timbangan.json` `mpe.baris`,
///   tanpa E2). Selama belum ada, dipakai pagar kasar [pagarKasarNominal] dan
///   alasannya ditandai [AlasanAturan.mpeBelumTersedia].
/// - (ATURAN-0541-3, selesai 20 Okt): alasan tampil di layar review lewat
///   `FotoReviewScreen.catatan` / `teksAlasanAturan`.
class AturanFormulirAsli {
  const AturanFormulirAsli._();

  /// Template server yang dikenai aturan ini.
  static const templateId = 'anak_timbangan';

  static const tabelStandar = {'at_s1', 'at_s2'};

  /// Tabel tempat nominal keping diketik di lembar (baris S1; tabel lain
  /// punya baris sendiri yang nominalnya tidak diisi).
  static const tabelNominal = 'at_s1';
  static const tabelUut = ('at_t1', 'at_t2');

  /// Dua UUT dalam satu blok & pengulangan boleh berselisih paling banyak
  /// sekian kali resolusi neraca. Lebih dari itu = salah satunya hampir pasti
  /// salah baca (digit tertukar/hilang) → dua-duanya kuning.
  static const kelipatanResolusiDuaUut = 10;

  /// Pagar kasar Standard lawan nominal blok SELAMA MPE kelas belum tersedia:
  /// 1% nominal. Sengaja longgar — cuma menangkap koma geser / digit hilang,
  /// bukan menilai kelas.
  static const pagarKasarNominal = 0.01;

  static bool berlakuUntuk(String templateId) =>
      templateId == AturanFormulirAsli.templateId;

  /// Periksa semua sel satu foto. Kunci keluaran = [SelAturanMasuk.kunci];
  /// sel yang tidak kena aturan apa pun tidak muncul.
  ///
  /// [mpe] (opsional) = MPE untuk satu nominal, dalam satuan yang sama dengan
  /// pembacaan; `null`/tidak diberikan = pakai [pagarKasarNominal].
  static Map<String, PutusanAturan> periksa(
    List<SelAturanMasuk> sel, {
    double? Function(double nominal)? mpe,
  }) {
    final keluar = <String, PutusanAturan>{};

    void turunkan(String kunci, VonisAturan v, AlasanAturan a) {
      final lama = keluar[kunci];
      keluar[kunci] = (
        vonis: lama == null || v.index > lama.vonis.index ? v : lama.vonis,
        alasan: {...?lama?.alasan, a},
      );
    }

    // ---- per sel: desimal & Standard lawan nominal --------------------------
    for (final s in sel) {
      final teks = s.teks.trim();
      if (teks.isEmpty) continue;

      final nilai = _angka(teks);
      if (nilai == null) {
        // Bukan angka desimal biasa (huruf, `NaN`, `Infinity`, `1e3`, tanda
        // minus...) → MERAH kosong. `double.tryParse` di hilir menerima
        // `NaN`/`Infinity`/eksponen, jadi tidak boleh diandalkan.
        turunkan(s.kunci, VonisAturan.merah, AlasanAturan.bukanAngka);
        continue;
      }

      final desimalHarus = s.desimal ?? desimalDariResolusi(s.resolusi);
      final tertulis = desimalTertulis(teks);
      if (desimalHarus != null &&
          tertulis != null &&
          tertulis != desimalHarus) {
        turunkan(s.kunci, VonisAturan.kuning, AlasanAturan.desimalTakCocok);
      }

      if (tabelStandar.contains(s.tabelId)) {
        final nominal = s.teksNominal == null
            ? null
            : uraiNominal(s.teksNominal!).nilai;
        if (nominal != null && nominal > 0) {
          final batasMpe = mpe?.call(nominal);
          final batas = batasMpe ?? nominal * pagarKasarNominal;
          if ((nilai - nominal).abs() > batas + _eps(batas)) {
            turunkan(
              s.kunci,
              VonisAturan.kuning,
              AlasanAturan.standarJauhDariNominal,
            );
            if (batasMpe == null) {
              turunkan(
                s.kunci,
                VonisAturan.kuning,
                AlasanAturan.mpeBelumTersedia,
              );
            }
          }
        }
      }
    }

    // ---- dua UUT dalam satu blok & pengulangan ------------------------------
    final perPasangan = <(int, int), Map<String, SelAturanMasuk>>{};
    for (final s in sel) {
      if (s.tabelId != tabelUut.$1 && s.tabelId != tabelUut.$2) continue;
      (perPasangan[(s.barisKe, s.repeatNo)] ??= {})[s.tabelId] = s;
    }
    for (final p in perPasangan.values) {
      final a = p[tabelUut.$1], b = p[tabelUut.$2];
      if (a == null || b == null) continue;

      final na = _angka(a.teks.trim()), nb = _angka(b.teks.trim());
      final res = a.resolusi ?? b.resolusi;
      if (na == null || nb == null || res == null || res <= 0) continue;

      if ((na - nb).abs() > kelipatanResolusiDuaUut * res + _eps(res)) {
        turunkan(a.kunci, VonisAturan.kuning, AlasanAturan.duaUutBerselisih);
        turunkan(b.kunci, VonisAturan.kuning, AlasanAturan.duaUutBerselisih);
      }
    }

    // ---- kelengkapan blok, PER KOLOM PENGULANGAN ----------------------------
    //
    // Keputusan §23 (orkestrator, 20 Okt): OCR membaca kotak yang ada, server
    // merata-ratakan pembacaan per peran. Jadi satu kolom X1/X2/X3 dinilai
    // sendiri: kosong total di keempat baris = kolom itu tidak dipakai
    // (diabaikan, bukan merah); terisi sebagian = satu urutan S-T-T-S putus
    // → sel kosongnya MERAH. Blok yang tak satu kolom pun terisi tetap tidak
    // membuat titik.
    final perKolom = <(int, int), List<SelAturanMasuk>>{};
    for (final s in sel) {
      (perKolom[(s.barisKe, s.repeatNo)] ??= []).add(s);
    }
    for (final kolom in perKolom.values) {
      bool ada(SelAturanMasuk s) => s.gagalDibaca || s.teks.trim().isNotEmpty;
      final terisi = kolom.where(ada).length;

      if (terisi == 0 || terisi == kolom.length) continue;

      for (final s in kolom.where((s) => !ada(s))) {
        turunkan(s.kunci, VonisAturan.merah, AlasanAturan.blokTidakLengkap);
      }
    }

    return keluar;
  }

  /// Terapkan [vonis] ke teks & keyakinan baris review. Hanya menurunkan:
  ///
  /// - [VonisAturan.merah] → teks kosong, keyakinan 0 (MERAH, wajib diketik);
  /// - [VonisAturan.kuning] → keyakinan dipotong ke [AmbangKeyakinan.kuning]
  ///   (pita kuning). Keyakinan `null` tetap `null` (tidak diketahui — tetap
  ///   wajib dicek); keyakinan yang sudah di bawahnya tidak dinaikkan.
  static ({String teks, double? keyakinan}) terapkan(
    VonisAturan vonis, {
    required String teks,
    required double? keyakinan,
    AmbangKeyakinan ambang = AmbangKeyakinan.bawaan,
  }) => switch (vonis) {
    VonisAturan.tetap => (teks: teks, keyakinan: keyakinan),
    VonisAturan.merah => (teks: '', keyakinan: 0.0),
    VonisAturan.kuning => (
      teks: teks,
      keyakinan: keyakinan == null ? null : math.min(keyakinan, ambang.kuning),
    ),
  };
}

/// Satu sel masukan [AturanFormulirAsli.periksa].
typedef SelAturanMasuk = ({
  String kunci,
  String tabelId,
  int barisKe,
  int repeatNo,

  /// Teks OCR apa adanya ('' = kosong).
  String teks,

  /// Pembacaan sel ini GAGAL (galat ML Kit) — bukan kosong di kertas.
  bool gagalDibaca,

  /// `resolusi` & `desimal` dari aturan sel server (`aturan` JSON).
  double? resolusi,
  int? desimal,

  /// Teks nominal blok di lembar (boleh berbintang `20*`); `null` = belum ada.
  String? teksNominal,
});

typedef PutusanAturan = ({VonisAturan vonis, Set<AlasanAturan> alasan});

/// Urutan = keparahan; aturan hanya bisa memilih yang lebih parah.
enum VonisAturan { tetap, kuning, merah }

enum AlasanAturan {
  /// Jumlah angka di belakang koma beda dari resolusi neraca.
  desimalTakCocok,

  /// Standard terlalu jauh dari nominal blok.
  standarJauhDariNominal,

  /// Batas yang dipakai pagar kasar, bukan MPE kelas (TODO(ATURAN-0541-2)).
  mpeBelumTersedia,

  /// Dua UUT dalam satu blok & pengulangan berselisih terlalu jauh.
  duaUutBerselisih,

  /// Blok terisi sebagian; sel kosongnya wajib diketik.
  blokTidakLengkap,

  /// Teks bukan angka desimal biasa (mis. `NaN`, `1e3`, huruf) → merah.
  bukanAngka,
}

/// Titik sambung deteksi coretan — TODO(ATURAN-0541-1). Belum ada nilai
/// selain [belumDiperiksa]; jangan dipakai untuk menurunkan/menaikkan warna.
enum TandaCoretan { belumDiperiksa }

/// Nominal dari kertas/lembar: bintang (`20*`) = penanda keping KEDUA
/// bernominal sama, BUKAN bagian angka. `nilai` null kalau bukan angka.
({double? nilai, bool kepingKedua}) uraiNominal(String teks) {
  final t = teks.trim();
  final kedua = t.endsWith('*');
  final angka = t.replaceFirst(RegExp(r'\s*\*+$'), '');

  return (nilai: _angka(angka), kepingKedua: kedua);
}

/// Jumlah angka di belakang pemisah desimal yang TERTULIS (`49,99992` → 5,
/// `50` → 0). Pemisah = `,` atau `.` terakhir. `null` = bukan bentuk angka
/// sederhana (dua pemisah berbeda, huruf, dst.) — aturan desimal dilewati.
int? desimalTertulis(String teks) {
  final t = teks.trim();
  if (!RegExp(r'^\d+([.,]\d+)?$').hasMatch(t)) return null;

  final i = t.lastIndexOf(RegExp(r'[.,]'));

  return i < 0 ? 0 : t.length - i - 1;
}

/// Desimal yang diharapkan dari resolusi — sama dengan server
/// (`TemplateLembarKerja::desimal`): 0,01 → 2.
int? desimalDariResolusi(double? resolusi) {
  if (resolusi == null || resolusi <= 0) return null;

  final d = -((math.log(resolusi) / math.ln10) + 1e-9).floor();

  return math.min(math.max(0, d), 8);
}

/// Angka desimal KETAT: digit, opsional satu pemisah `,`/`.` lalu digit.
/// Menolak `NaN`, `Infinity`, eksponen, tanda, spasi, dan pemisah ganda —
/// bentuk yang `double.tryParse` terima tetapi tidak pernah ditulis di kertas.
double? _angka(String teks) {
  final t = teks.trim();
  if (!_polaAngka.hasMatch(t)) return null;

  return double.parse(t.replaceAll(',', '.'));
}

final _polaAngka = RegExp(r'^\d+([.,]\d+)?$');

/// Toleransi pembulatan biner untuk pembandingan kelipatan resolusi.
double _eps(double res) => res * 1e-6;
