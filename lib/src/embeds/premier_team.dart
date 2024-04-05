import 'package:nyxx/nyxx.dart';

import '../models/premier_team.dart';
import '../style.dart';
import '../util.dart';

extension PremierTeamEmbeddable on PremierTeam {
  EmbedBuilder get asEmbed {
    var description = [
      "**Rank**: \\#$rank",
      "**Division**: $division",
      "**Season points**: $leagueScore",
      "**Zone**: $zoneName"
    ].join("\n");

    var footer = EmbedFooterBuilder(
        text:
            "Last updated ${DateTime.now().difference(lastUpdated).formatted}");

    var embed = EmbedBuilder(
        color: Colors.primary,
        title: riotId,
        url: Uri.https('tracker.gg', '/valorant/premier/teams/$id'),
        description: description,
        footer: footer);

    return embed;
  }
}
