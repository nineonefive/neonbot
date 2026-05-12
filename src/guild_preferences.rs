use serde::{Deserialize, Serialize};
use serenity::model::id::{ChannelId, GuildId, RoleId};

use crate::premier::PartialTeam;

#[derive(Serialize, Deserialize)]
pub struct GuildPreferences {
    guild_id: GuildId,
    announcements_channel: Option<ChannelId>,
    voice_channel: Option<ChannelId>,
    signup_role: Option<RoleId>,
    premier_team: Option<PartialTeam>,
}

impl GuildPreferences {
    pub fn new(guild_id: GuildId) -> Self {
        Self {
            guild_id,
            announcements_channel: None,
            voice_channel: None,
            signup_role: None,
            premier_team: None,
        }
    }
}
