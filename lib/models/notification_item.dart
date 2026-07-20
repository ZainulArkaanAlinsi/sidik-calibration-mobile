/// Jenis notifikasi. Ngikutin `docs/kontrak-api.md` §6.
enum NotificationType { jatuhTempo, approval, revisi }

extension NotificationTypeJson on NotificationType {
  static NotificationType fromJson(String value) => switch (value) {
    'jatuh_tempo' => NotificationType.jatuhTempo,
    'approval' => NotificationType.approval,
    'revisi' => NotificationType.revisi,
    // Tipe yang belum dikenal dianggap `jatuhTempo` — paling netral, nggak
    // ngarahin ke aksi approval/revisi yang salah.
    _ => NotificationType.jatuhTempo,
  };
}

/// Satu notifikasi — respons `GET /api/notifications` (§6
/// `docs/kontrak-api.md`).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.tipe,
    required this.judul,
    required this.pesan,
    required this.dibaca,
    required this.createdAt,
  });

  final int id;
  final NotificationType tipe;
  final String judul;
  final String pesan;
  final bool dibaca;
  final DateTime createdAt;

  NotificationItem copyWith({bool? dibaca}) => NotificationItem(
    id: id,
    tipe: tipe,
    judul: judul,
    pesan: pesan,
    dibaca: dibaca ?? this.dibaca,
    createdAt: createdAt,
  );

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      tipe: NotificationTypeJson.fromJson(json['tipe'] as String),
      judul: json['judul'] as String,
      pesan: json['pesan'] as String,
      dibaca: json['dibaca'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
