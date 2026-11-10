import 'package:flutter/material.dart';

/// Daftar bidang yang sedang digambar, dipakai ringkasan sebelum kirim untuk
/// melompat ke bidang yang kurang.
///
/// Yang disimpan `BuildContext`, bukan `GlobalKey`: kode kolom yang sama bisa
/// sesaat digambar dua kali (ganti halaman, tata letak berubah), dan dua
/// `GlobalKey` kembar melempar assertion — sementara di sini yang terakhir
/// terdaftar menang dan yang dilepas hanya mencabut miliknya sendiri.
class PetaLompat {
  final Map<String, BuildContext> _konteks = {};

  /// Konteks bidang [kode] kalau SEDANG digambar (ListView membangun yang
  /// kelihatan saja), selain itu `null`.
  BuildContext? konteks(String kode) {
    final c = _konteks[kode];

    return (c != null && c.mounted) ? c : null;
  }

  void _daftar(String kode, BuildContext c) => _konteks[kode] = c;

  void _cabut(String kode, BuildContext c) {
    if (identical(_konteks[kode], c)) _konteks.remove(kode);
  }
}

/// Memasang [PetaLompat] untuk semua [TandaLompat] di bawahnya.
class ScopeLompat extends InheritedWidget {
  const ScopeLompat({super.key, required this.peta, required super.child});

  final PetaLompat peta;

  static PetaLompat? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ScopeLompat>()?.peta;

  @override
  bool updateShouldNotify(ScopeLompat oldWidget) =>
      !identical(peta, oldWidget.peta);
}

/// Menandai [child] sebagai sasaran lompat [kode]. Tanpa [ScopeLompat] di atas
/// (layar lain yang memakai widget isian yang sama) tidak melakukan apa-apa.
class TandaLompat extends StatefulWidget {
  const TandaLompat({super.key, required this.kode, required this.child});

  final String kode;
  final Widget child;

  @override
  State<TandaLompat> createState() => _TandaLompatState();
}

class _TandaLompatState extends State<TandaLompat> {
  PetaLompat? _peta;
  String? _kode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pasang();
  }

  @override
  void didUpdateWidget(TandaLompat old) {
    super.didUpdateWidget(old);
    _pasang();
  }

  void _pasang() {
    final peta = ScopeLompat.maybeOf(context);
    if (identical(peta, _peta) && widget.kode == _kode) return;

    if (_kode != null) _peta?._cabut(_kode!, context);
    _peta = peta;
    _kode = widget.kode;
    peta?._daftar(widget.kode, context);
  }

  @override
  void dispose() {
    if (_kode != null) _peta?._cabut(_kode!, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
