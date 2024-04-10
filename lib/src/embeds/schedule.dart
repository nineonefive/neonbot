import 'package:nyxx/nyxx.dart';

import '../models/valorant_maps.dart';
import '../models/valorant_regions.dart';
import '../util.dart';
import '../models/match_schedule.dart';
import '../style.dart';

/// Embed used by /schedule command
///
/// Shows upcoming matches, localized to the zone.
extension ScheduleEmbeddable on MatchSchedule {
  EmbedBuilder asEmbed(Region region) {
    String scheduleString = "";
    ValorantMap? lastMap;
    int mapsShown = 0;
    for (var match in upcomingMatches) {
      // Group by map. If this is a new map, then we add a header
      if (match.map != lastMap || match.matchType == MatchType.playoffs) {
        mapsShown++;

        // Cap our maps shown to reduce the embed size
        if (mapsShown > 3) {
          break;
        }

        lastMap = match.map;
        var header = "${match.map.emoji}  ${match.map.name}";
        scheduleString += "## $header\n";
      }

      // Print match
      scheduleString +=
          "- ${match.matchType.name} ${match.time.toDiscord(region)}\n";
    }

    return EmbedBuilder()
      ..color = Colors.primary
      ..footer = EmbedFooterBuilder(text: "Times shown in your local time")
      ..title = "${region.name} Schedule"
      ..description = scheduleString;
  }
}
