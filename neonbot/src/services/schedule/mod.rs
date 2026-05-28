use std::{collections::HashMap, sync::Arc, time::Duration};

use crate::{
    services::GuildService,
    types::{Affinity, Conference, EventType, PremierEvent, PremierSchedule},
};
use anyhow::Result;
use chrono_tz::Tz;
use moka::future::{Cache, CacheBuilder};
use serenity::{
    all::prelude::{Context, EventHandler, TypeMapKey},
    async_trait,
    http::Http,
    model::id::GuildId,
};
use tokio::{
    sync::OnceCell,
    task::{JoinHandle, JoinSet},
};
use tracing::{error, info};
use uuid::Uuid;
use valorant_api::types::{V1PremierSeasonDataItem, V1PremierSeasonDataItemEventsItem};

mod repair;
use repair::repair;

/// How often the scheduled events are updated in each guild
const SCHEDULE_UPDATE_INTERVAL: Duration = Duration::from_hours(1);

/// Service that manages the scheduled premier events
pub struct ScheduleService {
    /// The valorant API client used to fetch premier season data
    client: valorant_api::Client,

    /// Cache for the raw premier season data
    season_cache: Cache<Affinity, V1PremierSeasonDataItem>,

    /// Cache for the repaired premier schedule data per conference
    schedule_cache: Cache<Conference, PremierSchedule>,

    /// Cache for the timezone of each conference since that's fetched
    /// from another api endpoint
    tz_cache: Cache<Conference, chrono_tz::Tz>,

    /// The task that periodically updates the schedule cache
    schedule_update_task: OnceCell<JoinHandle<()>>,
}

/// Public methods
impl ScheduleService {
    /// Creates a new `ScheduleService` with the given valorant API client
    pub fn new(client: valorant_api::Client) -> Self {
        // These cache durations are long because I don't expect riot to change them often
        Self {
            client,
            season_cache: CacheBuilder::new(100)
                .time_to_live(Duration::from_hours(24))
                .build(),
            schedule_cache: CacheBuilder::new(100)
                .time_to_live(Duration::from_hours(24))
                .build(),
            tz_cache: CacheBuilder::new(100)
                .time_to_live(Duration::from_hours(24))
                .build(),
            schedule_update_task: OnceCell::new(),
        }
    }

    /// Fetches the current premier season for a given [`Affinity`].
    ///
    /// This method caches calls to `/valorant/v1/premier/seasons/{region}`.
    ///
    /// Returns [`Ok`] with the current season data, with [`None`] if there is no current season.
    pub async fn get_current_season(
        &self,
        affinity: Affinity,
    ) -> Result<Option<V1PremierSeasonDataItem>> {
        let now = chrono::Utc::now();
        if let Some(season) = self.season_cache.get(&affinity).await {
            if season.ends_at.is_some_and(|t| t < now) {
                return Ok(season.into());
            }
        }

        let seasons = self
            .client
            .get_valorant_v1_premier_seasons_region(affinity)
            .await
            .map(|r| r.into_inner().data)
            .map_err(|e| anyhow::anyhow!(e))?;

        for season in seasons {
            if let Some(starts_at) = season.starts_at
                && let Some(ends_at) = season.ends_at
            {
                if starts_at <= now && now <= ends_at {
                    self.season_cache.insert(affinity, season.clone()).await;
                    return Ok(season.into());
                }
            }
        }

        Ok(None)
    }

    pub async fn get_current_schedule(
        &self,
        conference: Conference,
    ) -> Result<Option<PremierSchedule>> {
        let now = chrono::Utc::now();
        if let Some(schedule) = self.schedule_cache.get(&conference).await {
            if schedule.ends_at < now {
                return Ok(schedule.into());
            }
        }

        if let Some(season) = self.get_current_season(conference.into()).await? {
            let schedule = self.get_schedule_from_season(&season, conference).await?;
            self.schedule_cache
                .insert(conference, schedule.clone())
                .await;
            return Ok(schedule.into());
        }

        Ok(None)
    }

    pub async fn get_timezone(&self, conference: Conference) -> Result<chrono_tz::Tz> {
        if let Some(tz) = self.tz_cache.get(&conference).await {
            return Ok(tz);
        }

        let conferences = self
            .client
            .get_valorant_v1_premier_conferences()
            .await
            .map(|r| r.into_inner())
            .map_err(|e| anyhow::anyhow!(e))?;

        for c in conferences.data {
            if let Some(conference_name) = c.name
                && let Some(tz) = c.timezone
            {
                let tz: Tz = tz.parse()?;
                self.tz_cache.insert(conference_name, tz).await;
            }
        }

        Ok(self
            .tz_cache
            .get(&conference)
            .await
            .expect("Should have been cached by now"))
    }
}

