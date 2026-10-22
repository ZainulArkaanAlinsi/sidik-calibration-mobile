import '../../core/utils/uuid.dart';
import '../../models/titik_sesi.dart';

/// Kenapa satu perubahan titik sesi ditolak DI HP — sebelum dikirim.
///
/// Aturannya salinan aturan server (`TitikUkurSesi::terapkan`); server tetap
/// penentunya. Ditahan di sini supaya teknisi langsung tahu, bukan baru tahu
/// waktu simpan ditolak 422.
enum GalatTitikSesi {
  /// Tabel titik tidak ada di batas lembar ini.
  tabelTidakAda,

  /// Lembar ini tidak menerima titik di luar nominal kertasnya.
  tidakBolehTambah,

  /// Nominal sudah dipakai titik lain (aktif maupun nonaktif).
  nominalKembar,

  /// Titik aktif sudah sebanyak `maks` tabel.
  aktifPenuh,

  /// Titik aktif tinggal `min` tabel.
  aktifMinimum,

  /// Lebih dari 60 titik per sesi (termasuk nonaktif).
  totalPenuh,

  /// Alasan kurang dari 5 huruf.
  alasanPendek,

  /// Titik permintaan pelanggan wajib menyebut dasarnya.
  alasanPelanggan,

  /// Titik di lembar ini tidak bisa dinonaktifkan.
  tidakBolehNonaktif,

  /// Titik pertama tabel ini wajib aktif (Tekanan).
  pertamaTerkunci,

  /// Nominal titik yang sudah punya pembacaan tidak bisa diubah.
  punyaPembacaan,

  /// Nominal titik profil dipatok kertas.
  nominalDipatok,

  /// Fase yang dipilih tidak boleh di tabel ini.
  faseTidakBoleh,

  /// Titik tidak ditemukan.
  titikTidakAda,

  /// Semua baris set point lembar sudah terisi (nominal diketik di baris).
  barisPenuh,
}

/// Cara baris lembar kerja berhubungan dengan set titik sesi.
enum ModeBarisTitikSesi {
  /// Baris = daftar titik set (Timer, pH, Timbangan Accuracy): menambah titik
  /// menambah baris.
  daftar,

  /// Set point DIKETIK di baris (Tekanan): satu baris = satu titik; set
  /// mengikuti isi baris.
  ketik,

  /// Baris dipatok kertas (Micrometer): titik cuma bisa dinonaktifkan.
  tetap,
}

/// Peran baris mentah yang BUKAN pembacaan berulang — balok ukur Micrometer
/// dan keping nominal Timbangan. Sama dengan
/// `TitikUkurSesi::PERAN_BUKAN_PENGULANGAN` (`MicrometerMentah::PERAN_BALOK`,
/// `TimbanganMentah::PERAN_NOMINAL`).
const peranBukanPengulangan = {'mikro_balok', 'nominal'};

/// Minimal panjang alasan — sama dengan `TitikUkurSesi::ALASAN_MIN`.
const alasanTitikMinimal = 5;

/// Maksimal titik per sesi — sama dengan `TitikUkurSesi::MAKS_TOTAL`.
const titikSesiMaksTotal = 60;

/// Set titik ukur sesi yang sedang dipegang layar.
///
/// Murni data — tidak tahu apa-apa soal tabel di layar. Yang menghubungkan set
/// ini ke baris lembar kerja itu `LembarKerjaState`.
///
/// Aturan yang dipegang di sini (server menegakkan yang sama):
///  - titik TIDAK PERNAH dihapus; yang tersedia cuma nonaktif dengan alasan;
///  - nominal unik dalam satu sesi;
///  - [revisi] = revisi server yang jadi dasar perubahan lokal. Konflik (409)
///    tidak pernah diselesaikan otomatis dengan revisi baru.
class TitikSesiState {
  BatasTitik? _batas;

  /// Batas yang berlaku. Dari sesi (`meta.titik_sesi.batas`) kalau ada —
  /// dihitung server dengan spesifikasi sesi itu — atau dari lembar kosong.
  BatasTitik? get batas => _batas;

  List<TitikSesi> _titik = const [];

  /// Seluruh titik, urut set (aktif dan nonaktif).
  List<TitikSesi> get titik => List.unmodifiable(_titik);

  /// Revisi server yang jadi dasar kiriman berikutnya. Sesi baru: 0.
  int revisi = 0;

