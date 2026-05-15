use anyhow::Result;
use chrono::{DateTime, Utc};
use reqwest::Url;
use serde::Deserialize;
use serde_json::Value;
use uuid::Uuid;

use super::util::parse_premier_data;
use crate::premier::{Region, Team};

#[derive(Clone)]
pub struct TrackerClient {
    pub client: wreq::Client,
    pub max_retries: Option<usize>,
    pub use_flaresolverr: bool,
}

impl TrackerClient {
    pub fn new(client: wreq::Client, max_retries: Option<usize>, use_flaresolverr: bool) -> Self {
        Self {
            client,
            max_retries,
            use_flaresolverr,
        }
    }

    pub async fn get_team_by_uuid(&self, uuid: Uuid) -> Result<Team> {
        let endpoint = format!("valorant/premier/teams/{}", uuid);
        self.get_endpoint::<TeamByUUIDResponse>(&endpoint)
            .await?
            .try_into()
    }

    pub async fn get_team_by_riot_id(&self, riot_id: &str) -> Result<Team> {
        let url = Url::parse(&format!(
            "https://api.tracker.gg/api/v1/valorant/search/by-query/{}",
            riot_id
        ))?;
        let raw = super::util::get(
            &self.client,
            url,
            self.max_retries.unwrap_or(0),
            self.use_flaresolverr,
        )
        .await?;
        let resp: SearchByNameResponse = serde_json::from_str(&raw)?;
        let resp = resp.data;
        if let Some(result_set) = resp.resultSets.first()
            && result_set._type == "premier-team"
        {
            if result_set.results.is_empty() {
                Err(anyhow::anyhow!("No team found"))
            } else if result_set.results.len() > 1 {
                Err(anyhow::anyhow!("Multiple teams found"))
            } else {
                let team_result = TeamResult::deserialize(result_set.results[0].clone())?;
                Ok(team_result.try_into()?)
            }
        } else {
            Err(anyhow::anyhow!("No team found"))
        }
    }

    async fn get_endpoint<T>(&self, endpoint: &str) -> Result<T>
    where
        T: for<'de> Deserialize<'de>,
    {
        let url = Url::parse(&format!("https://tracker.gg/{}", endpoint))?;

        let raw = super::util::get(
            &self.client,
            url,
            self.max_retries.unwrap_or(0),
            self.use_flaresolverr,
        )
        .await?;
        let html = parse_premier_data(&raw)?;
        let response = T::deserialize(html)?;
        Ok(response)
    }
}

#[derive(Deserialize)]
struct TeamByUUIDResponse {
    #[serde(rename = "detailedRoster")]
    pub detailed_roster: DetailedRoster,
}

#[derive(Deserialize)]
struct DetailedRoster {
    #[serde(rename = "createdDate")]
    created_date: DateTime<Utc>,
    division: usize,
    #[serde(rename = "divisionImageUrl")]
    division_image_url: Url,
    icon: Icon,
    id: Option<Uuid>,
    #[serde(rename = "isDeleted")]
    is_deleted: bool,
    #[serde(rename = "leagueScore")]
    league_score: Option<usize>,
    losses: usize,
    name: String,
    rank: Option<usize>,
    wins: usize,
    /// Zone identifier like NA_US_EAST
    zone: String,
    /// Friendly zone name like US East
    #[serde(rename = "zoneName")]
    zone_name: String,
}

#[derive(Deserialize)]
struct Icon {
    #[serde(rename = "imageUrl")]
    image_url: Url,
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
struct SearchByNameResponse {
    data: ResultSets,
}

#[derive(Deserialize)]
struct ResultSets {
    resultSets: Vec<ResultSet>,
}

#[derive(Deserialize)]
struct ResultSet {
    #[serde(rename = "type")]
    _type: String,
    results: Vec<Value>,
}

#[derive(Deserialize)]
struct TeamResult {
    id: Uuid,
    name: String,
    status: String,
    #[serde(rename = "imageUrl")]
    image_url: Url,
    metadata: Metadata,
}

#[derive(Deserialize)]
struct Metadata {
    zone: String,
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

#[cfg(test)]
mod tests {

    use wreq_util::Emulation;

    use super::*;

    fn get_client() -> TrackerClient {
        TrackerClient::new(
            wreq::Client::builder()
                .emulation(Emulation::Firefox139)
                .build()
                .unwrap(),
            None,
            false,
        )
    }

    #[tokio::test]
    async fn test_get_team_by_uuid() -> Result<()> {
        let uuid = Uuid::parse_str("0237ec41-a671-4af7-adef-4a5097e07b77").unwrap();
        let tracker = get_client();

        let team = tracker.get_team_by_uuid(uuid).await?;
        assert_eq!(team.uuid, uuid);
        assert_eq!(team.riot_id, "Milk Truck#MILK");
        assert_eq!(team.region, Region::UsEast);
        Ok(())
    }

    #[tokio::test]
    async fn test_get_team_by_riot_id() -> Result<()> {
        let tracker = get_client();
        let team = tracker.get_team_by_riot_id("Milk Truck#MILK").await?;
        assert_eq!(
            team.uuid,
            Uuid::parse_str("0237ec41-a671-4af7-adef-4a5097e07b77").unwrap()
        );
        assert_eq!(team.riot_id, "Milk Truck#MILK");
        assert_eq!(team.region, Region::UsEast);
        Ok(())
    }
}
