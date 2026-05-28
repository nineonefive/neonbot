use reqwest::header::HeaderMap;

use crate::types::{Affinities, PremierConferences};

include!(concat!(env!("OUT_DIR"), "/codegen.rs"));

impl Client {
    pub fn new_with_token(token: &str) -> Self {
        let mut headers = HeaderMap::new();
        headers.insert(
            "Authorization",
            reqwest::header::HeaderValue::from_str(token).unwrap(),
        );
        let client = reqwest::ClientBuilder::new()
            .default_headers(headers)
            .build()
            .unwrap();
        Self::new_with_client("https://api.henrikdev.xyz", client)
    }
}

impl From<PremierConferences> for Affinities {
    fn from(conference: PremierConferences) -> Self {
        match conference {
            PremierConferences::EuCentralEast => Affinities::Eu,
            PremierConferences::EuWest => Affinities::Eu,
            PremierConferences::EuMiddleEast => Affinities::Eu,
            PremierConferences::EuTurkey => Affinities::Eu,
            PremierConferences::NaUsEast => Affinities::Na,
            PremierConferences::NaUsWest => Affinities::Na,
            PremierConferences::LatamNorth => Affinities::Latam,
            PremierConferences::LatamSouth => Affinities::Latam,
            PremierConferences::BrBrazil => Affinities::Br,
            PremierConferences::KrKorea => Affinities::Kr,
            PremierConferences::ApAsia => Affinities::Ap,
            PremierConferences::ApJapan => Affinities::Ap,
            PremierConferences::ApOceania => Affinities::Ap,
            PremierConferences::ApSouthAsia => Affinities::Ap,
            PremierConferences::NaSuper => Affinities::Na,
            PremierConferences::EuTurkeySuper => Affinities::Eu,
            PremierConferences::EuMiddleEastSuper => Affinities::Eu,
            PremierConferences::EuDach => Affinities::Eu,
            PremierConferences::EuIbit => Affinities::Eu,
            PremierConferences::EuFrance => Affinities::Eu,
            PremierConferences::EuEast => Affinities::Eu,
            PremierConferences::EuDachSuper => Affinities::Eu,
            PremierConferences::EuIbitSuper => Affinities::Eu,
            PremierConferences::EuFranceSuper => Affinities::Eu,
            PremierConferences::EuEastSuper => Affinities::Eu,
            PremierConferences::EuNorth => Affinities::Eu,
            PremierConferences::EuNorthSuper => Affinities::Eu,
            PremierConferences::KrKoreaSuper => Affinities::Kr,
            PremierConferences::ApOceaniaSuper => Affinities::Ap,
            PremierConferences::ApAsiaSuper => Affinities::Ap,
            PremierConferences::ApJapanSuper => Affinities::Ap,
            PremierConferences::ApSouthAsiaSuper => Affinities::Ap,
            PremierConferences::BrBrazilSuper => Affinities::Br,
            PremierConferences::LatamNorthSuper => Affinities::Latam,
            PremierConferences::LatamSouthSuper => Affinities::Latam,
        }
    }
}
