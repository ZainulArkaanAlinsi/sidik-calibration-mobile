import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/validasi.dart';
import '../../auth/widgets/neu.dart';

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
        if (_dipilih.contains(_kunciTemuan(t))) '• ${t.pesan}',
      for (final a in _alasan(l10n))
        if (_dipilih.contains('alasan:${a.label}')) '• ${a.label}',
    ];

    final tambahan = _catatan.text.trim();
    if (tambahan.isNotEmpty) baris.add(tambahan);

    return baris.join('\n');
  }

  /// Kode yang ikut dikirim: kolom dari alasan siap-pakai, PLUS kode sel dari
  /// temuan yang diketuk.
  ///
  /// Kode selnya yang bikin penolakan berhenti jadi "ulangi tabelnya". Sebelum
  /// ini temuan yang diketuk cuma nyumbang prosanya — jadi admin bisa bilang
  /// "Titik ke-2 Repeat 3 komanya kegeser", tapi teknisi mesti nyari kotak itu
  /// pakai mata di tabel berisi puluhan angka. Yang nggak nemu milih jalan
  /// aman: ngosongin tabel, ngetik ulang semuanya, termasuk angka yang udah
  /// bener — dan itu justru ngundang salah ketik BARU di sesi revisi.
  ///
  /// Temuan yang nggak punya kode sel (kolom identitas, atau pembacaan yang
  /// titiknya kembar) cuma nyumbang prosanya, sama kayak sebelumnya.
  List<String> _fieldTerpilih(AppLocalizations l10n) => {
    for (final a in _alasan(l10n))
      if (_dipilih.contains('alasan:${a.label}')) ...a.field,
    for (final t in widget.temuan)
      if (_dipilih.contains(_kunciTemuan(t))) ?t.kodeSel,
  }.toList();

  /// Kunci pilihan buat satu temuan.
  ///
  /// **Bukan `t.kode`.** Kode mesinnya sengaja sama buat temuan sejenis —
  /// `pembacaan_di_luar_rentang` muncul sekali per pembacaan — jadi mengunci
  /// pilihan ke kode bikin empat baris di layar nyala-mati barengan. Untuk
  /// prosa itu cuma berisik; sejak temuan bisa nyumbang KODE SEL, itu bikin
  /// admin yang mau nandain satu kotak diam-diam nandain empat, dan tiga di
  /// antaranya angka yang justru sudah benar.
  ///
  /// Pesannya ikut jadi kunci karena di situ posisinya disebut ("Titik ke-2
  /// Repeat 3"), jadi dua temuan yang beda selalu punya kunci yang beda.
  String _kunciTemuan(Temuan t) => 'temuan:${t.kode}|${t.kodeSel ?? ''}|${t.pesan}';

  void _tukar(String kunci) => setState(() {
    _dipilih.contains(kunci) ? _dipilih.remove(kunci) : _dipilih.add(kunci);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = NeuColors.of(context);
    final catatan = _susunCatatan(l10n);

    // Backend minta minimal 5 karakter. Dijaga di sini juga supaya tombolnya
    // mati dari awal — bukan nyala, ditekan, lalu dimarahin snackbar.
    final bolehKirim = catatan.trim().length >= 5;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      // Latarnya `c.base` sama kayak layar Perhitungan yang manggil lembar
      // ini — sheet putih Material di atas panel soft-UI kelihatan nempel dari
      // aplikasi lain.
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.base,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Gagang seret kecil — penanda bahwa lembarnya bisa ditarik,
                // dan pengganti garis Divider yang dibuang.
                Expanded(
                  child: Text(
                    l10n.tolakJudul,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: NeuRaised(
                    circle: true,
                    distance: 3,
                    blur: 7,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.close, size: 18, color: c.textMuted),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: c.darkShadow.withValues(alpha: 0.5),
          ),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  l10n.tolakPetunjuk,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),

                // Temuan mesin duluan: itu yang paling nggak terbantahkan, dan
                // paling sering jadi alasan sebenernya.
                if (widget.temuan.isNotEmpty) ...[
                  Text(
                    l10n.tolakDariPemeriksaan.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final t in widget.temuan)
                    _BarisTemuan(
                      pesan: t.pesan,
                      dipilih: _dipilih.contains(_kunciTemuan(t)),
                      onTap: () => _tukar(_kunciTemuan(t)),
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text(
                  l10n.tolakAlasanUmum.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final a in _alasan(l10n))
                      _ChipAlasan(
                        label: a.label,
                        aktif: _dipilih.contains('alasan:${a.label}'),
                        onTap: () => _tukar('alasan:${a.label}'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                NeuInset(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _catatan,
                    maxLines: 3,
                    style: TextStyle(fontSize: 13.5, color: c.text),
                    decoration: InputDecoration(
                      labelText: l10n.tolakCatatanTambahan,
                      labelStyle: TextStyle(color: c.textMuted, fontSize: 13),
                      hintText: l10n.tolakCatatanHint,
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 12.5),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Pratinjau: admin lihat persis kalimat yang bakal diterima
                // teknisi sebelum ngirim.
                if (catatan.isNotEmpty) ...[
                  Text(
                    l10n.tolakPratinjau.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  NeuInset(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        catatan,
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: c.text),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

          // Bilah yang ngirim penolakan — sengaja tetap tegas batasnya dari
          // isi yang dibaca, sama alasannya kayak `_BilahAksi` di layar
          // Perhitungan.
          Container(
            decoration: BoxDecoration(
              color: c.base,
              border: Border(
                top: BorderSide(color: c.darkShadow.withValues(alpha: 0.5)),
              ),
              boxShadow: [
                BoxShadow(
                  color: c.darkShadow.withValues(alpha: 0.45),
                  offset: const Offset(0, -4),
                  blurRadius: 14,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                // Keyboard-nya nutupin bilah ini kalau nggak digeser: admin
                // ngetik alasan di kotak "Catatan tambahan", lalu tombol KIRIM
                // ada DI BAWAH papan ketik — dia mesti nutup keyboard dulu buat
                // nemuin tombolnya. Sheet lain di app (Ruangan, Metode, Rumus)
                // udah pakai `viewInsets`; cuma lembar ini yang kelewat.
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                ),
                child: NeuButton(
                  label: l10n.tolakKirim,
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
      ),
    );
  }
}

/// Satu temuan mesin yang bisa ditap. Bukan `CheckboxListTile`: kotak centang
/// Material di tengah lembar soft-UI kelihatan nempel dari aplikasi lain, dan
/// baris ini yang paling sering ditap admin.
class _BarisTemuan extends StatelessWidget {
  const _BarisTemuan({
    required this.pesan,
    required this.dipilih,
    required this.onTap,
  });

  final String pesan;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: NeuRaised(
          radius: 14,
          distance: dipilih ? 2 : 4,
          blur: dipilih ? 6 : 10,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                dipilih ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: dipilih ? c.accent : c.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pesan,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: dipilih ? FontWeight.w600 : FontWeight.w400,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alasan siap-pakai. Yang aktif diisi warna aksen — di permukaan sewarna,
/// bayangan doang kurang kebaca sekilas, dan ini kontrol yang dipakai sambil
/// buru-buru. Sama perlakuannya kayak `_Chip` di Antrean Approval.
class _ChipAlasan extends StatelessWidget {
  const _ChipAlasan({
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: NeuRaised(
        radius: 18,
        distance: aktif ? 3 : 5,
        blur: aktif ? 8 : 12,
        color: aktif ? c.accent : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: aktif ? FontWeight.w700 : FontWeight.w600,
            color: aktif ? c.onAccent : c.textMuted,
          ),
        ),
      ),
    );
  }
}
