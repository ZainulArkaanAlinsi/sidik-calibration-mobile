/// Isi sertifikat yang **dibekukan waktu terbit** (`GET /api/certificates/{id}`
/// → `snapshot`).
///
/// Sertifikat yang udah dipegang pelanggan nggak boleh berubah cuma gara-gara
/// data master diedit belakangan. Makanya isinya disalin utuh waktu terbit, dan
/// PDF, Excel, halaman verifikasi QR, serta layar ini semuanya baca salinan
/// yang sama — mustahil beda isi.
///
/// **Jangan tambah field di luar struktur ini** (spesifikasi poin 9). Yang
/// dirender di sini persis yang dicetak; kalau ada yang kurang, yang ditambah
/// snapshot-nya di backend, bukan tempelan di layar.
library;

/// Header — 16 field, urutannya ngikutin yang tercetak di sertifikat.
class HeaderSertifikat {
  const HeaderSertifikat(this._raw);

  final Map<String, dynamic> _raw;

  String? _t(String k) {
    final v = _raw[k];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  String? get certificateNumber => _t('certificate_number');
  String? get page => _t('page');
  String? get owner => _t('owner');
  String? get orderNumber => _t('order_number');
  String? get address => _t('address');
  String? get receivedDate => _t('received_date');
  String? get equipmentName => _t('equipment_name');
  String? get manufacturer => _t('manufacturer');
  String? get calibrationLocation => _t('calibration_location');
  String? get modelType => _t('model_type');
  String? get calibrationDate => _t('calibration_date');
  String? get serialNumber => _t('serial_number');
  String? get calibrationMethod => _t('calibration_method');
  String? get capacityGraduation => _t('capacity_graduation');
  String? get envCondition => _t('env_condition');
  String? get technicianId => _t('technician_id');

  /// Pasangan label→nilai siap render, urutannya persis sertifikat cetak.
  List<(String, String?)> baris() => [
    ('Certificate Number', certificateNumber),
    ('Page', page),
    ('Owner', owner),
    ('Order Number', orderNumber),
    ('Address', address),
    ('Received Date', receivedDate),
    ('Equipment Name', equipmentName),
    ('Manufacturer', manufacturer),
    ('Calibration Location', calibrationLocation),
    ('Model/Type', modelType),
    ('Calibration Date', calibrationDate),
    ('Serial Number', serialNumber),
    ('Calibration Method', calibrationMethod),
    ('Capacity/Graduation', capacityGraduation),
    ('Env. Condition', envCondition),
    ('Technician ID', technicianId),
  ];
}

/// Satu baris tabel hasil — **empat kolom**, nggak lebih.
class BarisHasilSertifikat {
  const BarisHasilSertifikat({
    required this.titikKe,
    required this.standardValue,
    required this.unitUnderTest,
    required this.correction,
    required this.u95,
  });

  final int titikKe;
  final double standardValue;
  final double unitUnderTest;

  /// **Di sertifikat Correction = Standard − Average** — kebalikan dari lembar
  /// PERHITUNGAN. Dua-duanya bener, jangan dipakai silang.
  final double correction;

  final double u95;

  factory BarisHasilSertifikat.fromJson(Map<String, dynamic> json) =>
      BarisHasilSertifikat(
        titikKe: (json['titik_ke'] as num?)?.toInt() ?? 0,
        standardValue: (json['standard_value'] as num?)?.toDouble() ?? 0,
        unitUnderTest: (json['unit_under_test'] as num?)?.toDouble() ?? 0,
        correction: (json['correction'] as num?)?.toDouble() ?? 0,
        u95: (json['u95'] as num?)?.toDouble() ?? 0,
      );
}

/// Satu baris tabel "Standard Used".
class StandarDigunakan {
  const StandarDigunakan({this.name, this.merkType, this.serialNumber, this.traceableTo});

  final String? name;
  final String? merkType;
  final String? serialNumber;
  final String? traceableTo;

