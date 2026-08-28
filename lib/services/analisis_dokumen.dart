import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'pembaca_halaman.dart';

/// Satu baris teks, hasil mengelompokkan kepingan OCR yang sebaris.
///
/// ML Kit memulangkan hasil per **ELEMENT** — kira-kira per kata. `Nama Alat :`
/// tidak pernah datang utuh; yang sampai potongan `Nama`, `Alat`, dan `:`.
/// Semua pemahaman dokumen di berkas ini berdiri di atas penyatuan itu.
typedef BarisDokumen = ({List<TeksTerbaca> elemen, Rect kotak, String teks});

/// Satu pasangan label → nilai yang terdeteksi di dokumen.
///
/// [keyakinan] diambil dari kepingan NILAI-nya saja, bukan labelnya: label itu
/// teks cetak yang hampir selalu terbaca benar, dan mencampurnya bikin
/// keyakinan pasangan kelihatan tinggi padahal yang penting — tulisan tangan
/// di sisi kanan — dibaca ragu-ragu.
typedef PasanganLabel = ({
  String label,
  String nilai,
  Rect kotakLabel,
  Rect kotakNilai,
  double? keyakinan,
});

/// Satu tabel yang terdeteksi dari susunan teksnya sendiri.
///
/// [kepala] boleh kosong: banyak lembar kerja menaruh tabel tanpa baris kepala,
/// dan tabel tanpa nama kolom tetap tabel. Yang menandainya keteraturan
/// kolomnya, bukan ada-tidaknya judul.
///
/// [baris] berukuran seragam sepanjang jumlah kolom. Sel yang tidak ada isinya
/// diisi string kosong **di posisinya**, bukan dilewat: sel yang digeser bikin
/// seluruh kolom sesudahnya meleset, dan itu kelas kesalahan yang paling mahal
/// di berkas ini — angkanya lengkap, tabelnya wajar, dan yang salah cuma kolom
/// mana yang dimaksud.
typedef TabelDokumen = ({
  List<String> kepala,
  List<List<String>> baris,
  List<double> pusatKolom,
  Rect kotak,
});

/// Membaca STRUKTUR dokumen dari kepingan OCR, tanpa tahu lembar apa yang
/// difoto.
///
/// ## Kenapa ini ada di samping `PetaTabelFoto`, bukan menggantikannya
///
/// `PetaTabelFoto` menempatkan angka ke dalam bentuk lembar yang **sudah
/// diketahui** — server mengirim titik ukur & kolomnya, kamera tinggal mengisi.
/// Itu yang bikin angkanya mendarat presisi di dua puluh lembar produksi, dan
/// itu tidak diganggu.
///
/// Yang di sini kebalikannya: **dokumennya yang menentukan bentuknya**. Dipakai
/// waktu lembar yang difoto tidak dikenal — belum punya profil, belum punya
/// geometri. Tanpa ini, lembar baru memulangkan nol dan satu-satunya jalan
/// keluar membuatkan parser baru per lembar, yang persis yang mau dihindari.
///
/// Hasilnya USULAN, sama seperti jalur foto lain: yang mendarat di data tetap
/// yang disetujui teknisi di layar review.
class AnalisisDokumen {
  const AnalisisDokumen();

  /// Seberapa besar tumpang tindih tegak dua kepingan supaya dianggap sebaris.
  ///
  /// Setengah tinggi huruf, angka yang sama dengan yang sudah dipakai
  /// `PetaTabelFoto` buat menggabungkan frasa. Fotonya selalu agak miring dan
  /// tinggi huruf antar-kata tidak pernah sama persis, jadi menuntut tumpang
  /// tindih penuh memecah satu baris jadi beberapa.
  static const _ambangSebaris = 0.5;

  /// Celah mendatar (dalam satuan tinggi huruf) yang memisahkan NILAI sebuah
  /// pasangan dari LABEL pasangan berikutnya di baris yang sama.
  ///
  /// Lembar kerja sering menaruh dua pasangan sebaris:
  /// `Merk : Fluke        Tipe : 87V`. Tanpa ambang ini, `Fluke Tipe` terbaca
  /// jadi satu nilai. Dua kali tinggi huruf: lebih besar dari spasi antar-kata
  /// biasa (sekitar ⅓ tinggi huruf), lebih kecil dari jarak antar-kolom yang
  /// sengaja direnggangkan pembuat lembar.
  static const _celahPisah = 2.0;

