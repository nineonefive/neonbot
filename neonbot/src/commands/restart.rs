use crate::Context;

/// Shuts down neonbot
#[poise::command(slash_command, owners_only)]
pub async fn restart(ctx: Context<'_>) -> anyhow::Result<()> {
    tracing::info!("Received restart command, shutting down");
    ctx.framework().shard_manager().shutdown_all().await;
    Ok(())
}
