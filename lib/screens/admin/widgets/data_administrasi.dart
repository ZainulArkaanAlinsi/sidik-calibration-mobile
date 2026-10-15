import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/calibration_detail.dart' show CalibrationDetail;
import '../../../models/perhitungan.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/lembar_kerja_provider.dart';
import '../../../providers/perhitungan_provider.dart';
import '../../../providers/ruangan_provider.dart';
import '../../../widgets/app_button.dart';
import '../../auth/widgets/neu.dart';

/// Panjang maksimal Order Number — sama dengan `max:100` di
/// `CalibrationController::updateAdminFields`.
const panjangMaksNomorOrder = 100;

/// Minta Order Number lewat dialog. `null` = dibatalkan.
///
/// Dipakai dua tempat yang sama-sama menyetujui sesi: tombol Ubah di kartu
/// [KartuDataAdministrasi] dan tombol Setujui (layar Perhitungan & kartu
/// Antrean) waktu Order Number-nya masih kosong — server menolak approve tanpa
/// nomor ini (422 `nomor_order_wajib`, K-49-14).
Future<String?> mintaNomorOrder(BuildContext context, {String? awal}) =>
    showDialog<String>(
      context: context,
      builder: (_) => DialogNomorOrder(awal: awal),
    );

class DialogNomorOrder extends StatefulWidget {
  const DialogNomorOrder({super.key, this.awal});

  final String? awal;

  @override
  State<DialogNomorOrder> createState() => _DialogNomorOrderState();
}

class _DialogNomorOrderState extends State<DialogNomorOrder> {
  late final _isian = TextEditingController(text: widget.awal ?? '');
  bool _kosong = false;

  @override
  void dispose() {
    _isian.dispose();
    super.dispose();
  }

  void _simpan() {
    final teks = _isian.text.trim();
    if (teks.isEmpty) {
      setState(() => _kosong = true);
      return;
    }
    Navigator.of(context).pop(teks);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.adminNomorOrderJudul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminNomorOrderPetunjuk,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('isian-nomor-order'),
            controller: _isian,
            autofocus: true,
            maxLength: panjangMaksNomorOrder,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _simpan(),
            onChanged: (_) {
              if (_kosong) setState(() => _kosong = false);
            },
            decoration: InputDecoration(
              labelText: l10n.perhitNomorOrder,
              errorText: _kosong ? l10n.adminNomorOrderKosong : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.custCancel),
        ),
        FilledButton(
          key: const ValueKey('simpan-nomor-order'),
          onPressed: _simpan,
          child: Text(l10n.perhitSimpanAdmin),
        ),
      ],
    );
  }
}

/// Kartu "Data administrasi" di layar periksa (Perhitungan): Order Number,
/// metode, ruangan, tanggal terima, dan thermohygro — kolom yang diisi Master
/// Data (admin) atau super admin lewat `PATCH /calibrations/{id}/admin`, BUKAN
/// teknisi (K-49-14).
///
/// Thermohygro cuma DISEBUT di sini; pemilihnya tetap satu, di blok Kondisi
/// Lingkungan (`BlokKondisi`), tepat di atas koreksi & U95% yang dia isi. Dua
/// pemilih untuk satu kolom cuma mengundang pertanyaan mana yang berlaku.
///
/// Nilai sekarang dibaca dari detail sesi (`GET /calibrations/{id}`); daftar
/// metode & ruangan baru dimuat waktu tombol Ubah-nya ditekan, jadi membuka
/// layar periksa tidak menambah dua permintaan yang jarang dipakai.
class KartuDataAdministrasi extends ConsumerStatefulWidget {
  const KartuDataAdministrasi({
    super.key,
    required this.calibrationId,
    required this.kondisi,
    this.tanggalKalibrasi,
    this.onBukaLembar,
  });

  final int calibrationId;
  final KondisiLingkungan kondisi;

  /// Batas atas tanggal terima (`before_or_equal:tanggal_kalibrasi` di server).
  final String? tanggalKalibrasi;

  /// Buka lembar kerja teknisi di layar yang sama dengan teknisi. `null` =
  /// tombolnya tidak digambar.
  final VoidCallback? onBukaLembar;

  @override
  ConsumerState<KartuDataAdministrasi> createState() =>
      _KartuDataAdministrasiState();
}

class _KartuDataAdministrasiState extends ConsumerState<KartuDataAdministrasi> {
  bool _sibuk = false;

  AksiAdmin get _aksi => ref.read(aksiAdminProvider(widget.calibrationId));

