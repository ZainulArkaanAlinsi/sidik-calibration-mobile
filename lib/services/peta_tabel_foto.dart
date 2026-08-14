import 'pembaca_halaman.dart';

/// Satu angka hasil foto tabel, sudah ketahuan tempatnya.
typedef SelTabelFoto = ({
  double titikUkur,
  int repeatNo,
  String fieldId,
  String teks,
});

/// Hasil memetakan foto satu tabel.
class HasilPetaTabel {
  const HasilPetaTabel({
    required this.sel,
    required this.titikKetemu,
    required this.repeatKetemu,
    required this.angkaTakTerpetakan,
  });

  final List<SelTabelFoto> sel;

  /// Nilai standar yang jangkarnya ketemu di foto. Kalau ini kosong, seluruh
  /// foto **tidak dipetakan sama sekali** — bukan dipetakan sebagian.
  final List<double> titikKetemu;

  /// Nomor Repeat yang kepala kolomnya (`X1`..`Xn`) ketemu di foto.
  final List<int> repeatKetemu;

  /// Angka yang kebaca tapi nggak ketemu baris/kolomnya. **Dibuang, bukan
  /// dipaksa masuk** — dan jumlahnya dilaporkan supaya teknisi tahu ada yang
  /// nggak keangkut, bukan mengira tabelnya memang segitu.
  final int angkaTakTerpetakan;

  bool get kosong => sel.isEmpty;
}

/// Foto satu tabel → angka per sel, **tanpa menebak dari urutan**.
///
/// ## Kenapa ini boleh ada, padahal jalur bermarker dirancang justru buat
/// menghindari OCR sehalaman
///
/// Yang dilarang bukan "membaca sehalaman", tapi **menentukan posisi dari
/// urutan**: OCR halaman penuh memberi daftar teks, lalu ada yang menebak teks
/// ke-3 masuk kolom ke-3. Itu sumber bug "angka pindah baris", dan tebakan itu
/// nggak pernah ngasih gejala waktu salah.
///
/// Di sini posisinya **dikunci tinta yang tercetak di tabelnya sendiri**:
///
///  - **baris** dikenali dari kolom nilai standar (`279,6`, `4,00`, `1,412`).
///    Angkanya sudah kita tahu dari bentuk lembar, jadi yang dicocokkan bukan
///    urutan tapi NILAINYA. Baris yang nilai standarnya nggak kebaca nggak
///    pernah keisi.
///  - **kolom** dikenali dari kepala `X1`..`Xn` yang tercetak. Kolom yang
///    kepalanya nggak kebaca nggak pernah keisi.
///
/// Jadi tiap angka harus punya DUA jangkar sebelum ditaruh. Yang cuma punya
/// satu, atau nggak punya sama sekali, dibuang — dan ikut kehitung di
/// [HasilPetaTabel.angkaTakTerpetakan].
///
/// **Nggak ada aturan angka di sini.** Teks dikirim apa adanya ke kotak isian;
/// yang memutuskan itu angka wajar atau bukan tetap mata teknisi (dan backend
/// waktu sesinya dihitung). Kelas ini cuma menjawab satu pertanyaan: angka ini
/// tempatnya di mana.
class PetaTabelFoto {
  const PetaTabelFoto();

  /// Seberapa jauh nilai yang kebaca boleh meleset dari nilai standar sebelum
  /// dianggap BUKAN jangkar baris itu.
  ///
  /// Relatif, bukan absolut: titiknya berkisar dari 1,412 sampai 12880, dan
  /// selisih absolut yang wajar di satu ujung ngawur di ujung lain.
  ///
  /// Sengaja sempit (0,5%). Ini bukan pencocokan "kira-kira" — nilai standar
  /// TERCETAK di kertas, jadi yang kebaca mestinya sama persis; toleransinya
  /// cuma buat menampung salah baca satu digit di belakang koma
  /// (`279,6` → `279,5`). Dilonggarkan, dua titik yang berdekatan
  /// (Spectrophotometer punya 453,6 & 460,0) bisa saling rebut.
  static const _toleransiTitik = 0.005;

  /// Setinggi apa satu baris dianggap masih baris yang sama, relatif terhadap
  /// jarak antar jangkar baris.
  ///
  /// Angka di baris ke-2 nggak pernah persis sejajar sama nilai standarnya —
  /// tinggi hurufnya beda, dan fotonya selalu agak miring. Setengah jarak
  /// antar baris itu batas alaminya: lewat dari situ, dia lebih dekat ke baris
  /// tetangga, dan menaruhnya di baris ini artinya menaruh di baris yang salah.
  static const _rasioBaris = 0.5;

