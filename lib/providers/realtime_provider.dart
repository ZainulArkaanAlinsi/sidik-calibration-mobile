import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/latar_depan.dart';
import '../services/realtime_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart';
import 'history_provider.dart';
import 'jatuh_tempo_provider.dart';
import 'notifikasi_perangkat_provider.dart';
import 'notification_provider.dart';
import 'pengendalian_provider.dart';
import 'certificate_provider.dart';
import 'koreksi_provider.dart';
import 'permintaan_provider.dart';
import 'pusat_pelanggan_provider.dart';

/// Sambungan realtime. **Mock (no-op)** kalau realtime nonaktif (kunci Reverb
/// kosong) atau mode mock — jadi dev & test nggak pernah nyoba buka websocket.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  if (!AppConfig.realtimeAktif) return MockRealtimeService();
  final service = PusherRealtimeService();
  ref.onDispose(service.putus);
  return service;
});

/// Jeda tarik ulang waktu realtime mati.
///
/// Tiga menit, bukan satu. Versi satu menit (15 Sep 2026 pagi) membuat server
/// Render gratis nyaris tak pernah menganggur: satu tarikan admin = riwayat +
/// antrean + draf = 5 halaman × ~3,7 s kerja server, dikali jumlah perangkat
/// yang terbuka — dan tombol kirim ikut antre sampai "Server nggak nyaut".
/// Membangunkan server sudah diurus cron-job.org, bukan tugas tarikan ini.
const jedaTarikTanpaRealtime = Duration(minutes: 3);

/// Nyambungin realtime ke daur hidup auth: begitu user login (+ token) → konek
/// & subscribe channel org/user; tiap peristiwa → refresh provider terkait;
/// logout → putus. Ditahan hidup dengan di-`watch` dari shell utama.
final realtimeSyncProvider = Provider<void>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  final user = ref.watch(authProvider).value;

  if (user == null) return; // belum login → nggak usah konek

  // Selama Reverb mati di produksi (`render.yaml`: `BROADCAST_CONNECTION=log`)
  // tidak ada sinyal apa pun dari perangkat lain: sesi yang dikirim dari HP
  // tidak muncul di antrean approval Windows, dan tolakan dari Windows tidak
  // sampai ke HP, sampai layarnya ditutup-buka. Tarik ulang berkala
  // menggantikan sinyal itu lewat jalur yang sama persis — invalidate tetap
  // lazy, jadi yang benar-benar ditarik cuma layar yang sedang ditonton.
  //
  // Mode mock dikecualikan: tidak ada perangkat lain untuk disusul.
  if (!AppConfig.realtimeAktif && !AppConfig.useMock) {
    final timer = Timer.periodic(jedaTarikTanpaRealtime, (_) {
      // HP di saku / jendela diminimalkan tidak ikut membebani server.
      if (!aplikasiDiLayarDepan()) return;

      _tangani(ref, const DataBerubah(jenis: 'berkala', aksi: 'tarik'));
      _tangani(ref, const NotifikasiMasuk());
    });
    ref.onDispose(timer.cancel);
  }

  final sub = service.peristiwa.listen((p) => _tangani(ref, p));

  // Konek butuh token dari storage (async) — fire-and-forget.
  Future(() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;
    await service.hubungkan(
      token: token,
      userId: user.id,
      organizationId: user.organizationId,
    );

    // Notifikasi yang UDAH ada waktu sambungan dibuka dicatat tanpa dibunyiin.
    // Admin yang login pagi hari dengan 20 notifikasi belum dibaca nggak boleh
    // kena 20 notifikasi sistem sekaligus — yang kayak gitu bukan bikin dia
    // sadar, tapi bikin dia matiin notifikasi app-nya selamanya.
    //
    // Dibungkus `try`: ini lapisan tambahan. Gagal narik daftar awal — token
    // kedaluwarsa, jaringan putus — nggak boleh ngerusak sambungan realtime
    // yang justru tugas utama provider ini.
    try {
      final awal = await ref.read(notificationProvider.future);
      await ref.read(pengabarNotifikasiProvider).mulai(awal);
    } catch (_) {
      // Loncengnya di dalam app tetap jalan; itu sumber kebenarannya.
    }
  });

  ref.onDispose(() {
    sub.cancel();
    service.putus();
  });
});

