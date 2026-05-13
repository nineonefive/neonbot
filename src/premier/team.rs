use chrono::{DateTime, Utc};
use reqwest::Url;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::premier::Region;

/// Represents a partial team not fully downloaded from tracker
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct PartialTeam {
    /// Unique identifier for the team
    uuid: Uuid,

    /// Player-chosen Riot ID for the team, e.g. "Milk Truck#MILK"
    riot_id: String,

    /// The premier region the team competes in
    region: Region,
}

impl PartialTeam {
    pub fn new(uuid: Uuid, riot_id: String, region: Region) -> Self {
        Self {
            uuid,
            riot_id,
            region,
        }
    }

    pub fn uuid(&self) -> &Uuid {
        &self.uuid
    }

    pub fn riot_id(&self) -> &str {
        &self.riot_id
    }

    pub fn region(&self) -> Region {
        self.region
    }
}

#[derive(Clone)]
pub struct Team {
    inner_team: PartialTeam,
    image_url: Url,
    stats: TeamStats,
    last_updated: DateTime<Utc>,
}

impl Team {
    pub fn new(
        inner_team: PartialTeam,
        image_url: Url,
        stats: TeamStats,
        last_updated: DateTime<Utc>,
    ) -> Self {
        Self {
            inner_team,
            image_url,
            stats,
            last_updated,
        }
    }

    pub fn update_image_url(&mut self, image_url: Url) {
        self.image_url = image_url;
        self.last_updated = Utc::now();
    }

    pub fn update_stats(&mut self, stats: TeamStats) {
        self.stats = stats;
        self.last_updated = Utc::now();
    }
}

#[derive(Clone)]
pub struct TeamStats {
    rank: u32,
    league_score: u32,
    division: String,
}

impl TeamStats {
    pub fn new(rank: u32, league_score: u32, division: String) -> Self {
        Self {
            rank,
            league_score,
            division,
        }
    }
}
