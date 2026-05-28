use std::str::FromStr;

use serde::{Deserialize, Serialize};
use valorant_api::types::{Affinities, PremierConferences};

/// Premier team regions
#[derive(Deserialize, Serialize, Clone, Copy, Eq, PartialEq, Debug, Hash)]
pub enum Region {
    UsEast,
    UsWest,
    LatamNorth,
    LatamSouth,
    Brazil,
    AsiaEast,
    Japan,
    Oceania,
    AsiaSouth,
    Korea,
    EuNorth,
    EuEast,
    EuWest,
    Dach,
    Ibit,
    France,
    MiddleEast,
    Turkiye,
}

impl Region {
    pub fn riot_id(&self) -> &str {
        match self {
            Region::UsEast => "NA_US_EAST",
            Region::UsWest => "NA_US_WEST",
            Region::LatamNorth => "LATAM_NORTH",
            Region::LatamSouth => "LATAM_SOUTH",
            Region::Brazil => "BR_BRAZIL",
            Region::AsiaEast => "AP_ASIA",
            Region::Japan => "AP_JAPAN",
            Region::Oceania => "AP_OCEANIA",
            Region::AsiaSouth => "AP_ASIA_SOUTH",
            Region::Korea => "KR_KOREA",
            Region::EuNorth => "EU_NORTH",
            Region::EuEast => "EU_EAST",
            Region::EuWest => "EU_WEST",
            Region::Dach => "EU_DACH",
            Region::Ibit => "EU_IBIT",
            Region::France => "EU_FRANCE",
            Region::MiddleEast => "EU_MIDDLE_EAST",
            Region::Turkiye => "EU_TURKIYE",
        }
    }

    pub fn name(&self) -> &str {
        match self {
            Region::UsEast => "US East",
            Region::UsWest => "US West",
            Region::LatamNorth => "Latin America North",
            Region::LatamSouth => "Latin America South",
            Region::Brazil => "Brazil",
            Region::AsiaEast => "East Asia",
            Region::Japan => "Japan",
            Region::Oceania => "Oceania",
            Region::AsiaSouth => "South Asia",
            Region::Korea => "Korea",
            Region::EuNorth => "EU North",
            Region::EuEast => "EU East",
            Region::EuWest => "EU West",
            Region::Dach => "DACH",
            Region::Ibit => "IBIT",
            Region::France => "France",
            Region::MiddleEast => "Middle East",
            Region::Turkiye => "Türkiye",
        }
    }

    pub fn all_regions() -> &'static [Region] {
        &[
            Region::UsEast,
            Region::UsWest,
            Region::LatamNorth,
            Region::LatamSouth,
            Region::Brazil,
            Region::AsiaEast,
            Region::Japan,
            Region::Oceania,
            Region::AsiaSouth,
            Region::Korea,
            Region::EuNorth,
            Region::EuEast,
            Region::EuWest,
            Region::Dach,
            Region::Ibit,
            Region::France,
            Region::MiddleEast,
            Region::Turkiye,
        ]
    }
}

impl FromStr for Region {
    type Err = UnsupportedRegionError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "NA_US_EAST" => Ok(Region::UsEast),
            "NA_US_WEST" => Ok(Region::UsWest),
            "LATAM_NORTH" => Ok(Region::LatamNorth),
            "LATAM_SOUTH" => Ok(Region::LatamSouth),
            "BR_BRAZIL" => Ok(Region::Brazil),
            "AP_ASIA" => Ok(Region::AsiaEast),
            "AP_JAPAN" => Ok(Region::Japan),
            "AP_OCEANIA" => Ok(Region::Oceania),
            "AP_ASIA_SOUTH" => Ok(Region::AsiaSouth),
            "KR_KOREA" => Ok(Region::Korea),
            "EU_NORTH" => Ok(Region::EuNorth),
            "EU_EAST" => Ok(Region::EuEast),
            "EU_WEST" => Ok(Region::EuWest),
            "EU_DACH" => Ok(Region::Dach),
            "EU_IBIT" => Ok(Region::Ibit),
            "EU_FRANCE" => Ok(Region::France),
            "EU_MIDDLE_EAST" => Ok(Region::MiddleEast),
            "EU_TURKIYE" => Ok(Region::Turkiye),
            _ => Err(UnsupportedRegionError(s.to_owned())),
        }
    }
}

