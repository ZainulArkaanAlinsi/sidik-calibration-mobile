import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/dashboard_summary.dart';
import '../models/izin.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/izin_provider.dart';

/// Ngasih tahu admin waktu ada lembar kerja baru masuk antrean approval.
///
/// Kenapa perlu: teknisi ngirim dari lapangan, admin lagi buka layar lain, dan
/// nggak ada apa pun yang ngasih tahu. Angka di navbar aja nggak cukup — itu
/// cuma kelihatan kalau kebetulan dilirik. Yang bikin admin nengok itu bunyi
/// dan banner.
///
/// Dipasang membungkus isi shell, jadi tanda ini muncul di layar mana pun,
/// bukan cuma waktu kebetulan lagi buka dashboard.
class PemantauAntrean extends ConsumerStatefulWidget {
  const PemantauAntrean({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PemantauAntrean> createState() => _PemantauAntreanState();
}

class _PemantauAntreanState extends ConsumerState<PemantauAntrean>
    with WidgetsBindingObserver {
  /// Jumlah antrean yang terakhir dilihat. Null = belum pernah dapat angka;
  /// angka PERTAMA nggak dibunyiin — itu keadaan waktu app dibuka, bukan
  /// kiriman baru. Tanpa penjaga ini, tiap kali admin buka app dengan antrean
  /// yang memang sudah ada, dia dapat alarm palsu.
  int? _terakhir;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Balik dari background = paling mungkin ada yang kelewat. Penyegaran
    // berkala berhenti waktu app nggak aktif, jadi angkanya pasti basi di sini.
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider.notifier).segarkanDiamDiam();
    }
  }

  void _tandaiKiriman(int selisih) {
    final l10n = AppLocalizations.of(context);

    // `SystemSound`, bukan paket audio: bunyinya ngikut setelan sistem
    // (termasuk mode senyap), nggak nambah dependensi, dan nggak butuh izin
    // apa pun. Di lab yang lagi ramai itu cukup buat bikin orang nengok.
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.antreanMasukBaru(selisih)),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bolehSetujui = ref.bolehkah(
      NamaIzin.kalibrasiSetujui,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    ref.listen<AsyncValue<DashboardSummary>>(dashboardProvider, (lama, baru) {
      final jumlah = baru.value?.menungguApproval;
      if (jumlah == null) return;

      final sebelumnya = _terakhir;
      _terakhir = jumlah;

      // Cuma NAIK yang dibunyiin. Turun berarti admin (atau rekannya) baru
      // nyelesaikan satu — itu kabar baik, bukan sesuatu yang perlu alarm.
      if (!bolehSetujui || sebelumnya == null || jumlah <= sebelumnya) return;

      _tandaiKiriman(jumlah - sebelumnya);
    });

    return widget.child;
  }
}
