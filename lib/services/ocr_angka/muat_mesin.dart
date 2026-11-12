import 'mesin_angka.dart';
import 'meta_model.dart';
import 'sesi_inferensi.dart';
import 'sumber_model_ocr.dart';

/// Kenapa mesin angka TIDAK dimuat. Semuanya berakhir sama bagi teknisi:
/// pembaca jatuh ke ML Kit, tanpa crash.
enum PenolakanMesin {
  /// Tidak ada runtime inferensi di build ini ([BuatSesiCtc] `null`).
  runtimeTidakAda,

  /// `meta.json` atau berkas model tidak ditemukan di sumber.
  modelTidakAda,
  metaTidakSah,

  /// Berkas model tidak sama dengan sha256 di meta (rusak/tertukar).
  sha256TidakCocok,

  /// sha256 model bukan salah satu yang dipatok di app (build rilis hanya
  /// memuat model yang dipatok; model dari folder perangkat tidak dipercaya).
  sha256TakDikenal,

  /// Bukti akurasi model masih SINTETIS dan sakelar developer tidak menyala.
  buktiSintetisDitolak,

  /// Runtime gagal membuat sesi (pustaka native, memori).
  runtimeGagalDimuat,
}

typedef HasilMuatMesin = ({MesinAngka? mesin, PenolakanMesin? ditolak});

/// Gerbang pemuatan mesin angka. Semua harus lolos, kalau tidak: tidak ada
/// mesin (dan tidak ada galat yang bocor ke pemanggil).
///
///  1. runtime tersedia;
///  2. meta + model ada di [sumber];
///  3. meta sah (kolom, sha256, alfabet);
///  4. sha256 model = sha256 di meta;
///  5. bukti `SINTETIS` hanya diterima bila [izinkanSintetis] (sakelar
///     developer);
///  6. bila [sha256Dipercaya] diberikan: sha256 model harus ada di dalamnya;
///  7. runtime sanggup membuat sesi.
Future<HasilMuatMesin> muatMesinAngka({
  required SumberModelOcr sumber,
  required BuatSesiCtc? buatSesi,
  required bool izinkanSintetis,
  Set<String>? sha256Dipercaya,
}) async {
  if (buatSesi == null) {
    return (mesin: null, ditolak: PenolakanMesin.runtimeTidakAda);
  }

  final metaJson = await sumber.metaJson();
  if (metaJson == null) {
    return (mesin: null, ditolak: PenolakanMesin.modelTidakAda);
  }

  final meta = MetaModelOcr.dari(metaJson);
  if (meta == null) {
    return (mesin: null, ditolak: PenolakanMesin.metaTidakSah);
  }

  final model = await sumber.model(meta.berkas);
  if (model == null) {
    return (mesin: null, ditolak: PenolakanMesin.modelTidakAda);
  }

  if (!meta.cocokDengan(model)) {
    return (mesin: null, ditolak: PenolakanMesin.sha256TidakCocok);
  }

  if (meta.buktiSintetis && !izinkanSintetis) {
    return (mesin: null, ditolak: PenolakanMesin.buktiSintetisDitolak);
  }

  if (sha256Dipercaya != null && !sha256Dipercaya.contains(meta.sha256)) {
    return (mesin: null, ditolak: PenolakanMesin.sha256TakDikenal);
  }

  try {
    final sesi = await buatSesi(model);
    return (mesin: MesinAngka(sesi: sesi, meta: meta), ditolak: null);
  } catch (_) {
    return (mesin: null, ditolak: PenolakanMesin.runtimeGagalDimuat);
  }
}
