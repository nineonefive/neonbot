use anyhow::{Result, anyhow};
use scraper::{Html, Selector};
use serde_json::Value;
use wreq::{StatusCode, Url};

use crate::flaresolverr::get_with_flaresolverr;

pub(super) async fn get(
    client: &wreq::Client,
    url: Url,
    max_retries: usize,
    use_flaresolverr: bool,
) -> Result<String> {
    // Try first with regular requests
    let mut retries = max_retries + 1;
    while retries > 0 {
        let response = client.get(url.clone()).send().await?;
        match response.status() {
            // Cloudflare, use flaresolverr below
            StatusCode::FORBIDDEN => {
                if use_flaresolverr {
                    let html = get_with_flaresolverr(client, url.clone()).await?;
                    return Ok(html);
                }

                return Err(anyhow!("Blocked by Cloudflare"));
            }
            StatusCode::OK => {
                let html = response.text().await?;
                if html.contains("window._cf_chl_opt") {
                    // Cloudflare JS challenge served as 200
                    if use_flaresolverr {
                        let html = get_with_flaresolverr(client, url.clone()).await?;
                        return Ok(html);
                    }
                    return Err(anyhow!("Blocked by Cloudflare challenge"));
                }
                return Ok(html);
            }
            StatusCode::NOT_FOUND => {
                return Err(anyhow!("Not found"));
            }
            _ => {
                retries -= 1;
            }
        }
    }

    Err(anyhow!("Failed to get data"))
}

pub(super) fn parse_premier_data(html: &str) -> Result<Value> {
    let document = Html::parse_document(html);
    let selector = Selector::parse("script").unwrap();

    for element in document.select(&selector) {
        // We expect the data to look like
        // window.__INITIAL_STATE__ = {"valorantPremier": <data>, ...}
        let prefix = "window.__INITIAL_STATE__ = ";
        let inner = element.inner_html();
        if inner.contains(prefix) {
            let json = inner.strip_prefix(prefix).unwrap();
            let data = serde_json::from_str::<Value>(json)
                .map_err(|e| anyhow!("Error parsing JSON: {}", e))?;
            return data
                .get("valorantPremier")
                .ok_or_else(|| anyhow!("Error getting valorantPremier data"))
                .cloned();
        }
    }

    Err(anyhow!("No <script> element with the data found"))
}
