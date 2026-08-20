import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../models/equipment_lookup.dart';
import '../../providers/autoclave_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/autoclave_hasil_panel.dart';

/// Lembar Kerja Autoklaf (SIDIK-FM-CAL-0539_Rev.4) — layar input teknisi.
///
/// Autoklaf punya bentuk sendiri, beda dari `LembarKerjaScreen` generik: satu
/// sesi mengukur DUA besaran (Suhu & Tekanan). Suhu diambil 3 disk sensor
/// sekaligus, tiap disk beberapa titik waktu pada satu Set Point, plus
/// Indikator & Suhu Ruang; Tekanan satu titik dengan pilihan satuan & tipe
/// display. Karena itu layar & endpoint-nya khusus
/// (`POST /calibrations/autoclave/preview`).
///
/// **Nggak ada rumus di layar ini.** Rata-rata, koreksi, Kestabilan/Keseragaman/
/// Variasi, konversi satuan, dan U95 semua dari backend. Layar cuma ngumpulin
/// angka & nampilin hasil.
class AutoclaveInputScreen extends ConsumerStatefulWidget {
  const AutoclaveInputScreen({super.key, this.judulTambahan, this.kategori});

  /// Nama alat, buat subjudul app bar (mis. "Autoclave").
  final String? judulTambahan;

  /// Kode kategori alat — nyaring picker Equipment biar cuma alat relevan.
  final String? kategori;

  @override
  ConsumerState<AutoclaveInputScreen> createState() =>
      _AutoclaveInputScreenState();
}

class _AutoclaveInputScreenState extends ConsumerState<AutoclaveInputScreen> {
  static const int _jumlahDisk = 3;
  static const int _jumlahTitikWaktu = 5;
  static const int _jumlahPembacaanTekanan = 5;

  static const List<String> _satuanTekanan = [
    'Bar', 'MPa', 'kPa', 'Psi', 'kg/cm2', 'inHg', 'mmHg', 'Pa',
  ];
  static const List<String> _displayTekanan = [
    'Digital', 'Analog 1', 'Analog 2', 'Analog 3',
  ];

  final _setPointCtrl = TextEditingController(text: '121');
  late final List<List<TextEditingController>> _disk;
  late final List<TextEditingController> _indikator;
  late final List<TextEditingController> _suhuRuang;

  final _uutSettingCtrl = TextEditingController();
  late final List<TextEditingController> _pembacaanTekanan;
  String _satuan = 'MPa';
  String _display = 'Digital';

  // ---- Identitas (buat Simpan) ----
  int? _equipmentId;
  DateTime _tanggalKalibrasi = DateTime.now();
  final _suhuAwalCtrl = TextEditingController();
  final _suhuAkhirCtrl = TextEditingController();
  final _rhAwalCtrl = TextEditingController();
  final _rhAkhirCtrl = TextEditingController();
  bool _menyimpan = false;

  String? _errorInput;

