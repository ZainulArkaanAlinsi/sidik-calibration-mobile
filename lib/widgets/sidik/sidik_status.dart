import 'package:flutter/material.dart';

import '../../core/theme/sidik_material.dart';

/// Nada status. Empat saja, dan tiap nada punya ARTI tetap di seluruh app.
///
/// Ini yang memperbaiki masalah lama: status yang sama tampil beda warna di
/// layar yang beda (`perlu_revisi` merah di Alur Kerja tapi kuning di Riwayat;
/// `menunggu_approval` kuning di satu tempat, abu di tempat lain), dan cobalt
/// dipakai sekaligus sebagai warna tombol DAN sebagai "peringatan".
enum NadaStatus {
  /// Beres, lolos, aktif, berlaku.
  lulus,

  /// Gagal, kadaluarsa, error. Dipakai paling irit supaya tetap berbobot.
  gagal,

  /// "Lihat dulu" — perlu revisi, jatuh tempo, hampir habis.
  awas,

  /// Lagi di tangan orang lain — menunggu approval, sedang dibuat.
  tunggu,

  /// Belum jalan — draf, nonaktif.
  draf,
}

/// Satu status yang siap ditampilkan: label, nada, ikon.
@immutable
class StatusSidik {
  const StatusSidik(this.label, this.nada, this.ikon);

  final String label;
  final NadaStatus nada;
  final IconData ikon;

  /// Terjemahkan kode dari API jadi tampilan.
  ///
  /// **Ini satu-satunya tempat pemetaan itu ditulis.** Riwayat, Detail, Alur
  /// Kerja, Antrean, Notifikasi, dan Alat semuanya lewat sini, jadi status yang
  /// sama tidak bisa lagi tampil beda di layar yang beda.
  ///
  /// [keputusan] dipakai untuk sesi yang sudah `disetujui`: yang ditampilkan
  /// vonisnya (PASS/FAIL), bukan kata "Disetujui" — karena itu yang dicari
  /// orang. `null` berarti alat yang memang tidak divonis (Conductivity,
  /// Spectrophotometer).
  factory StatusSidik.dariApi(String? kode, {String? keputusan}) {
    switch (kode) {
      // ── Sesi kalibrasi ──────────────────────────────────────────────
      case 'draft':
        return const StatusSidik('Draf', NadaStatus.draf, Icons.edit_outlined);
      case 'menunggu_approval':
        return const StatusSidik(
          'Menunggu approval',
          NadaStatus.tunggu,
          Icons.hourglass_empty,
        );
      // Gerbang pengesahan (26 Sep): sudah diperiksa admin, belum sah.
      case 'menunggu_pengesahan':
        return const StatusSidik(
          'Menunggu pengesahan',
          NadaStatus.tunggu,
          Icons.verified_user_outlined,
        );
      case 'perlu_revisi':
        return const StatusSidik(
          'Perlu revisi',
          NadaStatus.awas,
          Icons.error_outline,
        );
      case 'disetujui':
        return switch (keputusan) {
          'PASS' => const StatusSidik(
            'PASS',
            NadaStatus.lulus,
            Icons.check_circle_outline,
          ),
          'FAIL' => const StatusSidik(
            'FAIL',
            NadaStatus.gagal,
            Icons.cancel_outlined,
          ),
          _ => const StatusSidik(
            'Tanpa vonis',
            NadaStatus.tunggu,
            Icons.remove_circle_outline,
          ),
        };

      // ── Vonis lepas ─────────────────────────────────────────────────
      case 'PASS':
        return const StatusSidik(
          'PASS',
          NadaStatus.lulus,
          Icons.check_circle_outline,
        );
      case 'FAIL':
        return const StatusSidik('FAIL', NadaStatus.gagal, Icons.cancel_outlined);

      // ── Alat ────────────────────────────────────────────────────────
      case 'aktif':
        return const StatusSidik(
          'Aktif',
          NadaStatus.lulus,
          Icons.check_circle_outline,
        );
      case 'overdue':
        return const StatusSidik(
          'Jatuh tempo',
          NadaStatus.awas,
          Icons.schedule,
        );
      case 'nonaktif':
        return const StatusSidik(
          'Nonaktif',
          NadaStatus.draf,
          Icons.remove_circle_outline,
        );

      // ── Standar acuan ───────────────────────────────────────────────
      case 'valid':
        return const StatusSidik(
          'Berlaku',
          NadaStatus.lulus,
          Icons.verified_outlined,
        );
      case 'warning':
        return const StatusSidik(
          'Hampir habis',
          NadaStatus.awas,
          Icons.schedule,
        );
      case 'expired':
        return const StatusSidik(
          'Kadaluarsa',
          NadaStatus.gagal,
          Icons.error_outline,
        );

      // ── Sertifikat ──────────────────────────────────────────────────
      case 'terbit':
        return const StatusSidik(
          'Terbit',
          NadaStatus.lulus,
          Icons.workspace_premium_outlined,
        );
      case 'menunggu_generate':
        return const StatusSidik(
          'Sedang dibuat',
          NadaStatus.tunggu,
          Icons.hourglass_empty,
        );
      case 'gagal':
        return const StatusSidik(
          'Gagal dibuat',
          NadaStatus.gagal,
          Icons.error_outline,
        );

      // ── Akun ────────────────────────────────────────────────────────
      case 'pending':
        return const StatusSidik(
          'Menunggu persetujuan',
          NadaStatus.awas,
          Icons.hourglass_empty,
        );

      // Kode yang belum dikenal ditampilkan apa adanya dengan nada netral —
      // lebih baik daripada menyembunyikannya.
      default:
        return StatusSidik(
          kode ?? '—',
          NadaStatus.draf,
          Icons.help_outline,
        );
    }
  }

