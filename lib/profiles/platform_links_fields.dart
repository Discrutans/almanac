part of 'platform_links_sheet.dart';

class _ConfigField extends StatelessWidget {
  const _ConfigField({
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(labelText: label, hintText: hintText),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: AppLocalizations.of(context).linkCopied,
          onPressed: () async {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              AlmanacFeedback.showSuccess(
                context,
                AppLocalizations.of(context).linkCopied,
              );
            }
          },
        ),
      ],
    );
  }
}
