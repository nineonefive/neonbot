import 'package:nyxx/nyxx.dart' hide Cache;

import '../cache.dart';
import '../services/valorantapi.dart';
import '../util.dart' as util;

enum ValorantMap {
  abyss("Abyss", ":hourglass:"),
  ascent("Ascent", ":wind_blowing_face:"),
  bind("Bind", ":desert:"),
  breeze("Breeze", ":island:"),
  corrode("Corrode", ":tornado:"),
  fracture("Fracture", ":radioactive:"),
  haven("Haven", ":japanese_castle:"),
  icebox("Icebox", ":snowflake:"),
  lotus("Lotus", ":lotus:"),
  pearl("Pearl", ":ocean:"),
  split("Split", ":bullettrain_front:"),
  sunset("Sunset", ":city_sunset:"),
  playoffs("Playoffs", ":trophy:");

  const ValorantMap(this.name, this.emoji);

  final String name;
  final String emoji;

  static Cache<ValorantMap, ImageBuilder> _imageCache = Cache(
    retrieve: (map) => map.downloadImage(),
  );

  Future<ImageBuilder> get image async => (await _imageCache.get(this))!;

  Future<ImageBuilder> downloadImage() async {
    Uri imageUrl;
    String format;

    if (this == playoffs) {
      format = "jpg";
      imageUrl = Uri.parse(
          "https://oyster.ignimgs.com/mediawiki/apis.ign.com/valorant/3/3c/Premier_Tournament_Structure.JPG?width=800");
    } else {
      format = "png";
      imageUrl = (await ValorantApi().getImageUrlForMap(this))!;
    }

    var data = await util.downloadImage(imageUrl);
    return ImageBuilder(data: data, format: format);
  }

  static ValorantMap getByName(String? name) {
    for (var map in values) {
      if (map.name == name) {
        return map;
      }
    }

    return playoffs;
  }
}
