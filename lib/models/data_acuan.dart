/// Model Studio Data Acuan (CR-48) — bentuk respons `docs/kontrak-api.md` §15
/// (repo API), tujuh rute baca `GET /api/data-acuan/*`.
///
/// Data acuan = lapis 1 olah data (tabel balok ukur, pita CMC, konstanta
/// metode) yang sekarang berversi di server. **HP tidak menghitung apa pun dari
/// sini.** Nilai sel disimpan APA ADANYA (`num`/`String`/`List`/`null`):
/// server meng-encode dengan `JSON_PRESERVE_ZERO_FRACTION`, jadi `20.0` datang
/// sebagai `double` dan `200` sebagai `int` — dan isi kanonik membedakan
/// keduanya (tipe itu sampai ke calculator). Pembulatan cuma urusan tampilan.
///
/// ## Kunci yang tidak dikirim ke teknisi
///
/// Teknisi cuma melihat versi `aktif`. Daftar & detail paket untuknya TIDAK
/// membawa `versi_terjadwal`, `jumlah_draf`, `jumlah_diajukan` — kuncinya tidak
/// ada, bukan `null`. Di sini ketiganya nullable: `null` = "server tidak
/// mengatakan apa-apa", BUKAN nol. Layar yang membacanya sebagai nol bakal
/// menulis "0 draf" ke teknisi yang memang tidak boleh tahu jumlahnya.
///
/// Penyembunyian tombol di HP cuma kenyamanan — aturan siapa melihat apa
/// ditegakkan server (404 untuk versi non-aktif, banding, dan riwayat sel).
library;

import '../core/utils/parse_list.dart';

/// Status satu versi data acuan (`PaketAcuanVersi::STATUS_*` di server).
enum StatusVersiAcuan {
  draf('draf'),
  diajukan('diajukan'),
  terjadwal('terjadwal'),
  aktif('aktif'),
  pensiun('pensiun'),
  ditolak('ditolak'),
  ditarik('ditarik'),
  dibuang('dibuang'),

  /// Status yang belum dikenal aplikasi ini (server lebih baru). Kode
  /// mentahnya tetap tersimpan di `kodeStatus` model pemiliknya.
  tidakDikenal('');

  const StatusVersiAcuan(this.kode);

  final String kode;

  static StatusVersiAcuan dariKode(Object? nilai) {
    final kode = '${nilai ?? ''}'.trim().toLowerCase();

    return StatusVersiAcuan.values.firstWhere(
      (s) => s != tidakDikenal && s.kode == kode,
      orElse: () => tidakDikenal,
    );
  }
}

/// Jenis lembar skema: menentukan cara membaca baris & kunci baris.
enum JenisLembarAcuan {
  /// Satu baris, kuncinya `0`.
  objek('objek'),

  /// Peta kunci → nilai; kunci baris = kunci peta (`1.0`, `101.6`, `200`).
  baris('baris'),

  /// List objek; kunci baris = nilai kolom kunci, atau posisi mulai `0`.
  daftar('daftar'),

  tidakDikenal('');

  const JenisLembarAcuan(this.kode);

  final String kode;

  static JenisLembarAcuan dariKode(Object? nilai) {
    final kode = '${nilai ?? ''}'.trim().toLowerCase();

    return JenisLembarAcuan.values.firstWhere(
      (j) => j != tidakDikenal && j.kode == kode,
      orElse: () => tidakDikenal,
    );
  }
}