  @override
  void initState() {
    super.initState();
    _disk = List.generate(
      _jumlahDisk,
      (_) => List.generate(_jumlahTitikWaktu, (_) => TextEditingController()),
    );
    _indikator =
        List.generate(_jumlahTitikWaktu, (_) => TextEditingController());
    _suhuRuang =
        List.generate(_jumlahTitikWaktu, (_) => TextEditingController());
    _pembacaanTekanan =
        List.generate(_jumlahPembacaanTekanan, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _setPointCtrl.dispose();
    for (final baris in _disk) {
      for (final c in baris) {
        c.dispose();
      }
    }
    for (final c in [..._indikator, ..._suhuRuang, ..._pembacaanTekanan]) {
      c.dispose();
    }
    _uutSettingCtrl.dispose();
    _suhuAwalCtrl.dispose();
    _suhuAkhirCtrl.dispose();
    _rhAwalCtrl.dispose();
    _rhAkhirCtrl.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  List<double?> _kolom(List<TextEditingController> ctrls) =>
      ctrls.map(_num).toList();

  bool _adaIsi(Iterable<double?> xs) => xs.any((x) => x != null);

  /// Rakit payload untuk `POST /calibrations/autoclave/preview`. Blok suhu /
  /// tekanan cuma ikut kalau ada isinya — backend nolak blok tekanan tanpa
  /// pembacaan, dan blok suhu kosong nggak ada gunanya dihitung.
  Map<String, dynamic>? _payload() {
    setState(() => _errorInput = null);

    final setPoint = _num(_setPointCtrl);
    if (setPoint == null) {
      setState(() => _errorInput = 'Set Point wajib diisi.');
      return null;
    }

    final payload = <String, dynamic>{'set_point': setPoint};

    final disk = _disk.map(_kolom).toList();
    final indikator = _kolom(_indikator);
    final suhuRuang = _kolom(_suhuRuang);
    final adaSuhu = disk.any(_adaIsi) || _adaIsi(indikator);
    if (adaSuhu) {
      payload['suhu'] = {
        'disk': disk,
        'indikator': indikator,
        'suhu_ruang': suhuRuang,
      };
    }

    final uut = _num(_uutSettingCtrl);
    final bacaan = _kolom(_pembacaanTekanan);
    if (uut != null && _adaIsi(bacaan)) {
      payload['tekanan'] = {
        'uut_setting': uut,
        'satuan': _satuan,
        'display': _display,
        'pembacaan_standar': bacaan,
      };
    }

    if (!adaSuhu && payload['tekanan'] == null) {
      setState(() => _errorInput =
          'Isi minimal satu blok: data Suhu (disk/indikator) atau Tekanan.');
      return null;
    }

    return payload;
  }

  Future<void> _hitung() async {
    FocusScope.of(context).unfocus();
    final payload = _payload();
    if (payload == null) return;
    await ref.read(autoclavePratinjauProvider.notifier).hitung(payload);
  }

  /// Payload simpan = data ukur (`_payload`) + identitas sesi. Equipment &
  /// tanggal wajib buat kirim; kondisi lingkungan opsional (admin bisa lengkapi).
  Map<String, dynamic>? _payloadSimpan() {
    final ukur = _payload();
    if (ukur == null) return null;

    if (_equipmentId == null) {
      setState(() => _errorInput = 'Pilih Alat (Equipment) dulu sebelum menyimpan.');
      return null;
    }

    return {
      ...ukur,
      'equipment_id': _equipmentId,
      'tanggal_kalibrasi':
          _tanggalKalibrasi.toIso8601String().substring(0, 10),
      if (_num(_suhuAwalCtrl) != null) 'suhu_awal': _num(_suhuAwalCtrl),
      if (_num(_suhuAkhirCtrl) != null) 'suhu_akhir': _num(_suhuAkhirCtrl),
      if (_num(_rhAwalCtrl) != null) 'kelembaban_awal': _num(_rhAwalCtrl),
      if (_num(_rhAkhirCtrl) != null) 'kelembaban_akhir': _num(_rhAkhirCtrl),
    };
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    final payload = _payloadSimpan();
    if (payload == null) return;

    setState(() => _menyimpan = true);
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw Exception('Sesi login habis, masuk lagi.');
      await ref.read(autoclaveServiceProvider).simpan(token, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi Autoklaf terkirim ke admin.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorInput = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggalKalibrasi,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (hasil != null) setState(() => _tanggalKalibrasi = hasil);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(autoclavePratinjauProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lembar Kerja Autoclave'),
        bottom: widget.judulTambahan == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.judulTambahan!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _seksiIdentitas(theme),
          const SizedBox(height: AppSpacing.md),
          _seksi('1. Set Point', [
            _fieldAngka(_setPointCtrl,
                label: 'Set Point (°C)',
                fieldKey: const Key('ac_setpoint')),
          ]),
          const SizedBox(height: AppSpacing.md),
          _seksiSuhu(theme),
          const SizedBox(height: AppSpacing.md),
          _seksiTekanan(theme),
          const SizedBox(height: AppSpacing.lg),
          if (_errorInput != null) ...[
            Text(_errorInput!,
                style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Hitung',
                  variant: AppButtonVariant.secondary,
                  isLoading: status.menghitung,
                  onPressed: _hitung,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Simpan & Kirim',
                  isLoading: _menyimpan,
                  onPressed: _simpan,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (status.gagal != null) ...[
            _KotakError(pesan: '${status.gagal}'),
            const SizedBox(height: AppSpacing.md),
          ],
          if (status.hasil != null)
            AutoclaveHasilPanel(hasil: status.hasil!, judul: 'Hasil Olah Data'),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ---- Bagian input ----

  Widget _seksiIdentitas(ThemeData theme) {
    final alatAsync = ref.watch(equipmentLookupProvider(widget.kategori));

    return _seksi('Identitas Kalibrasi', [
      alatAsync.when(
        data: (list) => DropdownButtonFormField<int>(
          initialValue:
              list.any((a) => a.id == _equipmentId) ? _equipmentId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Alat (Equipment) *',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final EquipmentLookup a in list)
              DropdownMenuItem(
                value: a.id,
                child: Text('${a.namaAlat} — ${a.serialNumber}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _equipmentId = v),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
        error: (e, _) => Text('Gagal muat daftar alat: $e',
            style: TextStyle(color: theme.colorScheme.error)),
      ),
      const SizedBox(height: AppSpacing.sm),
      InkWell(
        onTap: _pilihTanggal,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Tanggal Kalibrasi',
            border: OutlineInputBorder(),
          ),
          child: Text(_tanggalKalibrasi.toIso8601String().substring(0, 10)),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text('Kondisi Lingkungan (opsional)', style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xs),
      Row(children: [
        Expanded(child: _fieldAngka(_suhuAwalCtrl, label: 'T awal (°C)')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _fieldAngka(_suhuAkhirCtrl, label: 'T akhir (°C)')),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(child: _fieldAngka(_rhAwalCtrl, label: 'RH awal (%)')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _fieldAngka(_rhAkhirCtrl, label: 'RH akhir (%)')),
      ]),
    ]);
  }

  /// Lebar satu sel angka.
  ///
  /// Disamakan dengan tabel lembar kerja (`LembarKerjaTabel._lebarSel`) supaya
  /// nggak ada dua ukuran tabel yang beda di aplikasi yang sama.
  static const double _lebarSel = 78;

  /// Lebar kolom label kiri.
  ///
  /// 128, bukan 104: di 104 label "Indikator" dan "Suhu Ruang" membungkus jadi
  /// dua baris di HP sempit, dan baris yang tingginya dipatok bikin
  /// bungkusannya kepotong separuh.
  static const double _lebarLabel = 128;

  /// Tinggi baris dipatok supaya kolom label yang DIAM dan kolom sel yang
  /// DIGESER tetap sebaris. Tanpa tinggi yang sama persis, label "Disk 2" bisa
  /// mendarat di samping angka milik Disk 1 — dan di lembar kalibrasi, baris
  /// yang meleset satu itu salah data, bukan salah tampilan.
  static const double _tinggiBaris = 56;
  static const double _tinggiKepala = 24;

  Widget _seksiSuhu(ThemeData theme) {
    // Sel angkanya digeser mendatar, bukan diperas jadi selebar apa pun yang
    // tersisa. Sebelumnya lima titik waktu dibagi rata di sisa lebar layar:
    // di HP 360 dp itu jadi ~50 dp per kotak — terlalu sempit buat mengetik
    // angka berkoma, apalagi buat memeriksanya lagi sebelum dikirim.
    // Pemisah antara tiga disk dan dua sensor acuan. Tingginya dipatok dan
    // dipasang di KEDUA kolom — kalau cuma di satu, baris di bawahnya langsung
    // meleset sebaris penuh.
    const tinggiPemisah = 9.0;

    Widget kolomLabel(List<String> label) => SizedBox(
      width: _lebarLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _tinggiKepala),
          for (final (i, l) in label.indexed) ...[
            if (i == _jumlahDisk)
              const SizedBox(height: tinggiPemisah, child: Divider()),
            SizedBox(
              height: _tinggiBaris,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l, style: theme.textTheme.bodySmall),
              ),
            ),
          ],
        ],
      ),
    );

    Widget barisSel(List<TextEditingController> ctrls) => SizedBox(
      height: _tinggiBaris,
      child: Row(
        children: [
          for (final c in ctrls)
            SizedBox(
              width: _lebarSel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs / 2,
                  vertical: AppSpacing.xs,
                ),
                child: _fieldAngka(c, dense: true),
              ),
            ),
        ],
      ),
    );

    final label = [
      for (var d = 0; d < _jumlahDisk; d++) 'Disk ${d + 1}',
      'Indikator',
      'Suhu Ruang',
    ];

    final baris = [..._disk, _indikator, _suhuRuang];

    return _seksi('2. Hasil Suhu ($_jumlahDisk disk × $_jumlahTitikWaktu titik waktu)', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kolomLabel(label),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _tinggiKepala,
                    child: Row(
                      children: [
                        for (var i = 1; i <= _jumlahTitikWaktu; i++)
                          SizedBox(
                            width: _lebarSel,
                            child: Center(
                              child: Text(
                                'W$i',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final (i, ctrls) in baris.indexed) ...[
                    if (i == _jumlahDisk)
                      const SizedBox(height: tinggiPemisah, child: Divider()),
                    barisSel(ctrls),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _seksiTekanan(ThemeData theme) {
    return _seksi('3. Hasil Tekanan (1 titik)', [
      Row(
        children: [
          Expanded(
              child: _fieldAngka(_uutSettingCtrl, label: 'UUT Setting')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _satuan,
              decoration: const InputDecoration(labelText: 'Satuan'),
              items: [
                for (final s in _satuanTekanan)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => _satuan = v ?? _satuan),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<String>(
        initialValue: _display,
        decoration: const InputDecoration(labelText: 'Tipe Display'),
        items: [
          for (final s in _displayTekanan)
            DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) => setState(() => _display = v ?? _display),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text('Standar Reading — Pressure Disk Logger (Bar)',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xs),
      // Digeser mendatar, bukan diperas rata seperti dulu — sama alasannya
      // dengan kisi suhu di atas. Lima pembacaan yang dibagi rata di lebar HP
      // jadi ~55 dp per kotak, terlalu sempit buat angka empat desimal seperti
      // `1.231`.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, c) in _pembacaanTekanan.indexed)
              SizedBox(
                width: _lebarSel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs / 2,
                  ),
                  child: _fieldAngka(
                    c,
                    dense: true,
                    fieldKey: i == 0 ? const Key('ac_p0') : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _seksi(String judul, List<Widget> anak) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ...anak,
          ],
        ),
      ),
    );
  }

  Widget _fieldAngka(TextEditingController c,
      {String? label, bool dense = false, Key? fieldKey}) {
    return TextField(
      key: fieldKey,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      textAlign: dense ? TextAlign.center : TextAlign.start,
      // Ikut skala tema, bukan angka lepas: ukuran huruf yang dipatok di satu
      // layar bikin dia beda sendiri waktu skala teks sistem dinaikkan — dan
      // yang menaikkannya biasanya orang yang memang susah membaca angka kecil.
      style: dense ? Theme.of(context).textTheme.bodySmall : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: dense,
        contentPadding: dense
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              )
            : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
class _KotakError extends StatelessWidget {
  const _KotakError({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Gagal menghitung: $pesan',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

