import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/pindah_alat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/riwayat_alat_provider.dart';
import '../../providers/super_admin_provider.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import 'hak_super_admin.dart';
import 'widgets/pesan_galat_sa.dart';
import 'widgets/pesan_layar.dart';

/// Pindahkan alat, langkah 2 dan 3: PRATINJAU (`dry_run`, tidak menulis apa
/// pun) lalu KONFIRMASI dengan alasan wajib; sesudahnya keadaan sukses.
///
/// Angka di sini dari server, bukan dihitung layar: jumlah alat, sertifikat
/// terdampak, siapa mulai dan berhenti melihat. Alasan diketik orang yang
/// menekan dan masuk jejak audit apa adanya (tidak diisi otomatis). Eksekusi
/// TIDAK diulang otomatis; `alat_sudah_pindah` (409) berarti pratinjau basi
/// dan harus diulang.
class PratinjauPindahAlatScreen extends ConsumerStatefulWidget {
  const PratinjauPindahAlatScreen({
    super.key,
    required this.asal,
    required this.tujuan,
    required this.alatIds,
  });

  final Customer asal;
  final Customer tujuan;
  final List<int> alatIds;

  @override
  ConsumerState<PratinjauPindahAlatScreen> createState() =>
      _PratinjauPindahAlatScreenState();
}

class _PratinjauPindahAlatScreenState
    extends ConsumerState<PratinjauPindahAlatScreen> {
  final _alasan = TextEditingController();

  PratinjauPindahAlat? _pratinjau;
  HasilPindahAlat? _hasil;
  Object? _galatPratinjau;
  bool _memuat = true;
  bool _memindah = false;
  String? _galatAlasan;
  String? _galatUmum;
  bool _basi = false;

  @override
  void initState() {
    super.initState();
    _muatPratinjau();
  }

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  Future<void> _muatPratinjau() async {
    setState(() {
      _memuat = true;
      _galatPratinjau = null;
      _galatUmum = null;
      _basi = false;
    });
    try {
      final hasil = await ref
          .read(anggotaPelangganServiceProvider)
          .pratinjauPindahAlat(
            await _token(),
            widget.asal.id,
            alatIds: widget.alatIds,
            keCustomerId: widget.tujuan.id,
          );
      if (!mounted) return;
      setState(() {
        _pratinjau = hasil;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galatPratinjau = e;
        _memuat = false;
      });
    }
  }

  Future<void> _pindahkan() async {
    final l10n = AppLocalizations.of(context);
    final p = _pratinjau;
    if (_memindah || p == null) return;

    final alasan = _alasan.text.trim();
    if (alasan.length < 3) {
      setState(() => _galatAlasan = l10n.saAlasanPendek);
      return;
    }
    if (alasan.length > 500) {
      setState(() => _galatAlasan = l10n.saAlasanPanjang);
      return;
    }
    setState(() => _galatAlasan = null);

    final yakin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.saPindahKonfirmJudul(p.jumlahAlat, p.ke.nama),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Text(l10n.saPindahKonfirmIsi(p.sertifikatTerdampak)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.saBatal),
          ),
          TextButton(
            key: const Key('konfirmasi-pindah'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.saPindahAksi),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() {
      _memindah = true;
      _galatUmum = null;
    });
    try {
      final hasil = await ref
          .read(anggotaPelangganServiceProvider)
          .pindahkanAlat(
            await _token(),
            widget.asal.id,
            alatIds: widget.alatIds,
            keCustomerId: widget.tujuan.id,
            alasan: alasan,
          );
      if (!mounted) return;
      // Daftar alat PT asal & hitungan di detail sudah basi.
      ref.invalidate(alatPelangganProvider(widget.asal.id));
      ref.invalidate(pelangganDetailSaProvider(widget.asal.id));
      ref.invalidate(pelangganDetailSaProvider(widget.tujuan.id));
      setState(() {
        _hasil = hasil;
        _memindah = false;
        // Alasan tidak perlu tertahan sesudah tercatat.
        _alasan.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final dikolom = e is ApiException && e.status == 422
          ? pesanKolomServer(e, 'alasan')
          : null;
      setState(() {
        _memindah = false;
        _galatAlasan = dikolom;
        _galatUmum = dikolom == null ? pesanGalatSa(l10n, e) : null;
        // Pratinjau basi: alat berpindah/di luar PT asal di antara pratinjau
        // dan eksekusi. Pemakai harus melihat keadaan terbaru dulu.
        _basi = e is ApiException && perluMuatUlang(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!ref.bolehPindahAlat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.saPratinjauJudul)),
        body: PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin),
      );
    }

    final Widget isi;
    if (_hasil != null) {
      isi = _Sukses(
        hasil: _hasil!,
        saatSelesai: () => Navigator.of(context).pop(true),
      );
    } else if (_memuat) {
      isi = const _KerangkaPratinjau();
    } else if (_galatPratinjau != null) {
      isi = PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: _galatPratinjau is TokenHilangException
            ? l10n.historySessionExpired
            : _pesanPratinjau(l10n, _galatPratinjau!),
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: _muatPratinjau,
        ),
      );
    } else {
      isi = _IsiPratinjau(
        p: _pratinjau!,
        alasan: _alasan,
        galatAlasan: _galatAlasan,
        galatUmum: _galatUmum,
        basi: _basi,
        memindah: _memindah,
        saatPindah: _pindahkan,
        saatUlang: _muatPratinjau,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hasil != null ? l10n.saPindahSelesai : l10n.saPratinjauJudul,
        ),
        // Sesudah sukses hanya "Selesai" yang menutup layar (hasilnya dikirim
        // ke layar sebelumnya); tombol kembali tidak membawa hasil.
        automaticallyImplyLeading: _hasil == null,
      ),
      body: SafeArea(
        top: false,
        child: ReadableWidth(maksimum: 720, child: isi),
      ),
    );
  }

  String _pesanPratinjau(AppLocalizations l10n, Object galat) {
    final pesan = pesanGalatSa(l10n, galat);
    return pesan == l10n.saGalatUmum ? l10n.saPratinjauGagal : pesan;
  }
}

