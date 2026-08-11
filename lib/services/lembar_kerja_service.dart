import 'mock_store.dart';
import '../models/lembar_kerja.dart';
import '../models/lembar_kerja_submission.dart';
import 'api_client.dart';
import 'equipment_lookup_service.dart';

/// Lembar kerja teknisi: ambil bentuk formulirnya, kirim isiannya.
abstract class LembarKerjaService {
  /// Bentuk formulir dari `GET /api/calibrations/lembar-kerja`. Responsnya
  /// udah disaring per-role di backend, jadi hasilnya beda antara teknisi &
  /// admin — layar nggak perlu nyaring apa-apa lagi.
  ///
  /// [profil] = kode jenis alat (`ph_meter` / `turbidimeter` /
  /// `chlorine_meter`). Backend milih bentuk lembar kerjanya dari sini;
  /// default pH kalau kosong. Lihat `docs/kontrak-api.md` §4.
  ///
  /// [pengulangan] = berapa KOTAK pengulangan yang digambar (2–10). `null` =
  /// pakai bawaan profilnya (5, ngikut form kertas). Ini murni soal tampilan:
  /// rumusnya selalu ngikut berapa kotak yang beneran diisi, jadi ngecilin
  /// kolom nggak ngubah hasil hitungannya.
  /// [equipmentId] bikin backend nyusutin bentuknya ke ALAT ITU: titik yang
  /// punya varian satuan dikirim SATU baris, ngikut satuan di resolusi alat.
  /// Tanpa ini yang kekirim bentuk generik — Conductivity keluar 4 baris dengan
  /// dua varian titik tengah yang saling ngunci, dan satuannya nggak ngikut
  /// alat pelanggan.
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  });

  /// `POST /api/calibrations` — balikin id sesi yang kebentuk.
  Future<int> kirim(String token, LembarKerjaSubmission isian);

  /// `PUT /api/calibrations/{id}` — lanjut draft atau perbaiki sesi yang
  /// dikembalikan admin.
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian);
}

class ApiLembarKerjaService implements LembarKerjaService {
  ApiLembarKerjaService(this._api);

  final ApiClient _api;

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async {
    final q = <String>[
      if (profil != null && profil.isNotEmpty) 'profil=$profil',
      if (pengulangan != null) 'pengulangan=$pengulangan',
      if (equipmentId != null) 'equipment_id=$equipmentId',
    ];
    final path = '/calibrations/lembar-kerja${q.isEmpty ? '' : '?${q.join('&')}'}';
    final json = await _api.get(path, token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return LembarKerja.fromJson(data);
  }

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    final json = await _api.post(
      '/calibrations',
      token: token,
      body: isian.toJson(),
    );
    return _idDari(json);
  }

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) async {
    final json = await _api.put(
      '/calibrations/$id',
      token: token,
      body: isian.toJson(),
    );
    return _idDari(json);
  }

  int _idDari(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}

/// Tiruan buat test. [payloadTerakhir] nyimpen body yang bakal dikirim ke
/// server — itu yang diperiksa test, bukan tampilannya, karena aturan yang
/// paling gampang rusak diam-diam ada di bentuk payload-nya (sel kosong wajib
/// jadi `null`, bukan dibuang).
class MockLembarKerjaService implements LembarKerjaService {
  MockLembarKerjaService({
    this.gagal = false,
    this.untukAdmin = false,
    this.gagalKirimSampaiPercobaanKe = 0,
    this.tanpaPasanganStandar = false,
  });

  final bool gagal;
  final bool untukAdmin;

  /// Buang `standard_id` dari baris tabel hasil — niru standar yang belum
  /// didaftarin di master lab, atau backend versi lama yang belum ngirim
  /// pasangan titik↔larutan. Layar mesti jatuh ke pilihan manual, bukan
  /// ninggalin titiknya tanpa standar diam-diam.
  final bool tanpaPasanganStandar;

  /// Bikin `kirim`/`perbarui` gagal sampai percobaan ke-n — buat niru sinyal
  /// putus di lapangan, dan mastiin retry-nya bawa `client_request_id` yang
  /// SAMA (kalau berubah, backend bikin sesi dobel).
  final int gagalKirimSampaiPercobaanKe;

