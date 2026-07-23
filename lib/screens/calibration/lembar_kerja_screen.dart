import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../models/lembar_kerja.dart';
import '../../models/room.dart';
import '../../models/standard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart';
import '../../providers/lembar_kerja_provider.dart';
import '../../widgets/app_button.dart';
import 'lembar_kerja_state.dart';
import 'widgets/lembar_kerja_tabel.dart';

/// Lembar Kerja pH Meter (SIDIK-FM-CAL-0509_Rev.4) — layar input teknisi.
///
/// **Kolomnya digambar dari `GET /api/calibrations/lembar-kerja`, bukan
/// di-hardcode.** Backend yang punya definisi formulirnya, dan responsnya udah
/// disaring per-role: waktu yang login teknisi, kolom administratif (Order
/// Number, Calibration Methode, Thermohygro used) nggak ikut terkirim sama
/// sekali — jadi layar ini nggak mungkin nampilin kolom yang bukan haknya,
/// bahkan kalau ada bug di sisi tampilan.
///
/// **Tombol kirim nggak pernah dikunci.** Satu-satunya yang ditahan itu alat
/// belum dipilih — tanpa itu nggak ada yang bisa dikirim sama sekali. Sisanya
/// boleh kosong: teknisi di lapangan sering ketemu kondisi yang bikin satu-dua
/// kolom nggak bisa diisi, dan nahan tombol di situ bikin data hilang
/// seluruhnya. Penjagaannya ada di pemeriksaan admin sebelum sertifikat
/// terbit, bukan di formulir ini.
///
/// **Nggak ada satu pun rumus di sini.** Average, Correction, STDEV, U95% —
/// semua dihitung backend. Ikut ngitung di layar cepat atau lambat bikin
/// angkanya beda dari sertifikat.
class LembarKerjaScreen extends ConsumerWidget {
  const LembarKerjaScreen({super.key, this.sesiId, this.judulTambahan});

  /// Keisi = lanjut draft / perbaiki sesi yang dikembalikan admin (`PUT`).
  /// Null = sesi baru (`POST`).
  final int? sesiId;

  final String? judulTambahan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bentukAsync = ref.watch(lembarKerjaProvider);

    return Scaffold(
      appBar: AppBar(
        // Tombol back-nya bawaan AppBar — tiap halaman wajib punya
        // (spesifikasi poin 5).
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.lkTitle),
            if (judulTambahan != null)
              Text(
                judulTambahan!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
      body: switch (bentukAsync) {
        AsyncData(:final value) => _Form(bentuk: value, sesiId: sesiId),
        AsyncError() => _Gagal(
          onCobaLagi: () => ref.invalidate(lembarKerjaProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.lkLoadGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.lkRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.bentuk, this.sesiId});

  final LembarKerja bentuk;
  final int? sesiId;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final LembarKerjaState _isian = LembarKerjaState(
    bentuk: widget.bentuk,
    // Dibikin SEKALI waktu layar kebuka, bukan tiap tap tombol: kalau sinyal
    // putus pas nunggu respons dan teknisi nekan kirim lagi, backend ngenalin
    // ini submission yang sama dan balikin sesi yang udah ada — bukan bikin
    // sesi dobel buat satu kejadian kalibrasi.
    clientRequestId: generateUuidV4(),
  );

  bool _mengirim = false;

  @override
  void dispose() {
    _isian.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool draft}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Satu-satunya yang ditahan: alat belum dipilih. Tanpa itu nggak ada yang
    // bisa dikirim sama sekali — bukan "kolom wajib", tapi identitas barangnya.
    if (_isian.alat == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.lkBelumPilihAlat)));
      return;
    }

    setState(() => _mengirim = true);

    final hasil = await ref
        .read(kirimLembarKerjaProvider.notifier)
        .kirim(_isian.toSubmission(draft: draft), sesiId: widget.sesiId);

    if (!mounted) return;
    setState(() => _mengirim = false);

