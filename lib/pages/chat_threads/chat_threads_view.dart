import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_threads/chat_threads.dart';
import 'package:extera_next/utils/date_time_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';

class ChatThreadsView extends StatelessWidget {
  final ChatThreadsController controller;

  const ChatThreadsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = controller.room;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(L10n.of(context).chatThreads),
      ),
      body: MaxWidthBody(
        withScrolling: false,
        withoutVerticalPadding: true,
        child: room == null
            ? _buildEmptyState(context, theme)
            : _buildContent(context, theme, room),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Room room) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (controller.threads.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: controller.threads.length,
        itemBuilder: (context, index) {
          final thread = controller.threads[index];
          final th = controller.threadsMap?.values.firstWhere(
            (t) => t.rootEvent.eventId == thread.eventId,
          );
          return _ThreadListItem(
            thread: thread,
            room: room,
            messageCount: th?.count,
            onTap: () => controller.openThread(thread),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 80,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              L10n.of(context).noThreadsYet,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              L10n.of(context).noThreadsYetLong,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadListItem extends StatelessWidget {
  final Event thread;
  final int? messageCount;
  final Room room;
  final VoidCallback onTap;

  const _ThreadListItem({
    required this.thread,
    required this.room,
    required this.onTap,
    this.messageCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sender = thread.senderFromMemoryOrFallback;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar(
                      mxContent: sender.avatarUrl,
                      name: sender.calcDisplayname(),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            sender.calcDisplayname(),
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            thread.originServerTs.localizedTimeShort(context),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                          Expanded(child: const SizedBox.shrink()),
                          FilledButton(
                            onPressed: () {
                              onTap();
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.forum_outlined),
                                const SizedBox(width: 12),
                                Text(
                                  messageCount?.toString() ??
                                      L10n.of(context).discuss,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: thread.calcLocalizedBody(
                    MatrixLocals(L10n.of(context)),
                    plaintextBody: true,
                    removeMarkdown: true,
                    hideReply: true,
                  ),
                  initialData: thread.calcLocalizedBodyFallback(
                    MatrixLocals(L10n.of(context)),
                    plaintextBody: true,
                    removeMarkdown: true,
                    hideReply: true,
                  ),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? '',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
