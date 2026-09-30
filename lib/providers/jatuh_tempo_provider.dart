import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/equipment.dart';
import '../models/jatuh_tempo.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'equipment_provider.dart';
import 'jam_provider.dart';

/// Batas halaman yang ditarik per permintaan. 15 alat per halaman × 20 = 300
/// alat — jauh di atas lab yang ada sekarang. Batas ada supaya server yang
/// sedang lambat tidak membuat satu layar menembakkan puluhan permintaan
/// beruntun.
const _batasHalaman = 20;

/// Rentang terjauh layar jatuh tempo (chip "90 hari"). Dikirim ke server
/// sebagai `jatuh_tempo_dalam`, jadi alat yang jatuh temponya tahun depan tidak
/// ikut ditarik sama sekali.
const _rentangHari = 90;

/// Tarik SEMUA halaman satu permintaan berpenyaring, sampai [_batasHalaman].
Future<List<Equipment>> _tarikSemua(
  Ref ref,
  String token, {
  String? status,
  int? pelangganId,
  int? jatuhTempoDalam,
  bool termasukLewat = false,
}) async {
  final service = ref.read(equipmentServiceProvider);
  final semua = <Equipment>[];
  var halaman = 1;
  while (true) {
    final hasil = await service.daftar(
      token,
      status: status,
      pelangganId: pelangganId,
      jatuhTempoDalam: jatuhTempoDalam,
      termasukLewat: termasukLewat,
      // Paling lama lewat di atas — urutan yang dibutuhkan layar, dikerjakan
      // server. Kalau daftar terpotong di batas halaman, yang hilang adalah
      // yang paling jauh jatuh temponya, bukan yang paling mendesak.
      urut: 'jatuh_tempo',
      page: halaman,
    );
    semua.addAll(hasil.items);
    if (halaman >= hasil.lastPage || halaman >= _batasHalaman) break;
    halaman++;
  }
  return semua;
}

/// Dua permintaan, bukan satu, dan itu disengaja:
///
/// 1. `status=overdue` — SEMUA alat yang ditandai lewat jadwal. Dipisah karena
///    `overdue` bukan nilai di DB dan alat yang ditandai `overdue` tapi tanpa
///    tanggal tidak akan pernah muncul di saringan tanggal.
/// 2. `jatuh_tempo_dalam=90&termasuk_lewat=1` — alat aktif yang jatuh tempo
///    dalam 90 hari, TERMASUK yang tanggalnya sudah lewat tapi statusnya belum
///    sempat berganti. Ini yang dulu ditarik dengan membaca SEMUA alat aktif
///    lalu membuangnya di sisi HP.
///
/// Daftarnya bisa memuat id yang sama dua kali; `susunJatuhTempo` yang
/// membuangnya. Pengelompokan (lewat / 30 / 90 hari) tetap di aplikasi karena
/// "hari ini" milik `jamProvider`, bukan milik server.
Future<RingkasanJatuhTempo> _ringkas(Ref ref, {int? pelangganId}) async {
  // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
  ref.watch(authProvider);

  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  final semua = <Equipment>[
    ...await _tarikSemua(
      ref,
      token,
      status: 'overdue',
      pelangganId: pelangganId,
    ),
    ...await _tarikSemua(
      ref,
      token,
      pelangganId: pelangganId,
      jatuhTempoDalam: _rentangHari,
      termasukLewat: true,
    ),
  ];

  return susunJatuhTempo(semua, ref.read(jamProvider)());
}

/// Jatuh tempo se-lab, dipakai layar Jatuh tempo, Jadwal kalibrasi ulang,
/// Pusat pelanggan, dan Beranda super admin — SATU pengambilan untuk semuanya,
/// supaya angka "4 lewat jadwal" di beranda selalu sama dengan panjang daftar
/// yang terbuka begitu kartunya diketuk.
///
/// Sengaja BUKAN `equipmentProvider` (state tab "Alat": punya kata cari &
/// saringan sendiri) dan bukan `deviceOverviewProvider` (cuma halaman
/// pertama): keduanya bisa membuat daftar jatuh tempo terpotong tanpa tanda.
///
/// Tidak ada kata cari di sini, jadi tidak ada saringan yang perlu dijaga saat
/// `realtimeSyncProvider` meng-invalidate-nya.
final jatuhTempoProvider = FutureProvider<RingkasanJatuhTempo>(
  (ref) => _ringkas(ref),
  retry: (retryCount, error) => null,
);

/// Jatuh tempo SATU pelanggan, untuk detail Pusat pelanggan. Penyaringannya di
/// server (`customer_id`), bukan membuang alat pelanggan lain dari
/// [jatuhTempoProvider] — jadi detail satu pelanggan tidak lagi bergantung pada
/// apakah daftar se-lab sempat termuat atau terpotong.
///
/// `autoDispose`: dibuka sesekali.
final jatuhTempoPelangganProvider = FutureProvider.autoDispose
    .family<RingkasanJatuhTempo, int>(
      (ref, pelangganId) => _ringkas(ref, pelangganId: pelangganId),
      retry: (retryCount, error) => null,
    );