/// Private methods
impl ScheduleService {
    async fn get_schedule_from_season(
        &self,
        season: &V1PremierSeasonDataItem,
        conference: Conference,
    ) -> Result<PremierSchedule> {
        // So the processing is kinda complicated. The season object has all the event data minus the times in the
        // `events` field. The `scheduled_events` field has the times for each conference linked to event id.

        // First step is to build a mapping from ids to event details
        let mut event_details = HashMap::<Uuid, V1PremierSeasonDataItemEventsItem>::new();
        for event in &season.events {
            if let Some(id) = &event.id {
                event_details.insert(id.clone(), event.clone());
            }
        }

        // Now go through the scheduled events and build the event list for this particular
        // region, linking details from the event details map
        let mut events = Vec::<PremierEvent>::new();
        for event in &season.scheduled_events {
            if event.conference == Some(conference) {
                let id = event
                    .event_id
                    .ok_or(anyhow::anyhow!("event id is missing"))?;
                if let Some(details) = event_details.get(&id) {
                    let map_selection = details
                        .map_selection
                        .as_ref()
                        .ok_or(anyhow::anyhow!("map selection is missing"))?;

                    let premier_event = PremierEvent {
                        id,
                        event_type: details
                            .type_
                            .ok_or(anyhow::anyhow!("event type is missing"))?,
                        map_selection: map_selection
                            .type_
                            .ok_or(anyhow::anyhow!("map selection type is missing"))?,
                        map_pool: map_selection
                            .maps
                            .iter()
                            .filter_map(|m| m.name)
                            .collect::<Vec<_>>(),
                        // pull these from this entry
                        starts_at: event
                            .starts_at
                            .ok_or(anyhow::anyhow!("starts at is missing"))?,
                        ends_at: event.ends_at.ok_or(anyhow::anyhow!("ends at is missing"))?,
                    };

                    events.push(premier_event);
                }
            }
        }

        events.sort_by(|a, b| a.starts_at.cmp(&b.starts_at));

        let schedule = PremierSchedule {
            events: events,
            championship_points_required: season
                .championship_points_required
                .ok_or(anyhow::anyhow!("championship points required is missing"))?,
            starts_at: season
                .starts_at
                .ok_or(anyhow::anyhow!("start date is missing"))?,
            ends_at: season
                .ends_at
                .ok_or(anyhow::anyhow!("end date is missing"))?,
        };

        let tz = self.get_timezone(conference).await?;
        let schedule = repair(&schedule, tz);
        Ok(schedule)
    }

    async fn update_guild_events(
        &self,
        http: impl AsRef<Http>,
        guild_service: &GuildService,
        guild_id: GuildId,
    ) -> anyhow::Result<()> {
        // Not sure yet how the guild wouldn't have preferences, but skip processing them
        let prefs = guild_service.get_preferences(guild_id).await?;
        if prefs.is_none() {
            return Ok(());
        }

        let prefs = prefs.unwrap();

        // If they haven't set their team, also skip
        if prefs.premier_conference().is_none() {
            return Ok(());
        }

        let conference = prefs.premier_conference().unwrap();
        let schedule = self.get_current_schedule(conference).await?;

        Ok(())
    }
}

#[async_trait]
impl EventHandler for ScheduleService {
    async fn cache_ready(&self, _ctx: Context, _guilds: Vec<GuildId>) {
        // Wait for the guilds to be loaded before starting this, hence why we're doing this in
        // the cache_ready handler instead of ready
        let (guild_service, schedule_service) = {
            let data = _ctx.data.read().await;
            let gs = data
                .get::<GuildService>()
                .expect("guild service missing")
                .clone();
            let ss = data
                .get::<ScheduleService>()
                .expect("schedule service missing")
                .clone();
            (gs, ss)
        };
        let cache = _ctx.cache.clone();
        let http = _ctx.http.clone();

        let join_handle = tokio::task::spawn(async move {
            loop {
                info!("Updating schedule for all guilds");
                let mut join_set = JoinSet::new();
                for &guild_id in cache.guilds().iter() {
                    let gs = guild_service.clone();
                    let ss = schedule_service.clone();
                    let http = http.clone();
                    join_set.spawn(async move {
                        if let Err(why) = ss.update_guild_events(&http, &gs, guild_id).await {
                            error!("Error updating schedule for guild {}: {}", guild_id, why);
                        }
                    });
                }

                while let Some(res) = join_set.join_next().await {
                    if let Some(err) = res.err() {
                        error!("Error updating schedule: {}", err);
                    }
                }

                tokio::time::sleep(SCHEDULE_UPDATE_INTERVAL).await;
            }
        });

        tracing::debug!("Started schedule update task");
        self.schedule_update_task
            .set(join_handle)
            .expect("The task shouldn't have already been set");
    }
}

