/// Kategori notifikasi yang dikirim backend (`NotificationResource.kategori`).
///
/// Kategori asing dianggap [umum] — netral, nggak ngarahin ke aksi yang salah,
/// dan tetap kelihatan di daftar. Kategori baru dari backend nggak boleh bikin
/// notifikasinya ilang diam-diam dari layar.
enum NotifKategori {
  jatuhTempo,
  sesiMenungguApproval,
  sesiDisetujui,
  sesiPerluRevisi,
  sertifikatTerbit,
  umum;

  static NotifKategori fromApi(String? value) => switch (value) {
    'jatuh_tempo' => NotifKategori.jatuhTempo,
    'sesi_menunggu_approval' => NotifKategori.sesiMenungguApproval,
    'sesi_disetujui' => NotifKategori.sesiDisetujui,
    'sesi_perlu_revisi' => NotifKategori.sesiPerluRevisi,
    'sertifikat_terbit' => NotifKategori.sertifikatTerbit,
    _ => NotifKategori.umum,
  };
}

/// Layar tujuan waktu notifikasinya diketuk — `{tipe, id}` dari backend,
/// mis. `{"tipe": "calibration", "id": 12}`.
///
/// Yang nentuin tujuan itu backend, bukan tebakan mobile dari kategori: satu
/// kategori bisa nunjuk ke layar beda tergantung datanya (sertifikat terbit
/// bisa buka sertifikatnya, atau sesinya kalau PDF-nya masih digenerate).
class NotifTautan {
  const NotifTautan({required this.tipe, required this.id});

  /// `calibration` / `certificate` / `equipment`.
  final String tipe;
  final int id;

  static NotifTautan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final tipe = raw['tipe'];
    final id = raw['id'];
    if (tipe is! String || id is! num) return null;
    return NotifTautan(tipe: tipe, id: id.toInt());
  }
}

/// Satu notifikasi — respons `GET /api/notifications`.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kategori,
    required this.judul,
    required this.isi,
    required this.dibaca,
    required this.dibuatPada,
    this.tautan,
  });

  /// UUID, bukan int — notifikasi Laravel pakai `DatabaseNotification` yang
  /// primary key-nya string.
  final String id;

  final NotifKategori kategori;
  final String judul;
  final String isi;
  final bool dibaca;
  final DateTime dibuatPada;
  final NotifTautan? tautan;

  NotificationItem copyWith({bool? dibaca}) => NotificationItem(
    id: id,
    kategori: kategori,
    judul: judul,
    isi: isi,
    dibaca: dibaca ?? this.dibaca,
    dibuatPada: dibuatPada,
    tautan: tautan,
  );

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: '${json['id']}',
      kategori: NotifKategori.fromApi(json['kategori'] as String?),
      judul: json['judul'] as String? ?? '',
      isi: json['isi'] as String? ?? '',
      dibaca: json['dibaca'] as bool? ?? false,
      dibuatPada:
          DateTime.tryParse(json['dibuat_pada'] as String? ?? '') ??
          DateTime.now(),
      tautan: NotifTautan.fromJson(json['tautan']),
    );
  }
}
