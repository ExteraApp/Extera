import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_list/chat_list_item.dart';

class ChatPrivacyList extends StatelessWidget {
  final Client client;

  const ChatPrivacyList({required this.client, super.key});

  List<String> get roomIds {
    // xyz.extera.room_privacy_settings.
    var keys = client.accountData.keys.toList();
    keys = keys
        .where((s) => s.startsWith('xyz.extera.room_privacy_settings.'))
        .where((eventKey) {
          final content = client.accountData[eventKey]!.content;
          return content.keys.isNotEmpty;
        })
        .map((s) => s.substring(33))
        .toList();
    return keys;
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            L10n.of(context).noCustomPrivacySettings,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).noCustomPrivacySettingsDetails,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = roomIds;
    return Material(
      elevation: 8.0,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ids.isEmpty)
              _buildEmptyPlaceholder(context)
            else
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: ids.length,
                itemBuilder: (context, index) {
                  final roomId = ids[index];
                  final room = client.getRoomById(roomId);
                  if (room == null) return const SizedBox.shrink();
                  return ChatListItem(
                    room,
                    noBackgroundColor: true,
                    onTap: () {
                      context.pop();
                      context.push('/rooms/$roomId/details/privacy');
                    },
                  );
                },
              ),
            const Divider(),
            ListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: Text(L10n.of(context).cancel),
                  onTap: () {
                    context.pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