impl TypeMapKey for ScheduleService {
    type Value = Arc<Self>;
}

#[cfg(test)]
mod tests {
    use chrono::{Datelike as _, Timelike as _, Weekday};

    use crate::types::Affinity;

    use super::*;

    #[tokio::test]
    async fn test_get_current_season() -> anyhow::Result<()> {
        dotenvy::dotenv().ok();

        let token = std::env::var("VALORANT_API_TOKEN").unwrap();
        let client = valorant_api::Client::new_with_token(&token);
        let service = ScheduleService::new(client);

        let now = chrono::Utc::now();
        for region in vec![
            Affinity::Na,
            Affinity::Eu,
            Affinity::Kr,
            Affinity::Ap,
            Affinity::Br,
            Affinity::Latam,
        ] {
            let season = service.get_current_season(region).await?;
            assert!(season.is_some());
            let season = season.unwrap();
            assert!(season.starts_at.unwrap() < now && now < season.ends_at.unwrap());
            assert!(service.season_cache.contains_key(&region));
        }
        Ok(())
    }

    #[tokio::test]
    async fn test_get_schedule_useast() -> anyhow::Result<()> {
        dotenvy::dotenv().ok();

        let token = std::env::var("VALORANT_API_TOKEN").unwrap();
        let client = valorant_api::Client::new_with_token(&token);
        let service = ScheduleService::new(client);
        let conference = Conference::NaUsEast;
        let schedule = service.get_current_schedule(conference).await?;
        assert!(schedule.is_some());
        let schedule = schedule.unwrap();
        assert!(!schedule.events.is_empty());
        assert!(service.schedule_cache.contains_key(&conference));

        let tz = service.tz_cache.get(&conference).await.unwrap();

        // Now check it matches the known pattern
        // At least in UsEast, the schedule works like this:
        // - W (7p): Scrim
        // - Th (7p): League (+24h)
        // - F (8p): Scrim (+25h)
        // - S (8p): League (+24h)
        // - Su (7p): League/Tournament (+23h)
        let weekdays = vec![
            Weekday::Wed,
            Weekday::Thu,
            Weekday::Fri,
            Weekday::Sat,
            Weekday::Sun,
        ];
        for (i, event) in schedule.events.iter().enumerate() {
            let localized_event = event.localize(tz);
            let expected_weekday = weekdays[i % weekdays.len()];
            assert_eq!(expected_weekday, localized_event.starts_at.weekday());

            // Check map pool consistency
            if expected_weekday != Weekday::Wed && event.event_type != EventType::Tournament {
                assert_eq!(event.map_pool, schedule.events[i - 1].map_pool);
            }

            // Check match time
            match expected_weekday {
                Weekday::Wed | Weekday::Thu | Weekday::Sun => {
                    assert_eq!(localized_event.starts_at.hour(), 19);
                }
                _ => assert_eq!(localized_event.starts_at.hour(), 20),
            }
        }

        // Should end on a tournament
        assert_eq!(
            schedule.events.last().unwrap().event_type,
            EventType::Tournament
        );

        Ok(())
    }

    #[tokio::test]
    async fn test_get_timezone() -> anyhow::Result<()> {
        dotenvy::dotenv().ok();

        let token = std::env::var("VALORANT_API_TOKEN").unwrap();
        let client = valorant_api::Client::new_with_token(&token);
        let service = ScheduleService::new(client);

        let conference = Conference::NaUsEast;
        let tz = service.get_timezone(conference).await?;
        assert_eq!(tz, chrono_tz::America::New_York);

        // Check several values were cached
        service.tz_cache.run_pending_tasks().await;
        assert!(service.tz_cache.entry_count() > 1);

        let conference = Conference::ApJapan;
        let tz = service.get_timezone(conference).await?;
        assert_eq!(tz, chrono_tz::Asia::Tokyo);

        Ok(())
    }
}
