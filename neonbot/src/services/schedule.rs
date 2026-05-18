use std::time::Duration;

use crate::types::Region;
use anyhow::Result;
use moka::future::{Cache, CacheBuilder};
use valorant_api::types::{Affinities, V1PremierSeasonDataItem};

pub struct ScheduleService {
    client: valorant_api::Client,
    season_cache: Cache<Region, V1PremierSeasonDataItem>,
}

impl ScheduleService {
    pub fn new(client: valorant_api::Client) -> Self {
        Self {
            client,
            season_cache: CacheBuilder::new(100)
                .time_to_live(Duration::from_hours(24))
                .build(),
        }
    }

    pub async fn get_current_season(
        &self,
        affinity: Affinities,
    ) -> Result<V1PremierSeasonDataItem> {
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
                    return Ok(season);
                }
            }
        }

        Err(anyhow::anyhow!("No current season found"))
    }
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
        }
        Ok(())
    }
}
