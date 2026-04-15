import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/synchronization/push/result.dart';
import 'package:open_authenticator/model/backend/synchronization/queue.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/expandable_tile.dart';
import 'package:open_authenticator/widgets/image_text_actions.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// The sync issues page.
class SyncIssuesPage extends ConsumerWidget {
  /// The scan page name.
  static const String name = '/syncIssues';

  /// Creates a new sync issues page instance.
  const SyncIssuesPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<PushOperationError>> errors = ref.watch(pushOperationsErrorsProvider);
    return AppScaffold.asyncValue(
      header: FHeader.nested(
        prefixes: [
          ClickableHeaderAction.back(
            onPress: () => Navigator.pop(context),
          ),
        ],
        suffixes: [
          ClickableHeaderAction(
            icon: const Icon(FIcons.trash),
            onPress: () async {
              await showWaitingOverlay(
                context,
                future: ref.read(appDatabaseProvider).clearBackendPushOperationErrors(),
              );
            },
          ),
        ],
        title: Text(translations.syncIssues.title),
      ),
      asyncValue: errors,
      builder: (value) => [
        if (value.isEmpty)
          ImageTextActions.icon(
            icon: FIcons.checkCheck,
            text: translations.syncIssues.operations.empty,
          )
        else
          for (int i = 0; i < value.length; i++)
            Padding(
              padding: .only(bottom: i < value.length - 1 ? kBigSpace : 0),
              child: _PushOperationErrorWidget(
                error: value[i],
                onDeletePress: () async {
                  await showWaitingOverlay(
                    context,
                    future: ref.read(appDatabaseProvider).deleteBackendPushOperationError(value[i]),
                  );
                },
              ),
            ),
      ],
      onRetryPressed: () => ref.invalidate(pushOperationsErrorsProvider),
    );
  }
}

/// A push operation error widget.
class _PushOperationErrorWidget extends ConsumerWidget {
  /// The push operation error.
  final PushOperationError error;

  /// The on delete press callback.
  final VoidCallback? onDeletePress;

  /// Creates a new push operation error widget instance.
  const _PushOperationErrorWidget({
    required this.error,
    this.onDeletePress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpandableTile(
    title: Text(
      translations.syncIssues.operations.title(errorCode: error.errorCode),
    ),
    children: [
      if (error.errorKind!.isPermanent)
        Text(
          translations.syncIssues.operations.expandable.permanent,
          style: TextStyle(
            fontSize: context.theme.typography.xs.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      Text(
        translations.syncIssues.operations.expandable.date(
          date: '${DateFormat.yMd(translations.$meta.locale.underscoreTag).format(error.createdAt)} ${DateFormat.Hms(translations.$meta.locale.underscoreTag).format(error.createdAt)}',
        ),
        style: TextStyle(
          fontSize: context.theme.typography.xs.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        translations.syncIssues.operations.expandable.details,
        style: TextStyle(
          fontSize: context.theme.typography.xs.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        error.errorDetails.toString(),
        maxLines: null,
        overflow: TextOverflow.visible,
        style: TextStyle(fontSize: context.theme.typography.xs.fontSize),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: ClickableButton(
          variant: .destructive,
          mainAxisSize: .min,
          onPress: onDeletePress,
          child: ButtonText(translations.syncIssues.operations.expandable.deleteButton),
        ),
      ),
    ],
  );
}
