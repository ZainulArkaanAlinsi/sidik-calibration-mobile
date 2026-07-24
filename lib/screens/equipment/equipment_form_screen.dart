import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer_lookup.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart'
    show categoryDetailProvider, categoryListProvider;
import '../../providers/equipment_provider.dart';
import '../../providers/master_data_provider.dart' show customerLookupProvider;
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Form tambah/edit alat. `existing == null` → mode tambah.
///
/// Viewer bisa buka layar ini (baca alat itu hak semua role,
/// `docs/kontrak-api.md` §3), tapi field-nya `enabled: false` dan nggak ada
/// tombol simpan/hapus — nulis cuma buat admin & teknisi
/// ([UserRole.bisaInput]).
class EquipmentFormScreen extends ConsumerStatefulWidget {
  const EquipmentFormScreen({super.key, this.existing});

  final Equipment? existing;

  @override
  ConsumerState<EquipmentFormScreen> createState() =>
      _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  late final _namaAlat = TextEditingController(text: widget.existing?.namaAlat);
  late final _serialNumber = TextEditingController(
    text: widget.existing?.serialNumber,
  );
  late final _merk = TextEditingController(text: widget.existing?.merk);
  late final _model = TextEditingController(text: widget.existing?.model);
  late final _noIdentifikasi = TextEditingController(
    text: widget.existing?.noIdentifikasi,
  );
  late final _rangeMin = TextEditingController(
    text: widget.existing?.rangeMin?.toString(),
  );
  late final _rangeMax = TextEditingController(
    text: widget.existing?.rangeMax?.toString(),
  );
  late final _satuan = TextEditingController(text: widget.existing?.satuan);
  late final _resolusi = TextEditingController(
    text: widget.existing?.resolusi?.toString(),
  );
  late final _toleransi = TextEditingController(
    text: widget.existing?.toleransi?.toString(),
  );
  late final _lokasi = TextEditingController(text: widget.existing?.lokasi);
  late final _catatan = TextEditingController(text: widget.existing?.catatan);

  String? _kategori;
  int? _pelangganId;

  /// Disimpen terpisah dari [_pelangganId] karena picker-nya nggak megang
  /// daftar lengkap di memori — waktu buka form edit, nama pelanggannya datang
  /// dari alat yang lagi dibuka, bukan dari hasil pencarian.
  String? _pelangganNama;

  String? _namaAlatKemampuan;
  EquipmentStatus _status = EquipmentStatus.aktif;

  bool _menyimpan = false;
  String? _errorNama;
  String? _errorSerial;
  String? _errorKategori;
  String? _errorPelanggan;
  String? _errorToleransi;

  @override
  void initState() {
    super.initState();
    _kategori = widget.existing?.kategori;
    _pelangganId = widget.existing?.pelangganId;
    _pelangganNama = widget.existing?.pelangganNama;
    _namaAlatKemampuan = widget.existing?.namaAlatKemampuan;

    // `GET /equipments` bisa balikin `overdue`, tapi dropdown status cuma
    // punya `aktif`/`nonaktif` — kalau nilainya dibiarin `overdue`, Flutter
    // langsung assert ("no matching item"). Ditampilin sebagai `aktif` karena
    // itu emang nilai yang kesimpen di server; `overdue`-nya cuma turunan
    // dari `tanggal_jatuh_tempo`.
    final status = widget.existing?.status ?? EquipmentStatus.aktif;
    _status = status == EquipmentStatus.overdue
        ? EquipmentStatus.aktif
        : status;
  }

  @override
  void dispose() {
    _namaAlat.dispose();
    _serialNumber.dispose();
    _merk.dispose();
    _model.dispose();
    _noIdentifikasi.dispose();
    _rangeMin.dispose();
    _rangeMax.dispose();
    _satuan.dispose();
    _resolusi.dispose();
    _toleransi.dispose();
    _lokasi.dispose();
    _catatan.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);

    setState(() {
      _errorNama = _namaAlat.text.trim().isEmpty ? l10n.custFieldRequired : null;
      _errorSerial =
          _serialNumber.text.trim().isEmpty ? l10n.custFieldRequired : null;
      _errorKategori = _kategori == null ? l10n.custFieldRequired : null;
      _errorPelanggan = _pelangganId == null ? l10n.custFieldRequired : null;
      // Backend masih ngebolehin `toleransi` kosong, tapi alat tanpa toleransi
      // nggak bisa dikalibrasi sama sekali — PASS/FAIL-nya nggak bisa
      // diputusin, jadi submit kalibrasinya ditolak 422 belakangan. Dicegat di
      // sini biar ketahuannya sekarang, bukan pas teknisi udah kelar ngisi
      // seluruh worksheet.
      _errorToleransi = _parse(_toleransi.text) == null
          ? l10n.equipToleransiWajib
          : null;
    });
    if (_errorNama != null ||
        _errorSerial != null ||
        _errorKategori != null ||
        _errorPelanggan != null ||
        _errorToleransi != null) {
      return;
    }