  /// Warna tinta + warna dasar untuk nada ini.
  (Color, Color) warna(SidikMaterial m) => switch (nada) {
    NadaStatus.lulus => (m.lulus, m.lulusTipis),
    NadaStatus.gagal => (m.gagal, m.gagalTipis),
    NadaStatus.awas => (m.awas, m.awasTipis),
    NadaStatus.tunggu => (m.tunggu, m.tungguTipis),
    NadaStatus.draf => (m.tinta2, Colors.transparent),
  };
}

/// Label status tercetak di kertas.
///
/// Selalu **ikon + teks**, tidak pernah warna saja — supaya tetap kebaca oleh
/// yang buta warna dan tetap masuk akal di cetakan hitam-putih.
class SidikLencana extends StatelessWidget {
  const SidikLencana(this.status, {super.key});

  /// Bikin langsung dari kode API.
  SidikLencana.dariApi(String? kode, {super.key, String? keputusan})
    : status = StatusSidik.dariApi(kode, keputusan: keputusan);

  final StatusSidik status;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final (tinta, dasar) = status.warna(m);
    final draf = status.nada == NadaStatus.draf;

    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        height: 26,
        padding: const EdgeInsets.only(left: 7, right: 9),
        decoration: BoxDecoration(
          color: dasar,
          borderRadius: BorderRadius.circular(3),
          // Draf belum punya isi, jadi tepinya dilemahkan — Flutter tidak
          // punya garis putus-putus bawaan untuk Border, dan menggambarnya
          // sendiri tidak sepadan buat satu keadaan.
          border: Border.all(
            color: draf ? tinta.withValues(alpha: 0.5) : tinta,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.ikon, size: 14, color: tinta),
            const SizedBox(width: 5),
            Text(
              status.label,
              style: TextStyle(
                color: tinta,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CAP KARET — vonis besar, miring, seperti stempel kantor.
///
/// Dipakai **irit**: cuma di kepala layar detail dan di pratinjau sertifikat.
/// Jangan dipakai di baris daftar — belasan cap miring dalam satu daftar
/// kebaca berantakan, dan itu persis jenis "skeuomorphic jelek" yang dihindari
/// sistem ini.
class CapVonis extends StatelessWidget {
  const CapVonis({super.key, required this.lulus, this.teks});

  final bool lulus;
  final String? teks;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final warna = lulus ? m.lulus : m.gagal;
    return Semantics(
      label: 'Vonis: ${teks ?? (lulus ? 'PASS' : 'FAIL')}',
      excludeSemantics: true,
      child: Transform.rotate(
        angle: -0.07, // ±4°, seperti cap yang ditekan tangan
        child: Opacity(
          opacity: 0.88,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: warna, width: 3),
            ),
            child: Text(
              teks ?? (lulus ? 'PASS' : 'FAIL'),
              style: TextStyle(
                color: warna,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
