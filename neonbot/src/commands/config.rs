use poise::CreateReply;
use serenity::{
    builder::CreateEmbed,
    model::id::{ChannelId, RoleId},
};

use crate::{
    Context,
    services::GuildService,
    style::{PRIMARY_COLOR, bot_footer},
};

#[poise::command(
    slash_command,
    subcommands("show", "edit", "team"),
    guild_only,
    check = "is_neonbot_admin"
)]
pub async fn config(ctx: Context<'_>) -> anyhow::Result<()> {
    Ok(())
}

/// Shows the current guild config
#[poise::command(slash_command, ephemeral)]
pub async fn show(ctx: Context<'_>) -> anyhow::Result<()> {
    let guild_service = {
        let data = ctx.serenity_context().data.read().await;
        data.get::<GuildService>().unwrap().clone()
    };

    let prefs = guild_service
        .get_preferences(
            ctx.guild_id()
                .expect("Should only be callable from a guild"),
        )
        .await;

    if let Err(ref e) = prefs {
        ctx.reply(":x: there was an error retrieving your guild's preferences")
            .await?;
        return Err(anyhow::anyhow!(
            "Failed to get guild preferences in `show` command: {}",
            e
        ));
    }

    let prefs = prefs.unwrap();
    if prefs.is_none() {
        ctx.reply(":x: there was an error retrieving your guild's preferences")
            .await?;
        return Err(anyhow::anyhow!(
            "guild preferences not found for guild {}, should have been set in the guild_create event",
            ctx.guild_id().unwrap()
        ));
    }

    let prefs = prefs.unwrap();

    let reply = {
        let description = [
            format!(
                "**announcements channel**: {}",
                format_channel(prefs.announcements_channel)
            ),
            format!("**voice channel**: {}", format_channel(prefs.voice_channel)),
            format!("**signup role**: {}", format_role(prefs.signup_role)),
            format!(
                "**premier team**: {}",
                prefs
                    .premier_team
                    .as_ref()
                    .map(|t| t.riot_id())
                    .unwrap_or("none".to_owned())
            ),
            format!(
                "**premier conference**: {}",
                prefs
                    .premier_team
                    .as_ref()
                    .map(|t| t.conference.to_string())
                    .unwrap_or("none".to_owned())
            ),
        ]
        .join("\n");
        let embed = CreateEmbed::new()
            .title("server config")
            .description(description)
            .color(PRIMARY_COLOR)
            .footer(bot_footer());

        CreateReply::default().embed(embed)
    };

    ctx.send(reply).await?;
    Ok(())
}

#[poise::command(slash_command)]
pub async fn edit(ctx: Context<'_>) -> anyhow::Result<()> {
    Ok(())
}

#[poise::command(slash_command)]
pub async fn team(ctx: Context<'_>) -> anyhow::Result<()> {
    Ok(())
}

#[inline(always)]
fn format_channel(c: Option<ChannelId>) -> String {
    c.map(|c| "<#".to_owned() + &c.to_string() + ">")
        .unwrap_or("none".to_owned())
}

#[inline(always)]
fn format_role(r: Option<RoleId>) -> String {
    r.map(|r| "<@&".to_owned() + &r.to_string() + ">")
        .unwrap_or("none".to_owned())
}

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
