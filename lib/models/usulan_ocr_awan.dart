import 'ocr_awan.dart';
import 'worksheet_scan.dart' show KoreksiSel;

/// Alur USULAN untuk hasil OCR awan (gerbang 2). Logika murni, tanpa layar.
///
/// Aturan yang dijaga di sini, dan semuanya tidak menghasilkan error bila
/// dilanggar, jadi masing-masing punya tes:
///
///  1. **Tidak ada nilai sebelum manusia memutuskan.** Papan baru dibuat dari
///     [HasilOcrAwan] selalu berisi keputusan [KeputusanUsulan.menunggu] dan
///     [PapanUsulanAwan.koreksiTerkonfirmasi] kosong. Satu-satunya jalan ke
///     nilai adalah [PapanUsulanAwan.pakai] atau [PapanUsulanAwan.ubah] untuk
///     SATU kunci, yaitu aksi teknisi pada sel itu.
///  2. **Tidak ada "terima semua".** Tidak ada method yang memutuskan lebih dari
///     satu sel sekaligus, dan itu disengaja (tulisan tangan tidak pernah
///     hijau; model OCR tetap percaya diri saat salah membaca coretan).
///  3. **Hanya sel yang punya bentuk angka murni yang menjadi usulan.** Merah,
///     kosong, `teks_normal` kosong, atau bentuk yang tidak dikenal klien
///     masuk [PapanUsulanAwan.tanpaUsulan]: sel itu tetap kosong dan tidak
///     mengisi apa pun.
///  4. **Dua bentuk berdampingan.** [UsulanSelAwan.duaBentuk] mengembalikan
///     `teks_awan` dan `teks_normal` bila berbeda; layar wajib menampilkan
///     keduanya, bukan hanya yang sudah dirapikan.
///  5. **Sel identitas tidak pernah jadi usulan.** Kunci `isian|`/`centang|`
///     dibuang walau server (keliru) mengirimnya.
///
/// Papan tidak bisa diubah; tiap keputusan menghasilkan papan baru.

/// Keputusan teknisi atas satu usulan.
enum KeputusanUsulan {
  /// Belum dilihat. Belum ada nilai.
  menunggu,

  /// Teknisi menekan "Pakai" pada sel ini; nilainya `teks_normal` apa adanya.
  dipakai,

  /// Teknisi mengetik angka sendiri pada sel ini (beda dari usulan).
  diubah,

  /// Teknisi menolak usulan. Sel tidak terisi dari OCR awan.
  ditolak,
}

/// Mengapa sebuah sel dari `hasil[]` tidak ditawarkan sebagai usulan.
enum AlasanTanpaUsulan {
  /// Status merah: tidak lolos normalisasi / keyakinan rendah / Google gagal.
  merah,

  /// Google tidak melihat tulisan. Sel kosong tetap kosong.
  kosong,

  /// Kuning tetapi `teks_normal` tidak ada, atau bukan angka murni menurut
  /// [bacaAngkaUsulan]. Tidak ditebak.
  bentukTidakDikenal,

  /// Kunci sel identitas (`isian|`/`centang|`).
  selIdentitas,
}

/// Sel `hasil[]` yang TIDAK menjadi usulan. Tidak punya nilai.
class SelTanpaUsulanAwan {
  const SelTanpaUsulanAwan({
    required this.kunci,
    required this.sebab,
    this.alasan = const [],
  });

  final String kunci;
  final AlasanTanpaUsulan sebab;

  /// Kode alasan dari server (diterjemahkan di layar, bukan dibaca mentah).
  final List<String> alasan;
}

final _angkaMurni = RegExp(r'^[+-]?\d+(?:[.,]\d+)?$');

/// Baca bentuk angka murni (`4,01`, `4.01`, `-0,5`, `12`) menjadi double.
///
/// Sengaja KETAT, dan itu keputusan pemilik 23 Nov 2026: hasil OCR tidak diubah
/// agar cocok. Tidak menerima eksponen (`1e5`), `NaN`/`Infinity`, pemisah
/// ribuan (`1.234,56`), spasi di tengah, atau koma/titik menggantung (`4,`).
/// Selain itu `null`. Spasi di tepi dibuang.
///
/// Tidak ada pembulatan: nilai antara tidak dibulatkan.
double? bacaAngkaUsulan(String? teks) {
  if (teks == null) return null;

  final t = teks.trim();
  if (!_angkaMurni.hasMatch(t)) return null;

  return double.tryParse(t.replaceFirst(',', '.'));
}

