use reqwest::Url;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::premier::Region;

/// Represents a partial team not fully downloaded from tracker
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct PartialTeam {
    /// Unique identifier for the team
    pub uuid: Uuid,

    /// Player-chosen Riot ID for the team, e.g. "Milk Truck#MILK"
    pub riot_id: String,

    /// The premier region the team competes in
    pub region: Region,
}

impl PartialTeam {
    pub fn new(uuid: Uuid, riot_id: String, region: Region) -> Self {
        Self {
            uuid,
            riot_id,
            region,
        }
    }
}

#[derive(Clone)]
pub struct Team {
    pub uuid: Uuid,
    pub riot_id: String,
    pub region: Region,
    pub image_url: Url,
}

impl Team {
    pub fn from_partial_team(team: PartialTeam, image_url: Url) -> Self {
        Self {
            uuid: team.uuid,
            riot_id: team.riot_id,
            region: team.region,
            image_url,
        }
    }
}

impl From<Team> for PartialTeam {
    fn from(team: Team) -> Self {
        Self::new(team.uuid, team.riot_id, team.region)
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
