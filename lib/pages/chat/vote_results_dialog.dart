import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/utils/poll_events.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/list_divider.dart';
import 'package:extera_next/widgets/matrix.dart';

/// Shows a dialog with detailed poll results
///
/// For disclosed polls, shows results immediately
/// For undisclosed polls, only shows results after poll ends
/// Voter names are only shown for disclosed polls or ended disclosed polls
Future<void> showPollResultsDialog(
  BuildContext context,
  Event pollEvent,
) async {
  final content =
      pollEvent.content[PollEvents.PollStart] as Map<String, dynamic>;
  final kind = content['kind'] as String?;
  final isDisclosed = kind == 'org.matrix.msc3381.poll.disclosed';

  // Check if poll has ended
  final room = pollEvent.room;
  final endEvents = await room.client.getRelatingEventsWithRelTypeAndEventType(
    room.id,
    pollEvent.eventId,
    'm.reference',
    'org.matrix.msc3381.poll.end',
  );
  final isEnded = endEvents.chunk.isNotEmpty;

  // Determine if we should show results and voter names
  final shouldShowResults = isDisclosed || isEnded;
  final shouldShowVoters = isDisclosed; // Only disclosed polls show who voted

  if (!shouldShowResults) {
    // Poll is undisclosed and not ended yet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Poll results are hidden until the poll ends'),
      ),
    );
    return;
  }

  // Calculate results
  final pollContent =
      pollEvent.content['org.matrix.msc3381.poll.start']! as Map;
  final int maxAnswers = pollContent['max_selections'] ?? 1;
  final results = <String, int>{};
  final voters = <String, List<String>>{}; // answerId -> list of userIds

  final rel = await Matrix.of(context).client
      .getRelatingEventsWithRelTypeAndEventType(
        room.id,
        pollEvent.eventId,
        "m.reference",
        "org.matrix.msc3381.poll.response",
      );

  final responses = rel.chunk;
  final userLatestResponse = <String, MatrixEvent>{};

  for (final response in responses) {
    final senderId = response.senderId;
    final ts = response.originServerTs;

    if (!userLatestResponse.containsKey(senderId) ||
        ts.isAfter(userLatestResponse[senderId]!.originServerTs)) {
      userLatestResponse[senderId] = response;
    }
  }

  for (final response in userLatestResponse.values) {
    final responseContent =
        response.content['org.matrix.msc3381.poll.response']
            as Map<String, dynamic>;

    final List<dynamic> answersRaw = responseContent['answers'] ?? [];
    final answers = answersRaw.cast<String>();
    if (answers.length > maxAnswers) {
      continue;
    }

    for (final answer in answers) {
      results[answer] = (results[answer] ?? 0) + 1;
      if (!voters.containsKey(answer)) {
        voters[answer] = [];
      }
      voters[answer]!.add(response.senderId);
    }
  }

  final List<dynamic> answers = content['answers'] ?? [];

  if (!context.mounted) return;

  showAdaptiveBottomSheet(
    context: context,
    useRootNavigator: false,
    builder: (context) => _PollResultsDialog(
      pollEvent: pollEvent,
      answers: answers,
      pollResults: results,
      pollVoters: voters,
      showVoters: shouldShowVoters,
      isEnded: isEnded,
    ),
  );
}

class _PollResultsDialog extends StatelessWidget {
  final Event pollEvent;
  final List<dynamic> answers;
  final Map<String, int> pollResults;
  final Map<String, List<String>> pollVoters;
  final bool showVoters;
  final bool isEnded;

  const _PollResultsDialog({
    required this.pollEvent,
    required this.answers,
    required this.pollResults,
    required this.pollVoters,
    required this.showVoters,
    required this.isEnded,
  });

  int get totalVotes {
    if (pollResults.isEmpty) return 0;
    return pollResults.values.reduce((a, b) => a + b);
  }

  double _getPercentage(String answerId) {
    if (totalVotes == 0) return 0.0;
    return (pollResults[answerId] ?? 0) / totalVotes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content =
        pollEvent.content[PollEvents.PollStart] as Map<String, dynamic>;
    final question =
        content['question']?['m.text'] as String? ??
        content['question']?['org.matrix.msc1767.text'] as String? ??
        content['question']?['body'] as String? ??
        'Poll';

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).pollResults),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          Text(question, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).totalVotes(totalVotes),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (isEnded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Material(
                borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                clipBehavior: .hardEdge,
                color: theme.colorScheme.surfaceContainer,
                child: Padding(
                  padding: const .all(16),
                  child: Row(
                    spacing: 12,
                    children: [
                      Icon(
                        Icons.check_circle,
                        // size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      Text(
                        L10n.of(context).pollHasBeenEnded,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          Material(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
            clipBehavior: .hardEdge,
            color: theme.colorScheme.surfaceContainer,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: answers.length,
              itemBuilder: (context, index) {
                final answer = answers[index];
                final answerMap = answer as Map<String, dynamic>;
                final answerId = answerMap['id'] as String;
                final answerText =
                    answerMap['m.text'] as String? ??
                    answerMap['org.matrix.msc1767.text'] as String? ??
                    'Answer';
                final voteCount = pollResults[answerId] ?? 0;
                final percentage = _getPercentage(answerId);
                final voterIds = pollVoters[answerId] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const .all(16),
                      child: Column(
                        mainAxisAlignment: .start,
                        crossAxisAlignment: .start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  answerText,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(percentage * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 8,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            L10n.of(context).voteCount(voteCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          if (showVoters && voterIds.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: voterIds.map((userId) {
                                return FutureBuilder<User?>(
                                  future: pollEvent.room.requestUser(userId),
                                  builder: (context, snapshot) {
                                    final user = snapshot.data;
                                    final displayName =
                                        user?.calcDisplayname() ?? userId;

                                    return Chip(
                                      avatar: Avatar(
                                        mxContent: user?.avatarUrl,
                                        name: displayName,
                                        size: 24,
                                        client: pollEvent.room.client,
                                      ),
                                      label: Text(
                                        displayName,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      color: WidgetStateProperty.all(
                                        theme
                                            .colorScheme
                                            .surfaceContainerLowest,
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (index != answers.length - 1) const ListDivider(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
