use ratatui::style::{Color, Modifier, Style};

// Brand colors (matching Go theme)
pub const BLUE: Color = Color::Rgb(91, 155, 213);
pub const CYAN: Color = Color::Rgb(86, 204, 242);
pub const GREEN: Color = Color::Rgb(107, 203, 119);
pub const RED: Color = Color::Rgb(255, 107, 107);
pub const YELLOW: Color = Color::Rgb(255, 217, 61);
pub const PURPLE: Color = Color::Rgb(192, 132, 252);
pub const MAGENTA: Color = Color::Rgb(244, 114, 182);
pub const MUTED: Color = Color::Rgb(85, 85, 85);
pub const DIM: Color = Color::Rgb(58, 58, 58);
pub const WHITE: Color = Color::Rgb(250, 250, 250);
pub const BG_SUBTLE: Color = Color::Rgb(26, 26, 46);
pub const BG_PANEL: Color = Color::Rgb(22, 33, 62);
pub const HIGHLIGHT: Color = Color::Rgb(15, 52, 96);

pub fn logo() -> Style {
    Style::default().fg(PURPLE).add_modifier(Modifier::BOLD)
}

pub fn title() -> Style {
    Style::default().fg(CYAN).add_modifier(Modifier::BOLD)
}

pub fn title_accent() -> Style {
    Style::default().fg(PURPLE).add_modifier(Modifier::BOLD)
}

pub fn subtitle() -> Style {
    Style::default().fg(MUTED).add_modifier(Modifier::ITALIC)
}

pub fn success() -> Style {
    Style::default().fg(GREEN).add_modifier(Modifier::BOLD)
}

pub fn error() -> Style {
    Style::default().fg(RED).add_modifier(Modifier::BOLD)
}

pub fn warning() -> Style {
    Style::default().fg(YELLOW)
}

pub fn selected() -> Style {
    Style::default().fg(GREEN).add_modifier(Modifier::BOLD)
}

pub fn unselected() -> Style {
    Style::default().fg(MUTED)
}

pub fn active_item() -> Style {
    Style::default().fg(WHITE).add_modifier(Modifier::BOLD)
}

pub fn cursor() -> Style {
    Style::default().fg(CYAN).add_modifier(Modifier::BOLD)
}

pub fn spinner() -> Style {
    Style::default().fg(PURPLE)
}

pub fn help_key() -> Style {
    Style::default().fg(PURPLE).add_modifier(Modifier::BOLD)
}

pub fn help_sep() -> Style {
    Style::default().fg(DIM)
}

pub fn help_value() -> Style {
    Style::default().fg(MUTED)
}

pub fn badge() -> Style {
    Style::default().fg(CYAN).add_modifier(Modifier::BOLD)
}

pub fn progress_bar(width: u16, percent: f64) -> String {
    let filled = (width as f64 * percent).round() as usize;
    let empty = width as usize - filled;
    format!("{}{}", "█".repeat(filled), "░".repeat(empty))
}
