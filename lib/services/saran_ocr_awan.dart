import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import '../models/ocr_awan.dart';
import '../models/review_foto.dart';
import '../models/usulan_ocr_awan.dart';
import '../models/worksheet_template.dart';
import 'auth_service.dart';
import 'ocr_awan_sel_service.dart';
import 'vonis_sel_foto.dart';

/// Penjalur usulan OCR awan atas potongan sel angka untuk layar review foto.
///
/// Satu tugas: mengubah "sel mana yang masih ragu" menjadi usulan bacaan awan,
/// dengan tiga jaminan yang diuji:
///
///  1. **Hanya potongan sel angka yang keluar.** Kandidat disaring dari templat
///     ([kunciSelAngka]: baris bertipe `angka`, bukan `jam`/isian/centang) dan
///     tiap potongan diperiksa ukurannya ([periksaPotongan]). Foto utuh bukan
///     masukan di sini.
///  2. **Apa pun yang gagal jatuh ke jalur lama.** [PenjalurSaranAwan.minta]
///     tidak pernah melempar: galat jaringan, 4xx/5xx, waktu habis, dan bug di
///     sisi sendiri semuanya menjadi [SebabGagalSaranAwan]. Layar tetap
///     bekerja; sel yang tidak terbaca tetap isi manual / pembaca di HP.
///  3. **Tidak ada ulang otomatis dan tidak ada tembakan paralel.** Permintaan
///     dikirim BERURUTAN (maksimal [maksSelPerPermintaanUnggah] sel per
///     permintaan), diberi jeda agar tidak melewati limiter 4 permintaan per
///     menit, dan berhenti pada galat pertama.
///
/// Hasilnya [PapanUsulanAwan] (USULAN): tidak ada nilai sebelum teknisi memutuskan
/// per sel. Potongan tidak disimpan dan tidak ditulis ke log di sini.

/// Satu sel yang ditawarkan ke awan.
class KandidatSelAwan {
  const KandidatSelAwan({required this.kunci, required this.potongan});

  /// Kunci templat server (`tabel|baris|repeat|field`), apa adanya.
  final String kunci;

  /// Potongan PNG/JPEG sel ini, dari pemotong yang sudah ada (di memori).
  final Uint8List potongan;
}

/// Kunci templat server untuk sel ANGKA: sel yang barisnya bertipe `angka`.
///
/// Sama dengan aturan gagal-tertutup server (`PemilahPotonganSel`): baris `jam`,
/// baris tanpa `tipe`, kunci yang tidak ada di templat, dan kunci `isian|`/
/// `centang|` tidak termasuk. Klien tidak boleh mengandalkan server untuk
/// membuang sel yang bukan angka.
Set<String> kunciSelAngka(WorksheetTemplate templat) {
  final barisAngka = <String>{
    for (final t in templat.tabel)
      for (final b in t.baris)
        if (b.tipe == 'angka') '${t.tabelId}|${b.barisKe}',
  };

  return {
    for (final s in templat.selAsli)
      if (!kunciSelIdentitas(s.kunci) &&
          barisAngka.contains('${s.tabelId}|${s.barisKe}'))
        s.kunci,
  };
}

/// Pilih sel yang layak ditawarkan ke awan dari baris review.
///
/// Syarat: kuncinya sel angka ([kunciAngka]), punya potongan, dan vonis di HP
/// BUKAN hijau (yang ditawarkan hanya sel yang ragu atau tidak terbaca). Sel
/// kosong di kertas tidak punya baris review, jadi tidak pernah sampai di sini
/// ("sel kosong tetap kosong").
///
/// [kunciServerPerBaris]: kunci baris review ([kunciSelFoto]) -> kunci templat
/// server. Baris yang tidak ada di peta ini (isian Env./header) tidak pernah
/// dikirim.
List<KandidatSelAwan> pilihKandidatAwan({
  required Set<String> kunciAngka,
  required List<BarisReviewFoto> baris,
  required Map<String, String> kunciServerPerBaris,
}) {
  final hasil = <KandidatSelAwan>[];
  final terlihat = <String>{};

  for (final b in baris) {
    final kunciServer =
        kunciServerPerBaris[kunciSelFoto(b.titikUkur, b.repeatNo, b.fieldId)];
    final potongan = b.potongan;

    if (kunciServer == null || potongan == null) continue;
    if (!kunciAngka.contains(kunciServer)) continue;
    if (b.vonis == VonisFoto.hijau) continue;
    if (!terlihat.add(kunciServer)) continue;

    hasil.add(KandidatSelAwan(kunci: kunciServer, potongan: potongan));
  }

  return hasil;
}