  /// Semua payload yang pernah dicoba dikirim, termasuk yang gagal.
  final List<Map<String, dynamic>> payload = [];

  Map<String, dynamic>? get payloadTerakhir =>
      payload.isEmpty ? null : payload.last;

  int get jumlahKirim => payload.length;

  /// Alat yang diminta tiap kali bentuk diambil (`null` = bentuk generik).
  /// Dicatat karena inilah yang nentuin Conductivity keluar 3 baris atau 4:
  /// tanpa ini, dua varian titik tengah muncul bareng dan saling ngunci.
  final List<int?> equipmentIdDiminta = [];

  /// Jumlah kotak pengulangan yang diminta tiap kali bentuk diambil (`null` =
  /// nggak minta apa-apa, pakai bawaan). Dicatat biar test bisa mastiin
  /// pilihan teknisi beneran nyampe ke backend, bukan cuma keganti di layar.
  final List<int?> pengulanganDiminta = [];

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    pengulanganDiminta.add(pengulangan);
    equipmentIdDiminta.add(equipmentId);

    final bentuk = switch (profil) {
      'turbidimeter' => contohBentukLembarKerjaTurbidi(untukAdmin: untukAdmin),
      'chlorine_meter' => contohBentukLembarKerjaChlorine(untukAdmin: untukAdmin),
      'refractometer' => contohBentukLembarKerjaRefractometer(
        untukAdmin: untukAdmin,
      ),
      // Profil kosong / nggak dikenal SENGAJA jatuh ke pH, bukan lempar error —
      // sama kayak janji kontraknya (`docs/kontrak-api.md` §4).
      _ => contohBentukLembarKerja(untukAdmin: untukAdmin),
    };

    // Niru backend: yang ditulis ulang cuma jumlah KOTAKnya.
    final dipakai = pengulangan == null
        ? bentuk
        : setelKolomPengulanganMock(bentuk, pengulangan);

    return LembarKerja.fromJson(
      tanpaPasanganStandar ? _tanpaPasangan(dipakai) : dipakai,
    );
  }

  /// Salinan bentuk tanpa `standard_id`/`standard_nama` di baris tabel hasil.
  static Map<String, dynamic> _tanpaPasangan(Map<String, dynamic> bentuk) => {
    ...bentuk,
    'bagian': [
      for (final bagian in (bentuk['bagian'] as List).cast<Map<String, dynamic>>())
        {
          ...bagian,
          if (bagian['tabel'] != null)
            'tabel': [
              for (final tabel in (bagian['tabel'] as List).cast<Map<String, dynamic>>())
                {
                  ...tabel,
                  'baris': [
                    for (final baris
                        in (tabel['baris'] as List).cast<Map<String, dynamic>>())
                      {...baris}
                        ..remove('standard_id')
                        ..remove('standard_nama'),
                  ],
                },
            ],
        },
    ],
  };

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    // Dicatat ke ingatan bersama, bukan balikin id karangan: tanpa ini sesi
    // yang barusan dikirim teknisi nggak pernah nongol di antrean approval,
    // dan alur dari lembar kerja sampai sertifikat nggak bisa dicoba sama
    // sekali tanpa backend nyala. Lihat [MockStore].
    //
    // Namanya dibaca dari alat yang DIPILIH, bukan dipatok 'pH Meter': dulu
    // sesi turbidimeter nongol di antrean approval sebagai pH Meter, dan admin
    // yang lagi nyoba alurnya offline nggak punya cara buat sadar itu salah.
    final id = MockStore.instance.tambahSesi(
      namaAlat: '${namaAlatMock(isian.equipmentId) ?? 'Alat'} (sesi baru)',
      namaTeknisi: 'Teknisi',
      draft: isian.simpanSebagaiDraft,
    );

    final hasil = _catat(isian, id);

    // Baru bilang berhasil sesudah sesinya beneran mendarat di disk. Lihat
    // `MockStore.tungguTersimpan`.
    await MockStore.instance.tungguTersimpan();

    return hasil;
  }

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) async =>
      _catat(isian, id);

  int _catat(LembarKerjaSubmission isian, int id) {
    // Dicatat DULUAN, baru dilempar errornya — payload percobaan yang gagal
    // itu justru yang mau diperiksa test.
    payload.add(isian.toJson());

    if (gagal || payload.length <= gagalKirimSampaiPercobaanKe) {
      throw Exception('server nggak nyaut');
    }

    return id;
  }
}