class _IsiPratinjau extends StatelessWidget {
  const _IsiPratinjau({
    required this.p,
    required this.alasan,
    required this.galatAlasan,
    required this.galatUmum,
    required this.basi,
    required this.memindah,
    required this.saatPindah,
    required this.saatUlang,
  });

  final PratinjauPindahAlat p;
  final TextEditingController alasan;
  final String? galatAlasan;
  final String? galatUmum;
  final bool basi;
  final bool memindah;
  final VoidCallback saatPindah;
  final VoidCallback saatUlang;

  /// Kalimat lokal untuk kode peringatan yang stabil; kode baru dari server
  /// tampil dengan `pesan`-nya.
  String _peringatan(AppLocalizations l10n, PeringatanPindah w) =>
      switch (w.kode) {
        'paket_tidak_dipindah' => l10n.saPeringatanPaket,
        'arsip_tidak_dipindah' => l10n.saPeringatanArsip,
        'isi_sertifikat_tetap' => l10n.saPeringatanIsi,
        _ => w.pesan,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    Widget orang(OrangTerdampak o) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        o.email.isEmpty ? o.nama : '${o.nama} · ${o.email}',
        style: tema.textTheme.bodyMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    Widget daftarOrang(String judul, List<OrangTerdampak> daftar, Key kunci) =>
        Column(
          key: kunci,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: tema.textTheme.labelLarge),
            if (daftar.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l10n.saPratinjauTidakAda, style: redup),
              )
            else
              for (final o in daftar) orang(o),
          ],
        );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.saPratinjauDari, style: redup),
                Text(
                  p.dari.nama,
                  key: const Key('pratinjau-dari'),
                  style: tema.textTheme.titleSmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.saPratinjauAnggotaPt(p.dari.anggotaAktifCount),
                  style: redup,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.saPratinjauKe, style: redup),
                Text(
                  p.ke.nama,
                  key: const Key('pratinjau-ke'),
                  style: tema.textTheme.titleSmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.saPratinjauAnggotaPt(p.ke.anggotaAktifCount),
                  style: redup,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.saPratinjauAlat(p.jumlahAlat),
                  key: const Key('pratinjau-alat'),
                  style: tema.textTheme.titleSmall,
                ),
                for (final a in p.alat)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        a.nama.isEmpty ? '-' : a.nama,
                        if (a.nomorSeri.isNotEmpty) a.nomorSeri,
                      ].join(' · '),
                      style: tema.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.saPratinjauSertTerdampak(p.sertifikatTerdampak),
                  key: const Key('pratinjau-sertifikat'),
                  style: tema.textTheme.titleSmall,
                ),
                Text(
                  l10n.saPratinjauSertTerlihat(p.sertifikatTerlihatPelanggan),
                  key: const Key('pratinjau-terlihat'),
                  style: redup,
                ),
                if (p.paketTerkaitCount > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.saPratinjauPaket(p.paketTerkaitCount),
                    key: const Key('pratinjau-paket'),
                    style: redup,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                daftarOrang(
                  l10n.saPratinjauMulai,
                  p.anggotaMulaiMelihat,
                  const Key('pratinjau-mulai'),
                ),
                const SizedBox(height: AppSpacing.sm),
                daftarOrang(
                  l10n.saPratinjauBerhenti,
                  p.anggotaBerhentiMelihat,
                  const Key('pratinjau-berhenti'),
                ),
              ],
            ),
          ),
        ),
        if (p.peringatan.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final w in p.peringatan)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _peringatan(l10n, w),
                      key: Key('peringatan-${w.kode}'),
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          label: l10n.saAlasanWajib,
          child: TextField(
            key: const Key('alasan-pindah'),
            controller: alasan,
            enabled: !memindah,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            inputFormatters: [LengthLimitingTextInputFormatter(550)],
            decoration: InputDecoration(
              labelText: l10n.saAlasanWajib,
              helperText: l10n.saAlasanCatatan,
              helperMaxLines: 3,
              errorText: galatAlasan,
              errorMaxLines: 3,
              alignLabelWithHint: true,
            ),
          ),
        ),
        if (galatUmum != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              galatUmum!,
              key: const Key('galat-pindah'),
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (basi)
          AppButton(
            key: const Key('ulangi-pratinjau'),
            label: l10n.saPratinjauUlang,
            icon: Icons.refresh,
            onPressed: saatUlang,
          )
        else
          AppButton(
            key: const Key('pindahkan'),
            label: l10n.saPindahEksekusi(p.jumlahAlat),
            icon: Icons.drive_file_move_outline,
            isLoading: memindah,
            onPressed: memindah ? null : saatPindah,
          ),
      ],
    );
  }
}

class _Sukses extends StatelessWidget {
  const _Sukses({required this.hasil, required this.saatSelesai});

  final HasilPindahAlat hasil;
  final VoidCallback saatSelesai;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Semantics(
          liveRegion: true,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saPindahBerhasil(
                            hasil.jumlahAlat,
                            hasil.ke.nama,
                          ),
                          key: const Key('pindah-berhasil'),
                          style: tema.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.saPindahBerhasilIsi(
                            hasil.sertifikatTerdampak,
                            hasil.sertifikatTerlihatPelanggan,
                          ),
                          style: tema.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('selesai-pindah'),
          label: l10n.saPindahSelesai,
          icon: Icons.check,
          onPressed: saatSelesai,
        ),
      ],
    );
  }
}

class _KerangkaPratinjau extends StatelessWidget {
  const _KerangkaPratinjau();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12, width: 60),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 16, width: 200),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(height: 12, width: 60),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 16, width: 180),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 16, width: 140),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 12, width: 220),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 12, width: 180),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
