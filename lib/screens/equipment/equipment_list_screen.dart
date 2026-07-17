import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/empty_placeholder.dart';

class EquipmentListScreen extends StatelessWidget {
  const EquipmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEquipment)),
      body: EmptyPlaceholder(
        icon: Icons.straighten_outlined,
        title: l10n.equipmentPlaceholderTitle,
        message: l10n.equipmentPlaceholderBody,
      ),
    );
  }
}
