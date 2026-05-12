use serenity::{Client, all::GatewayIntents};
use tracing::{debug, error};
use tracing_subscriber::EnvFilter;

use crate::services::AutoReact;

pub mod emojis;
mod guild_preferences;
mod premier;
mod services;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    // Optional: load environment variables from .env file
    dotenv::dotenv().ok();

    let filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("warn,neonbot=info"));

    tracing_subscriber::fmt().with_env_filter(filter).init();

    // Obtain token and start serenity
    let token =
        std::env::var("NEONBOT_TOKEN").expect("Need to set discord token with NEONBOT_TOKEN");

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

    debug!("Initializing client");
    let mut client = Client::builder(&token, intents)
        .event_handler(AutoReact::new())
        .await
        .expect("Failed to create client");

    debug!("Client initialized, starting");
    if let Err(why) = client.start().await {
        error!("Error initializing client: {why:?}");
    }
}
