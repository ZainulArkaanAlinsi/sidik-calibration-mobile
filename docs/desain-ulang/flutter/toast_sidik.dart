// lib/widgets/biru_awan/toast_sidik.dart — kerangka untuk diselesaikan Claude Code.
// Warna/ukuran WAJIB dari token (PaletBiruAwan, UkuranBiruAwan), bukan angka di sini;
// angka di komentar hanya rujukan dari ELEMEN.md.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

enum JenisToast { sukses, info, peringatan, galat, kabar }

OverlayEntry? _aktif;
Timer? _penghitung;

/// Satu-satunya cara menampilkan toast. Menggantikan showSnackBar.
void tampilkanToast(
  BuildContext context, {
  required JenisToast jenis,
  required String judul,
  String? isi,
  String? aksi,
  VoidCallback? onAksi,
}) {
  _tutup();
  final overlay = Overlay.of(context, rootOverlay: true);
  _aktif = OverlayEntry(
    builder: (_) => _ToastSidik(
      jenis: jenis, judul: judul, isi: isi, aksi: aksi, onAksi: onAksi, onTutup: _tutup,
    ),
  );
  overlay.insert(_aktif!);
  SemanticsService.announce('$judul. ${isi ?? ''}', Directionality.of(context));

  // Galat dan toast beraksi tidak hilang sendiri.
  final lama = switch (jenis) {
    JenisToast.galat => null,
    _ when aksi != null => null,
    JenisToast.peringatan => const Duration(seconds: 6),
    _ => const Duration(seconds: 4),
  };
  if (lama != null) _penghitung = Timer(lama, _tutup);
}

void _tutup() {
  _penghitung?.cancel();
  _aktif?.remove();
  _aktif = null;
}

class _ToastSidik extends StatelessWidget {
  const _ToastSidik({
    required this.jenis, required this.judul, this.isi, this.aksi, this.onAksi, required this.onTutup,
  });

  final JenisToast jenis;
  final String judul;
  final String? isi;
  final String? aksi;
  final VoidCallback? onAksi;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    // TODO(Claude Code): susun sesuai ELEMEN.md §Toast:
    // SafeArea → Align(topCenter) → Padding(16) → ConstrainedBox(maxWidth 420)
    // → Dismissible(direction: up, onDismissed: onTutup)
    // → animasi masuk geser turun + pudar AppMotion.sedang (hormati kurangi gerak)
    // → Material(radius 22, bayangan) → Row[ubin ikon 40, Column[judul, isi], aksi?, tutup].
    // Varian kabar: latar navy + logo di ubin putih.
    throw UnimplementedError();
  }
}
