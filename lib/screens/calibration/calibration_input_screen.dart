import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_draft.dart';
import '../../models/category.dart';
import '../../models/equipment_lookup.dart';
import '../../models/standard.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Form input kalibrasi — kategori → alat → standar acuan, lalu titik ukur
/// (target + pembacaan berulang) yang dinamis. Nggak nyoba nyaingin worksheet
/// penuh (CMC per kategori, validasi rentang): mobile kirim data mentah,
/// **backend yang ngitung GUM & keputusan PASS/FAIL** — sesuai
/// `docs/kontrak-api.md` §4.
class CalibrationInputScreen extends ConsumerWidget {
  const CalibrationInputScreen({super.key, this.kategoriAwal});

  /// Kode kategori yang udah dipilih dari [CategoryPickerScreen] /
  /// [InstrumentPickerScreen] — kalau ada, dropdown Kategori di bawah
  /// langsung ke-pre-fill (teknisi nggak milih ulang apa yang udah dia
  /// pilih di layar sebelumnya). Null kalau dibuka langsung (jalur lama).
  final String? kategoriAwal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriAsync = ref.watch(categoryListProvider);
    final standarAsync = ref.watch(standardListProvider);
    final l10n = AppLocalizations.of(context);

    final kategori = kategoriAsync.value;
    final standar = standarAsync.value;