  /// Kelompokkan kepingan OCR jadi baris, urut atas→bawah lalu kiri→kanan.
  ///
  /// Kepingan yang kotaknya kosong (lebar atau tinggi nol) dibuang: dia tidak
  /// bisa diukur tumpang tindihnya, dan membiarkannya masuk bikin satu baris
  /// menelan seluruh halaman.
  List<BarisDokumen> kelompokkanBaris(List<TeksTerbaca> terbaca) {
    final sah = [
      for (final t in terbaca)
        if (t.kotak.height > 0 && t.kotak.width > 0 && t.teks.trim().isNotEmpty)
          t,
    ]..sort((a, b) => a.kotak.top.compareTo(b.kotak.top));

    final baris = <List<TeksTerbaca>>[];

    for (final t in sah) {
      final ketemu = baris.firstWhere(
        (b) => _sebaris(b, t),
        orElse: () => <TeksTerbaca>[],
      );

      if (ketemu.isEmpty) {
        baris.add([t]);
      } else {
        ketemu.add(t);
      }
    }

    return [
      for (final b in baris..sort((x, y) => _atas(x).compareTo(_atas(y))))
        _rakit(b..sort((a, c) => a.kotak.left.compareTo(c.kotak.left))),
    ];
  }

  /// Cari pasangan label → nilai di dalam baris-baris dokumen.
  ///
  /// Yang dicari titik dua. Lembar kerja lab menulis `Nama Alat :`, `Merk :`,
  /// `Serial Number :` — dan titik dua itu satu-satunya penanda yang muncul di
  /// semua lembar apa pun bentuknya. Label tanpa titik dua (mis. kepala kolom
  /// tabel) SENGAJA tidak diambil di sini; itu urusan pendeteksi tabel.
  ///
  /// Pasangan yang nilainya kosong tetap dipulangkan dengan [nilai] kosong —
  /// kolom yang belum diisi teknisi itu keterangan yang berguna, bukan
  /// ketiadaan. Yang menyaringnya pemanggil, bukan di sini.
  List<PasanganLabel> deteksiPasangan(List<BarisDokumen> baris) {
    final hasil = <PasanganLabel>[];

    for (final b in baris) {
      final tinggi = _tinggiTengah(b.elemen);
      var mulai = 0;

      for (var i = 0; i < b.elemen.length; i++) {
        if (!_titikDua(b.elemen[i].teks)) continue;

        // Label = kepingan dari akhir pasangan sebelumnya sampai titik dua ini.
        //
        // Kepingan bertitik dua itu sendiri IKUT kalau dia membawa teks lain
        // (`Number:`), dan TIDAK ikut kalau dia cuma titik dua berdiri sendiri
        // (`:`). Dibuang dua-duanya, `Serial Number :` yang tercetak rapat
        // kehilangan kata terakhirnya dan labelnya jadi `Serial` — pasangan
        // yang salah nama, bukan pasangan yang hilang, jadi nggak ada yang
        // kelihatan gagal.
        final sendirian = b.elemen[i].teks.trim() == ':';
        final label = b.elemen.sublist(mulai, sendirian ? i : i + 1);

        if (label.isEmpty) {
          mulai = i + 1;
          continue;
        }

        // Nilai = kepingan sesudah titik dua, berhenti di celah lebar (awal
        // pasangan berikutnya) atau di titik dua berikutnya.
        final nilai = <TeksTerbaca>[];

        for (var j = i + 1; j < b.elemen.length; j++) {
          if (_titikDua(b.elemen[j].teks)) break;

          if (nilai.isNotEmpty) {
            final celah = b.elemen[j].kotak.left - nilai.last.kotak.right;
            if (celah > tinggi * _celahPisah) break;
          }

          nilai.add(b.elemen[j]);
        }

        hasil.add((
          label: _gabung(label).replaceAll(RegExp(r'\s*:\s*$'), '').trim(),
          nilai: _gabung(nilai),
          kotakLabel: _kotak(label),
          kotakNilai: nilai.isEmpty ? Rect.zero : _kotak(nilai),
          keyakinan: _keyakinanTerendah(nilai),
        ));

        mulai = i + 1 + nilai.length;
        i = mulai - 1;
      }
    }

    return hasil;
  }

