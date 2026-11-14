import 'package:flutter/material.dart';

import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';

/// Nada stempel status. Lima saja; tiap nada punya ARTI tetap di seluruh app.
///
/// Warna TIDAK PERNAH sendirian: [StatusTampil] selalu membawa ikon dan kata,
/// dan [Stempel] menampilkan keduanya.
enum NadaStempel {
  /// Beres, lolos, berlaku, disetujui.
  lulus,

  /// Gagal, lewat jadwal, masa berlaku berakhir, dibatalkan.
  gagal,

  /// "Lihat dulu": perlu revisi, segera.
  awas,

  /// Di tangan orang lain atau sedang diproses: menunggu, sedang dibuat.
  tunggu,

  /// Belum jalan, tidak aktif, atau sudah tidak berlaku tanpa kegagalan: draf,
  /// nonaktif, digantikan revisi, belum terbit. Digambar bergaris tepi tanpa
  /// isi, supaya beda bentuknya dari "menunggu" (abu berisi).
  netral,
}

/// Kata status. Tiap nilai punya kunci ARB `stempel*` (id dan en) di
/// [StatusTampil.label]; layar tidak menulis kata status sendiri.
enum KataStatus {
  draf,
  menunggu,
  perluRevisi,
  disetujui,
  pass,
  fail,
  ditarik,
  aktif,
  nonaktif,
  lewatJadwal,
  berlaku,
  segera,
  masaBerlakuBerakhir,
  terbit,
  sedangDibuat,
  gagalDibuat,
  menungguPersetujuan,
  baru,
  diproses,
  selesai,
  dibatalkan,
  digantikanRevisi,
  belumTerbit,
}

/// Satu status yang siap ditampilkan: kata, nada, ikon.
///
/// Ini SATU-SATUNYA pemetaan status Lab yang baru. Ia menggantikan dua sistem
/// lama (`StatusBadge` dan `StatusSidik`) yang memberi warna dan kata berbeda
/// untuk status yang sama. Layar tidak menulis kata status sendiri: ia memanggil
/// [StatusTampil.dariKode] atau [StatusTampil.jadwal], dan kata diambil dari
/// ARB lewat [label] (Indonesia dan English, mengikuti pilihan bahasa di
/// Profil).
///
/// Istilah baku: "Lewat jadwal" dan "Masa berlaku berakhir" (tidak ada
/// "Kedaluwarsa"); "Jatuh tempo" hanya nama tanggal, bukan nama status.
///
/// Kode yang dipetakan: status sesi (`CalibrationStatus`), alat
/// (`EquipmentStatus`), akun (`UserStatus`), label dokumen sertifikat
/// (`StatusDokumen`), status teknis sertifikat, status standar acuan, status
/// order, dan vonis. `test/komponen_sidik/stempel_status_test.dart` menurunkan
/// daftar kode dari enum itu dan dari dua sistem lama, jadi kode baru yang tak
/// dipetakan membuat tes gagal.
@immutable
class StatusTampil {
  const StatusTampil(this.kata, this.nada, this.ikon, {this.mentah});

  /// Kata yang dipetakan; `null` untuk kode yang belum dikenal ([mentah]).
  final KataStatus? kata;
  final NadaStempel nada;
  final IconData ikon;

  /// Kode asing dari server, ditampilkan apa adanya (bukan disembunyikan).
  final String? mentah;

  /// Batas hari menuju jadwal yang disebut "Segera" (<= 30 hari).
  static const int batasSegeraHari = 30;

  /// Status jadwal kalibrasi ulang dari sisa [hari] menuju jadwal (negatif =
  /// lewat): "Lewat jadwal" bila < 0, "Segera" bila 0..30, selain itu
  /// "Berlaku". `null` (server menandai `overdue` tanpa tanggal) = "Lewat
  /// jadwal": jumlah harinya tidak ditebak.
  factory StatusTampil.jadwal(int? hari) {
    if (hari == null || hari < 0) return _lewatJadwal;
    if (hari <= batasSegeraHari) return _segera;
    return _berlaku;
  }

