use poise::FrameworkError;
use serenity::gateway::ActivityData;
use serenity::model::user::OnlineStatus;
use serenity::{Client, all::GatewayIntents};
use std::sync::Arc;
use tracing::{debug, error};
use tracing_subscriber::EnvFilter;
use valorant_api::Client as ValoClient;

use crate::services::AutoReact;
use crate::services::GuildService;
use crate::services::ScheduleService;
use crate::services::TeamService;

mod commands;
mod db;
mod emojis;
mod services;
mod style;
mod types;

pub type Context<'a> = poise::Context<'a, (), anyhow::Error>;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    // Optional: load environment variables from .env file
    dotenvy::dotenv().ok();

    // Set up logging
    let filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("warn,neonbot=info"));
    tracing_subscriber::fmt().with_env_filter(filter).init();

    // Start up the database
    let db = db::get_db().await.unwrap();

    // Obtain token and start serenity
    let discord_token =
        std::env::var("NEONBOT_TOKEN").expect("Need to set discord token with NEONBOT_TOKEN");
    let valo_token = std::env::var("VALORANT_API_TOKEN")
        .expect("Need to set valorant token with VALORANT_API_TOKEN");

    // Breakdown of the permissions:
    // - guildMessageReactions: Needed for auto react or possibly signup mechanisms
    // - guildMembers: See what roles each user has in the scheduled events
    // - guildMessages: Needed for autoreact
    // - guildScheduledEvents: Needed for scheduling matches to the discord events list
    // - guilds: So we receive GUILD_CREATE so we know what servers we're in
    // - messageContent: needed for autoreactions
    let intents = GatewayIntents::GUILD_MESSAGE_REACTIONS
        | GatewayIntents::GUILD_MEMBERS
        | GatewayIntents::GUILD_MESSAGES
        | GatewayIntents::GUILD_SCHEDULED_EVENTS
        | GatewayIntents::GUILDS
        | GatewayIntents::MESSAGE_CONTENT;

    debug!("Initializing services");
    let valo_client = ValoClient::new_with_token(&valo_token);
    let guild_service = Arc::new(GuildService::new(db.clone()));
    let schedule_service = Arc::new(ScheduleService::new(valo_client.clone()));
    let team_service = Arc::new(TeamService::new(valo_client.clone()));

    debug!("Initializing framework");
    let framework = poise::Framework::<(), anyhow::Error>::builder()
        .options(poise::FrameworkOptions {
            commands: vec![commands::config(), commands::restart()],
            on_error: |error| {
                Box::pin(async move {
                    // First arg is None if the check succeeds and it returns false
                    if let FrameworkError::CommandCheckFailed {
                        error: None, ctx, ..
                    } = error
                    {
                        ctx.say(":x: you do not have permission").await.unwrap();
                        return;
                    }

                    match error.ctx() {
                        Some(ctx) => {
                            let cmd = &ctx.command().qualified_name;
                            tracing::error!("Error in poise command `{}`: {}", cmd, error);
                        }
                        None => {
                            tracing::error!("Error in poise command: {}", error);
                        }
                    }
                })
            },
            ..Default::default()
        })
        .setup(|ctx, _ready, framework| {
            Box::pin(async move {
                poise::builtins::register_globally(ctx, &framework.options().commands).await?;
                Ok(())
            })
        })
        .build();

    debug!("Initializing client");
    let mut client = Client::builder(&discord_token, intents)
        .framework(framework)
        .event_handler(AutoReact::new())
        .event_handler_arc(guild_service.clone())
        .event_handler_arc(schedule_service.clone())
        .status(OnlineStatus::Online)
        .activity(ActivityData::playing("VALORANT"))
        .await
        .expect("Failed to create client");

    debug!("Client initialized, injecting data");
    {
        let mut data = client.data.write().await;
        data.insert::<GuildService>(guild_service.clone());
        data.insert::<ScheduleService>(schedule_service.clone());
        data.insert::<TeamService>(team_service.clone());
    }

    if let Err(why) = client.start().await {
        error!("Error initializing client: {why:?}");
    }
}
