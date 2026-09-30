import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/pelacakan.dart';
import '../models/pengesahan.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'master_data_provider.dart' show customerServiceProvider;
import 'pengendalian_provider.dart'
    show pelacakanServiceProvider, pengesahanServiceProvider;

/// Kata cari Pusat pelanggan.
///
/// Di provider sendiri, bukan field controller atau state layar: daftarnya
/// di-invalidate `realtimeSyncProvider` tiap ada perubahan dari perangkat lain,
/// dan saringan yang ikut hilang membuat super admin yang sedang mengetik
/// "tirta" tiba-tiba melihat semua pelanggan (alasan yang sama dengan
/// `_Saringan` di `pengendalian_provider.dart`). Ikut `authProvider`: ganti
/// akun → kotak cari kembali kosong.
final kataCariPelangganProvider = NotifierProvider<KataCariPelanggan, String>(
  KataCariPelanggan.new,
);

class KataCariPelanggan extends Notifier<String> {
  @override
  String build() {
    ref.watch(authProvider);
    return '';
  }

  void setel(String kata) => state = kata;
}

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Daftar pelanggan untuk Pusat pelanggan. Pencariannya dikerjakan server
/// (`?search=`, halaman pertama 15 pelanggan) — sama seperti layar Pelanggan di
/// master data, supaya lab dengan pelanggan lebih banyak dari satu halaman
/// tidak menyaring sebagian daftar saja di sisi HP.
final pusatPelangganProvider = FutureProvider<List<Customer>>((ref) async {
  ref.watch(authProvider);
  final kata = ref.watch(kataCariPelangganProvider);
  return ref
      .read(customerServiceProvider)
      .daftar(await _token(ref), search: kata);
}, retry: (retryCount, error) => null);

/// Satu pelanggan. `autoDispose`: dibuka sesekali, tidak perlu ditahan.
final detailPelangganProvider = FutureProvider.autoDispose
    .family<Customer, int>((ref, id) async {
      ref.watch(authProvider);
      return ref.read(customerServiceProvider).detail(await _token(ref), id);
    }, retry: (retryCount, error) => null);

/// Paket yang SEDANG BERJALAN (belum diserahkan) — bahan Beranda super admin
/// dan Detail pelanggan.
///
/// Sengaja bukan `daftarPaketProvider`: itu milik layar Pelacakan dan membawa
/// kata cari & saringan "terlambat"-nya; dipakai bareng, saringan di layar itu
/// ikut mengubah angka di beranda.
final paketBerjalanProvider = FutureProvider<List<PaketLacak>>((ref) async {
  ref.watch(authProvider);
  final semua = await ref
      .read(pelacakanServiceProvider)
      .daftar(await _token(ref));
  return [
    for (final p in semua)
      if (p.tahap != 'diserahkan') p,
  ];
}, retry: (retryCount, error) => null);

/// Paket berjalan milik satu pelanggan. Pencocokannya lewat NAMA (satu-satunya
/// yang dikirim `GET /pelacakan`), jadi diambil dari [paketBerjalanProvider]
/// dan disaring di sini — dua pelanggan yang persis sama namanya tidak
/// dibedakan; di data yang ada, nama pelanggan unik per lab.
final paketPelangganProvider = FutureProvider.autoDispose
    .family<List<PaketLacak>, String>((ref, nama) async {
      final semua = await ref.watch(paketBerjalanProvider.future);
      return [
        for (final p in semua)
          if (p.pelanggan == nama) p,
      ];
    });

/// Antrean pengesahan yang BELUM disaring, khusus angka di Beranda super
/// admin.
///
/// Bukan `antreanPengesahanProvider`: kata cari layar antreannya tersimpan di
/// sana, jadi super admin yang habis mencari "tirta" di gerbang sertifikat akan
/// melihat berandanya menulis "1 lembar kerja menunggu" padahal ada tiga.
final antreanBerandaProvider = FutureProvider<List<ItemPengesahan>>((
  ref,
) async {
  ref.watch(authProvider);
  return ref.read(pengesahanServiceProvider).antrean(await _token(ref));
}, retry: (retryCount, error) => null);
