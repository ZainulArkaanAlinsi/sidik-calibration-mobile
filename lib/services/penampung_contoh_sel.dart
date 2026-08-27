import 'potong_sel_foto.dart';
import 'simpanan_contoh_sel.dart';

/// Alamat satu sel, dalam bentuk yang BISA LANGSUNG dipakai membaca angka
/// finalnya dari formulir.
///
/// ## Kenapa posisi, bukan nomor Repeat
///
/// Formulirnya menyimpan sel per POSISI kolom (`TitikState.kotak(tahap,
/// kolom, index)`), sementara foto mengenali sel per NOMOR Repeat
/// (`X1`, `X2`, …). Dua-duanya kelihatan sama selama daftar pengulangannya
/// `[1, 2, 3]` — dan berhenti sama begitu ada lembar yang pengulangannya
/// nggak mulai dari 1 atau nggak berurutan.
///
/// Repo ini sudah pernah kena bentuk bug yang persis sama: grid sensor
/// memakai `repeatNo - 1` sebagai indeks, yang benar
/// `pengulangan.indexOf(repeatNo)`. Akibatnya sunyi — angkanya mendarat di
/// kolom yang salah tanpa satu pun error.
///
/// Makanya penerjemahannya dilakukan SEKALI, di [PenampungContohSel.tampung],
/// di tempat yang memang memegang daftar pengulangan tabelnya. Yang keluar
/// dari sini sudah berupa alamat formulir, jadi pemanggil nggak punya
/// kesempatan menebaknya lagi.
///
/// [tahap] ikut dibawa karena satu lembar bisa punya tabel `sebelum` dan
/// `sesudah` dengan titik dan kolom yang sama persis — tanpa dia, contoh dari
/// dua tabel itu saling menimpa.
typedef KunciSel = ({
  String tahap,
  double titikUkur,
  int posisiRepeat,
  String fieldId,
});

/// Hasil menyerahkan tampungan ke simpanan.
///
/// [tanpaLabel] dilaporkan, bukan dilewat diam-diam: kalau angkanya besar,
/// artinya banyak sel yang difoto lalu dikosongkan teknisi — dan itu petunjuk
/// tentang fotonya, bukan sesuatu yang pantas hilang tanpa jejak.
typedef HasilSerah = ({int tersimpan, int tanpaLabel});

/// Menahan potongan sel dari saat DIFOTO sampai teknisi menekan SIMPAN.
///
/// ## Kenapa ditahan, bukan langsung disimpan
///
/// Keputusan pemilik lab: yang jadi label itu angka **saat teknisi menekan
/// Simpan**, bukan angka yang dibaca OCR sesaat setelah foto.
///
/// Bedanya menentukan, dan ini inti seluruh berkas ini. Teknisi memotret, lalu
/// **mengoreksi** angka yang salah baca — dan koreksi itu justru kejadian yang
/// paling berharga: di situlah OCR-nya meleset, dan di situ pula angka yang
/// benar akhirnya diketik. Disimpan sesaat setelah foto, potongannya
/// dipasangkan dengan bacaan yang SALAH, dan model dilatih buat mengulangi
/// kesalahan yang barusan dibetulkan orang.
///
/// Jadi potongannya menunggu di sini, dan angkanya diambil belakangan.
///
/// ## Yang ditahan cuma di memori
///
/// Nggak ada yang ditulis ke penyimpanan sampai [serahkan] dipanggil. Teknisi
/// yang membatalkan lembarnya nggak meninggalkan jejak apa-apa — [buang] yang
/// mengurusnya.
class PenampungContohSel {
  PenampungContohSel(this.simpanan);

  final SimpananContohSel simpanan;

  final _tertampung = <KunciSel, ({PotonganSel potongan, String? bacaanOcr})>{};

  int get jumlah => _tertampung.length;

