import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/angka.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/perhitungan.dart';
import '../../auth/widgets/neu.dart';

/// Angka lembar perhitungan ditampilkan **apa adanya dari server** — nggak ada
/// pembulatan, dan nggak ada operasi aritmetika di file ini. Yang diatur cuma
/// berapa desimal yang kelihatan biar muat di kolom sempit.
///
/// Delegasi ke [formatNilai]: `desimalMin` = resolusi titik (nol belakang di
/// bawahnya DIPERTAHANKAN → "4,60" bukan "4,6"), `maksDesimal` = batas atas biar
/// nilai presisi penuh (`4.0092251999999995`) nggak makan selebar layar.
String formatAngka(double n, {int maksDesimal = 4, int desimalMin = 0}) =>
    formatNilai(n, desimalMin: desimalMin, desimalMaks: maksDesimal);

/// Satu tabel "DATA HASIL KALIBRASI" (Before / After adjustment).
///
/// Susunannya persis sheet PERHITUNGAN: **kolom = titik ukur**, header-nya
/// nilai `Standard`, isinya Repeat 1..n (pH & °C), lalu ditutup baris
/// **Average**, **Correction**, **STDEV**, dan **MAX STDEV**.
///
/// Perhatikan: ini KEBALIKAN dari lembar kerja teknisi, yang barisnya titik
/// ukur dan kolomnya Repeat. Bukan kesalahan — dua dokumen itu memang beda
/// susunannya, dan yang dicontek di sini sheet PERHITUNGAN-nya.
class TabelPerhitunganWidget extends StatelessWidget {
  const TabelPerhitunganWidget({
    super.key,
    required this.tabel,
    this.resolusiAlat,
  });

  final TabelPerhitungan tabel;

  /// Resolusi alatnya (`IdentitasAlat.resolusi`) — dipakai buat titik yang
  /// `desimal`-nya null, artinya alat resolusi seragam. Tanpa ini pembacaan
  /// `1,3360` di alat 0,0001 tampil `1,336` dan kelihatan kayak alat yang lebih
  /// kasar dari aslinya.
  final double? resolusiAlat;

  /// Berapa desimal buat titik ini: yang dikirim per baris menang
  /// (Turbidimeter), sisanya ikut resolusi alat. `null` = nggak ada yang bisa
  /// disimpulin — sesi lama yang alatnya nggak kekirim resolusinya.
  int? _desimalTitik(TitikPerhitungan t) =>
      t.desimal ?? desimalDariResolusi(resolusiAlat);

  int _desimal(TitikPerhitungan t) => _desimalTitik(t) ?? 0;

  /// Batas desimal buat nilai yang satuannya sama dengan pembacaan — Standard
  /// & Correction.
  ///
  /// Dipotong ke resolusi alat, bukan dibiarin 7: `Standard 4.0092252` di alat
  /// beresolusi 0,01 itu lima digit yang nggak mewakili apa pun, dan bikin mata
  /// susah mbandingin baris. Sertifikatnya sendiri nyetak `4,01`.
  ///
  /// Resolusinya nggak ketahuan → balik ke 7, persis kayak sebelumnya. Mending
  /// kepanjangan daripada mbulatkan pakai angka yang cuma ditebak.
  int _maksNilai(TitikPerhitungan t) => _desimalTitik(t) ?? 7;

  /// Batas desimal buat STDEV — resolusi alat **+2**, bukan resolusi persis.
  ///
  /// STDEV itu sebaran, dan sering jauh lebih kecil dari resolusi: `0,0054772`
  /// dibulatkan ke 2 desimal jadi `0,01`, sama persis kayak `0,0149`. Dua
  /// keterulangan yang beda jadi kelihatan sama, padahal justru itu yang dipakai
  /// admin buat mutusin. Beda dari Standard/Correction yang emang nilai
  /// pengukuran dan pantas dipotong ke resolusi.
  int _maksStdev(TitikPerhitungan t) {
    final d = _desimalTitik(t);
    return d == null ? 7 : d + 2;
  }

  /// Titik ini pembacaannya dipindah suhu (Refractometer) — bukan cuma beda
  /// tipis karena derau float.
  static bool _adaKoreksiSuhu(TitikPerhitungan t) {
    final mentah = t.average;
    final terkoreksi = t.averageDikoreksiSuhu;
    if (mentah == null || terkoreksi == null) return false;

    return (terkoreksi - mentah).abs() > 1e-9;
  }

