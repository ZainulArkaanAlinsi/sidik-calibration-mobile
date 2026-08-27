import 'dart:ui' show Rect;

import 'pembaca_halaman.dart';

/// Satu angka hasil foto tabel, sudah ketahuan tempatnya.
typedef SelTabelFoto = ({
  double titikUkur,
  int repeatNo,
  String fieldId,
  String teks,
});

/// Satu slot larutan seperti TERCETAK di kepala tabel bentuk ke-bawah.
///
/// Tulisan kertas dipisah dari titik yang dihitung karena di lembar
/// Conductivity dua-duanya beda: kertas `Rev.5` masih nulis nominal botol lama
/// (`84 / 1413 / 5000 / 80000`), master pindah ke `25 / 1412 / 111` pada April
/// 2024. Yang dicari di foto tulisan kertasnya; yang jadi tujuan angkanya
/// [titikUkur].
typedef SlotFoto = ({
  /// Titik yang dituju angka di kolom ini. **Null = slot mati** — kotaknya ada
  /// di kertas, larutannya belum kedaftar di master.
  double? titikUkur,

  /// Tulisan kepala slot yang TERCETAK. Boleh lebih dari satu kalau kertasnya
  /// nyetak dua varian satuan berdampingan (`1413 µS` / `1.413 mS`).
  List<String> kepala,

  /// Label satuan yang tercetak di bawah kepala slot, per kolom:
  /// `{'pembacaan': 'µS/cm', 'suhu': '°C'}`. Satu isi = seluruh angka di kolom
  /// ini masuk ke field itu tanpa perlu jangkar tambahan.
  Map<String, String> labelField,
});