  /// Tahan potongan hasil satu jepretan.
  ///
  /// Sel yang difoto ULANG menimpa yang lama: jepretan kedua dilakukan justru
  /// karena yang pertama jelek, jadi yang lama bukan contoh tambahan melainkan
  /// contoh yang sudah ditolak teknisinya sendiri.
  ///
  /// Jenis lembarnya NGGAK diminta di sini, dan itu disengaja: dia sifat
  /// seluruh lembar, bukan sifat tiap potongan. Diminta di sini, tiga widget
  /// yang memanggil ini harus dialiri profil alatnya cuma buat diteruskan —
  /// tiga parameter baru yang nggak dipakai widgetnya sendiri. Diminta di
  /// [serahkan], yang menyebutnya cuma layar yang memang sudah tahu.
  ///
  /// [pengulangan] dan [tahap] SEBALIKNYA memang milik tabel yang barusan
  /// difoto, dan cuma pemanggil di sini yang memegangnya. Dua-duanya dipakai
  /// menerjemahkan nomor Repeat jadi alamat formulir — lihat [KunciSel].
  ///
  /// Sel yang nomor Repeat-nya NGGAK ada di [pengulangan] dibuang: dia nggak
  /// punya kolom di formulir, jadi nggak akan pernah punya angka final yang
  /// bisa jadi labelnya. Ditahan, dia cuma jadi tampungan yang selalu
  /// dihitung "tanpa label" tiap kali Simpan ditekan.
  void tampung({
    required Iterable<PotonganSel> potongan,
    required List<int> pengulangan,
    required String tahap,
  }) {
    for (final p in potongan) {
      final posisi = pengulangan.indexOf(p.kotak.repeatNo);
      if (posisi < 0) continue;

      _tertampung[(
        tahap: tahap,
        titikUkur: p.kotak.titikUkur,
        posisiRepeat: posisi,
        fieldId: p.kotak.fieldId,
      )] = (
        potongan: p,
        // Apa yang OCR baca waktu difoto. Boleh kosong, dan boleh beda dari
        // label finalnya — yang beda itu contoh paling berharga.
        bacaanOcr: p.kotak.teks,
      );
    }
  }

  /// Buang tampungan tanpa menyimpan apa pun.
  void buang() => _tertampung.clear();

  /// Serahkan tampungan ke [simpanan], dengan label dari [labelAkhir].
  ///
  /// [labelAkhir] balikin angka yang AKHIRNYA ada di sel itu, atau `null`
  /// kalau selnya kosong. Yang `null` atau kosong nggak disimpan — contoh
  /// tanpa label nggak bisa melatih apa pun — tapi tetap dihitung di
  /// [HasilSerah.tanpaLabel].
  ///
  /// Tampungannya dikosongkan sesudah ini, jadi menekan Simpan dua kali nggak
  /// menyimpan contoh yang sama dua kali.
  ///
  /// Disimpan BERURUTAN, satu per satu. [SimpananContohSel] memang sudah
  /// mengantre tulisannya sendiri, jadi ini bukan soal benar-salah melainkan
  /// soal beban: satu lembar bisa seratusan sel, dan menembakkan seratus
  /// penulisan berkas sekaligus bikin HP tersendat persis waktu teknisi baru
  /// saja menekan Simpan.
  Future<HasilSerah> serahkan(
    String? Function(KunciSel) labelAkhir, {
    required String lembar,
  }) async {
    // Disalin dulu, lalu tampungannya dikosongkan SEBELUM menulis: kalau
    // penulisannya gagal di tengah, yang sudah tersimpan nggak ikut terserah
    // lagi di penekanan Simpan berikutnya.
    final isi = Map.of(_tertampung);
    _tertampung.clear();

    var tersimpan = 0;
    var tanpaLabel = 0;

    for (final e in isi.entries) {
      final label = labelAkhir(e.key);

      if (label == null || label.trim().isEmpty) {
        tanpaLabel++;
        continue;
      }

      final hasil = await simpanan.simpan(
        potongan: e.value.potongan,
        label: label,
        lembar: lembar,
        bacaanOcr: e.value.bacaanOcr,
      );

      if (hasil == null) {
        tanpaLabel++;
        continue;
      }

      tersimpan++;
    }

    return (tersimpan: tersimpan, tanpaLabel: tanpaLabel);
  }
}
