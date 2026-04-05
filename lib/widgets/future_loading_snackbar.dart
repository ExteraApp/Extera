import 'dart:async';

import 'package:flutter/material.dart';

import 'package:async/async.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/localized_exception_extension.dart';

/// Displays a loading snackbar which reacts to the given [future]. Unlike
/// [showFutureLoadingDialog], this does not block the UI — the user can
/// continue interacting with the app while the operation runs in the
/// background. The snackbar is dismissed automatically when the future
/// completes. If an error occurs, an error snackbar is shown briefly.
Future<Result<T>> showFutureLoadingSnackbar<T>({
  required BuildContext context,
  Future<T> Function()? future,
  Future<T> Function(void Function(double?) setProgress)? futureWithProgress,
  String? title,
  Duration errorDuration = const Duration(seconds: 4),
  ExceptionContext? exceptionContext,
}) async {
  assert(future != null || futureWithProgress != null);

  final messenger = ScaffoldMessenger.of(context);
  final l10n = L10n.of(context);
  final theme = Theme.of(context);
  final loadingTitle = title ?? l10n.loadingPleaseWait;

  final progressNotifier = ValueNotifier<double?>(null);

  // Show the loading snackbar
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(minutes: 5),
      dismissDirection: DismissDirection.none,
      content: ValueListenableBuilder<double?>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) => Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                value: progress,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                loadingTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  try {
    final result = futureWithProgress != null
        ? await futureWithProgress((p) => progressNotifier.value = p)
        : await future!();

    messenger.clearSnackBars();
    progressNotifier.dispose();
    return Result.value(result);
  } catch (e, s) {
    messenger.clearSnackBars();
    progressNotifier.dispose();

    final errorMessage = e.toLocalizedString(context, exceptionContext);

    messenger.showSnackBar(
      SnackBar(
        duration: errorDuration,
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onError,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.error,
      ),
    );

    return Result.error(e, s);
  }
}