    setState(() => _menyimpan = true);

    final data = Equipment(
      id: widget.existing?.id ?? 0,
      namaAlat: _namaAlat.text.trim(),
      serialNumber: _serialNumber.text.trim(),
      kategori: _kategori!,
      status: _status,
      merk: _merk.text.trim(),
      model: _model.text.trim(),
      noIdentifikasi: _noIdentifikasi.text.trim(),
      pelangganId: _pelangganId,
      namaAlatKemampuan: _namaAlatKemampuan,
      rangeMin: _parse(_rangeMin.text),
      rangeMax: _parse(_rangeMax.text),
      satuan: _satuan.text.trim(),
      resolusi: _parse(_resolusi.text),
      toleransi: _parse(_toleransi.text),
      lokasi: _lokasi.text.trim(),
      catatan: _catatan.text.trim(),
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.existing == null) {
        await ref.read(equipmentProvider.notifier).tambah(data);
      } else {
        await ref.read(equipmentProvider.notifier).ubah(data);
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.equipSaveFailed(e.toString()))),
      );
      setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mengedit = widget.existing != null;
    final bisaInput = ref.watch(authProvider).value?.role.bisaInput ?? false;
    final kategoriList = ref.watch(categoryListProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(mengedit ? l10n.equipEdit : l10n.equipAdd)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppTextField(
            label: l10n.equipNamaAlat,
            controller: _namaAlat,
            errorText: _errorNama,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipSerialNumber,
            controller: _serialNumber,
            errorText: _errorSerial,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),

          Text(l10n.equipKategori.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            isExpanded: true,
            hint: Text(l10n.equipKategoriHint),
            items: kategoriList
                .map((k) => DropdownMenuItem(value: k.kode, child: Text(k.nama)))
                .toList(),
            onChanged: bisaInput
                ? (value) => setState(() {
                    _kategori = value;
                    _errorKategori = null;
                    // Kemampuan (CMC) terikat ke kategori — ganti kategori,
                    // pilihan lama nggak tentu masih valid buat kategori baru.
                    _namaAlatKemampuan = null;
                  })
                : null,
            decoration: InputDecoration(errorText: _errorKategori),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_kategori != null) ...[
            Text(
              l10n.equipNamaAlatKemampuan.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _KemampuanDropdown(
              kategori: _kategori!,
              value: _namaAlatKemampuan,
              enabled: bisaInput,
              onChanged: (value) => setState(() => _namaAlatKemampuan = value),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          Text(l10n.equipPelanggan.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          _PelangganField(
            nama: _pelangganNama,
            errorText: _errorPelanggan,
            enabled: bisaInput,
            onPilih: (pilihan) => setState(() {
              _pelangganId = pilihan.id;
              _pelangganNama = pilihan.nama;
              _errorPelanggan = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: l10n.equipMerk,
                  controller: _merk,
                  enabled: bisaInput,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: l10n.equipModel,
                  controller: _model,
                  enabled: bisaInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipNoIdentifikasi,
            controller: _noIdentifikasi,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.equipRangeMin,
                  controller: _rangeMin,
                  enabled: bisaInput,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.equipRangeMax,
                  controller: _rangeMax,
                  enabled: bisaInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: l10n.equipSatuan,
                  controller: _satuan,
                  enabled: bisaInput,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.equipResolusi,
                  controller: _resolusi,
                  enabled: bisaInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField.measurement(
            label: l10n.equipToleransi,
            controller: _toleransi,
            errorText: _errorToleransi,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.equipToleransiWajibHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipLokasi,
            controller: _lokasi,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipCatatan,
            controller: _catatan,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),

          Text(l10n.equipStatus.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<EquipmentStatus>(
            initialValue: _status,
            isExpanded: true,
            items: [
              // `overdue` sengaja NGGAK ditawarin: itu status turunan yang
              // dihitung backend dari `tanggal_jatuh_tempo`, bukan sesuatu yang
              // boleh dikirim. Dulu pilihannya ada di sini, dan karena
              // `Equipment.toApi()` diam-diam nurunin `overdue` jadi `aktif`,
              // user yang milih "Jatuh tempo" ngeliat form-nya sukses tersimpan
              // padahal yang kesimpen `aktif`.
              DropdownMenuItem(
                value: EquipmentStatus.aktif,
                child: Text(l10n.equipStatusAktif),
              ),
              DropdownMenuItem(
                value: EquipmentStatus.nonaktif,
                child: Text(l10n.equipStatusNonaktif),
              ),
            ],
            onChanged: bisaInput
                ? (value) => setState(() => _status = value!)
                : null,
          ),

          if (bisaInput) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.equipSave,
              isLoading: _menyimpan,
              onPressed: _menyimpan ? null : _simpan,
            ),
          ],
        ],
      ),
    );
  }
}

/// Field pelanggan — bukan `DropdownButtonFormField`, tapi kolom yang dipencet
/// buat buka pencarian.
///
/// Daftar pelanggan dipaginasi 15/halaman di backend, jadi dropdown biasa cuma
/// bakal nampilin 15 pelanggan pertama tanpa ada tanda apa pun kalau sisanya
/// kepotong — di lab yang pelanggannya banyak, alat jadi nggak bisa disimpan
/// karena pelanggannya "nggak ada di daftar". Pencariannya dilempar ke server.
class _PelangganField extends StatelessWidget {
  const _PelangganField({
    required this.nama,
    required this.errorText,
    required this.enabled,
    required this.onPilih,
  });

  final String? nama;
  final String? errorText;
  final bool enabled;
  final ValueChanged<CustomerLookup> onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final kosong = nama == null || nama!.isEmpty;

    return InkWell(
      onTap: enabled
          ? () async {
              final pilihan = await showModalBottomSheet<CustomerLookup>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _PelangganSheet(),
              );
              if (pilihan != null) onPilih(pilihan);
            }
          : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: errorText,
          suffixIcon: const Icon(Icons.search),
          enabled: enabled,
        ),
        child: Text(
          kosong ? l10n.equipPelangganHint : nama!,
          style: kosong
              ? theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Sheet pencarian pelanggan. Query-nya dikirim ke server (`?search=`), bukan
/// nyaring daftar yang udah keburu kepotong paginasi di sisi mobile.
class _PelangganSheet extends ConsumerStatefulWidget {
  const _PelangganSheet();

  @override
  ConsumerState<_PelangganSheet> createState() => _PelangganSheetState();
}

class _PelangganSheetState extends ConsumerState<_PelangganSheet> {
  final _kunci = TextEditingController();

  /// Query yang beneran dikirim ke server. Sengaja dipisah dari isi
  /// [_kunci]: tiap huruf yang diketik nggak langsung jadi satu request.
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _kunci.dispose();
    super.dispose();
  }

  void _ketik(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasil = ref.watch(customerLookupProvider(_query));

    return Padding(
      // Sheet-nya naik ngikutin keyboard — kalau nggak, kolom pencariannya
      // ketutupan persis waktu user mau ngetik di situ.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.equipPelanggan, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _kunci,
                autofocus: true,
                onChanged: _ketik,
                decoration: InputDecoration(
                  hintText: l10n.equipPelangganCariHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 280,
                child: hasil.when(
                  skipLoadingOnReload: true,
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text(
                      l10n.equipPelangganGagal,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (daftar) {
                    if (daftar.isEmpty) {
                      return Center(child: Text(l10n.equipPelangganKosong));
                    }

                    return ListView.builder(
                      itemCount: daftar.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(daftar[i].nama),
                        onTap: () => Navigator.of(context).pop(daftar[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown "Jenis Alat (Kemampuan Kalibrasi)" — nunjuk ke `nama_alat` di
/// `GET /api/categories/{kode}`. Field ini OPSIONAL, tapi begitu di-set,
/// sesi kalibrasi alat ini bakal kepasang CMC akreditasi resmi lab
/// (`GumCalculator::kemampuanUntukTitik()`), bukan jalur generik.
class _KemampuanDropdown extends ConsumerWidget {
  const _KemampuanDropdown({
    required this.kategori,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String kategori;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(categoryDetailProvider(kategori));

    return detail.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(l10n.equipNamaAlatKemampuanGagal),
      data: (data) {
        // Nama alat kemampuan bisa dobel per rentang beda (mis. "Jangka
        // Sorong" 0-150mm & 150-300mm) — dropdown-nya per NAMA, bukan per
        // rentang, jadi disaring biar nggak ada entri kembar.
        final namaUnik = data.kemampuan.map((k) => k.namaAlat).toSet().toList()..sort();

        return DropdownButtonFormField<String>(
          initialValue: namaUnik.contains(value) ? value : null,
          isExpanded: true,
          hint: Text(
            namaUnik.isEmpty
                ? l10n.equipNamaAlatKemampuanKosong
                : l10n.equipNamaAlatKemampuanHint,
          ),
          items: namaUnik
              .map((nama) => DropdownMenuItem(value: nama, child: Text(nama)))
              .toList(),
          onChanged: enabled && namaUnik.isNotEmpty ? onChanged : null,
        );
      },
    );
  }
}
