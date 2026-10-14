import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';

import '../inti/sesi_studio.dart';
import '../l10n/studio_l10n.dart';
import '../tema/tema_studio.dart';
import '../tema/warna_studio.dart';

/// Pasang dialog "Sesi berakhir, masuk lagi" di atas layar yang sedang
/// terbuka (FR-STU-004, ST-90 "Sesi kedaluwarsa").
///
/// Navigator AKAR: dialog menutup seluruh cangkang, termasuk navigasi — bukan
/// cuma panel seksi. Layar di bawahnya tidak dibongkar, jadi isian & posisi
/// tetap di tempatnya sesudah masuk ulang.
Future<void> tampilkanDialogSesiBerakhir(BuildContext context) =>
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const DialogSesiBerakhir(),
    );

class DialogSesiBerakhir extends ConsumerStatefulWidget {
  const DialogSesiBerakhir({super.key});

  @override
  ConsumerState<DialogSesiBerakhir> createState() => _DialogSesiBerakhirState();
}

class _DialogSesiBerakhirState extends ConsumerState<DialogSesiBerakhir> {
  final _sandi = TextEditingController();
  String? _galat;
  bool _memuat = false;
  bool _sandiTerlihat = false;

  @override
  void dispose() {
    _sandi.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    final l10n = StudioL10n.of(context);
    if (_sandi.text.isEmpty) {
      setState(() => _galat = l10n.isianSandiWajib);
      return;
    }

    final wadah = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    setState(() {
      _memuat = true;
      _galat = null;
    });

    try {
      await masukUlangStudio(wadah, sandi: _sandi.text);
      navigator.pop();
      return;
    } on AkunBerbedaException {
      _galat = l10n.sesiAkunBerbeda;
    } on AuthException catch (e) {
      // Pesan server apa adanya: sandi salah, akun dinonaktifkan, 429.
      _galat = e.message;
    } catch (e) {
      _galat = l10n.gagalDiPerangkat('$e');
    }

    if (mounted) setState(() => _memuat = false);
  }

  /// Ganti akun / berhenti: tutup dialog DULU (ia hidup di navigator akar dan
  /// akan tertinggal di atas layar masuk), baru keluar.
  Future<void> _keluar() async {
    final wadah = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop();
    await keluarStudio(wadah);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final akun = ref.watch(authProvider).value;
    final identitas = akun == null
        ? ''
        : (akun.employeeId.isNotEmpty ? akun.employeeId : akun.email);

    // Esc / tombol kembali TIDAK menutup: di balik dialog ini server menolak
    // semua permintaan; menutupnya cuma memindahkan galat ke tiap layar.
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(Icons.lock_clock_outlined, color: w.teks2),
        title: Text(l10n.sesiBerakhirJudul),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.sesiBerakhirKet(akun?.nama ?? '', identitas),
                  style: teks.bodyMedium?.copyWith(color: w.teks2),
                ),
                const SizedBox(height: UkuranStudio.j4),
                TextField(
                  controller: _sandi,
                  autofocus: true,
                  enabled: !_memuat,
                  obscureText: !_sandiTerlihat,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _masuk(),
                  decoration: InputDecoration(
                    labelText: l10n.isianSandi,
                    errorText: _galat,
                    errorMaxLines: 3,
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      tooltip: _sandiTerlihat
                          ? l10n.sembunyikanSandi
                          : l10n.tampilkanSandi,
                      icon: Icon(
                        _sandiTerlihat
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _sandiTerlihat = !_sandiTerlihat),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _memuat ? null : _keluar,
            child: Text(l10n.sesiBerakhirKeluar),
          ),
          FilledButton(
            onPressed: _memuat ? null : _masuk,
            child: _memuat
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.memuat,
                    ),
                  )
                : Text(l10n.tombolMasuk),
          ),
        ],
      ),
    );
  }
}