  /// Pengulangan tersimpan per tabel (informasi; yang dikirim dihitung ulang
  /// dari jumlah kolom lembar).
  Map<String, int> pengulanganTersimpan = const {};

  /// Id titik yang sudah ada di server — tidak boleh hilang dari kiriman.
  Set<String> _idTersimpan = {};

  /// Id titik aktif di luar cakupan CMC (dari server, pada muatan terakhir).
  List<String> diLuarCmc = const [];

  /// Set datang dari server (`meta.titik_sesi.set` bukan null).
  bool dariServer = false;

  /// Teknisi sudah mengubah set di perangkat ini sejak muatan terakhir.
  bool diubahLokal = false;

  bool get didukung => _batas?.didukung ?? false;

  bool get kosong => _titik.isEmpty;

  bool idTersimpan(String id) => _idTersimpan.contains(id);

  TitikSesi? titikDenganNominal(double nominal) {
    for (final t in _titik) {
      if (nominalCocok(t.nominal, nominal)) return t;
    }
    return null;
  }

  TitikSesi? titikDenganId(String id) {
    for (final t in _titik) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Titik bernominal [nominal] ada di set dan NONAKTIF.
  bool nonaktif(double nominal) => titikDenganNominal(nominal)?.aktif == false;

  List<TitikSesi> titikTabel(String kode) => [
    for (final t in _titik)
      if (t.tabel == kode) t,
  ];

  int jumlahAktif(String kode) => titikTabel(kode).where((t) => t.aktif).length;

  /// Titik ini titik PERTAMA tabelnya dan tabelnya mewajibkan dia aktif.
  bool pertamaTerkunci(TitikSesi t) {
    final b = _batas?.tabelUntuk(t.tabel);
    if (b == null || !b.pertamaWajibAktif) return false;
    final daftar = titikTabel(t.tabel);
    return daftar.isNotEmpty && daftar.first.id == t.id;
  }

  // ------------------------------------------------------------ memuat

  /// Pasang batas dari LEMBAR KOSONG (`batas_titik` + `titik_sesi_bawaan`).
  ///
  /// Set tidak diganti kalau sudah datang dari server atau sudah diubah
  /// teknisi — bentuk lembar ditarik ulang berkali-kali (ganti alat, kembali
  /// ke depan), dan menimpa set di sana berarti membuang keputusan teknisi.
  void pasangBatasLembar(BatasTitik? batas, List<TitikSesi> bawaan) {
    // Batas sesi (dari server) lebih tepat — dihitung dengan spesifikasi
    // sesinya — jadi cuma diisi dari lembar kalau belum ada.
    if (!dariServer || _batas == null) _batas = batas;

    if (dariServer || diubahLokal) return;
    _titik = (batas?.didukung ?? false) ? List.of(bawaan) : const [];
    revisi = 0;
    _idTersimpan = {};
  }

  /// Muat dari `meta.titik_sesi` sesi yang dibuka ulang.
  void muatMeta(MetaTitikSesi meta) {
    _batas = meta.batas;
    diLuarCmc = List.of(meta.diLuarCmc);

    final set = meta.set;
    if (set != null) {
      _gantiSet(set);
      dariServer = true;
    } else {
      _titik = meta.batas.didukung
          ? List.of(meta.bawaan ?? const [])
          : const [];
      revisi = 0;
      _idTersimpan = {};
      pengulanganTersimpan = const {};
      dariServer = false;
    }
    diubahLokal = false;
  }

  /// Ganti set lokal dengan set terbaru server — dipakai sesudah 409 dan
  /// sesudah simpan sukses. Perubahan lokal yang belum tersimpan DIBUANG
  /// (teknisi diminta mengulangnya); pembacaan di tabel tidak disentuh di
  /// sini.
  void gantiDariServer(SetTitikSesi set, {List<String>? diLuarCmc}) {
    _gantiSet(set);
    dariServer = true;
    diubahLokal = false;
    if (diLuarCmc != null) this.diLuarCmc = List.of(diLuarCmc);
  }

  /// Tambahkan kembali titik lokal (belum tersimpan) yang sudah berisi
  /// pembacaan, sesudah set diganti dari server. Nominal yang sudah ada di
  /// set server dilewat.
  void pertahankanTitikLokal(Iterable<TitikSesi> lokal) {
    final tambah = [
      for (final t in lokal)
        if (titikDenganId(t.id) == null &&
            titikDenganNominal(t.nominal) == null)
          t,
    ];
    if (tambah.isEmpty) return;
    _titik = [..._titik, ...tambah];
    diubahLokal = true;
  }

  void _gantiSet(SetTitikSesi set) {
    _titik = List.of(set.titik);
    revisi = set.revisi;
    pengulanganTersimpan = Map.of(set.pengulangan);
    _idTersimpan = {for (final t in set.titik) t.id};
  }

  // ------------------------------------------------------------ mengubah

  GalatTitikSesi? _periksaAlasan(String? alasan) =>
      (alasan?.trim().length ?? 0) < alasanTitikMinimal
      ? GalatTitikSesi.alasanPendek
      : null;

  /// Tambah titik baru. [fase] null = `['sesudah']`.
  GalatTitikSesi? tambah({
    required String tabel,
    required double nominal,
    AsalTitik asal = AsalTitik.teknisi,
    String? alasan,
    bool denganSebelum = false,
    String? id,
  }) {
    final b = _batas?.tabelUntuk(tabel);
    if (b == null) return GalatTitikSesi.tabelTidakAda;
    if (!b.bolehTambah) return GalatTitikSesi.tidakBolehTambah;
    if (titikDenganNominal(nominal) != null) {
      return GalatTitikSesi.nominalKembar;
    }
    if (_titik.length >= titikSesiMaksTotal) return GalatTitikSesi.totalPenuh;
    if (jumlahAktif(tabel) >= b.maks) return GalatTitikSesi.aktifPenuh;
    if (asal == AsalTitik.pelanggan && _periksaAlasan(alasan) != null) {
      return GalatTitikSesi.alasanPelanggan;
    }
    if (denganSebelum && !b.bolehFaseSebelum) {
      return GalatTitikSesi.faseTidakBoleh;
    }

    final baru = TitikSesi(
      id: id ?? generateUuidV4(),
      tabel: tabel,
      nominal: nominal,
      satuan: b.satuan,
      fase: denganSebelum ? const ['sebelum', 'sesudah'] : const ['sesudah'],
      asal: asal == AsalTitik.profil ? AsalTitik.teknisi : asal,
      alasan: alasan?.trim().isEmpty ?? true ? null : alasan!.trim(),
    );

    _titik = _sisipkan(baru, b);
    diubahLokal = true;
    return null;
  }

  /// Titik baru disisipkan urut naik kalau titik tabelnya memang urut naik
  /// (Timer, pH, …) — sertifikat mencetak titik menurut urutan set. Tabel
  /// yang titik pertamanya dikunci (Tekanan) tidak pernah disisipi di depan.
  List<TitikSesi> _sisipkan(TitikSesi baru, TabelBatasTitik b) {
    final hasil = List.of(_titik);
    final milikTabel = [
      for (var i = 0; i < hasil.length; i++)
        if (hasil[i].tabel == baru.tabel) i,
    ];

    if (milikTabel.isEmpty) return hasil..add(baru);

    var urutNaik = true;
    for (var k = 1; k < milikTabel.length; k++) {
      if (hasil[milikTabel[k]].nominal < hasil[milikTabel[k - 1]].nominal) {
        urutNaik = false;
        break;
      }
    }

    if (urutNaik) {
      for (var k = 0; k < milikTabel.length; k++) {
        if (k == 0 && b.pertamaWajibAktif) continue;
        final i = milikTabel[k];
        if (hasil[i].nominal > baru.nominal) {
          hasil.insert(i, baru);
          return hasil;
        }
      }
    }

    hasil.insert(milikTabel.last + 1, baru);
    return hasil;
  }

  void _ganti(TitikSesi baru) {
    _titik = [
      for (final t in _titik)
        if (t.id == baru.id) baru else t,
    ];
    diubahLokal = true;
  }

  /// Ubah nominal titik yang BELUM punya pembacaan.
  GalatTitikSesi? ubahNominal(
    String id,
    double nominal, {
    required bool punyaPembacaan,
  }) {
    final t = titikDenganId(id);
    if (t == null) return GalatTitikSesi.titikTidakAda;
    if (nominalCocok(t.nominal, nominal)) return null;

    final b = _batas?.tabelUntuk(t.tabel);
    if (b == null) return GalatTitikSesi.tabelTidakAda;
    if (punyaPembacaan) return GalatTitikSesi.punyaPembacaan;
    if (b.nominal == JenisNominal.dipatok) return GalatTitikSesi.nominalDipatok;
    if (titikDenganNominal(nominal) != null) {
      return GalatTitikSesi.nominalKembar;
    }

    _ganti(t.salin(nominal: nominal));
    return null;
  }

  /// Nonaktifkan dengan alasan. Pembacaannya TIDAK disentuh.
  GalatTitikSesi? nonaktifkan(String id, String alasan) {
    final t = titikDenganId(id);
    if (t == null) return GalatTitikSesi.titikTidakAda;
    if (!t.aktif) return null;

    final b = _batas?.tabelUntuk(t.tabel);
    if (b == null) return GalatTitikSesi.tabelTidakAda;
    if (!b.bolehNonaktif) return GalatTitikSesi.tidakBolehNonaktif;
    if (pertamaTerkunci(t)) return GalatTitikSesi.pertamaTerkunci;
    if (_periksaAlasan(alasan) case final g?) return g;
    if (jumlahAktif(t.tabel) <= b.min) return GalatTitikSesi.aktifMinimum;

    _ganti(t.salin(aktif: false, alasan: alasan.trim()));
    return null;
  }

  /// Aktifkan lagi titik nonaktif. Alasan titik teknisi dibersihkan;
  /// titik pelanggan tetap wajib beralasan, jadi alasannya dibiarkan.
  GalatTitikSesi? aktifkan(String id) {
    final t = titikDenganId(id);
    if (t == null) return GalatTitikSesi.titikTidakAda;
    if (t.aktif) return null;

    final b = _batas?.tabelUntuk(t.tabel);
    if (b == null) return GalatTitikSesi.tabelTidakAda;
    if (jumlahAktif(t.tabel) >= b.maks) return GalatTitikSesi.aktifPenuh;

    _ganti(t.salin(aktif: true, hapusAlasan: t.asal != AsalTitik.pelanggan));
    return null;
  }

  /// Isi / kosongkan justifikasi CMC satu titik.
  GalatTitikSesi? aturJustifikasiCmc(String id, String? teks) {
    final t = titikDenganId(id);
    if (t == null) return GalatTitikSesi.titikTidakAda;
    final isi = teks?.trim() ?? '';

    _ganti(
      isi.isEmpty
          ? t.salin(hapusJustifikasi: true)
          : t.salin(justifikasiCmc: isi),
    );
    return null;
  }

  /// Pastikan titik yang punya pembacaan as-found memilih fase `sebelum`
  /// (server menolak pembacaan `sebelum_adjustment` untuk titik tanpa fase
  /// itu). Cuma di tabel yang memang membolehkan fase itu.
  void pastikanFaseSebelum(Iterable<double> nominalBerSebelum) {
    var berubah = false;
    final baru = <TitikSesi>[];

    for (final t in _titik) {
      final perlu =
          !t.denganSebelum &&
          (_batas?.tabelUntuk(t.tabel)?.bolehFaseSebelum ?? false) &&
          nominalBerSebelum.any((n) => nominalCocok(n, t.nominal));
      if (perlu) {
        baru.add(t.salin(fase: const ['sebelum', 'sesudah']));
        berubah = true;
      } else {
        baru.add(t);
      }
    }

    if (berubah) {
      _titik = baru;
      diubahLokal = true;
    }
  }

  /// Selaraskan titik tabel [kode] dengan set point yang DIKETIK di baris
  /// lembar (Tekanan: nominal `bebas`, satu baris = satu titik), urut baris.
  ///
  ///  - nominal yang sudah ada di set → titiknya dipakai (status aktif/alasan
  ///    tetap);
  ///  - nominal baru → titik tanpa pembacaan yang tidak lagi diketik di baris
  ///    mana pun dipakai ulang (id tetap, nominal ganti); kalau tidak ada,
  ///    titik baru `asal: teknisi`;
  ///  - titik yang tidak diketik lagi: yang sudah tersimpan di server tetap
  ///    ikut (titik tidak pernah dihapus), yang baru lahir di HP dibuang.
  ///
  /// Urutan set = urutan baris, jadi titik pertama set = baris pertama.
  void selaraskanDariBaris(
    String kode,
    List<double> urutan, {
    required bool Function(double nominal) punyaPembacaan,
  }) {
    final b = _batas?.tabelUntuk(kode);
    if (b == null) return;

    final milik = titikTabel(kode);
    final terpakai = <String>{};
    final cocok = <TitikSesi?>[];

    for (final v in urutan) {
      TitikSesi? ketemu;
      for (final t in milik) {
        if (!terpakai.contains(t.id) && nominalCocok(t.nominal, v)) {
          ketemu = t;
          break;
        }
      }
      if (ketemu != null) terpakai.add(ketemu.id);
      cocok.add(ketemu);
    }

    final hasilTabel = <TitikSesi>[];
    for (var i = 0; i < urutan.length; i++) {
      final ada = cocok[i];
      if (ada != null) {
        hasilTabel.add(ada);
        continue;
      }

      // Kembar di dalam baris yang diketik — nominal wajib unik; baris kedua
      // dibiarkan ditolak server, bukan dikarang jadi titik lain.
      if (hasilTabel.any((t) => nominalCocok(t.nominal, urutan[i]))) continue;

      TitikSesi? pakaiUlang;
      for (final t in milik) {
        if (terpakai.contains(t.id) || !t.aktif) continue;
        if (punyaPembacaan(t.nominal)) continue;
        if (b.nominal == JenisNominal.dipatok) continue;
        pakaiUlang = t;
        break;
      }

      if (pakaiUlang != null) {
        terpakai.add(pakaiUlang.id);
        hasilTabel.add(pakaiUlang.salin(nominal: urutan[i]));
      } else {
        hasilTabel.add(
          TitikSesi(
            id: generateUuidV4(),
            tabel: kode,
            nominal: urutan[i],
            satuan: b.satuan,
          ),
        );
      }
    }

    // Titik yang tidak diketik lagi.
    for (final t in milik) {
      if (terpakai.contains(t.id)) continue;
      if (_idTersimpan.contains(t.id)) hasilTabel.add(t);
    }

    // Sisipkan kembali di posisi tabel ini di set (tabel lain tidak disentuh).
    final baru = <TitikSesi>[];
    var sudah = false;
    for (final t in _titik) {
      if (t.tabel != kode) {
        baru.add(t);
        continue;
      }
      if (!sudah) {
        baru.addAll(hasilTabel);
        sudah = true;
      }
    }
    if (!sudah) baru.addAll(hasilTabel);

    if (!_samaIsi(baru, _titik)) {
      _titik = baru;
      diubahLokal = true;
    }
  }

  static bool _samaIsi(List<TitikSesi> a, List<TitikSesi> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i].toJson();
      final y = b[i].toJson();
      if (x.toString() != y.toString()) return false;
    }
    return true;
  }

  // ------------------------------------------------------------ mengirim

  /// Badan `titik_sesi` untuk `POST`/`PUT`/`preview`. `null` kalau lembar ini
  /// tidak mendukung titik sesi atau setnya masih kosong (server menolak
  /// `titik` kosong; tanpa kunci, set tersimpan tidak diubah).
  Map<String, dynamic>? payload({Map<String, int?> pengulangan = const {}}) {
    if (!didukung || _titik.isEmpty) return null;

    return {
      'revisi': revisi,
      'titik': [for (final t in _titik) t.toJson()],
      if (pengulangan.isNotEmpty) 'pengulangan': pengulangan,
    };
  }

  // ------------------------------------------------------------ salinan HP

  Map<String, dynamic> salinanLokal() => {
    'revisi': revisi,
    'titik': [for (final t in _titik) t.toJson()],
    'id_tersimpan': [..._idTersimpan],
    'di_luar_cmc': diLuarCmc,
    'dari_server': dariServer,
    'diubah_lokal': diubahLokal,
  };

  /// Pulihkan dari [salinanLokal]. Batas tidak ikut disalin — dia datang lagi
  /// dari bentuk lembar / sesi.
  void pulihkanSalinan(Object? s) {
    if (s is! Map) return;
    final tabelTunggal = (_batas?.tabel.length ?? 0) == 1
        ? _batas!.tabel.first.kode
        : null;

    _titik = parseTitikSesi(s['titik'], tabelBawaan: tabelTunggal);
    revisi = (s['revisi'] as num?)?.toInt() ?? 0;
    _idTersimpan = {
      if (s['id_tersimpan'] is List)
        for (final id in s['id_tersimpan'] as List)
          if (id is String) id,
    };
    diLuarCmc = [
      if (s['di_luar_cmc'] is List)
        for (final id in s['di_luar_cmc'] as List)
          if (id is String) id,
    ];
    dariServer = s['dari_server'] == true;
    diubahLokal = s['diubah_lokal'] == true;
  }
}
