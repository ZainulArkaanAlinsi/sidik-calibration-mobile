import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sumber "sekarang" buat layar — supaya waktu bisa dipatok di test.
///
/// ## Kenapa ada
///
/// Golden lembar kerja nyimpen tanggal kalibrasi bawaan (`DateTime.now()`) ke
/// dalam gambarnya. Akibatnya golden-nya **merah tiap ganti hari**, tanpa ada
/// yang rusak: 9 Agt 2026 hijau, 10 Agt 2026 merah, dan yang berubah cuma satu
/// baris teks tanggal. Tes yang merahnya nggak ada hubungannya sama perubahan
/// kode itu lama-lama diabaikan orang — termasuk waktu dia beneran nangkep bug.
///
/// ## Kenapa provider, bukan parameter di widget
///
/// Nambah `tanggalAwal` ke `LembarKerjaScreen` cuma buat test itu API produksi
/// yang nggak dipakai produksi. Provider dioverride dari luar tanpa nambah
/// permukaan widget-nya sama sekali:
///
/// ```dart
/// ProviderScope(
///   overrides: [jamProvider.overrideWithValue(() => DateTime(2026, 8, 9))],
///   child: ...,
/// )
/// ```
///
/// Yang disimpen fungsinya, bukan `DateTime`-nya: `DateTime` bakal beku di
/// nilai waktu provider pertama dibaca, dan buat app yang kebuka berjam-jam di
/// lapangan itu salah — tanggalnya nggak ikut ganti waktu lewat tengah malam.
final jamProvider = Provider<DateTime Function()>((ref) => DateTime.now);
