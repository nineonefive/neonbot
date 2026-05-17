use chrono_tz::{America, Asia, Australia, Europe, Tz, US};
use serde::{Deserialize, Serialize};

/// Premier team regions
#[derive(Deserialize, Serialize, Clone, Copy, PartialEq, Debug)]
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
            Region::AsiaEast => "Asia",
            Region::Japan => "Japan",
            Region::Oceania => "Oceania",
            Region::AsiaSouth => "South Asia",
            Region::Korea => "Korea",
            Region::EuNorth => "EU North",
            Region::EuEast => "EU East",
            Region::Dach => "DACH",
            Region::Ibit => "IBIT",
            Region::France => "France",
            Region::MiddleEast => "Middle East",
            Region::Turkiye => "Türkiye",
        }
    }

    pub fn tz(&self) -> Tz {
        match self {
            Region::UsEast => US::Eastern,
            Region::UsWest => US::Pacific,
            Region::LatamNorth => America::New_York, // fixme: not sure this is right
            Region::LatamSouth => America::Santiago,
            Region::Brazil => America::Sao_Paulo,
            Region::AsiaEast => Asia::Taipei,
            Region::Japan => Asia::Tokyo,
            Region::Oceania => Australia::Sydney,
            Region::AsiaSouth => Asia::Kolkata,
            Region::Korea => Asia::Seoul,
            Region::EuNorth => Europe::London,
            Region::EuEast => Europe::Warsaw,
            Region::Dach => Europe::Berlin,
            Region::Ibit => Europe::Madrid,
            Region::France => Europe::Paris,
            Region::MiddleEast => Asia::Qatar,
            Region::Turkiye => Europe::Istanbul,
        }
    }

    pub fn from_riot_id(s: &str) -> Option<Region> {
        match s {
            "NA_US_EAST" => Some(Region::UsEast),
            "NA_US_WEST" => Some(Region::UsWest),
            "LATAM_NORTH" => Some(Region::LatamNorth),
            "LATAM_SOUTH" => Some(Region::LatamSouth),
            "BR_BRAZIL" => Some(Region::Brazil),
            "AP_ASIA" => Some(Region::AsiaEast),
            "AP_JAPAN" => Some(Region::Japan),
            "AP_OCEANIA" => Some(Region::Oceania),
            "AP_ASIA_SOUTH" => Some(Region::AsiaSouth),
            "KR_KOREA" => Some(Region::Korea),
            "EU_NORTH" => Some(Region::EuNorth),
            "EU_EAST" => Some(Region::EuEast),
            "EU_DACH" => Some(Region::Dach),
            "EU_IBIT" => Some(Region::Ibit),
            "EU_FRANCE" => Some(Region::France),
            "EU_MIDDLE_EAST" => Some(Region::MiddleEast),
            "EU_TURKIYE" => Some(Region::Turkiye),
            _ => None,
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
            Region::Dach,
            Region::Ibit,
            Region::France,
            Region::MiddleEast,
            Region::Turkiye,
        ]
    }
}

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
            assert_eq!(Region::from_riot_id(&region_id), Some(region));
        }
    }
}
