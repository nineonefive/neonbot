#[derive(Copy, Debug, Clone, PartialEq, Eq)]
pub enum MatchType {
    Scrim,
    Match,
    Playoffs,
}

impl MatchType {
    pub fn from_event_type(event_type: &str) -> Option<Self> {
        match event_type {
            "SCRIM" => Some(Self::Scrim),
            "LEAGUE" => Some(Self::Match),
            "TOURNAMENT" => Some(Self::Playoffs),
            _ => None,
        }
    }

    pub fn to_string(&self) -> &str {
        match self {
            Self::Scrim => "Scrim",
            Self::Match => "Match",
            Self::Playoffs => "Playoffs",
        }
    }
}