  /// Petakan hasil OCR satu tabel.
  ///
  /// [titikUkur] & [pengulangan] datang dari bentuk lembar — bukan dari foto.
  /// [fieldPerRepeat] nama kolom di dalam tiap Repeat (`pembacaan`, `suhu`);
  /// kalau cuma satu, semua angka di bawah `Xn` masuk ke situ.
  HasilPetaTabel petakan({
    required List<TeksTerbaca> terbaca,
    required List<double> titikUkur,
    required List<int> pengulangan,
    required List<String> fieldPerRepeat,
    Map<String, String> labelField = const {},
  }) {
    final angka = <({double nilai, TeksTerbaca t})>[];

    for (final t in terbaca) {
      final n = _angka(t.teks);
      if (n != null) angka.add((nilai: n, t: t));
    }

    final jangkarBaris = _jangkarBaris(angka, titikUkur);

    // --- jangkar KOLOM: kepala `X1`..`Xn` yang tercetak --------------------
    final jangkarKolom = <int, TeksTerbaca>{};

    for (final r in pengulangan) {
      for (final t in terbaca) {
        if (_samaAbaikanBesarKecil(t.teks, 'X$r')) {
          jangkarKolom[r] = t;
          break;
        }
      }
    }

    if (jangkarBaris.isEmpty || jangkarKolom.isEmpty) {
      // Nggak ada satu pun jangkar = nggak ada dasar buat naruh angka mana pun.
      // Dikembalikan KOSONG, bukan dipetakan pakai urutan.
      return HasilPetaTabel(
        sel: const [],
        titikKetemu: jangkarBaris.keys.toList(),
        repeatKetemu: jangkarKolom.keys.toList(),
        angkaTakTerpetakan: angka.length,
      );
    }

    // --- jangkar FIELD di dalam satu Repeat --------------------------------
    //
    // Cuma perlu waktu satu Repeat punya lebih dari satu kolom (pembacaan &
    // suhu). Kepalanya tercetak juga (`Reading`, `°C`), jadi dicocokkan ke
    // labelnya — bukan dibagi rata dua.
    //
    // SEMUA kemunculannya dikumpulkan, bukan yang pertama saja: `pH` & `°C`
    // tercetak sekali per Repeat, jadi di lembar 5 Repeat ada lima pasang.
    // Dulu cuma pasangan pertama yang disimpan — akibatnya pembacaan Repeat 2
    // (yang x-nya jauh di kanan) lebih dekat ke `°C` Repeat 1 daripada ke
    // `pH` Repeat 1, dan mendarat di kolom suhu.
    final jangkarField = <({String field, TeksTerbaca t})>[];

    if (fieldPerRepeat.length > 1) {
      for (final f in fieldPerRepeat) {
        final label = labelField[f] ?? f;

        for (final t in terbaca) {
          if (_samaAbaikanBesarKecil(t.teks, label)) {
            jangkarField.add((field: f, t: t));
          }
        }
      }
    }

    final tinggiBaris = _jarakAntarBaris(jangkarBaris.values);

    // Batas kiri area PEMBACAAN. Semua yang di kirinya itu kolom label tabel —
    // nomor urut (`1`..`10`) dan nilai standar — dan dua-duanya angka yang sah.
    //
    // Mereka **bukan** "angka yang gagal dipetakan": mereka memang bukan
    // pembacaan. Dibedakan supaya laporan "ada yang nggak keangkut" tetap
    // berarti apa yang dia katakan; kalau nomor urut ikut kehitung, tiap foto
    // yang sempurna pun kelihatan seperti kehilangan sepuluh angka.
    final batasKiri = jangkarKolom.values
            .map((j) => j.kotak.left)
            .reduce((a, b) => a < b ? a : b) -
        tinggiBaris;

    final sel = <SelTabelFoto>[];
    var terbuang = 0;

    for (final a in angka) {
      if (a.t.kotak.center.dx < batasKiri) continue;

      final titik = _barisTerdekat(a.t, jangkarBaris, tinggiBaris);
      final repeat = _kolomTerdekat(a.t, jangkarKolom);

      if (titik == null || repeat == null) {
        terbuang++;
        continue;
      }

      final field = fieldPerRepeat.length == 1
          ? fieldPerRepeat.first
          : _fieldTerdekat(a.t, jangkarField);

      if (field == null) {
        terbuang++;
        continue;
      }

      sel.add((
        titikUkur: titik,
        repeatNo: repeat,
        fieldId: field,
        teks: a.t.teks,
      ));
    }

    // Satu sel nggak boleh keisi dua kali. Kalau ada dua angka yang jatuh ke
    // kotak yang sama, DUA-DUANYA dibuang: nggak ada dasar buat milih, dan
    // milih asal itu persis cara angka mendarat di tempat yang salah.
    final perKunci = <String, List<SelTabelFoto>>{};

    for (final s in sel) {
      perKunci
          .putIfAbsent('${s.titikUkur}|${s.repeatNo}|${s.fieldId}', () => [])
          .add(s);
    }

    final bersih = <SelTabelFoto>[];

    for (final e in perKunci.entries) {
      if (e.value.length == 1) {
        bersih.add(e.value.first);
      } else {
        terbuang += e.value.length;
      }
    }

    return HasilPetaTabel(
      sel: bersih,
      titikKetemu: jangkarBaris.keys.toList(),
      repeatKetemu: jangkarKolom.keys.toList(),
      angkaTakTerpetakan: terbuang,
    );
  }

