import 'package:matrix/matrix.dart';

extension RecentStickersExtension on Client {
  static const String _accountDataKey = 'xyz.extera.recent_stickers';
  static const int _maxRecentStickers = 24;

  List<ImagePackImageContent> get recentStickers {
    final data = accountData[_accountDataKey]?.content;
    if (data == null) return [];

    final stickersJson = data.tryGetList<Map<String, dynamic>>('stickers');
    if (stickersJson == null) return [];

    return stickersJson
        .map(
          (json) =>
              ImagePackImageContent.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }

  Future<void> addRecentSticker(ImagePackImageContent sticker) async {
    final current = recentStickers;

    current.removeWhere((s) => s.url.toString() == sticker.url.toString());

    current.insert(0, sticker);

    if (current.length > _maxRecentStickers) {
      current.removeRange(_maxRecentStickers, current.length);
    }

    await setAccountData(userID!, _accountDataKey, {
      'stickers': current.map((s) => s.toJson()).toList(),
    });
  }

  Future<void> removeRecentSticker(ImagePackImageContent sticker) async {
    final current = recentStickers;

    current.removeWhere((s) => s.url.toString() == sticker.url.toString());

    await setAccountData(userID!, _accountDataKey, {
      'stickers': current.map((s) => s.toJson()).toList(),
    });
  }
}