/// Kenapa usulan awan tidak (sepenuhnya) tersedia. Semuanya berakhir sama bagi
/// teknisi: lanjut dengan pembaca di HP / isi manual.
enum SebabGagalSaranAwan {
  /// Sakelar klien mati: tidak ada panggilan jaringan sama sekali.
  dimatikan,

  /// Tidak ada sel layak kirim (semuanya disaring di HP).
  tidakAdaSel,

  /// `503 fitur_dimatikan`: Super Admin mematikan fiturnya.
  fiturMati,

  /// `503 ocr_cloud_belum_aktif` / `ocr_cloud_belum_disetel`, dan 502/503/504 lain.
  awanBelumSiap,

  /// `429` jatah per lembar / per akun habis.
  jatahHabis,

  /// `429` limiter 4 permintaan per menit.
  terlaluSering,

  /// `502 ocr_cloud_gagal` / `422 gambar_tidak_terbaca`: awan tidak membaca.
  awanGagal,

  /// `422`/`404`/`403 bukan_sesi_anda` dari server: kiriman tidak diterima.
  ditolakServer,

  /// `401`/`403` peran, atau token tidak ada: akun ini tidak boleh memakai fitur.
  akses,

  /// Tidak ada jaringan, putus, atau waktu habis.
  jaringan,

  /// Galat lain yang tidak dikenal. Tetap jatuh ke jalur lama.
  lainnya,
}

/// Petakan SEMUA jenis galat ke [SebabGagalSaranAwan]. Tidak melempar.
SebabGagalSaranAwan petakanGalatSaranAwan(Object galat) {
  if (galat is GalatOcrAwan) {
    return switch (galat.jenis) {
      JenisGalatOcrAwan.fiturMati => SebabGagalSaranAwan.fiturMati,
      JenisGalatOcrAwan.awanBelumSiap => SebabGagalSaranAwan.awanBelumSiap,
      JenisGalatOcrAwan.jatahHabis => SebabGagalSaranAwan.jatahHabis,
      JenisGalatOcrAwan.terlaluSering => SebabGagalSaranAwan.terlaluSering,
      JenisGalatOcrAwan.awanGagal ||
      JenisGalatOcrAwan.tidakTerbaca => SebabGagalSaranAwan.awanGagal,
      JenisGalatOcrAwan.permintaanDitolak ||
      JenisGalatOcrAwan.tidakAdaPotongan ||
      JenisGalatOcrAwan.sesiBermasalah ||
      JenisGalatOcrAwan.citraBermasalah => SebabGagalSaranAwan.ditolakServer,
      JenisGalatOcrAwan.lainnya => SebabGagalSaranAwan.lainnya,
    };
  }

  if (galat is KoneksiException ||
      galat is TimeoutException ||
      galat is SocketException) {
    return SebabGagalSaranAwan.jaringan;
  }

  if (galat is ApiException) {
    return switch (galat.status) {
      401 || 403 => SebabGagalSaranAwan.akses,
      429 => SebabGagalSaranAwan.terlaluSering,
      502 || 503 || 504 => SebabGagalSaranAwan.awanBelumSiap,
      404 || 422 => SebabGagalSaranAwan.ditolakServer,
      _ => SebabGagalSaranAwan.lainnya,
    };
  }

  return SebabGagalSaranAwan.lainnya;
}

/// Hasil satu putaran [PenjalurSaranAwan.minta].
class HasilSaranAwan {
  const HasilSaranAwan({
    this.papan,
    this.sebabGagal,
    this.jumlahDikirim = 0,
    this.jumlahTidakTerkirim = 0,
    this.jumlahDitahanDiHp = 0,
    this.dibatalkan = false,
  });

  /// Usulan (semuanya menunggu keputusan). `null` = tidak ada satu pun jawaban
  /// server yang sampai.
  final PapanUsulanAwan? papan;

  /// `null` = semua permintaan berjalan sampai selesai.
  final SebabGagalSaranAwan? sebabGagal;

