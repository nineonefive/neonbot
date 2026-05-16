use crate::{Team, types::raw::*};
use anyhow::Result;
use serde::Deserialize;
use uuid::Uuid;
use wreq::Url;

use crate::util::parse_premier_data;

#[derive(Clone)]
pub struct TrackerClient {
    client: wreq::Client,
    max_retries: Option<usize>,
    use_flaresolverr: bool,
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
        if let Some(result_set) = resp.result_sets.first()
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

#[cfg(test)]
mod tests {

    use wreq_util::Emulation;

    use crate::Region;

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
