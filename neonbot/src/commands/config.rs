use std::sync::Arc;
use std::time::Duration;

use crate::{emojis::Emoji, types::Conference};
use futures::StreamExt;
use poise::CreateReply;
use serenity::{
    builder::{
        CreateActionRow, CreateButton, CreateEmbed, CreateInteractionResponse,
        CreateInteractionResponseMessage, CreateSelectMenu, CreateSelectMenuKind,
        CreateSelectMenuOption,
    },
    collector::ComponentInteractionCollector,
    model::{
        application::{ButtonStyle, ComponentInteractionDataKind},
        channel::ChannelType,
        mention::Mention,
    },
};
use tracing_subscriber::fmt::format;

use crate::{
    Context,
    services::{GuildPreferences, GuildService, TeamService},
    style::{PRIMARY_COLOR, bot_footer},
};

#[poise::command(
    slash_command,
    subcommands("show", "edit", "set_team"),
    guild_only,
    check = "is_neonbot_admin"
)]
pub async fn config(_ctx: Context<'_>) -> anyhow::Result<()> {
    Ok(())
}

/// Shows the current guild config
#[poise::command(slash_command, ephemeral)]
pub async fn show(ctx: Context<'_>) -> anyhow::Result<()> {
    let (_, prefs) = get_guild_prefs(&ctx).await?;
    ctx.send(config_embed_reply(&prefs)).await?;
    Ok(())
}

/// Edit the server config interactively
#[poise::command(slash_command, ephemeral)]
pub async fn edit(ctx: Context<'_>) -> anyhow::Result<()> {
    let guild_id = ctx
        .guild_id()
        .expect("Should only be callable from a guild");
    let (guild_service, mut prefs) = get_guild_prefs(&ctx).await?;

    let handle = ctx.send(config_form_reply(&prefs)).await?;
    let msg = handle.message().await?;

    let mut submitted = false;
    let mut cancelled = false;
    let mut stream = ComponentInteractionCollector::new(ctx.serenity_context())
        .author_id(ctx.author().id)
        .message_id(msg.id)
        .timeout(Duration::from_secs(120))
        .stream();

    while let Some(interaction) = stream.next().await {
        match interaction.data.custom_id.as_str() {
            "announcementChannel" => {
                if let ComponentInteractionDataKind::ChannelSelect { values } =
                    &interaction.data.kind
                {
                    prefs.announcements_channel = values.first().copied();
                }
                interaction
                    .create_response(ctx, CreateInteractionResponse::Acknowledge)
                    .await?;
            }
            "voiceChannel" => {
                if let ComponentInteractionDataKind::ChannelSelect { values } =
                    &interaction.data.kind
                {
                    prefs.voice_channel = values.first().copied();
                }
                interaction
                    .create_response(ctx, CreateInteractionResponse::Acknowledge)
                    .await?;
            }
            "signupRole" => {
                if let ComponentInteractionDataKind::RoleSelect { values } = &interaction.data.kind
                {
                    prefs.signup_role = values.first().copied();
                }
                interaction
                    .create_response(ctx, CreateInteractionResponse::Acknowledge)
                    .await?;
            }
            "premierConference" => {
                if let ComponentInteractionDataKind::StringSelect { values } =
                    &interaction.data.kind
                {
                    prefs.premier_conference =
                        values.first().and_then(|s| s.parse::<Conference>().ok());
                }
                interaction
                    .create_response(ctx, CreateInteractionResponse::Acknowledge)
                    .await?;
            }
            "submit" => {
                interaction
                    .create_response(
                        ctx,
                        CreateInteractionResponse::UpdateMessage(
                            CreateInteractionResponseMessage::new()
                                .content(":hourglass:")
                                .components(vec![]),
                        ),
                    )
                    .await?;
                submitted = true;
                break;
            }
            "cancel" => {
                interaction
                    .create_response(
                        ctx,
                        CreateInteractionResponse::UpdateMessage(
                            CreateInteractionResponseMessage::new()
                                .content(":x: cancelled by user")
                                .components(vec![]),
                        ),
                    )
                    .await?;
                cancelled = true;
                break;
            }
            _ => {}
        }
    }

    if submitted {
        // save the preferences and then show them as if they did /config show
        guild_service
            .update_preferences(guild_id, prefs.clone())
            .await?;
        handle
            .edit(ctx, config_embed_reply(&prefs).content(""))
            .await?;
    } else if !cancelled {
        // timed out
        handle
            .edit(
                ctx,
                CreateReply::default()
                    .content(":x: form expired")
                    .components(vec![]),
            )
            .await?;
    }

    Ok(())
}