/// Tiruan `CalibrationProfile::setelKolomPengulangan()` di backend, buat mode
/// mock & widget test.
///
/// Sengaja niru bentuk keluarannya, bukan aturannya: yang diuji di sisi mobile
/// itu "layarnya ngikut apa pun jumlah kotak yang dikirim backend", bukan
/// "mobile bisa ngitung sendiri berapa kotaknya". Batas 2–10 tetap urusan
/// backend — di sini nggak divalidasi lagi biar nggak ada dua sumber aturan.
Map<String, dynamic> setelKolomPengulanganMock(
  Map<String, dynamic> bentuk,
  int jumlah,
) {
  Object? tulisUlang(Object? simpul) {
    if (simpul is Map<String, dynamic>) {
      return {
        for (final e in simpul.entries)
          e.key: switch (e.key) {
            'jumlah_pengulangan' when e.value is int => jumlah,
            'pengulangan' when e.value is List => List<int>.generate(jumlah, (i) => i + 1),
            _ => tulisUlang(e.value),
          },
      };
    }
    if (simpul is List) return simpul.map(tulisUlang).toList();
    return simpul;
  }

  return tulisUlang(bentuk)! as Map<String, dynamic>;
}

/// Salinan bentuk yang dibalikin `GET /api/calibrations/lembar-kerja`
/// (`LembarKerjaTemplate` di backend). Ditaruh di lib, bukan di test, biar
/// dipakai bareng sama mock — dan biar kalau bentuk backend berubah,
/// ketahuannya dari satu tempat.
Map<String, dynamic> contohBentukLembarKerja({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    // `standard_id` per baris = pasangan tercetak titik↔buffer, dan id-nya
    // sengaja sama persis kayak baris usage check di bawah: itu larutan yang
    // SAMA, cuma dilihat dari dua bagian formulir. Mock yang ngirim id beda
    // bakal bikin layar kelihatan bener padahal ketertelusurannya pecah.
    'baris': [
      {
        'titik_ukur': 4.00,
        'label': '4,00',
        'standard_id': 2,
        'standard_nama': 'pH Buffer Solution 4',
      },
      {
        'titik_ukur': 7.00,
        'label': '7,00',
        'standard_id': 3,
        'standard_nama': 'pH Buffer Solution 7',
      },
      {
        'titik_ukur': 10.01,
        'label': '10,01',
        'standard_id': 4,
        'standard_nama': 'pH Buffer Solution 10',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'pH', 'tipe': 'angka', 'satuan': 'pH'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field(
          'equipment.range_resolusi',
          '2. Range/Resolution',
          'teks',
          sumber: 'otomatis',
          satuan: 'pH',
        ),
        // Tiga kolom ini DIKETIK TEKNISI dari badan alat, bukan disalin
        // master — lihat LembarKerjaTemplate di backend.
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field(
          'thermohygro_standard_id',
          '6. Thermohygro used',
          'pilihan',
          sumber: 'master_thermohygro',
          // Id-nya nunjuk ke `MockStandardService` beneran (40/42/43/41).
          // Dulu 7/11/12/9 — id yang nggak ada isinya di mock, jadi pilihan
          // teknisi nyampe ke payload sebagai standar yang nggak eksis.
          pilihan: [
            {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
            {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
            {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
            {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
          ],
        ),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Lima baris TERCETAK di formulir, bukan katalog standar lab. Baris
      // terakhir sengaja `standard_id: null` — di lab beneran pun standar itu
      // belum kedaftar di master, dan barisnya tetap harus kelihatan.
      'baris': [
        {'label': 'pH Buffer Solutions 4', 'standard_id': 2, 'terdaftar': true},
        {'label': 'pH Buffer Solutions 7', 'standard_id': 3, 'terdaftar': true},
        {'label': 'pH Buffer Solutions 10', 'standard_id': 4, 'terdaftar': true},
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 6, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field(
          'lokasi',
          '1. Location',
          'pilihan',
          pilihan: [
            {'nilai': 'lab', 'label': 'In lab'},
            {'nilai': 'onsite', 'label': 'Insitu'},
          ],
        ),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field(
            'calibration_method_id',
            '2. Calibration Methode',
            'pilihan',
            sumber: 'master_metode',
            hanyaAdmin: true,
          ),
      ],
    },
    {
      'kode': 'hasil',
      // SATU halaman, sama kayak Turbidimeter & Chlorine. Backend udah nggak
      // mecah dua sejak `3ab1d09` ("satu gulungan"), mobile-nya ketinggalan —
      // jadi build mock nampilin tombol "LANJUT KE HALAMAN BERIKUTNYA" yang di
      // build asli nggak ada sama sekali.
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0509_Rev.4',
    'judul': 'Calibration Worksheet - pH Meter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [4.00, 7.00, 10.01],
    'satuan': 'pH',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Turbidimeter (`?profil=turbidimeter`, `TurbidimeterProfile`
/// di backend). Titik 1/100/1000 NTU dengan resolusi per-titik (0,01/0,1/1),
/// dipakai mock biar alur turbidimeter bisa dicoba tanpa backend.
Map<String, dynamic> contohBentukLembarKerjaTurbidi({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {
        'titik_ukur': 1.0,
        'label': '1',
        'resolusi': 0.01,
        'desimal': 2,
        'standard_id': 20,
        'standard_nama': 'Turbidity Standard 1 NTU',
      },
      {
        'titik_ukur': 100.0,
        'label': '100',
        'resolusi': 0.1,
        'desimal': 1,
        'standard_id': 21,
        'standard_nama': 'Turbidity Standard 100 NTU',
      },
      {
        'titik_ukur': 1000.0,
        'label': '1000',
        'resolusi': 1.0,
        'desimal': 0,
        'standard_id': 22,
        'standard_nama': 'Turbidity Standard 1000 NTU',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'NTU', 'tipe': 'angka', 'satuan': 'NTU'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'NTU'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
              {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
            ]),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      'baris': [
        {'label': 'Turbidity Standard 1 NTU', 'standard_id': 20, 'terdaftar': true},
        {'label': 'Turbidity Standard 100 NTU', 'standard_id': 21, 'terdaftar': true},
        {'label': 'Turbidity Standard 1000 NTU', 'standard_id': 22, 'terdaftar': true},
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 6, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'In lab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0530_Rev.2',
    'judul': 'Calibration Worksheet - Turbidimeter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [1.0, 100.0, 1000.0],
    'satuan': 'NTU',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Chlorin Meter (`?profil=chlorine_meter`, `ChlorineProfile` di
/// backend). Disalin dari lembar kerja cetaknya, **SIDIK-FM-CAL-0531_Rev.2** —
/// satu halaman (`Page 1 of 1`), metode `SIDIK-IK-CAL-0524`.
///
/// ## Kenapa titiknya 1,74 & 1,83 dan BUKAN 0,40 & 4,00
///
/// Lembar cetak Rev.2 nulis `Solution Standard 0.40` & `4.00`, dan baris
/// STANDARD-nya "Chlorine Std. Solutions 0.4 / 4 mg/l". Tiga sumber lain
/// bilang beda, dan ketiganya lebih baru:
///
/// - **Lampiran akreditasi LK-285-IDN no. 42** (`docs/Rekap-Data-Kemampuan-
///   Kalibrasi.md`, berlaku 28 Okt 2024–27 Okt 2029): titik **1,74** mg/L
///   (CMC 0,091) & **1,83** mg/L (CMC 0,08).
/// - **`Project-PT-Sidik/Chlorine_Meter_CSV/DATABASE.csv`** (snapshot 19 Des
///   2025): Jenis Rentang 1,74 & 1,83 dengan CMC yang sama persis, dan standar
///   fisiknya "Chlorine Standard Solution 1.74 mg/L" (U95 0,09) & "Chlorine
///   Standar Cuvettes 1.83 mg/L" (U95 0,06), dua-duanya Supelco/Merck.
/// - **Sesi asli 0189-CAL-624** (Hanna HI97711, Juni 2024): standarnya 1,74 &
///   1,83, pembacaannya 1,76 & 1,86.
///
/// `FORM_VALIDASI.csv` revisi #6 (3 Apr 2024) nyatet "Update std Chlorine 4
/// mgl (MRA/ISO 17034)" — set standarnya emang sempat gonta-ganti, dan lembar
/// cetak Rev.2 ketinggalan. Yang dipakai di sini yang **ada di lingkup
/// akreditasi**: kalibrasi di titik luar lampiran nggak bisa jadi sertifikat.
/// Diputusin bareng Raihan 5 Agt 2026.
///
/// Beda dari Turbidimeter: resolusinya **seragam** 0,01 mg/L di dua titik, jadi
/// `resolusi`/`desimal` per baris sengaja NGGAK dikirim (null = seragam). Cuma
/// alat yang resolusinya beda per titik yang butuh itu.
Map<String, dynamic> contohBentukLembarKerjaChlorine({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {
        'titik_ukur': 1.74,
        'label': '1,74',
        'standard_id': 30,
        'standard_nama': 'Chlorine Standard Solution 1.74 mg/L',
      },
      {
        'titik_ukur': 1.83,
        'label': '1,83',
        'standard_id': 31,
        'standard_nama': 'Chlorine Standar Cuvettes 1.83 mg/L',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'mg/L', 'tipe': 'angka', 'satuan': 'mg/L'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'mg/L'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro Used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
              {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
            ]),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Dua baris pertama namanya diambil apa adanya dari DATABASE.csv —
      // itu nama standar fisik yang beneran ada di lab, lengkap sama nilai
      // sertifikatnya. Dua baris terakhir sama kayak lembar pH & Turbidimeter.
      'baris': [
        {
          'label': 'Chlorine Standard Solution 1.74 mg/L',
          'standard_id': 30,
          'terdaftar': true,
        },
        {
          'label': 'Chlorine Standar Cuvettes 1.83 mg/L',
          'standard_id': 31,
          'terdaftar': true,
        },
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 6, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0531_Rev.2',
    'judul': 'Calibration Worksheet - Chlorine Meter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [1.74, 1.83],
    'satuan': 'mg/L',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Refractometer (`?profil=refractometer`, `RefractometerProfile`
/// di backend). Lembar cetaknya **SIDIK-FM-CAL-0523_Rev.2**, satu halaman.
/// Alat KEEMPAT yang punya lembar sendiri, dan yang paling beda dari tiga
/// sebelumnya.
///
/// ## Kolom °C di sini BUKAN pelengkap
///
/// Di lembar Chlorine, suhu cuma dicatat buat jejak. Di sini dia yang dipakai
/// NGITUNG: indeks bias berubah ikut suhu, jadi pembacaan dinormalisasi dulu ke
/// **20 °C** (huruf "20" di `n20D` itu ini) sebelum diadu ke larutan standar.
///
/// ```
/// Corrected = Observed + 0,00045 × (T − 20)     // n20D
/// Corrected = Observed + 0,07    × (T − 20)     // °Brix
/// ```
///
/// Sesi master `2211.11.R`: titik 1,33659 dibaca `1,3362` pada rata-rata suhu
/// **27 °C** → `1,3362 + 0,00045 × 7` = **1,33935**. Yang kecetak di sertifikat
/// sebagai Unit Under Test itu 1,33935, BUKAN 1,3362. Teknisi yang ngosongin
/// kolom suhu tetap boleh ngirim — backend pakai pembacaan apa adanya, nggak
/// nebak — tapi hasilnya jadi kurang teliti.
///
/// ## Kenapa `desimal`/`resolusi` per baris NGGAK dikirim
///
/// Sama alasannya kayak Chlorine: resolusinya **seragam** 0,0001 n20D di dua
/// titik. Bedanya, di sini itu penting banget — nilai terkoreksinya bisa **5
/// desimal** (`1,33935`) padahal resolusi alatnya 4. Mad ke 4 desimal bikin
/// `1,33935` kecetak `1,3394`, beda dari sertifikat.
///
/// ## Satuan ditanya di depan
///
/// Satu refractometer bisa nampilin n20D atau °Brix, dan pilihannya ngubah
/// SEMUA angka hilirnya (koefisien suhu 0,00045 vs 0,07, titik standar, CMC).
/// Makanya `equipment.satuan` ada di `identitas_alat` — ditanya sebelum teknisi
/// mulai ngisi tabel, bukan ditebak.
Map<String, dynamic> contohBentukLembarKerjaRefractometer({
  bool untukAdmin = false,
}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  // Larutan fisiknya SAMA, cuma dibaca di skala yang beda: `BSAG2.5-0034`
  // dibaca 2,5 °Brix atau 1,33659 n20D, `BSAG40-0071` dibaca 40 °Brix atau
  // 1,39986 n20D. Angkanya cocok sama CMC yang diseed backend, jadi titiknya
  // tetap dapat budget ketidakpastian.
  const barisN20D = [
    {'titik_ukur': 1.33659, 'label': '1,33659'},
    {'titik_ukur': 1.39986, 'label': '1,39986'},
  ];
  const barisBrix = [
    {'titik_ukur': 2.5, 'label': '2,5'},
    {'titik_ukur': 40.0, 'label': '40'},
  ];

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    // Sengaja tanpa `resolusi`/`desimal` — lihat docblock.
    'baris': barisN20D,
    'baris_per_satuan': {'n20D': barisN20D, '°Brix': barisBrix},
    'kolom': [
      {'kode': 'pembacaan', 'label': 'n20D', 'tipe': 'angka', 'satuan': 'n20D'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        // Tanpa `satuan` — nilainya udah bawa satuannya sendiri ("0–53 °Brix /
        // 0,1 °Brix"), dan alat ini bisa kecatat di skala mana pun. Lihat
        // `RefractometerProfile` di backend.
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro Used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '36', 'label': 'TH-1', 'grup': 'Inlab'},
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '44', 'label': 'TH-5', 'grup': 'Inlab'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
            ]),
        // Pilihannya ikut di field-nya sendiri, jadi layar nggak perlu baca
        // `pilihan_satuan` di akar respons — dua-duanya isinya sama.
        field('equipment.satuan', '7. Satuan Refracto', 'pilihan',
            pilihan: const [
              {'nilai': 'n20D', 'label': 'n20D'},
              {'nilai': '°Brix', 'label': '°Brix'},
            ]),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Satu botol fisik dipakai buat dua satuan sekaligus (BSAG2.5-0034 =
      // 2,5 °Brix DAN 1,33659 n20D), makanya empat baris larutan walau yang
      // dikalibrasi cuma dua titik n20D.
      'baris': [
        {
          'label': 'Refractometer Std Solution 1.33659 n20D',
          'standard_id': 50,
          'terdaftar': true,
        },
        {
          'label': 'Refractometer Std Solution 1.39986 n20D',
          'standard_id': 51,
          'terdaftar': true,
        },
        {
          'label': 'Refractometer Std Solution 2.5 oBrix',
          'standard_id': 52,
          'terdaftar': true,
        },
        {
          'label': 'Refractometer Std Solution 40 oBrix',
          'standard_id': 53,
          'terdaftar': true,
        },
        {
          'label': 'Termometer & Sensor Std.',
          'standard_id': 6,
          'terdaftar': true,
        },
        {'label': 'PT100/SH1', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0523_Rev.2',
    'judul': 'Calibration Worksheet - Refractometer',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [1.33659, 1.39986],
    'satuan': 'n20D',
    'satuan_suhu': '°C',
    'pilihan_satuan': [
      {'nilai': 'n20D', 'label': 'n20D (indeks bias)'},
      {'nilai': '°Brix', 'label': '°Brix (kadar sukrosa)'},
    ],
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim. Suhu tiap pembacaan WAJIB diisi kalau '
        'bisa: tanpa itu pembacaan nggak bisa dinormalisasi ke 20 °C.',
    'bagian': bagian,
  };
}
