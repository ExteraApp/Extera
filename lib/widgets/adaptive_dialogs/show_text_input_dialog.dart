import 'package:flutter/material.dart';

import 'package:flutter_linkify/flutter_linkify.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/adaptive_dialogs/dialog_text_field.dart';

Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? okLabel,
  String? cancelLabel,
  bool useRootNavigator = false,
  String? hintText,
  String? labelText,
  String? initialText,
  String? prefixText,
  String? suffixText,
  bool obscureText = false,
  bool isDestructive = false,
  int? minLines,
  int? maxLines,
  String? Function(String input)? validator,
  TextInputType? keyboardType,
  int? maxLength,
  bool autocorrect = true,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      final controller = TextEditingController(text: initialText);
      final error = ValueNotifier<String?>(null);
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: AlertDialog.adaptive(
          title: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256),
            child: Text(title),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null)
                  SelectableLinkify(
                    text: message,
                    textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
                    linkStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                    options: const LinkifyOptions(humanize: false),
                    onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
                  ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String?>(
                  valueListenable: error,
                  builder: (context, error, _) {
                    return DialogTextField(
                      hintText: hintText,
                      errorText: error,
                      labelText: labelText,
                      controller: controller,
                      initialText: initialText,
                      prefixText: prefixText,
                      suffixText: suffixText,
                      minLines: minLines,
                      maxLines: maxLines,
                      maxLength: maxLength,
                      keyboardType: keyboardType,
                      obscureText: obscureText,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
              ),
              child: Text(cancelLabel ?? L10n.of(context).cancel),
            ),
            FilledButton(
              onPressed: () {
                final input = controller.text;
                final errorText = validator?.call(input);
                if (errorText != null) {
                  error.value = errorText;
                  return;
                }
                Navigator.of(context).pop<String>(input);
              },
              autofocus: true,
              style: isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              child: Text(okLabel ?? L10n.of(context).ok),
            ),
          ],
        ),
      );
    },
  );
}