/// Sets the premier team for this guild
#[poise::command(slash_command, rename = "set-team")]
pub async fn set_team(
    ctx: Context<'_>,
    #[description = "The Riot ID of your team, e.g. team#1234"] team: String,
) -> anyhow::Result<()> {
    let team = team.trim();
    if team.is_empty() {
        ctx.say(":x: the team cannot be empty").await?;
        return Ok(());
    }

    let (guild_service, mut prefs) = get_guild_prefs(&ctx).await?;

    let team_service = {
        let data = ctx.serenity_context().data.read().await;
        data.get::<TeamService>().unwrap().clone()
    };

    let teams = team_service.search_teams_by_riot_id(team).await;
    if let Err(e) = teams {
        ctx.send(
            CreateReply::default()
                .content(":x: there was an error searching for the team")
                .ephemeral(true),
        )
        .await?;
        return Err(anyhow::anyhow!("Failed to search for team: {}", e));
    }

    let teams = teams.unwrap();
    if teams.is_empty() {
        ctx.send(
            CreateReply::default()
                .content(format!(":x: no team found with Riot ID `{}`", team))
                .ephemeral(true),
        )
        .await?;
        return Ok(());
    }
    if teams.len() > 1 {
        ctx.send(
            CreateReply::default()
                .content(format!(":x: multiple teams found with Riot ID `{}`", team))
                .ephemeral(true),
        )
        .await?;
        return Ok(());
    }

    prefs.set_premier_team(teams[0].clone().into());
    guild_service
        .update_preferences(ctx.guild_id().expect("only callable from guilds"), prefs)
        .await?;

    Ok(())
}

/// Loads the GuildService and GuildPreferences for the current guild
async fn get_guild_prefs(
    ctx: &Context<'_>,
) -> anyhow::Result<(Arc<GuildService>, GuildPreferences)> {
    let guild_id = ctx.guild_id().expect("only callable from a guild");

    let guild_service = {
        let data = ctx.serenity_context().data.read().await;
        data.get::<GuildService>().unwrap().clone()
    };

    let prefs = guild_service.get_preferences(guild_id).await;

    match prefs {
        Err(e) => {
            ctx.send(
                CreateReply::default()
                    .content(":x: there was an error retrieving your guild's preferences")
                    .ephemeral(true),
            )
            .await?;
            Err(anyhow::anyhow!(
                "failed to get guild preferences for {}: {}",
                guild_id,
                e
            ))
        }
        Ok(None) => {
            ctx.send(
                CreateReply::default()
                    .content(":x: there was an error retrieving your guild's preferences")
                    .ephemeral(true),
            )
            .await?;
            Err(anyhow::anyhow!(
                "guild preferences not found for {}, should have been set in guild_create",
                guild_id
            ))
        }
        Ok(Some(prefs)) => Ok((guild_service, prefs)),
    }
}

/// Returns a reply containing the config summary embed.
fn config_embed_reply(prefs: &GuildPreferences) -> CreateReply {
    let description = [
        "### general".to_owned(),
        format!(
            "announcements channel: {}",
            mention(prefs.announcements_channel)
        ),
        format!("voice channel: {}", mention(prefs.voice_channel)),
        format!("signup role: {}", mention(prefs.signup_role)),
        format!("### {} premier", Emoji::ValorantPremier),
        format!(
            "premier team: `{}`",
            prefs
                .premier_team
                .as_ref()
                .map(|t| t.riot_id())
                .unwrap_or("none".to_owned())
        ),
        format!(
            "premier conference: `{}`",
            prefs
                .premier_conference
                .map(|c| c.to_string())
                .unwrap_or("none".to_owned())
        ),
    ]
    .join("\n");

    let embed = CreateEmbed::new()
        .title(":gear: server config")
        .description(description)
        .color(PRIMARY_COLOR)
        .footer(bot_footer());

    CreateReply::default().embed(embed)
}

