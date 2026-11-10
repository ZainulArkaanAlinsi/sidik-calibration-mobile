import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';

/// Konvensi warna isian lembar kerja — SATU tempat, dipakai semua lembar.
///
/// Empat keadaan, dan warna tidak pernah jadi satu-satunya penanda: isian
/// wajib selalu membawa tanda `*` (di label, atau di hint untuk sel tabel yang
/// tidak punya label).
///
///  - [StatusIsian.wajibKosong]: latar oranye lembut + tepi tegas.
///  - [StatusIsian.wajibTerisi]: latar hijau sangat lembut.
///  - [StatusIsian.opsional]: tampilan biasa, tanpa warna.
///  - [StatusIsian.otomatis]: abu kebiruan lembut — dihitung/diisi sistem dan
///    tidak ada yang perlu dilengkapi teknisi (hasil hitung server, Order
///    Number baca-saja).
///
/// ## Identitas alat: warna menurut ISI
///
/// Kolom identitas yang tercetak di sertifikat (nomor seri, merek, tipe,
/// kapasitas, resolusi, lokasi, tanggal kalibrasi, pelanggan — daftar di
/// `peran_isian_identitas.dart`) memakai status menurut ISI-nya, baik yang
/// diketik teknisi maupun yang otomatis dari data alat: terisi = hijau,
/// kosong = oranye + `*`. Untuk yang otomatis, hijau membawa ikon kunci kecil
/// (baca-saja) dan oranye membawa petunjuk "Lengkapi di data alat" —
/// kosongnya datang dari data alat, bukan dari ketikan di sini.
///
/// Caranya: [dekorasiIsian] dipanggil dengan `wajib: true` DAN
/// `otomatis: true`. `otomatis` tanpa `wajib` tetap abu kebiruan.
///
/// ## Hanya di layar INPUT
///
/// Warna baru menyala di bawah [WarnaIsianScope]. Tanpa scope itu (layar
/// periksa, detail, atau baca-saja yang kebetulan memakai widget isian yang
/// sama), [dekorasiIsian] mengembalikan dekorasi apa adanya.
///
/// ## Apa arti "wajib"
///
/// Isian yang MEMANG punya gerbang di kode (`LembarKerjaScreen._submit`),
/// yang ditandai `wajib: true` oleh server, atau identitas alat di atas
/// (hanya penanda; kolom kosongnya TIDAK menahan kirim). Server hari ini
/// selalu mengirim `wajib: false` untuk semua kolom, jadi tanpa penanda dari
/// kode, sebuah isian tampil opsional — bukan ditebak wajib.
enum StatusIsian { wajibKosong, wajibTerisi, opsional, otomatis }

StatusIsian statusIsian({
  required bool wajib,
  required bool terisi,
  bool otomatis = false,
}) {
  // `otomatis` + `wajib` = identitas dari data alat: menurut isi, bukan abu.
  if (!wajib) return otomatis ? StatusIsian.otomatis : StatusIsian.opsional;

  return terisi ? StatusIsian.wajibTerisi : StatusIsian.wajibKosong;
}

/// Pasangan latar + tepi untuk satu keadaan, di satu kecerahan tema.
class WarnaStatusIsian {
  const WarnaStatusIsian({required this.latar, required this.tepi});

  final Color latar;
  final Color tepi;
}

/// Token warna terang + gelap. Dipatok (bukan diambil dari ColorScheme): oranye
/// "wajib" harus beda jelas dari merah `error` dan dari kuning "perlu dicek"
/// milik pindai (`kuningPerluDicek`) di layar HP di bawah lampu bengkel.
class PaletIsian {
  const PaletIsian._();

  static const _terang = {
    StatusIsian.wajibKosong: WarnaStatusIsian(
      latar: Color(0xFFFFE8CC),
      tepi: Color(0xFFB45309),
    ),
    StatusIsian.wajibTerisi: WarnaStatusIsian(
      latar: Color(0xFFE6F4EA),
      tepi: Color(0xFF81C995),
    ),
    StatusIsian.otomatis: WarnaStatusIsian(
      latar: Color(0xFFE8EEF6),
      tepi: Color(0xFF9FB3C8),
    ),
  };

