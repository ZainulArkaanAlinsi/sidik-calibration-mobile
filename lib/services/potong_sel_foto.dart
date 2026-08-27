import 'package:image/image.dart' as img;

import 'peta_tabel_foto.dart';

/// Satu sel yang sudah jadi citra sendiri, berikut asal-usulnya.
///
/// [kotak] dibawa utuh supaya potongan ini tetap tahu dia sel yang mana —
/// tanpa itu, potongan berubah jadi tumpukan gambar tanpa nama dan nggak bisa
/// dipasangkan dengan angka yang diketik teknisi.
typedef PotonganSel = ({KotakSelFoto kotak, img.Image potongan});

/// Hasil satu kali pemotongan, berikut yang GAGAL dipotong.
///
/// Yang gagal dihitung, bukan dibuang diam-diam — alasan yang sama seperti
/// [HasilPetaTabel.kotakSelDibuang]: kalau angkanya nanti tinggi, yang salah
/// cara memotretnya, dan itu cuma ketahuan kalau ada yang menghitungnya.
typedef HasilPotongSel = ({List<PotonganSel> potongan, int gagal});

/// Ubah kotak sel jadi citra sel — bahan mentah model pengenal angka sendiri.
///
/// ## Kenapa ini terpisah dari `PindaiLembar.potongSel`
///
/// Repo ini sudah punya pemotong sel, dan dia dipakai jalur pindai bermarker.
/// Yang ini BUKAN penggantinya, dan bukan juga salinannya — dua-duanya memotong
/// sel, tapi dari dunia yang beda, dan dua bedanya menentukan:
///
/// | | `PindaiLembar.potongSel` | di sini |
/// |---|---|---|
/// | sumbernya | citra yang sudah DIRATAKAN lewat marker | foto apa adanya |
/// | kotaknya dari | template lembar, koordinat pasti | jangkar yang kebaca OCR |
/// | margin | +6%, biar garis tabel nggak ikut | **nol** |
/// | kotak di luar citra | dijepit masuk (`clamp`) | **dibuang** |
///
/// **Margin nol** karena penyusutannya sudah terjadi di hulu:
/// [PetaTabelFoto] sudah mengecilkan tiap kotak jadi 0,8 petak lewat
/// `_rapatKotak`, dengan alasan yang persis sama (garis tabel dan ekor angka
/// tetangga itu derau). Ditambah 6% lagi di sini, potongannya menyusut dua
/// kali dan angkanya sendiri yang kepotong.
///
/// **Dibuang, bukan dijepit**, karena artinya beda. Di jalur bermarker,
/// koordinatnya datang dari template yang sudah pasti benar, jadi kotak yang
/// keluar sedikit itu ketidaksempurnaan perataan — dijepit masuk masih
/// menghasilkan sel yang benar. Di sini koordinatnya turunan dari jangkar yang
/// kebaca; kotak yang keluar citra berarti selnya memang di tepi foto.
/// Dijepit, yang keluar bukan potongan sel itu — melainkan potongan yang
/// bergeser, isinya sebagian sel tetangga, dan dia tetap dilabeli angka sel
/// ini. Itu contoh latih yang bohong, dan model yang dilatih dengan bohong
/// salah dengan percaya diri.
///
/// ## Apa yang TIDAK dilakukan di sini
///
/// Nggak ada citra yang keluar dari HP. Kelas ini cuma memotong; yang
/// menyimpan [SimpananContohSel], dan simpanannya pun lokal. Ekspor keluar
/// perangkat butuh keputusan eksplisit pemilik lab dan belum dibangun sama
/// sekali — lihat `.claude/skills/sidik-fe-ocr-privasi-audit`.
class PotongSelFoto {
  const PotongSelFoto();

  /// Potong tiap kotak di [kotak] dari [citra].
  ///
  /// Yang kotaknya nggak muat utuh di dalam [citra], atau yang ukurannya
  /// menyusut jadi nol, nggak ikut dipulangkan dan dihitung di `gagal`.
  HasilPotongSel potong({
    required img.Image citra,
    required List<KotakSelFoto> kotak,
  }) {
    final hasil = <PotonganSel>[];
    var gagal = 0;

    for (final k in kotak) {
      final kiri = k.kotak.left.round();
      final atas = k.kotak.top.round();
      final lebar = k.kotak.width.round();
      final tinggi = k.kotak.height.round();

      // Dibulatkan dulu BARU diperiksa, bukan sebaliknya: kotak yang tepinya
      // pas di batas bisa jatuh keluar setelah dibulatkan, dan `copyCrop`
      // dengan lebar yang melewati tepi memulangkan potongan yang isinya
      // bukan sel itu lagi.
      if (lebar <= 0 ||
          tinggi <= 0 ||
          kiri < 0 ||
          atas < 0 ||
          kiri + lebar > citra.width ||
          atas + tinggi > citra.height) {
        gagal++;
        continue;
      }

      hasil.add((
        kotak: k,
        potongan: img.copyCrop(
          citra,
          x: kiri,
          y: atas,
          width: lebar,
          height: tinggi,
        ),
      ));
    }

    return (potongan: hasil, gagal: gagal);
  }
}
