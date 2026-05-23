use serenity::{builder::CreateEmbedFooter, model::Color};

pub const PRIMARY_COLOR: Color = Color::new(0x03fccf);

#[inline(always)]
pub fn bot_footer() -> CreateEmbedFooter {
    CreateEmbedFooter::new("Made with 💙 by 915")
}
