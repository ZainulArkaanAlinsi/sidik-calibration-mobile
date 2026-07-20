import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../models/ph_calibration_draft.dart';
import '../../models/standard.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Input kalibrasi pH Meter — struktur lengkap ngikutin master worksheet asli
/// PT Sidik (kondisi lingkungan awal/akhir, 3 titik buffer standar × 5
/// pembacaan sebelum & sesudah adjustment). Layar terpisah dari
/// [CalibrationInputScreen] generik karena pH butuh field yang jauh lebih
/// spesifik — dipaksa masuk ke form generik bakal bikin dua-duanya berantakan.
///
/// **Nggak ada rumus GUM/ILAC-G8 di sini.** Backend yang ngitung ketidakpastian
/// & keputusan PASS/FAIL (`Aturan Bisnis Inti.md`) — layar ini cuma nangkep
/// data mentah dan ngirim ke `POST /api/calibrations` yang udah live.
class PhCalibrationInputScreen extends ConsumerWidget {
  const PhCalibrationInputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standarAsync = ref.watch(standardListProvider);
    final l10n = AppLocalizations.of(context);

    final standar = standarAsync.value;

    final Widget isi;
    if (standar != null) {
      isi = _Form(standarList: standar);
    } else if (standarAsync.hasError) {
      isi = _Gagal(onCobaLagi: () => ref.invalidate(standardListProvider));
    } else {
      isi = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.phCalibTitle)),
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

/// Controller teks buat satu titik buffer — 1 nilai standar + 5×2 pembacaan
/// (pH + suhu) untuk tiap state (sebelum/sesudah adjustment), plus standar
/// buffer yang dipakai KHUSUS titik ini (`PhBufferPoint.standardId`).
class _TitikControllers {
  _TitikControllers(String nilaiDefault)
    : nilaiStandar = TextEditingController(text: nilaiDefault),
      sebelumPh = List.generate(5, (_) => TextEditingController()),
      sebelumSuhu = List.generate(5, (_) => TextEditingController()),
      sesudahPh = List.generate(5, (_) => TextEditingController()),
      sesudahSuhu = List.generate(5, (_) => TextEditingController());

  final TextEditingController nilaiStandar;
  final List<TextEditingController> sebelumPh;
  final List<TextEditingController> sebelumSuhu;
  final List<TextEditingController> sesudahPh;
  final List<TextEditingController> sesudahSuhu;

  /// Mis. "pH Buffer Solution 4" — beda dari standar sesi (Termometer &
  /// Sensor Std.), lihat komentar di [PhBufferPoint.standardId].
  Standard? standarBuffer;

  void dispose() {
    nilaiStandar.dispose();
    for (final c in [...sebelumPh, ...sebelumSuhu, ...sesudahPh, ...sesudahSuhu]) {
      c.dispose();
    }
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.standarList});

  final List<Standard> standarList;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

/// Thermohygro yang aktif di lab (`FORM VALIDASI.csv`: "adding TH-3 s/d 7").
/// Sentinel di luar rentang biar nggak pernah ketuker sama ID alat asli
/// kalau lab nambah unit baru.
const _thermohygroCustom = '__custom__';
const _thermohygroPresets = ['TH-1', 'TH-2', 'TH-3', 'TH-4', 'TH-5', 'TH-6', 'TH-7'];

class _FormState extends ConsumerState<_Form> {
  EquipmentLookup? _alat;
  Standard? _standar;
  DateTime _tanggal = DateTime.now();
  DateTime? _tanggalTerima;
  LokasiKalibrasi _lokasi = LokasiKalibrasi.lab;
  final _nomorOrder = TextEditingController();
  String _thermohygroPreset = 'TH-3';
  final _thermohygro = TextEditingController(text: 'TH-3');

  /// Di-generate SEKALI waktu layar dibuka (bukan tiap tap tombol) — kalau
  /// teknisi tap "Kirim" berkali-kali (mis. sinyal lemot, nungguin respons),
  /// backend ngenalin ini submission yang sama lewat `client_request_id`,
  /// bukan bikin sesi dobel (`docs/kontrak-api.md` §4).
  final _clientRequestId = generateUuidV4();
  final _suhuAwal = TextEditingController();
  final _suhuAkhir = TextEditingController();
  final _kelembabanAwal = TextEditingController();
  final _kelembabanAkhir = TextEditingController();

  final _titik4 = _TitikControllers('3.99');
  final _titik7 = _TitikControllers('7');
  final _titik10 = _TitikControllers('10.01');

