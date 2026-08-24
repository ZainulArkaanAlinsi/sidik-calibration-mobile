import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../grid_sensor_state.dart';

/// Layar isian GRID SENSOR: satu set point = banyak termokopel × banyak
/// pembacaan, plus baris Indikator & Suhu Ruang.
///
/// Susunannya SEBARIS-SEBARIS ngikut kertas, sama alasannya dengan
/// [LembarKerjaMatriks]: teknisi mengisi layar ini sambil memegang kertas yang
/// barusan dia tulis di chamber, dan matanya lompat baris per baris.
///
/// Yang beda dari matriks — dan ini yang bikin dia butuh widget sendiri —
/// **barisnya nggak dipatok backend**. Berapa termokopel dipasang dan nomor
/// berapa saja baru ketahuan di lapangan, jadi barisnya bisa ditambah,
/// dikurangi, dan dinomori bebas. Nomor itu pula yang menentukan koreksi mana
/// yang dipakai dan sensor mana jadi Sensor Acuan — bukan urutan barisnya di
/// layar.
class LembarKerjaGrid extends StatefulWidget {
  const LembarKerjaGrid({
    super.key,
    required this.state,
    required this.satuanSuhu,
    required this.onBerubah,
    this.merkKalibrator,
  });

  final GridSensorState state;

  /// `°C` — dari `satuan_suhu` lembar.
  final String satuanSuhu;

  final VoidCallback onBerubah;

  /// Merk standar yang dicentang teknisi. Menentukan kolom Channel muncul atau
  /// nggak: koreksi Recorder (GL840) dibaca per kanal, Constant & Yokogawa
  /// nggak. Null = belum milih standar.
  final String? merkKalibrator;

  @override
  State<LembarKerjaGrid> createState() => _LembarKerjaGridState();
}

class _LembarKerjaGridState extends State<LembarKerjaGrid> {
  static const _lebarNo = 62.0;
  static const _lebarKanal = 62.0;
  static const _lebarKolom = 78.0;

  bool get _pakaiKanal => widget.state.bentuk.butuhChannel(widget.merkKalibrator);

  /// Sekali sentuh = hitung ulang Sensor Acuan, nomor kembar, dan peringatan.
  ///
  /// Harus setState di sini, bukan cuma memanggil [widget.onBerubah]: yang
  /// berubah bukan cuma payload di luar, tapi apa yang digambar baris ini —
  /// lencana "Acuan" pindah begitu nomor terkecil diketik atau dikosongkan.
  void _berubah() {
    widget.state.bacaUlang();
    setState(() {});
    widget.onBerubah();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bentuk = widget.state.bentuk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bentuk.catatanSensorAcuan.isNotEmpty)
          _Catatan(teks: bentuk.catatanSensorAcuan),

        for (var i = 0; i < widget.state.setPoint.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          _KartuSetPoint(
            nomor: i + 1,
            sp: widget.state.setPoint[i],
            satuanSuhu: widget.satuanSuhu,
            pakaiKanal: _pakaiKanal,
            merkKalibrator: widget.merkKalibrator,
            lebarNo: _lebarNo,
            lebarKanal: _lebarKanal,
            lebarKolom: _lebarKolom,
            onBerubah: _berubah,
            bisaDihapus: widget.state.setPoint.length > 1,
            onHapus: () {
              setState(() => widget.state.hapusSetPoint(i));
              widget.onBerubah();
            },
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('grid_tambah_set_point'),
            onPressed: () {
              setState(widget.state.tambahSetPoint);
              widget.onBerubah();
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Set Point'),
          ),
        ),

        // Peringatan dikumpulkan di BAWAH, sesudah semua set point — bukan
        // dilempar sebagai error waktu kirim. Tombol kirim nggak pernah
        // dikunci di lembar kerja; ini pemberitahuan supaya teknisi sempat
        // melengkapi, bukan penjagaan.
        Builder(
          builder: (context) {
            final pesan = widget.state.peringatan(widget.merkKalibrator);
            if (pesan.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: _PanelPeringatan(pesan: pesan, theme: theme),
            );
          },
        ),
      ],
    );
  }
}

class _KartuSetPoint extends StatelessWidget {
  const _KartuSetPoint({
    required this.nomor,
    required this.sp,
    required this.satuanSuhu,
    required this.pakaiKanal,
    required this.merkKalibrator,
    required this.lebarNo,
    required this.lebarKanal,
    required this.lebarKolom,
    required this.onBerubah,
    required this.bisaDihapus,
    required this.onHapus,
  });

