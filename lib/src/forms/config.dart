// Otherwise construct the configuration modal
import 'package:nyxx/nyxx.dart';

import '../services/preferences.dart';

Future<MessageBuilder> createConfigForm(Snowflake guildId) async {
  var gp = await GuildSettings.service.getForGuild(guildId);
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
          customId: "roleMention",
          placeholder: "Role to tag for signups",
          minValues: 1,
          maxValues: 1,
          defaultValues: gp.hasTagForSignupRole
              ? [DefaultValue.role(id: gp.tagForSignupRole)]
              : null)
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
        "- **Announcements channel**: Match signups will be posted here",
        "- **Match voice call channel**: Events will be hosted in this channel",
        "- **Mention role**: This role will be tagged when new events are posted"
      ].join("\n");

  var messageBuilder = MessageBuilder(content: content, components: components);
  return messageBuilder;
}
