/// Skema form yang dibikin dari isi lembar kerja yang difoto
/// (`POST /api/dokumen/baca`), bukan dari daftar field per jenis alat.
///
/// Bentuknya ngikutin dokumennya: lembar tiga kolom jadi tiga kolom, lembar
/// tujuh kolom jadi tujuh. Alat baru nggak perlu kelas baru di sini.
library;

import '../core/utils/parse_list.dart';

/// Status satu nilai hasil baca. Nilainya ditentukan server (`AmbangKeyakinan`).
class StatusBaca {
  static const ok = 'OK';
  static const perluReview = 'REVIEW_REQUIRED';
}

/// Dari mana satu nilai datang.
class SumberNilai {
  /// Sudah tercetak di formulir — bukan isian teknisi.
  static const statis = 'static_document';

  /// Ditulis tangan sama teknisi.
  static const tulisan = 'handwriting';

  static const tidakDiketahui = 'unknown';
}

/// Kotak asal satu nilai di gambar, buat nyorot pas teknisi ngecek.
class KotakBatas {
  const KotakBatas({
    required this.x,
    required this.y,
    required this.lebar,
    required this.tinggi,
  });

  final double x;
  final double y;
  final double lebar;
  final double tinggi;

  /// `null` kalau kotaknya nggak lengkap — kotak separuh nggak bisa dipakai
  /// nyorot apa pun, dan nyimpennya bikin tiap pemakai harus ngecek sisinya
  /// satu-satu.
  static KotakBatas? fromJson(dynamic json) {
    if (json is! Map) return null;

    final x = _angka(json['x']);
    final y = _angka(json['y']);
    final w = _angka(json['width']);
    final h = _angka(json['height']);

    if (x == null || y == null || w == null || h == null) return null;

    return KotakBatas(x: x, y: y, lebar: w, tinggi: h);
  }

  static double? _angka(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
}

/// Satu isian tunggal (bukan sel tabel).
class FieldDinamis {
  const FieldDinamis({
    required this.kunci,
    required this.tipe,
    required this.status,
    required this.sumber,
    required this.bisaDiisi,
    this.label,
    this.satuan,
    this.nilai,
    this.keyakinan,
    this.tingkatKeyakinan,
    this.halaman = 1,
    this.bbox,
  });

  /// Kunci unik dari POSISI, bukan dari label — label di lembar kerja berulang
  /// terus (satu lembar bisa punya empat "Reading"), jadi kunci berbasis label
  /// bikin dua isian beda nempel ke kotak yang sama.
  final String kunci;

  final String? label;
  final String tipe;
  final String? satuan;

  /// Apa adanya seperti terbaca di kertas — `25,4` tetap `25,4`. Sengaja
  /// nggak dinormalkan biar bisa dibandingin langsung sama lembarnya.
  final String? nilai;

  final String sumber;
  final double? keyakinan;
  final String? tingkatKeyakinan;
  final String status;
  final int halaman;
  final KotakBatas? bbox;

  /// `false` buat teks yang memang sudah TERCETAK di formulir. Ditampilin
  /// baca-saja, biar nama standar yang tercetak nggak kelihatan kayak kotak
  /// kosong yang lupa diisi.
  final bool bisaDiisi;

  bool get perluDilihat => status != StatusBaca.ok;

  factory FieldDinamis.fromJson(Map<String, dynamic> json) => FieldDinamis(
    kunci: json['kunci'] as String,
    label: json['label'] as String?,
    tipe: (json['tipe'] as String?) ?? 'text',
    satuan: json['satuan'] as String?,
    nilai: _teks(json['nilai']),
    sumber: (json['sumber'] as String?) ?? SumberNilai.tidakDiketahui,
    keyakinan: (json['keyakinan'] as num?)?.toDouble(),
    tingkatKeyakinan: json['tingkat_keyakinan'] as String?,
    status: (json['status'] as String?) ?? StatusBaca.perluReview,
    halaman: (json['halaman'] as num?)?.toInt() ?? 1,
    bbox: KotakBatas.fromJson(json['bbox']),
    bisaDiisi: json['bisa_diisi'] as bool? ?? true,
  );
}

/// Satu kolom tabel. Judulnya apa adanya dari kertas — kolom tanpa judul tetap
/// kolom, dan dikasih judul karangan malah bikin teknisi ngira ada keterangan
/// yang sebenernya nggak tertulis.
class KolomDinamis {
  const KolomDinamis({required this.kunci, required this.tipe, this.judul});