    final Widget isi;
    if (kategori != null && standar != null) {
      isi = _Form(kategoriList: kategori, standarList: standar, kategoriAwal: kategoriAwal);
    } else if (kategoriAsync.hasError || standarAsync.hasError) {
      isi = _Gagal(
        onCobaLagi: () {
          ref.invalidate(categoryListProvider);
          ref.invalidate(standardListProvider);
        },
      );
    } else {
      isi = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibTitle)),
      body: isi,
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
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.calibLoadPilihanGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.calibRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Titik {
  _Titik() : nilaiTarget = TextEditingController(), satuan = TextEditingController();

  final TextEditingController nilaiTarget;
  final TextEditingController satuan;
  final List<TextEditingController> pembacaan = [
    TextEditingController(),
    TextEditingController(),
  ];

  void dispose() {
    nilaiTarget.dispose();
    satuan.dispose();
    for (final c in pembacaan) {
      c.dispose();
    }
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.kategoriList, required this.standarList, this.kategoriAwal});

  final List<Category> kategoriList;
  final List<Standard> standarList;
  final String? kategoriAwal;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  String? _kategori;
  EquipmentLookup? _alat;
  Standard? _standar;
  DateTime _tanggal = DateTime.now();
  LokasiKalibrasi _lokasi = LokasiKalibrasi.lab;
  final _suhuRuang = TextEditingController(text: '23.5');
  final _kelembaban = TextEditingController(text: '55');
  final List<_Titik> _titikList = [_Titik()];

  @override
  void initState() {
    super.initState();
    _kategori = widget.kategoriAwal;
  }

  /// Di-generate SEKALI waktu layar dibuka — lihat komentar yang sama di
  /// `ph_calibration_input_screen.dart`.
  final _clientRequestId = generateUuidV4();

  bool _mengirim = false;

  @override
  void dispose() {
    _suhuRuang.dispose();
    _kelembaban.dispose();
    for (final t in _titikList) {
      t.dispose();
    }
    super.dispose();
  }

  void _tambahTitik() => setState(() => _titikList.add(_Titik()));

  void _hapusTitik(int index) {
    if (_titikList.length <= 1) return;
    setState(() {
      _titikList.removeAt(index).dispose();
    });
  }

  void _tambahPembacaan(_Titik titik) =>
      setState(() => titik.pembacaan.add(TextEditingController()));

  double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _submit({required bool draft}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_kategori == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiKategori)));
      return;
    }
    if (_alat == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAlat)));
      return;
    }
    if (_standar == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiStandar)));
      return;
    }

    final suhu = _parse(_suhuRuang.text);
    final lembab = _parse(_kelembaban.text);
    if (suhu == null || lembab == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAngka)));
      return;
    }

    final measurements = <MeasurementPoint>[];
    for (final titik in _titikList) {
      final target = _parse(titik.nilaiTarget.text);
      if (target == null || titik.satuan.text.trim().isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAngka)));
        return;
      }

      final pembacaan = <double>[];
      for (final c in titik.pembacaan) {
        final nilai = _parse(c.text);
        if (nilai != null) pembacaan.add(nilai);
      }
      if (pembacaan.length < 2) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiPembacaan)));
        return;
      }

      measurements.add(
        MeasurementPoint(
          titikUkur: target,
          satuan: titik.satuan.text.trim(),
          pembacaan: pembacaan,
        ),
      );
    }

    setState(() => _mengirim = true);

    final hasil = await ref.read(calibrationSubmitProvider.notifier).submit(
      CalibrationDraft(
        equipmentId: _alat!.id,
        kategori: _kategori!,
        standardId: _standar!.id,
        tanggalKalibrasi: _tanggal,
        suhuRuang: suhu,
        kelembaban: lembab,
        lokasi: _lokasi,
        clientRequestId: _clientRequestId,
        measurements: measurements,
        simpanSebagaiDraft: draft,
      ),
    );

    if (!mounted) return;
    setState(() => _mengirim = false);

    if (hasil != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(draft ? l10n.calibBerhasilDraft : l10n.calibBerhasilApproval),
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(calibrationSubmitProvider).error;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.calibGagal(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final equipmentAsync = ref.watch(equipmentLookupProvider(_kategori));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.calibKategori.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _kategori,
          isExpanded: true,
          hint: Text(l10n.calibKategoriHint),
          items: widget.kategoriList
              .map((k) => DropdownMenuItem(value: k.kode, child: Text(k.nama)))
              .toList(),
          onChanged: (value) => setState(() {
            _kategori = value;
            _alat = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.calibAlat.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        equipmentAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(l10n.calibAlatKosong),
          data: (list) => DropdownButtonFormField<EquipmentLookup>(
            initialValue: _alat,
            isExpanded: true,
            hint: Text(list.isEmpty ? l10n.calibAlatKosong : l10n.calibAlatHint),
            items: list
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text('${e.namaAlat} · ${e.serialNumber}'),
                  ),
                )
                .toList(),
            onChanged: list.isEmpty ? null : (value) => setState(() => _alat = value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.calibStandar.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<Standard>(
          initialValue: _standar,
          isExpanded: true,
          hint: Text(l10n.calibStandarHint),
          items: widget.standarList
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  enabled: s.masihBerlaku,
                  child: Text(
                    s.masihBerlaku ? s.nama : '${s.nama} (${l10n.calibStandarKadaluarsa})',
                    style: s.masihBerlaku
                        ? null
                        : TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _standar = value),
        ),
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: () async {
            final dipilih = await showDatePicker(
              context: context,
              initialDate: _tanggal,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (dipilih != null) setState(() => _tanggal = dipilih);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.calibTanggal.toUpperCase(),
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              '${_tanggal.day}/${_tanggal.month}/${_tanggal.year}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.calibLokasi.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<LokasiKalibrasi>(
          initialValue: _lokasi,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: LokasiKalibrasi.lab, child: Text(l10n.calibLokasiLab)),
            DropdownMenuItem(
              value: LokasiKalibrasi.onsite,
              child: Text(l10n.calibLokasiOnsite),
            ),
          ],
          onChanged: (value) => setState(() => _lokasi = value!),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: AppTextField.measurement(
                label: l10n.calibSuhuRuang,
                controller: _suhuRuang,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.measurement(
                label: l10n.calibKelembaban,
                controller: _kelembaban,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        for (var i = 0; i < _titikList.length; i++) ...[
          _TitikCard(
            index: i,
            titik: _titikList[i],
            bisaHapus: _titikList.length > 1,
            onHapus: () => _hapusTitik(i),
            onTambahPembacaan: () => _tambahPembacaan(_titikList[i]),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: l10n.calibTambahTitik,
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          onPressed: _tambahTitik,
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: l10n.calibKirimApproval,
          isLoading: _mengirim,
          onPressed: _mengirim ? null : () => _submit(draft: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.calibSimpanDraft,
          variant: AppButtonVariant.secondary,
          isLoading: _mengirim,
          onPressed: _mengirim ? null : () => _submit(draft: true),
        ),
      ],
    );
  }
}

class _TitikCard extends StatelessWidget {
  const _TitikCard({
    required this.index,
    required this.titik,
    required this.bisaHapus,
    required this.onHapus,
    required this.onTambahPembacaan,
  });

  final int index;
  final _Titik titik;
  final bool bisaHapus;
  final VoidCallback onHapus;
  final VoidCallback onTambahPembacaan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.calibTitikUkur(index + 1),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (bisaHapus)
                  IconButton(
                    tooltip: l10n.calibHapusTitik,
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onHapus,
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField.measurement(
                    label: l10n.calibNilaiTarget,
                    controller: titik.nilaiTarget,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: l10n.calibSatuan,
                    controller: titik.satuan,
                    hint: 'mm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < titik.pembacaan.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppTextField.measurement(
                  label: l10n.calibPembacaan(i + 1),
                  controller: titik.pembacaan[i],
                ),
              ),
            ],
            TextButton(
              onPressed: onTambahPembacaan,
              child: Text(l10n.calibTambahPembacaan),
            ),
          ],
        ),
      ),
    );
  }
}