  static const _gelap = {
    StatusIsian.wajibKosong: WarnaStatusIsian(
      latar: Color(0xFF4A3118),
      tepi: Color(0xFFFFB366),
    ),
    StatusIsian.wajibTerisi: WarnaStatusIsian(
      latar: Color(0xFF1D3A28),
      tepi: Color(0xFF4F8F63),
    ),
    StatusIsian.otomatis: WarnaStatusIsian(
      latar: Color(0xFF28323F),
      tepi: Color(0xFF5B6B7E),
    ),
  };

  /// `null` untuk [StatusIsian.opsional] — tidak diwarnai.
  static WarnaStatusIsian? untuk(Brightness kecerahan, StatusIsian status) =>
      (kecerahan == Brightness.dark ? _gelap : _terang)[status];
}

/// Menyalakan warna isian untuk semua widget di bawahnya.
class WarnaIsianScope extends InheritedWidget {
  const WarnaIsianScope({super.key, required super.child});

  /// `true` hanya kalau ada [WarnaIsianScope] di atas [context].
  static bool aktif(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WarnaIsianScope>() != null;

  @override
  bool updateShouldNotify(WarnaIsianScope oldWidget) => false;
}

/// Dekorasi isian menurut konvensi di atas.
///
/// [base] = dekorasi asli kotaknya (label, satuan, helper, `isDense`, …);
/// hasilnya salinan dengan latar/tepi/tanda wajib ditambahkan.
///
/// [tandaDiHint]: untuk sel tanpa label (tabel) — tanda `*` ditaruh di hint
/// selama kosong, karena label-nya tidak ada tempat menempelkan bintang.
///
/// [petunjukKosong]: kalimat pendek yang menggantikan helper selama isian
/// wajib masih KOSONG (mis. "Lengkapi di data alat" untuk identitas otomatis).
/// Satuan tetap ikut kalau [base] punya `suffixText`. Sudah dilokalkan oleh
/// pemanggil — helper ini tidak mengenal bahasa.
///
/// Identitas otomatis (`wajib: true` + `otomatis: true`) yang TERISI membawa
/// ikon kunci kecil ([kunciIkonIdentitas]) kalau [base] belum punya
/// `suffixIcon`.
InputDecoration dekorasiIsian(
  BuildContext context, {
  required bool wajib,
  required bool terisi,
  bool otomatis = false,
  InputDecoration base = const InputDecoration(),
  bool tandaDiHint = false,
  String? petunjukKosong,
}) {
  if (!WarnaIsianScope.aktif(context)) return base;

  final status = statusIsian(wajib: wajib, terisi: terisi, otomatis: otomatis);
  final warna = PaletIsian.untuk(Theme.of(context).brightness, status);
  if (warna == null) return base;

  final tebal = status == StatusIsian.wajibKosong;
  OutlineInputBorder tepi(double lebar) => OutlineInputBorder(
    borderSide: BorderSide(color: warna.tepi, width: lebar),
  );

  final tandaWajib = status == StatusIsian.otomatis ? null : ' *';
  final label = base.labelText;
  final hint = base.hintText;

  // Identitas otomatis: kunci kalau terisi (baca-saja), petunjuk kalau kosong.
  final identitasOtomatis = wajib && otomatis;
  final kunci = identitasOtomatis && terisi && base.suffixIcon == null;
  final petunjuk = (status == StatusIsian.wajibKosong) ? petunjukKosong : null;

  return base.copyWith(
    filled: true,
    fillColor: warna.latar,
    enabledBorder: tepi(tebal ? 2 : 1),
    focusedBorder: tepi(2.5),
    labelText: (tandaWajib != null && label != null)
        ? '$label$tandaWajib'
        : label,
    hintText: (tandaWajib != null && tandaDiHint)
        ? '${hint ?? ''}$tandaWajib'.trim()
        : hint,
    helperText: petunjuk == null
        ? base.helperText
        : _gabungHelper(petunjuk, base.suffixText),
    suffixIcon: kunci
        ? const Icon(Icons.lock_outline, key: kunciIkonIdentitas, size: 18)
        : base.suffixIcon,
  );
}

/// Kunci ikon kunci pada identitas otomatis yang sudah terisi (untuk test).
const kunciIkonIdentitas = ValueKey('ikon-kunci-identitas');

String _gabungHelper(String petunjuk, String? satuan) =>
    (satuan == null || satuan.isEmpty) ? petunjuk : '$petunjuk · $satuan';

/// Versi untuk widget yang bukan `TextField` (mis. baris centang): [anak]
/// dibungkus kotak berlatar + bertepi menurut konvensi yang sama. Tanpa warna
/// (di luar scope, atau opsional) [anak] dikembalikan apa adanya.
///
/// Pakai `Material`, bukan `DecoratedBox`: `ListTile` menggambar latar dan
/// percikan tapnya di Material terdekat, dan `DecoratedBox` berwarna di
/// atasnya menutupi itu (Flutter melempar assertion).
Widget bungkusKotakIsian(
  BuildContext context, {
  required bool wajib,
  required bool terisi,
  required Widget anak,
}) {
  if (!WarnaIsianScope.aktif(context)) return anak;

  final status = statusIsian(wajib: wajib, terisi: terisi);
  final warna = PaletIsian.untuk(Theme.of(context).brightness, status);
  if (warna == null) return anak;

  return Material(
    color: warna.latar,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(
        color: warna.tepi,
        width: status == StatusIsian.wajibKosong ? 2 : 1,
      ),
    ),
    child: anak,
  );
}

