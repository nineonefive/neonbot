use super::Conference;
use reqwest::Url;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use valorant_api::types::V1PartialPremierTeam;

/// Represents a partial team not fully downloaded from tracker
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct PartialPremierTeam {
    /// Unique identifier for the team
    pub id: Uuid,

    /// Player chosen name for the team. The first part of the Riot ID
    pub name: String,

    /// Player chosen tag for the team. The second part of the Riot ID
    pub tag: String,

    /// The premier conference the team competes in (e.g. US East)
    pub conference: Conference,

    /// The team's image URL
    pub image_url: Url,
}

impl PartialPremierTeam {
    pub fn riot_id(&self) -> String {
        format!("{}#{}", self.name, self.tag)
    }
}

impl TryFrom<V1PartialPremierTeam> for PartialPremierTeam {
    type Error = anyhow::Error;

    fn try_from(team: V1PartialPremierTeam) -> Result<Self, Self::Error> {
        let url = team.customization.map(|c| c.image).flatten();
        let url = Url::parse(&url.ok_or(anyhow::anyhow!("image url is missing"))?)
            .map_err(|e| anyhow::anyhow!(e))?;

        Ok(Self {
            id: team.id.ok_or(anyhow::anyhow!("id is missing"))?,
            name: team.name.ok_or(anyhow::anyhow!("name is missing"))?,
            tag: team.tag.ok_or(anyhow::anyhow!("tag is missing"))?,
            conference: team
                .conference
                .ok_or(anyhow::anyhow!("conference is missing"))?,
            image_url: url,
        })
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
