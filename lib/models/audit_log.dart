import 'dart:convert';

import '../core/utils/parse_list.dart';
import '../core/utils/tanggal_api.dart';

/// Satu kolom yang berubah di sebuah baris riwayat (`perubahan.{kolom}.{lama,baru}`).
class PerubahanKolom {
  const PerubahanKolom({required this.kolom, this.lama, this.baru});

  final String kolom;
  final Object? lama;
  final Object? baru;

  /// Nama kolom yang nilainya tidak boleh tampil di layar.
  ///
  /// Server sudah tidak menyimpan nilai `password` dkk. di riwayat (hanya
  /// nama kolomnya — trait `Diaudit` di API), tapi layar tidak boleh
  /// bergantung pada itu: satu kolom rahasia baru yang lupa didaftarkan di
  /// server tidak boleh langsung muncul di HP admin.
  static final _rahasia = RegExp(
    r'password|sandi|secret|token|remember|otp|recovery|hash',
    caseSensitive: false,
  );

  bool get rahasia => _rahasia.hasMatch(kolom);

  /// Nilai sebagai teks. `null` → `null` (pemanggil yang memutuskan tampilannya).
  static String? teks(Object? nilai) {
    if (nilai == null) return null;
    if (nilai is String) return nilai;
    if (nilai is num || nilai is bool) return '$nilai';
    try {
      return jsonEncode(nilai);
    } catch (_) {
      return '$nilai';
    }
  }
}

/// Satu baris riwayat perubahan data (`GET /api/audit-logs`, `AuditLogResource`).
///
/// Baca-saja: baris riwayat tulis-sekali di server dan tidak punya rute ubah.
class AuditLogItem {
  const AuditLogItem({
    required this.id,
    required this.entitasTipe,
    required this.aksi,
    this.entitasId,
    this.perubahan = const [],
    this.pelakuId,
    this.pelakuNama,
    this.pelakuRole,
    this.olehSistem = false,
    this.catatan,
    this.dicatatPada,
  });

  final int id;

  /// Nama TABEL (mis. `standards`), bukan nama kelas — kontrak server.
  final String entitasTipe;
  final int? entitasId;

  /// `dibikin` / `diubah` / `dihapus` / `dipulihkan`; server juga mencatat
  /// aksi lain (`dibaca`, `akses_lintas_lab`, …), jadi nilainya tidak dibatasi.
  final String aksi;
  final List<PerubahanKolom> perubahan;
  final int? pelakuId;
  final String? pelakuNama;
  final String? pelakuRole;

  /// `true` = bukan dari orang yang login (job antrean, artisan, seeder).
  /// Bukan data yang hilang.
  final bool olehSistem;
  final String? catatan;
  final DateTime? dicatatPada;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    final entitas = json['entitas'];
    final pelaku = json['pelaku'];
    final perubahan = json['perubahan'];

    return AuditLogItem(
      id: (json['id'] as num).toInt(),
      entitasTipe: entitas is Map ? (entitas['tipe'] as String? ?? '') : '',
      entitasId: entitas is Map ? (entitas['id'] as num?)?.toInt() : null,
      aksi: json['aksi'] as String? ?? '',
      // `perubahan` itu OBJEK (`{}` waktu kosong, kontrak server); bentuk
      // lain diabaikan, bukan dijadikan crash.
      perubahan: perubahan is Map
          ? [
              for (final e in perubahan.entries)
                if (e.value is Map)
                  PerubahanKolom(
                    kolom: '${e.key}',
                    lama: (e.value as Map)['lama'],
                    baru: (e.value as Map)['baru'],
                  ),
            ]
          : const [],
      pelakuId: pelaku is Map ? (pelaku['id'] as num?)?.toInt() : null,
      pelakuNama: pelaku is Map ? pelaku['nama'] as String? : null,
      pelakuRole: pelaku is Map ? pelaku['role'] as String? : null,
      olehSistem: json['oleh_sistem'] == true,
      catatan: json['catatan'] as String?,
      dicatatPada: switch (json['dicatat_pada']) {
        final String s => DateTime.tryParse(s)?.toLocal(),
        _ => null,
      },
    );
  }
}

/// Satu halaman hasil `GET /api/audit-logs` — data + `meta` paginasi Laravel.
class HalamanAuditLog {
  const HalamanAuditLog({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
  });

  final List<AuditLogItem> items;
  final int currentPage;
  final int lastPage;

  factory HalamanAuditLog.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];

    return HalamanAuditLog(
      items: parseListAman(json['data'], AuditLogItem.fromJson),
      currentPage: meta is Map
          ? (meta['current_page'] as num?)?.toInt() ?? 1
          : 1,
      lastPage: meta is Map ? (meta['last_page'] as num?)?.toInt() ?? 1 : 1,
    );
  }
}

/// Penyaring daftar riwayat. Nama kuncinya mengikuti query server
/// (`entity_type`, `entity_id`, `action`, `dari`, `sampai`).
class FilterAuditLog {
  const FilterAuditLog({
    this.aksi,
    this.entityType,
    this.entityId,
    this.dari,
    this.sampai,
  });

  /// Aksi yang diterima server untuk penyaringan (`AuditLog::actions()`).
  static const aksiTersaring = ['dibikin', 'diubah', 'dihapus', 'dipulihkan'];

  final String? aksi;
  final String? entityType;
  final int? entityId;
  final DateTime? dari;
  final DateTime? sampai;

  /// Jumlah penyaring yang aktif — untuk lencana di tombol Filter.
  int get jumlahAktif =>
      [aksi, entityType, entityId, dari, sampai].where((e) => e != null).length;

  bool get kosong => jumlahAktif == 0;

  /// Parameter query. Yang kosong tidak dikirim sama sekali.
  Map<String, String> toQuery({int page = 1}) => {
    'action': ?aksi,
    'entity_type': ?entityType,
    if (entityId != null) 'entity_id': '$entityId',
    if (dari != null) 'dari': tanggalApi(dari!),
    if (sampai != null) 'sampai': tanggalApi(sampai!),
    if (page > 1) 'page': '$page',
  };

  FilterAuditLog salin({
    Object? aksi = _tetap,
    Object? entityType = _tetap,
    Object? entityId = _tetap,
    Object? dari = _tetap,
    Object? sampai = _tetap,
  }) => FilterAuditLog(
    aksi: identical(aksi, _tetap) ? this.aksi : aksi as String?,
    entityType: identical(entityType, _tetap)
        ? this.entityType
        : entityType as String?,
    entityId: identical(entityId, _tetap) ? this.entityId : entityId as int?,
    dari: identical(dari, _tetap) ? this.dari : dari as DateTime?,
    sampai: identical(sampai, _tetap) ? this.sampai : sampai as DateTime?,
  );

  static const _tetap = Object();
}