int? _bulat(Object? nilai) => switch (nilai) {
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

String? _teks(Object? nilai) => nilai == null ? null : '$nilai';

/// Tanggal `YYYY-MM-DD` atau ISO-8601. `null` bila kosong/tak terbaca.
DateTime? _tanggal(Object? nilai) =>
    nilai is String && nilai.isNotEmpty ? DateTime.tryParse(nilai) : null;

Map<String, dynamic>? _peta(Object? nilai) => switch (nilai) {
  final Map<String, dynamic> m => m,
  final Map m => Map<String, dynamic>.from(m),
  _ => null,
};

/// Versi dalam bentuk ringkas — `versi_aktif`, `versi_terjadwal[]`, `lama`/
/// `baru` di banding, dan `versi` di riwayat sel
/// (`PaketAcuanVersiResource::ringkas`).
///
/// Kunci hash-nya `sha256` (bukan `isi_sha256` seperti bentuk lengkap).
class RingkasanVersiAcuan {
  const RingkasanVersiAcuan({
    required this.id,
    required this.nomor,
    required this.kodeStatus,
    this.berlakuMulai,
    this.berlakuSampai,
    this.sha256,
  });

  final int id;
  final int nomor;

  /// Kode status mentah dari server.
  final String kodeStatus;

  final DateTime? berlakuMulai;

  /// `null` = masih berlaku tanpa batas akhir.
  final DateTime? berlakuSampai;

  /// `null` = draf yang isinya belum dikunci.
  final String? sha256;

  StatusVersiAcuan get status => StatusVersiAcuan.dariKode(kodeStatus);

  factory RingkasanVersiAcuan.fromJson(Map<String, dynamic> json) =>
      RingkasanVersiAcuan(
        id: _bulat(json['id']) ?? 0,
        nomor: _bulat(json['nomor']) ?? 0,
        kodeStatus: '${json['status'] ?? ''}',
        berlakuMulai: _tanggal(json['berlaku_mulai']),
        berlakuSampai: _tanggal(json['berlaku_sampai']),
        sha256: _teks(json['sha256']),
      );

  static RingkasanVersiAcuan? dariJson(Object? nilai) {
    final m = _peta(nilai);
    return m == null ? null : RingkasanVersiAcuan.fromJson(m);
  }
}

/// Satu kolom di lembar skema (`skemaAcuan()` profil di server).
class KolomSkemaAcuan {
  const KolomSkemaAcuan({
    required this.kode,
    required this.label,
    required this.tipe,
    this.satuan,
    this.asal,
    this.perluKonfirmasi = false,
  });

  final String kode;
  final String label;

  /// Tipe mentah: `teks`, `desimal`, `bulat`, `tanggal`, `daftar_angka`.
  /// Disimpan sebagai teks supaya tipe baru dari server tidak meledakkan
  /// parsing.
  final String tipe;

  final String? satuan;

  /// Alamat sel master (`Standar_GB!R10:R132`). `null` = angka telanjang di
  /// rumus master atau disalin dari kertas, bukan dari sel.
  final String? asal;

  /// Nilai ini perlu konfirmasi lab (asal-usulnya belum dibuktikan).
  final bool perluKonfirmasi;

  factory KolomSkemaAcuan.fromJson(Map<String, dynamic> json) =>
      KolomSkemaAcuan(
        kode: '${json['kode'] ?? ''}',
        label: '${json['label'] ?? json['kode'] ?? ''}',
        tipe: '${json['tipe'] ?? ''}',
        satuan: _teks(json['satuan']),
        asal: _teks(json['asal']),
        perluKonfirmasi: json['perlu_konfirmasi'] == true,
      );
}

/// Satu lembar skema — tab di layar Studio. Tab digambar dari sini, bukan
/// dari `if` per alat.
class LembarSkemaAcuan {
  const LembarSkemaAcuan({
    required this.kode,
    required this.label,
    required this.kodeJenis,
    required this.kolom,
    this.jalur,
    this.kunci,
    this.bolehTambahBaris = false,
  });

  final String kode;
  final String label;

  /// Letak lembar di dalam `isi` (dipisah `/`, `*` = tiap elemen induk).
  final String? jalur;

  /// Kode jenis mentah; lihat [jenis].
  final String kodeJenis;

  /// Kode kolom kunci baris. `null` = tanpa kunci (objek, atau daftar yang
  /// dikunci posisi).
  final String? kunci;

  final List<KolomSkemaAcuan> kolom;
  final bool bolehTambahBaris;

  JenisLembarAcuan get jenis => JenisLembarAcuan.dariKode(kodeJenis);

  factory LembarSkemaAcuan.fromJson(Map<String, dynamic> json) =>
      LembarSkemaAcuan(
        kode: '${json['kode'] ?? ''}',
        label: '${json['label'] ?? json['kode'] ?? ''}',
        jalur: _teks(json['jalur']),
        kodeJenis: '${json['jenis'] ?? ''}',
        kunci: _teks(json['kunci']),
        kolom: parseListAman(json['kolom'], KolomSkemaAcuan.fromJson),
        bolehTambahBaris: json['boleh_tambah_baris'] == true,
      );
}

/// Kunci baris lembar berjenis `objek` (satu-satunya barisnya).
const kunciObjekAcuan = '0';

/// Pemisah awalan elemen induk (`*` di jalur) dari kunci baris: titik
/// pra-cetak varian ke-2 baris ke-4 = `1:3`. Bukan `/`, karena kunci baris
/// masuk ke path URL rute riwayat sel.
const pemisahIndukAcuan = ':';

/// Baris satu lembar dari isi versi: kunci baris → (kode kolom → nilai).
///
/// Port SATU-SATU `App\Services\Acuan\SelAcuan::baris()` di server — kunci
/// yang dihasilkan di sini dipakai apa adanya di rute
/// `sel/{lembar}/{kunci}/{kolom}/riwayat`, jadi aturannya tidak boleh
/// berbeda dari server:
///
///  - `objek`  → satu baris berkunci [kunciObjekAcuan];
///  - `baris`  → kunci peta sebagai teks (`1.0`, `101.6`, `200`); kolom
///    [LembarSkemaAcuan.kunci] diisi kunci itu (TEKS, seperti di server);
///  - `daftar` → nilai kolom kunci (skalar) sebagai teks, atau POSISI mulai
///    `0` kalau tanpa kunci;
///  - segmen `*` di jalur memberi awalan kunci/posisi induk + [pemisahIndukAcuan].
///
/// Kolom yang tidak ada di isi TIDAK muncul (beda dari kolom bernilai
/// `null`). Nilai dikembalikan apa adanya — tidak dibulatkan, tipenya tidak
/// diubah. Urutan baris = urutan di isi (isi kanonik = kunci terurut teks).
///
/// HP tidak menghitung apa pun dari sini; fungsi ini cuma menavigasi isi.
Map<String, Map<String, Object?>> barisLembarAcuan(
  LembarSkemaAcuan lembar,
  Object? isi,
) {
  final kolom = [for (final k in lembar.kolom) k.kode];
  final kunciKolom = lembar.kunci;
  final hasil = <String, Map<String, Object?>>{};

  for (final MapEntry(key: awalan, value: simpul) in _simpulAcuan(
    isi,
    lembar.jalur ?? '',
  ).entries) {
    // PHP: `is_array` — objek JSON maupun list.
    if (simpul is! Map && simpul is! List) continue;

    switch (lembar.jenis) {
      case JenisLembarAcuan.objek:
        hasil[_gabungKunci(awalan, kunciObjekAcuan)] = _ambilKolom(
          simpul!,
          kolom,
        );

      case JenisLembarAcuan.baris:
        final kolomNilai = [
          for (final k in kolom)
            if (k != kunciKolom) k,
        ];
        for (final MapEntry(key: k, value: nilai) in _entri(simpul!)) {
          final sel = <String, Object?>{?kunciKolom: k};
          if (nilai is Map) {
            sel.addAll(_ambilKolom(nilai, kolomNilai));
          } else if (kolomNilai.length == 1) {
            sel[kolomNilai.single] = nilai;
          }
          hasil[_gabungKunci(awalan, k)] = sel;
        }

      case JenisLembarAcuan.daftar:
        // PHP: `array_is_list` — hanya list JSON.
        if (simpul is! List) break;
        for (var posisi = 0; posisi < simpul.length; posisi++) {
          final obj = simpul[posisi];
          if (obj is! Map && obj is! List) continue;

          final nilaiKunci = kunciKolom != null && obj is Map
              ? obj[kunciKolom]
              : null;
          final k = _teksSkalarPhp(nilaiKunci) ?? '$posisi';

          hasil[_gabungKunci(awalan, k)] = _ambilKolom(obj!, kolom);
        }

      case JenisLembarAcuan.tidakDikenal:
        break;
    }
  }

  return hasil;
}

String _gabungKunci(String awalan, String kunci) =>
    awalan.isEmpty ? kunci : '$awalan$pemisahIndukAcuan$kunci';

/// Entri map, atau (posisi → elemen) untuk list — padanan `foreach` PHP.
Iterable<MapEntry<String, Object?>> _entri(Object simpul) => switch (simpul) {
  final Map m => [for (final e in m.entries) MapEntry('${e.key}', e.value)],
  final List l => [for (var i = 0; i < l.length; i++) MapEntry('$i', l[i])],
  _ => const [],
};

/// Padanan `array_key_exists` + ambil, untuk kolom yang ada saja.
Map<String, Object?> _ambilKolom(Object obj, List<String> kolom) {
  final peta = {for (final e in _entri(obj)) e.key: e.value};
  return {
    for (final k in kolom)
      if (peta.containsKey(k)) k: peta[k],
  };
}

/// Simpul di [jalur] (dipisah `/`, `*` = tiap elemen induk), dikunci awalan
/// induknya (`''` bila jalurnya tanpa `*`). Padanan `SelAcuan::simpul()`.
Map<String, Object?> _simpulAcuan(Object? isi, String jalur) {
  var simpul = <String, Object?>{'': isi};

  for (final segmen in jalur.split('/')) {
    final lanjut = <String, Object?>{};

    for (final MapEntry(key: awalan, value: node) in simpul.entries) {
      if (node is! Map && node is! List) continue;

      if (segmen == '*') {
        for (final e in _entri(node!)) {
          lanjut[_gabungKunci(awalan, e.key)] = e.value;
        }
      } else {
        for (final e in _entri(node!)) {
          if (e.key == segmen) {
            lanjut[awalan] = e.value;
            break;
          }
        }
      }
    }

    simpul = lanjut;
  }

  return simpul;
}

/// `(string)` PHP untuk nilai skalar (`is_scalar`), atau `null` bila bukan
/// skalar (null, list, objek) — server lalu jatuh ke posisi baris.
///
/// Float bulat ditulis tanpa `.0` (`(string) 25.0` = `"25"` di PHP).
/// ⚠ Satu beda yang disadari: PHP memakai `precision` 14 angka penting untuk
/// float tak bulat, Dart memakai representasi terpendek. Baru berbeda untuk
/// float ber-15+ angka penting di kolom KUNCI daftar — tidak ada di skema mana
/// pun hari ini (kunci daftar Micrometer = `kode` teks).
String? _teksSkalarPhp(Object? nilai) => switch (nilai) {
  final String s => s,
  final int n => '$n',
  final bool b => b ? '1' : '',
  final double d when d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15 =>
    '${d.toInt()}',
  final double d => '$d',
  _ => null,
};

/// Skema data acuan satu profil.
class SkemaAcuan {
  const SkemaAcuan({
    required this.skemaVersi,
    required this.lembar,
    this.sumberJson,
  });

  final int skemaVersi;

  /// Berkas JSON repo yang menjadi versi 1 (`tabel-standar-micrometer.json`).
  final String? sumberJson;

  final List<LembarSkemaAcuan> lembar;

  factory SkemaAcuan.fromJson(Map<String, dynamic> json) => SkemaAcuan(
    skemaVersi: _bulat(json['skema_versi']) ?? 0,
    sumberJson: _teks(json['sumber_json']),
    lembar: parseListAman(json['lembar'], LembarSkemaAcuan.fromJson),
  );
}

/// Satu paket data acuan — baris `GET /data-acuan/paket` atau detail
/// `GET /data-acuan/paket/{kode}` (detail: + [skema], + [jumlahDiajukan]).
class PaketAcuan {
  const PaketAcuan({
    required this.kode,
    required this.nama,
    required this.skemaVersi,
    required this.diimpor,
    this.versiAktif,
    this.versiTerjadwal,
    this.jumlahDraf,
    this.jumlahDiajukan,
    this.skema,
  });

  /// Kode profil (`micrometer`) — juga kunci rute paket.
  final String kode;
  final String nama;
  final int? skemaVersi;

  /// `false` = profil punya skema, tapi lab ini belum mengimpornya. Tampil
  /// abu-abu "belum diimpor"; detailnya `404`.
  final bool diimpor;

  /// Versi `data` yang berlaku HARI INI, atau `null`.
  final RingkasanVersiAcuan? versiAktif;

  /// `null` = kunci tidak dikirim (teknisi). List kosong = memang tidak ada.
  final List<RingkasanVersiAcuan>? versiTerjadwal;

  /// `null` = kunci tidak dikirim (teknisi), BUKAN nol.
  final int? jumlahDraf;

  /// Hanya di detail, dan tidak untuk teknisi.
  final int? jumlahDiajukan;

  /// Hanya di detail paket.
  final SkemaAcuan? skema;

  factory PaketAcuan.fromJson(Map<String, dynamic> json) {
    final skema = _peta(json['skema']);

    return PaketAcuan(
      kode: '${json['kode'] ?? ''}',
      nama: '${json['nama'] ?? json['kode'] ?? ''}',
      skemaVersi: _bulat(json['skema_versi']),
      diimpor: json['diimpor'] == true,
      versiAktif: RingkasanVersiAcuan.dariJson(json['versi_aktif']),
      versiTerjadwal: json.containsKey('versi_terjadwal')
          ? parseListAman(json['versi_terjadwal'], RingkasanVersiAcuan.fromJson)
          : null,
      jumlahDraf: _bulat(json['jumlah_draf']),
      jumlahDiajukan: _bulat(json['jumlah_diajukan']),
      skema: skema == null ? null : SkemaAcuan.fromJson(skema),
    );
  }
}

/// Satu entri `rujukan` versi (`{jenis, nilai, catatan}`).
class RujukanVersiAcuan {
  const RujukanVersiAcuan({required this.jenis, this.nilai, this.catatan});

  /// Mis. `berkas_repo`.
  final String jenis;
  final String? nilai;
  final String? catatan;

  factory RujukanVersiAcuan.fromJson(Map<String, dynamic> json) =>
      RujukanVersiAcuan(
        jenis: '${json['jenis'] ?? ''}',
        nilai: _teks(json['nilai']),
        catatan: _teks(json['catatan']),
      );
}

/// Satu versi lengkap — garis waktu, `berlaku`, dan `GET /data-acuan/versi/{id}`
/// (yang terakhir membawa [isi]).
class VersiAcuan {
  const VersiAcuan({
    required this.id,
    required this.jenis,
    required this.nomor,
    required this.kodeStatus,
    this.paket,
    this.skemaVersi,
    this.dasarVersiId,
    this.berlakuMulai,
    this.berlakuSampai,
    this.isiSha256,
    this.alasan,
    this.rujukan = const [],
    this.catatanKeputusan,
    this.dibuatOleh,
    this.diajukanOleh,
    this.diajukanPada,
    this.disahkanOleh,
    this.disahkanPada,
    this.ditolakOleh,
    this.ditolakPada,
    this.lockVersi,
    this.dibuatPada,
    this.diubahPada,
    this.isi,
  });

  final int id;

  /// Kode paket (`micrometer`). Bisa `null` bila server tidak memuat paketnya.
  final String? paket;

  /// `data` atau `bentuk`.
  final String jenis;

  final int nomor;
  final String kodeStatus;
  final int? skemaVersi;
  final int? dasarVersiId;
  final DateTime? berlakuMulai;
  final DateTime? berlakuSampai;

  /// `null` = draf yang isinya belum dikunci.
  final String? isiSha256;

  final String? alasan;
  final List<RujukanVersiAcuan> rujukan;
  final String? catatanKeputusan;

  /// `*_oleh` masih **id user** (kontrak §15), bukan nama. `null` di versi 1
  /// hasil impor: impor bukan pengesahan, dan tidak ada yang boleh mengarang
  /// persetujuan siapa pun.
  final int? dibuatOleh;
  final int? diajukanOleh;
  final DateTime? diajukanPada;
  final int? disahkanOleh;
  final DateTime? disahkanPada;
  final int? ditolakOleh;
  final DateTime? ditolakPada;
  final int? lockVersi;
  final DateTime? dibuatPada;
  final DateTime? diubahPada;

  /// Dokumen isi terurai APA ADANYA (objek tetap `Map`, angka tetap tipenya).
  /// Hanya ada di `GET /data-acuan/versi/{id}`; `null` di daftar.
  final Object? isi;

  StatusVersiAcuan get status => StatusVersiAcuan.dariKode(kodeStatus);

  bool get punyaIsi => isi != null;

  factory VersiAcuan.fromJson(Map<String, dynamic> json) => VersiAcuan(
    id: _bulat(json['id']) ?? 0,
    paket: _teks(json['paket']),
    jenis: '${json['jenis'] ?? 'data'}',
    nomor: _bulat(json['nomor']) ?? 0,
    kodeStatus: '${json['status'] ?? ''}',
    skemaVersi: _bulat(json['skema_versi']),
    dasarVersiId: _bulat(json['dasar_versi_id']),
    berlakuMulai: _tanggal(json['berlaku_mulai']),
    berlakuSampai: _tanggal(json['berlaku_sampai']),
    isiSha256: _teks(json['isi_sha256']),
    alasan: _teks(json['alasan']),
    rujukan: parseListAman(json['rujukan'], RujukanVersiAcuan.fromJson),
    catatanKeputusan: _teks(json['catatan_keputusan']),
    dibuatOleh: _bulat(json['dibuat_oleh']),
    diajukanOleh: _bulat(json['diajukan_oleh']),
    diajukanPada: _tanggal(json['diajukan_pada']),
    disahkanOleh: _bulat(json['disahkan_oleh']),
    disahkanPada: _tanggal(json['disahkan_pada']),
    ditolakOleh: _bulat(json['ditolak_oleh']),
    ditolakPada: _tanggal(json['ditolak_pada']),
    lockVersi: _bulat(json['lock_versi']),
    dibuatPada: _tanggal(json['created_at']),
    diubahPada: _tanggal(json['updated_at']),
    isi: json['isi'],
  );
}

/// Jawaban `GET /data-acuan/paket/{kode}/berlaku` — "sesi bertanggal X
/// dihitung pakai versi yang mana?".
///
/// `versi == null` itu jawaban SAH, bukan galat: tanggalnya bisa jatuh
/// sebelum versi pertama. [alasan] ditampilkan apa adanya — jangan diurai.
/// Untuk teknisi kalimatnya sengaja generik (tidak membocorkan versi
/// non-aktif).
class HasilBerlakuAcuan {
  const HasilBerlakuAcuan({this.versi, this.alasan});

  final VersiAcuan? versi;
  final String? alasan;

  factory HasilBerlakuAcuan.fromJson(Map<String, dynamic> json) {
    final data = _peta(json['data']);

    return HasilBerlakuAcuan(
      versi: data == null ? null : VersiAcuan.fromJson(data),
      alasan: _teks(json['alasan']),
    );
  }
}

/// Satu sel yang berubah di banding.
class SelBerubahAcuan {
  const SelBerubahAcuan({
    required this.lembar,
    required this.kunci,
    required this.kolom,
    this.lama,
    this.baru,
    this.punyaSelisih = false,
    this.selisihAbsolut,
    this.selisihRelatif,
  });

  final String lembar;
  final String kunci;
  final String kolom;

  /// Nilai apa adanya (tipe ikut JSON).
  final Object? lama;
  final Object? baru;

  /// Server hanya mengirim selisih bila lama & baru sama-sama angka.
  final bool punyaSelisih;

  /// `baru − lama`, BERTANDA, presisi penuh float apa adanya
  /// (`0.0019999999999988916`, bukan `0.002`). Format = urusan tampilan.
  final num? selisihAbsolut;

  /// Selisih ÷ |lama|. `null` walau [punyaSelisih] bila lama nol.
  final num? selisihRelatif;

  factory SelBerubahAcuan.fromJson(Map<String, dynamic> json) =>
      SelBerubahAcuan(
        lembar: '${json['lembar'] ?? ''}',
        kunci: '${json['kunci'] ?? ''}',
        kolom: '${json['kolom'] ?? ''}',
        lama: json['lama'],
        baru: json['baru'],
        punyaSelisih: json.containsKey('selisih_absolut'),
        selisihAbsolut: json['selisih_absolut'] is num
            ? json['selisih_absolut'] as num
            : null,
        selisihRelatif: json['selisih_relatif'] is num
            ? json['selisih_relatif'] as num
            : null,
      );
}

/// Baris yang ditambah/dihapus di banding: `{kunci, sel: {kolom: nilai}}`.
class BarisAcuan {
  const BarisAcuan({required this.kunci, this.sel = const {}});

  final String kunci;

  /// Kolom → nilai apa adanya. Kolom yang tidak ada di isi TIDAK muncul
  /// (beda dari kolom bernilai `null`).
  final Map<String, Object?> sel;

  factory BarisAcuan.fromJson(Map<String, dynamic> json) => BarisAcuan(
    kunci: '${json['kunci'] ?? ''}',
    sel: _peta(json['sel']) ?? const {},
  );
}

/// Banding satu lembar skema.
class LembarBandingAcuan {
  const LembarBandingAcuan({
    required this.kode,
    required this.label,
    this.selBerubah = const [],
    this.barisTambah = const [],
    this.barisHapus = const [],
  });

  final String kode;
  final String label;
  final List<SelBerubahAcuan> selBerubah;
  final List<BarisAcuan> barisTambah;
  final List<BarisAcuan> barisHapus;

  bool get berubah =>
      selBerubah.isNotEmpty || barisTambah.isNotEmpty || barisHapus.isNotEmpty;

  factory LembarBandingAcuan.fromJson(Map<String, dynamic> json) =>
      LembarBandingAcuan(
        kode: '${json['kode'] ?? ''}',
        label: '${json['label'] ?? json['kode'] ?? ''}',
        selBerubah: parseListAman(
          json['sel_berubah'],
          SelBerubahAcuan.fromJson,
        ),
        barisTambah: parseListAman(json['baris_tambah'], BarisAcuan.fromJson),
        barisHapus: parseListAman(json['baris_hapus'], BarisAcuan.fromJson),
      );
}

/// Ringkasan jumlah perubahan banding.
class RingkasanBandingAcuan {
  const RingkasanBandingAcuan({
    this.lembarBerubah = 0,
    this.selBerubah = 0,
    this.barisTambah = 0,
    this.barisHapus = 0,
  });

  final int lembarBerubah;
  final int selBerubah;
  final int barisTambah;
  final int barisHapus;

  factory RingkasanBandingAcuan.fromJson(Map<String, dynamic> json) =>
      RingkasanBandingAcuan(
        lembarBerubah: _bulat(json['lembar_berubah']) ?? 0,
        selBerubah: _bulat(json['sel_berubah']) ?? 0,
        barisTambah: _bulat(json['baris_tambah']) ?? 0,
        barisHapus: _bulat(json['baris_hapus']) ?? 0,
      );
}

/// Jawaban `GET /data-acuan/versi/{lama}/banding/{baru}` (FR-11). Bukan
/// untuk teknisi — server menjawab 404.
class BandingAcuan {
  const BandingAcuan({
    required this.paket,
    required this.lembar,
    required this.ringkasan,
    this.skemaVersi,
    this.lama,
    this.baru,
  });

  final String paket;
  final int? skemaVersi;
  final RingkasanVersiAcuan? lama;
  final RingkasanVersiAcuan? baru;

  /// SEMUA lembar skema, termasuk yang tidak berubah (list kosong).
  final List<LembarBandingAcuan> lembar;

  final RingkasanBandingAcuan ringkasan;

  factory BandingAcuan.fromJson(Map<String, dynamic> json) => BandingAcuan(
    paket: '${json['paket'] ?? ''}',
    skemaVersi: _bulat(json['skema_versi']),
    lama: RingkasanVersiAcuan.dariJson(json['lama']),
    baru: RingkasanVersiAcuan.dariJson(json['baru']),
    lembar: parseListAman(json['lembar'], LembarBandingAcuan.fromJson),
    ringkasan: RingkasanBandingAcuan.fromJson(
      _peta(json['ringkasan']) ?? const {},
    ),
  );
}

/// Nilai satu sel di satu versi (entri `riwayat`).
class NilaiSelPerVersi {
  const NilaiSelPerVersi({this.versi, this.ada = false, this.nilai});

  final RingkasanVersiAcuan? versi;

  /// `false` = sel ini tidak ada di versi itu (beda dari bernilai `null`).
  final bool ada;
  final Object? nilai;

  factory NilaiSelPerVersi.fromJson(Map<String, dynamic> json) =>
      NilaiSelPerVersi(
        versi: RingkasanVersiAcuan.dariJson(json['versi']),
        ada: json['ada'] == true,
        nilai: json['nilai'],
      );
}

/// Satu suntingan sel (jejak audit: siapa, kapan, lama → baru, alasan).
class SuntinganSelAcuan {
  const SuntinganSelAcuan({
    required this.id,
    this.paketAcuanVersiId,
    this.nomorVersi,
    this.nilaiLama,
    this.nilaiBaru,
    this.sumber,
    this.alasan,
    this.pengguna,
    this.dibuatPada,
  });

  final int id;
  final int? paketAcuanVersiId;
  final int? nomorVersi;

  /// Apa adanya dari server (kontrak: teks, mis. `"19.00011"`).
  final Object? nilaiLama;
  final Object? nilaiBaru;

  /// `ketik` | `tempel` | `impor` | `ambil_alih`.
  final String? sumber;
  final String? alasan;

  /// `null` bila akunnya sudah tidak ada.
  final ({int id, String nama})? pengguna;

  final DateTime? dibuatPada;

  factory SuntinganSelAcuan.fromJson(Map<String, dynamic> json) {
    final user = _peta(json['user']);

    return SuntinganSelAcuan(
      id: _bulat(json['id']) ?? 0,
      paketAcuanVersiId: _bulat(json['paket_acuan_versi_id']),
      nomorVersi: _bulat(json['nomor_versi']),
      nilaiLama: json['nilai_lama'],
      nilaiBaru: json['nilai_baru'],
      sumber: _teks(json['sumber']),
      alasan: _teks(json['alasan']),
      pengguna: user == null
          ? null
          : (id: _bulat(user['id']) ?? 0, nama: '${user['nama'] ?? ''}'),
      dibuatPada: _tanggal(json['created_at']),
    );
  }
}

/// Jawaban `GET /data-acuan/versi/{versi}/sel/{lembar}/{kunci}/{kolom}/riwayat`
/// (FR-03, FR-28). Bukan untuk teknisi — server menjawab 404.
class RiwayatSelAcuan {
  const RiwayatSelAcuan({
    required this.paket,
    required this.lembar,
    required this.kunci,
    this.versi,
    this.kolom,
    this.ada = false,
    this.nilai,
    this.riwayat = const [],
    this.suntingan = const [],
  });

  final String paket;

  /// Versi yang sedang dilihat.
  final RingkasanVersiAcuan? versi;

  final String lembar;
  final String kunci;
  final KolomSkemaAcuan? kolom;

  /// Sel ada di versi yang dilihat? Kunci yang tidak ada di versi mana pun →
  /// `200` dengan `ada: false`, bukan 404.
  final bool ada;
  final Object? nilai;

  /// Semua versi berjenis sama, urut nomor (termasuk draf).
  final List<NilaiSelPerVersi> riwayat;

  final List<SuntinganSelAcuan> suntingan;

  factory RiwayatSelAcuan.fromJson(Map<String, dynamic> json) {
    final kolom = _peta(json['kolom']);

    return RiwayatSelAcuan(
      paket: '${json['paket'] ?? ''}',
      versi: RingkasanVersiAcuan.dariJson(json['versi']),
      lembar: '${json['lembar'] ?? ''}',
      kunci: '${json['kunci'] ?? ''}',
      kolom: kolom == null ? null : KolomSkemaAcuan.fromJson(kolom),
      ada: json['ada'] == true,
      nilai: json['nilai'],
      riwayat: parseListAman(json['riwayat'], NilaiSelPerVersi.fromJson),
      suntingan: parseListAman(json['suntingan'], SuntinganSelAcuan.fromJson),
    );
  }
}
