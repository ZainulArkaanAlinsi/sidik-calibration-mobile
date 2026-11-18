import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/catatan_identifikasi_lembar.dart';

/// Catatan lokal identifikasi lembar (kalibrasi ambang nanti). Lewat provider
/// supaya tes memakai penampung memori, bukan folder HP. Isi dan batas
/// privasinya di `catatan_identifikasi_lembar.dart`.
final catatanIdentifikasiLembarProvider = Provider<CatatanIdentifikasiLembar>(
  (ref) => CatatanIdentifikasiBerkas(),
);