  /// Cari tabel dari **keteraturan kolomnya**, bukan dari garis kotaknya.
  ///
  /// ## Kenapa bukan garis
  ///
  /// Banyak lembar kerja mencetak tabel tanpa garis penuh, dan yang bergaris
  /// pun garisnya sering tidak terbaca OCR (dia pengenal TEKS). Yang selalu ada
  /// justru **kolom yang berulang di beberapa baris berturut-turut** — dan itu
  /// yang dicari di sini.
  ///
  /// Aturannya: baris-baris yang berdekatan tegak, sama-sama punya minimal
  /// [minKolom] kepingan, dan kepingannya jatuh di sekitar posisi mendatar yang
  /// sama. Deret sepanjang minimal [minBaris] dianggap tabel.
  ///
  /// Yang SENGAJA tidak dilakukan di sini: menebak arti kolomnya. Kepala kolom
  /// dipulangkan apa adanya kalau ada, dan yang memutuskan `Standard` itu
  /// artinya apa bukan berkas ini — di sini cuma bentuknya.
  List<TabelDokumen> deteksiTabel(
    List<BarisDokumen> baris, {
    int minKolom = 2,
    int minBaris = 2,
  }) {
    final hasil = <TabelDokumen>[];
    var i = 0;

    while (i < baris.length) {
      if (baris[i].elemen.length < minKolom) {
        i++;
        continue;
      }

      // Kolom dipatok dari baris pertama deret ini sebagai RENTANG mendatar,
      // bukan titik pusat. Sel berisi dua kata (`PT Gracia`) punya kata kedua
      // yang pusatnya melenceng jauh dari pusat kolom — diadu ke titik, baris
      // itu ditolak seluruhnya dan tabelnya hilang tanpa jejak.
      //
      // Dipatok dari baris pertama saja, bukan dihitung ulang tiap baris:
      // tabel yang satu selnya kosong menggeser kolomnya dan deretnya putus.
      final pusat = [
        for (final e in baris[i].elemen) (e.kotak.left, e.kotak.right),
      ];
      final tinggi = _tinggiTengah(baris[i].elemen);

      final deret = <BarisDokumen>[baris[i]];
      var j = i + 1;

      while (j < baris.length && _cocokKolom(baris[j], pusat, tinggi)) {
        deret.add(baris[j]);
        j++;
      }

      if (deret.length >= minBaris) {
        hasil.add(_rakitTabel(deret, pusat));
        i = j;
      } else {
        i++;
      }
    }

    return hasil;
  }

  /// Baris ini jatuh di kolom yang sama?
  ///
  /// Tidak menuntut SEMUA kolom terisi — sel kosong di tengah tabel itu hal
  /// biasa di lembar yang belum selesai diisi. Yang dituntut: tiap kepingan
  /// yang ADA harus dekat ke salah satu kolom, dan minimal separuh kolomnya
  /// kena. Menuntut semuanya bikin deretnya putus di baris pertama yang
  /// selnya bolong.
  bool _cocokKolom(
    BarisDokumen b,
    List<(double, double)> pusat,
    double tinggi,
  ) {
    if (b.elemen.isEmpty) return false;

    final kena = <int>{};

    for (final e in b.elemen) {
      final k = _kolomTerdekat(e.kotak, pusat, tinggi);
      if (k == null) return false;
      kena.add(k);
    }

    return kena.length * 2 >= pusat.length;
  }

  /// Kolom terdekat, atau null kalau tidak ada yang cukup dekat.
  ///
  /// Toleransinya dua kali tinggi huruf: cukup longgar buat angka yang
  /// panjangnya beda-beda (`4,01` vs `120,45` tidak pernah persis sepusat),
  /// cukup ketat buat tidak menelan kolom sebelah.
  int? _kolomTerdekat(Rect kotak, List<(double, double)> pusat, double tinggi) {
    // Bertumpang tindih mendatar menang duluan: itu bukti paling kuat bahwa
    // kepingan ini memang di kolom itu, dan dia yang bikin sel berisi dua kata
    // tetap utuh.
    for (var k = 0; k < pusat.length; k++) {
      if (kotak.right >= pusat[k].$1 && kotak.left <= pusat[k].$2) return k;
    }

    // Nggak bertumpang tindih — jatuh ke jarak ke tepi kolom terdekat.
    // Toleransinya dua kali tinggi huruf: cukup longgar buat angka yang
    // panjangnya beda-beda, cukup ketat buat nggak menelan kolom sebelah.
    var terdekat = -1;
    var jarak = double.infinity;

    for (var k = 0; k < pusat.length; k++) {
      final d = math.min(
        (pusat[k].$1 - kotak.right).abs(),
        (pusat[k].$2 - kotak.left).abs(),
      );

      if (d < jarak) {
        jarak = d;
        terdekat = k;
      }
    }

    return jarak <= tinggi * 2 ? terdekat : null;
  }