  bool _mengirim = false;

  @override
  void dispose() {
    _nomorOrder.dispose();
    _thermohygro.dispose();
    _suhuAwal.dispose();
    _suhuAkhir.dispose();
    _kelembabanAwal.dispose();
    _kelembabanAkhir.dispose();
    _titik4.dispose();
    _titik7.dispose();
    _titik10.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  PhBufferPoint? _bacaTitik(_TitikControllers c, String label, AppLocalizations l10n) {
    final nilaiStandar = _parse(c.nilaiStandar.text);
    if (nilaiStandar == null || c.standarBuffer == null) return null;

    final titik = PhBufferPoint(
      label: label,
      nilaiStandar: nilaiStandar,
      standardId: c.standarBuffer!.id,
    );

    for (var i = 0; i < 5; i++) {
      final phSebelum = _parse(c.sebelumPh[i].text);
      final suhuSebelum = _parse(c.sebelumSuhu[i].text);
      if (phSebelum != null && suhuSebelum != null) {
        titik.sebelumAdjustment[i] = PhReading(ph: phSebelum, suhu: suhuSebelum);
      }

      final phSesudah = _parse(c.sesudahPh[i].text);
      final suhuSesudah = _parse(c.sesudahSuhu[i].text);
      if (phSesudah != null && suhuSesudah != null) {
        titik.sesudahAdjustment[i] = PhReading(ph: phSesudah, suhu: suhuSesudah);
      }
    }

    return titik;
  }

  Future<void> _submit({required bool draft}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_alat == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAlat)));
      return;
    }
    if (_standar == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiStandar)));
      return;
    }

    final suhuAwal = _parse(_suhuAwal.text);
    final suhuAkhir = _parse(_suhuAkhir.text);
    final kelembabanAwal = _parse(_kelembabanAwal.text);
    final kelembabanAkhir = _parse(_kelembabanAkhir.text);
    if (suhuAwal == null ||
        suhuAkhir == null ||
        kelembabanAwal == null ||
        kelembabanAkhir == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.phCalibValidasiLingkungan)),
      );
      return;
    }

    if (_titik4.standarBuffer == null ||
        _titik7.standarBuffer == null ||
        _titik10.standarBuffer == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.phCalibValidasiStandarBuffer)),
      );
      return;
    }

    final titikList = [
      _bacaTitik(_titik4, '4', l10n),
      _bacaTitik(_titik7, '7', l10n),
      _bacaTitik(_titik10, '10', l10n),
    ];

    for (final titik in titikList) {
      final cukup =
          titik != null && titik.sesudahAdjustment.whereType<PhReading>().length >= 5;
      if (!cukup) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.phCalibValidasiPembacaan)),
        );
        return;
      }
    }

    final draftPh = PhCalibrationDraft(
      equipmentId: _alat!.id,
      standardId: _standar!.id,
      tanggalKalibrasi: _tanggal,
      thermohygroId: _thermohygro.text.trim(),
    )
      ..suhuAwal = suhuAwal
      ..suhuAkhir = suhuAkhir
      ..kelembabanAwal = kelembabanAwal
      ..kelembabanAkhir = kelembabanAkhir
      ..nomorOrder = _nomorOrder.text.trim()
      ..tanggalTerima = _tanggalTerima;

    draftPh.points
      ..[0] = titikList[0]!
      ..[1] = titikList[1]!
      ..[2] = titikList[2]!;

    setState(() => _mengirim = true);

    final hasil = await ref.read(calibrationSubmitProvider.notifier).submit(
      draftPh.toGenericDraft(
        clientRequestId: _clientRequestId,
        lokasi: _lokasi,
        simpanSebagaiDraft: draft,
      ),
    );

    if (!mounted) return;
    setState(() => _mengirim = false);

    if (hasil != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            draft ? l10n.calibBerhasilDraft : l10n.calibBerhasilApproval,
          ),
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
    // pH Meter selalu kategori "instrumen-analitik" — nggak ada dropdown
    // kategori di layar ini, beda sama form generik.
    final equipmentAsync = ref.watch(
      equipmentLookupProvider(PhCalibrationDraft.kategori),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
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

        Text(l10n.phCalibStandarSesi.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<Standard>(
          initialValue: _standar,
          isExpanded: true,
          hint: Text(l10n.phCalibStandarSesiHint),
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

        AppTextField(
          label: l10n.calibNomorOrder,
          controller: _nomorOrder,
          hint: l10n.calibNomorOrderHint,
        ),
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: () async {
            final dipilih = await showDatePicker(
              context: context,
              initialDate: _tanggalTerima ?? _tanggal,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (dipilih != null) setState(() => _tanggalTerima = dipilih);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.calibTanggalTerima.toUpperCase(),
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              _tanggalTerima == null
                  ? '—'
                  : '${_tanggalTerima!.day}/${_tanggalTerima!.month}/${_tanggalTerima!.year}',
            ),
          ),
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
            child: Text('${_tanggal.day}/${_tanggal.month}/${_tanggal.year}'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.phCalibThermohygro.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _thermohygroPreset,
          isExpanded: true,
          items: [
            for (final th in _thermohygroPresets)
              DropdownMenuItem(value: th, child: Text(th)),
            DropdownMenuItem(
              value: _thermohygroCustom,
              child: Text(l10n.phCalibThermohygroCustom),
            ),
          ],
          onChanged: (value) => setState(() {
            _thermohygroPreset = value!;
            if (value != _thermohygroCustom) _thermohygro.text = value;
          }),
        ),
        if (_thermohygroPreset == _thermohygroCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: l10n.phCalibThermohygro,
            controller: _thermohygro,
            hint: l10n.phCalibThermohygroHint,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        Text(
          l10n.phCalibKondisiLingkungan.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          // start, bukan center: label yang turun baris bikin tinggi kedua
          // kolom beda, dan kalau center kotak inputnya jadi miring sebelah.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField.measurement(
                label: l10n.phCalibSuhuAwal,
                controller: _suhuAwal,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.measurement(
                label: l10n.phCalibSuhuAkhir,
                controller: _suhuAkhir,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField.measurement(
                label: l10n.phCalibKelembabanAwal,
                controller: _kelembabanAwal,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.measurement(
                label: l10n.phCalibKelembabanAkhir,
                controller: _kelembabanAkhir,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        _BufferPointCard(
          label: '4',
          controllers: _titik4,
          standarList: widget.standarList,
          onStandarChanged: (v) => setState(() => _titik4.standarBuffer = v),
        ),
        const SizedBox(height: AppSpacing.md),
        _BufferPointCard(
          label: '7',
          controllers: _titik7,
          standarList: widget.standarList,
          onStandarChanged: (v) => setState(() => _titik7.standarBuffer = v),
        ),
        const SizedBox(height: AppSpacing.md),
        _BufferPointCard(
          label: '10',
          controllers: _titik10,
          standarList: widget.standarList,
          onStandarChanged: (v) => setState(() => _titik10.standarBuffer = v),
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

class _BufferPointCard extends StatelessWidget {
  const _BufferPointCard({
    required this.label,
    required this.controllers,
    required this.standarList,
    required this.onStandarChanged,
  });

  final String label;
  final _TitikControllers controllers;
  final List<Standard> standarList;
  final ValueChanged<Standard?> onStandarChanged;

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
            Text(
              l10n.phCalibTitikBuffer(label),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField.measurement(
              label: l10n.phCalibNilaiStandar,
              controller: controllers.nilaiStandar,
              satuan: 'pH',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.phCalibStandarBuffer.toUpperCase(),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<Standard>(
              initialValue: controllers.standarBuffer,
              isExpanded: true,
              hint: Text(l10n.phCalibStandarBufferHint),
              items: standarList
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      enabled: s.masihBerlaku,
                      child: Text(
                        s.masihBerlaku
                            ? s.nama
                            : '${s.nama} (${l10n.calibStandarKadaluarsa})',
                        style: s.masihBerlaku
                            ? null
                            : TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onStandarChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            _ReadingSection(
              judul: l10n.phCalibSebelumAdjustment,
              phControllers: controllers.sebelumPh,
              suhuControllers: controllers.sebelumSuhu,
            ),
            const SizedBox(height: AppSpacing.md),
            _ReadingSection(
              judul: l10n.phCalibSesudahAdjustment,
              phControllers: controllers.sesudahPh,
              suhuControllers: controllers.sesudahSuhu,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.judul,
    required this.phControllers,
    required this.suhuControllers,
  });

  final String judul;
  final List<TextEditingController> phControllers;
  final List<TextEditingController> suhuControllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          judul,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField.measurement(
                    label: l10n.phCalibPembacaanKe(i + 1),
                    controller: phControllers[i],
                    satuan: 'pH',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField.measurement(
                    label: l10n.phCalibSuhu,
                    controller: suhuControllers[i],
                    satuan: '°C',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
