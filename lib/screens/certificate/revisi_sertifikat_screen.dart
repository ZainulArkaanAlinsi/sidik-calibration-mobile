import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../models/revisi_sertifikat.dart';
import '../../providers/certificate_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;
import 'sertifikat_screen.dart';

/// Formulir revisi sertifikat (admin; kontrak A2).
///
/// Diisi awal dari `data_cetak` — nilai yang TERCETAK, bukan data master yang
/// mungkin sudah berubah. Yang dikirim cuma kunci yang berubah; nilai yang
/// sama dengan cetakan tidak dihitung sebagai perubahan oleh server, jadi
/// mengirimnya hanya membuat 422 "Tidak ada yang berubah" lebih sulit dibaca.
///
/// Sertifikat lama tidak pernah diubah: server menerbitkan baris REVISI baru
/// (`-R1`, dst.) dan sertifikat lama jadi `digantikan`. Sesudah 202 layar ini
/// diganti dengan sertifikat revisi yang baru lahir.
class RevisiSertifikatScreen extends ConsumerStatefulWidget {
  const RevisiSertifikatScreen({super.key, required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  ConsumerState<RevisiSertifikatScreen> createState() =>
      _RevisiSertifikatScreenState();
}

class _RevisiSertifikatScreenState
    extends ConsumerState<RevisiSertifikatScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _teks = {};
  late final Map<String, String> _awal;
  late final Map<String, DateTime?> _tanggal;
  late final TextEditingController _alasan;
  late final TextEditingController _catatan;

  bool _sibuk = false;

  /// Galat klien & server dipegang satu tempat, per kunci isian. Kuncinya kunci
  /// data cetak, `alasan`, atau `catatan_pelanggan`.
  Map<String, String> _galat = {};

  /// Pesan di atas formulir: galat keadaan (`{message}` tanpa `errors`) atau
  /// "tidak ada yang berubah".
  String? _banner;

  @override
  void initState() {
    super.initState();
    final cetak = widget.sertifikat.dataCetak;
    _awal = {for (final k in KunciDataCetak.semua) k: cetak?[k] ?? ''};
    _tanggal = {
      for (final k in KunciDataCetak.tanggal) k: DateTime.tryParse(_awal[k]!),
    };
    for (final k in KunciDataCetak.semua) {
      if (!KunciDataCetak.tanggal.contains(k)) {
        _teks[k] = TextEditingController(text: _awal[k]);
      }
    }
    _alasan = TextEditingController();
    _catatan = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in _teks.values) {
      c.dispose();
    }
    _alasan.dispose();
    _catatan.dispose();
    super.dispose();
  }

  static String _tgl(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// Nilai sekarang per kunci (tanggal dalam `YYYY-MM-DD`).
  String _nilai(String k) {
    if (KunciDataCetak.tanggal.contains(k)) {
      final t = _tanggal[k];
      return t == null ? '' : _tgl(t);
    }
    return _teks[k]!.text.trim();
  }

  /// Hanya kunci yang berubah dari yang tercetak.
  Map<String, String> get _perubahan => {
    for (final k in KunciDataCetak.semua)
      if (_nilai(k) != _awal[k]!.trim()) k: _nilai(k),
  };

  String _label(AppLocalizations l10n, String k) => switch (k) {
    KunciDataCetak.pemilik => l10n.revisiFieldPemilik,
    KunciDataCetak.alamat => l10n.revisiFieldAlamat,
    KunciDataCetak.merk => l10n.revisiFieldMerk,
    KunciDataCetak.tipe => l10n.revisiFieldTipe,
    KunciDataCetak.nomorSeri => l10n.revisiFieldNomorSeri,
    KunciDataCetak.lokasiKalibrasi => l10n.revisiFieldLokasi,
    KunciDataCetak.tanggalKalibrasi => l10n.revisiFieldTanggalKalibrasi,
    _ => l10n.revisiFieldBerlakuSampai,
  };

  Future<void> _pilihTanggal(String k) async {
    final awal = _tanggal[k] ?? DateTime.now();
    final pilih = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pilih == null) return;
    setState(() {
      _tanggal[k] = pilih;
      _galat = {..._galat}..remove(k);
    });
  }

  /// Aturan klien yang sama dengan server — supaya galatnya muncul sebelum
  /// perjalanan ke server, bukan sesudahnya.
  bool _validasiKlien(AppLocalizations l10n) {
    final galat = <String, String>{};
    String? banner;

    if (_alasan.text.trim().isEmpty) {
      galat['alasan'] = l10n.revisiAlasanWajib;
    }

    final berubah = _perubahan;
    if (berubah.isEmpty) banner = l10n.revisiTidakAdaPerubahan;

    // Isian teks yang tadinya terisi tidak boleh dikosongkan.
    for (final k in KunciDataCetak.semua) {
      if (KunciDataCetak.tanggal.contains(k)) continue;
      if (_nilai(k).isEmpty && _awal[k]!.trim().isNotEmpty) {
        galat[k] = l10n.revisiIsianWajib;
      }
    }

    // berlaku_sampai harus sesudah tanggal_kalibrasi (yang baru, atau yang lama
    // kalau tidak diubah).
    final tk = _tanggal[KunciDataCetak.tanggalKalibrasi];
    final bs = _tanggal[KunciDataCetak.berlakuSampai];
    if (tk != null && bs != null && !bs.isAfter(tk)) {
      galat[KunciDataCetak.berlakuSampai] = l10n.revisiBerlakuSesudah;
    }

    setState(() {
      _galat = galat;
      _banner = banner;
    });
    return galat.isEmpty && banner == null;
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_sibuk || !_validasiKlien(l10n)) return;