  final int nomor;
  final SetPointGridState sp;
  final String satuanSuhu;
  final bool pakaiKanal;
  final String? merkKalibrator;
  final double lebarNo;
  final double lebarKanal;
  final double lebarKolom;
  final VoidCallback onBerubah;
  final bool bisaDihapus;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acuan = sp.nomorAcuan;
    final kembar = sp.nomorKembar.toSet();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Set Point $nomor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 92,
                  child: _KotakAngka(
                    key: Key('grid_titik_$nomor'),
                    controller: sp.titikCtl,
                    onBerubah: onBerubah,
                    hint: satuanSuhu,
                  ),
                ),
                const Spacer(),
                if (bisaDihapus)
                  IconButton(
                    tooltip: 'Hapus set point ini',
                    onPressed: onHapus,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kepala(theme),
                  for (var i = 0; i < sp.sensor.length; i++)
                    _barisSensor(
                      context,
                      theme,
                      sp.sensor[i],
                      i,
                      acuan: acuan,
                      kembar: kembar,
                    ),
                  if (sp.bentuk.barisIndikator)
                    _barisDeret(
                      theme,
                      'Indikator',
                      sp.indikator,
                      kunci: 'grid_indikator_$nomor',
                    ),
                  if (sp.bentuk.barisSuhuRuang)
                    _barisDeret(
                      theme,
                      'Suhu Ruang',
                      sp.suhuRuang,
                      kunci: 'grid_suhu_ruang_$nomor',
                      redup: true,
                    ),
                ],
              ),
            ),

            if (sp.bentuk.barisSuhuRuang)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Baris Suhu Ruang dicatat di lembar, tapi belum dikirim ke '
                  'server — backend belum punya tempat menampungnya.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('grid_tambah_sensor_$nomor'),
                onPressed: () {
                  sp.tambahSensor();
                  onBerubah();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah termokopel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sel(ThemeData theme, String teks, double lebar, {bool tebal = false}) =>
      Container(
        width: lebar,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        alignment: Alignment.center,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          teks,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: tebal ? FontWeight.w600 : null,
          ),
        ),
      );

  Widget _kepala(ThemeData theme) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sel(theme, 'No. TC', lebarNo, tebal: true),
        if (pakaiKanal) _sel(theme, 'CH', lebarKanal, tebal: true),
        for (final n in sp.bentuk.pengulangan)
          _sel(theme, '$n', lebarKolom, tebal: true),
        _sel(theme, '', 48),
      ],
    ),
  );

  Widget _barisSensor(
    BuildContext context,
    ThemeData theme,
    BarisSensorState s,
    int index, {
    required int? acuan,
    required Set<int> kembar,
  }) {
    final no = s.no;
    final iniAcuan = no != null && no == acuan;
    final iniKembar = no != null && kembar.contains(no);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: lebarNo,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _KotakAngka(
                key: Key('grid_no_${nomor}_$index'),
                controller: s.noCtl,
                onBerubah: onBerubah,
                bulat: true,
                galat: iniKembar,
              ),
            ),
          ),
          if (pakaiKanal)
            SizedBox(
              width: lebarKanal,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  key: Key('grid_ch_${nomor}_$index'),
                  controller: s.channelCtl,
                  onBerubah: onBerubah,
                  bulat: true,
                  // Kanal kosong padahal kalibratornya Recorder = set point-nya
                  // nggak dihitung. Ditandai di selnya, bukan cuma di panel
                  // peringatan jauh di bawah.
                  galat: s.jumlahTerisi > 0 && s.channel == null,
                ),
              ),
            ),
          for (var k = 0; k < s.pembacaanCtl.length; k++)
            SizedBox(
              width: lebarKolom,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  key: Key('grid_baca_${nomor}_${index}_$k'),
                  controller: s.pembacaanCtl[k],
                  onBerubah: onBerubah,
                ),
              ),
            ),
          SizedBox(
            width: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iniAcuan)
                  Tooltip(
                    message: 'Sensor Acuan — nomor terkecil yang terisi',
                    child: Icon(
                      Icons.star,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else if (s.pembacaanKurang)
                  Tooltip(
                    message:
                        'Baru ${s.jumlahTerisi} pembacaan — minimal 4 supaya '
                        'set point ini ikut dihitung',
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  IconButton(
                    key: Key('grid_hapus_sensor_${nomor}_$index'),
                    tooltip: 'Hapus baris',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      sp.hapusSensor(index);
                      onBerubah();
                    },
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisDeret(
    ThemeData theme,
    String label,
    BarisDeretState b, {
    required String kunci,
    bool redup = false,
  }) {
    final lebarKiri = lebarNo + (pakaiKanal ? lebarKanal : 0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: lebarKiri,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: redup ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          for (var k = 0; k < b.ctl.length; k++)
            SizedBox(
              width: lebarKolom,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  key: Key('${kunci}_$k'),
                  controller: b.ctl[k],
                  onBerubah: onBerubah,
                ),
              ),
            ),
          SizedBox(width: 48, child: Container()),
        ],
      ),
    );
  }
}

class _KotakAngka extends StatelessWidget {
  const _KotakAngka({
    super.key,
    required this.controller,
    required this.onBerubah,
    this.bulat = false,
    this.galat = false,
    this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onBerubah;

  /// Kotak nomor (No. TC / CH) — bilangan bulat, tanpa koma & tanpa minus.
  final bool bulat;

  final bool galat;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      keyboardType: bulat
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          bulat ? RegExp(r'[0-9]') : RegExp(r'[0-9.,\-]'),
        ),
      ],
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: const OutlineInputBorder(),
        enabledBorder: galat
            ? OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.error),
              )
            : null,
      ),
      onChanged: (_) => onBerubah(),
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(teks, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _PanelPeringatan extends StatelessWidget {
  const _PanelPeringatan({required this.pesan, required this.theme});

  final List<String> pesan;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Kalau dikirim sekarang, ini nggak ikut dihitung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final p in pesan)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $p',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set point-nya tetap TERSIMPAN — pembacaannya nggak hilang, dan '
            'set point lain di sesi ini tetap dihitung.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
