/// Model riwayat pelacakan pelanggan → alat → sertifikat di sisi LAB
/// (`GET /customers/{customer}/alat`, `GET /equipments/{equipment}/sertifikat`;
/// kontrak `docs/perintah-frontend-super-admin.md` §3.4 dan §3.5).
///
/// Baris tanpa `id` melempar supaya layar menampilkan galat, bukan daftar yang
/// diam-diam kurang satu. Kode status dibaca dari server APA ADANYA: layar
/// tidak menghitung ulang "mendekati jadwal" atau "digantikan".
library;

import 'revisi_sertifikat.dart' show StatusDokumen;

/// Tanggal POLOS (`2026-11-30`) tanpa jam: `DateTime.parse` tanpa zona
/// menghasilkan tengah malam LOKAL, jadi harinya tidak melompat.
DateTime? _tanggalPolos(Object? nilai) {
  if (nilai is! String || nilai.isEmpty) return null;
  return DateTime.tryParse(nilai);
}

/// Waktu ISO-8601 (`dibatalkan_pada`, `ditarik_pada`) → zona perangkat.
DateTime? _waktu(Object? nilai) {
  if (nilai is! String || nilai.isEmpty) return null;
  return DateTime.tryParse(nilai)?.toLocal();
}

String _teks(Object? nilai) => nilai is String ? nilai : '';

int? _angkaAtauNull(Object? nilai) => nilai is num ? nilai.toInt() : null;

/// Satu halaman hasil paginasi KURSOR: [kursorBerikut] `null` = habis.
class HalamanKursor<T> {
  const HalamanKursor({required this.items, this.kursorBerikut});

  final List<T> items;
  final String? kursorBerikut;

  /// `meta.next_cursor` + `meta.ada_lagi` (kontrak §3.4). `ada_lagi: false`
  /// menang atas kursor yang tersisa; bentuk polos `next_cursor` di akar juga
  /// diterima. Kursor kosong/`null` = tidak ada halaman berikutnya. Nilainya
  /// OPAK: dikirim balik apa adanya, tidak dibaca, tidak disimpan lintas sesi.
  static String? bacaKursor(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is Map && meta['ada_lagi'] == false) return null;
    final nilai =
        (meta is Map ? meta['next_cursor'] : null) ?? json['next_cursor'];
    return nilai is String && nilai.isNotEmpty ? nilai : null;
  }
}

/// Rujukan ke sertifikat lain (`revisi_dari`, `digantikan_oleh`).
class RujukanNomor {
  const RujukanNomor({required this.id, required this.nomor});

  final int id;
  final String nomor;

  static RujukanNomor? dari(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! num) return null;
    return RujukanNomor(id: id.toInt(), nomor: _teks(json['nomor']));
  }
}

/// `sertifikat_terbaru` di baris alat: terbaru DIBUAT (status apa pun).
class SertifikatTerbaru {
  const SertifikatTerbaru({
    required this.id,
    required this.nomor,
    required this.keadaan,
    this.diterbitkanPada,
  });

  final int id;
  final String nomor;
  final KeadaanSertifikat keadaan;
  final DateTime? diterbitkanPada;

  static SertifikatTerbaru? dari(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! num) return null;
    return SertifikatTerbaru(
      id: id.toInt(),
      nomor: _teks(json['nomor']),
      keadaan: keadaanSertifikat(
        _teks(json['status']),
        StatusDokumen.dariApi(json['status_dokumen'] as String?),
      ),
      diterbitkanPada: _tanggalPolos(json['diterbitkan_pada']),
    );
  }
}

/// Baris alat milik satu pelanggan.
class AlatRingkas {
  const AlatRingkas({
    required this.id,
    required this.nama,
    this.merk = '',
    this.model = '',
    this.nomorSeri = '',
    this.noIdentifikasi = '',
    this.status = 'aktif',
    this.statusAlat,
    this.jatuhTempo,
    this.hariKeJatuhTempo,
    this.kalibrasiTerakhir,
    this.jumlahSertifikat = 0,
    this.sertifikatTerbaru,
  });

  final int id;
  final String nama;
  final String merk;
  final String model;
  final String nomorSeri;
  final String noIdentifikasi;

  /// Kosakata lab (`aktif` | `overdue` | `nonaktif`); cadangan lencana bila
  /// server lama belum mengirim [statusAlat].
  final String status;

