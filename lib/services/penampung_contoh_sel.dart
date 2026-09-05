import 'peta_tabel_foto.dart';
import 'potong_sel_foto.dart';
import 'simpanan_contoh_sel.dart';

/// Cara membaca angka FINAL satu sel dari formulir.
///
/// ## Kenapa pemanggil yang menyediakannya
///
/// Tiga jalur foto menyimpan selnya di tempat yang beda-beda, dan alamatnya
/// nggak bisa dipaksa jadi satu bentuk:
///
/// | jalur | alamat selnya |
/// |---|---|
/// | tabel | `(tahap, titikUkur, POSISI kolom, fieldId)` |
/// | matriks (Autoklaf) | `(kodeData, nomor titik waktu)` |
/// | grid (Enclosure) | `(penanda baris, POSISI kolom)` |
///
/// Versi pertama kelas ini mengandaikan bentuk TABEL berlaku buat semuanya.
/// Itu salah, dan ketahuannya waktu menyambung jalur kedua. Memaksakan satu
/// bentuk berarti dua jalur lain dialamatkan lewat kunci yang bukan miliknya —
/// dan salah alamat di sini artinya label menempel di potongan sel yang salah.
///
/// Sekarang penampungnya nggak tahu apa-apa soal alamat: yang tahu formulirnya
/// yang menyediakan cara membacanya. Fungsinya dipanggil BELAKANGAN, waktu
/// [PenampungContohSel.serahkan] jalan — itu yang bikin labelnya angka final
/// teknisi, bukan bacaan OCR waktu memotret.
///
/// Balikin `null` kalau selnya nggak ada atau nggak punya angka.
typedef PembacaLabel = String? Function(KotakSelFoto);

/// Cara mengenali sel yang SAMA antar jepretan.
///
/// Dipakai membuang tampungan lama waktu sel yang sama difoto ulang. Wajib
/// unik per sel di dalam satu lembar — kunci yang kekasar bikin dua sel beda
/// saling menimpa dan separuh data latihnya lenyap tanpa jejak.
typedef PenandaSel = String Function(KotakSelFoto);

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

  final _tertampung =
      <
        String,
        ({String pemilik, PotonganSel potongan, PembacaLabel labelAkhir})
      >{};

  int get jumlah => _tertampung.length;

  /// Berapa tampungan milik [pemilik] — buat test dan penjagaan.
  int jumlahMilik(String pemilik) =>
      _tertampung.values.where((v) => v.pemilik == pemilik).length;

  /// Tahan potongan hasil satu jepretan.
  ///
  /// Sel yang difoto ULANG menimpa yang lama: jepretan kedua dilakukan justru
  /// karena yang pertama jelek, jadi yang lama bukan contoh tambahan melainkan
  /// contoh yang sudah ditolak teknisinya sendiri. [penanda] yang menentukan
  /// "sel yang sama".
  ///
  /// [labelAkhir] disimpan, BUKAN dipanggil sekarang. Dia baru dijalankan
  /// waktu [serahkan] — itu seluruh alasan penampung ini ada.
  ///
  /// Jenis lembarnya nggak diminta di sini: dia sifat seluruh lembar, bukan
  /// sifat tiap potongan, dan yang tahu profil alatnya cuma layar. Diminta di
  /// [serahkan].
  ///
  /// ## Kenapa [pemilik] wajib
  ///
  /// Penampungnya SATU buat seluruh aplikasi, jadi tanpa penanda kepemilikan
  /// dia gampang mencampur dua sesi lembar. Teknisi yang memotret lalu MENUTUP
  /// lembarnya tanpa menyimpan meninggalkan potongan di sini — dan waktu
  /// lembar BERIKUTNYA dikirim, potongan lembar lama ikut tersimpan dengan
  /// nama lembar yang salah, sementara [labelAkhir]-nya membaca formulir yang
  /// sudah di-dispose.
  ///
  /// Isi [pemilik] dengan sesuatu yang unik per sesi lembar
  /// (`LembarKerjaState.clientRequestId`). [serahkan] cuma menyerahkan
  /// tampungan milik pemilik yang menyerahkannya, dan [buang] cuma membuang
  /// miliknya sendiri.
  void tampung({
    required Iterable<PotonganSel> potongan,
    required PenandaSel penanda,
    required PembacaLabel labelAkhir,
    required String pemilik,
  }) {
    for (final p in potongan) {
      _tertampung['$pemilik|${penanda(p.kotak)}'] = (
        pemilik: pemilik,
        potongan: p,
        labelAkhir: labelAkhir,
      );
    }
  }

  /// Buang tampungan milik [pemilik] tanpa menyimpan apa pun.
  ///
  /// WAJIB dipanggil waktu sesi lembar berakhir tanpa dikirim — lembar yang
  /// ditutup sesudah difoto meninggalkan potongan berikut closure yang
  /// menangkap formulir yang sudah di-dispose.
  ///
  /// Cuma miliknya sendiri yang dibuang: layar lain yang kebetulan masih
  /// hidup nggak boleh kehilangan tampungannya gara-gara layar ini ditutup.
  void buang(String pemilik) =>
      _tertampung.removeWhere((_, v) => v.pemilik == pemilik);

  /// Serahkan tampungan ke [simpanan], dengan label dari [labelAkhir].
  ///
  /// Tiap tampungan dibaca lewat [PembacaLabel] yang disertakan waktu
  /// [tampung] — dipanggil SEKARANG, bukan waktu itu, supaya yang terbaca
  /// angka yang akhirnya diketik teknisi.
  ///
  /// Sel yang labelnya `null` atau kosong nggak disimpan — contoh tanpa label
  /// nggak bisa melatih apa pun — tapi tetap dihitung di
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
  Future<HasilSerah> serahkan({
    required String lembar,
    required String pemilik,
  }) async {
    // Disalin dulu, lalu tampungannya dikosongkan SEBELUM menulis: kalau
    // penulisannya gagal di tengah, yang sudah tersimpan nggak ikut terserah
    // lagi di penekanan Simpan berikutnya.
    final isi = [
      for (final e in _tertampung.values)
        if (e.pemilik == pemilik) e,
    ];

    _tertampung.removeWhere((_, v) => v.pemilik == pemilik);

    var tersimpan = 0;
    var tanpaLabel = 0;

    for (final e in isi) {
      final label = e.labelAkhir(e.potongan.kotak);

      if (label == null || label.trim().isEmpty) {
        tanpaLabel++;
        continue;
      }

      final hasil = await simpanan.simpan(
        potongan: e.potongan,
        label: label,
        lembar: lembar,
        // Apa yang OCR baca waktu difoto. Boleh kosong, dan boleh beda dari
        // labelnya — yang beda itu contoh paling berharga.
        bacaanOcr: e.potongan.kotak.teks,
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
