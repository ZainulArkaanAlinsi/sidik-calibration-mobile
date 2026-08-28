import 'dart:ui' show Rect;

import '../services/analisis_dokumen.dart';
import '../services/vonis_sel_foto.dart';

/// Jenis isi satu kolom, ditebak dari nilainya sendiri.
///
/// Sengaja SEDIKIT. Tiap jenis baru harus bisa dibedakan dari yang lain cuma
/// dengan melihat nilainya — begitu pembedanya butuh tahu "ini lembar apa",
/// dia bukan lagi milik jalur generik.
enum JenisIsi {
  angka,
  teks,

  /// Kolomnya ada, tapi belum diisi. Dibedakan dari [teks] kosong karena
  /// artinya beda buat teknisi: yang ini "kertasnya minta diisi", bukan
  /// "kebaca sebagai teks kosong".
  kosong,
}

/// Satu kolom isian hasil pembacaan dokumen.
typedef KolomSkema = ({
  String label,
  String nilai,
  JenisIsi jenis,
  String? satuan,
  double? keyakinan,
  VonisFoto vonis,
  Rect kotak,
});

/// Satu tabel di dalam skema — bentuknya mengikuti tabel di kertasnya.
typedef TabelSkema = ({List<String> kepala, List<List<String>> baris, Rect kotak});

/// Bentuk dokumen yang dibaca dari FOTO, disusun dari isinya sendiri.
///
/// ## Kenapa bukan `LembarKerja`
///
/// Godaan pertamanya memakai ulang [LembarKerja] supaya renderer form yang
/// sudah ada langsung bisa menggambarnya. Itu tidak jadi dilakukan, dan
/// alasannya bukan kerapian: [LembarKerja] mewajibkan `larutanStandar`,
/// `jumlahPengulangan`, `satuan`, `kodeDokumen` — dan dokumen yang baru
/// difoto **tidak menyediakan satu pun dari itu**. Mengisinya berarti
/// mengarang nilai, dan angka karangan di lembar kalibrasi persis yang paling
/// mahal di proyek ini.
///
/// Jadi bentuknya mengikuti dokumen: apa yang ketemu, itu yang ada. Yang tidak
/// ketemu tidak muncul — bukan muncul sebagai nol.
typedef SkemaDokumen = ({
  String? judul,
  List<KolomSkema> kolom,
  List<TabelSkema> tabel,
  List<String> peringatan,
});

/// Susun [SkemaDokumen] dari hasil [AnalisisDokumen].
///
/// Ini yang mengubah "ada pasangan label→nilai dan ada tabel" jadi bentuk yang
/// bisa digambar dan diisi. Tidak ada satu pun nama alat di sini, dan tidak
/// ada daftar field tetap — kalau suatu saat ada, jalur generiknya sudah mati
/// dan yang tersisa parser dengan nama lain.
class PembuatSkema {
  const PembuatSkema({this.ambang = AmbangKeyakinan.bawaan});

  final AmbangKeyakinan ambang;

  /// Satuan yang dikenali kalau menempel di ekor nilai (`25,4 °C`).
  ///
  /// Daftar ini **bukan** batas kemampuan sistem: nilai bersatuan di luar
  /// daftar tetap masuk, satuannya saja yang tidak dipisah. Dia ada supaya
  /// satuan yang umum tidak ikut terbaca sebagai bagian dari angkanya —
  /// bukan supaya lembar yang satuannya asing ditolak.
  static const _satuanUmum = [
    '°C', 'C', '%RH', '%', 'pH', 'NTU', 'µS/cm', 'mS/cm', 'µS', 'mS',
    'V', 'mV', 'A', 'mA', 'kg', 'g', 'mg', 'mL', 'L', 'm³', 'nm',
    'bar', 'psi', 'kPa', 'MPa', 'Nm', 'rpm', 's', 'min', 'jam', 'mm', 'cm', 'm',
  ];

