import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/validasi.dart';

/// Apa yang dikirim balik waktu admin nolak lembar kerja.
class KirimanTolak {
  const KirimanTolak({required this.catatan, required this.field});

  /// Prosa buat dibaca teknisi.
  final String catatan;

  /// Kode kolom yang diminta dibetulin — dipakai layar teknisi buat nyorot
  /// persis yang salah. Boleh kosong (nolak tanpa nunjuk kolom tertentu).
  final List<String> field;
}

/// Satu alasan siap-pakai: label yang dilihat admin + kolom yang ditandainya.
class _Alasan {
  const _Alasan(this.label, this.field);

  final String label;
  final List<String> field;
}

/// Lembar "Kembalikan ke teknisi".
///
/// ## Kenapa bukan kotak teks kosong
///
/// Versi sebelumnya: admin nekan TOLAK, muncul dialog dengan kotak kosong,
/// ngetik kalimat dari nol. Padahal temuan pemeriksaannya **udah tertulis di
/// layar tepat di atasnya** — jadi admin disuruh ngetik ulang apa yang mesin
/// udah tahu. Itu yang bikin langkah ini kerasa buntu.
///
/// Sekarang: temuan validator jadi bisa ditap, ditambah alasan lapangan yang
/// sering kepakai. Sekali tap, kalimatnya kesusun sendiri — dan **kode
/// kolomnya ikut kekirim**, jadi waktu teknisi buka lembar kerjanya, kolom
/// yang diminta dibetulin langsung kesorot. Dia nggak perlu nyisir puluhan
/// kolom nyari mana yang dimaksud.
///
/// Kotak teks tetap ada di bawah: alasan siap-pakai nggak akan pernah nyakup
/// semua kasus, dan yang paling penting buat teknisi justru "kenapa"-nya.
class LembarTolak extends StatefulWidget {
  const LembarTolak({super.key, this.temuan = const []});

  /// Temuan dari `GET /calibrations/{id}/validasi` yang lagi tampil di layar.
  final List<Temuan> temuan;

  @override
  State<LembarTolak> createState() => _LembarTolakState();
}

class _LembarTolakState extends State<LembarTolak> {
  final _catatan = TextEditingController();
  final _dipilih = <String>{};

  @override
  void initState() {
    super.initState();
    // Kotak teks ikut dipantau supaya tombol Kirim nyala/mati sesuai isinya —
    // tanpa ini admin bisa ngetik alasan tapi tombolnya tetap mati.
    _catatan.addListener(_perbarui);
  }

  @override
  void dispose() {
    _catatan.removeListener(_perbarui);
    _catatan.dispose();
    super.dispose();
  }

  void _perbarui() => setState(() {});

  /// Alasan lapangan yang berulang — yang nggak bisa dideteksi validator karena
  /// butuh mata orang: angka yang meragukan, identitas yang nggak cocok sama
  /// barang fisiknya.
  List<_Alasan> _alasan(AppLocalizations l10n) => [
    _Alasan(l10n.tolakAlasanSerial, const ['alat_serial_number']),
    _Alasan(l10n.tolakAlasanIdentitas, const [
      'alat_model',
      'alat_merk',
      'alat_serial_number',
    ]),
    _Alasan(l10n.tolakAlasanPemilik, const ['pemilik_nama', 'pemilik_alamat']),
    _Alasan(l10n.tolakAlasanEnv, const [
      'suhu_awal',
      'suhu_akhir',
      'kelembaban_awal',
      'kelembaban_akhir',
    ]),
    _Alasan(l10n.tolakAlasanThermohygro, const ['thermohygro_standard_id']),
    _Alasan(l10n.tolakAlasanPembacaan, const []),
    _Alasan(l10n.tolakAlasanUsageCheck, const []),
  ];

  /// Catatan yang bakal diterima teknisi. Ditampilin apa adanya sebelum
  /// dikirim — admin nggak boleh nebak-nebak isi pesan yang dia kirim sendiri.
  String _susunCatatan(AppLocalizations l10n) {
    final baris = <String>[
      for (final t in widget.temuan)
        if (_dipilih.contains('temuan:${t.kode}')) '• ${t.pesan}',
      for (final a in _alasan(l10n))
        if (_dipilih.contains('alasan:${a.label}')) '• ${a.label}',
    ];

    final tambahan = _catatan.text.trim();
    if (tambahan.isNotEmpty) baris.add(tambahan);

    return baris.join('\n');
  }

  /// Kode kolom dari semua alasan yang dipilih, tanpa kembar.
  List<String> _fieldTerpilih(AppLocalizations l10n) => {
    for (final a in _alasan(l10n))
      if (_dipilih.contains('alasan:${a.label}')) ...a.field,
  }.toList();

  void _tukar(String kunci) => setState(() {
    _dipilih.contains(kunci) ? _dipilih.remove(kunci) : _dipilih.add(kunci);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final catatan = _susunCatatan(l10n);

    // Backend minta minimal 5 karakter. Dijaga di sini juga supaya tombolnya
    // mati dari awal — bukan nyala, ditekan, lalu dimarahin snackbar.
    final bolehKirim = catatan.trim().length >= 5;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tolakJudul,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.perhitKonfirmasiBatal,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  l10n.tolakPetunjuk,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Temuan mesin duluan: itu yang paling nggak terbantahkan, dan
                // paling sering jadi alasan sebenernya.
                if (widget.temuan.isNotEmpty) ...[
                  Text(
                    l10n.tolakDariPemeriksaan,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final t in widget.temuan)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _dipilih.contains('temuan:${t.kode}'),
                      onChanged: (_) => _tukar('temuan:${t.kode}'),
                      title: Text(t.pesan, style: theme.textTheme.bodySmall),
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text(l10n.tolakAlasanUmum, style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final a in _alasan(l10n))
                      FilterChip(
                        label: Text(a.label),
                        selected: _dipilih.contains('alasan:${a.label}'),
                        onSelected: (_) => _tukar('alasan:${a.label}'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _catatan,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.tolakCatatanTambahan,
                    hintText: l10n.tolakCatatanHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Pratinjau: admin lihat persis kalimat yang bakal diterima
                // teknisi sebelum ngirim.
                if (catatan.isNotEmpty) ...[
                  Text(
                    l10n.tolakPratinjau,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(catatan, style: theme.textTheme.bodySmall),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

          Material(
            elevation: 8,
            color: theme.colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  icon: const Icon(Icons.reply),
                  label: Text(l10n.tolakKirim),
                  onPressed: bolehKirim
                      ? () => Navigator.of(context).pop(
                          KirimanTolak(
                            catatan: catatan,
                            field: _fieldTerpilih(l10n),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