  /// Kode yang SAMA dengan yang dilihat pelanggan di aplikasinya
  /// (`terkalibrasi` | `mendekati_jadwal` | `lewat_jadwal` | `belum_pernah` |
  /// `nonaktif`). Dihitung server; jangan dihitung ulang di klien.
  final String? statusAlat;

  /// Jadwal kalibrasi ulang (`tanggal_jatuh_tempo`).
  final DateTime? jatuhTempo;

  /// Negatif = sudah lewat; `null` = belum ada jadwal.
  final int? hariKeJatuhTempo;
  final DateTime? kalibrasiTerakhir;
  final int jumlahSertifikat;
  final SertifikatTerbaru? sertifikatTerbaru;

  factory AlatRingkas.fromJson(Map<String, dynamic> json) {
    final status = _teks(json['status']);
    final statusAlat = _teks(json['status_alat']);
    return AlatRingkas(
      id: (json['id'] as num).toInt(),
      nama: _teks(json['nama_alat']),
      merk: _teks(json['merk']),
      model: _teks(json['model']),
      nomorSeri: _teks(json['serial_number']),
      noIdentifikasi: _teks(json['no_identifikasi']),
      status: status.isEmpty ? 'aktif' : status,
      statusAlat: statusAlat.isEmpty ? null : statusAlat,
      jatuhTempo: _tanggalPolos(json['tanggal_jatuh_tempo']),
      hariKeJatuhTempo: _angkaAtauNull(json['hari_ke_jatuh_tempo']),
      kalibrasiTerakhir: _tanggalPolos(json['tanggal_kalibrasi_terakhir']),
      jumlahSertifikat: (json['jumlah_sertifikat'] as num?)?.toInt() ?? 0,
      sertifikatTerbaru: SertifikatTerbaru.dari(json['sertifikat_terbaru']),
    );
  }
}

/// Keadaan satu sertifikat di riwayat alat, diturunkan dari DUA kolom server:
/// `status` (teknis: terbit / menunggu_generate / gagal / dibatalkan / ditarik)
/// dan `status_dokumen` (sah atau tidak: berlaku / digantikan / dibatalkan /
/// ditarik / belum_terbit).
///
/// `status_dokumen` menang bila ada (itu yang menjawab "masih sah atau
/// tidak"); `gagal` dan `menunggu_generate` hanya ada di kolom teknis.
enum KeadaanSertifikat {
  terbit,
  digantikan,
  ditarik,
  dibatalkan,
  gagal,
  menunggu,
}

KeadaanSertifikat keadaanSertifikat(String status, StatusDokumen? dokumen) {
  if (status == 'gagal') return KeadaanSertifikat.gagal;
  if (dokumen != null) {
    switch (dokumen) {
      case StatusDokumen.digantikan:
        return KeadaanSertifikat.digantikan;
      case StatusDokumen.ditarik:
        return KeadaanSertifikat.ditarik;
      case StatusDokumen.dibatalkan:
        return KeadaanSertifikat.dibatalkan;
      case StatusDokumen.belumTerbit:
        return KeadaanSertifikat.menunggu;
      case StatusDokumen.berlaku:
        break;
    }
  }
  return switch (status) {
    'terbit' => KeadaanSertifikat.terbit,
    'dibatalkan' => KeadaanSertifikat.dibatalkan,
    'ditarik' => KeadaanSertifikat.ditarik,
    'menunggu_generate' => KeadaanSertifikat.menunggu,
    // Server lama tanpa `status`: yang `berlaku` dianggap terbit; sisanya
    // menunggu.
    _ =>
      dokumen == StatusDokumen.berlaku
          ? KeadaanSertifikat.terbit
          : KeadaanSertifikat.menunggu,
  };
}

/// Baris sertifikat di riwayat satu alat. Sertifikat lama TETAP tampil: yang
/// digantikan/ditarik/dibatalkan adalah jejak, bukan sampah.
class SertifikatRingkas {
  const SertifikatRingkas({
    required this.id,
    required this.nomor,
    required this.keadaan,
    this.diterbitkanPada,
    this.berlakuSampai,
    this.tahun,
    this.bulan,
    this.keputusan,
    this.revisiKe = 0,
    this.revisiDari,
    this.digantikanOleh,
    this.ditarikPada,
    this.dibatalkanPada,
  });

