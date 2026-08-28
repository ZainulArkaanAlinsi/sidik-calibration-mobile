import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/skema_dinamis.dart';
import '../services/dokumen_generik_service.dart';
import '../services/photo_source.dart';
import 'auth_provider.dart';

final dokumenGenerikServiceProvider = Provider<DokumenGenerikService>(
  (ref) => DokumenGenerikService(ref.watch(apiClientProvider)),
);

/// Sumber fotonya lewat provider supaya alur kameranya bisa di-widget-test —
/// alasan yang sama kenapa [SumberFoto] dipisah dari layar.
final sumberFotoDokumenProvider = Provider<SumberFoto>(
  (ref) => const KameraSumberFoto(),
);

/// Keadaan satu sesi baca dokumen.
sealed class KeadaanBacaDokumen {
  const KeadaanBacaDokumen();
}

class BelumAdaFoto extends KeadaanBacaDokumen {
  const BelumAdaFoto();
}

class SedangMembaca extends KeadaanBacaDokumen {
  const SedangMembaca();
}

class DokumenTerbaca extends KeadaanBacaDokumen {
  const DokumenTerbaca(this.skema, this.foto, this.bacaanId);

  final SkemaDinamis skema;

  /// Id baris `dokumen_bacaan` di server. Dipakai buat ngirim koreksi.
  final int bacaanId;

  /// Fotonya ditahan buat layar keterlacakan — teknisi harus bisa lihat asal
  /// tiap angka di gambar aslinya.
  final File foto;
}

class BacaDokumenGagal extends KeadaanBacaDokumen {
  const BacaDokumenGagal(this.sebab, this.pesan);

  final GagalBacaDokumen sebab;
  final String pesan;

  /// Cuma sebagian kegagalan yang pantas dijawab "foto ulang". Menawarkan
  /// tombol itu waktu penyedianya yang sibuk cuma bikin teknisi motret
  /// berkali-kali buat sesuatu yang mustahil berhasil sampai bebannya turun.
  bool get pantasDiulang =>
      sebab == GagalBacaDokumen.takTerbaca ||
      sebab == GagalBacaDokumen.jaringan;
}

/// Hasil terakhir menekan Simpan. `null` = belum pernah ditekan.
class KeadaanSimpanKoreksi {
  const KeadaanSimpanKoreksi({
    required this.sedang,
    this.tersimpan,
    this.gagal,
  });

  final bool sedang;

  /// Berapa koreksi yang benar-benar mendarat di server.
  final int? tersimpan;

  final String? gagal;
}

class PengendaliSimpanKoreksi extends Notifier<KeadaanSimpanKoreksi> {
  @override
  KeadaanSimpanKoreksi build() => const KeadaanSimpanKoreksi(sedang: false);

  Future<void> simpan(int bacaanId) async {
    final nilai = ref.read(koreksiDokumenProvider);

    state = const KeadaanSimpanKoreksi(sedang: true);

    final token = await ref.read(tokenStorageProvider).read();

    final hasil = await ref
        .read(dokumenGenerikServiceProvider)
        .koreksi(bacaanId: bacaanId, nilai: nilai, token: token);

    state = hasil.berhasil
        ? KeadaanSimpanKoreksi(
            sedang: false,
            tersimpan: hasil.cocok + hasil.meleset,
          )
        : KeadaanSimpanKoreksi(sedang: false, gagal: hasil.pesan);
  }
}

final simpanKoreksiProvider =
    NotifierProvider<PengendaliSimpanKoreksi, KeadaanSimpanKoreksi>(
      PengendaliSimpanKoreksi.new,
    );

class PengendaliBacaDokumen extends Notifier<KeadaanBacaDokumen> {
  @override
  KeadaanBacaDokumen build() => const BelumAdaFoto();

  /// Ambil foto lalu baca. [namaAlat] cuma konteks — isi lembarnya yang
  /// menentukan bentuk formnya.
  Future<void> fotoLaluBaca({String? namaAlat}) async {
    final foto = await ref
        .read(sumberFotoDokumenProvider)
        .ambil(
          // Cukup besar buat tulisan tangan tetap kebaca, tapi nggak sebesar foto
          // mentah 12 MP — yang cuma bikin unggahan lama di sinyal lapangan tanpa
          // nambah ketelitian.
          maxWidth: 2400,
          imageQuality: 88,
        );

    // Dibatalkan itu BUKAN error: layar nggak boleh nampilin pesan gagal.
    if (foto == null) return;

    state = const SedangMembaca();

    final token = await ref.read(tokenStorageProvider).read();

    final hasil = await ref
        .read(dokumenGenerikServiceProvider)
        .baca(foto: foto, namaAlat: namaAlat, token: token);

    state = hasil.berhasil
        ? DokumenTerbaca(hasil.skema!, foto, hasil.bacaanId!)
        : BacaDokumenGagal(
            hasil.gagal ?? GagalBacaDokumen.jaringan,
            hasil.pesan ?? 'Gagal membaca lembar.',
          );
  }

  void ulangDariAwal() => state = const BelumAdaFoto();
}

final bacaDokumenProvider =
    NotifierProvider<PengendaliBacaDokumen, KeadaanBacaDokumen>(
      PengendaliBacaDokumen.new,
    );

/// Nilai yang sedang berlaku per kunci — hasil baca yang sudah dikoreksi
/// teknisi.
///
/// Dipisah dari [bacaDokumenProvider] SUPAYA koreksi nggak hilang waktu
/// keadaannya berubah. Kalau ikut di dalam state, tiap `state = ...` bakal
/// membuang ketikan yang sudah masuk.
class PengendaliKoreksiDokumen extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void ubah(String kunci, String nilai) {
    state = {...state, kunci: nilai};
  }

  void bersihkan() => state = {};
}

final koreksiDokumenProvider =
    NotifierProvider<PengendaliKoreksiDokumen, Map<String, String>>(
      PengendaliKoreksiDokumen.new,
    );