/// Membangun ulang [builder] setiap [controller] berubah, KHUSUS isian wajib.
///
/// Isian yang tidak wajib tidak memasang listener sama sekali — lembar dengan
/// puluhan sel tidak boleh membayar apa-apa untuk kotak yang tidak berwarna.
class PemantauTerisi extends StatelessWidget {
  const PemantauTerisi({
    super.key,
    required this.controller,
    required this.wajib,
    required this.builder,
  });

  final TextEditingController controller;
  final bool wajib;

  /// `terisi` = teks (tanpa spasi pinggir) tidak kosong.
  final Widget Function(BuildContext context, bool terisi) builder;

  @override
  Widget build(BuildContext context) {
    if (!wajib) return builder(context, false);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          builder(context, controller.text.trim().isNotEmpty),
    );
  }
}

/// Baris ringkas di atas lembar: empat titik warna + tombol info yang membuka
/// penjelasan lengkapnya.
class LegendaWarnaIsian extends StatelessWidget {
  const LegendaWarnaIsian({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 2,
              children: [
                _Titik(
                  status: StatusIsian.wajibKosong,
                  teks: l10n.lkLegendaRingkasWajib,
                ),
                _Titik(
                  status: StatusIsian.wajibTerisi,
                  teks: l10n.lkLegendaRingkasTerisi,
                ),
                _Titik(
                  status: StatusIsian.opsional,
                  teks: l10n.lkLegendaRingkasOpsional,
                ),
                _Titik(
                  status: StatusIsian.otomatis,
                  teks: l10n.lkLegendaRingkasOtomatis,
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('tombol-legenda-warna-isian'),
            tooltip: l10n.lkLegendaJudul,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            color: theme.colorScheme.primary,
            icon: const Icon(Icons.info_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const _LembarLegenda(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik({required this.status, required this.teks});

  final StatusIsian status;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = PaletIsian.untuk(theme.brightness, status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: warna?.latar,
            border: Border.all(
              color: warna?.tepi ?? theme.colorScheme.outline,
              width: status == StatusIsian.wajibKosong ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(teks, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _LembarLegenda extends StatelessWidget {
  const _LembarLegenda();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget baris(StatusIsian status, String judul, String isi) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _Titik(status: status, teks: ''),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: theme.textTheme.titleSmall),
                Text(isi, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.lkLegendaJudul, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            baris(
              StatusIsian.wajibKosong,
              l10n.lkLegendaWajibKosongJudul,
              l10n.lkLegendaWajibKosongIsi,
            ),
            baris(
              StatusIsian.wajibTerisi,
              l10n.lkLegendaWajibTerisiJudul,
              l10n.lkLegendaWajibTerisiIsi,
            ),
            baris(
              StatusIsian.opsional,
              l10n.lkLegendaOpsionalJudul,
              l10n.lkLegendaOpsionalIsi,
            ),
            baris(
              StatusIsian.otomatis,
              l10n.lkLegendaOtomatisJudul,
              l10n.lkLegendaOtomatisIsi,
            ),
            // Identitas alat: warnanya menurut isi, dan kunci = otomatis dari
            // data alat. Satu baris sendiri supaya tidak tenggelam di empat
            // keadaan di atas.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                key: const ValueKey('legenda-identitas-alat'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1, right: AppSpacing.xs),
                    child: Icon(Icons.lock_outline, size: 14),
                  ),
                  Expanded(
                    child: Text(
                      l10n.lkLegendaIdentitas,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.lkLegendaTanda, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
