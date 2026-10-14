import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Keadaan satu salinan lembar kerja yang tersimpan DI HP.
enum StatusDrafLokal {
  /// Simpanan otomatis — teknisi belum menekan Simpan Draf, jadi nggak
  /// pernah dikirim otomatis. Gunanya cuma satu: isian nggak hilang kalau
  /// aplikasinya dimatikan paksa.
  lokal('lokal'),

  /// Teknisi sudah menekan Simpan Draf tapi servernya nggak terjangkau.
  /// Dikirim otomatis sebagai `status: draft` begitu ada permintaan yang
  /// berhasil.
  belumTersinkron('belum_tersinkron'),

  /// Server MENOLAK isinya (422 / 4xx lain). Nggak dicoba ulang otomatis —
  /// mengirim isi yang sama cuma dapat penolakan yang sama. Teknisi yang
  /// membuka & membetulkannya.
  perluDiperbaiki('perlu_diperbaiki');

  const StatusDrafLokal(this.api);

  final String api;

  static StatusDrafLokal dari(Object? nilai) => StatusDrafLokal.values
      .firstWhere((s) => s.api == nilai, orElse: () => StatusDrafLokal.lokal);
}

/// Satu lembar kerja yang tersimpan di HP (spesifikasi F3, paket 30 Sep).
///
/// Isinya dua hal yang beda fungsi:
///
///  - [isian]: keadaan MENTAH formulir (apa yang diketik teknisi, per kotak),
///    dibuat & dipulihkan `LembarKerjaState`. Ini yang dipakai membuka ulang
///    lembarnya — bukan payload server, karena payload server membuang hal yang
///    tetap harus kembali di layar (centang standar yang dilepas, sel yang
///    ditandai kamera, pilihan slot satuan, baris tambahan).
///  - [kiriman]: body PERSIS yang dikirim waktu Simpan Draf gagal karena
///    jaringan. Cuma ada di yang [StatusDrafLokal.belumTersinkron] /
///    [StatusDrafLokal.perluDiperbaiki]; itu yang diulang pengirim antrean,
///    tanpa perlu membangun ulang formulirnya.
class DrafLokal {
  const DrafLokal({
    required this.userId,
    required this.clientRequestId,
    required this.profil,
    required this.disimpanPada,
    required this.isian,
    this.sesiId,
    this.judul,
    this.judulTambahan,
    this.equipmentId,
    this.pengulangan,
    this.basisServer,
    this.status = StatusDrafLokal.lokal,
    this.pesan,
    this.dicobaKirim = false,
    this.matriks = false,
    this.kiriman,
    this.versiAplikasi,
    this.versiFormat = versiFormatSekarang,
  });

  /// Naik kalau bentuk [isian] berubah tak kompatibel. Salinan dengan versi
  /// yang nggak dikenal DILEWAT waktu dibaca, bukan dipaksa dipulihkan
  /// setengah-setengah.
  static const versiFormatSekarang = 1;

  final int versiFormat;
  final String? versiAplikasi;
  final int userId;

  /// Id sesi di server. Null = lembar baru yang belum pernah tersimpan.
  final int? sesiId;
  final String clientRequestId;

  /// Kode lembar kerja (`ph_meter`, `autoclave`, …) — bentuk formulirnya.
  final String profil;

  /// Nama yang ditampilkan di daftar (nama alat · nomor seri).
  final String? judul;
  final String? judulTambahan;

  /// Kunci bentuk lembar waktu disimpan — dipakai supaya lembar yang dibuka
  /// ulang langsung menarik bentuk yang sudah disusutkan ke alatnya.
  final int? equipmentId;
  final int? pengulangan;

  /// Jam HP waktu salinan ini ditulis.
  final DateTime disimpanPada;

  /// `updated_at` server yang jadi DASAR isian ini (waktu sesinya dimuat).
  /// Lihat `lebihBaruDari` — ini yang bikin jam HP yang meleset nggak
  /// membuang isian teknisi.
  final DateTime? basisServer;

  final StatusDrafLokal status;

