import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization/app_localizations.dart';
import '../core/ui/almanac_feedback.dart';

class YdbSetupGuidePage extends StatelessWidget {
  const YdbSetupGuidePage({super.key});

  static const _console = 'https://console.yandex.cloud/folders';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = <(String, String, String)>[
      ('1', l10n.ydbGuideStep1Title, l10n.ydbGuideStep1Body),
      ('2', l10n.ydbGuideStep2Title, l10n.ydbGuideStep2Body),
      ('3', l10n.ydbGuideStep3Title, l10n.ydbGuideStep3Body),
      ('4', l10n.ydbGuideStep4Title, l10n.ydbGuideStep4Body),
      ('5', l10n.ydbGuideStep5Title, l10n.ydbGuideStep5Body),
      ('6', l10n.ydbGuideStep6Title, l10n.ydbGuideStep6Body),
      ('7', l10n.ydbGuideStep7Title, l10n.ydbGuideStep7Body),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ydbGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(l10n.ydbGuideIntro, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 16),
          for (final step in steps)
            _Step(number: step.$1, title: step.$2, body: step.$3),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _console));
              if (context.mounted) {
                AlmanacFeedback.showSuccess(context, _console);
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.ydbGuideCopyConsole),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, child: Text(number)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
