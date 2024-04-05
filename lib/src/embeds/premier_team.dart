import 'package:nyxx/nyxx.dart';

import '../models/premier_team.dart';
import '../style.dart';
import '../util.dart';

extension PremierTeamEmbeddable on PremierTeam {
  EmbedBuilder get asEmbed {
    var description = [
      "**Rank**: \\#$rank",
      "**Season points**: $leagueScore",
      "**Division**: $division",
      "**Zone**: $zoneName"
    ].join("\n");

    var timeString = DateTime.now().difference(lastUpdated).formatted;
    timeString = timeString == "now" ? timeString : "$timeString ago";
    var footer = EmbedFooterBuilder(text: "Last updated $timeString");

    var embed = EmbedBuilder(
        title: riotId,
        description: description,
        footer: footer,
        color: Colors.primary,
        url: Uri.https('tracker.gg', '/valorant/premier/teams/$id'),
        image: EmbedImageBuilder(url: Uri.parse(imageUrl)));

    return embed;
  }
}
