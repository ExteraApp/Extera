import 'dart:ui';

abstract class AppConfig {
  static const String pushIsolatePortName = 'push_isolate';
  static const String mainIsolatePortName = 'main_isolate';

  static const String bannerProfileField = 'chat.commet.profile_banner';

  static const String aboutProfileField = 'xyz.extera.about';
  static const String updateCheckUrl = 'https://extera.xyz/next/version.txt';
  static const String downloadUpdateUrl = 'https://extera.xyz/';

  static const String appSsoUrlScheme = 'xyz.extera.auth';

  static String _applicationName = 'Extera';

  static String get applicationName => _applicationName;
  static String? _applicationWelcomeMessage;

  static String? get applicationWelcomeMessage => _applicationWelcomeMessage;
  static String _defaultHomeserver = 'extera.xyz';

  static bool alreadyCheckedUpdates = false;

  static String get defaultHomeserver => _defaultHomeserver;
  static const Color chatColor = primaryColor;
  static const bool allowOtherHomeservers = true;
  static const bool enableRegistration = true;
  static const Color primaryColor = Color(0xFF5625BA);
  static const Color primaryColorLight = Color(0xFFCCBDEA);
  static const Color secondaryColor = Color(0xFF41a2bc);
  static String _privacyUrl =
      'https://github.com/ExteraApp/Extera/blob/main/PRIVACY.md';

  static String get privacyUrl => _privacyUrl;
  static const String website = 'https://extera.xyz';
  static const String enablePushTutorial =
      'https://github.com/krille-chan/fluffychat/wiki/Push-Notifications-without-Google-Services';
  static const String encryptionTutorial =
      'https://github.com/krille-chan/fluffychat/wiki/How-to-use-end-to-end-encryption-in-FluffyChat';
  static const String startChatTutorial =
      'https://github.com/krille-chan/fluffychat/wiki/How-to-Find-Users-in-FluffyChat';
  static const String appId = 'xyz.extera.next';
  static const String appOpenUrlScheme = 'xyz.extera.next';
  static String _webBaseUrl = 'https://fluffychat.im/web';

  static String get webBaseUrl => _webBaseUrl;
  static const String sourceCodeUrl = 'https://github.com/ExteraApp/Extera';
  static const String supportUrl = 'https://github.com/ExteraApp/Extera/issues';
  static const String changelogUrl =
      'https://github.com/ExteraApp/Extera/blob/main/CHANGELOG.md';
  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/ExteraApp/Extera/issues',
  );

  static const bool hideTypingUsernames = false;
  static const bool hideAllStateEvents = false;
  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'xyz.extera.next://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'exteranext_push';
  static const String pushNotificationsAppId = 'xyz.extera.next';
  static const String recentEmojisAccountDataKey = 'io.element.recent_emoji';
  static const double borderRadius = 18.0;
  static const double columnWidth = 360.0;
  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'servers.joinmatrix.org',
    path: 'servers.json',
  );
  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  // See CREDITS.md
  static const Map<String, String> ringtoneFiles = {
    // people won't answer calls listening to this banger
    'Homebase': 'sounds/ringtones/homebase.mp3',
    'Dream of Light': 'sounds/ringtones/dream_of_light.mp3',
  };

  static void loadFromJson(Map<String, dynamic> json) {
    // if (json['chat_color'] != null) {
    //   try {
    //     colorSchemeSeed = Color(json['chat_color']);
    //   } catch (e) {
    //     Logs().w(
    //       'Invalid color in config.json! Please make sure to define the color in this format: "0xffdd0000"',
    //       e,
    //     );
    //   }
    // }
    if (json['application_name'] is String) {
      _applicationName = json['application_name'];
    }
    if (json['application_welcome_message'] is String) {
      _applicationWelcomeMessage = json['application_welcome_message'];
    }
    if (json['default_homeserver'] is String) {
      _defaultHomeserver = json['default_homeserver'];
    }
    if (json['privacy_url'] is String) {
      _privacyUrl = json['privacy_url'];
    }
    if (json['web_base_url'] is String) {
      _webBaseUrl = json['web_base_url'];
    }
  }
}
