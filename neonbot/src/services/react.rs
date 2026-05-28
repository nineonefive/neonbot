use cfg_if::cfg_if;
use regex::Regex;
use serde::Deserialize;
use serenity::all::prelude::EventHandler;
use serenity::model::channel::Message;
use serenity::{async_trait, prelude::*};
use tracing::error;

use crate::emojis::Emoji;

const MILK_TRUCK_GUILD_ID: u64 = 1101930063819190425;

pub struct AutoReact {}

impl AutoReact {
    pub fn new() -> Self {
        Self {}
    }

    fn should_react(&self, ctx: &Context, msg: &Message) -> bool {
        !msg.content.is_empty()
            && (msg.guild_id.is_some_and(|id| id == MILK_TRUCK_GUILD_ID)
                || msg.mentions_user_id(ctx.cache.current_user().id))
    }

    fn find_keyword_reactions(&self, msg: &str) -> Vec<Emoji> {
        let re = Regex::new(r"\W").unwrap();
        re.split(msg)
            .filter_map(|s| match s {
                // Milk truck members
                "915" => Some(Emoji::NeonSquish),
                "swit" => Some(Emoji::SageLove),
                "lauten" => Some(Emoji::Discord("🦑".to_owned())),
                "ben" => Some(Emoji::Discord("🤓".to_owned())),
                "paige" => Some(Emoji::Discord("🥛".to_owned())),
                "bloom" => Some(Emoji::Discord("🪷".to_owned())),
                "glaze" => Some(Emoji::Glaze),

                // customers
                "mh" => Some(Emoji::Discord("🌽".to_owned())),
                "italian" => Some(Emoji::Discord("🐧".to_owned())),
                "kev" => Some(Emoji::Kev),
                "chris" => Some(Emoji::Giraffe),

                // Other keywords
                "man" => Some(Emoji::Man),
                "costco" => Some(Emoji::Costco),
                "alecks" => Some(Emoji::Alecks),
                _ => None,
            })
            .collect()
    }
}

#[async_trait]
impl EventHandler for AutoReact {
    async fn message(&self, ctx: Context, msg: Message) {
        if !self.should_react(&ctx, &msg) {
            return;
        }

        let content = msg.content.to_lowercase();

        let mut reactions = Vec::<Emoji>::new();
        reactions.extend(self.find_keyword_reactions(&content).into_iter());

        // If the message does @neonbot, react to the sentiment of the message. Only available
        // in milk truck discord with our feature flag.
        cfg_if! {
            if #[cfg(feature = "milk-truck")] {
                // Replace mentions but check if the message contains "neonbot" in case
                // the user didn't explictly mention us
                let neonbot_mention = format!("<@{}>", ctx.cache.current_user().id);
                let content = content.replace(&neonbot_mention, "neonbot");
                if content.contains("neonbot") {
                    let sentiment = self.get_sentiment(&content, None).await;

                    match sentiment {
                        Ok(sentiment) => {
                            reactions.push(self.get_reaction_for_sentiment(sentiment));
                        }
                        Err(e) => {
                            error!("Failed to get sentiment: {}", e);
                        }
                    }
                }
            }
        }

        for emote in reactions.into_iter() {
            let http = ctx.http.clone();
            if let Err(why) = msg.react(http, emote).await {
                error!("Failed to react: {}", why)
            }
        }
    }
}

#[cfg(feature = "milk-truck")]
#[derive(Debug, PartialEq)]
enum Sentiment {
    Positive,
    Negative,
    Neutral,
}

#[cfg(feature = "milk-truck")]
impl Sentiment {
    fn from_vader(sentiment: vader_sentimental::SentimentIntensity) -> Self {
        if sentiment.compound > 0.33 {
            Self::Positive
        } else if sentiment.compound < -0.33 {
            Self::Negative
        } else {
            Self::Neutral
        }
    }

    fn from_str(label: &str) -> anyhow::Result<Self> {
        match label {
            "LABEL_0" => Ok(Self::Negative),
            "LABEL_1" => Ok(Self::Neutral),
            "LABEL_2" => Ok(Self::Positive),
            _ => Err(anyhow::anyhow!("Invalid label: {}", label)),
        }
    }
}

#[cfg(feature = "milk-truck")]
#[derive(Debug, Deserialize)]
struct Prediction {
    label: String,
    score: f64,
}

