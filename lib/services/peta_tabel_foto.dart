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
  }) {
    final angka = <({double nilai, TeksTerbaca t})>[];

    for (final t in terbaca) {
      final n = _angka(t.teks);
      if (n != null) angka.add((nilai: n, t: t));
    }

    final jangkarBaris = _jangkarBaris(angka, titikUkur);

    // --- jangkar KOLOM: kepala `X1`..`Xn` yang tercetak --------------------
    final jangkarKolom = _jangkarTeks(
      terbaca,
      {for (final r in pengulangan) r: kepalaPengulangan[r] ?? kepalaBawaan(r)},
    );

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
        labelKeField.putIfAbsent(_rapatkan(e.value), () => e.key);
      }
    }

    final tinggiBaris = _jarakAntarBaris(jangkarBaris.values);
    final batasKolom = _jarakAntarKolom(jangkarKolom.values) * _rasioBaris;

    // Jangkar field dikelompokkan PER SLOT, bukan satu tumpukan buat seluruh
    // tabel: `µS/cm` tercetak sekali di tiap slot, dan yang mutusin kolom
    // pembacaan slot ini itu label yang ada di slot ini juga.
    final fieldPerSlot = <int, List<({String field, TeksTerbaca t})>>{};

    for (final t in terbaca) {
      final field = labelKeField[_rapatkan(t.teks)];
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

    for (final e in kepala.entries) {
      final cari = [for (final k in e.value) _rapatkan(k)];

      for (final t in terbaca) {
        if (!cari.contains(_rapatkan(t.teks))) continue;

        final ada = hasil[e.key];
        if (ada == null || t.kotak.top < ada.kotak.top) hasil[e.key] = t;
      }
    }

    return hasil;
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

  /// Teks buat dibandingin: huruf kecil semua, tanpa spasi.
  static String _rapatkan(String teks) =>
      teks.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _samaAbaikanBesarKecil(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
