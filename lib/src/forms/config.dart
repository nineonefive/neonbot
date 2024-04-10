// Otherwise construct the configuration modal
import 'package:nyxx/nyxx.dart';

import '../services/guilds.dart';

Future<MessageBuilder> createConfigForm(Snowflake guildId) async {
  var gp = await GuildService().getPreferences(guildId);
  var components = [
    // Selection modal for the announcement channel
    ActionRowBuilder(components: [
      SelectMenuBuilder.channelSelect(
          customId: "announcementChannel",
          placeholder: "Announcements channel",
          minValues: 1,
          maxValues: 1,
          defaultValues: gp.hasAnnouncementsChannel
              ? [DefaultValue.channel(id: gp.announcementsChannel)]
              : null)
    ]),
    // Selection modal for the voice channel
    ActionRowBuilder(components: [
      SelectMenuBuilder.channelSelect(
          customId: "voiceChannel",
          placeholder: "Match voice channel",
          minValues: 1,
          maxValues: 1,
          defaultValues: gp.hasVoiceChannel
              ? [DefaultValue.channel(id: gp.voiceChannel)]
              : null)
    ]),
    // Selection modal for the role mention
    ActionRowBuilder(components: [
      SelectMenuBuilder.roleSelect(
          customId: "signupRole",
          placeholder: "Signup role",
          minValues: 1,
          maxValues: 1,
          defaultValues:
              gp.hasSignupRole ? [DefaultValue.role(id: gp.signupRole)] : null)
    ]),
    ActionRowBuilder(components: [
      ButtonBuilder(
        customId: "submit",
        style: ButtonStyle.primary,
        label: "Save",
      ),
      ButtonBuilder(
        customId: "cancel",
        style: ButtonStyle.secondary,
        label: "Cancel",
      )
    ])
  ];

// ignore: prefer_interpolation_to_compose_strings
  var content = "Update the server config:\n" +
      [
        "- **Announcements channel**: New schedule notifications will be posted here",
        "- **Voice channel**: Events will be hosted in this voice channel",
        "- **Signup role**: Members with this role will be counted towards event signups",
      ].join("\n");

  var messageBuilder = MessageBuilder(content: content, components: components);
  return messageBuilder;
}
