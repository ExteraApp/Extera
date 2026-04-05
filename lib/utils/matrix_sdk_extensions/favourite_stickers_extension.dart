import 'package:matrix/matrix.dart';

extension FavouriteStickersExtension on Client {
  static const String _accountDataKey = 'xyz.extera.favourite_stickers';

  List<ImagePackImageContent> get favouriteStickers {
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

  bool isFavouriteSticker(ImagePackImageContent sticker) {
    return favouriteStickers.any(
      (s) => s.url.toString() == sticker.url.toString(),
    );
  }

  Future<void> addFavouriteSticker(ImagePackImageContent sticker) async {
    final current = favouriteStickers;

    current.removeWhere((s) => s.url.toString() == sticker.url.toString());

    current.insert(0, sticker);

    await setAccountData(userID!, _accountDataKey, {
      'stickers': current.map((s) => s.toJson()).toList(),
    });
  }

  Future<void> removeFavouriteSticker(ImagePackImageContent sticker) async {
    final current = favouriteStickers;

    current.removeWhere((s) => s.url.toString() == sticker.url.toString());

    await setAccountData(userID!, _accountDataKey, {
      'stickers': current.map((s) => s.toJson()).toList(),
    });
  }
}