  SkemaDokumen susun({
    required List<PasanganLabel> pasangan,
    required List<TabelDokumen> tabel,
    String? judul,
  }) {
    final peringatan = <String>[];

    final kolom = [
      for (final p in pasangan) _kolom(p),
    ];

    // Label kembar itu tanda pembacaannya meleset, bukan dokumen yang aneh:
    // lembar kerja tidak menamai dua kolom sama persis. Disebut sebagai
    // peringatan, BUKAN dibuang — yang dibuang menghilangkan satu isian dari
    // layar tanpa ada yang tahu.
    final hitung = <String, int>{};
    for (final k in kolom) {
      hitung[k.label] = (hitung[k.label] ?? 0) + 1;
    }

    for (final e in hitung.entries) {
      if (e.value > 1) peringatan.add('Label "${e.key}" ketemu ${e.value} kali');
    }

    if (kolom.isEmpty && tabel.isEmpty) {
      peringatan.add('Nggak ada isian maupun tabel yang kebaca dari foto ini');
    }

    return (
      judul: judul,
      kolom: kolom,
      tabel: [
        for (final t in tabel)
          (kepala: t.kepala, baris: t.baris, kotak: t.kotak),
      ],
      peringatan: peringatan,
    );
  }

  KolomSkema _kolom(PasanganLabel p) {
    final (nilai, satuan) = _pisahSatuan(p.nilai);

    return (
      label: p.label,
      nilai: nilai,
      jenis: _jenis(nilai),
      satuan: satuan,
      keyakinan: p.keyakinan,
      // Vonisnya lewat aturan yang SAMA dengan jalur foto tabel — termasuk
      // "tulisan tangan nggak pernah hijau". Jalur generik tidak boleh lebih
      // longgar cuma karena dokumennya belum dikenal; kalau ada bedanya,
      // justru di sini yang lebih perlu diperiksa.
      vonis: NilaiVonisFoto.dari(p.keyakinan, ambang: ambang),
      kotak: p.kotakNilai,
    );
  }

  JenisIsi _jenis(String nilai) {
    if (nilai.trim().isEmpty) return JenisIsi.kosong;
    return _angka(nilai) ? JenisIsi.angka : JenisIsi.teks;
  }

  bool _angka(String s) =>
      RegExp(r'^[-+]?\d+([.,]\d+)?$').hasMatch(s.trim());

  /// Pisahkan satuan dari ekor nilai.
  ///
  /// Yang dipisah cuma kalau sisanya benar-benar angka: `PT Gracia m` tidak
  /// boleh kehilangan `m`-nya cuma karena `m` kebetulan satuan panjang.
  ///
  /// ## Kenapa huruf besar-kecilnya dijaga
  ///
  /// **`Nm` newton-meter, `nm` nanometer.** Dicocokkan tanpa peduli besar-kecil,
  /// torsi 200 Nm dari lembar torque wrench pulang bersatuan panjang gelombang
  /// — angkanya benar, satuannya masuk akal dibaca sekilas, dan salahnya cuma
  /// ketahuan kalau ada yang memperhatikan huruf pertamanya. Jadi:
  ///
  ///  1. Cocokkan PERSIS dulu. `Nm` ketemu `Nm`.
  ///  2. Baru cocokkan abai besar-kecil — dan waktu itu yang dipulangkan
  ///     **ejaan dokumennya**, bukan ejaan daftar di sini. Teknisi yang
  ///     menulis `MPA` tidak boleh diam-diam diubah jadi `MPa`; yang dijawab
  ///     berkas ini "ada satuannya", bukan "satuannya harus ditulis begini".
  (String, String?) _pisahSatuan(String nilai) {
    final bersih = nilai.trim();

    for (final s in _satuanUmum) {
      if (!bersih.endsWith(s)) continue;

      final sisa = bersih.substring(0, bersih.length - s.length).trim();
      if (sisa.isNotEmpty && _angka(sisa)) return (sisa, s);
    }

    for (final s in _satuanUmum) {
      if (!bersih.toLowerCase().endsWith(s.toLowerCase())) continue;

      final potong = bersih.length - s.length;
      final sisa = bersih.substring(0, potong).trim();

      if (sisa.isNotEmpty && _angka(sisa)) {
        return (sisa, bersih.substring(potong));
      }
    }

    return (bersih, null);
  }
}