  final String kunci;
  final String? judul;
  final String tipe;

  factory KolomDinamis.fromJson(Map<String, dynamic> json) => KolomDinamis(
    kunci: json['kunci'] as String,
    judul: json['judul'] as String?,
    tipe: (json['tipe'] as String?) ?? 'text',
  );
}

/// Satu sel tabel.
class SelDinamis {
  const SelDinamis({
    required this.kunci,
    required this.baris,
    required this.kolom,
    required this.status,
    required this.sumber,
    this.nilai,
    this.keyakinan,
    this.tingkatKeyakinan,
    this.halaman = 1,
    this.bbox,
  });

  final String kunci;
  final int baris;
  final int kolom;
  final String? nilai;
  final String sumber;
  final double? keyakinan;
  final String? tingkatKeyakinan;
  final String status;
  final int halaman;
  final KotakBatas? bbox;

  bool get perluDilihat => status != StatusBaca.ok;

  factory SelDinamis.fromJson(Map<String, dynamic> json) => SelDinamis(
    kunci: json['kunci'] as String,
    baris: (json['baris'] as num).toInt(),
    kolom: (json['kolom'] as num).toInt(),
    nilai: _teks(json['nilai']),
    sumber: (json['sumber'] as String?) ?? SumberNilai.tidakDiketahui,
    keyakinan: (json['keyakinan'] as num?)?.toDouble(),
    tingkatKeyakinan: json['tingkat_keyakinan'] as String?,
    status: (json['status'] as String?) ?? StatusBaca.perluReview,
    halaman: (json['halaman'] as num?)?.toInt() ?? 1,
    bbox: KotakBatas.fromJson(json['bbox']),
  );

  /// Sel pengganti buat data yang bentuknya cacat — lihat [TabelDinamis].
  factory SelDinamis.rusak(String kunciTabel, int baris, int kolom) =>
      SelDinamis(
        kunci: '$kunciTabel.sel-$baris-$kolom',
        baris: baris,
        kolom: kolom,
        status: StatusBaca.perluReview,
        sumber: SumberNilai.tidakDiketahui,
      );
}

class TabelDinamis {
  const TabelDinamis({
    required this.kunci,
    required this.kolom,
    required this.baris,
    this.nama,
    this.keyakinan,
  });

  final String kunci;
  final String? nama;
  final List<KolomDinamis> kolom;
  final List<List<SelDinamis>> baris;
  final double? keyakinan;

  /// Sel yang cacat DIGANTI di tempatnya, bukan dilewat.
  ///
  /// Ini beda sengaja dari [parseListAman] yang dipakai di tempat lain. Buat
  /// daftar biasa, ngelewat item cacat itu benar — sisanya tetap tampil. Tapi
  /// buat sel tabel, ngelewat satu sel bikin sel sesudahnya NAIK satu kolom,
  /// dan angka yang mendarat di kolom yang salah itu kesalahan paling mahal di
  /// lembar kalibrasi: kelihatan wajar, nggak ada yang merah, dan baru ketahuan
  /// waktu sertifikatnya kepakai.
  ///
  /// Jadi di sini yang cacat jadi sel KOSONG berstatus perlu-review — posisinya
  /// dijaga, dan teknisi diminta ngisi sendiri.
  factory TabelDinamis.fromJson(Map<String, dynamic> json) {
    final kunci = json['kunci'] as String;
    final baris = <List<SelDinamis>>[];

    final barisMentah = json['baris'];

    if (barisMentah is List) {
      for (var r = 0; r < barisMentah.length; r++) {
        final isi = barisMentah[r];
        final satuBaris = <SelDinamis>[];

        if (isi is List) {
          for (var k = 0; k < isi.length; k++) {
            final sel = isi[k];

            if (sel is Map) {
              try {
                satuBaris.add(
                  SelDinamis.fromJson(Map<String, dynamic>.from(sel)),
                );
                continue;
              } catch (_) {
                // jatuh ke pengganti di bawah
              }
            }

            satuBaris.add(SelDinamis.rusak(kunci, r, k));
          }
        }

        baris.add(satuBaris);
      }
    }

    return TabelDinamis(
      kunci: kunci,
      nama: json['nama'] as String?,
      kolom: parseListAman(json['kolom'], KolomDinamis.fromJson),
      baris: baris,
      keyakinan: (json['keyakinan'] as num?)?.toDouble(),
    );
  }
}

class BagianDinamis {
  const BagianDinamis({
    required this.kunci,
    required this.field,
    required this.tabel,
    this.nama,
  });