  /// Pesan penolakan server buat [StatusDrafLokal.perluDiperbaiki].
  final String? pesan;

  /// Pernah ada POST yang GAGAL KARENA JARINGAN untuk `client_request_id`
  /// ini — jadi servernya mungkin sudah menyimpannya. Lihat pengirim antrean
  /// soal kenapa itu mengubah cara kirim berikutnya.
  final bool dicobaKirim;

  /// Lembar bermatriks (Autoklaf) — endpoint simpannya sendiri.
  final bool matriks;

  final Map<String, dynamic>? kiriman;
  final Map<String, dynamic> isian;

  String get kunci =>
      kunciUntuk(sesiId: sesiId, clientRequestId: clientRequestId);

  static String kunciUntuk({int? sesiId, required String clientRequestId}) =>
      sesiId != null ? 'sesi-$sesiId' : 'baru-$clientRequestId';

  /// Isian di HP ini lebih baru dari yang tersimpan di server?
  ///
  /// Dua lapis, dan urutannya disengaja:
  ///
  ///  1. Server BELUM berubah sejak isian ini dimuat ([basisServer] sama atau
  ///     lebih baru dari [server]) → yang di HP pasti lebih baru, apa pun kata
  ///     jamnya. Tanpa lapis ini, HP yang jamnya telat lima menit membuang
  ///     isian teknisi karena "kelihatan lebih lama".
  ///  2. Server SUDAH berubah sesudahnya (disimpan dari perangkat lain) →
  ///     baru jam dibandingkan, dan yang lebih baru menang.
  bool lebihBaruDari(DateTime? server) {
    if (server == null) return true;

    final basis = basisServer;
    if (basis != null && !server.isAfter(basis)) return true;

    return disimpanPada.isAfter(server);
  }

  DrafLokal copyWith({
    int? sesiId,
    bool hapusSesiId = false,
    DateTime? disimpanPada,
    DateTime? basisServer,
    StatusDrafLokal? status,
    String? pesan,
    bool hapusPesan = false,
    bool? dicobaKirim,
    Map<String, dynamic>? kiriman,
    Map<String, dynamic>? isian,
    String? judul,
    int? equipmentId,
    int? pengulangan,
  }) => DrafLokal(
    versiFormat: versiFormat,
    versiAplikasi: versiAplikasi,
    userId: userId,
    sesiId: hapusSesiId ? null : (sesiId ?? this.sesiId),
    clientRequestId: clientRequestId,
    profil: profil,
    judul: judul ?? this.judul,
    judulTambahan: judulTambahan,
    equipmentId: equipmentId ?? this.equipmentId,
    pengulangan: pengulangan ?? this.pengulangan,
    disimpanPada: disimpanPada ?? this.disimpanPada,
    basisServer: basisServer ?? this.basisServer,
    status: status ?? this.status,
    pesan: hapusPesan ? null : (pesan ?? this.pesan),
    dicobaKirim: dicobaKirim ?? this.dicobaKirim,
    matriks: matriks,
    kiriman: kiriman ?? this.kiriman,
    isian: isian ?? this.isian,
  );

  Map<String, dynamic> toJson() => {
    'versi_format': versiFormat,
    'versi_aplikasi': versiAplikasi,
    'user_id': userId,
    'sesi_id': sesiId,
    'client_request_id': clientRequestId,
    'profil': profil,
    'judul': judul,
    'judul_tambahan': judulTambahan,
    'equipment_id': equipmentId,
    'pengulangan': pengulangan,
    'disimpan_pada': disimpanPada.toUtc().toIso8601String(),
    'basis_server': basisServer?.toUtc().toIso8601String(),
    'status': status.api,
    'pesan': pesan,
    'dicoba_kirim': dicobaKirim,
    'matriks': matriks,
    'kiriman': kiriman,
    'isian': isian,
  };

