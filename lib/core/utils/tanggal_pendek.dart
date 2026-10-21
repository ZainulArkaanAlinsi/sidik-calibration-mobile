import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// `d MMM yyyy` dalam bahasa aplikasi, atau `—` kalau tanggalnya kosong.
///
/// Locale dibaca dari konteks: `Intl.defaultLocale` tidak pernah disetel di
/// app ini, jadi `DateFormat` tanpa locale selalu mencetak nama bulan Inggris
/// — "Target 2 Oct 2026" di layar berbahasa Indonesia.
String tanggalPendek(BuildContext context, DateTime? t) => t == null
    ? '—'
    : DateFormat(
        'd MMM yyyy',
        Localizations.localeOf(context).languageCode,
      ).format(t);
