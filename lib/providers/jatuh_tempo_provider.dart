import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/equipment.dart';
import '../models/jatuh_tempo.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'equipment_provider.dart';
import 'jam_provider.dart';

/// Batas halaman yang ditarik per status. 15 alat per halaman × 20 = 300 alat
/// per status — jauh di atas lab yang ada sekarang. Batas ada supaya server
/// yang sedang lambat tidak membuat satu layar menembakkan puluhan permintaan
/// beruntun; kalau labnya memang sebesar itu, yang benar adalah saringan
/// "jatuh tempo dalam N hari" di server, bukan menaikkan angka ini.
const _batasHalaman = 20;

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
final jatuhTempoProvider = FutureProvider<RingkasanJatuhTempo>((ref) async {
  // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
  ref.watch(authProvider);

  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  final service = ref.read(equipmentServiceProvider);
  final semua = <Equipment>[];

  // Dua permintaan terpisah karena `status=aktif` di server SUDAH
  // mengecualikan yang lewat tanggal, dan `overdue` bukan nilai di DB —
  // menggabungkannya jadi satu saringan tidak ada di API.
  for (final status in const ['overdue', 'aktif']) {
    var halaman = 1;
    while (true) {
      final hasil = await service.daftar(token, status: status, page: halaman);
      semua.addAll(hasil.items);
      if (halaman >= hasil.lastPage || halaman >= _batasHalaman) break;
      halaman++;
    }
  }

  return susunJatuhTempo(semua, ref.read(jamProvider)());
}, retry: (retryCount, error) => null);
