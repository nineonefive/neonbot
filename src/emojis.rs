use serenity::model::channel::ReactionType;

#[derive(Clone, Debug, PartialEq)]
pub enum Emoji {
    NeonSquish,
    NeonWow,
    NeonSweat,
    NeonISee,
    NeonLurk,
    NeonLove,
    NeonLove2,
    NeonSad,
    NeonAngry,
    NeonRage,
    NeonThisIsFine,
    SageLove,
    Glaze,
    Kev,
    Giraffe,
    Man,
    Costco,
    Alecks,
    Discord(String),
}

impl From<Emoji> for ReactionType {
    fn from(emoji: Emoji) -> Self {
        match emoji {
            Emoji::NeonSquish => ReactionType::Custom {
                animated: false,
                id: 1041584725627781140.into(),
                name: Some("neonsquish".to_string()),
            },
            Emoji::NeonWow => ReactionType::Custom {
                animated: false,
                id: 1140755513399848970.into(),
                name: Some("neonwow".to_string()),
            },
            Emoji::NeonSweat => ReactionType::Custom {
                animated: false,
                id: 954830684080459817.into(),
                name: Some("neonsweat".to_string()),
            },
            Emoji::NeonISee => ReactionType::Custom {
                animated: false,
                id: 1233576381326037102.into(),
                name: Some("neonisee".to_string()),
            },
            Emoji::NeonLurk => ReactionType::Custom {
                animated: false,
                id: 1049438090751647745.into(),
                name: Some("neonlurk".to_string()),
            },
            Emoji::NeonLove => ReactionType::Custom {
                animated: false,
                id: 954830472561692765.into(),
                name: Some("neonlove".to_string()),
            },
            Emoji::NeonLove2 => ReactionType::Custom {
                animated: false,
                id: 1140755039179260055.into(),
                name: Some("neonlove2".to_string()),
            },
            Emoji::NeonSad => ReactionType::Custom {
                animated: false,
                id: 1049438054714192074.into(),
                name: Some("neonsad".to_string()),
            },
            Emoji::NeonAngry => ReactionType::Custom {
                animated: false,
                id: 1049438000335044668.into(),
                name: Some("neonangry".to_string()),
            },
            Emoji::NeonRage => ReactionType::Custom {
                animated: false,
                id: 1049438130282967050.into(),
                name: Some("neonrage".to_string()),
            },
            Emoji::NeonThisIsFine => ReactionType::Custom {
                animated: false,
                id: 1140755514188382248.into(),
                name: Some("neonthisisfine".to_string()),
            },
            Emoji::SageLove => ReactionType::Custom {
                animated: false,
                id: 1226382840422207548.into(),
                name: Some("sagelove".to_string()),
            },
            Emoji::Glaze => ReactionType::Custom {
                animated: false,
                id: 1226388046203584552.into(),
                name: Some("glaze".to_string()),
            },
            Emoji::Kev => ReactionType::Custom {
                animated: false,
                id: 1226386493774237738.into(),
                name: Some("kev".to_string()),
            },
            Emoji::Giraffe => ReactionType::Custom {
                animated: false,
                id: 1319815973628411944.into(),
                name: Some("giraffe".to_string()),
            },
            Emoji::Man => ReactionType::Custom {
                animated: false,
                id: 1213704607658807336.into(),
                name: Some("MAN".to_string()),
            },
            Emoji::Costco => ReactionType::Custom {
                animated: false,
                id: 1167897307811954828.into(),
                name: Some("costco".to_string()),
            },
            Emoji::Alecks => ReactionType::Custom {
                animated: false,
                id: 1143687438045302864.into(),
                name: Some("alecks".to_string()),
            },
            Emoji::Discord(unicode) => ReactionType::Unicode(unicode.to_string()),
        }
    }
}