    setState(() => _sibuk = true);
    try {
      final hasil = await ref
          .read(sertifikatAksiProvider)
          .revisi(
            widget.sertifikat.id,
            perubahan: _perubahan,
            alasan: _alasan.text,
            catatanPelanggan: _catatan.text,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.revisiTerkirim(hasil.nomor))),
      );
      // Ganti formulir dengan sertifikat revisi yang baru lahir (masih
      // `menunggu_generate`; sinyal realtime / tarik-ulang mengisinya).
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SertifikatScreen(certificateId: hasil.id),
        ),
      );
    } on GalatAksi catch (e) {
      if (!mounted) return;
      final galat = <String, String>{};
      for (final k in KunciDataCetak.semua) {
        final p = e.untuk('perubahan.$k');
        if (p != null) galat[k] = p;
      }
      final a = e.untuk('alasan');
      if (a != null) galat['alasan'] = a;
      final c = e.untuk('catatan_pelanggan');
      if (c != null) galat['catatan_pelanggan'] = c;
      setState(() {
        _galat = galat;
        // Galat keadaan membawa `{message}` tanpa `errors`: tampilkan di atas.
        // Galat isian sudah tertulis di bawah kolomnya.
        _banner = galat.isEmpty ? e.pesan : l10n.revisiPeriksaIsian;
        _sibuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sibuk = false);
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.revisiJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      widget.sertifikat.nomor,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(l10n.revisiPetunjuk, style: theme.textTheme.bodySmall),
                    if (_banner != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        key: const ValueKey('banner-revisi'),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: m.gagalTipis,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 18, color: m.gagal),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _banner!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: m.gagal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Kertas(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final k in KunciDataCetak.semua) ...[
                            if (KunciDataCetak.tanggal.contains(k))
                              _IsianTanggal(
                                key: ValueKey('isian-revisi-$k'),
                                label: _label(l10n, k),
                                nilai: _tanggal[k],
                                galat: _galat[k],
                                onTap: () => _pilihTanggal(k),
                              )
                            else
                              TextField(
                                key: ValueKey('isian-revisi-$k'),
                                controller: _teks[k],
                                minLines: 1,
                                maxLines: k == KunciDataCetak.alamat ? 3 : 1,
                                onChanged: (_) {
                                  if (_galat.containsKey(k)) {
                                    setState(
                                      () => _galat = {..._galat}..remove(k),
                                    );
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: _label(l10n, k),
                                  errorText: _galat[k],
                                  errorMaxLines: 3,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Kertas(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            key: const ValueKey('isian-revisi-alasan'),
                            controller: _alasan,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) {
                              if (_galat.containsKey('alasan')) {
                                setState(
                                  () => _galat = {..._galat}..remove('alasan'),
                                );
                              }
                            },
                            decoration: InputDecoration(
                              labelText: l10n.revisiAlasan,
                              helperText: l10n.revisiAlasanHelper,
                              helperMaxLines: 2,
                              errorText: _galat['alasan'],
                              errorMaxLines: 3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            key: const ValueKey('isian-revisi-catatan'),
                            controller: _catatan,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: l10n.revisiCatatan,
                              helperText: l10n.revisiCatatanHelper,
                              helperMaxLines: 2,
                              errorText: _galat['catatan_pelanggan'],
                              errorMaxLines: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: m.kertas,
                  border: Border(top: BorderSide(color: m.garis)),
                ),
                child: SidikTombol(
                  key: const ValueKey('kirim-revisi-sertifikat'),
                  label: l10n.revisiKirim,
                  ikon: Icons.edit_document,
                  ragam: RagamTombol.utama,
                  penuh: true,
                  sibuk: _sibuk,
                  onPressed: _sibuk ? null : _kirim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isian tanggal yang dibuka lewat pemilih tanggal. Bukan `TextField`: nilai
/// tanggal tidak boleh diketik bebas (formatnya `YYYY-MM-DD` di server).
class _IsianTanggal extends StatelessWidget {
  const _IsianTanggal({
    super.key,
    required this.label,
    required this.nilai,
    required this.galat,
    required this.onTap,
  });

  final String label;
  final DateTime? nilai;
  final String? galat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: galat,
          errorMaxLines: 3,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          nilai == null ? '—' : tanggalPendek(context, nilai),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
