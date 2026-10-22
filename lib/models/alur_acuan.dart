/// Alur versi data acuan lapis 1 (Studio Data Acuan T2.2/T2.3; §54 repo API):
/// draf → ajukan → simulasi → aktifkan / tolak.
///
/// Bentuk respons disalin dari `DataAcuanAlurController` (repo API, branch
/// `feat/studio-kendali-olah-data`):
///  - `GET /data-acuan/paket/{kode}/alur` → `data[]` = `PaketAcuanVersiResource`
///    + `simulasi` (`ringkasSimulasi`) + `log[]`;
///  - `GET /data-acuan/versi/{versi}/simulasi` → `data` = `ringkasSimulasi` +
///    `laporan` (`{sesi[], bersama_antar_varian}` dari `SimulasiVersiAcuan` &
///    `DataBersamaVarian`).
///
/// Semua parsing toleran: kunci yang hilang → `null`/kosong, tipe yang salah
/// → diabaikan, kunci yang belum dikenal → diabaikan. Nilai `lama`/`baru`
/// disimpan APA ADANYA (`num`/`String`/`bool`/`null`) — tidak dibulatkan;
/// tampilan yang memformat.
library;

import '../core/utils/parse_list.dart';
import 'data_acuan.dart';

int? _bulat(Object? nilai) => switch (nilai) {
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

String? _teks(Object? nilai) => switch (nilai) {
  null => null,
  final String s => s.isEmpty ? null : s,
  final num n => '$n',
  _ => null,
};

DateTime? _waktu(Object? nilai) =>
    nilai is String && nilai.isNotEmpty ? DateTime.tryParse(nilai) : null;

Map<String, dynamic>? _peta(Object? nilai) => switch (nilai) {
  final Map<String, dynamic> m => m,
  final Map m => Map<String, dynamic>.from(m),
  _ => null,
};

List<String> _daftarTeks(Object? nilai) => nilai is List
    ? [
        for (final v in nilai)
          if (v is String && v.isNotEmpty) v else if (v is num) '$v',
      ]
    : const [];

/// Status simulasi terakhir terhadap isi versi & data sekarang
/// (`AlurVersiAcuan::statusSimulasi`).
enum StatusSimulasiAcuan {
  belumAda('belum_ada'),
  terbaru('terbaru'),
  kedaluwarsa('kedaluwarsa'),
  gagal('gagal'),
  tidakDikenal('');

  const StatusSimulasiAcuan(this.kode);

  final String kode;

  static StatusSimulasiAcuan dariKode(Object? nilai) {
    final kode = '${nilai ?? ''}'.trim().toLowerCase();
    return values.firstWhere(
      (s) => s != tidakDikenal && s.kode == kode,
      orElse: () => tidakDikenal,
    );
  }
}

/// Butir yang wajib diakui saat aktifkan (`AlurVersiAcuan::AKUI_*`).
abstract final class ButirPengakuanAcuan {
  static const terbitCetakBerubah = 'terbit_cetak_berubah';
  static const bersamaAntarVarian = 'bersama_antar_varian';
  static const sesiGagal = 'sesi_gagal';

  /// Panjang minimum alasan per butir (server: `mb_strlen(trim()) < 10`).
  static const panjangMinimum = 10;
}

/// `simulasi.ringkasan` — angka hitungan sesi, bukan angka kalibrasi.
class RingkasanAngkaSimulasi {
  const RingkasanAngkaSimulasi({
    this.sesiTotal,
    this.sesiBerubah,
    this.cetakBerubah,
    this.terbitCetakBerubah,
    this.vonisBerubah,
    this.sesiGagal,
    this.bersamaAntarVarian,
    this.masterVarianLainTidakSepakat,
    this.sumberAcuanAktif,
    this.catatanSumber,
  });

  final int? sesiTotal;
  final int? sesiBerubah;
  final int? cetakBerubah;
  final int? terbitCetakBerubah;
  final int? vonisBerubah;
  final int? sesiGagal;
  final int? bersamaAntarVarian;
  final int? masterVarianLainTidakSepakat;

  /// `DATA_ACUAN_SUMBER` server saat simulasi (`db`/`json`).
  final String? sumberAcuanAktif;

  /// Peringatan server bila jalur hitung produksi belum membaca versi DB.
  final String? catatanSumber;

  static RingkasanAngkaSimulasi? dariJson(Object? nilai) {
    final j = _peta(nilai);
    if (j == null) return null;
    return RingkasanAngkaSimulasi(
      sesiTotal: _bulat(j['sesi_total']),
      sesiBerubah: _bulat(j['sesi_berubah']),
      cetakBerubah: _bulat(j['cetak_berubah']),
      terbitCetakBerubah: _bulat(j['terbit_cetak_berubah']),
      vonisBerubah: _bulat(j['vonis_berubah']),
      sesiGagal: _bulat(j['sesi_gagal']),
      bersamaAntarVarian: _bulat(j['bersama_antar_varian']),
      masterVarianLainTidakSepakat: _bulat(
        j['master_varian_lain_tidak_sepakat'],
      ),
      sumberAcuanAktif: _teks(j['sumber_acuan_aktif']),
      catatanSumber: _teks(j['catatan_sumber']),
    );
  }
}

/// `ringkasSimulasi()` — status + ringkasan + butir wajib diakui.
class SimulasiVersiAcuan {
  const SimulasiVersiAcuan({
    required this.kodeStatus,
    this.id,
    this.isiSha256,
    this.dijalankanOleh,
    this.selesai,
    this.ringkasan,
    this.wajibDiakui = const [],
  });

  static const kosong = SimulasiVersiAcuan(kodeStatus: 'belum_ada');

  final String kodeStatus;
  final int? id;
  final String? isiSha256;
  final int? dijalankanOleh;
  final DateTime? selesai;
  final RingkasanAngkaSimulasi? ringkasan;

  /// Kode butir (`ButirPengakuanAcuan`) yang wajib diakui saat aktifkan.
  final List<String> wajibDiakui;

  StatusSimulasiAcuan get status => StatusSimulasiAcuan.dariKode(kodeStatus);

  factory SimulasiVersiAcuan.fromJson(Map<String, dynamic> j) =>
      SimulasiVersiAcuan(
        kodeStatus: _teks(j['status']) ?? 'belum_ada',
        id: _bulat(j['id']),
        isiSha256: _teks(j['isi_sha256']),
        dijalankanOleh: _bulat(j['dijalankan_oleh']),
        selesai: _waktu(j['selesai']),
        ringkasan: RingkasanAngkaSimulasi.dariJson(j['ringkasan']),
        wajibDiakui: _daftarTeks(j['wajib_diakui']),
      );

  static SimulasiVersiAcuan dariJson(Object? nilai) {
    final j = _peta(nilai);
    return j == null ? kosong : SimulasiVersiAcuan.fromJson(j);
  }
}

/// Satu baris `paket_acuan_log` (append-only).
class LogAlurAcuan {
  const LogAlurAcuan({
    required this.aksi,
    this.statusDari,
    this.statusKe,
    this.isiSha256,
    this.userId,
    this.alasan,
    this.sumber,
    this.rincian,
    this.pada,
  });

  /// `dibuat`, `ajukan`, `simulasi`, `sahkan`, `tolak`, `buang`, `pensiun`, …
  final String aksi;
  final String? statusDari;
  final String? statusKe;
  final String? isiSha256;
  final int? userId;
  final String? alasan;

  /// Sumber draf (workbook master id + sha256, peta sel, varian) — apa adanya.
  final Map<String, dynamic>? sumber;
  final Map<String, dynamic>? rincian;
  final DateTime? pada;

  factory LogAlurAcuan.fromJson(Map<String, dynamic> j) => LogAlurAcuan(
    aksi: _teks(j['aksi']) ?? '',
    statusDari: _teks(j['status_dari']),
    statusKe: _teks(j['status_ke']),
    isiSha256: _teks(j['isi_sha256']),
    userId: _bulat(j['user_id']),
    alasan: _teks(j['alasan']),
    sumber: _peta(j['sumber']),
    rincian: _peta(j['rincian']),
    pada: _waktu(j['pada']),
  );
}

/// Satu baris `GET /paket/{kode}/alur`: versi + simulasi + log.
class VersiAlurAcuan {
  const VersiAlurAcuan({
    required this.versi,
    this.simulasi = SimulasiVersiAcuan.kosong,
    this.log = const [],
  });

  final VersiAcuan versi;
  final SimulasiVersiAcuan simulasi;
  final List<LogAlurAcuan> log;

  int get id => versi.id;
  int get nomor => versi.nomor;
  StatusVersiAcuan get status => StatusVersiAcuan.dariKode(versi.kodeStatus);

  factory VersiAlurAcuan.fromJson(Map<String, dynamic> j) => VersiAlurAcuan(
    versi: VersiAcuan.fromJson(j),
    simulasi: SimulasiVersiAcuan.dariJson(j['simulasi']),
    log: parseListAman(j['log'], LogAlurAcuan.fromJson),
  );
}

/// Perubahan nilai satu kolom hasil hitung (`selisih[]`).
class SelisihSimulasiAcuan {
  const SelisihSimulasiAcuan({
    required this.titik,
    required this.kolom,
    this.lama,
    this.baru,
    this.selisih,
  });

  final int? titik;
  final String kolom;
  final Object? lama;
  final Object? baru;

  /// `baru - lama` bila keduanya angka (server), selain itu `null`.
  final num? selisih;

  factory SelisihSimulasiAcuan.fromJson(Map<String, dynamic> j) =>
      SelisihSimulasiAcuan(
        titik: _bulat(j['titik']),
        kolom: _teks(j['kolom']) ?? '',
        lama: j['lama'],
        baru: j['baru'],
        selisih: j['selisih'] is num ? j['selisih'] as num : null,
      );
}

/// Teks cetak sertifikat yang berubah (`cetak[]`): teks persis lama/baru.
class CetakBerubahAcuan {
  const CetakBerubahAcuan({
    required this.titik,
    required this.kolom,
    this.lama,
    this.baru,
  });

  final int? titik;
  final String kolom;
  final String? lama;
  final String? baru;

  factory CetakBerubahAcuan.fromJson(Map<String, dynamic> j) =>
      CetakBerubahAcuan(
        titik: _bulat(j['titik']),
        kolom: _teks(j['kolom']) ?? '',
        lama: j['lama'] == null ? null : '${j['lama']}',
        baru: j['baru'] == null ? null : '${j['baru']}',
      );
}

/// Titik yang terhitung di satu sisi saja (`titik_tidak_terhitung[]`).
class TitikTidakTerhitungAcuan {
  const TitikTidakTerhitungAcuan({
    required this.titik,
    required this.lama,
    required this.baru,
  });

  final int? titik;
  final bool lama;
  final bool baru;

  factory TitikTidakTerhitungAcuan.fromJson(Map<String, dynamic> j) =>
      TitikTidakTerhitungAcuan(
        titik: _bulat(j['titik']),
        lama: j['lama'] == true,
        baru: j['baru'] == true,
      );
}

/// Satu sesi di laporan simulasi (`SimulasiVersiAcuan::simulasiSesi`).
class SesiSimulasiAcuan {
  const SesiSimulasiAcuan({
    this.sesiId,
    this.nomorSesi,
    this.statusSesi,
    this.tanggalKalibrasi,
    this.sudahTerbit = false,
    this.nomorSertifikatTerbit = const [],
    this.versiPembanding,
    this.berubah = false,
    this.cetakBerubah = false,
    this.vonisBerubah = false,
    this.selisih = const [],
    this.cetak = const [],
    this.titikTidakTerhitung = const [],
    this.galat,
  });

  final int? sesiId;
  final String? nomorSesi;
  final String? statusSesi;
  final String? tanggalKalibrasi;
  final bool sudahTerbit;
  final List<String> nomorSertifikatTerbit;
  final String? versiPembanding;
  final bool berubah;
  final bool cetakBerubah;
  final bool vonisBerubah;
  final List<SelisihSimulasiAcuan> selisih;
  final List<CetakBerubahAcuan> cetak;
  final List<TitikTidakTerhitungAcuan> titikTidakTerhitung;
  final String? galat;

  bool get gagal => galat != null;

  factory SesiSimulasiAcuan.fromJson(Map<String, dynamic> j) =>
      SesiSimulasiAcuan(
        sesiId: _bulat(j['sesi_id']),
        nomorSesi: _teks(j['nomor_sesi']),
        statusSesi: _teks(j['status_sesi']),
        tanggalKalibrasi: _teks(j['tanggal_kalibrasi']),
        sudahTerbit: j['sudah_terbit'] == true,
        nomorSertifikatTerbit: _daftarTeks(j['nomor_sertifikat_terbit']),
        versiPembanding: _teks(j['versi_pembanding']),
        berubah: j['berubah'] == true,
        cetakBerubah: j['cetak_berubah'] == true,
        vonisBerubah: j['vonis_berubah'] == true,
        selisih: parseListAman(j['selisih'], SelisihSimulasiAcuan.fromJson),
        cetak: parseListAman(j['cetak'], CetakBerubahAcuan.fromJson),
        titikTidakTerhitung: parseListAman(
          j['titik_tidak_terhitung'],
          TitikTidakTerhitungAcuan.fromJson,
        ),
        galat: _teks(j['galat']),
      );
}

/// Satu daun data bersama antar varian (`jalur`, `lama`, `baru`).
class DaunBersamaAcuan {
  const DaunBersamaAcuan({required this.jalur, this.lama, this.baru});

  final String jalur;
  final Object? lama;
  final Object? baru;

  factory DaunBersamaAcuan.fromJson(Map<String, dynamic> j) => DaunBersamaAcuan(
    jalur: _teks(j['jalur']) ?? '',
    // Bentuk `master_lain[].beda[]` memakai `master`/`draf`.
    lama: j.containsKey('lama') ? j['lama'] : j['master'],
    baru: j.containsKey('baru') ? j['baru'] : j['draf'],
  );
}

/// Master aktif varian lain dan bedanya dengan draf.
class MasterVarianLainAcuan {
  const MasterVarianLainAcuan({
    this.workbookMasterId,
    this.nama,
    this.varian,
    this.beda = const [],
    this.galat,
  });

  final int? workbookMasterId;
  final String? nama;
  final String? varian;
  final List<DaunBersamaAcuan> beda;
  final String? galat;

  factory MasterVarianLainAcuan.fromJson(Map<String, dynamic> j) =>
      MasterVarianLainAcuan(
        workbookMasterId: _bulat(j['workbook_master_id']),
        nama: _teks(j['nama']),
        varian: _teks(j['varian']),
        beda: parseListAman(j['beda'], DaunBersamaAcuan.fromJson),
        galat: _teks(j['galat']),
      );
}

/// `laporan.bersama_antar_varian` (`DataBersamaVarian::periksa`).
class BersamaAntarVarianAcuan {
  const BersamaAntarVarianAcuan({
    this.berlaku = false,
    this.varianDraf,
    this.berubah = const [],
    this.masterLain = const [],
  });

  final bool berlaku;
  final String? varianDraf;
  final List<DaunBersamaAcuan> berubah;
  final List<MasterVarianLainAcuan> masterLain;

  static BersamaAntarVarianAcuan? dariJson(Object? nilai) {
    final j = _peta(nilai);
    if (j == null) return null;
    return BersamaAntarVarianAcuan(
      berlaku: j['berlaku'] == true,
      varianDraf: _teks(j['varian_draf']),
      berubah: parseListAman(j['berubah'], DaunBersamaAcuan.fromJson),
      masterLain: parseListAman(
        j['master_lain'],
        MasterVarianLainAcuan.fromJson,
      ),
    );
  }
}

/// `GET /versi/{versi}/simulasi` — ringkasan + laporan utuh (yang dilihat
/// pengaktif). `laporan == null` = belum ada simulasi.
class LaporanSimulasiAcuan {
  const LaporanSimulasiAcuan({
    required this.simulasi,
    this.sesi = const [],
    this.bersama,
    this.adaLaporan = false,
  });

  final SimulasiVersiAcuan simulasi;
  final List<SesiSimulasiAcuan> sesi;
  final BersamaAntarVarianAcuan? bersama;
  final bool adaLaporan;

  factory LaporanSimulasiAcuan.fromJson(Map<String, dynamic> j) {
    final laporan = _peta(j['laporan']);
    return LaporanSimulasiAcuan(
      simulasi: SimulasiVersiAcuan.fromJson(j),
      adaLaporan: laporan != null,
      sesi: parseListAman(laporan?['sesi'], SesiSimulasiAcuan.fromJson),
      bersama: BersamaAntarVarianAcuan.dariJson(
        laporan?['bersama_antar_varian'],
      ),
    );
  }
}

/// Satu rujukan tambahan saat mengajukan (`rujukan.*` di `ajukan`).
class RujukanAjuanAcuan {
  const RujukanAjuanAcuan({
    required this.jenis,
    required this.nilai,
    this.catatan,
  });

  /// Jenis yang diterima server (`in:` di validasi `ajukan`).
  static const jenisSah = [
    'sertifikat_standar',
    'ik',
    'lampiran',
    'sel_master',
    'lain',
  ];

  final String jenis;
  final String nilai;
  final String? catatan;

  Map<String, dynamic> toJson() => {
    'jenis': jenis,
    'nilai': nilai,
    if (catatan != null && catatan!.isNotEmpty) 'catatan': catatan,
  };
}

/// Kode galat alur versi yang dikenali klien (`AlurVersiAcuanDitolak::kode`,
/// sandi konfirmasi, middleware aplikasi). Yang lain → [lain].
enum KodeGalatAlurAcuan {
  statusTidakSesuai('status_tidak_sesuai'),
  jenisTidakDidukung('jenis_tidak_didukung'),
  hanyaSuperAdmin('hanya_super_admin'),
  pengesahIkutMenyunting('pengesah_ikut_menyunting'),
  berlakuMulaiLampau('berlaku_mulai_lampau'),
  simulasiBelumAda('simulasi_belum_ada'),
  simulasiKedaluwarsa('simulasi_kedaluwarsa'),
  simulasiGagal('simulasi_gagal'),
  pengakuanWajib('pengakuan_wajib'),
  rentangBentrok('rentang_bentrok'),
  konfirmasiSandiSalah('konfirmasi_sandi_salah'),
  bukanAplikasiIni('bukan_aplikasi_ini'),
  bukanAkunStudio('bukan_akun_studio'),
  lain('');

  const KodeGalatAlurAcuan(this.kode);

  final String kode;

  static KodeGalatAlurAcuan dariKode(Object? nilai) {
    final kode = '${nilai ?? ''}'.trim().toLowerCase();
    return values.firstWhere(
      (k) => k != lain && k.kode == kode,
      orElse: () => lain,
    );
  }
}
