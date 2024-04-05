import 'package:neonbot/src/services/valorantapi.dart';
import 'package:nyxx/nyxx.dart';

import 'util.dart';

class Colors {
  static final primary = DiscordColor.parseHexString('#03fccf');
}

final botFooter = EmbedFooterBuilder(text: "Made with 💙 by 915");

enum ValorantMap {
  Ascent("Ascent", ":wind_blowing_face:"),
  Bind("Bind", ":desert:"),
  Breeze("Breeze", ":island:"),
  Fracture("Fracture", ":radioactive:"),
  Haven("Haven", ":japanese_castle:"),
  Icebox("Icebox", ":snowflake:"),
  Lotus("Lotus", ":lotus:"),
  Pearl("Pearl", ":ocean:"),
  Split("Split", ":bullettrain_front:"),
  Sunset("Sunset", ":city_sunset:"),
  Playoffs("Playoffs", ":trophy:");

  const ValorantMap(this.name, this.emoji);

  final String name;
  final String emoji;

  static Map<ValorantMap, ImageBuilder> _imageCache = {};

  Future<ImageBuilder> get image async {
    // Get from cache if possible
    if (_imageCache.containsKey(this)) {
      return _imageCache[this]!;
    }

    // Download otherwise
    Uri imageUrl;
    String format;

    if (this == ValorantMap.Playoffs) {
      format = "jpg";
      imageUrl = Uri.parse(
          "https://oyster.ignimgs.com/mediawiki/apis.ign.com/valorant/3/3c/Premier_Tournament_Structure.JPG?width=800");
    } else {
      format = "png";
      imageUrl = (await ValorantApi.service.getImageForMap(this))!;
    }

    var data = await downloadImage(imageUrl);
    var builder = ImageBuilder(data: data, format: format);
    _imageCache[this] = builder;
    return builder;
  }

  static ValorantMap getByName(String? name) {
    for (var map in values) {
      if (map.name == name) {
        return map;
      }
    }

    return ValorantMap.Playoffs;
  }
}