  /// Jangkar baris: nilai standar yang TERCETAK di kolom kiri tabel.
  ///
  /// ## Kenapa nggak cukup "angka yang cocok ke titik ukur"
  ///
  /// Pembacaan alat memang selalu DEKAT nilai standarnya — itu justru tanda
  /// alatnya sehat. Di lembar spektro, titik `334,0` dibaca `333,74`: selisih
  /// 0,08%, jauh di dalam toleransi jangkar mana pun yang masih berguna.
  ///
  /// Jadi kalau tiap angka dinilai sendiri-sendiri, pembacaan bisa merebut
  /// peran jangkar barisnya sendiri. Yang lebih buruk: waktu nilai standarnya
  /// nggak kebaca OCR, pembacaan di kolom X1 diam-diam menggantikannya, dan
  /// seluruh baris itu jadi berjangkar pada angka yang justru mau diukur.
  ///
  /// Yang benar: jangkar diambil dari SATU KOLOM. Nilai standar berdiri di
  /// kolomnya sendiri, sejajar dari atas ke bawah, dan selalu di kiri kolom
  /// pembacaan. Kolom itu yang dicari — bukan angkanya satu per satu.
  ///
  /// @param angka semua angka yang kebaca, berikut kotaknya.
  Map<double, TeksTerbaca> _jangkarBaris(
    List<({double nilai, TeksTerbaca t})> angka,
    List<double> titikUkur,
  ) {
    // Semua angka yang NILAINYA cocok ke salah satu titik — calon jangkar,
    // termasuk pembacaan yang kebetulan mirip.
    final calon = <({double titik, TeksTerbaca t})>[];

    for (final a in angka) {
      for (final titik in titikUkur) {
        if ((a.nilai - titik).abs() <= titik.abs() * _toleransiTitik) {
          calon.add((titik: titik, t: a.t));
        }
      }
    }

    if (calon.isEmpty) return {};

    // Dikelompokkan per KOLOM: calon yang tepi kirinya berdekatan itu satu
    // kolom yang sama. Toleransinya lebar huruf, bukan lebar kolom — yang
    // disejajarkan tepi kiri tulisannya, dan tabel cetak selalu rata kiri di
    // dalam kolomnya.
    final lebarHuruf = calon.first.t.kotak.height;
    final kolom = <List<({double titik, TeksTerbaca t})>>[];

    for (final c in [...calon]..sort(
      (a, b) => a.t.kotak.left.compareTo(b.t.kotak.left),
    )) {
      final terakhir = kolom.isEmpty ? null : kolom.last;

      if (terakhir != null &&
          (c.t.kotak.left - terakhir.first.t.kotak.left).abs() <= lebarHuruf) {
        terakhir.add(c);
      } else {
        kolom.add([c]);
      }
    }

    // Kolom nilai standar = kolom PALING KIRI yang menaungi lebih dari satu
    // baris. Syarat "lebih dari satu" yang memisahkannya dari angka nyasar di
    // kolom label (nomor urut yang kebetulan cocok ke titik ukur bernilai
    // kecil); kalau lembarnya cuma punya satu titik, syarat itu nggak bisa
    // dipakai dan yang paling kiri langsung menang.
    final berjamaah = kolom.where((k) => k.length > 1);
    final pilih = berjamaah.isNotEmpty ? berjamaah.first : kolom.first;

    final hasil = <double, TeksTerbaca>{};

    for (final c in pilih) {
      // Satu titik nggak boleh punya dua jangkar. Yang paling atas menang —
      // urutan baris di kertas naik ke bawah, jadi yang di atas yang lebih
      // mungkin baris aslinya.
      final ada = hasil[c.titik];

      if (ada == null || c.t.kotak.top < ada.kotak.top) {
        hasil[c.titik] = c.t;
      }
    }

    return hasil;
  }

