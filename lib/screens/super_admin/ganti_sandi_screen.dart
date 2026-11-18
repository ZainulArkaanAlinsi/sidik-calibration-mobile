import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/ganti_sandi_provider.dart';
import '../../services/auth_service.dart' show ApiException, AuthException;
import '../../services/ganti_sandi_service.dart' show HasilGantiSandi;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import 'widgets/kolom_berlabel.dart';

/// Ganti sandi SENDIRI (`POST /api/me/ganti-sandi`).
///
/// ## Yang sengaja begitu
///
/// - **Layar tidak menilai sandi.** Panjang minimal, "pernah bocor", dan "sama
///   dengan yang lama" ditentukan server (422). Yang dicek di sini hanya yang
///   murni kenyamanan: kolom kosong dan konfirmasi yang tidak sama.
/// - **Tidak logout sesudahnya.** Server mempertahankan token yang sedang
///   dipakai; perangkat LAIN yang dikeluarkan.
/// - **Sandi tidak bertahan.** Ketiga kolom dikosongkan begitu permintaan
///   selesai, sukses maupun gagal; tidak ada `print`/log/state provider yang
///   memegangnya.
/// - **Bercabang pada `kode`, bukan isi `message`:** `sandi_lama_salah`.
class GantiSandiScreen extends ConsumerStatefulWidget {
  const GantiSandiScreen({super.key});

  @override
  ConsumerState<GantiSandiScreen> createState() => _GantiSandiScreenState();
}

class _GantiSandiScreenState extends ConsumerState<GantiSandiScreen> {
  /// Jeda tombol sesudah 429 (maks 5 percobaan per menit per akun).
  static const _jedaBatasPercobaan = Duration(seconds: 15);

  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();

  /// Kunci: `lama` / `baru` / `ulang`.
  Map<String, String> _galat = {};
  String? _galatUmum;
  HasilGantiSandi? _berhasil;
  bool _mengirim = false;
  bool _ditahan = false;
  Timer? _penahan;

  @override
  void dispose() {
    _penahan?.cancel();
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  void _kosongkan() {
    _lama.clear();
    _baru.clear();
    _ulang.clear();
  }

  bool _valid() {
    final l10n = AppLocalizations.of(context);
    // Sandi TIDAK di-trim: spasi di tepi bisa disengaja.
    final galat = <String, String>{
      if (_lama.text.isEmpty) 'lama': l10n.saGantiLamaKosong,
      if (_baru.text.isEmpty)
        'baru': l10n.saGantiBaruKosong
      else if (_baru.text != _ulang.text)
        'ulang': l10n.saGantiBeda,
    };

    setState(() {
      _galat = galat;
      _galatUmum = null;
      _berhasil = null;
    });
    return galat.isEmpty;
  }

  /// `422`: `kode: sandi_lama_salah` → kolom sandi lama; `errors.sandi_lama[0]`
  /// → sandi lama; `errors.sandi[0]` → sandi baru (konfirmasi yang tidak cocok
  /// pun dikunci `sandi` oleh server). Pesan server ditampilkan apa adanya.
  void _petakan422(ApiException e) {
    final dipetakan = <String, String>{};

    if (e.body['kode'] == 'sandi_lama_salah') {
      dipetakan['lama'] = e.message;
    }

    final errors = e.body['errors'];
    if (errors is Map) {
      String? pertama(Object? v) {
        if (v is List && v.isNotEmpty) return '${v.first}';
        if (v is String && v.isNotEmpty) return v;
        return null;
      }

      final lama = pertama(errors['sandi_lama']);
      final baru = pertama(errors['sandi']);
      if (lama != null) dipetakan['lama'] = lama;
      if (baru != null) dipetakan['baru'] = baru;
    }

    setState(() {
      _galat = dipetakan;
      // `message` Laravel memuat "(and 1 more error)"; hanya dipakai bila tidak
      // ada satu pun kolom yang bisa dipetakan.
      _galatUmum = dipetakan.isEmpty ? e.message : null;
    });
  }

  void _tahanSebentar() {
    _penahan?.cancel();
    setState(() => _ditahan = true);
    _penahan = Timer(_jedaBatasPercobaan, () {
      if (mounted) setState(() => _ditahan = false);
    });
  }

  Future<void> _kirim() async {
    if (_mengirim || _ditahan || !_valid()) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _mengirim = true;
      _galatUmum = null;
    });

    // Disalin ke variabel lokal sebelum dikosongkan; hidupnya hanya selama
    // satu permintaan ini.
    final lama = _lama.text;
    final baru = _baru.text;
    final ulang = _ulang.text;

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      final hasil = await ref
          .read(gantiSandiServiceProvider)
          .ganti(token, sandiLama: lama, sandiBaru: baru, konfirmasi: ulang);

      if (!mounted) return;
      setState(() {
        _galat = {};
        _berhasil = hasil;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 422) {
        _petakan422(e);
      } else {
        setState(() => _galatUmum = e.message);
        if (e.status == 429) _tahanSebentar();
      }
    } on TokenHilangException {
      if (!mounted) return;
      setState(() => _galatUmum = l10n.historySessionExpired);
    } on AuthException catch (e) {
      // Koneksi putus dkk.: pesannya sudah dirancang untuk dibaca pengguna.
      if (!mounted) return;
      setState(() => _galatUmum = e.message);
    } catch (_) {
      // Jenis galatnya TIDAK ikut ditulis: tidak ada yang perlu bocor dari
      // jalur yang memegang sandi.
      if (!mounted) return;
      setState(() => _galatUmum = l10n.saGantiGagal);
    } finally {
      // Kalau layarnya sudah ditutup, controller-nya ikut dibuang bersama
      // `dispose()`; tidak ada sandi yang tersisa untuk dikosongkan.
      if (mounted) {
        _kosongkan();
        setState(() => _mengirim = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saGantiJudul)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          maksimum: 560,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_berhasil case final hasil?) ...[
                _KartuBerhasil(
                  pesan: l10n.saGantiBerhasil,
                  tambahan: hasil.sesiDicabut > 0
                      ? l10n.saGantiSesiLain(hasil.sesiDicabut)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                l10n.saGantiIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              KolomBerlabel(
                key: const Key('ganti-lama'),
                label: l10n.saGantiLama,
                controller: _lama,
                isPassword: true,
                enabled: !_mengirim,
                errorText: _galat['lama'],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              KolomBerlabel(
                key: const Key('ganti-baru'),
                label: l10n.saGantiBaru,
                controller: _baru,
                isPassword: true,
                enabled: !_mengirim,
                errorText: _galat['baru'],
                helperText: l10n.saGantiHelper,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              KolomBerlabel(
                key: const Key('ganti-ulang'),
                label: l10n.saGantiUlang,
                controller: _ulang,
                isPassword: true,
                enabled: !_mengirim,
                errorText: _galat['ulang'],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _kirim(),
              ),
              if (_galatUmum case final pesan?) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    pesan,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.saGantiSimpan,
                icon: Icons.lock_reset,
                isLoading: _mengirim,
                onPressed: (_mengirim || _ditahan) ? null : _kirim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuBerhasil extends StatelessWidget {
  const _KartuBerhasil({required this.pesan, this.tambahan});

  final String pesan;
  final String? tambahan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pesan, style: theme.textTheme.bodyMedium),
                    if (tambahan != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tambahan!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