  /// Potongan dalam permintaan yang dijawab server.
  final int jumlahDikirim;

  /// Potongan layak kirim yang tidak sempat dikirim (berhenti oleh galat atau
  /// dibatalkan). Tetap isi manual.
  final int jumlahTidakTerkirim;

  /// Potongan yang ditahan di HP karena melewati batas ukuran server. Tidak
  /// diperkecil dan tidak dikirim.
  final int jumlahDitahanDiHp;

  /// Dihentikan pemanggil (mis. layar review ditutup).
  final bool dibatalkan;

  /// Tidak ada jawaban server yang bisa ditampilkan.
  bool get gagalTotal => papan == null;

  /// Ada sel yang tidak ikut terbaca awan, apa pun sebabnya.
  bool get sebagian =>
      sebabGagal != null ||
      dibatalkan ||
      jumlahTidakTerkirim > 0 ||
      jumlahDitahanDiHp > 0;
}

typedef Tidur = Future<void> Function(Duration lama);

Future<void> _tidurNyata(Duration lama) => Future<void>.delayed(lama);

String _kodeDilewatiLokal(AlasanPotonganDitolak a) => switch (a) {
  AlasanPotonganDitolak.bukanCitra => 'potongan_bukan_citra',
  AlasanPotonganDitolak.kebesaranByte => 'potongan_kebesaran_byte',
  AlasanPotonganDitolak.kebesaranPiksel => 'potongan_kebesaran_piksel',
};

class PenjalurSaranAwan {
  PenjalurSaranAwan({
    required OcrAwanSelService service,
    required Future<String?> Function() bacaToken,
    bool Function()? nyala,
    DateTime Function()? sekarang,
    Tidur? tidur,
    this.maksPermintaanPerJendela = 4,
    this.jendela = const Duration(seconds: 60),
  }) : _service = service,
       _bacaToken = bacaToken,
       _nyala = nyala ?? (() => true),
       _sekarang = sekarang ?? DateTime.now,
       _tidur = tidur ?? _tidurNyata;

  final OcrAwanSelService _service;
  final Future<String?> Function() _bacaToken;
  final bool Function() _nyala;
  final DateTime Function() _sekarang;
  final Tidur _tidur;

  /// Limiter server `ocr-sel-unggah`: 4 permintaan per menit per akun.
  final int maksPermintaanPerJendela;
  final Duration jendela;

  /// Saat tiap permintaan dikirim (termasuk yang gagal: server tetap
  /// menghitungnya). Hidup selama penjalurnya hidup, jadi jendela limiter
  /// berlaku lintas layar review.
  final List<DateTime> _dikirim = [];

  /// Tunggu sampai permintaan berikutnya aman terhadap limiter, lalu catat.
  /// `false` bila dibatalkan selagi menunggu.
  Future<bool> _giliran(bool Function()? dibatalkan) async {
    while (true) {
      if (dibatalkan?.call() ?? false) return false;

      final kini = _sekarang();
      _dikirim.removeWhere((t) => kini.difference(t) >= jendela);

      if (_dikirim.length < maksPermintaanPerJendela) {
        _dikirim.add(kini);
        return true;
      }

      // Yang tertua keluar dari jendela sesudah ini; +1 detik cadangan jam.
      final tunggu =
          jendela -
          kini.difference(_dikirim.first) +
          const Duration(seconds: 1);
      await _tidur(tunggu);
    }
  }

  /// Minta usulan awan untuk [kandidat]. TIDAK PERNAH melempar.
  ///
  /// [onKemajuan] dipanggil `(selesai, total)` dalam hitungan permintaan.
  /// [dibatalkan] dicek sebelum tiap permintaan dan selagi menunggu jeda.
  Future<HasilSaranAwan> minta({
    required KonteksOcrAwanSel konteks,
    required List<KandidatSelAwan> kandidat,
    void Function(int selesai, int total)? onKemajuan,
    bool Function()? dibatalkan,
  }) async {
    // Sakelar mati = perilaku lama persis: tidak membaca token, tidak ada
    // panggilan jaringan.
    if (!_nyala()) {
      return const HasilSaranAwan(sebabGagal: SebabGagalSaranAwan.dimatikan);
    }

    try {
      return await _jalankan(konteks, kandidat, onKemajuan, dibatalkan);
    } catch (e) {
      // Jaring terakhir: bug di sisi sendiri pun tidak boleh menjatuhkan layar
      // review. Isi galat tidak dicatat (bisa memuat data kerja).
      return HasilSaranAwan(
        sebabGagal: petakanGalatSaranAwan(e),
        jumlahTidakTerkirim: kandidat.length,
      );
    }
  }

