use std::sync::Arc;

use anyhow::Result;
use chrono::{DateTime, TimeZone, Utc};
use moka::notification::RemovalCause;
use serde::{Deserialize, Serialize};
use serenity::{
    all::prelude::{Context, EventHandler},
    async_trait,
    model::{
        guild::Guild,
        id::{ChannelId, GuildId, RoleId},
    },
};
use sqlx::{Row, SqlitePool};
use tracing::{error, info};

use crate::types::PartialPremierTeam;

/// The preferences for a guild
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct GuildPreferences {
    /// The id of the guild this is for
    pub guild_id: GuildId,

    /// Where the members choose to receive neonbot announcements
    pub announcements_channel: Option<ChannelId>,

    /// The voice channel where events are tied to
    pub voice_channel: Option<ChannelId>,

    /// Members with this role will be tagged whenever the schedule is updated
    pub signup_role: Option<RoleId>,

    /// The premier team this guild is associated with
    pub premier_team: Option<PartialPremierTeam>,

    /// The last time the schedule of events in *this guild* was updated
    pub schedule_last_updated: DateTime<Utc>,
}

impl GuildPreferences {
    pub fn new(guild_id: GuildId) -> Self {
        Self {
            guild_id,
            announcements_channel: None,
            voice_channel: None,
            signup_role: None,
            premier_team: None,
            schedule_last_updated: Utc.timestamp_nanos(0),
        }
    }
}

#[derive(Clone)]
pub struct GuildService {
    db: SqlitePool,
    cache: moka::future::Cache<GuildId, GuildPreferences>,
}

impl GuildService {
    pub fn new(db: SqlitePool) -> Self {
        let cache_db = db.clone();
        Self {
            db,
            cache: moka::future::CacheBuilder::<GuildId, GuildPreferences, _>::new(100)
                .async_eviction_listener(move |key: Arc<GuildId>, value, reason| {
                    let cache_db = cache_db.clone();
                    Box::pin(async move {
                        if reason == RemovalCause::Size {
                            tracing::debug!("Evicting guild preferences for guild {}", key);
                            if let Err(e) =
                                GuildService::persist_preferences(&cache_db, *key, value).await
                            {
                                tracing::error!(
                                    "Failed to save guild preferences for guild {}: {}",
                                    key,
                                    e
                                );
                            }
                        }
                    })
                })
                .build(),
        }
    }

    async fn persist_preferences(
        db: &SqlitePool,
        guild_id: GuildId,
        preferences: GuildPreferences,
    ) -> Result<()> {
        let json = serde_json::to_value(preferences)?;
        sqlx::query("update guild_preferences set preferences = $1 where guild_id = $2")
            .bind(json)
            .bind(guild_id.get() as i64)
            .execute(db)
            .await
            .map_err(|e| anyhow::anyhow!(e))?;
        Ok(())
    }

    async fn update_preferences(
        &self,
        guild_id: GuildId,
        preferences: GuildPreferences,
    ) -> Result<()> {
        self.cache.insert(guild_id, preferences.clone()).await;
        let json = serde_json::to_value(preferences)?;
        sqlx::query("update guild_preferences set preferences = $1 where guild_id = $2")
            .bind(json)
            .bind(guild_id.get() as i64)
            .execute(&self.db)
            .await
            .map_err(|e| anyhow::anyhow!(e))?;
        Ok(())
    }

    async fn get_preferences(&self, guild_id: GuildId) -> Result<Option<GuildPreferences>> {
        // First check the cache
        if let Some(prefs) = self.cache.get(&guild_id).await {
            return Ok(Some(prefs));
        }

        // Check if it exists in the database
        let row = sqlx::query("select * from guild_preferences where guild_id = $1")
            .bind(guild_id.get() as i64)
            .fetch_optional(&self.db)
            .await
            .map_err(|e| {
                anyhow::anyhow!(
                    "Error fetching guild preferences for guild {:?}: {}",
                    guild_id,
                    e
                )
            })?;

        // If we found an existing row, add it to the cache and return it
        if let Some(row) = row {
            let prefs = row.try_get::<String, _>("preferences").map_err(|e| {
                anyhow::anyhow!(
                    "Error deserializing preferences from database for guild {:?}: {}",
                    guild_id,
                    e
                )
            })?;
            let prefs: GuildPreferences = serde_json::from_str(&prefs)?;
            self.cache.insert(guild_id, prefs.clone()).await;
            return Ok(Some(prefs));
        }

        Ok(None)
    }

