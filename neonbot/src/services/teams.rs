use anyhow::Result;
use moka::future::{Cache, CacheBuilder};
use std::time::Duration;
use uuid::Uuid;
use valorant_api::types::{V1PartialPremierTeam, V1PremierTeamData};

use crate::types::PartialPremierTeam;

#[derive(Clone)]
pub struct TeamService {
    client: valorant_api::Client,
    team_cache: Cache<Uuid, V1PremierTeamData>,
}

impl TeamService {
    pub fn new(client: valorant_api::Client) -> Self {
        Self {
            client,
            team_cache: CacheBuilder::new(100)
                .time_to_live(Duration::from_mins(10))
                .build(),
        }
    }

    pub async fn get_team_by_id(&self, team_id: &Uuid) -> Result<Option<V1PremierTeamData>> {
        if let Some(team) = self.team_cache.get(team_id).await {
            return Ok(Some(team));
        }

        let team = self
            .client
            .get_valorant_v1_premier_team_id(team_id)
            .await
            .map(|r| r.into_inner().data)
            .map_err(|e| anyhow::anyhow!(e))?;

        if let Some(team) = team.clone() {
            self.team_cache.insert(team_id.clone(), team.clone()).await;
        }

        Ok(team)
    }

    pub async fn search_teams_by_riot_id(&self, riot_id: &str) -> Result<Vec<PartialPremierTeam>> {
        let (name, tag) = riot_id.split_once('#').unwrap_or((riot_id, ""));

        let teams = self
            .client
            .get_valorant_v1_premier_search(None, None, name.into(), tag.into())
            .await
            .map(|r| r.into_inner().data)
            .map_err(|e| anyhow::anyhow!(e))?;

        // deduplicate teams by id. we have no way to pick the most recent one because V1PartialPremierTeam doesn't have a
        // updated_at field. might be a codegen bug in valorant-api because the actual endpoint does return that
        let deduped_teams = teams
            .into_iter()
            .fold(Vec::<V1PartialPremierTeam>::new(), |mut acc, team| {
                if !acc.iter().any(|t| t.id == team.id) {
                    acc.push(team);
                }
                acc
            })
            .into_iter()
            .map(|team| team.try_into())
            .collect::<Result<Vec<PartialPremierTeam>>>()?;

        Ok(deduped_teams)
    }
}

#[cfg(test)]
mod tests {
    use crate::types::Conference;

    use super::*;

    #[tokio::test]
    #[ignore] // this endpoint isn't working right now
    async fn test_get_team_by_id() -> anyhow::Result<()> {
        dotenvy::dotenv().ok();

        let token = std::env::var("VALORANT_API_TOKEN").unwrap();
        let client = valorant_api::Client::new_with_token(&token);
        let team_service = TeamService::new(client);

        let uuid = Uuid::parse_str("ecc786f0-48cc-4300-97db-f00ea88cb32a").unwrap();
        let team = team_service.get_team_by_id(&uuid).await?.unwrap();
        assert_eq!(team.name, Some("Milk Truck".to_owned()));
        assert_eq!(team.tag, Some("MILK".to_owned()));
        Ok(())
    }

    #[tokio::test]
    async fn test_search_teams_by_riot_id() -> anyhow::Result<()> {
        dotenvy::dotenv().ok();

        let token = std::env::var("VALORANT_API_TOKEN").unwrap();
        let client = valorant_api::Client::new_with_token(&token);
        let team_service = TeamService::new(client);

        let teams = team_service
            .search_teams_by_riot_id("Milk Truck#MILK")
            .await?;
        for team in &teams {
            println!("{:?}", team);
        }
        assert_eq!(teams.len(), 1);

        let team = &teams[0];
        assert_eq!(
            team.id,
            Uuid::parse_str("ecc786f0-48cc-4300-97db-f00ea88cb32a").unwrap()
        );
        assert_eq!(&team.name, "Milk Truck");
        assert_eq!(&team.tag, "MILK");
        assert_eq!(team.conference, Conference::NaUsEast);
        Ok(())
    }
}
