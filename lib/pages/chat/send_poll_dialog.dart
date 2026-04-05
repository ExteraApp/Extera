import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';
import 'package:uuid/uuid.dart';

import 'package:extera_next/generated/l10n/l10n.dart';

class SendPollDialog extends StatefulWidget {
  final Room room;
  final BuildContext outerContext;
  final Event? replyEvent;
  final Thread? thread;

  const SendPollDialog({
    required this.room,
    required this.thread,
    required this.outerContext,
    this.replyEvent,
    super.key,
  });

  @override
  SendPollDialogState createState() => SendPollDialogState();
}

class SendPollDialogState extends State<SendPollDialog> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _answerControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _maxSelections = 1;
  String _kind = 'org.matrix.msc3381.poll.disclosed';

  void _addAnswer() {
    setState(() {
      _answerControllers.add(TextEditingController());
    });
  }

  void _removeAnswer(int index) {
    if (_answerControllers.length > 2) {
      setState(() {
        _answerControllers.removeAt(index);
        if (_maxSelections > _answerControllers.length) {
          _maxSelections = _answerControllers.length;
        }
      });
    }
  }

  void _sendPoll() async {
    final question = _questionController.text.trim();
    final answers = _answerControllers
        .map((controller) => controller.text.trim())
        .where((answer) => answer.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).pleaseEnterQuestion)),
      );
      return;
    }

    if (answers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).atLeastTwoAnswersRequired)),
      );
      return;
    }

    final pollContent = {
      'org.matrix.msc3381.poll.start': {
        'question': {
          'org.matrix.msc1767.text': question,
          'm.text': question,
          'body': question,
          'msgtype': 'm.text',
        },
        'answers': answers
            .map(
              (answer) => {
                'id': const Uuid().v4(),
                'org.matrix.msc1767.text': answer,
                'm.text': answer,
              },
            )
            .toList(),
        'max_selections': _maxSelections,
        'kind': _kind,
      },
      'org.matrix.msc1767.text': "$question\n${answers.join('\n')}",
    };

    try {
      await widget.room.sendEvent(
        pollContent,
        type: 'org.matrix.msc3381.poll.start',
        threadLastEventId:
            widget.thread?.lastEvent?.eventId ??
            widget.thread?.rootEvent.eventId,
        threadRootEventId: widget.thread?.rootEvent.eventId,
      );
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send poll: $e')));
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // Ensure max slider value is at least 1 to prevent division by zero errors
    final maxAnswers = _answerControllers.isNotEmpty
        ? _answerControllers.length.toDouble()
        : 1.0;

    return AlertDialog(
      title: Text(l10n.createPoll),
      // In M3, the surface tint color is often used, but we keep default styling here
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Question Input ---
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                labelText: l10n.question,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // --- Answer Inputs ---
            ..._answerControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: '${l10n.answer} ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      // M3 uses standard variant colors for destructive actions
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeAnswer(index),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Add Answer Button
            Center(
              child: OutlinedButton.icon(
                onPressed: _addAnswer,
                icon: const Icon(Icons.add),
                label: Text(l10n.addAnswer),
              ),
            ),

            const Divider(height: 32),

            // --- Max Selections (Slider) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.maxSelections,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '$_maxSelections',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Slider(
              value: _maxSelections.toDouble().clamp(1.0, maxAnswers),
              min: 1,
              max: maxAnswers,
              divisions: (maxAnswers > 1) ? (maxAnswers - 1).toInt() : 1,
              label: '$_maxSelections',
              onChanged: (value) {
                setState(() {
                  _maxSelections = value.toInt();
                });
              },
            ),

            const SizedBox(height: 16),

            // --- Poll Type (Segmented Button) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
              child: Text(
                l10n.pollType,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false, // Cleaner look for text-only segments
                segments: [
                  ButtonSegment<String>(
                    value: 'org.matrix.msc3381.poll.disclosed',
                    label: Text(l10n.publicPoll),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'org.matrix.msc3381.poll.undisclosed',
                    label: Text(l10n.anonymousPoll),
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    // SegmentedButton returns a Set, we just need the first (only) value
                    _kind = newSelection.first;
                  });
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: Navigator.of(context).pop,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
          ),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _sendPoll, child: Text(l10n.send)),
      ],
    );
  }
}