  static const _lebarLabel = 96.0;
  static const _lebarKolom = 108.0;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    if (tabel.titik.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tabel.judul,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nilai Standard per titik. BUKAN nilai nominal —
              // ini nilai buffer pada suhu larutan saat itu.
              _Baris(
                label: l10n.perhitStandard,
                tebal: true,
                sel: [
                  for (final t in tabel.titik)
                    t.standard == null
                        ? '—'
                        : formatAngka(t.standard!, maksDesimal: _maksNilai(t), desimalMin: _desimal(t)),
                ],
              ),
              _Baris(
                label: '',
                kecil: true,
                sel: [for (final t in tabel.titik) t.satuan ?? ''],
              ),
              _Garis(),

              for (var r = 0; r < tabel.jumlahPengulangan; r++)
                _Baris(
                  label: '${l10n.perhitRepeat} ${r + 1}',
                  sel: [
                    for (final t in tabel.titik)
                      r < t.pembacaan.length ? _sel(t.pembacaan[r], _desimal(t)) : '—',
                  ],
                ),

              _Garis(),

              // Baris Average nampilin **nilai terkoreksi** — itu yang dipakai
              // ngitung Correction di bawahnya dan yang kecetak di sertifikat
              // sebagai Unit Under Test.
              //
              // Dipotong ke resolusi alat, sama kayak Standard & Correction.
              // Sempat dibiarin 7 desimal dengan alasan "nilai terkoreksi
              // Refractometer bisa 5 desimal (1,33935), kepotong di 4 jadi beda
              // dari sertifikat" — alasan itu KELIRU: `SertifikatCocokMasterTest`
              // nunjukin sertifikatnya sendiri nyetak `1,3394`. Yang kejadian
              // malah sebaliknya, layar nampilin `7.004` buat pH yang di
              // sertifikat kecetak `7,00`.
              _Baris(
                label: l10n.perhitAverage,
                tebal: true,
                sel: [
                  for (final t in tabel.titik)
                    t.averageDikoreksiSuhu == null
                        ? '—'
                        : '${formatAngka(t.averageDikoreksiSuhu!, maksDesimal: _maksNilai(t), desimalMin: _desimal(t))}'
                              '${t.averageSuhu == null ? '' : '  ·  ${formatAngka(t.averageSuhu!)} °C'}',
                ],
              ),

              // Pembacaan mentahnya cuma ditunjukin kalau emang BEDA dari yang
              // terkoreksi — buat pH/Turbidimeter/Chlorine dua-duanya sama
              // persis, dan baris kembar cuma bikin tabelnya rame. Yang butuh
              // ini Refractometer: teknisi perlu lihat angka yang dia ketik
              // (`1,3362`) buat ngecek dia nggak salah ketik, sementara yang
              // dihitung `1,33935`.
              if (tabel.titik.any(_adaKoreksiSuhu))
                _Baris(
                  label: l10n.perhitObserved,
                  kecil: true,
                  sel: [
                    for (final t in tabel.titik)
                      t.average == null
                          ? '—'
                          : formatAngka(
                              t.average!,
                              maksDesimal: _maksNilai(t),
                              desimalMin: _desimal(t),
                            ),
                  ],
                ),
              _Baris(
                label: l10n.perhitCorrection,
                tebal: true,
                sel: [
                  for (final t in tabel.titik)
                    t.correction == null
                        ? '—'
                        : formatAngka(t.correction!, maksDesimal: _maksNilai(t), desimalMin: _desimal(t)),
                ],
              ),
              _Baris(
                label: l10n.perhitStdev,
                sel: [
                  for (final t in tabel.titik)
                    t.stdev == null
                        ? '—'
                        : formatAngka(t.stdev!, maksDesimal: _maksStdev(t)),
                ],
              ),
            ],
          ),
        ),

        if (tabel.maxStdev != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${l10n.perhitMaxStdev}: ',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted,
                ),
              ),
              Text(
                // MAX STDEV itu salah satu STDEV di atasnya, jadi dipotong
                // pakai aturan yang sama — kalau nggak, angka yang sama muncul
                // dua kali dengan panjang beda dan kelihatan kayak dua nilai.
                formatAngka(
                  tabel.maxStdev!,
                  maksDesimal: _maksStdev(tabel.titik.first),
                ),
                style: TextStyle(fontSize: 11.5, color: c.text),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _sel(PembacaanPerhitungan p, int? desimal) {
    final nilai = formatAngka(p.nilai, desimalMin: desimal ?? 0);
    final suhu = p.suhu;
    return suhu == null ? nilai : '$nilai  ·  ${formatAngka(suhu)} °C';
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.sel,
    this.tebal = false,
    this.kecil = false,
  });

  final String label;
  final List<String> sel;
  final bool tebal;
  final bool kecil;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final gaya = kecil
        ? TextStyle(fontSize: 11, color: c.textMuted)
        : TextStyle(
            fontSize: 12.5,
            fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
            color: c.text,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: TabelPerhitunganWidget._lebarLabel,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: tebal ? FontWeight.w700 : FontWeight.w500,
                color: tebal ? c.text : c.textMuted,
              ),
            ),
          ),
          for (final s in sel)
            SizedBox(
              width: TabelPerhitunganWidget._lebarKolom,
              child: Text(s, textAlign: TextAlign.center, style: gaya),
            ),
        ],
      ),
    );
  }
}

/// Pemisah baris tabel. Garis tipis dari bayangan gelap, bukan `Divider`
/// Material — biar nyatu sama permukaan soft-UI, sama kayak `_Blok` di layar
/// Perhitungan.
class _Garis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        height: 1,
        color: NeuColors.of(context).darkShadow.withValues(alpha: 0.35),
      ),
    );
  }
}