impl TryFrom<PremierConferences> for Region {
    type Error = UnsupportedRegionError;

    fn try_from(value: PremierConferences) -> Result<Self, Self::Error> {
        let result = match value {
            PremierConferences::EuCentralEast => Region::EuEast,
            PremierConferences::EuWest => Region::EuWest,
            PremierConferences::EuMiddleEast => Region::MiddleEast,
            PremierConferences::EuTurkey => Region::Turkiye,
            PremierConferences::NaUsEast => Region::UsEast,
            PremierConferences::NaUsWest => Region::UsWest,
            PremierConferences::LatamNorth => Region::LatamNorth,
            PremierConferences::LatamSouth => Region::LatamSouth,
            PremierConferences::BrBrazil => Region::Brazil,
            PremierConferences::KrKorea => Region::Korea,
            PremierConferences::ApAsia => Region::AsiaEast,
            PremierConferences::ApJapan => Region::Japan,
            PremierConferences::ApOceania => Region::Oceania,
            PremierConferences::ApSouthAsia => Region::AsiaSouth,
            PremierConferences::EuTurkeySuper => Region::Turkiye,
            PremierConferences::EuDach => Region::Dach,
            PremierConferences::EuIbit => Region::Ibit,
            PremierConferences::EuFrance => Region::France,
            PremierConferences::EuNorth => Region::EuNorth,
            _ => return Err(UnsupportedRegionError(value.to_string())), // all the super variants
        };

        Ok(result)
    }
}

impl From<Region> for PremierConferences {
    fn from(region: Region) -> Self {
        match region {
            Region::AsiaEast => PremierConferences::ApAsia,
            Region::Japan => PremierConferences::ApJapan,
            Region::Oceania => PremierConferences::ApOceania,
            Region::AsiaSouth => PremierConferences::ApSouthAsia,
            Region::Turkiye => PremierConferences::EuTurkeySuper,
            Region::Dach => PremierConferences::EuDach,
            Region::Ibit => PremierConferences::EuIbit,
            Region::France => PremierConferences::EuFrance,
            Region::EuNorth => PremierConferences::EuNorth,
            Region::UsEast => PremierConferences::NaUsEast,
            Region::UsWest => PremierConferences::NaUsWest,
            Region::LatamNorth => PremierConferences::LatamNorth,
            Region::LatamSouth => PremierConferences::LatamSouth,
            Region::Brazil => PremierConferences::BrBrazil,
            Region::Korea => PremierConferences::KrKorea,
            Region::EuEast => PremierConferences::EuEast,
            Region::EuWest => PremierConferences::EuWest,
            Region::MiddleEast => PremierConferences::EuMiddleEast,
        }
    }
}

impl From<Region> for Affinities {
    fn from(region: Region) -> Self {
        match region {
            Region::AsiaEast => Affinities::Ap,
            Region::Japan => Affinities::Ap,
            Region::Oceania => Affinities::Ap,
            Region::AsiaSouth => Affinities::Ap,
            Region::Turkiye => Affinities::Eu,
            Region::Dach => Affinities::Eu,
            Region::Ibit => Affinities::Eu,
            Region::France => Affinities::Eu,
            Region::EuNorth => Affinities::Eu,
            Region::UsEast => Affinities::Na,
            Region::UsWest => Affinities::Na,
            Region::LatamNorth => Affinities::Latam,
            Region::LatamSouth => Affinities::Latam,
            Region::Brazil => Affinities::Br,
            Region::Korea => Affinities::Kr,
            Region::EuEast => Affinities::Eu,
            Region::EuWest => Affinities::Eu,
            Region::MiddleEast => Affinities::Eu,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UnsupportedRegionError(pub String);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_all_regions() {
        let regions = Region::all_regions();
        assert_eq!(regions.len(), 17);
    }

    #[test]
    fn test_riot_ids() {
        for &region in Region::all_regions() {
            let region_id = region.riot_id();
            assert_eq!(str::parse::<Region>(&region_id), Ok(region));
        }
    }
}
