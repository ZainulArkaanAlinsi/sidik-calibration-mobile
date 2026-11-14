// lib/widgets/biru_awan/visual_alat.dart
// Gambar alat: 48 alat lampiran LK-285-IDN + contoh alat baru + 7 gambar bentuk.
// PNG transparan 1x/2x/3x di assets/images/visual/ (ekspor dari aset/visual/*.svg).
// Urutan cari: nama persis -> alias -> kata kunci bentuk -> kelompok -> umum.
// Hasil TIDAK PERNAH kosong.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class PetaVisualAlat {
  /// 1. Nama alat persis (huruf kecil, spasi dirapikan).
  static const Map<String, String> perAlat = {
    'temperature indicator tanpa sensor': 'ti_tanpa_sensor', // 01 Suhu dan Kelembapan
    'temperatur indikator dengan sensor': 'ti_sensor', // 02 Suhu dan Kelembapan
    'temperatur transmitter': 'transmitter', // 03 Suhu dan Kelembapan
    'termometer gelas': 'termometer_gelas', // 04 Suhu dan Kelembapan
    'thermocouple': 'thermocouple', // 05 Suhu dan Kelembapan
    'oven': 'oven', // 06 Suhu dan Kelembapan
    'bath': 'bath', // 07 Suhu dan Kelembapan
    'inkubator': 'inkubator', // 08 Suhu dan Kelembapan
    'furnace': 'furnace', // 09 Suhu dan Kelembapan
    'refrigerator': 'refrigerator', // 10 Suhu dan Kelembapan
    'thermohygrometer': 'thermohygro', // 11 Suhu dan Kelembapan
    'timbangan (elektronik, mekanik)': 'timbangan', // 12 Massa
    'buret': 'buret', // 13 Volume
    'buret digital': 'buret_digital', // 14 Volume
    'piston pipette': 'piston_pipette', // 15 Volume
    'dispensett': 'dispensett', // 16 Volume
    'gelas ukur': 'gelas_ukur', // 17 Volume
    'labu ukur': 'labu_ukur', // 18 Volume
    'pipet ukur': 'pipet_ukur', // 19 Volume
    'pipet volume': 'pipet_volume', // 20 Volume
    'picnometer': 'picnometer', // 21 Volume
    'pressure transmitter': 'pressure_transmitter', // 22 Tekanan
    'pressure gauge': 'pressure_gauge', // 23 Tekanan
    'pressure transducer, recorder, safety valve, manometer': 'pressure_transducer', // 24 Tekanan
    'vacuum gauge': 'vacuum_gauge', // 25 Tekanan
    'differential pressure': 'differential_pressure', // 26 Tekanan
    'mesin utm': 'utm', // 27 Gaya
    'load cell': 'load_cell', // 28 Gaya
    'proving ring': 'proving_ring', // 29 Gaya
    'flow meter cairan (totalizer)': 'totalizer', // 30 Aliran
    'flow meter cairan (flowrate)': 'flowrate', // 31 Aliran
    'hydrometer': 'hidrometer', // 32 Densitas
    'sieve': 'sieve', // 33 Panjang
    'micrometer': 'micrometer', // 34 Panjang
    'vernier caliper': 'vernier', // 35 Panjang
    'dial indicator': 'dial_indicator', // 36 Panjang
    'timer/stopwatch': 'stopwatch', // 37 Waktu dan Frekuensi
    'centrifuge': 'centrifuge', // 38 Waktu dan Frekuensi
    'infrared tachometer': 'tachometer', // 39 Waktu dan Frekuensi
    'conductivitymeter': 'conductivity', // 40 Instrumen Analitik
    'ph meter': 'ph_meter', // 41 Instrumen Analitik
    'chlorin meter': 'chlorine', // 42 Instrumen Analitik
    'turbidimeter': 'turbidimeter', // 43 Instrumen Analitik
    'viscometer': 'viscometer', // 44 Instrumen Analitik
    'refractometer': 'refractometer', // 45 Instrumen Analitik
    'do meter': 'do_meter', // 46 Instrumen Analitik
    'spektrofotometer': 'spektrofotometer', // 47 Instrumen Analitik
    'autoklaf': 'autoklaf', // 48 Instrumen Analitik
    // Contoh alat di luar lampiran (sudah digambar):
    'tensimeter': 'tensimeter', 'tensimeter digital': 'tensimeter', 'sphygmomanometer': 'tensimeter',
    'infusion pump': 'infus_pump', 'pompa infus': 'infus_pump', 'syringe pump': 'infus_pump',
  };

  /// 2. Ejaan lain dari data server/lama -> nama baku di [perAlat].
  static const Map<String, String> alias = {
    'incubator': 'inkubator', 'autoclave': 'autoklaf',
    'temperature indicator': 'temperatur indikator dengan sensor',
    'temperature indicator dengan sensor': 'temperatur indikator dengan sensor',
    'vernier caliper digital': 'vernier caliper', 'jangka sorong': 'vernier caliper',
    'mikrometer': 'micrometer', 'stopwatch': 'timer/stopwatch', 'timer': 'timer/stopwatch',
    'conductivity meter': 'conductivitymeter', 'chlorine meter': 'chlorin meter',
    'spectrophotometer': 'spektrofotometer', 'flow meter cairan': 'flow meter cairan (flowrate)',
    'pressure transducer': 'pressure transducer, recorder, safety valve, manometer',
    'pressure recorder': 'pressure transducer, recorder, safety valve, manometer',
    'pressure safety valve': 'pressure transducer, recorder, safety valve, manometer',
    'manometer': 'pressure transducer, recorder, safety valve, manometer',
    'timbangan': 'timbangan (elektronik, mekanik)', 'timbangan analitik': 'timbangan (elektronik, mekanik)',
  };

  /// 3. Kata kunci di nama alat -> gambar bentuk (dicek berurutan, yang pertama cocok menang).
  static const List<(String, String)> kataKunciBentuk = [
    ('oven', 'bentuk_lemari'), ('chamber', 'bentuk_lemari'), ('freezer', 'bentuk_lemari'),
    ('kulkas', 'bentuk_lemari'), ('kabinet', 'bentuk_lemari'), ('cabinet', 'bentuk_lemari'),
    ('steril', 'bentuk_lemari'), ('incubat', 'bentuk_lemari'),
    ('centrifug', 'bentuk_putar'), ('shaker', 'bentuk_putar'), ('stirrer', 'bentuk_putar'),
    ('mixer', 'bentuk_putar'), ('rotator', 'bentuk_putar'),
    ('labu', 'bentuk_kaca'), ('gelas', 'bentuk_kaca'), ('tabung', 'bentuk_kaca'),
    ('flask', 'bentuk_kaca'), ('beaker', 'bentuk_kaca'), ('kuvet', 'bentuk_kaca'),
    ('probe', 'bentuk_probe'), ('sensor', 'bentuk_probe'), ('elektroda', 'bentuk_probe'),
    ('transmitter', 'bentuk_probe'),
    ('analyzer', 'bentuk_meja'), ('analyser', 'bentuk_meja'), ('fotometer', 'bentuk_meja'),
    ('photometer', 'bentuk_meja'), ('kolorimeter', 'bentuk_meja'), ('pump', 'bentuk_meja'),
    ('pompa', 'bentuk_meja'), ('monitor', 'bentuk_meja'), ('ecg', 'bentuk_meja'),
    ('ekg', 'bentuk_meja'), ('defibrilator', 'bentuk_meja'), ('ventilator', 'bentuk_meja'),
    ('meter', 'bentuk_genggam'), ('tester', 'bentuk_genggam'), ('detektor', 'bentuk_genggam'),
    ('detector', 'bentuk_genggam'), ('oksimeter', 'bentuk_genggam'), ('oximeter', 'bentuk_genggam'),
    ('termometer', 'bentuk_genggam'), ('thermometer', 'bentuk_genggam'), ('gauge', 'pressure_gauge'),
  ];

  /// 4. Kelompok besaran (10 kelompok LK-285-IDN).
  static const Map<String, String> perKelompok = {
    'suhu dan kelembapan': 'ti_sensor', 'massa': 'timbangan', 'volume': 'pipet_ukur',
    'tekanan': 'pressure_gauge', 'gaya': 'load_cell', 'aliran': 'flowrate',
    'densitas': 'hidrometer', 'panjang': 'vernier', 'waktu dan frekuensi': 'stopwatch',
    'instrumen analitik': 'ph_meter',
  };

  /// 5. Terakhir.
  static const String umum = 'bentuk_umum';

  static String cari({required String nama, String? kelompok}) {
    var n = nama.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    n = alias[n] ?? n;
    final persis = perAlat[n];
    if (persis != null) return persis;
    for (final (kata, berkas) in kataKunciBentuk) {
      if (n.contains(kata)) return _catat(nama, berkas);
    }
    final k = kelompok?.trim().toLowerCase();
    final perK = k == null ? null : perKelompok[k];
    return _catat(nama, perK ?? umum);
  }

  /// Nama yang belum punya gambar sendiri dicatat (debug) supaya jadi daftar kerja gambar.
  static String _catat(String nama, String berkas) {
    if (kDebugMode) debugPrint('VisualAlat: "$nama" belum punya gambar sendiri -> $berkas');
    return berkas;
  }
}

/// Murni dekoratif; selalu menggambar sesuatu (paling tidak gambar umum).
class VisualAlat extends StatelessWidget {
  const VisualAlat({super.key, required this.nama, this.kelompok, required this.ukuran});

  final String nama;
  final String? kelompok;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final berkas = PetaVisualAlat.cari(nama: nama, kelompok: kelompok);
    return ExcludeSemantics(
      child: Image.asset('assets/images/visual/$berkas.png',
          width: ukuran, height: ukuran, filterQuality: FilterQuality.medium),
    );
  }
}
