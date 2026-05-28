pub use valorant_api::types::Affinities as Affinity;
pub use valorant_api::types::PremierConferences as Conference;
pub use valorant_api::types::PremierSeasonsEventMapSelectionTypes as MapSelection;
pub use valorant_api::types::PremierSeasonsEventTypes as EventType;

mod team;
pub use team::PartialPremierTeam;
mod schedule;
pub use schedule::{PremierEvent, PremierSchedule};