  Future<void> _simpan(Future<void> Function(AksiAdmin aksi) kerja) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sibuk = true);
    try {
      await kerja(_aksi);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.perhitAdminTersimpan)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _ubahNomorOrder(String? sekarang) async {
    final nomor = await mintaNomorOrder(context, awal: sekarang);
    if (nomor == null || !mounted) return;
    await _simpan((a) => a.simpanKolomAdmin(nomorOrder: nomor));
  }

  Future<void> _ubahMetode() async {
    final id = await _pilihDariDaftar<int>(
      judul: AppLocalizations.of(context).adminMetode,
      muat: () async {
        final daftar = await ref.read(daftarMetodeProvider.future);
        return [
          for (final m in daftar)
            if (m.aktif) (m.id, m.kodeLengkap, m.nama),
        ];
      },
    );
    if (id == null || !mounted) return;
    await _simpan((a) => a.simpanKolomAdmin(calibrationMethodId: id));
  }

  Future<void> _ubahRuangan() async {
    final id = await _pilihDariDaftar<int>(
      judul: AppLocalizations.of(context).adminRuangan,
      muat: () async {
        final daftar = await ref.read(roomListProvider.future);
        return [
          for (final r in daftar)
            if (r.aktif) (r.id, r.label, null),
        ];
      },
    );
    if (id == null || !mounted) return;
    await _simpan((a) => a.simpanKolomAdmin(roomId: id));
  }

  Future<void> _ubahTanggalTerima(String? sekarang) async {
    final sekarangTgl = DateTime.tryParse(sekarang ?? '');
    final batas =
        DateTime.tryParse(widget.tanggalKalibrasi ?? '') ?? DateTime.now();
    final awal = sekarangTgl != null && !sekarangTgl.isAfter(batas)
        ? sekarangTgl
        : batas;

    final dipilih = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(2020),
      lastDate: batas,
    );
    if (dipilih == null || !mounted) return;

    final teks =
        '${dipilih.year.toString().padLeft(4, '0')}-'
        '${dipilih.month.toString().padLeft(2, '0')}-'
        '${dipilih.day.toString().padLeft(2, '0')}';
    await _simpan((a) => a.simpanKolomAdmin(tanggalTerima: teks));
  }

  /// Dialog pilih satu dari daftar (id, judul, keterangan).
  Future<T?> _pilihDariDaftar<T>({
    required String judul,
    required Future<List<(T, String, String?)>> Function() muat,
  }) => showDialog<T>(
    context: context,
    builder: (konteks) {
      final l10n = AppLocalizations.of(konteks);
      return AlertDialog(
        title: Text(judul),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        content: SizedBox(
          width: 360,
          child: FutureBuilder<List<(T, String, String?)>>(
            future: muat(),
            builder: (_, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(l10n.adminGagalMuat),
                );
              }
              final daftar = snap.data;
              if (daftar == null) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (daftar.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(l10n.adminPilihKosong),
                );
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final (id, label, ket) in daftar)
                    ListTile(
                      title: Text(label),
                      subtitle: ket == null || ket == label ? null : Text(ket),
                      onTap: () => Navigator.of(konteks).pop(id),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(konteks).pop(),
            child: Text(l10n.custCancel),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = NeuColors.of(context);
    final detail = ref.watch(calibrationDetailProvider(widget.calibrationId));
    final adm = detail.value?.administrasi;

    Widget baris(
      String label,
      String? nilai, {
      required VoidCallback? onUbah,
      Key? kunciUbah,
      bool wajib = false,
    }) {
      final kosong = nilai == null || nilai.isEmpty;
      final warnaKosong = wajib
          ? AppColors.statusPeringatan(context)
          : c.textMuted;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 128,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ),
            Expanded(
              child: Text(
                kosong ? (wajib ? l10n.adminBelumDiisi : '—') : nilai,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: kosong ? warnaKosong : c.text,
                ),
              ),
            ),
            TextButton(
              key: kunciUbah,
              onPressed: _sibuk ? null : onUbah,
              child: Text(l10n.adminUbah),
            ),
          ],
        ),
      );
    }

    final bolehUbah = adm != null;

    return NeuRaised(
      key: const ValueKey('kartu-data-administrasi'),
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminDataJudul.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: c.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: c.darkShadow.withValues(alpha: 0.35)),
          const SizedBox(height: AppSpacing.sm),
          if (detail.hasError && adm == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminGagalMuat,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.statusPeringatan(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(
                    calibrationDetailProvider(widget.calibrationId),
                  ),
                  child: Text(l10n.folderRetry),
                ),
              ],
            )
          else if (adm == null)
            const LinearProgressIndicator()
          else ...[
            baris(
              l10n.perhitNomorOrder,
              adm.nomorOrder,
              wajib: true,
              kunciUbah: const ValueKey('ubah-nomor-order'),
              onUbah: bolehUbah ? () => _ubahNomorOrder(adm.nomorOrder) : null,
            ),
            baris(
              l10n.adminMetode,
              adm.metodeLabel,
              onUbah: bolehUbah ? _ubahMetode : null,
            ),
            baris(
              l10n.adminRuangan,
              adm.ruanganLabel,
              onUbah: bolehUbah ? _ubahRuangan : null,
            ),
            baris(
              l10n.adminTanggalTerima,
              adm.tanggalTerima,
              onUbah: bolehUbah
                  ? () => _ubahTanggalTerima(adm.tanggalTerima)
                  : null,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 128,
                  child: Text(
                    l10n.adminThermohygro,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.kondisi.thermohygro ?? '—',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: widget.kondisi.thermohygro == null
                          ? c.textMuted
                          : c.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.adminThermohygroDiBlokKondisi,
              style: TextStyle(fontSize: 11, color: c.textMuted),
            ),
          ),
          if (widget.onBukaLembar != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              key: const ValueKey('buka-lembar-teknisi'),
              label: l10n.adminBukaLembar,
              icon: Icons.edit_note,
              variant: AppButtonVariant.secondary,
              onPressed: widget.onBukaLembar,
            ),
          ],
        ],
      ),
    );
  }
}

/// Order Number pasti kosong menurut detail sesi yang SUDAH termuat.
///
/// Belum termuat / gagal = `false`: tombol Setujui tidak menahan berdasarkan
/// tebakan. Server tetap menjaga (422 `nomor_order_wajib`) dan layar
/// menanganinya dengan meminta nomornya.
bool perluNomorOrder(CalibrationDetail? detail) =>
    detail?.administrasi.perluNomorOrder ?? false;