  Future<HasilSaranAwan> _jalankan(
    KonteksOcrAwanSel konteks,
    List<KandidatSelAwan> kandidat,
    void Function(int selesai, int total)? onKemajuan,
    bool Function()? dibatalkan,
  ) async {
    // Saring di HP: kunci kembar/kosong/identitas dan potongan di luar batas
    // ukuran tidak pernah dikirim (dan tidak diperkecil).
    final layak = <PotonganSelAwan>[];
    final ditahan = <SelDilewatiAwan>[];
    final terlihat = <String>{};

    for (final k in kandidat) {
      if (k.kunci.trim().isEmpty ||
          kunciSelIdentitas(k.kunci) ||
          !terlihat.add(k.kunci)) {
        continue;
      }

      final alasan = periksaPotongan(k.potongan);
      if (alasan != null) {
        ditahan.add(
          SelDilewatiAwan(kunci: k.kunci, alasan: _kodeDilewatiLokal(alasan)),
        );
        continue;
      }

      layak.add(PotonganSelAwan(kunci: k.kunci, isi: k.potongan));
    }

    if (layak.isEmpty) {
      return HasilSaranAwan(
        sebabGagal: SebabGagalSaranAwan.tidakAdaSel,
        jumlahDitahanDiHp: ditahan.length,
      );
    }

    final token = await _bacaToken();
    if (token == null || token.isEmpty) {
      return HasilSaranAwan(
        sebabGagal: SebabGagalSaranAwan.akses,
        jumlahTidakTerkirim: layak.length,
        jumlahDitahanDiHp: ditahan.length,
      );
    }

    final bagian = <List<PotonganSelAwan>>[
      for (var i = 0; i < layak.length; i += maksSelPerPermintaanUnggah)
        layak.sublist(
          i,
          i + maksSelPerPermintaanUnggah > layak.length
              ? layak.length
              : i + maksSelPerPermintaanUnggah,
        ),
    ];

    final hasil = <SelOcrAwan>[];
    final dilewati = <SelDilewatiAwan>[];
    var sebagianServer = false;
    var dikirim = 0;
    var panggilan = 0;
    var selesai = 0;
    int? sisa;
    SebabGagalSaranAwan? sebab;
    var batal = false;

    onKemajuan?.call(0, bagian.length);

    for (final b in bagian) {
      if (!await _giliran(dibatalkan)) {
        batal = true;
        break;
      }

      try {
        final h = await _service.bacaSel(token, konteks: konteks, sel: b);
        hasil.addAll(h.hasil);
        dilewati.addAll(h.dilewati);
        sebagianServer = sebagianServer || h.meta.sebagian;
        dikirim += b.length;
        panggilan += h.meta.jumlahPanggilan ?? 0;
        sisa = h.meta.sisaSelLembar ?? sisa;
        selesai++;
        onKemajuan?.call(selesai, bagian.length);
      } catch (e) {
        // Satu galat menghentikan sisanya: tidak ada ulang otomatis.
        sebab = petakanGalatSaranAwan(e);
        break;
      }
    }

    final tidakTerkirim = layak.length - dikirim;
    dilewati.addAll(ditahan);

    final papan = selesai == 0
        ? null
        : PapanUsulanAwan.dari(
            HasilOcrAwan(
              hasil: hasil,
              dilewati: dilewati,
              meta: MetaOcrAwan(
                jumlahDikirim: dikirim,
                jumlahPanggilan: panggilan,
                sebagian:
                    sebagianServer ||
                    sebab != null ||
                    batal ||
                    tidakTerkirim > 0,
                sisaSelLembar: sisa,
              ),
            ),
          );

    return HasilSaranAwan(
      papan: papan,
      sebabGagal: sebab,
      jumlahDikirim: dikirim,
      jumlahTidakTerkirim: tidakTerkirim,
      jumlahDitahanDiHp: ditahan.length,
      dibatalkan: batal,
    );
  }
}
