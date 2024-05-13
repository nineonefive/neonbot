import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds/config.dart';
import '../models/guild_preferences.dart';
import '../models/valorant_regions.dart';
import '../services/guilds.dart';
import 'formhandler.dart';

class ConfigFormHandler extends MessageFormHandler {
  final GuildPreferences gp;
  final dynamic memento;

  ConfigFormHandler._(super.context, super.message, this.gp, this.memento);

  static Future<ConfigFormHandler> create(
      ChatContext context, Message message) async {
    var gp = await GuildService().getPreferences(context.guild!.id);
    var memento = gp.getMemento();

    return ConfigFormHandler._(context, message, gp, memento);
  }

  @override
  Future<bool> handle() async {
    var interaction = lastInteraction!;
    var snowflakeData = Snowflake(
        int.tryParse(interaction.data.values?.firstOrNull ?? "0") ?? 0);
    var premierRegionData =
        Region.fromId(interaction.data.values?.firstOrNull ?? "");

    switch (interaction.data.customId) {
      // When the user submits, we persist the changes and remove the form.
      case "submit":
        // Avoid 10062 error
        await message.update(
            MessageUpdateBuilder(content: ":hourglass:", components: []));
        return true;

      // When the user cancels, we should refresh the preferences from the database
      case "cancel":
        await message.update(MessageUpdateBuilder(
            content: ":x: Cancelled by user", components: []));

        gp.updateFromMemento(memento);
        return true;

      // If the user edits other settings, we simply acknowledge them
      case "announcementChannel":
        gp.announcementsChannel = snowflakeData;
        await interaction.acknowledge(updateMessage: true);
        return false;
      case "voiceChannel":
        gp.voiceChannel = snowflakeData;
        await interaction.acknowledge(updateMessage: true);
        return false;
      case "signupRole":
        gp.signupRole = snowflakeData;
        await interaction.acknowledge(updateMessage: true);
        return false;
      case "premierRegion":
        gp.premierRegion = premierRegionData;
        await interaction.acknowledge(updateMessage: true);
        return false;
    }

    return false;
  }

  @override
  Future<void> onDone() async {
    // Save new preferences
    await GuildService().savePreferences(gp);
    await message.update(MessageUpdateBuilder(
        content: "", embeds: [await gp.asEmbed], components: []));
  }

  @override
  Future<void> onExpire() async {
    // Restore guild settings
    gp.updateFromMemento(memento);
    await GuildService().savePreferences(gp);
  }
}

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
      SelectMenuBuilder.stringSelect(
          customId: "premierRegion",
          placeholder: "Premier region",
          minValues: 1,
          maxValues: 1,
          options: Region.values.where((r) => r != Region.none).map((r) {
            return SelectMenuOptionBuilder(
              label: r.name,
              value: r.id,
            );
          }).toList())
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
        "- **Premier region**: Region where the premier team is based"
      ].join("\n");

  var messageBuilder = MessageBuilder(content: content, components: components);
  return messageBuilder;
}