  factory StandarDigunakan.fromJson(Map<String, dynamic> json) =>
      StandarDigunakan(
        name: json['name'] as String?,
        merkType: json['merk_type'] as String?,
        serialNumber: json['serial_number'] as String?,
        traceableTo: json['traceable_to'] as String?,
      );
}

class FooterSertifikat {
  const FooterSertifikat({
    this.issuanceDate,
    this.penandatangan,
    this.jabatan,
    this.kodeDokumen,
  });

  final String? issuanceDate;
  final String? penandatangan;
  final String? jabatan;
  final String? kodeDokumen;

  factory FooterSertifikat.fromJson(Map<String, dynamic> json) =>
      FooterSertifikat(
        issuanceDate: json['issuance_date'] as String?,
        penandatangan: json['penandatangan'] as String?,
        jabatan: json['jabatan'] as String?,
        kodeDokumen: json['kode_dokumen'] as String?,
      );
}

class CertificateSnapshot {
  const CertificateSnapshot({
    required this.header,
    required this.hasil,
    required this.catatan,
    required this.standarDigunakan,
    required this.footer,
    this.desimal = 2,
    this.satuan,
    this.keputusan,
  });

  final HeaderSertifikat header;
  final List<BarisHasilSertifikat> hasil;

  /// Dua catatan baku di bawah tabel. **Datang dari backend**, bukan ditulis
  /// ulang di mobile — kalau lab merevisi kalimatnya, yang berubah satu tempat.
  final List<String> catatan;

  final List<StandarDigunakan> standarDigunakan;
  final FooterSertifikat footer;

  /// Berapa desimal angka hasil dicetak. Ditentukan backend dari resolusi
  /// alatnya, jadi jangan dipatok di sini.
  final int desimal;

  final String? satuan;

  /// `PASS` / `FAIL`. Sesi FAIL tetap terbit sertifikatnya — yang beda
  /// keputusannya, bukan boleh/nggaknya terbit.
  final String? keputusan;

  bool get gagal => keputusan == 'FAIL';

  factory CertificateSnapshot.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return CertificateSnapshot(
      desimal: (json['desimal'] as num?)?.toInt() ?? 2,
      satuan: json['satuan'] as String?,
      keputusan: meta['keputusan'] as String?,
      header: HeaderSertifikat(
        json['header'] as Map<String, dynamic>? ?? const {},
      ),
      hasil: (json['hasil'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BarisHasilSertifikat.fromJson)
          .toList(),
      catatan: (json['catatan'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
      standarDigunakan: (json['standar_digunakan'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(StandarDigunakan.fromJson)
          .toList(),
      footer: FooterSertifikat.fromJson(
        json['footer'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Respons `GET /api/certificates/{id}` — ringkasan + snapshot + hasil
/// pemeriksaan waktu terbit.
class CertificateDetail {
  const CertificateDetail({
    required this.id,
    required this.nomor,
    required this.status,
    this.snapshot,
    this.pdfUrl,
    this.qrToken,
    this.diterbitkanPada,
  });

  final int id;
  final String nomor;

  /// `terbit` / `menunggu_generate` / `gagal`.
  final String status;

  /// `null` kalau PDF-nya belum jadi — snapshot dibekukan waktu terbit, jadi
  /// sertifikat yang gagal generate belum punya isi.
  final CertificateSnapshot? snapshot;

  final String? pdfUrl;
  final String? qrToken;
  final String? diterbitkanPada;

  bool get siap => status == 'terbit';

  factory CertificateDetail.fromJson(Map<String, dynamic> json) =>
      CertificateDetail(
        id: (json['id'] as num).toInt(),
        nomor: json['nomor'] as String? ?? '',
        status: json['status'] as String? ?? 'menunggu_generate',
        pdfUrl: json['pdf_url'] as String?,
        qrToken: json['qr_token'] as String?,
        diterbitkanPada: json['diterbitkan_pada'] as String?,
        snapshot: json['snapshot'] is Map<String, dynamic>
            ? CertificateSnapshot.fromJson(
                json['snapshot'] as Map<String, dynamic>,
              )
            : null,
      );
}
