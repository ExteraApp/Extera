import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';

bool hasIndividualPrivacyOptionsEnabled(Client client, String roomId) {
  return client.accountData.containsKey(
    'xyz.extera.room_privacy_settings.$roomId',
  );
}

bool shouldSendPublicReadReceipts(Client client, String roomId) {
  if (!hasIndividualPrivacyOptionsEnabled(client, roomId))
    return AppSettings.sendPublicReadReceipts.value;
  final content =
      client.accountData['xyz.extera.room_privacy_settings.$roomId']!.content;
  return content.tryGet('read_receipts') ??
      AppSettings.sendPublicReadReceipts.value;
}

bool shouldSendTypingNotifications(Client client, String roomId) {
  if (!hasIndividualPrivacyOptionsEnabled(client, roomId))
    return AppSettings.sendTypingNotifications.value;
  final content =
      client.accountData['xyz.extera.room_privacy_settings.$roomId']!.content;
  return content.tryGet('typing_notifications') ??
      AppSettings.sendTypingNotifications.value;
}