/// Satu usulan untuk satu sel, beserta keputusan teknisi.
class UsulanSelAwan {
  const UsulanSelAwan._({
    required this.sel,
    required this.angkaUsulan,
    this.keputusan = KeputusanUsulan.menunggu,
    this.teksFinal,
    this.nilaiFinal,
  });

  /// Respons server untuk sel ini, apa adanya.
  final SelOcrAwan sel;

  /// Nilai dari `teks_normal` (yang dilihat teknisi), bukan dari `nilai_awan`.
  final double angkaUsulan;

  final KeputusanUsulan keputusan;

  /// Isi sel bila sudah diputuskan [KeputusanUsulan.dipakai]/[KeputusanUsulan.diubah];
  /// selain itu `null`.
  final String? teksFinal;
  final double? nilaiFinal;

  String get kunci => sel.kunci;

  /// Belum diputuskan teknisi.
  bool get perluDicek => keputusan == KeputusanUsulan.menunggu;

  /// Teknisi sudah menyatakan nilai untuk sel ini.
  bool get terkonfirmasi =>
      keputusan == KeputusanUsulan.dipakai ||
      keputusan == KeputusanUsulan.diubah;

  /// Bentuk yang ditawarkan ke teknisi (`teks_normal`).
  String get teksUsulan => sel.teksNormal!.trim();

  /// `teks_awan` dan `teks_normal` untuk ditampilkan berdampingan; `null` bila
  /// keduanya sama dan tidak perlu dua kolom.
  ({String awan, String normal})? get duaBentuk => sel.bentukBeda
      ? (awan: sel.teksAwan!, normal: sel.teksNormal!)
      : null;

  UsulanSelAwan _putuskan(
    KeputusanUsulan keputusan, {
    String? teks,
    double? nilai,
  }) => UsulanSelAwan._(
    sel: sel,
    angkaUsulan: angkaUsulan,
    keputusan: keputusan,
    teksFinal: teks,
    nilaiFinal: nilai,
  );
}

/// Seluruh usulan satu permintaan `ocr-awan`.
class PapanUsulanAwan {
  PapanUsulanAwan._({
    required List<UsulanSelAwan> usulan,
    required List<SelTanpaUsulanAwan> tanpaUsulan,
    required List<SelDilewatiAwan> dilewati,
    required this.sebagian,
  }) : usulan = List.unmodifiable(usulan),
       tanpaUsulan = List.unmodifiable(tanpaUsulan),
       dilewati = List.unmodifiable(dilewati);

  /// Usulan awal: semuanya [KeputusanUsulan.menunggu], belum ada nilai.
  factory PapanUsulanAwan.dari(HasilOcrAwan hasil) {
    final usulan = <UsulanSelAwan>[];
    final tanpa = <SelTanpaUsulanAwan>[];
    final terlihat = <String>{};

    for (final sel in hasil.hasil) {
      // Kunci kembar: yang pertama menang, supaya satu sel tidak punya dua
      // keputusan.
      if (!terlihat.add(sel.kunci)) continue;

      if (kunciSelIdentitas(sel.kunci)) {
        tanpa.add(
          SelTanpaUsulanAwan(
            kunci: sel.kunci,
            sebab: AlasanTanpaUsulan.selIdentitas,
            alasan: sel.alasan,
          ),
        );
        continue;
      }

      if (sel.status == StatusSelAwan.merah ||
          sel.status == StatusSelAwan.kosong) {
        tanpa.add(
          SelTanpaUsulanAwan(
            kunci: sel.kunci,
            sebab: sel.status == StatusSelAwan.kosong
                ? AlasanTanpaUsulan.kosong
                : AlasanTanpaUsulan.merah,
            alasan: sel.alasan,
          ),
        );
        continue;
      }

      final angka = sel.adaUsulan ? bacaAngkaUsulan(sel.teksNormal) : null;
      if (angka == null) {
        tanpa.add(
          SelTanpaUsulanAwan(
            kunci: sel.kunci,
            sebab: AlasanTanpaUsulan.bentukTidakDikenal,
            alasan: sel.alasan,
          ),
        );
        continue;
      }

      usulan.add(UsulanSelAwan._(sel: sel, angkaUsulan: angka));
    }

    return PapanUsulanAwan._(
      usulan: usulan,
      tanpaUsulan: tanpa,
      dilewati: hasil.dilewati,
      sebagian: hasil.meta.sebagian,
    );
  }

