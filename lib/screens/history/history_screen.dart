import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/empty_placeholder.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHistory)),
      body: EmptyPlaceholder(
        icon: Icons.history_outlined,
        title: l10n.historyPlaceholderTitle,
        message: l10n.historyPlaceholderBody,
      ),
    );
  }
}
