/// Hasil sertifikat Enclosure (Oven, Furnace, Bath, Inkubator, Refrigerator)
/// — `snapshot.enclosure` dari `GET /api/certificates/{id}`.
///
/// Master mencetak DUA bagian, bukan tabel `Standard | UUT | Correction`:
/// A) Sebaran Suhu per posisi termokopel (Terukur & Koreksi terhadap
/// Indikator, U95 per set point) dan B) Kinerja Enklosur (Keseragaman,
/// Kestabilan, Variasi Keseluruhan). `snapshot.hasil` untuk alat ini `[]`.
///
/// Angkanya presisi penuh dari server dan TIDAK dihitung di sini; layar cuma
/// membulatkan dengan [desimal] / [desimalU95] / [desimalK] — persis
/// `sertifikat/pdf.blade.php`. Kontrak: `docs/perintah-frontend-enclosure.md`
/// §6 di repo API.
library;

double? _angka(Object? v) => v is num ? v.toDouble() : null;
int? _bulat(Object? v) => v is num ? v.toInt() : null;

/// Satu kolom posisi termokopel di chamber.
class PosisiEnclosure {
  const PosisiEnclosure({required this.posisi, this.no});

  /// Nomor kolom yang tercetak di kepala tabel.
  final int posisi;

  /// Nomor termokopel di posisi itu (Type N mulai 3, Type K mulai 1).
  final int? no;

  static PosisiEnclosure? dariJson(Object? raw) {
    if (raw is! Map) return null;
    final posisi = _bulat(raw['posisi']);
    if (posisi == null) return null;
    return PosisiEnclosure(posisi: posisi, no: _bulat(raw['no']));
  }
}

/// Satu termokopel di satu set point.
class SensorEnclosure {
  const SensorEnclosure({
    this.posisi,
    this.no,
    this.channel,
    this.terukur,
    this.koreksi,
  });

  final int? posisi;
  final int? no;

  /// Kanal recorder (CH1..CH20); `null` untuk kalibrator tanpa kanal.
  final int? channel;

  /// Rata-rata terkoreksi.
  final double? terukur;

  /// Terukur − Indikator.
  final double? koreksi;

  static SensorEnclosure? dariJson(Object? raw) {
    if (raw is! Map) return null;
    return SensorEnclosure(
      posisi: _bulat(raw['posisi']),
      no: _bulat(raw['no']),
      channel: _bulat(raw['channel']),
      terukur: _angka(raw['terukur']),
      koreksi: _angka(raw['koreksi']),
    );
  }
}

/// Satu set point: satu baris di tabel A (dua baris cetak: Terukur & Koreksi)
/// dan satu baris di tabel B.
class SetPointEnclosure {
  const SetPointEnclosure({
    this.titikKe,
    this.setPoint,
    this.indikator,
    this.sensorAcuan,
    this.posisiAcuan,
    this.sensor = const [],
    this.keseragaman,
    this.kestabilan,
    this.variasiKeseluruhan,
    this.u95,
    this.faktorCakupanK,
  });

  final int? titikKe;
  final double? setPoint;
  final double? indikator;

  /// Nomor termokopel yang jadi acuan keseragaman di set point ini.
  final int? sensorAcuan;

  /// Posisi (kolom) Sensor Acuan — bisa bergeser kalau termokopel bernomor
  /// terkecil kosong di set point ini.
  final int? posisiAcuan;

  /// SEJAJAR dengan [EnclosureSertifikat.posisi]: `sensor[i]` milik
  /// `posisi[i]`, dan `null` = termokopel itu kosong di set point ini. Kolom
  /// tidak boleh digeser.
  final List<SensorEnclosure?> sensor;

  final double? keseragaman;
  final double? kestabilan;
  final double? variasiKeseluruhan;
  final double? u95;
  final double? faktorCakupanK;

  /// Sensor untuk kolom ke-[i], `null` kalau kosong atau di luar daftar.
  SensorEnclosure? sensorDi(int i) => i < sensor.length ? sensor[i] : null;

  static SetPointEnclosure? dariJson(Object? raw) {
    if (raw is! Map) return null;
    final sensor = raw['sensor'];
    return SetPointEnclosure(
      titikKe: _bulat(raw['titik_ke']),
      setPoint: _angka(raw['set_point']),
      indikator: _angka(raw['indikator']),
      sensorAcuan: _bulat(raw['sensor_acuan']),
      posisiAcuan: _bulat(raw['posisi_acuan']),
      // `null` di dalam daftar DIPERTAHANKAN — itu penanda kolom kosong.
      sensor: [
        if (sensor is List)
          for (final s in sensor) SensorEnclosure.dariJson(s),
      ],
      keseragaman: _angka(raw['keseragaman']),
      kestabilan: _angka(raw['kestabilan']),
      variasiKeseluruhan: _angka(raw['variasi_keseluruhan']),
      u95: _angka(raw['u95']),
      faktorCakupanK: _angka(raw['faktor_cakupan_k']),
    );
  }
}

class EnclosureSertifikat {
  const EnclosureSertifikat({
    this.satuan,
    this.desimal = 1,
    int? desimalU95,
    this.desimalK,
    this.tandaNol = true,
    this.posisi = const [],
    this.setPoint = const [],
  }) : desimalU95 = desimalU95 ?? desimal;

  final String? satuan;

  /// Desimal Terukur, Koreksi, Indikator, Set point, dan tabel B. Bawaan 1 —
  /// sama dengan `pdf.blade.php` kalau kuncinya tidak ada.
  final int desimal;

  /// Desimal U95; jatuh ke [desimal] kalau server tidak mengirimnya.
  final int desimalU95;

  /// Desimal faktor cakupan `k`. `null` = paling banyak 2 desimal, nol di
  /// belakang dibuang (perilaku PDF yang sama).
  final int? desimalK;

  /// Koreksi negatif yang membulat ke nol dicetak `-0,0` atau `0,0`.
  final bool tandaNol;

  final List<PosisiEnclosure> posisi;
  final List<SetPointEnclosure> setPoint;

  /// `null` kalau [raw] bukan peta atau peta kosong.
  static EnclosureSertifikat? dariJson(Object? raw) {
    if (raw is! Map || raw.isEmpty) return null;
    final posisi = raw['posisi'];
    final setPoint = raw['set_point'];
    return EnclosureSertifikat(
      satuan: raw['satuan'] as String?,
      desimal: _bulat(raw['desimal']) ?? 1,
      desimalU95: _bulat(raw['desimal_u95']),
      desimalK: _bulat(raw['desimal_k']),
      tandaNol: raw['tanda_nol'] is bool ? raw['tanda_nol'] as bool : true,
      posisi: [
        if (posisi is List)
          for (final p in posisi) ?PosisiEnclosure.dariJson(p),
      ],
      setPoint: [
        if (setPoint is List)
          for (final s in setPoint) ?SetPointEnclosure.dariJson(s),
      ],
    );
  }
}
