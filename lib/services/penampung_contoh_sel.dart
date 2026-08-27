import 'potong_sel_foto.dart';
import 'simpanan_contoh_sel.dart';

/// Alamat satu sel — cukup buat mencocokkan potongan dengan angka finalnya.
typedef KunciSel = ({double titikUkur, int repeatNo, String fieldId});

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
  void tampung({required Iterable<PotonganSel> potongan}) {
    for (final p in potongan) {
      _tertampung[_kunci(p)] = (
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

  KunciSel _kunci(PotonganSel p) => (
    titikUkur: p.kotak.titikUkur,
    repeatNo: p.kotak.repeatNo,
    fieldId: p.kotak.fieldId,
  );
}