    async fn create_preferences(&self, guild_id: GuildId) -> Result<GuildPreferences> {
        let prefs = GuildPreferences::new(guild_id);
        sqlx::query("insert into guild_preferences (guild_id, preferences) values ($1, $2)")
            .bind(guild_id.get() as i64)
            .bind(serde_json::to_string(&prefs)?)
            .execute(&self.db)
            .await
            .map_err(|e| {
                anyhow::anyhow!(
                    "Error creating new preferences for guild {:?}: {}",
                    guild_id,
                    e
                )
            })?;
        self.cache.insert(guild_id, prefs.clone()).await;
        Ok(prefs)
    }

    async fn maybe_create_preferences(&self, guild_id: GuildId) {
        // Check if the guild has preferences or create them
        let result = self.get_preferences(guild_id).await;
        if result.is_err() {
            error!(
                "Failed to get preferences for guild {:?}: {}",
                guild_id,
                result.err().unwrap()
            );
            return;
        }

        let result = result.unwrap();
        if result.is_none() {
            info!(
                "No preferences found for guild {:?}, creating default.",
                guild_id
            );
            if let Err(why) = self.create_preferences(guild_id).await {
                error!(
                    "Failed to create preferences for guild {:?}: {}",
                    guild_id, why
                );
            }
        }
    }
}

#[async_trait]
impl EventHandler for GuildService {
    async fn guild_create(&self, _ctx: Context, guild: Guild, _is_new: Option<bool>) {
        self.maybe_create_preferences(guild.id).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn get_db() -> Result<SqlitePool> {
        let db = SqlitePool::connect(":memory:").await?;
        sqlx::query("create table guild_preferences (id integer primary key, guild_id integer, preferences text)")
            .execute(&db)
            .await
            .unwrap();
        Ok(db)
    }

    #[tokio::test]
    async fn test_get_nonexistent_guild() {
        let db = get_db().await.unwrap();
        let service = GuildService::new(db.clone());
        let guild_id = GuildId::new(123);
        let prefs = service.get_preferences(guild_id).await.unwrap();
        assert!(prefs.is_none());
    }

    #[tokio::test]
    async fn test_get_guild_through_db() {
        let db = get_db().await.unwrap();
        let service = GuildService::new(db.clone());
        let guild_id = GuildId::new(123);

        // Create a preference to make sure it's in the db, then we call update
        // to make our new (non default) value take effect in the cache and db. finally,
        // invalidate the cache to ensure the read is from the db
        let mut expected_prefs = service.create_preferences(guild_id).await.unwrap();
        expected_prefs.signup_role = Some(RoleId::new(456));
        service
            .update_preferences(guild_id, expected_prefs.clone())
            .await
            .unwrap();
        service.cache.invalidate(&guild_id).await;

        let prefs = service.get_preferences(guild_id).await.unwrap();
        assert_eq!(prefs, Some(expected_prefs));
    }

    #[tokio::test]
    async fn test_get_guild_through_cache() {
        let db = get_db().await.unwrap();
        let service = GuildService::new(db.clone());
        let guild_id = GuildId::new(123);

        // Create a preference to make sure it's in the db, then we call update
        // to make our new (non default) value take effect in the cache and db.
        let mut expected_prefs = service.create_preferences(guild_id).await.unwrap();
        expected_prefs.signup_role = Some(RoleId::new(456));
        service
            .update_preferences(guild_id, expected_prefs.clone())
            .await
            .unwrap();

        let prefs = service.get_preferences(guild_id).await.unwrap();
        assert_eq!(prefs, Some(expected_prefs));
    }
}