  /// Sel yang ditawarkan, urutan dari server.
  final List<UsulanSelAwan> usulan;

  /// Sel dari `hasil[]` yang tidak ditawarkan (tetap kosong / isi manual).
  final List<SelTanpaUsulanAwan> tanpaUsulan;

  /// `dilewati[]` dari server: tidak dibaca sama sekali.
  final List<SelDilewatiAwan> dilewati;

  /// Server hanya membaca sebagian sel yang diminta (`meta.sebagian`).
  final bool sebagian;

  UsulanSelAwan? cari(String kunci) {
    for (final u in usulan) {
      if (u.kunci == kunci) return u;
    }
    return null;
  }

  int get jumlahMenunggu => usulan.where((u) => u.perluDicek).length;

  bool get adaYangMenunggu => jumlahMenunggu > 0;

  /// Teknisi menekan "Pakai" pada SATU sel: nilainya `teks_normal` apa adanya.
  PapanUsulanAwan pakai(String kunci) {
    final u = _wajibAda(kunci);

    return _ganti(
      u,
      u._putuskan(
        KeputusanUsulan.dipakai,
        teks: u.teksUsulan,
        nilai: u.angkaUsulan,
      ),
    );
  }

  /// Teknisi mengetik angkanya sendiri pada SATU sel. [teks] harus angka murni
  /// ([bacaAngkaUsulan]); selain itu [ArgumentError] (layar yang memvalidasi
  /// ketikan, bukan model yang menebak). Sama dengan usulan = [KeputusanUsulan.dipakai].
  PapanUsulanAwan ubah(String kunci, String teks) {
    final u = _wajibAda(kunci);
    final nilai = bacaAngkaUsulan(teks);

    if (nilai == null) {
      throw ArgumentError.value(teks, 'teks', 'Bukan angka murni.');
    }

    return _ganti(
      u,
      u._putuskan(
        nilai == u.angkaUsulan
            ? KeputusanUsulan.dipakai
            : KeputusanUsulan.diubah,
        teks: teks.trim(),
        nilai: nilai,
      ),
    );
  }

  /// Teknisi menolak usulan pada SATU sel. Tidak menghasilkan nilai.
  PapanUsulanAwan tolak(String kunci) {
    final u = _wajibAda(kunci);

    return _ganti(u, u._putuskan(KeputusanUsulan.ditolak));
  }

  /// Batalkan keputusan: sel kembali [KeputusanUsulan.menunggu], nilainya hilang.
  PapanUsulanAwan kembalikan(String kunci) {
    final u = _wajibAda(kunci);

    return _ganti(u, u._putuskan(KeputusanUsulan.menunggu));
  }

  /// Nilai yang SUDAH dinyatakan teknisi, siap dikirim lewat
  /// `WorksheetScanService.kirimKoreksi`. Hanya sel terkonfirmasi.
  ///
  /// `kirimKoreksi` menuntut SEMUA sel lembar (bukti akurasi), jadi pemanggil
  /// menggabungkan daftar ini dengan sel lain; papan ini tidak mengarang nilai
  /// untuk sel yang ditolak, tanpa usulan, atau belum diputuskan.
  List<KoreksiSel> get koreksiTerkonfirmasi => [
    for (final u in usulan)
      if (u.terkonfirmasi) KoreksiSel(kunci: u.kunci, nilaiFinal: u.nilaiFinal),
  ];

  UsulanSelAwan _wajibAda(String kunci) {
    final u = cari(kunci);
    if (u == null) {
      throw ArgumentError.value(
        kunci,
        'kunci',
        'Tidak ada usulan untuk sel ini.',
      );
    }
    return u;
  }

  PapanUsulanAwan _ganti(UsulanSelAwan lama, UsulanSelAwan baru) =>
      PapanUsulanAwan._(
        usulan: [for (final u in usulan) identical(u, lama) ? baru : u],
        tanpaUsulan: tanpaUsulan,
        dilewati: dilewati,
        sebagian: sebagian,
      );
}