  TabelDokumen _rakitTabel(
    List<BarisDokumen> deret,
    List<(double, double)> pusat,
  ) {
    final tinggi = _tinggiTengah(deret.first.elemen);

    List<String> selBaris(BarisDokumen b) {
      final sel = List.filled(pusat.length, '');

      for (final e in b.elemen) {
        final k = _kolomTerdekat(e.kotak, pusat, tinggi);
        if (k == null) continue;

        // Digabung, bukan ditimpa: dua kata di satu sel (`PT Gracia`) datang
        // sebagai dua kepingan, dan yang belakangan menimpa yang duluan bikin
        // selnya kehilangan separuh isinya tanpa ada yang kelihatan hilang.
        sel[k] = sel[k].isEmpty ? e.teks.trim() : '${sel[k]} ${e.teks.trim()}';
      }

      return sel;
    }

    // Baris pertama dianggap KEPALA cuma kalau tidak satu pun selnya angka.
    // Tabel yang langsung mulai dari data (lembar tanpa baris kepala) tidak
    // boleh kehilangan baris pertamanya jadi "judul".
    final pertama = selBaris(deret.first);
    final kepala = pertama.every((s) => s.isEmpty || !_miripAngka(s))
        ? pertama
        : <String>[];

    return (
      kepala: kepala,
      baris: [
        for (final b in kepala.isEmpty ? deret : deret.skip(1)) selBaris(b),
      ],
      pusatKolom: [for (final r in pusat) (r.$1 + r.$2) / 2],
      kotak: deret
          .map((b) => b.kotak)
          .reduce((a, c) => a.expandToInclude(c)),
    );
  }

  /// Teks ini terbaca sebagai angka?
  ///
  /// Koma DAN titik dua-duanya dianggap pemisah desimal: lembar kerja lab
  /// dicetak dengan koma (`4,01`), tapi teknisi kadang menulis titik, dan OCR
  /// juga sering menukar keduanya. Yang dijawab di sini cuma "ini angka atau
  /// bukan" — mengubahnya jadi `double` urusan pemanggil.
  bool _miripAngka(String s) =>
      RegExp(r'^[-+]?\d+([.,]\d+)?$').hasMatch(s.trim());

  bool _sebaris(List<TeksTerbaca> baris, TeksTerbaca t) {
    final tinggi = math.min(_tinggiTengah(baris), t.kotak.height);
    final atas = math.max(_atas(baris), t.kotak.top);
    final bawah = math.min(_bawah(baris), t.kotak.bottom);

    return (bawah - atas) > tinggi * _ambangSebaris;
  }

  double _atas(List<TeksTerbaca> b) =>
      b.map((t) => t.kotak.top).reduce(math.min);

  double _bawah(List<TeksTerbaca> b) =>
      b.map((t) => t.kotak.bottom).reduce(math.max);

  /// Tinggi TENGAH, bukan rata-rata: satu kepingan yang kotaknya kacau (huruf
  /// besar judul yang nyelip, atau garis tabel yang kebaca jadi teks) menarik
  /// rata-rata cukup jauh untuk mengubah pengelompokan seluruh baris.
  double _tinggiTengah(List<TeksTerbaca> b) {
    final t = [for (final e in b) e.kotak.height]..sort();
    return t.isEmpty ? 0 : t[t.length ~/ 2];
  }

  BarisDokumen _rakit(List<TeksTerbaca> b) =>
      (elemen: b, kotak: _kotak(b), teks: _gabung(b));

  Rect _kotak(List<TeksTerbaca> b) => b.isEmpty
      ? Rect.zero
      : b.map((t) => t.kotak).reduce((a, c) => a.expandToInclude(c));

  String _gabung(List<TeksTerbaca> b) =>
      b.map((t) => t.teks.trim()).where((s) => s.isNotEmpty).join(' ').trim();

  /// Titik dua bisa datang sebagai kepingan sendiri (`:`) atau menempel di
  /// ekor kata (`Alat:`). Dua-duanya harus dikenali — mana yang terjadi
  /// tergantung jarak cetaknya, dan itu berbeda per lembar.
  bool _titikDua(String teks) => teks.trim().endsWith(':');

  /// Keyakinan pasangan = yang TERENDAH di antara kepingan nilainya.
  ///
  /// Nilai `25,4` yang separuh kepingannya dibaca ragu tetap nilai yang ragu.
  /// Kalau ada satu saja kepingan yang keyakinannya tidak dilaporkan, seluruh
  /// pasangan dianggap tidak diketahui — bukan diambil dari kepingan yang
  /// kebetulan punya angka.
  double? _keyakinanTerendah(List<TeksTerbaca> b) {
    if (b.isEmpty) return null;

    var terendah = double.infinity;

    for (final t in b) {
      if (t.keyakinan == null) return null;
      terendah = math.min(terendah, t.keyakinan!);
    }

    return terendah;
  }
}