/// Sinyal tipis → tarik ulang data lewat REST (arsitektur backend: broadcast
/// cuma nandain "ada perubahan", isinya tetap via REST ber-otorisasi).
void _tangani(Ref ref, PeristiwaRealtime p) {
  switch (p) {
    case DataBerubah():
      // Invalidate = lazy: yang lagi ditonton refetch, yang nggak nunggu dibuka.
      ref.invalidate(dashboardProvider);
      ref.invalidate(historyProvider);
      ref.invalidate(antreanApprovalProvider);
      // Pengesahan, pelacakan, penugasan: super admin yang mengesahkan dari
      // satu HP, meja depan yang menandai serah terima dari laptop, teknisi
      // yang melapor progres — perangkat lain di lab yang sama ikut menyusul.
      // Saringan layarnya tidak hilang (lihat `Saringan`).
      ref.invalidate(antreanPengesahanProvider);
      ref.invalidate(daftarPaketProvider);
      ref.invalidate(detailPaketProvider);
      ref.invalidate(daftarPenugasanProvider);
      // Layar super admin/admin turunan dari data yang sama: jatuh tempo &
      // jadwal (alat baru, tanggal diubah, sesi disahkan memajukan jatuh
      // tempo), Pusat pelanggan, dan paket berjalan di beranda. Kata cari
      // Pusat pelanggan hidup di provider terpisah, jadi tidak ikut hilang.
      ref.invalidate(jatuhTempoProvider);
      ref.invalidate(jatuhTempoPelangganProvider);
      ref.invalidate(pusatPelangganProvider);
      ref.invalidate(detailPelangganProvider);
      ref.invalidate(paketBerjalanProvider);
      ref.invalidate(antreanBerandaProvider);
      // Permintaan pelanggan (jenis 'permintaan': dibuat/diterima/ditolak/
      // dibatalkan/pesan): admin lain menerimanya, atau pelanggan menulis di
      // utas — antrean, badge menu, detail, dan utas yang terbuka menyusul.
      // Tab & kata cari tersimpan di provider terpisah, jadi tidak hilang.
      ref.invalidate(antreanPermintaanProvider);
      ref.invalidate(jumlahPermintaanBaruProvider);
      ref.invalidate(detailPermintaanProvider);
      ref.invalidate(pesanPermintaanProvider);
      // Jadwal, resi, dan alat tiba (jenis 'permintaan', aksi resi/jadwal/
      // alat_tiba) menarik detail yang sama — sudah tercakup di atas.
      //
      // Koreksi pelanggan (jenis 'koreksi_pelanggan': dibuat/diterima/
      // ditolak): antrean, badge menu, dan detail yang terbuka menyusul.
      ref.invalidate(antreanKoreksiProvider);
      ref.invalidate(jumlahKoreksiMenungguProvider);
      ref.invalidate(detailKoreksiProvider);
      // Sertifikat (jenis 'sertifikat': direvisi/dibatalkan/terbit): status
      // dokumen, revisi yang selesai dirender, dan tombol admin ikut segar.
      // Family-nya lazy: hanya yang sedang ditonton yang menarik ulang.
      ref.invalidate(certificateDetailProvider);
    case NotifikasiMasuk():
      // Badge lonceng selalu di-refresh (nyala barengan HP↔desktop); daftar
      // notifikasi refetch lazy saat layarnya dibuka.
      ref.invalidate(notificationProvider);
      ref.read(unreadCountProvider.notifier).muatUlang();
      // Lalu naik ke bilah SISTEM. Lonceng cuma kelihatan sama orang yang lagi
      // mbuka app-nya; admin yang lagi ngerjain hal lain di laptop nggak bakal
      // tahu ada kiriman teknisi masuk sampai dia kebetulan mbuka app lagi.
      _umumkan(ref);
  }
}

/// Tarik daftar notifikasi yang barusan di-invalidate, lalu umumin yang beneran
/// baru ke bilah sistem.
///
/// Sengaja `unawaited`-style (dibiarkan jalan sendiri): `_tangani` dipanggil
/// dari listener stream yang nggak nunggu siapa-siapa, dan gagal nampilin
/// notifikasi nggak boleh nahan refresh data yang jauh lebih penting.
void _umumkan(Ref ref) {
  Future(() async {
    try {
      final daftar = await ref.read(notificationProvider.future);
      await ref.read(pengabarNotifikasiProvider).umumkan(daftar);
    } catch (_) {
      // Notifikasi sistem itu lapisan tambahan. Kalau gagal — izin dicabut,
      // jaringan putus di tengah refetch — loncengnya di dalam app tetap
      // nyala, dan itu yang jadi sumber kebenarannya.
    }
  });
}