  final String kunci;
  final String? nama;
  final List<FieldDinamis> field;
  final List<TabelDinamis> tabel;

  factory BagianDinamis.fromJson(Map<String, dynamic> json) => BagianDinamis(
    kunci: json['kunci'] as String,
    nama: json['nama'] as String?,
    field: parseListAman(json['field'], FieldDinamis.fromJson),
    tabel: parseListAman(json['tabel'], TabelDinamis.fromJson),
  );
}

/// Kepala dokumen: apa yang terbaca, bukan apa yang dipilih teknisi.
class KepalaDokumen {
  const KepalaDokumen({
    this.judul,
    this.namaAlat,
    this.kodeDokumen,
    this.revisi,
    this.keyakinan,
  });

  final String? judul;
  final String? namaAlat;
  final String? kodeDokumen;
  final String? revisi;
  final double? keyakinan;

  factory KepalaDokumen.fromJson(dynamic json) {
    if (json is! Map) return const KepalaDokumen();

    return KepalaDokumen(
      judul: json['title'] as String?,
      namaAlat: json['equipment_name'] as String?,
      kodeDokumen: json['worksheet_code'] as String?,
      revisi: json['revision'] as String?,
      keyakinan: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class SkemaDinamis {
  const SkemaDinamis({
    required this.dokumen,
    required this.bagian,
    required this.peringatan,
    required this.jumlahField,
    required this.jumlahSel,
    required this.perluReview,
  });

  final KepalaDokumen dokumen;
  final List<BagianDinamis> bagian;

  /// Peringatan dari server — beda alat yang dipilih vs yang terbaca, halaman
  /// buram, bentuk yang nggak masuk akal. Ditampilin, bukan dibuang.
  final List<String> peringatan;

  final int jumlahField;
  final int jumlahSel;

  /// Berapa nilai yang WAJIB dilihat teknisi sebelum disimpan.
  final int perluReview;

  bool get adaYangPerluDilihat => perluReview > 0;

  factory SkemaDinamis.fromJson(Map<String, dynamic> json) {
    final ringkasan = json['ringkasan'];
    final r = ringkasan is Map ? ringkasan : const {};

    return SkemaDinamis(
      dokumen: KepalaDokumen.fromJson(json['dokumen']),
      bagian: parseListAman(json['bagian'], BagianDinamis.fromJson),
      peringatan: (json['peringatan'] is List)
          ? (json['peringatan'] as List).whereType<String>().toList()
          : const [],
      jumlahField: (r['jumlah_field'] as num?)?.toInt() ?? 0,
      jumlahSel: (r['jumlah_sel'] as num?)?.toInt() ?? 0,
      perluReview: (r['perlu_review'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Angka dan bool dari server dibikin teks buat ditampilin di kotak isian,
/// TANPA diformat ulang — `25,4` tetap `25,4`, `7.02` tetap `7.02`.
String? _teks(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is bool) return v ? 'true' : 'false';

  return v.toString();
}
