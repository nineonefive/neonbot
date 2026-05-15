use anyhow::Result;
use moka::future::{Cache, CacheBuilder};
use reqwest::{StatusCode, Url};
use std::time::Duration;
use uuid::Uuid;

use crate::{premier::Team, util::parse_premier_data};

#[derive(Clone)]
struct TeamService {
    client: reqwest::Client,
    team_cache: Cache<Uuid, Team>,
}

impl TeamService {
    pub fn new(client: reqwest::Client) -> Self {
        Self {
            client,
            team_cache: CacheBuilder::new(100)
                .time_to_live(Duration::from_mins(10))
                .build(),
        }
    }
}