    if (hasil == null) {
      final error = ref.read(kirimLembarKerjaProvider).error;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.lkGagalKirim('$error'))),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(hasil.draft ? l10n.lkBerhasilDraft : l10n.lkBerhasilKirim),
      ),
    );
    navigator.pop(hasil.id);
  }

  Future<bool> _bolehKeluar() async {
    if (!_isian.adaIsian || _mengirim) return true;

    final l10n = AppLocalizations.of(context);

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lkKeluarTanpaSimpan),
        content: Text(l10n.lkKeluarTanpaSimpanBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.lkKeluarBatal),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.lkKeluarLanjut),
          ),
        ],
      ),
    );

    return lanjut ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bentuk = widget.bentuk;

    // Diambil sebelum `await` — sesudahnya `context` punya build ini udah
    // nggak dijamin kepasang lagi.
    final navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _bolehKeluar() && mounted) navigator.pop();
      },
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _KopDokumen(bentuk: bentuk),
                const SizedBox(height: AppSpacing.md),

                for (final bagian in bentuk.bagian) ...[
                  _Bagian(
                    bagian: bagian,
                    isian: _isian,
                    onBerubah: () => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

          // Tombolnya nempel di bawah, bukan ikut ke-scroll: lembar kerjanya
          // panjang, dan teknisi nggak boleh perlu scroll sampai ujung cuma
          // buat nyimpen draft di tengah kerjaan.
          Material(
            elevation: 8,
            color: theme.colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      // Admin ngisi lembarnya buat dirinya sendiri — nggak ada
                      // "ke admin"-nya. Yang nentuin bentuk formulir juga
                      // backend (`untuk: admin`), jadi label ini ikut sumber
                      // yang sama, bukan ngecek role sendiri.
                      label: bentuk.untukAdmin ? l10n.lkKirimAdmin : l10n.lkKirim,
                      isLoading: _mengirim,
                      // SELALU aktif. Lihat docblock LembarKerjaScreen.
                      onPressed: () => _submit(draft: false),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: l10n.lkSimpanDraft,
                      variant: AppButtonVariant.secondary,
                      isLoading: _mengirim,
                      onPressed: () => _submit(draft: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KopDokumen extends StatelessWidget {
  const _KopDokumen({required this.bentuk});

  final LembarKerja bentuk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bentuk.judul, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              bentuk.kodeDokumen,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    // Catatannya datang dari backend — dia yang paling tahu
                    // kolom mana yang lagi opsional. Kalau kosong, pakai
                    // kalimat baku yang artinya sama.
                    bentuk.catatanPengisian.isEmpty
                        ? l10n.lkSemuaOpsional
                        : bentuk.catatanPengisian,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu bagian lembar kerja. Bagian yang punya tabel dirender sebagai tabel
/// hasil; sisanya sebagai daftar kolom.
class _Bagian extends ConsumerWidget {
  const _Bagian({
    required this.bagian,
    required this.isian,
    required this.onBerubah,
  });

  final BagianLembarKerja bagian;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bagian.judul.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: AppSpacing.lg),

            if (bagian.kode == 'usage_check')
              _UsageCheck(isian: isian, onBerubah: onBerubah)
            else ...[
              for (final f in bagian.field) ...[
                _Field(field: f, isian: isian, onBerubah: onBerubah),
                const SizedBox(height: AppSpacing.md),
              ],
            ],

            for (final tabel in bagian.tabel) ...[
              LembarKerjaTabel(
                tabel: tabel,
                isian: isian,
                onBerubah: onBerubah,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu kolom. Yang nentuin bentuknya `tipe` + `sumber` dari backend, bukan
/// daftar `if` per nama kolom — kolom baru dari Rev.5 tetap kerender.
class _Field extends ConsumerWidget {
  const _Field({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kolom `sumber: otomatis` — ketarik dari alat/akun, teknisi cuma lihat.
    if (field.sumber.readOnly) {
      final user = ref.watch(authProvider).value;
      return _Readonly(
        label: field.label,
        nilai: isian.nilaiTurunan(field.kode, namaTeknisi: user?.nama),
        satuan: field.satuan,
      );
    }

    return switch (field.sumber) {
      SumberField.masterAlat => _PilihAlat(isian: isian, onBerubah: onBerubah),
      SumberField.masterRuangan => _PilihRuangan(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      SumberField.masterStandar => _PilihStandar(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      SumberField.masterMetode => _PilihMetode(field: field, isian: isian),
      _ => _FieldBiasa(field: field, isian: isian, onBerubah: onBerubah),
    };
  }
}

class _FieldBiasa extends StatelessWidget {
  const _FieldBiasa({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    return switch (field.tipe) {
      TipeField.tanggal => _PilihTanggal(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      TipeField.pilihan => _PilihanTetap(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      _ => _Isian(field: field, isian: isian),
    };
  }
}

class _Isian extends StatelessWidget {
  const _Isian({required this.field, required this.isian});

  final FieldLembarKerja field;
  final LembarKerjaState isian;

  @override
  Widget build(BuildContext context) {
    final controller = isian.teks[field.kode];
    if (controller == null) return const SizedBox.shrink();

    final panjang = field.tipe == TipeField.teksPanjang;
    final angka = field.tipe == TipeField.angka;

    return TextField(
      controller: controller,
      maxLines: panjang ? 4 : 1,
      keyboardType: angka
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : (panjang ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(
        labelText: field.label,
        suffixText: field.satuan,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _PilihTanggal extends StatelessWidget {
  const _PilihTanggal({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nilai = isian.tanggal[field.kode];

    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final dipilih = await showDatePicker(
                  context: context,
                  initialDate: nilai ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  // Backend nolak tanggal kalibrasi di masa depan
                  // (`before_or_equal:today`) — jangan sampai bisa dipilih di
                  // sini terus ditolak sesudah teknisi selesai ngisi semuanya.
                  lastDate: DateTime.now(),
                );
                if (dipilih == null) return;
                isian.tanggal[field.kode] = dipilih;
                onBerubah();
              },
              child: Text(nilai == null ? l10n.lkKosong : _format(nilai)),
            ),
          ),
          if (nilai != null)
            IconButton(
              tooltip: l10n.lkHapusTanggal,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                isian.tanggal[field.kode] = null;
                onBerubah();
              },
            ),
        ],
      ),
    );
  }
}

class _PilihanTetap extends StatelessWidget {
  const _PilihanTetap({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    // Satu-satunya kolom pilihan bernilai tetap di lembar kerja: Location.
    if (field.kode != 'lokasi') return const SizedBox.shrink();

    return DropdownButtonFormField<LokasiKalibrasi>(
      initialValue: isian.lokasi,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final p in field.pilihan)
          DropdownMenuItem(
            value: p.nilai == 'onsite'
                ? LokasiKalibrasi.onsite
                : LokasiKalibrasi.lab,
            child: Text(p.label),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        isian.lokasi = value;
        onBerubah();
      },
    );
  }
}

class _PilihAlat extends ConsumerWidget {
  const _PilihAlat({required this.isian, required this.onBerubah});

  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // pH Meter selalu di kategori instrumen-analitik; null = semua alat, biar
    // lembar kerja ini bisa dipakai kategori lain waktu formulirnya nambah.
    final alatAsync = ref.watch(equipmentLookupProvider(null));

    return alatAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(l10n.lkAlatKosong),
      data: (list) => DropdownButtonFormField<EquipmentLookup>(
        initialValue: isian.alat,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.lkPilihAlat,
          border: const OutlineInputBorder(),
        ),
        hint: Text(list.isEmpty ? l10n.lkAlatKosong : l10n.lkPilih),
        items: [
          for (final e in list)
            DropdownMenuItem(
              value: e,
              child: Text(
                '${e.namaAlat} · ${e.serialNumber}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: list.isEmpty
            ? null
            : (value) {
                isian.alat = value;
                onBerubah();
              },
      ),
    );
  }
}

class _PilihRuangan extends ConsumerWidget {
  const _PilihRuangan({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ruanganAsync = ref.watch(roomListProvider);

    return ruanganAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      // Ruangan itu kolom opsional — kalau daftarnya gagal dimuat, jangan
      // ngeblok lembar kerjanya, cukup nggak usah ditawarin.
      error: (_, _) => const SizedBox.shrink(),
      data: (list) => DropdownButtonFormField<int>(
        initialValue: isian.roomId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        hint: Text(l10n.lkPilih),
        items: [
          for (final Room r in list)
            DropdownMenuItem(value: r.id, child: Text(r.label)),
        ],
        onChanged: (value) {
          isian.roomId = value;
          onBerubah();
        },
      ),
    );
  }
}

class _PilihStandar extends ConsumerWidget {
  const _PilihStandar({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final standarAsync = ref.watch(standardListProvider);

    // Kolom administratif "Thermohygro used" cuma nyampe sini kalau yang login
    // admin — backend nggak ngirimin bagiannya ke teknisi.
    final thermohygro = field.kode == 'thermohygro_standard_id';

    return standarAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        final pilihan = thermohygro
            ? list.where((s) => s.punyaParameterKondisi).toList()
            : list;

        return DropdownButtonFormField<int>(
          initialValue: thermohygro
              ? isian.thermohygroStandardId
              : isian.standardId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          hint: Text(l10n.lkPilih),
          items: [
            for (final Standard s in pilihan)
              DropdownMenuItem(
                value: s.id,
                // Standar kadaluarsa TETAP kelihatan tapi nggak bisa dipilih —
                // kalau disembunyiin, teknisi yang nyari standar yang biasa dia
                // pakai bakal ngira datanya ilang.
                enabled: s.masihBerlaku,
                child: Text(
                  s.masihBerlaku
                      ? s.nama
                      : '${s.nama} (${l10n.lkStandarKadaluarsa})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (thermohygro) {
              isian.thermohygroStandardId = value;
            } else {
              isian.standardId = value;
            }
            onBerubah();
          },
        );
      },
    );
  }
}

/// "Calibration Methode" — kolom administratif, cuma kerender di sisi admin.
/// Belum ada layanan master metode di mobile, jadi buat sekarang ditampilin
/// sebagai kolom nonaktif biar admin tau kolomnya ada & diisi di panel web.
class _PilihMetode extends StatelessWidget {
  const _PilihMetode({required this.field, required this.isian});

  final FieldLembarKerja field;
  final LembarKerjaState isian;

  @override
  Widget build(BuildContext context) {
    return _Readonly(label: field.label, nilai: '', satuan: field.satuan);
  }
}

class _Readonly extends StatelessWidget {
  const _Readonly({required this.label, required this.nilai, this.satuan});

  final String label;
  final String nilai;
  final String? satuan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tampil = nilai.trim().isEmpty ? l10n.lkKosong : nilai;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: satuan,
        helperText: l10n.lkOtomatis,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
      ),
      child: Text(
        tampil,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: nilai.trim().isEmpty
              ? theme.colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    );
  }
}

/// Kolom "Standard Name / Usage Check": daftar standar dari master data lab,
/// tiap baris ada centang "dipakai" + keterangan.
class _UsageCheck extends ConsumerWidget {
  const _UsageCheck({required this.isian, required this.onBerubah});

  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final standarAsync = ref.watch(standardListProvider);

    return standarAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(l10n.lkUsageCheckKosong),
      data: (list) {
        if (list.isEmpty) return Text(l10n.lkUsageCheckKosong);

        return Column(
          children: [
            for (final s in list) ...[
              _UsageCheckBaris(
                standar: s,
                state: isian.usage(s.id),
                onBerubah: onBerubah,
              ),
              const Divider(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _UsageCheckBaris extends StatelessWidget {
  const _UsageCheckBaris({
    required this.standar,
    required this.state,
    required this.onBerubah,
  });

  final Standard standar;
  final UsageCheckState state;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: state.dipakai,
              onChanged: (v) {
                state.dipakai = v ?? false;
                onBerubah();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(standar.nama, style: theme.textTheme.bodyMedium),
                  if (standar.serialNumber.isNotEmpty)
                    Text(
                      standar.serialNumber,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (!standar.masihBerlaku)
                    Text(
                      l10n.lkStandarKadaluarsa,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: TextField(
            controller: state.keterangan,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.lkUsageCheckKeterangan,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