  /// Terjemahkan kode dari API menjadi tampilan.
  ///
  /// [keputusan] dipakai untuk sesi yang sudah `disetujui`: yang tampil
  /// vonisnya (PASS/FAIL), karena itu yang dicari orang; `null` untuk alat yang
  /// memang tidak divonis, dan tampil "Disetujui". Kode yang belum dikenal
  /// tampil apa adanya dengan nada netral, bukan disembunyikan.
  factory StatusTampil.dariKode(String? kode, {String? keputusan}) {
    switch (kode) {
      // Sesi kalibrasi.
      case 'draft':
        return const StatusTampil(
          KataStatus.draf,
          NadaStempel.netral,
          Icons.edit_note,
        );
      case 'menunggu_approval':
      // Gerbang pengesahan dicabut 15 Okt 2026; baris lama bisa masih memakainya.
      case 'menunggu_pengesahan':
        return const StatusTampil(
          KataStatus.menunggu,
          NadaStempel.tunggu,
          Icons.hourglass_empty,
        );
      case 'perlu_revisi':
        return const StatusTampil(
          KataStatus.perluRevisi,
          NadaStempel.awas,
          Icons.error_outline,
        );
      case 'disetujui':
        return switch (keputusan) {
          'PASS' => _pass,
          'FAIL' => _fail,
          _ => const StatusTampil(
            KataStatus.disetujui,
            NadaStempel.lulus,
            Icons.task_alt,
          ),
        };
      case 'PASS':
        return _pass;
      case 'FAIL':
        return _fail;
      case 'ditarik':
        return const StatusTampil(
          KataStatus.ditarik,
          NadaStempel.awas,
          Icons.undo,
        );

      // Alat dan jadwal.
      case 'aktif':
        return const StatusTampil(
          KataStatus.aktif,
          NadaStempel.lulus,
          Icons.check_circle_outline,
        );
      case 'nonaktif':
        return const StatusTampil(
          KataStatus.nonaktif,
          NadaStempel.netral,
          Icons.remove_circle_outline,
        );
      case 'overdue':
        return _lewatJadwal;

      // Standar acuan, dan label dokumen sertifikat "berlaku" (masih sah:
      // kata dan nada yang sama dengan jadwal "Berlaku").
      case 'valid':
      case 'berlaku':
        return _berlaku;
      case 'warning':
        return _segera;
      case 'expired':
        return const StatusTampil(
          KataStatus.masaBerlakuBerakhir,
          NadaStempel.gagal,
          Icons.event_busy_outlined,
        );

      // Sertifikat: status teknis dan label dokumen (`StatusDokumen`).
      case 'terbit':
        return const StatusTampil(
          KataStatus.terbit,
          NadaStempel.lulus,
          Icons.workspace_premium_outlined,
        );
      case 'menunggu_generate':
        return const StatusTampil(
          KataStatus.sedangDibuat,
          NadaStempel.tunggu,
          Icons.autorenew,
        );
      case 'gagal':
        return const StatusTampil(
          KataStatus.gagalDibuat,
          NadaStempel.gagal,
          Icons.report_outlined,
        );
      // Sudah diterbitkan ulang sebagai revisi: bukan kegagalan dan bukan
      // peringatan, jadi netral (bergaris tepi).
      case 'digantikan':
        return const StatusTampil(
          KataStatus.digantikanRevisi,
          NadaStempel.netral,
          Icons.swap_horiz,
        );
      case 'belum_terbit':
        return const StatusTampil(
          KataStatus.belumTerbit,
          NadaStempel.netral,
          Icons.pending_outlined,
        );

      // Akun.
      case 'pending':
        return const StatusTampil(
          KataStatus.menungguPersetujuan,
          NadaStempel.tunggu,
          Icons.hourglass_empty,
        );

      // Order.
      case 'baru':
        return const StatusTampil(
          KataStatus.baru,
          NadaStempel.tunggu,
          Icons.add_circle_outline,
        );
      case 'diproses':
        return const StatusTampil(
          KataStatus.diproses,
          NadaStempel.tunggu,
          Icons.autorenew,
        );
      case 'selesai':
        return const StatusTampil(
          KataStatus.selesai,
          NadaStempel.lulus,
          Icons.task_alt,
        );
      case 'dibatalkan':
        // Ikonnya sengaja BUKAN `cancel_outlined` milik FAIL: order yang tidak
        // jadi dan alat yang tidak lolos tidak boleh terbaca sama sekilas.
        // Berlaku juga untuk sertifikat `dibatalkan`.
        return const StatusTampil(
          KataStatus.dibatalkan,
          NadaStempel.gagal,
          Icons.do_not_disturb_on_outlined,
        );

      default:
        return StatusTampil(
          null,
          NadaStempel.netral,
          Icons.help_outline,
          mentah: kode ?? '–',
        );
    }
  }