  /// Baris yang jangkarnya paling sejajar, atau `null` kalau nggak ada yang
  /// cukup dekat.
  double? _barisTerdekat(
    TeksTerbaca t,
    Map<double, TeksTerbaca> jangkar,
    double tinggiBaris,
  ) {
    final batas = tinggiBaris * _rasioBaris;
    double? terbaik;
    var jarakTerbaik = double.infinity;

    for (final e in jangkar.entries) {
      final jarak = (t.kotak.center.dy - e.value.kotak.center.dy).abs();

      if (jarak <= batas && jarak < jarakTerbaik) {
        terbaik = e.key;
        jarakTerbaik = jarak;
      }
    }

    return terbaik;
  }

  /// Repeat yang kepalanya paling segaris, atau `null` kalau angkanya jatuh di
  /// luar semua kolom.
  int? _kolomTerdekat(TeksTerbaca t, Map<int, TeksTerbaca> jangkar) {
    int? terbaik;
    var jarakTerbaik = double.infinity;

    for (final e in jangkar.entries) {
      // Lebar kolomnya sendiri nggak kita tahu — yang tercetak cuma kepalanya.
      // Jadi batasnya jarak ke kepala TERDEKAT: angka yang lebih dekat ke
      // kepala sebelah memang milik kolom sebelah.
      final jarak = (t.kotak.center.dx - e.value.kotak.center.dx).abs();

      if (jarak < jarakTerbaik) {
        terbaik = e.key;
        jarakTerbaik = jarak;
      }
    }

    return terbaik;
  }

  /// Kolom (field) yang kepalanya paling segaris.
  ///
  /// Dicari di antara SEMUA kepala yang tercetak — tiap Repeat punya
  /// pasangannya sendiri, dan yang menentukan pasangan mana yang paling dekat,
  /// bukan field mana yang kebetulan kebaca duluan.
  String? _fieldTerdekat(
    TeksTerbaca t,
    List<({String field, TeksTerbaca t})> jangkar,
  ) {
    if (jangkar.isEmpty) return null;

    String? terbaik;
    var jarakTerbaik = double.infinity;

    for (final j in jangkar) {
      final jarak = (t.kotak.center.dx - j.t.kotak.center.dx).abs();

      if (jarak < jarakTerbaik) {
        terbaik = j.field;
        jarakTerbaik = jarak;
      }
    }

    return terbaik;
  }

  /// Jarak khas antar baris, diukur dari jangkarnya sendiri.
  ///
  /// Diambil dari FOTO, bukan dipatok: tinggi baris di citra tergantung
  /// seberapa dekat HP waktu memotret, dan angka tetap bikin toleransinya
  /// terlalu longgar di foto dekat & terlalu ketat di foto jauh.
  double _jarakAntarBaris(Iterable<TeksTerbaca> jangkar) {
    final y = [for (final j in jangkar) j.kotak.center.dy]..sort();

    if (y.length < 2) {
      // Satu baris doang: pakai tinggi hurufnya sebagai ukuran.
      return jangkar.isEmpty ? 1 : jangkar.first.kotak.height * 2;
    }

    final jarak = [
      for (var i = 1; i < y.length; i++) y[i] - y[i - 1],
    ]..sort();

    // Median, bukan rata-rata: satu baris yang jangkarnya nggak kebaca bikin
    // jaraknya dobel, dan rata-rata ikut ketarik sama lompatan itu.
    return jarak[jarak.length ~/ 2];
  }

  /// Teks → angka, menerima koma maupun titik sebagai desimal.
  ///
  /// **Yang ada hurufnya BUKAN angka**, walau digitnya bisa dipungut. Dulu
  /// karakter non-digit dibuang dulu, dan akibatnya kepala kolom `X1` kebaca
  /// sebagai angka `1` — lalu ikut dicari-carikan tempat di dalam tabel, dan
  /// dilaporkan sebagai "3 angka nggak keangkut" di tiap foto yang sebenarnya
  /// sempurna. Yang lebih buruk: di tabel yang titik ukurnya kecil (`1,412`),
  /// `X1` bisa lolos jadi jangkar baris.
  ///
  /// **Nggak menyisipkan atau memindahkan koma.** `133659` tetap `133659` dan
  /// bakal gagal jadi jangkar mana pun — itu yang benar: yang salah baca harus
  /// kelihatan, bukan dibetulkan diam-diam sampai kelihatan wajar.
  static double? _angka(String teks) {
    final bersih = teks.trim();
    if (bersih.isEmpty) return null;
    if (!RegExp(r'^[0-9][0-9.,]*$|^-[0-9][0-9.,]*$').hasMatch(bersih)) {
      return null;
    }

    return double.tryParse(bersih.replaceAll(',', '.'));
  }

  static bool _samaAbaikanBesarKecil(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