/// Hasil memetakan foto satu tabel.
class HasilPetaTabel {
  const HasilPetaTabel({
    required this.sel,
    required this.titikKetemu,
    required this.repeatKetemu,
    required this.angkaTakTerpetakan,
    this.labelKolomKurang = const [],
    this.barisKembar = const [],
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

  /// Label sub-kolom di dalam satu Repeat (`cP`, `°C`) yang NGGAK kebaca di
  /// foto. Selama ada isinya, seluruh tabel sengaja nggak dipetakan — lihat
  /// alasannya di [PetaTabelFoto.petakan]. Dilaporkan supaya pesan ke teknisi
  /// bisa nyebut yang hilang, bukan nyuruh dia nebak.
  final List<String> labelKolomKurang;

  /// Nilai jangkar baris yang muncul lebih dari sekali di bentuk tabelnya.
  ///
  /// Selama ada isinya, seluruh tabel sengaja nggak dipetakan — lihat
  /// alasannya di [PetaTabelFoto._titikKembar]. Dilaporkan terpisah dari
  /// jangkar yang kepotong karena sebabnya beda: yang ini nggak bisa
  /// dibetulkan dengan jepretan ulang.
  final List<double> barisKembar;

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

  /// Nilai jangkar baris yang muncul lebih dari sekali di `titikUkur`.
  ///
  /// Jangkar baris disimpan berkunci nilainya (`Map<double, TeksTerbaca>`),
  /// jadi titik kembar runtuh jadi SATU baris: angka yang mestinya jatuh ke
  /// delapan baris beda semuanya ngaku baris yang sama, dan sisanya dibuang.
  ///
  /// Bentuk begitu ada beneran — lembar Autoclave (`SIDIK-FM-CAL-0539`)
  /// barisnya berlabel kata (`Time`, `Temp. Disk 1`), dan `titik_ukur`-nya nol
  /// semua sebagai pengisi.
  ///
  /// Ini nggak bisa dibetulin sama jepretan ulang, dan kalau dibiarkan jalan
  /// hasilnya bukan "gagal" tapi "sebagian angka mendarat di baris yang
  /// salah" — persis kegagalan tanpa gejala yang dicegah seluruh berkas ini.
  static List<double> _titikKembar(List<double> titikUkur) {
    final hitung = <double, int>{};

    for (final t in titikUkur) {
      hitung[t] = (hitung[t] ?? 0) + 1;
    }

    return [
      for (final e in hitung.entries)
        if (e.value > 1) e.key,
    ];
  }

  /// Setinggi apa satu baris dianggap masih baris yang sama, relatif terhadap
  /// jarak antar jangkar baris.
  ///
  /// Angka di baris ke-2 nggak pernah persis sejajar sama nilai standarnya —
  /// tinggi hurufnya beda, dan fotonya selalu agak miring. Setengah jarak
  /// antar baris itu batas alaminya: lewat dari situ, dia lebih dekat ke baris
  /// tetangga, dan menaruhnya di baris ini artinya menaruh di baris yang salah.
  static const _rasioBaris = 0.5;

  /// Kepala kolom pengulangan yang TERCETAK, kalau pemanggilnya nggak nyebut.
  ///
  /// Dua bentuk diterima sekaligus, dan itu bukan tebakan yang dibiarin
  /// menggantung: `Xn` yang dicetak `php artisan ocr:cetak-lembar`, dan
  /// `Repeat n` yang digambar layar waktu `prefiks_pengulangan` kosong. Formulir
  /// lama lab pakai salah satunya, dan menerima dua-duanya **nggak bisa bikin
  /// salah taruh**: dua-duanya tulisan yang cuma muncul di kepala kolom, jadi
  /// nggak ada sel isian yang bisa nyamar jadi salah satunya.
  ///
  /// **Nomor polos (`1`) sengaja NGGAK ikut.** Di kertas yang kepala kolomnya
  /// cuma nomor, `1` juga bisa jadi pembacaan, nomor urut baris, atau bagian
  /// dari nilai standar — dan jangkar yang salah rebut itu persis cara angka
  /// mendarat di baris yang salah tanpa ngasih gejala. Kalau ternyata kertasnya
  /// begitu, yang benar nambah jangkar lain (kata `Repeat` di kepala kolomnya),
  /// bukan melonggarkan yang ini.
  static List<String> kepalaBawaan(int repeat) => [
    'X$repeat',
    'Repeat $repeat',
  ];

  /// Nomor baris yang KEBACA dari kolom paling kiri.
  ///
  /// ## Kenapa ada jalur yang menemukan penanda barisnya sendiri
  ///
  /// Di sepuluh lembar pertama, penanda baris sudah diketahui sebelum fotonya
  /// dibaca — nilai standar yang tercetak di kertas, dan kita punya daftarnya
  /// dari bentuk lembar. Grid Enclosure tidak: yang ada di kolom kiri **nomor
  /// termokopel yang ditulis tangan teknisi di chamber**, dan berapa saja
  /// nomornya baru ketahuan dari kertas itu sendiri.
  ///
  /// Pemilik lab memutuskan urutan kerjanya **motret dulu, nomornya belakangan**
  /// (27 Agt 2026), jadi mencocokkan ke nomor yang sudah ada di layar bukan
  /// pilihan: waktu tombolnya ditekan, layarnya memang masih kosong.
  ///
  /// ## Risikonya, dan kenapa dia bisa ditanggung
  ///
  /// Nomor yang salah baca (7 kebaca 1) memindahkan SELURUH baris ke termokopel
  /// yang salah — dan nomor itu yang menentukan koreksi mana yang dipakai. Yang
  /// bikin ini bisa ditanggung: **nomornya ikut ditaruh di kotaknya sendiri dan
  /// ikut ditandai kuning**, jadi dia kelihatan dan bisa dibetulkan di satu
  /// tempat. Membetulkan nomornya memindahkan barisnya utuh — pembacaannya
  /// tetap menempel di baris yang sama seperti di kertas.
  ///
  /// Itu sebabnya barisnya dikenali dari POSISI di citra, bukan dari nomornya:
  /// yang dijamin utuh kebersamaan satu baris, bukan ketepatan nomornya.
  ///
  /// ## Yang bikin kolomnya nggak salah tebak
  ///
  ///  - Cuma bilangan BULAT yang dihitung. Pembacaan chamber berkoma
  ///    (`121,5`), jadi dia nggak pernah masuk daftar calon.
  ///  - Dikelompokkan per KOLOM lewat tepi kiri, lalu yang dipakai kolom
  ///    **paling kiri yang menaungi lebih dari satu baris**. Kepala kolom
  ///    pengulangan (`1`..`5`) berjajar MENDATAR, jadi tiap nomornya jatuh di
  ///    kolomnya sendiri-sendiri dan nggak pernah punya anggota kedua.
  ///  - Di luar [batasNomor] dibuang: nomor termokopel lab ini paling banyak
  ///    dua digit (`TCN3`..`TCN12`), dan angka bulat besar di kolom kiri jauh
  ///    lebih mungkin pembacaan yang kebetulan bulat.
  ///
  /// Balik daftar nomornya URUT DARI ATAS, apa adanya — termasuk kalau ada yang
  /// kembar. Yang memutuskan apa yang dilakukan atas kembar itu pemanggilnya;
  /// di sini nggak ada yang dibuang diam-diam.
  List<int> nomorBarisTerbaca(List<TeksTerbaca> terbaca) {
    final calon = <({int no, TeksTerbaca t})>[];

    for (final t in terbaca) {
      final n = int.tryParse(t.teks.trim());

      if (n == null || n < 1 || n > batasNomor) continue;

      calon.add((no: n, t: t));
    }

    if (calon.length < 2) return const [];

    final tinggi = calon
        .map((c) => c.t.kotak.height)
        .reduce((a, b) => a > b ? a : b);

    final kolom = <List<({int no, TeksTerbaca t})>>[];

    for (final c in [...calon]..sort(
      (a, b) => a.t.kotak.left.compareTo(b.t.kotak.left),
    )) {
      final terakhir = kolom.isEmpty ? null : kolom.last;

      if (terakhir != null &&
          (c.t.kotak.left - terakhir.first.t.kotak.left).abs() <= tinggi) {
        terakhir.add(c);
      } else {
        kolom.add([c]);
      }
    }

    final berjamaah = kolom.where((k) => k.length > 1).toList();

    if (berjamaah.isEmpty) return const [];

    final pilih = berjamaah.first
      ..sort((a, b) => a.t.kotak.top.compareTo(b.t.kotak.top));

    return [for (final c in pilih) c.no];
  }

  /// Nomor baris terbesar yang masih masuk akal — lihat [nomorBarisTerbaca].
  static const batasNomor = 99;

  /// Petakan hasil OCR satu tabel.
  ///
  /// [titikUkur] & [pengulangan] datang dari bentuk lembar — bukan dari foto.
  /// [fieldPerRepeat] nama kolom di dalam tiap Repeat (`pembacaan`, `suhu`);
  /// kalau cuma satu, semua angka di bawah `Xn` masuk ke situ.
  /// [kepalaPengulangan] tulisan kepala kolom yang TERCETAK per nomor Repeat;
  /// kosong = pakai [kepalaBawaan].
  HasilPetaTabel petakan({
    required List<TeksTerbaca> terbaca,
    required List<double> titikUkur,
    required List<int> pengulangan,
    required List<String> fieldPerRepeat,
    Map<String, String> labelField = const {},
    Map<int, List<String>> kepalaPengulangan = const {},
    // Tulisan kepala baris yang TERCETAK, kalau beda dari `titikUkur`.
    //
    // Viscometer yang bikin ini perlu: kertasnya nyetak label larutan bulat
    // ("100"/"1000"/"60000"), sementara titik yang dihitung nilai sertifikat
    // (99,65/1018/59003) — beda sampai 1,8%, jauh di luar [_toleransiTitik].
    // Baris begini nggak akan PERNAH kejangkar lewat angka, sebagus apa pun
    // fotonya. Diberi tulisan aslinya di sini, dicocokkan sebagai TEKS persis
    // kayak jangkar kolom `Xn` — bukan dilonggarkan toleransinya (itu yang
    // bikin 453,6 & 460,0 di lembar spektro bisa saling rebut).
    Map<double, String> labelTercetak = const {},
  }) {
    final kembar = _titikKembar(titikUkur);

    if (kembar.isNotEmpty) {
      // Bentuk tabelnya sendiri yang nggak bisa dipetakan — lihat
      // [_titikKembar]. Ditolak SEBELUM baca apa pun, biar sebabnya nunjuk ke
      // bentuk lembarnya, bukan ke kualitas fotonya.
      return HasilPetaTabel(
        sel: const [],
        titikKetemu: const [],
        repeatKetemu: const [],
        angkaTakTerpetakan: 0,
        barisKembar: kembar,
      );
    }

    final angka = <({double nilai, TeksTerbaca t})>[];

    for (final t in terbaca) {
      final n = _angka(t.teks);
      if (n != null) angka.add((nilai: n, t: t));
    }

    final jangkarBaris = _jangkarBaris(terbaca, titikUkur, labelTercetak);

    // --- jangkar KOLOM: kepala `X1`..`Xn` yang tercetak --------------------
    var jangkarKolom = _jangkarTeks(
      terbaca,
      {for (final r in pengulangan) r: kepalaPengulangan[r] ?? kepalaBawaan(r)},
    );

    // Kertas yang kepala kolomnya NOMOR POLOS (`1`..`5`), bukan `X1`/`Repeat 1`.
    //
    // Formulir Viscometer Rev.3 begitu — `UUT Reading` di atas, lalu deretan
    // 1..5 polos di bawahnya — dan lima lembar lain juga nggak ngirim
    // `prefiks_pengulangan`. Tanpa jalur ini kepala kolomnya NGGAK PERNAH
    // ketemu, jadi nol sel di tiap jepretan sesempurna apa pun fotonya.
    //
    // Nomor polos tetap nggak diterima satu-satu (lihat [kepalaBawaan]) —
    // yang diterima cuma DERETNYA UTUH, dan syaratnya di [_jangkarNomorPolos]
    // dibikin supaya pembacaan nggak bisa menyamar jadi deret itu.
    if (jangkarKolom.length < pengulangan.length) {
      final deret = _jangkarNomorPolos(terbaca, pengulangan, jangkarBaris);
      if (deret != null) jangkarKolom = deret;
    }

    // Cadangan terakhir: LABEL SUB-KOLOM yang terulang sekali per Repeat.
    //
    // Diuji di emulator dengan ML Kit asli (`integration_test/
    // foto_tabel_viscometer_hp_test.dart`): di lembar Viscometer, digit `3`
    // di kepala kolom **nggak kebaca sama sekali** — digit tunggal berdiri
    // sendiri itu bentuk tersulit buat ML Kit — sementara `cP` kebaca kelima-
    // limanya. Deret nomor yang bolong satu membatalkan seluruh tabel, jadi
    // tanpa jalur ini jepretan yang sehat tetap ditolak.
    //
    // Aman karena syaratnya ketat: labelnya harus muncul **persis** sebanyak
    // Repeat, semuanya sebaris mendatar, dan semuanya di atas baris isi.
    if (jangkarKolom.length < pengulangan.length) {
      final dariLabel = _jangkarDariLabelSubKolom(
        terbaca,
        pengulangan,
        fieldPerRepeat,
        labelField,
        jangkarBaris,
      );

      if (dariLabel != null) jangkarKolom = dariLabel;
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
    final labelKolomKurang = <String>[];

    if (fieldPerRepeat.length > 1) {
      for (final f in fieldPerRepeat) {
        final label = labelField[f] ?? f;

        for (final t in terbaca) {
          if (_samaLabel(t.teks, label)) {
            jangkarField.add((field: f, t: t));
          }
        }
      }

      // **Nggak semua label sub-kolom kebaca → seluruh tabel nggak dipetakan.**
      //
      // Ini aturan yang sama dengan [_fieldSlot] di jalur ke-bawah, dan
      // sebabnya kejadian nyata: waktu label kolom pembacaan (`cP`) nggak
      // kebaca sementara `°C` kebaca, yang TERDEKAT dari setiap angka jadi
      // `°C` — dan seluruh pembacaan mendarat rapi di kolom suhu. Nggak ada
      // yang kelihatan salah: kotaknya terisi, jumlahnya pas, dan angkanya
      // baru ketahuan aneh waktu sertifikatnya terbit.
      //
      // Yang hilang dicatat, bukan cuma dibuang, supaya teknisi dikasih tau
      // kolom mana yang harus ikut kefoto.
      // Label yang hilang di SEBAGIAN Repeat dilengkapi dari jaraknya sendiri.
      //
      // Diuji di emulator: `°C` kebaca di empat Repeat dan lewat di satu.
      // Akibatnya suhu Repeat itu jatuh lebih dekat ke `cP`-nya sendiri,
      // bentrok dengan pembacaan di sel yang sama, dan `_buangSelKembar`
      // membuang KEDUANYA — satu label yang lewat menghapus enam sel.
      //
      // Jarak antar label sub-kolom di dalam satu Repeat itu tetap (di lembar
      // uji: 151/152/151/151 px), jadi yang hilang bisa ditempatkan dari jarak
      // yang sudah terbaca. Ini deduksi dari tata letak yang terukur, bukan
      // tebakan urutan — dan tetap ditolak kalau jaraknya nggak konsisten.
      _lengkapiJangkarField(jangkarField, fieldPerRepeat, jangkarKolom);

      final ketemu = {for (final j in jangkarField) j.field};

      if (ketemu.length < fieldPerRepeat.length) {
        for (final f in fieldPerRepeat) {
          if (!ketemu.contains(f)) labelKolomKurang.add(labelField[f] ?? f);
        }

        return HasilPetaTabel(
          sel: const [],
          titikKetemu: jangkarBaris.keys.toList(),
          repeatKetemu: jangkarKolom.keys.toList(),
          angkaTakTerpetakan: angka.length,
          labelKolomKurang: labelKolomKurang,
        );
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
    // Diukur dari PUSAT jangkar paling kiri, mundur setengah lebar kolom —
    // bukan dari tepi kirinya mundur setinggi baris.
    //
    // Bedanya menentukan sejak jangkar kolom bisa datang dari label sub-kolom
    // (`_jangkarDariLabelSubKolom`), yang posisinya sengaja digeser ke tengah
    // span kolomnya. Diukur dari tepi kiri jangkar yang sudah tergeser itu,
    // batasnya masuk terlalu ke kanan dan MEMAKAN kolom pembacaan Repeat 1 —
    // lima belas sel hilang tanpa satu pun dilaporkan nyasar.
    //
    // Setengah lebar kolom itu batas alaminya: di kirinya sudah wilayah kolom
    // label tabel, bukan kolom Repeat pertama.
    final jarakKolom = _jarakAntarKolom(jangkarKolom.values);
    final mundur = jarakKolom.isFinite ? jarakKolom / 2 : tinggiBaris;

    // Sejauh apa satu angka masih boleh diakui kolom terdekat — aturan yang
    // sama persis dipakai jalur ke-bawah (`batasKolom` di [petakanKeBawah]).
    //
    // Dulu di sini nggak ada batasnya sama sekali, dan bawaan `_kolomTerdekat`
    // memang tanpa batas. Alasannya ditulis di method itu: kolom Repeat selalu
    // berdampingan rapat, jadi yang paling dekat memang pemiliknya. Premis itu
    // cuma berlaku waktu SEMUA kolom kejangkar.
    //
    // Begitu sebagian kepalanya nggak kebaca, dia terbalik jadi berbahaya:
    // angka di bawah kolom yang nggak punya jangkar ditarik ke jangkar
    // terdekat SEJAUH APA PUN — di lembar TITS yang enam kolomnya cuma
    // kejangkar tiga, itu berarti pembacaan DOWN mendarat di kolom UP. Nggak
    // ada error, jumlah selnya wajar, angkanya wajar.
    //
    // Yang lebih jauh dari setengah lebar kolom sekarang DIBUANG dan ikut
    // kehitung `angkaTakTerpetakan`, jadi teknisi diberitahu ada yang nggak
    // keangkut — bukan dikasih angka yang pindah kolom diam-diam. Ini persis
    // janji yang sudah tertulis di docblock [petakan]: kolom yang kepalanya
    // nggak kebaca nggak pernah keisi.
    final batasKolom = jarakKolom.isFinite
        ? jarakKolom * _rasioBaris
        : double.infinity;

    final batasKiri = jangkarKolom.values
            .map((j) => j.kotak.center.dx)
            .reduce((a, b) => a < b ? a : b) -
        mundur;

    // Batas ATAS area pembacaan — kembarannya [batasKiri], buat sumbu tegak.
    //
    // Semua yang di atasnya itu kepala tabel: nomor kolom (`1`..`5` di lembar
    // Viscometer) dan baris satuan. Angka yang sah, tapi bukan pembacaan —
    // jadi dilewat tanpa ikut kehitung "nggak keangkut", persis seperti
    // [batasKiri] melewat kolom label di kiri. Tanpa ini tiap foto yang
    // sempurna dilaporkan kehilangan lima angka.
    final batasAtas = jangkarBaris.values
            .map((j) => j.kotak.top)
            .reduce((a, b) => a < b ? a : b) -
        tinggiBaris;

    final sel = <SelTabelFoto>[];
    var terbuang = 0;

    for (final a in angka) {
      if (a.t.kotak.center.dx < batasKiri) continue;
      if (a.t.kotak.center.dy < batasAtas) continue;

      final titik = _barisTerdekat(a.t, jangkarBaris, tinggiBaris);
      final repeat = _kolomTerdekat(a.t, jangkarKolom, batas: batasKolom);

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

    final bersih = _buangSelKembar(sel, (n) => terbuang += n);

    return HasilPetaTabel(
      sel: bersih,
      titikKetemu: jangkarBaris.keys.toList(),
      repeatKetemu: jangkarKolom.keys.toList(),
      angkaTakTerpetakan: terbuang,
    );
  }

  /// Petakan foto tabel yang Repeat-nya TURUN KE BAWAH.
  ///
  /// Bentuk Conductivity (`SIDIK-FM-CAL-0510`) tabelnya terbalik dari bentuk
  /// pH: nomor Repeat turun di kolom kiri, dan yang berjajar ke kanan itu slot
  /// larutan (`84`, `1413 µS`, `5000 µS`, `80000 µS`).
  ///
  /// [petakan] nggak bisa dipakai di sini — bukan karena tulisannya beda, tapi
  /// karena **dua jangkarnya ada di sumbu yang salah**. Dijalanin apa adanya,
  /// hasilnya nol sel dan seluruh angka dibuang.
  ///
  /// Aturannya sama persis: tiap angka wajib punya DUA jangkar (baris & kolom)
  /// sebelum ditaruh, dan yang cuma punya satu dibuang, bukan ditebak.
  ///
  ///  - **baris** dari kepala Repeat yang tercetak di kolom kiri
  ///    ([kepalaPengulangan]).
  ///  - **kolom** dari tulisan kepala slot ([SlotFoto.kepala]) — yang tercetak
  ///    di kertas, BUKAN nilai titik ukurnya. Kertas Rev.5 masih nulis nominal
  ///    botol lama (`1413`), sementara titik yang dihitung `1412`.
  ///  - **field** di dalam satu slot (`pembacaan` vs `suhu`) dari label satuan
  ///    yang tercetak di bawah kepala slot.
  ///
  /// Slot yang [SlotFoto.titikUkur]-nya null (di kertas ada kotaknya, di master
  /// belum ada larutannya) tetap dijangkar — supaya angka di kolom itu KEBUANG,
  /// bukan ketarik ke slot sebelahnya.
  HasilPetaTabel petakanKeBawah({
    required List<TeksTerbaca> terbaca,
    required List<SlotFoto> slot,
    required List<int> pengulangan,
    Map<int, List<String>> kepalaPengulangan = const {},
  }) {
    // Baris di sini dijangkar nomor Repeat dan kolomnya index slot — dua-duanya
    // sudah unik, jadi jangkarnya nggak bisa runtuh seperti di [petakan]. Yang
    // masih bisa runtuh sel keluarannya: dua slot yang titik ukurnya sama
    // menghasilkan kunci `(titikUkur, repeatNo, fieldId)` yang sama, dan yang
    // belakangan diam-diam menimpa yang duluan.
    final kembar = _titikKembar([
      for (final s in slot)
        if (s.titikUkur != null) s.titikUkur!,
    ]);

    if (kembar.isNotEmpty) {
      return HasilPetaTabel(
        sel: const [],
        titikKetemu: const [],
        repeatKetemu: const [],
        angkaTakTerpetakan: 0,
        barisKembar: kembar,
      );
    }

    final angka = <({double nilai, TeksTerbaca t})>[];

    for (final t in terbaca) {
      final n = _angka(t.teks);
      if (n != null) angka.add((nilai: n, t: t));
    }

    // --- jangkar BARIS: kepala Repeat di kolom kiri ------------------------
    final jangkarBaris = _jangkarTeks(
      terbaca,
      {for (final r in pengulangan) r: kepalaPengulangan[r] ?? kepalaBawaan(r)},
    );

    // --- jangkar KOLOM: tulisan kepala slot di baris atas ------------------
    final jangkarKolom = _jangkarTeks(terbaca, {
      for (var i = 0; i < slot.length; i++) i: slot[i].kepala,
    });

    final titikKetemu = [
      for (final i in jangkarKolom.keys)
        if (slot[i].titikUkur != null) slot[i].titikUkur!,
    ];

    if (jangkarBaris.isEmpty || jangkarKolom.isEmpty) {
      return HasilPetaTabel(
        sel: const [],
        titikKetemu: titikKetemu,
        repeatKetemu: jangkarBaris.keys.toList(),
        angkaTakTerpetakan: angka.length,
      );
    }

    // --- jangkar FIELD di dalam satu slot ----------------------------------
    //
    // Cuma perlu waktu satu slot punya lebih dari satu kolom (pembacaan &
    // suhu). Labelnya tercetak per slot, jadi teks yang sama (`µS/cm`) muncul
    // beberapa kali — semuanya dikumpulkan, dan yang mutusin nanti jaraknya.
    final labelKeField = <String, String>{};

    for (final s in slot) {
      if (s.labelField.length < 2) continue;

      for (final e in s.labelField.entries) {
        labelKeField.putIfAbsent(_normalLabel(e.value), () => e.key);
      }
    }

    final tinggiBaris = _jarakAntarBaris(jangkarBaris.values);
    final batasKolom = _jarakAntarKolom(jangkarKolom.values) * _rasioBaris;

    // Jangkar field dikelompokkan PER SLOT, bukan satu tumpukan buat seluruh
    // tabel: `µS/cm` tercetak sekali di tiap slot, dan yang mutusin kolom
    // pembacaan slot ini itu label yang ada di slot ini juga.
    final fieldPerSlot = <int, List<({String field, TeksTerbaca t})>>{};

    for (final t in terbaca) {
      final field = labelKeField[_normalLabel(t.teks)];
      if (field == null) continue;

      final i = _kolomTerdekat(t, jangkarKolom, batas: batasKolom);
      if (i == null) continue;

      fieldPerSlot.putIfAbsent(i, () => []).add((field: field, t: t));
    }

    // Batas ATAS area pembacaan — semua yang di atasnya itu kepala tabel:
    // tulisan slot (`1413`) dan baris resolusi (`0,1`). Dua-duanya angka yang
    // sah dan dua-duanya bukan pembacaan, jadi dilewat tanpa ikut kehitung
    // "nggak keangkut", sama kayak [petakan] melewat kolom label di kirinya.
    final batasAtas =
        jangkarBaris.values
            .map((j) => j.kotak.top)
            .reduce((a, b) => a < b ? a : b) -
        tinggiBaris;

    // Batas KIRI — kolom Repeat itu sendiri. Waktu kepalanya angka polos
    // (`1`..`5`), tanpa batas ini nomor Repeat ikut dibaca sebagai pembacaan.
    final batasKiri =
        jangkarKolom.values
            .map((j) => j.kotak.left)
            .reduce((a, b) => a < b ? a : b) -
        tinggiBaris;

    final sel = <SelTabelFoto>[];
    var terbuang = 0;

    for (final a in angka) {
      if (a.t.kotak.center.dy < batasAtas) continue;
      if (a.t.kotak.center.dx < batasKiri) continue;

      final repeat = _barisTerdekat(a.t, jangkarBaris, tinggiBaris);
      final index = _kolomTerdekat(a.t, jangkarKolom, batas: batasKolom);

      if (repeat == null || index == null) {
        terbuang++;
        continue;
      }

      final titik = slot[index].titikUkur;
      final field = _fieldSlot(a.t, slot[index], fieldPerSlot[index]);

      if (titik == null || field == null) {
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

    final bersih = _buangSelKembar(sel, (n) => terbuang += n);

    return HasilPetaTabel(
      sel: bersih,
      titikKetemu: titikKetemu,
      repeatKetemu: jangkarBaris.keys.toList(),
      angkaTakTerpetakan: terbuang,
    );
  }

  /// Kolom mana di dalam satu slot — `pembacaan` atau `suhu`.
  ///
  /// **Kalau nggak SEMUA label kolom slot ini kebaca, jawabannya null.** Ini
  /// yang paling penting di sini, dan bukan kehati-hatian berlebihan: waktu
  /// label kolom pembacaan (`µS/cm`) nggak kebaca sementara `°C` kebaca, yang
  /// terdekat dari SETIAP angka jadi `°C` — dan seluruh pembacaan slot itu
  /// mendarat rapi di kolom suhu. Nggak ada yang kelihatan salah: kotaknya
  /// terisi, jumlahnya pas, dan angkanya baru ketahuan aneh di sertifikat.
  ///
  /// Slot yang di kertas cuma sekolom nggak butuh label sama sekali — nggak ada
  /// yang bisa ketuker.
  String? _fieldSlot(
    TeksTerbaca t,
    SlotFoto slot,
    List<({String field, TeksTerbaca t})>? jangkar,
  ) {
    if (slot.labelField.length == 1) return slot.labelField.keys.first;
    if (slot.labelField.isEmpty || jangkar == null) return null;

    final ketemu = {for (final j in jangkar) j.field};
    if (ketemu.length < slot.labelField.length) return null;

    return _fieldTerdekat(t, jangkar);
  }

  /// Satu sel nggak boleh keisi dua kali. Kalau ada dua angka yang jatuh ke
  /// kotak yang sama, DUA-DUANYA dibuang: nggak ada dasar buat milih, dan
  /// milih asal itu persis cara angka mendarat di tempat yang salah.
  List<SelTabelFoto> _buangSelKembar(
    List<SelTabelFoto> sel,
    void Function(int) buang,
  ) {
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
        buang(e.value.length);
      }
    }

    return bersih;
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
    List<TeksTerbaca> terbaca,
    List<double> titikUkur,
    Map<double, String> labelTercetak,
  ) {
    // Semua angka yang NILAINYA cocok ke salah satu titik — calon jangkar,
    // termasuk pembacaan yang kebetulan mirip. Atau, kalau labelnya beda dari
    // nilai (Viscometer), yang TEKS-nya persis sama dengan label tercetak.
    //
    // Yang disapu SELURUH teks yang kebaca, bukan cuma yang keparse jadi angka.
    // Dulu di sini cuma yang keparse — dan itu diam-diam membatasi
    // [labelTercetak] ke label yang kebetulan berupa ANGKA (`100`, `1000`).
    // Label yang berupa kata (`Indikator`, `Suhu Ruang` di grid Enclosure)
    // nggak pernah masuk daftar calon, jadi barisnya nggak pernah kejangkar
    // sekali pun labelnya kebaca jelas di foto. Buat label berupa angka nggak
    // ada yang berubah: elemen yang sama, jangkar yang sama.
    //
    // Frasanya ikut, TAPI cuma buat label yang memang BERSPASI — `Suhu Ruang`
    // itu dua element di mata ML Kit, dan dicocokkan per element dia nggak
    // akan pernah sama dengan labelnya.
    //
    // Frasa nggak boleh dipakai buat label satu kata, dan ini bukan kehati-
    // hatian kosong: [_rapatkan] MEMBUANG spasi, jadi dua element `100` dan `0`
    // yang kebetulan bersebelahan jadi frasa `100 0` yang rapat jadi `1000` —
    // persis label slot Viscometer. Jangkar barisnya pindah ke tempat yang
    // bukan barisnya, dan yang keluar bukan error tapi seluruh baris `1000`
    // keisi angka milik baris lain.
    final adaLabelBerspasi = labelTercetak.values.any(_berspasi);
    final calon = <({double titik, TeksTerbaca t})>[];

    for (final t in adaLabelBerspasi ? _frasa(terbaca) : terbaca) {
      final nilai = _angka(t.teks);
      final iniFrasa = _berspasi(t.teks);

      for (final titik in titikUkur) {
        final cocokAngka =
            nilai != null && (nilai - titik).abs() <= titik.abs() * _toleransiTitik;
        final label = labelTercetak[titik];
        final cocokLabel = label != null &&
            iniFrasa == _berspasi(label) &&
            _rapatkan(t.teks) == _rapatkan(label);

        if (cocokAngka || cocokLabel) {
          calon.add((titik: titik, t: t));
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

  /// Jangkar yang dikenali dari TULISAN yang tercetak, bukan dari nilainya.
  ///
  /// Dipakai dua kali dengan kunci yang beda: nomor Repeat di bentuk pH
  /// (`X1`..`Xn` berjajar ke kanan) dan index slot larutan di bentuk
  /// ke-bawah (`84`, `1413 µS` berjajar ke kanan). Yang pertama ketemu yang
  /// dipakai — kepala tercetak sekali per kolom.
  ///
  /// Spasinya diabaikan waktu mencocokkan: ML Kit kadang ngerapetin `Repeat 1`
  /// jadi `Repeat1`, dan kepala kolom yang gagal cocok gara-gara satu spasi
  /// bikin SELURUH kolomnya nggak keisi.
  ///
  /// Kalau tulisannya muncul lebih dari sekali, yang PALING ATAS yang menang —
  /// bukan yang kebetulan kebaca duluan. Dua sebabnya:
  ///
  ///  - Kepala slot bentuk ke-bawah bisa berupa angka polos (`84`), dan angka
  ///    itu bisa muncul lagi di badan tabel sebagai pembacaan. Kepala selalu di
  ///    ATAS pembacaannya, jadi yang paling atas itu yang kepala.
  ///  - Urutan hasil OCR bukan urutan di kertas. Milih "yang pertama kebaca"
  ///    bikin jangkarnya pindah-pindah antar jepretan yang isinya sama.
  Map<K, TeksTerbaca> _jangkarTeks<K>(
    List<TeksTerbaca> terbaca,
    Map<K, List<String>> kepala,
  ) {
    final hasil = <K, TeksTerbaca>{};
    // Elemen apa adanya DITAMBAH gabungan elemen bersebelahan — kepala kolom
    // yang di kertas dua kata nggak pernah datang sebagai satu potong.
    final calon = _frasa(terbaca);

    for (final e in kepala.entries) {
      final cari = [for (final k in e.value) _rapatkan(k)];

      for (final t in calon) {
        if (!cari.contains(_rapatkan(t.teks))) continue;

        final ada = hasil[e.key];
        if (ada == null || t.kotak.top < ada.kotak.top) hasil[e.key] = t;
      }
    }

    return hasil;
  }

  /// Berapa elemen bersebelahan yang paling banyak disambung jadi satu calon.
  ///
  /// Dua sudah cukup buat kepala kolom terpanjang yang kita punya (`DOWN X1`);
  /// tiga disediakan supaya kepala slot bersatuan (`1413 µS/cm`) yang kebaca
  /// terpecah tiga tetap kejangkar. Lebih dari itu cuma nambah calon tanpa
  /// nambah kepala yang beneran ada di kertas.
  static const _maksKataFrasa = 3;

  /// Elemen OCR apa adanya, ditambah gabungan elemen yang BERSEBELAHAN di
  /// baris yang sama.
  ///
  /// ## Kenapa perlu
  ///
  /// [MlKitPembacaHalaman] memulangkan per ELEMENT — kira-kira per kata. Jadi
  /// kepala kolom yang di kertas ditulis dua kata nggak pernah sampai ke sini
  /// utuh, dan yang tersisa cuma potongannya. Di lembar TITS potongan itu
  /// `X1`, dan `X1` kecetak DUA KALI: sekali di bawah `UP`, sekali di bawah
  /// `DOWN`. Yang menang jadi undian beberapa piksel, dan begitu yang menang
  /// kolom DOWN, angka kolom UP mendarat di Repeat yang salah — tanpa satu pun
  /// gejala, karena jumlah selnya tetap pas dan angkanya tetap wajar.
  ///
  /// ## Kenapa ini bukan "menebak dari urutan"
  ///
  /// Yang disambung cuma yang beneran bersebelahan DI CITRA: tumpang tindih
  /// tegaknya lebih dari separuh tinggi huruf (jadi memang satu baris teks),
  /// dan celah mendatarnya lebih sempit dari satu tinggi huruf (jadi memang
  /// satu tulisan, bukan dua kolom yang berjauhan). Kotaknya gabungan kotak
  /// keduanya, jadi jangkarnya duduk di TENGAH tulisan yang tercetak — bukan
  /// di kata pertamanya.
  ///
  /// Elemen aslinya tetap ikut, jadi kepala satu kata (`X1`, `1413`) tetap
  /// ketemu persis seperti sebelumnya.
  static List<TeksTerbaca> _frasa(List<TeksTerbaca> terbaca) {
    if (terbaca.length < 2) return terbaca;

    final hasil = [...terbaca];

    for (final baris in _perBaris(terbaca)) {
      for (var i = 0; i < baris.length; i++) {
        var gabung = baris[i];

        for (var n = 1; n < _maksKataFrasa && i + n < baris.length; n++) {
          final kanan = baris[i + n];
          final tinggi = gabung.kotak.height < kanan.kotak.height
              ? gabung.kotak.height
              : kanan.kotak.height;

          // Celah yang lebih lebar dari satu tinggi huruf itu batas antar
          // KOLOM, bukan spasi antar kata. Berhenti di situ — nyambung terus
          // bikin dua kepala kolom yang berjauhan jadi satu calon.
          if (kanan.kotak.left - gabung.kotak.right > tinggi) break;

          gabung = (
            teks: '${gabung.teks} ${kanan.teks}',
            kotak: gabung.kotak.expandToInclude(kanan.kotak),
          );

          hasil.add(gabung);
        }
      }
    }

    return hasil;
  }

  /// Elemen dikelompokkan jadi BARIS teks, tiap baris urut dari kiri.
  ///
  /// Bukan dari urutan hasil OCR — itu urutan blok ML Kit, dan blok bisa
  /// meloncat. Yang dipakai posisinya: dua elemen sebaris kalau tumpang tindih
  /// tegaknya lebih dari separuh tinggi huruf yang paling pendek di antara
  /// keduanya. Kepala kolom tabel cetak selalu memenuhi itu; angka di baris
  /// lain nggak pernah.
  static List<List<TeksTerbaca>> _perBaris(List<TeksTerbaca> terbaca) {
    final urut = [...terbaca]
      ..sort((a, b) => a.kotak.top.compareTo(b.kotak.top));

    final baris = <List<TeksTerbaca>>[];

    for (final t in urut) {
      var ketemu = false;

      for (final b in baris) {
        final acuan = b.first;
        final tinggi = acuan.kotak.height < t.kotak.height
            ? acuan.kotak.height
            : t.kotak.height;

        if (tinggi <= 0) continue;

        final atas = acuan.kotak.top > t.kotak.top
            ? acuan.kotak.top
            : t.kotak.top;
        final bawah = acuan.kotak.bottom < t.kotak.bottom
            ? acuan.kotak.bottom
            : t.kotak.bottom;

        if (bawah - atas < tinggi * _rasioBaris) continue;

        b.add(t);
        ketemu = true;
        break;
      }

      if (!ketemu) baris.add([t]);
    }

    for (final b in baris) {
      b.sort((a, c) => a.kotak.left.compareTo(c.kotak.left));
    }

    return baris;
  }

  /// Kepala kolom yang di kertas ditulis NOMOR POLOS (`1`..`5`).
  ///
  /// Dipakai cuma kalau kepala tekstual (`X1` / `Repeat 1`) nggak lengkap —
  /// formulir Viscometer Rev.3 & lima lembar lain nyetak nomor polos, dan
  /// tanpa ini kolomnya nggak pernah kejangkar.
  ///
  /// Nomor polos sendirian memang nggak bisa dipercaya: `1` juga bisa jadi
  /// pembacaan atau nomor urut baris. Yang dipercaya di sini bukan nomornya,
  /// tapi **DERETNYA** — dan empat syarat di bawah yang bikin pembacaan nggak
  /// bisa menyamar jadi deret itu:
  ///
  ///  1. SELURUH nomor pengulangan harus ada. Kurang satu → batal, bukan
  ///     dipakai sebagian.
  ///  2. Semuanya sebaris mendatar (dalam satu tinggi huruf).
  ///  3. `x`-nya menaik persis mengikuti nomornya (1 di kiri 2, 2 di kiri 3).
  ///  4. Barisnya ADA DI ATAS jangkar baris paling atas — kepala tabel selalu
  ///     di atas isinya. Ini yang paling menentukan: pembacaan hidup di baris
  ///     yang SAMA dengan nilai standarnya, jadi dia nggak pernah lolos.
  ///
  /// Balik `null` kalau salah satu syarat nggak kepenuhan — sengaja, karena
  /// kepala kolom yang salah tebak itu persis cara angka mendarat di kolom
  /// yang salah tanpa ngasih gejala.
  Map<int, TeksTerbaca>? _jangkarNomorPolos(
    List<TeksTerbaca> terbaca,
    List<int> pengulangan,
    Map<double, TeksTerbaca> jangkarBaris,
  ) {
    // Tanpa jangkar baris nggak ada acuan "di atas isi tabel", jadi syarat
    // ke-4 nggak bisa ditegakkan sama sekali.
    if (jangkarBaris.isEmpty || pengulangan.isEmpty) return null;

    final atasIsi = jangkarBaris.values
        .map((j) => j.kotak.top)
        .reduce((a, b) => a < b ? a : b);

    final calon = <({int no, TeksTerbaca t})>[];

    for (final t in terbaca) {
      final n = int.tryParse(t.teks.trim());

      if (n == null || !pengulangan.contains(n)) continue;
      // Syarat 4: yang sejajar atau di bawah baris pertama itu ISI tabel.
      if (t.kotak.bottom > atasIsi) continue;

      calon.add((no: n, t: t));
    }

    if (calon.isEmpty) return null;

    final tinggiHuruf = calon
        .map((c) => c.t.kotak.height)
        .reduce((a, b) => a > b ? a : b);

    // Syarat 2: dikelompokkan per baris mendatar.
    calon.sort((a, b) => a.t.kotak.center.dy.compareTo(b.t.kotak.center.dy));

    final klaster = <List<({int no, TeksTerbaca t})>>[];

    for (final c in calon) {
      final akhir = klaster.isEmpty ? null : klaster.last;

      if (akhir != null &&
          (c.t.kotak.center.dy - akhir.first.t.kotak.center.dy).abs() <=
              tinggiHuruf) {
        akhir.add(c);
      } else {
        klaster.add([c]);
      }
    }

    final urut = [...pengulangan]..sort();

    for (final k in klaster) {
      final perNomor = <int, TeksTerbaca>{};

      for (final c in k) {
        final ada = perNomor[c.no];
        if (ada == null || c.t.kotak.left < ada.kotak.left) {
          perNomor[c.no] = c.t;
        }
      }

      // Syarat 1: lengkap.
      if (perNomor.length != urut.length) continue;

      // Syarat 3: menaik ke kanan sesuai nomornya.
      var menaik = true;

      for (var i = 1; i < urut.length; i++) {
        if (perNomor[urut[i]]!.kotak.left <= perNomor[urut[i - 1]]!.kotak.left) {
          menaik = false;
          break;
        }
      }

      if (menaik) return perNomor;
    }

    return null;
  }

  /// Seberapa jauh jarak antar label sub-kolom boleh menyimpang sebelum
  /// dianggap bukan tata letak yang seragam, relatif terhadap jaraknya sendiri.
  ///
  /// Tabel cetak kolomnya seragam; 15 % sudah jauh lebih longgar dari
  /// penyimpangan yang wajar (di lembar uji: 151/152/151/151 px, 0,7 %) dan
  /// masih jauh lebih ketat dari jarak antar Repeat, yang dua kali lipatnya.
  static const _toleransiJarakLabel = 0.15;

  /// Tempatkan label sub-kolom yang lewat di sebagian Repeat.
  ///
  /// Dipanggil sesudah [jangkarField] terkumpul, dan cuma bekerja kalau ada
  /// field yang jangkarnya LEBIH lengkap dari yang lain — jaraknya diambil
  /// dari Repeat yang punya dua-duanya, lalu dipakai menempatkan yang hilang.
  ///
  /// Nggak melakukan apa-apa kalau: cuma satu Repeat yang punya pasangan
  /// lengkap (nggak ada yang bisa dirata-rata), atau jaraknya nggak konsisten
  /// antar Repeat ([_toleransiJarakLabel]). Dua-duanya berarti tata letaknya
  /// nggak sesuai dugaan, dan menempatkan jangkar di situ sama saja mengarang
  /// posisi kolom.
  void _lengkapiJangkarField(
    List<({String field, TeksTerbaca t})> jangkarField,
    List<String> fieldPerRepeat,
    Map<int, TeksTerbaca> jangkarKolom,
  ) {
    if (jangkarField.isEmpty || jangkarKolom.isEmpty) return;

    // Tiap jangkar dikelompokkan ke Repeat-nya.
    final perField = <String, Map<int, TeksTerbaca>>{};

    for (final j in jangkarField) {
      final repeat = _kolomTerdekat(j.t, jangkarKolom);
      if (repeat == null) continue;

      // Satu Repeat cuma boleh punya satu label per field; yang paling kiri
      // menang supaya hasilnya nggak bergantung urutan OCR.
      final ada = perField[j.field]?[repeat];
      if (ada == null || j.t.kotak.left < ada.kotak.left) {
        (perField[j.field] ??= {})[repeat] = j.t;
      }
    }

    if (perField.length < 2) return;

    // Field paling lengkap jadi acuan penempatan.
    final acuan = perField.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );

    for (final f in fieldPerRepeat) {
      if (f == acuan.key) continue;

      final punya = perField[f];
      if (punya == null || punya.isEmpty) continue;

      // Jarak field ini dari acuan, diukur di Repeat yang punya dua-duanya.
      final jarak = <double>[];

      for (final e in punya.entries) {
        final pasangan = acuan.value[e.key];
        if (pasangan == null) continue;

        jarak.add(e.value.kotak.left - pasangan.kotak.left);
      }

      if (jarak.length < 2) continue;

      final rata = jarak.reduce((a, b) => a + b) / jarak.length;

      if (rata == 0) continue;

      final menyimpang = jarak.any(
        (j) => (j - rata).abs() > rata.abs() * _toleransiJarakLabel,
      );

      if (menyimpang) continue;

      // Repeat yang labelnya lewat: ditempatkan dari acuan + jarak itu.
      for (final e in acuan.value.entries) {
        if (punya.containsKey(e.key)) continue;

        final kotak = e.value.kotak;

        jangkarField.add((
          field: f,
          t: (
            teks: '',
            kotak: Rect.fromLTWH(
              kotak.left + rata,
              kotak.top,
              kotak.width,
              kotak.height,
            ),
          ),
        ));
      }
    }
  }

  /// Kepala kolom yang disimpulkan dari LABEL SUB-KOLOM (`cP`, `°C`).
  ///
  /// Dipakai kalau kepala tekstual maupun deret nomor polos gagal — dan itu
  /// kejadian nyata, bukan pengaman teoretis: di lembar Viscometer ML Kit
  /// melewatkan digit `3` di kepala kolom sementara `cP` kebaca kelimanya.
  ///
  /// Label sub-kolom tercetak **sekali per Repeat**, jadi kalau salah satunya
  /// muncul persis sebanyak Repeat dan semuanya sebaris mendatar di atas isi
  /// tabel, urutan kirinya adalah urutan Repeat-nya. Yang dipakai di sini
  /// urutan **spasial** (kiri ke kanan di kertas), bukan urutan hasil OCR —
  /// urutan OCR memang nggak boleh dipercaya, tapi tata letak kolom di kertas
  /// boleh.
  ///
  /// Jangkarnya nggak ditaruh di label itu sendiri, tapi di **tengah span
  /// kolomnya**. Label `cP` berdiri di tepi kiri Repeat-nya, jadi memakainya
  /// apa adanya bikin kolom suhu Repeat 1 nyaris sama jauh dari `cP` Repeat 1
  /// dan `cP` Repeat 2 (155 px vs 165 px di jepretan uji) — selisih setipis
  /// itu bisa berbalik cuma karena fotonya agak miring. Digeser ke tengah
  /// span, jaraknya jadi 12 px vs 308 px.
  ///
  /// Balik `null` kalau nggak ada label yang memenuhi syarat.
  Map<int, TeksTerbaca>? _jangkarDariLabelSubKolom(
    List<TeksTerbaca> terbaca,
    List<int> pengulangan,
    List<String> fieldPerRepeat,
    Map<String, String> labelField,
    Map<double, TeksTerbaca> jangkarBaris,
  ) {
    if (jangkarBaris.isEmpty || pengulangan.length < 2) return null;

    final atasIsi = jangkarBaris.values
        .map((j) => j.kotak.top)
        .reduce((a, b) => a < b ? a : b);

    for (final f in fieldPerRepeat) {
      final label = labelField[f] ?? f;

      final cocok = [
        for (final t in terbaca)
          if (_samaLabel(t.teks, label) && t.kotak.bottom <= atasIsi) t,
      ]..sort((a, b) => a.kotak.left.compareTo(b.kotak.left));

      // Harus PERSIS sebanyak Repeat. Kurang berarti ada yang nggak kebaca
      // dan kita nggak tau yang mana; lebih berarti labelnya muncul di tempat
      // lain juga, jadi urutan kirinya nggak lagi berarti nomor Repeat.
      if (cocok.length != pengulangan.length) continue;

      // Semuanya harus sebaris mendatar — baris satuan di kepala tabel.
      final tinggi = cocok
          .map((t) => t.kotak.height)
          .reduce((a, b) => a > b ? a : b);
      final yPertama = cocok.first.kotak.center.dy;

      if (cocok.any((t) => (t.kotak.center.dy - yPertama).abs() > tinggi)) {
        continue;
      }

      // Lebar satu kolom Repeat, dari jarak antar label.
      final jarak =
          (cocok.last.kotak.left - cocok.first.kotak.left) /
          (cocok.length - 1);

      if (jarak <= 0) continue;

      final urut = [...pengulangan]..sort();
      final hasil = <int, TeksTerbaca>{};

      for (var i = 0; i < urut.length; i++) {
        final kotak = cocok[i].kotak;

        hasil[urut[i]] = (
          teks: cocok[i].teks,
          // Digeser ke tengah span kolomnya — lihat alasannya di dokumentasi
          // method ini.
          kotak: Rect.fromLTWH(
            kotak.left + jarak / 2 - kotak.width / 2,
            kotak.top,
            kotak.width,
            kotak.height,
          ),
        );
      }

      return hasil;
    }

    return null;
  }

  /// Baris yang jangkarnya paling sejajar, atau `null` kalau nggak ada yang
  /// cukup dekat.
  K? _barisTerdekat<K>(
    TeksTerbaca t,
    Map<K, TeksTerbaca> jangkar,
    double tinggiBaris,
  ) {
    final batas = tinggiBaris * _rasioBaris;
    K? terbaik;
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

  /// Kolom yang kepalanya paling segaris, atau `null` kalau angkanya jatuh di
  /// luar semua kolom.
  ///
  /// [batas] sejauh apa angka masih dianggap milik kolom itu. Bawaannya nggak
  /// terbatas — kolom Repeat bentuk pH selalu berdampingan rapat, dan yang
  /// paling dekat memang pemiliknya.
  K? _kolomTerdekat<K>(
    TeksTerbaca t,
    Map<K, TeksTerbaca> jangkar, {
    double batas = double.infinity,
  }) {
    K? terbaik;
    var jarakTerbaik = double.infinity;

    for (final e in jangkar.entries) {
      // Lebar kolomnya sendiri nggak kita tahu — yang tercetak cuma kepalanya.
      // Jadi batasnya jarak ke kepala TERDEKAT: angka yang lebih dekat ke
      // kepala sebelah memang milik kolom sebelah.
      final jarak = (t.kotak.center.dx - e.value.kotak.center.dx).abs();

      if (jarak <= batas && jarak < jarakTerbaik) {
        terbaik = e.key;
        jarakTerbaik = jarak;
      }
    }

    return terbaik;
  }

  /// Jarak antar kolom slot, diambil dari jangkarnya sendiri.
  ///
  /// **Yang dipakai jarak TERSEMPIT, bukan mediannya** — beda dari
  /// [_jarakAntarBaris], dan bedanya disengaja. Slot cetak cuma ada tiga-empat
  /// biji; satu kepala yang nggak kebaca langsung nggandain sebagian jaraknya
  /// dan median ikut ketarik. Toleransi yang ikut ketarik itu justru yang bikin
  /// angka di kolom tanpa jangkar ketarik ke slot sebelahnya — persis yang mau
  /// dicegah. Jarak tersempit nggak bisa ketarik: kepala yang hilang cuma
  /// bikin jarak lebih LEBAR, nggak pernah lebih sempit.
  double _jarakAntarKolom(Iterable<TeksTerbaca> jangkar) {
    final x = [for (final j in jangkar) j.kotak.center.dx]..sort();

    // Satu kolom doang: nggak ada jarak yang bisa diukur, jadi nggak ada
    // batas yang bisa dipertanggungjawabkan.
    if (x.length < 2) return double.infinity;

    var sempit = double.infinity;

    for (var i = 1; i < x.length; i++) {
      final jarak = x[i] - x[i - 1];
      if (jarak < sempit) sempit = jarak;
    }

    return sempit;
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

  /// Teks ini terdiri dari lebih dari satu kata?
  ///
  /// Dipakai memisahkan calon FRASA dari element tunggal waktu mencocokkan
  /// label baris — lihat alasannya di [_jangkarBaris].
  static bool _berspasi(String teks) => teks.trim().contains(RegExp(r'\s'));

  /// Teks buat dibandingin: huruf kecil semua, tanpa spasi.
  ///
  /// Tanda inci/detik diseragamkan dulu. Kepala kolom ketiga lembar suhu
  /// pasangan itu `0″`, `20″`, `40″` — server ngirimnya pakai DOUBLE
  /// PRIME (U+2033), sementara yang kecetak di lembar master lab tanda kutip
  /// biasa (`0"`), dan ML Kit balikin salah satu dari keduanya tergantung font.
  /// Dicocokkan mentah, satu karakter yang bahkan bukan bagian dari angkanya
  /// bikin SELURUH kolom nggak kejangkar.
  ///
  /// Nggak bisa bikin salah taruh: tanda-tanda ini nggak pernah muncul di
  /// pembacaan — [_angka] cuma nerima digit, titik, dan koma.
  static String _rapatkan(String teks) => teks
      .toLowerCase()
      .replaceAll(RegExp(r'[″”“′’‘`\u0027]'), '"')
      .replaceAll(RegExp(r'\s+'), '');

  /// Label SATUAN kolom buat dibandingin — lebih longgar dari [_rapatkan].
  ///
  /// Lingkaran derajat itu bentuk tersulit buat ML Kit di seluruh lembar:
  /// `°C` rutin kebaca `oC`, `0C`, `˚C`, atau `C` polos. Dicocokkan mentah,
  /// satu lingkaran yang meleset bikin SELURUH tabel nggak jadi dipetakan
  /// (lihat penjaga label di [petakan]) — jepretan sehat ditolak gara-gara
  /// satu karakter yang bahkan bukan bagian dari angkanya.
  ///
  /// Melonggarkan ini nggak bisa bikin salah taruh: yang dibandingkan cuma
  /// label satuan antar sub-kolom di satu tabel, dan `cP` vs `C` tetap beda.
  static String _normalLabel(String teks) {
    final s = teks.toLowerCase().replaceAll(RegExp(r'[\s°º˚*]'), '');

    // `oC` / `0C` — huruf atau nol yang berdiri sendiri di depan satuan suhu
    // itu sisa lingkaran derajat, bukan bagian satuannya.
    return RegExp(r'^[o0]c$').hasMatch(s) ? 'c' : s;
  }

  static bool _samaLabel(String a, String b) =>
      _normalLabel(a) == _normalLabel(b);
}
