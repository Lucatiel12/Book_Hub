// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:book_hub/features/settings/settings_provider.dart';
import 'package:book_hub/features/settings/locale_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Download settings (existing)
    final settings = ref.watch(downloadSettingsProvider);
    final ctrl = ref.read(downloadSettingsProvider.notifier);

    // Language (new)
    final appLang = ref.watch(appLanguageProvider);
    final langCtrl = ref.read(appLanguageProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // -------- Language picker (new) --------
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'), // add l10n key later if you want
            subtitle: Text(switch (appLang) {
              AppLanguage.system => 'System',
              AppLanguage.en => 'English',
              AppLanguage.ar => 'العربية',
            }),
            onTap:
                () => _pickLanguage(context, appLang, (v) {
                  langCtrl.set(v);
                }),
          ),
          const Divider(height: 0),

          // -------- Existing download settings --------
          SwitchListTile(
            title: const Text('Download over Wi-Fi only'),
            subtitle: const Text('Pause on cellular; resume manually/auto'),
            value: settings.wifiOnly,
            onChanged: ctrl.setWifiOnly,
          ),
          const Divider(height: 0),
          SwitchListTile(
            title: const Text('Auto-retry downloads'),
            subtitle: const Text('Retry after 20s, then 60s, then pause'),
            value: settings.autoRetry,
            onChanged: ctrl.setAutoRetry,
          ),
          const Divider(height: 0),
          SwitchListTile(
            title: const Text('Restore paused downloads on launch'),
            value: settings.autoRestoreOnLaunch,
            onChanged: ctrl.setAutoRestoreOnLaunch,
          ),
          const Divider(height: 0),

          ListTile(
            title: const Text('Max concurrent downloads'),
            subtitle: const Text('How many downloads can run at the same time'),
            trailing: DropdownButton<int>(
              value: settings.maxConcurrent,
              items:
                  [1, 2, 3, 4, 5]
                      .map(
                        (v) =>
                            DropdownMenuItem<int>(value: v, child: Text('$v')),
                      )
                      .toList(),
              onChanged: (v) {
                if (v != null) ctrl.setMaxConcurrent(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(
    BuildContext context,
    AppLanguage selected,
    void Function(AppLanguage) onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AppLanguage>(
                value: AppLanguage.system,
                groupValue: selected,
                title: const Text('System'),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(v);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<AppLanguage>(
                value: AppLanguage.en,
                groupValue: selected,
                title: const Text('English'),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(v);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<AppLanguage>(
                value: AppLanguage.ar,
                groupValue: selected,
                title: const Text('العربية'),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(v);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
