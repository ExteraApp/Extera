import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/msc4140_extension.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';

class SendLaterDialog extends StatefulWidget {
  final Room room;
  final BuildContext outerContext;
  final Event? replyEvent;
  final Map<String, dynamic> content;
  final Thread? thread;

  const SendLaterDialog({
    required this.room,
    required this.thread,
    required this.content,
    required this.outerContext,
    this.replyEvent,
    super.key,
  });

  @override
  SendLaterDialogState createState() => SendLaterDialogState();
}

class SendLaterDialogState extends State<SendLaterDialog> {
  DateTime? _selected;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _selected ?? now.add(const Duration(minutes: 5));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;
    setState(() {
      _selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatSelected() {
    if (_selected == null) return L10n.of(context).select;
    return '${MaterialLocalizations.of(context).formatFullDate(_selected!)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_selected!))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send later')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pick date and time to send the message'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _pickDateTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(_selected == null ? 'Select' : _formatSelected()),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_selected == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select date and time'),
                          ),
                        );
                        return;
                      }
                      final now = DateTime.now();
                      if (!_selected!.isAfter(now)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Selected time is in the past'),
                          ),
                        );
                        return;
                      }
                      final delayMs = _selected!.difference(now).inMilliseconds;
                      final result = await showFutureLoadingDialog<String>(
                        context: context,
                        future: () => widget.room.scheduleDelayedEvent(
                          widget.content,
                          delay: delayMs,
                          inReplyTo: widget.replyEvent,
                          threadRootEventId: widget.thread?.rootEvent.eventId,
                          threadLastEventId: widget.thread?.lastEvent?.eventId,
                        ),
                      );
                      if (result.isError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.asError?.error.toString() ??
                                  'An error occurred',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(result.asValue?.value);
                    },
                    child: const Text('Schedule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
