use std::str::FromStr;

use anyhow::Result;
use reqwest::Url;

#[derive(serde::Deserialize)]
pub struct FlareSolverrResponse {
    solution: FlareSolverrSolution,
}

#[derive(serde::Deserialize)]
pub struct FlareSolverrSolution {
    url: String,
    status: u16,
    response: String, // HTML body
}

pub async fn get_with_flaresolverr(client: &wreq::Client, url: Url) -> Result<String> {
    let flaresolverr_url = Url::from_str(
        &std::env::var("FLARESOLVERR_URL").unwrap_or("http://localhost:8191".to_owned()),
    )
    .map_err(|e| anyhow::anyhow!("Failed to parse FLARESOLVERR_URL: {}", e))?
    .join("/v1")?;

    let resp = client
        .post(flaresolverr_url)
        .json(&serde_json::json!({
            "cmd": "request.get",
            "url": url.as_str(),
            "maxTimeout": 30000
        }))
        .send()
        .await?
        .error_for_status()?
        .json::<FlareSolverrResponse>()
        .await?;

    Ok(resp.solution.response)
}
