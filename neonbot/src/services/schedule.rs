use std::{
    collections::{BinaryHeap, HashMap, HashSet},
    time::Duration,
};

use crate::types::{
    Affinity, Conference, EventType, MapSelection, PremierEvent, PremierSchedule, Region,
};
use anyhow::Result;
use chrono::{DateTime, Datelike, NaiveDate, TimeZone, Timelike, Utc, Weekday};
use chrono_tz::Tz;
use moka::future::{Cache, CacheBuilder};
use uuid::Uuid;
use valorant_api::types::{Maps, V1PremierSeasonDataItem, V1PremierSeasonDataItemEventsItem};

pub struct ScheduleService {
    client: valorant_api::Client,
    season_cache: Cache<Affinity, V1PremierSeasonDataItem>,
    schedule_cache: Cache<Conference, PremierSchedule>,
    tz_cache: Cache<Conference, chrono_tz::Tz>,
}

impl ScheduleService {
    pub fn new(client: valorant_api::Client) -> Self {
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
        }
    }

    pub async fn get_current_season(&self, affinity: Affinity) -> Result<V1PremierSeasonDataItem> {
        if let Some(season) = self.season_cache.get(&affinity).await {
            return Ok(season);
        }

        let seasons = self
            .client
            .get_valorant_v1_premier_seasons_region(affinity)
            .await
            .map(|r| r.into_inner().data)
            .map_err(|e| anyhow::anyhow!(e))?;

        let now = chrono::Utc::now();
        for season in seasons {
            if let Some(starts_at) = season.starts_at
                && let Some(ends_at) = season.ends_at
            {
                if starts_at <= now && now <= ends_at {
                    self.season_cache.insert(affinity, season.clone()).await;
                    return Ok(season);
                }
            }
        }

        Err(anyhow::anyhow!("No current season found"))
    }

    pub async fn get_schedule(&self, conference: Conference) -> Result<PremierSchedule> {
        if let Some(schedule) = self.schedule_cache.get(&conference).await {
            return Ok(schedule);
        }

        let season = self.get_current_season(conference.into()).await?;
        let schedule = self.get_schedule_from_season(&season, conference).await?;
        self.schedule_cache
            .insert(conference, schedule.clone())
            .await;
        Ok(schedule)
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

                    let key = (id, event.starts_at.unwrap(), event.ends_at.unwrap());
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
}

#[derive(Debug, Clone, PartialEq)]
struct EventChain<'a, T: TimeZone = Utc> {
    events: Vec<&'a PremierEvent<T>>,
    likelihood: f64,
}

impl Ord for EventChain<'_, Tz> {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.likelihood
            .partial_cmp(&other.likelihood)
            .unwrap_or(std::cmp::Ordering::Equal)
    }
}

impl PartialOrd for EventChain<'_, Tz> {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(
            self.likelihood
                .partial_cmp(&other.likelihood)
                .unwrap_or(std::cmp::Ordering::Equal),
        )
    }
}

impl Eq for EventChain<'_, Tz> {}

// Logic to repair the schedule from riot's garbage data
// idk if this is correct for other regions, plz help 🥺

fn repair(schedule: &PremierSchedule, tz: Tz) -> PremierSchedule {
    let localized_events = schedule
        .events
        .iter()
        .map(|e| e.localize(tz))
        .collect::<Vec<_>>();

    // Group them by date
    let mut grouped_events: HashMap<NaiveDate, Vec<&PremierEvent<Tz>>> = HashMap::new();
    localized_events
        .iter()
        .map(|e| (e.starts_at.date_naive(), e))
        .for_each(|(date, event)| {
            grouped_events.entry(date).or_default().push(event);
        });

    // Now put them into consecutive buckets for beam search
    let mut buckets = grouped_events.into_iter().collect::<Vec<_>>();
    buckets.sort_by_key(|(date, _)| *date);

    let chain = beam_search(buckets.as_slice(), 3);
    if chain.is_empty() {
        return schedule.clone();
    }

    PremierSchedule {
        events: chain
            .into_iter()
            .map(|e| e.to_utc())
            .collect::<Vec<PremierEvent>>(),
        championship_points_required: schedule.championship_points_required,
        starts_at: schedule.starts_at,
        ends_at: schedule.ends_at,
    }
}

/// Returns P(event | chain)
fn likelihood_model(chain: &[&PremierEvent<Tz>], el: &PremierEvent<Tz>, is_last: bool) -> f64 {
    let weekday = el.starts_at.weekday();

    // Simple checks
    match weekday {
        Weekday::Wed | Weekday::Fri => {
            if el.event_type != EventType::Scrim {
                return 0.0;
            }
        }
        Weekday::Thu | Weekday::Sat => {
            if el.event_type != EventType::League {
                return 0.0;
            }
        }
        Weekday::Sun => {
            if el.event_type == EventType::Scrim {
                return 0.0;
            }
        }
        _ => return 0.0,
    };

    if el.duration() < Duration::from_hours(1) && el.event_type != EventType::Tournament {
        return 0.0;
    }

    // All sequences end with a tournament
    if is_last {
        match el.event_type {
            EventType::Tournament => return 1.0,
            _ => return 0.0,
        };
    }

    1.0
}

fn beam_search<'a, 'b: 'a>(
    buckets: &'a [(NaiveDate, Vec<&'b PremierEvent<Tz>>)],
    beam_width: usize,
) -> Vec<&'b PremierEvent<Tz>> {
    let mut beam: Vec<EventChain<'_, Tz>> = buckets[0]
        .1
        .iter()
        .map(|&e| EventChain {
            events: vec![e],
            likelihood: likelihood_model(&[], e, false),
        })
        .collect();

    for bucket in &buckets[1..] {
        let is_last = bucket == buckets.last().unwrap();
        let mut next_generation = BinaryHeap::<EventChain<'_, Tz>>::new();
        for &candidate in bucket.1.iter() {
            for chain in &beam {
                let mut new_events = chain.events.clone();
                new_events.push(candidate);
                let likelihood = likelihood_model(&chain.events, candidate, is_last);
                next_generation.push(EventChain {
                    events: new_events,
                    likelihood: likelihood * chain.likelihood,
                });
            }
        }

        beam.clear();
        beam.extend(next_generation.into_iter().take(beam_width));
    }

    beam.into_iter()
        .max_by(|a, b| {
            a.likelihood
                .partial_cmp(&b.likelihood)
                .unwrap_or(std::cmp::Ordering::Equal)
        })
        .map(|c| c.events)
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
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
        let schedule = service.get_schedule(conference).await?;
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
