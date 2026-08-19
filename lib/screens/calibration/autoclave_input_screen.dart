import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/angka.dart';
import '../../models/autoclave_hasil.dart';
import '../../providers/autoclave_provider.dart';
import '../../widgets/app_button.dart';

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
  const AutoclaveInputScreen({super.key, this.judulTambahan});

  /// Nama alat, buat subjudul app bar (mis. "Autoclave").
  final String? judulTambahan;

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
          _seksi('1. Set Point', [
            _fieldAngka(_setPointCtrl, label: 'Set Point (°C)'),
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
          AppButton(
            label: 'Hitung',
            isLoading: status.menghitung,
            onPressed: _hitung,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (status.gagal != null) ...[
            _KotakError(pesan: '${status.gagal}'),
            const SizedBox(height: AppSpacing.md),
          ],
          if (status.hasil != null) _HasilPanel(hasil: status.hasil!),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ---- Bagian input ----

  Widget _seksiSuhu(ThemeData theme) {
    final header = ['', for (var i = 1; i <= _jumlahTitikWaktu; i++) 'W$i'];

    Widget baris(String label, List<TextEditingController> ctrls) {
      return Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: theme.textTheme.bodySmall)),
          for (final c in ctrls)
            Expanded(child: Padding(
              padding: const EdgeInsets.all(2),
              child: _fieldAngka(c, dense: true),
            )),
        ],
      );
    }

    return _seksi('2. Hasil Suhu (3 disk × $_jumlahTitikWaktu titik waktu)', [
      Row(
        children: [
          for (final h in header)
            h.isEmpty
                ? const SizedBox(width: 96)
                : Expanded(
                    child: Center(
                        child: Text(h, style: theme.textTheme.labelSmall))),
        ],
      ),
      const SizedBox(height: 4),
      for (var d = 0; d < _jumlahDisk; d++) baris('Disk ${d + 1}', _disk[d]),
      const Divider(),
      baris('Indikator', _indikator),
      baris('Suhu Ruang', _suhuRuang),
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
      const SizedBox(height: 4),
      Row(
        children: [
          for (final c in _pembacaanTekanan)
            Expanded(child: Padding(
              padding: const EdgeInsets.all(2),
              child: _fieldAngka(c, dense: true),
            )),
        ],
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
      {String? label, bool dense = false}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      textAlign: dense ? TextAlign.center : TextAlign.start,
      style: dense ? const TextStyle(fontSize: 13) : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: dense,
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
            : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ---- Panel hasil ----

class _HasilPanel extends StatelessWidget {
  const _HasilPanel({required this.hasil});

  final AutoclaveHasil hasil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hasil Olah Data', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (hasil.suhu != null) _kartuSuhu(context, hasil.suhu!),
        if (hasil.suhu != null) const SizedBox(height: AppSpacing.md),
        if (hasil.tekanan != null) _kartuTekanan(context, hasil.tekanan!),
      ],
    );
  }

  Widget _kartuSuhu(BuildContext context, AutoclaveSuhu s) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A) Sebaran Suhu', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Table(
              border: TableBorder.all(color: theme.dividerColor),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _barisTabel(
                    ['Sensor', 'Std Terkoreksi', 'Koreksi', 'ΔT'],
                    header: true),
                for (final sen in s.sensor)
                  _barisTabel([
                    '${sen.no}',
                    _f(sen.standarTerkoreksi, 3),
                    _f(sen.koreksi, 3),
                    _f(sen.deltaT, 3),
                  ]),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('B) Kinerja Autoklaf', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _kv('Suhu Indikator (rata)', _f(s.indikatorRata, 2), '°C'),
            _kv('Kestabilan (SS)', _f(s.kestabilan, 3), '°C'),
            _kv('Keseragaman (KS)', _f(s.keseragaman, 3), '°C'),
            _kv('Variasi Keseluruhan (VK)', _f(s.variasi, 3), '°C'),
            const Divider(),
            _kv('U95%', '± ${_f(s.u95, 4)}', '°C', tebal: true),
            _kv('Faktor cakupan (k)', _f(s.k, 4), ''),
          ],
        ),
      ),
    );
  }

  Widget _kartuTekanan(BuildContext context, AutoclaveTekanan t) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('C) Tekanan (${t.satuan})',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _kv('UUT Setting', _f(t.uutSetting, 4), t.satuan),
            _kv('Standard Value', _f(t.standarTerkoreksi, 4), t.satuan),
            _kv('Correction', _f(t.koreksi, 4), t.satuan),
            const Divider(),
            _kv('U95%', '± ${_f(t.u95, 4)}', t.satuan, tebal: true),
            _kv('Faktor cakupan (k)', _f(t.k, 4), ''),
          ],
        ),
      ),
    );
  }

  TableRow _barisTabel(List<String> sel, {bool header = false}) {
    return TableRow(
      children: [
        for (final s in sel)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(s,
                style: header
                    ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                    : const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _kv(String k, String v, String satuan, {bool tebal = false}) {
    final gaya = tebal ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(k, style: gaya)),
          Text(satuan.isEmpty ? v : '$v $satuan', style: gaya),
        ],
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

/// Format angka hasil buat tampilan. Nol belakang dipertahankan sampai
/// [desimal] (ikut gaya sertifikat lab), tapi angka null jadi "—".
String _f(double? v, int desimal) =>
    v == null ? '—' : formatNilai(v, desimalMin: desimal, desimalMaks: desimal);