  static const StatusTampil _pass = StatusTampil(
    KataStatus.pass,
    NadaStempel.lulus,
    Icons.check_circle_outline,
  );
  static const StatusTampil _fail = StatusTampil(
    KataStatus.fail,
    NadaStempel.gagal,
    Icons.cancel_outlined,
  );
  static const StatusTampil _berlaku = StatusTampil(
    KataStatus.berlaku,
    NadaStempel.lulus,
    Icons.verified_outlined,
  );
  static const StatusTampil _segera = StatusTampil(
    KataStatus.segera,
    NadaStempel.awas,
    Icons.schedule,
  );
  static const StatusTampil _lewatJadwal = StatusTampil(
    KataStatus.lewatJadwal,
    NadaStempel.gagal,
    Icons.event_busy_outlined,
  );

  /// Kata dalam bahasa yang sedang berlaku ([l10n]); kode asing apa adanya.
  String label(AppLocalizations l10n) => switch (kata) {
    KataStatus.draf => l10n.stempelDraf,
    KataStatus.menunggu => l10n.stempelMenunggu,
    KataStatus.perluRevisi => l10n.stempelPerluRevisi,
    KataStatus.disetujui => l10n.stempelDisetujui,
    KataStatus.pass => l10n.stempelPass,
    KataStatus.fail => l10n.stempelFail,
    KataStatus.ditarik => l10n.stempelDitarik,
    KataStatus.aktif => l10n.stempelAktif,
    KataStatus.nonaktif => l10n.stempelNonaktif,
    KataStatus.lewatJadwal => l10n.stempelLewatJadwal,
    KataStatus.berlaku => l10n.stempelBerlaku,
    KataStatus.segera => l10n.stempelSegera,
    KataStatus.masaBerlakuBerakhir => l10n.stempelMasaBerlakuBerakhir,
    KataStatus.terbit => l10n.stempelTerbit,
    KataStatus.sedangDibuat => l10n.stempelSedangDibuat,
    KataStatus.gagalDibuat => l10n.stempelGagalDibuat,
    KataStatus.menungguPersetujuan => l10n.stempelMenungguPersetujuan,
    KataStatus.baru => l10n.stempelBaru,
    KataStatus.diproses => l10n.stempelDiproses,
    KataStatus.selesai => l10n.stempelSelesai,
    KataStatus.dibatalkan => l10n.stempelDibatalkan,
    KataStatus.digantikanRevisi => l10n.stempelDigantikanRevisi,
    KataStatus.belumTerbit => l10n.stempelBelumTerbit,
    null => mentah ?? '–',
  };

  /// Tinta dan latar tipis untuk nada ini. Nada [NadaStempel.netral] tidak
  /// berlatar (transparan): ia digambar bergaris tepi.
  (Color tinta, Color latar) warna(SidikMaterial m) => switch (nada) {
    NadaStempel.lulus => (m.lulus, m.lulusTipis),
    NadaStempel.gagal => (m.gagal, m.gagalTipis),
    NadaStempel.awas => (m.awas, m.awasTipis),
    NadaStempel.tunggu => (m.tunggu, m.tungguTipis),
    NadaStempel.netral => (m.tinta2, Colors.transparent),
  };

  @override
  bool operator ==(Object other) =>
      other is StatusTampil &&
      other.kata == kata &&
      other.mentah == mentah &&
      other.nada == nada &&
      other.ikon == ikon;

  @override
  int get hashCode => Object.hash(kata, mentah, nada, ikon);
}
