//! Raw types for the Tracker API

use chrono::{DateTime, Utc};
use serde::Deserialize;
use serde_json::Value;
use uuid::Uuid;
use wreq::Url;

use crate::{Region, Team};

#[derive(Deserialize)]
pub(crate) struct TeamByUUIDResponse {
    #[serde(rename = "detailedRoster")]
    pub detailed_roster: DetailedRoster,
}

#[derive(Deserialize)]
pub(crate) struct DetailedRoster {
    #[serde(rename = "createdDate")]
    pub created_date: DateTime<Utc>,
    pub division: usize,
    #[serde(rename = "divisionImageUrl")]
    pub division_image_url: Url,
    pub icon: Icon,
    pub id: Option<Uuid>,
    #[serde(rename = "isDeleted")]
    pub is_deleted: bool,
    #[serde(rename = "leagueScore")]
    pub league_score: Option<usize>,
    pub losses: usize,
    pub name: String,
    pub rank: Option<usize>,
    pub wins: usize,
    /// Zone identifier like NA_US_EAST
    pub zone: String,
    /// Friendly zone name like US East
    #[serde(rename = "zoneName")]
    pub zone_name: String,
}

#[derive(Deserialize)]
pub(crate) struct Icon {
    #[serde(rename = "imageUrl")]
    pub image_url: Url,
    // Other fields don't matter
}

impl TryFrom<TeamByUUIDResponse> for Team {
    type Error = anyhow::Error;

    fn try_from(resp: TeamByUUIDResponse) -> Result<Self, Self::Error> {
        let roster = resp.detailed_roster;
        if roster.id.is_none() {
            return Err(anyhow::anyhow!("Team ID is missing"));
        }

        let uuid = roster.id.unwrap();
        let region = Region::from_riot_id(&roster.zone);
        if region.is_none() {
            return Err(anyhow::anyhow!("Invalid region idenifier: {}", roster.zone));
        }

        Ok(Self {
            uuid,
            riot_id: roster.name,
            region: region.unwrap(),
            image_url: roster.icon.image_url,
        })
    }
}

#[derive(Deserialize)]
pub(crate) struct SearchByNameResponse {
    pub data: ResultSets,
}

#[derive(Deserialize)]
pub(crate) struct ResultSets {
    #[serde(rename = "resultSets")]
    pub result_sets: Vec<ResultSet>,
}

#[derive(Deserialize)]
pub(crate) struct ResultSet {
    #[serde(rename = "type")]
    pub _type: String,
    pub results: Vec<Value>,
}

#[derive(Deserialize)]
pub(crate) struct TeamResult {
    pub id: Uuid,
    pub name: String,
    pub status: String,
    #[serde(rename = "imageUrl")]
    pub image_url: Url,
    pub metadata: Metadata,
}

#[derive(Deserialize)]
pub(crate) struct Metadata {
    pub zone: String,
}

impl TryFrom<TeamResult> for Team {
    type Error = anyhow::Error;

    fn try_from(value: TeamResult) -> Result<Self, Self::Error> {
        Ok(Self {
            uuid: value.id,
            riot_id: value.name,
            region: Region::from_riot_id(&value.metadata.zone).ok_or_else(|| {
                anyhow::anyhow!("No region found for code {}", &value.metadata.zone)
            })?,
            image_url: value.image_url,
        })
    }
}