/// Builds the interactive config form reply for the given preferences.
fn config_form_reply(prefs: &GuildPreferences) -> CreateReply {
    let content = ":gear: update the server config:\n\
        - **announcements channel**: new schedule notifications will be posted here\n\
        - **voice channel**: events will be hosted in this voice channel\n\
        - **signup role**: members with this role will be counted towards event signups\n\
        - **premier conference**: conference where your premier team competes";

    let announcement_select = CreateSelectMenu::new(
        "announcementChannel",
        CreateSelectMenuKind::Channel {
            channel_types: vec![ChannelType::Text].into(),
            default_channels: prefs.announcements_channel.map(|c| vec![c]),
        },
    )
    .placeholder("Announcements channel")
    .min_values(0)
    .max_values(1);

    let voice_select = CreateSelectMenu::new(
        "voiceChannel",
        CreateSelectMenuKind::Channel {
            channel_types: vec![ChannelType::Voice].into(),
            default_channels: prefs.voice_channel.map(|c| vec![c]),
        },
    )
    .placeholder("Match voice channel")
    .min_values(0)
    .max_values(1);

    let role_select = CreateSelectMenu::new(
        "signupRole",
        CreateSelectMenuKind::Role {
            default_roles: prefs.signup_role.map(|r| vec![r]),
        },
    )
    .placeholder("Signup role")
    .min_values(0)
    .max_values(1);

    let conference_options = all_conferences()
        .iter()
        .map(|&c| {
            let value = c.to_string();
            CreateSelectMenuOption::new(&value, &value)
                .default_selection(prefs.premier_conference == Some(c))
        })
        .collect();

    let conference_select = CreateSelectMenu::new(
        "premierConference",
        CreateSelectMenuKind::String {
            options: conference_options,
        },
    )
    .placeholder("Premier conference")
    .min_values(0)
    .max_values(1);

    CreateReply::default().content(content).components(vec![
        CreateActionRow::SelectMenu(announcement_select),
        CreateActionRow::SelectMenu(voice_select),
        CreateActionRow::SelectMenu(role_select),
        CreateActionRow::SelectMenu(conference_select),
        CreateActionRow::Buttons(vec![
            CreateButton::new("submit")
                .label("Save")
                .style(ButtonStyle::Primary),
            CreateButton::new("cancel")
                .label("Cancel")
                .style(ButtonStyle::Secondary),
        ]),
    ])
}

/// Super conferences are excluded — they are internal Riot matchmaking groupings
/// that players cannot select as their premier region.
fn all_conferences() -> &'static [Conference] {
    use Conference::*;
    &[
        NaUsEast,
        NaUsWest,
        LatamNorth,
        LatamSouth,
        BrBrazil,
        EuCentralEast,
        EuWest,
        EuMiddleEast,
        EuTurkey,
        EuDach,
        EuIbit,
        EuFrance,
        EuEast,
        EuNorth,
        KrKorea,
        ApAsia,
        ApJapan,
        ApOceania,
        ApSouthAsia,
    ]
}

#[inline]
fn mention<T: Into<Mention>>(x: Option<T>) -> String {
    x.map(|x| format!("{}", x.into()))
        .unwrap_or("`none`".to_owned())
}

/// Checks if the user is a neonbot admin
///
/// The user must have a role literally titled "neonbot admin"
async fn is_neonbot_admin(ctx: Context<'_>) -> anyhow::Result<bool> {
    let admin_role_id = ctx
        .guild()
        .and_then(|g| g.role_by_name("neonbot admin").map(|r| r.id));

    let member = ctx.author_member().await;

    Ok(admin_role_id.is_some_and(|role_id| {
        member
            .map(|m| m.roles.iter().any(|&rid| rid == role_id))
            .unwrap_or(false)
    }))
}