#[cfg(feature = "milk-truck")]
impl AutoReact {
    async fn get_sentiment(
        &self,
        msg: &str,
        max_retries: Option<usize>,
    ) -> anyhow::Result<Sentiment> {
        let sentiment = AutoReact::get_sentiment_hf(msg, max_retries).await;

        match sentiment {
            Ok(sentiment) => Ok(sentiment),
            Err(e) => {
                error!("Failed to get sentiment from HF: {}, using vader", e);
                let msg = msg.to_string();
                tokio::spawn(async move { AutoReact::get_sentiment_vader(msg.as_str()) })
                    .await
                    .map_err(|e| anyhow::anyhow!(e))
            }
        }
    }

    fn get_reaction_for_sentiment(&self, sentiment: Sentiment) -> Emoji {
        use rand::RngExt;

        let choose_from = match sentiment {
            Sentiment::Positive => vec![
                Emoji::NeonLove,
                Emoji::NeonLove2,
                Emoji::NeonWow,
                Emoji::Discord("💙".to_owned()),
            ],
            Sentiment::Negative => vec![
                Emoji::NeonSad,
                Emoji::NeonAngry,
                Emoji::NeonRage,
                Emoji::NeonThisIsFine,
            ],
            Sentiment::Neutral => vec![Emoji::NeonSweat, Emoji::NeonLurk, Emoji::NeonISee],
        };
        choose_from[rand::rng().random_range(0..choose_from.len())].clone()
    }

    fn get_sentiment_vader(msg: &str) -> Sentiment {
        use vader_sentimental::SentimentIntensityAnalyzer;
        let analyzer = SentimentIntensityAnalyzer::new();
        let sentiment = analyzer.polarity_scores(msg);
        Sentiment::from_vader(sentiment)
    }

    async fn get_sentiment_hf(msg: &str, max_retries: Option<usize>) -> anyhow::Result<Sentiment> {
        use anyhow::anyhow;
        use std::str::FromStr;

        use reqwest::Url;

        let hf_token = std::env::var("HF_TOKEN");

        if hf_token.is_err() {
            return Err(anyhow!("HF_TOKEN not set"));
        }

        let mut retries = max_retries.unwrap_or(3);
        let hf_token = hf_token.unwrap();
        let url = Url::from_str("https://router.huggingface.co/hf-inference/models/cardiffnlp/twitter-roberta-base-sentiment").unwrap();
        let client = reqwest::Client::new();
        let request = client
            .post(url.clone())
            .bearer_auth(hf_token.as_str())
            .json(&serde_json::json!({ "inputs": msg }));

        while retries > 0 {
            retries -= 1;
            let response = request
                .try_clone()
                .expect("We're not using streams")
                .send()
                .await?;

            if !response.status().is_success() {
                use reqwest::StatusCode;

                // Retrying won't make it magically appear
                if response.status() == StatusCode::NOT_FOUND {
                    return Err(anyhow!("Hugging face model returned 404"));
                }

                // Log failures but don't return an error because we might retry
                error!(
                    "Failed to get sentiment from hugging face; return code: {}",
                    response.status()
                );
                continue;
            }

            let predictions: Vec<Vec<Prediction>> = response.json().await?;
            let best = predictions.first().and_then(|p| {
                p.into_iter()
                    .max_by(|a, b| a.score.partial_cmp(&b.score).unwrap())
            });

            if let Some(best) = best {
                return Ok(Sentiment::from_str(best.label.as_str())?);
            }
        }

        Err(anyhow!("Exceeded max retries"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_keyword_reactions() {
        let auto_react = AutoReact::new();
        let emotes = auto_react.find_keyword_reactions("hi glaze, how are you");
        assert_eq!(emotes, vec![Emoji::Glaze]);

        let emotes = auto_react.find_keyword_reactions("swit, 91 5 said hi");
        assert_eq!(emotes, vec![Emoji::SageLove]);

        let emotes = auto_react.find_keyword_reactions("swit, 915 said hi");
        assert_eq!(emotes, vec![Emoji::SageLove, Emoji::NeonSquish]);
    }

    #[cfg(feature = "milk-truck")]
    #[test]
    fn test_vader_sentiment() {
        let sentiment = AutoReact::get_sentiment_vader("you suck, neonbot");
        assert_eq!(sentiment, Sentiment::Negative);
    }

    #[cfg(feature = "milk-truck")]
    #[tokio::test]
    async fn test_hf_sentiment() {
        dotenvy::dotenv().ok();
        let result = AutoReact::get_sentiment_hf("you suck, neonbot", None).await;
        if let Err(why) = result {
            panic!("Failed to get sentiment from hugging face: {}", why);
        }
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), Sentiment::Negative);
    }

    #[cfg(feature = "milk-truck")]
    #[tokio::test]
    async fn test_sentiment_fallback() {
        dotenvy::dotenv().ok();
        let auto_react = AutoReact::new();
        let result = auto_react.get_sentiment("you suck, neonbot", None).await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), Sentiment::Negative);
    }
}
