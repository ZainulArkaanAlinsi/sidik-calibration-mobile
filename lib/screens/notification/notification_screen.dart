import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/empty_placeholder.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navNotifications)),
      body: EmptyPlaceholder(
        icon: Icons.notifications_none,
        title: l10n.notificationPlaceholderTitle,
        message: l10n.notificationPlaceholderBody,
      ),
    );
  }
}
