import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../services/kabar_server_lambat.dart';

/// "Server sedang dinyalakan, mohon tunggu…" — muncul hanya kalau widget ini
/// sudah tergambar lebih lama dari [setelah].
///
/// Digambar pemanggil SELAMA menunggu server; begitu jawabannya datang,
/// pemanggil berhenti menggambarnya dan jamnya ikut dibatalkan. Jawaban cepat
/// tidak pernah memunculkan apa-apa.
class KabarServerLambat extends StatefulWidget {
  const KabarServerLambat({super.key, this.setelah = ambangKabarServerLambat});

  final Duration setelah;

  @override
  State<KabarServerLambat> createState() => _KabarServerLambatState();
}

class _KabarServerLambatState extends State<KabarServerLambat> {
  Timer? _jam;
  bool _tampil = false;

  @override
  void initState() {
    super.initState();
    _jam = Timer(widget.setelah, () {
      if (mounted) setState(() => _tampil = true);
    });
  }

  @override
  void dispose() {
    _jam?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_tampil) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('kabar-server-lambat'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppLocalizations.of(context).lkServerSedangDinyalakan,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