  final int id;
  final String nomor;
  final KeadaanSertifikat keadaan;
  final DateTime? diterbitkanPada;
  final DateTime? berlakuSampai;

  /// `tahun`/`bulan` dari server (dari `diterbitkan_pada`) untuk pengelompokan;
  /// `null` bila belum terbit.
  final int? tahun;
  final int? bulan;

  /// `PASS` / `FAIL` bila server menyertakannya.
  final String? keputusan;
  final int revisiKe;
  final RujukanNomor? revisiDari;

  /// Hanya bila penggantinya TERBIT (kontrak §3.5).
  final RujukanNomor? digantikanOleh;
  final DateTime? ditarikPada;
  final DateTime? dibatalkanPada;

  /// Tahun/bulan kelompok: dari server, cadangannya dari tanggal terbit.
  int? get tahunKelompok => tahun ?? diterbitkanPada?.year;
  int? get bulanKelompok => bulan ?? diterbitkanPada?.month;

  factory SertifikatRingkas.fromJson(Map<String, dynamic> json) {
    final keputusan = json['keputusan'];
    return SertifikatRingkas(
      id: (json['id'] as num).toInt(),
      nomor: _teks(json['nomor']),
      keadaan: keadaanSertifikat(
        _teks(json['status']),
        StatusDokumen.dariApi(json['status_dokumen'] as String?),
      ),
      diterbitkanPada: _tanggalPolos(json['diterbitkan_pada']),
      berlakuSampai: _tanggalPolos(json['berlaku_sampai']),
      tahun: _angkaAtauNull(json['tahun']),
      bulan: _angkaAtauNull(json['bulan']),
      keputusan: keputusan is String && keputusan.isNotEmpty ? keputusan : null,
      revisiKe: (json['revisi_ke'] as num?)?.toInt() ?? 0,
      revisiDari: RujukanNomor.dari(json['revisi_dari']),
      digantikanOleh: RujukanNomor.dari(json['digantikan_oleh']),
      ditarikPada: _waktu(json['ditarik_pada']),
      dibatalkanPada: _waktu(json['dibatalkan_pada']),
    );
  }
}

/// Satu baris tampilan riwayat: judul tahun, judul bulan, atau sertifikat.
sealed class BarisRiwayat {
  const BarisRiwayat();
}

class JudulTahun extends BarisRiwayat {
  const JudulTahun(this.tahun);

  /// `null` = daftar DIMULAI dengan sertifikat yang belum terbit.
  final int? tahun;
}

class JudulBulan extends BarisRiwayat {
  const JudulBulan(this.tahun, this.bulan);

  final int tahun;
  final int bulan;
}

class BarisSertifikat extends BarisRiwayat {
  const BarisSertifikat(this.sertifikat);

  final SertifikatRingkas sertifikat;
}

/// Susun [items] (urutan server: TERBARU dulu) menjadi tahun → bulan →
/// sertifikat.
///
/// Judul hanya disisipkan saat tahun/bulan BERGANTI, jadi urutan dari server
/// tidak pernah diacak dan halaman yang dimuat belakangan menyambung mulus di
/// bawah yang sudah tampak. Sertifikat yang belum terbit (`gagal`, menunggu:
/// tanpa tanggal) menempel pada kelompok yang sedang berjalan — lencananya
/// sudah menjelaskan — dan hanya bila ia PERTAMA di daftar ia membuka kelompok
/// "tanpa tanggal terbit".
List<BarisRiwayat> susunRiwayat(List<SertifikatRingkas> items) {
  final baris = <BarisRiwayat>[];
  int? tahunSekarang;
  int? bulanSekarang;
  var mulai = true;

  for (final s in items) {
    final tahun = s.tahunKelompok;
    final bulan = s.bulanKelompok;

    if (tahun == null && !mulai) {
      baris.add(BarisSertifikat(s));
      continue;
    }

    if (mulai || tahun != tahunSekarang) {
      baris.add(JudulTahun(tahun));
      tahunSekarang = tahun;
      bulanSekarang = null;
      mulai = false;
    }
    if (tahun != null && bulan != null && bulan != bulanSekarang) {
      baris.add(JudulBulan(tahun, bulan));
      bulanSekarang = bulan;
    }
    baris.add(BarisSertifikat(s));
  }
  return baris;
}
