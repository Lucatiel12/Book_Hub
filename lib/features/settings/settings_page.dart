// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/settings/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(downloadSettingsProvider);
    final ctrl = ref.read(downloadSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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

          // NEW: Max concurrent downloads
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
}