  /// `null` kalau isinya rusak atau versinya nggak dikenal.
  static DrafLokal? fromJson(Map<String, dynamic> json) {
    try {
      final versi = (json['versi_format'] as num?)?.toInt();
      if (versi != versiFormatSekarang) return null;

      final disimpan = DateTime.tryParse(
        json['disimpan_pada'] as String? ?? '',
      );
      if (disimpan == null) return null;

      return DrafLokal(
        versiFormat: versi!,
        versiAplikasi: json['versi_aplikasi'] as String?,
        userId: (json['user_id'] as num).toInt(),
        sesiId: (json['sesi_id'] as num?)?.toInt(),
        clientRequestId: json['client_request_id'] as String,
        profil: json['profil'] as String,
        judul: json['judul'] as String?,
        judulTambahan: json['judul_tambahan'] as String?,
        equipmentId: (json['equipment_id'] as num?)?.toInt(),
        pengulangan: (json['pengulangan'] as num?)?.toInt(),
        disimpanPada: disimpan,
        basisServer: switch (json['basis_server']) {
          final String t => DateTime.tryParse(t),
          _ => null,
        },
        status: StatusDrafLokal.dari(json['status']),
        pesan: json['pesan'] as String?,
        dicobaKirim: json['dicoba_kirim'] == true,
        matriks: json['matriks'] == true,
        kiriman: switch (json['kiriman']) {
          final Map<String, dynamic> k => k,
          _ => null,
        },
        isian: json['isian'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Simpanan lembar kerja di HP, **per akun**.
///
/// Aturan pemilik proyek (K-30-09): salinan disimpan 14 hari untuk akun yang
/// sama, dan DIBUANG begitu akun lain masuk di HP ini. HP lab dipakai
/// gantian; isian lembar kerja berisi nama pelanggan dan angka kalibrasinya.
///
/// Semua method **nggak pernah melempar**. Simpanan lokal itu jaring
/// pengaman: kalau dia rusak, lembar kerjanya tetap harus bisa diisi dan
/// dikirim ke server seperti biasa.
abstract class SimpananDrafLokal {
  static const umurMaksimal = Duration(days: 14);

  Future<DrafLokal?> baca(int userId, String kunci);

  /// Semua salinan milik [userId], terbaru di atas.
  Future<List<DrafLokal>> daftar(int userId);

  Future<void> simpan(DrafLokal draf);

  Future<void> hapus(int userId, String kunci);

  /// Buang salinan [userId] yang lebih tua dari [umurMaksimal].
  Future<void> buangKedaluwarsa(int userId, {DateTime? sekarang});

  /// Akun lain masuk di HP ini (K-30-09): buang SIMPANAN OTOMATIS milik akun
  /// selain [userId], plus apa pun yang lebih tua dari [umurMaksimal].
  ///
  /// Draf akun lain yang sudah ANTRE (`belum_tersinkron`) atau DITOLAK server
  /// (`perlu_diperbaiki`) TIDAK dibuang — itu draf yang teknisinya sengaja
  /// simpan dan belum sampai server; membuangnya berarti kehilangan data
  /// lapangan. Yang menjaga privasinya: [daftar] & [baca] cuma membuka folder
  /// akun yang diminta, dan pengirim antrean cuma mengirim milik akun yang
  /// login, pakai tokennya sendiri. Draf itu dikirim waktu pemiliknya login
  /// lagi, atau kedaluwarsa sesudah 14 hari.
  Future<void> buangAkunLain(int userId, {DateTime? sekarang});
}

/// Berkas JSON di `<dasar>/<userId>/<kunci>.json`. Bukan SQLite — keputusan
/// desain paket 30 Sep: nol dependensi baru, draf per formulir kecil.
///
/// Ditulis ATOMIK: isi ditulis ke berkas sementara dulu lalu di-`rename`.
/// HP yang mati persis waktu menulis meninggalkan salinan LAMA yang utuh,
/// bukan salinan baru yang terpotong separuh.
class SimpananDrafLokalBerkas implements SimpananDrafLokal {
  SimpananDrafLokalBerkas(this._dasar);

  /// Folder `draf_lokal`. Fungsi, bukan nilai: `getApplicationSupportDirectory`
  /// itu async, dan kegagalannya (mis. di bawah `flutter test`) harus bikin
  /// simpanan ini diam, bukan bikin layar gagal dibuka.
  final Future<Directory> Function() _dasar;

  Directory? _folder;
  bool _mati = false;
  int _nomorSementara = 0;

  /// Tulisan diantrekan per instance supaya dua tulisan ke kunci yang sama
  /// nggak saling salip.
  Future<void> _antrean = Future.value();

  /// Cuma `sesi-<angka>` atau `baru-<uuid>` — kunci jadi nama berkas, jadi
  /// apa pun yang lain (`..`, garis miring) ditolak di pintu.
  static final _polaKunci = RegExp(r'^(sesi-\d+|baru-[0-9A-Za-z-]{8,64})$');

  Future<Directory?> _akar() async {
    if (_mati) return null;
    try {
      return _folder ??= await _dasar();
    } catch (_) {
      _mati = true;
      return null;
    }
  }

  Future<File?> _berkas(int userId, String kunci) async {
    if (!_polaKunci.hasMatch(kunci)) return null;
    final akar = await _akar();
    if (akar == null) return null;
    return File(
      '${akar.path}${Platform.pathSeparator}$userId'
      '${Platform.pathSeparator}$kunci.json',
    );
  }

  Future<T> _berurutan<T>(Future<T> Function() kerja) {
    final hasil = _antrean.then((_) => kerja());
    _antrean = hasil.then((_) {}, onError: (_) {});
    return hasil;
  }

  @override
  Future<DrafLokal?> baca(int userId, String kunci) async {
    try {
      final berkas = await _berkas(userId, kunci);
      if (berkas == null || !await berkas.exists()) return null;
      final isi = jsonDecode(await berkas.readAsString());
      if (isi is! Map<String, dynamic>) return null;
      final draf = DrafLokal.fromJson(isi);
      return draf?.userId == userId ? draf : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DrafLokal>> daftar(int userId) async {
    try {
      final akar = await _akar();
      if (akar == null) return const [];
      final folder = Directory('${akar.path}${Platform.pathSeparator}$userId');
      if (!await folder.exists()) return const [];

      final hasil = <DrafLokal>[];
      await for (final e in folder.list()) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        try {
          final isi = jsonDecode(await e.readAsString());
          if (isi is! Map<String, dynamic>) continue;
          final draf = DrafLokal.fromJson(isi);
          if (draf != null && draf.userId == userId) hasil.add(draf);
        } catch (_) {
          // Satu berkas rusak nggak boleh menyembunyikan yang lain.
        }
      }

      hasil.sort((a, b) => b.disimpanPada.compareTo(a.disimpanPada));
      return hasil;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> simpan(DrafLokal draf) => _berurutan(() async {
    try {
      final berkas = await _berkas(draf.userId, draf.kunci);
      if (berkas == null) return;
      await berkas.parent.create(recursive: true);

      final sementara = File('${berkas.path}.${_nomorSementara++}.tmp');
      await sementara.writeAsString(jsonEncode(draf.toJson()), flush: true);
      await sementara.rename(berkas.path);
    } catch (_) {
      // Lihat docblock kelas.
    }
  });

  @override
  Future<void> hapus(int userId, String kunci) => _berurutan(() async {
    try {
      final berkas = await _berkas(userId, kunci);
      if (berkas != null && await berkas.exists()) await berkas.delete();
    } catch (_) {
      // Lihat docblock kelas.
    }
  });

  @override
  Future<void> buangKedaluwarsa(int userId, {DateTime? sekarang}) =>
      _berurutan(() async {
        try {
          final akar = await _akar();
          if (akar == null) return;
          await _sapu(
            Directory('${akar.path}${Platform.pathSeparator}$userId'),
            batas: (sekarang ?? DateTime.now()).subtract(
              SimpananDrafLokal.umurMaksimal,
            ),
            akunLain: false,
          );
        } catch (_) {
          // Lihat docblock kelas.
        }
      });

  @override
  Future<void> buangAkunLain(int userId, {DateTime? sekarang}) =>
      _berurutan(() async {
        try {
          final akar = await _akar();
          if (akar == null || !await akar.exists()) return;

          final batas = (sekarang ?? DateTime.now()).subtract(
            SimpananDrafLokal.umurMaksimal,
          );

          await for (final e in akar.list()) {
            if (e is! Directory) continue;
            final nama = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
            if (nama == '$userId') continue;

            await _sapu(e, batas: batas, akunLain: true);

            try {
              if (await e.list().isEmpty) await e.delete();
            } catch (_) {
              // Dicoba lagi waktu login berikutnya.
            }
          }
        } catch (_) {
          // Lihat docblock kelas.
        }
      });

  /// Sapu satu folder akun.
  ///
  /// Yang lebih tua dari [batas] selalu dibuang. Kalau [akunLain], simpanan
  /// otomatis (`lokal`) dan berkas yang nggak terbaca ikut dibuang — yang
  /// SUDAH antre / ditolak server tetap disimpan buat pemiliknya.
  Future<void> _sapu(
    Directory folder, {
    required DateTime batas,
    required bool akunLain,
  }) async {
    if (!await folder.exists()) return;

    await for (final e in folder.list()) {
      if (e is! File) continue;
      try {
        // Sisa tulisan yang terputus (HP mati di tengah menulis).
        if (e.path.endsWith('.tmp')) {
          if (akunLain || (await e.lastModified()).isBefore(batas)) {
            await e.delete();
          }
          continue;
        }

        DrafLokal? draf;
        try {
          final isi = jsonDecode(await e.readAsString());
          if (isi is Map<String, dynamic>) draf = DrafLokal.fromJson(isi);
        } catch (_) {
          draf = null;
        }

        final waktu = draf?.disimpanPada ?? await e.lastModified();
        final buang =
            waktu.isBefore(batas) ||
            (akunLain &&
                (draf == null || draf.status == StatusDrafLokal.lokal));

        if (buang) await e.delete();
      } catch (_) {
        // Berkas yang nggak bisa dibuang dicoba lagi lain kali.
      }
    }
  }
}

/// Simpanan di memori — buat test, dan sebagai pengganti kalau folder
/// aplikasi nggak tersedia.
class SimpananDrafLokalMemori implements SimpananDrafLokal {
  final Map<int, Map<String, DrafLokal>> _isi = {};

  /// Berapa kali [simpan] dipanggil — buat test debounce.
  int jumlahTulis = 0;

  @override
  Future<DrafLokal?> baca(int userId, String kunci) async =>
      _isi[userId]?[kunci];

  @override
  Future<List<DrafLokal>> daftar(int userId) async =>
      [...?_isi[userId]?.values]
        ..sort((a, b) => b.disimpanPada.compareTo(a.disimpanPada));

  @override
  Future<void> simpan(DrafLokal draf) async {
    jumlahTulis++;
    // Lewat JSON bolak-balik, sama seperti berkas: yang bisa dipulihkan cuma
    // yang selamat diserialisasi.
    final salinan = DrafLokal.fromJson(
      jsonDecode(jsonEncode(draf.toJson())) as Map<String, dynamic>,
    );
    if (salinan == null) return;
    (_isi[draf.userId] ??= {})[draf.kunci] = salinan;
  }

  @override
  Future<void> hapus(int userId, String kunci) async {
    _isi[userId]?.remove(kunci);
  }

  @override
  Future<void> buangKedaluwarsa(int userId, {DateTime? sekarang}) async {
    final batas = (sekarang ?? DateTime.now()).subtract(
      SimpananDrafLokal.umurMaksimal,
    );
    _isi[userId]?.removeWhere((_, d) => d.disimpanPada.isBefore(batas));
  }

  @override
  Future<void> buangAkunLain(int userId, {DateTime? sekarang}) async {
    final batas = (sekarang ?? DateTime.now()).subtract(
      SimpananDrafLokal.umurMaksimal,
    );
    for (final e in _isi.entries) {
      if (e.key == userId) continue;
      e.value.removeWhere(
        (_, d) =>
            d.disimpanPada.isBefore(batas) || d.status == StatusDrafLokal.lokal,
      );
    }
    _isi.removeWhere((id, isi) => id != userId && isi.isEmpty);
  }
}
