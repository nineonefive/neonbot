use std::time::Duration;

use super::{EventType, MapSelection};
use chrono::{DateTime, TimeZone, Utc};
use chrono_tz::Tz;
use uuid::Uuid;
use valorant_api::types::Maps;

#[derive(Clone, Debug)]
pub struct PremierSchedule {
    pub events: Vec<PremierEvent>,
    pub championship_points_required: f64,
    pub starts_at: DateTime<Utc>,
    pub ends_at: DateTime<Utc>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PremierEvent<T: TimeZone = Utc> {
    pub id: Uuid,

    pub event_type: EventType,

    pub map_selection: MapSelection,

    /// This is always a scalar except when map_selection == Pickban, in which case it's a vector
    pub map_pool: Vec<Maps>,

    pub starts_at: DateTime<T>,

    pub ends_at: DateTime<T>,
}

impl<T: TimeZone> PremierEvent<T> {
    pub fn duration(&self) -> Duration {
        self.ends_at
            .clone()
            .signed_duration_since(self.starts_at.clone())
            .to_std()
            .unwrap()
    }

    pub fn localize(&self, tz: Tz) -> PremierEvent<Tz> {
        PremierEvent {
            id: self.id,
            event_type: self.event_type,
            map_selection: self.map_selection,
            map_pool: self.map_pool.clone(),
            starts_at: self.starts_at.with_timezone(&tz),
            ends_at: self.ends_at.with_timezone(&tz),
        }
    }

    pub fn to_utc(&self) -> PremierEvent<Utc> {
        PremierEvent {
            id: self.id,
            event_type: self.event_type,
            map_selection: self.map_selection,
            map_pool: self.map_pool.clone(),
            starts_at: self.starts_at.with_timezone(&Utc),
            ends_at: self.ends_at.with_timezone(&Utc),
        }
    }
}
