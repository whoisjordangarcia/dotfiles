use crate::config::DotConfig;
use crate::detector::DetectedSystem;
use crate::tui::theme;
use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

enum Field {
    Name,
    Environment,
    Email,
    YubiKey,
}

const ENVIRONMENTS: &[(&str, &str)] = &[("personal", "🏠 Personal"), ("work", "🏢 Work")];

pub struct Wizard {
    detected: DetectedSystem,
    name: String,
    env_index: usize,
    email: String,
    yubikey: String,
    active_field: Field,
    done: bool,
    cancelled: bool,
}

impl Wizard {
    pub fn new(detected: DetectedSystem) -> Self {
        Self {
            detected,
            name: String::new(),
            env_index: 0,
            email: String::new(),
            yubikey: String::new(),
            active_field: Field::Name,
            done: false,
            cancelled: false,
        }
    }

    pub fn run(mut self, terminal: &mut ratatui::DefaultTerminal) -> anyhow::Result<Option<DotConfig>> {
        while !self.done {
            terminal.draw(|frame| self.draw(frame))?;
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    self.handle_key(key.code);
                }
            }
        }

        if self.cancelled {
            return Ok(None);
        }

        // Apply defaults
        let name = if self.name.is_empty() {
            "Jordan Garcia".to_string()
        } else {
            self.name
        };
        let environment = ENVIRONMENTS[self.env_index].0.to_string();
        let email = if self.email.is_empty() {
            match environment.as_str() {
                "work" => "jordan.arickhogarcia@nestgenomics.com".to_string(),
                _ => "arickho@gmail.com".to_string(),
            }
        } else {
            self.email
        };

        Ok(Some(DotConfig {
            name,
            email,
            environment,
            system: self.detected.system.clone(),
            yubikey: self.yubikey,
        }))
    }

    fn handle_key(&mut self, key: KeyCode) {
        match key {
            KeyCode::Esc => {
                self.cancelled = true;
                self.done = true;
            }
            KeyCode::Tab => self.next_field(),
            KeyCode::BackTab => self.prev_field(),
            KeyCode::Enter => match self.active_field {
                Field::YubiKey => self.done = true,
                _ => self.next_field(),
            },
            _ => match self.active_field {
                Field::Name => Self::handle_text_input(&mut self.name, key),
                Field::Environment => match key {
                    KeyCode::Left | KeyCode::Char('h') => {
                        if self.env_index > 0 {
                            self.env_index -= 1;
                        }
                    }
                    KeyCode::Right | KeyCode::Char('l') => {
                        if self.env_index < ENVIRONMENTS.len() - 1 {
                            self.env_index += 1;
                        }
                    }
                    _ => {}
                },
                Field::Email => Self::handle_text_input(&mut self.email, key),
                Field::YubiKey => Self::handle_text_input(&mut self.yubikey, key),
            },
        }
    }

    fn handle_text_input(field: &mut String, key: KeyCode) {
        match key {
            KeyCode::Char(c) => field.push(c),
            KeyCode::Backspace => {
                field.pop();
            }
            _ => {}
        }
    }

    fn next_field(&mut self) {
        self.active_field = match self.active_field {
            Field::Name => Field::Environment,
            Field::Environment => Field::Email,
            Field::Email => Field::YubiKey,
            Field::YubiKey => Field::YubiKey,
        };
    }

    fn prev_field(&mut self) {
        self.active_field = match self.active_field {
            Field::Name => Field::Name,
            Field::Environment => Field::Name,
            Field::Email => Field::Environment,
            Field::YubiKey => Field::Email,
        };
    }

    fn draw(&self, frame: &mut Frame) {
        let mut lines = Vec::new();

        lines.push(Line::styled("  otobun", theme::logo()));
        lines.push(Line::raw(""));
        lines.push(Line::from(vec![
            Span::styled("  Setup Wizard  ", theme::title()),
            Span::styled(format!("Detected: {}", self.detected.system), theme::subtitle()),
        ]));
        lines.push(Line::styled(
            "  ──────────────────────────────────────────────────",
            theme::help_sep(),
        ));
        lines.push(Line::raw(""));

        // Name field
        let name_active = matches!(self.active_field, Field::Name);
        let indicator = if name_active { "▶ " } else { "  " };
        let label_style = if name_active { theme::title() } else { theme::help_value() };
        let placeholder = if self.name.is_empty() { "Jordan Garcia" } else { "" };
        lines.push(Line::from(vec![
            Span::styled(format!("  {indicator}Full Name: "), label_style),
            Span::raw(&self.name),
            Span::styled(placeholder, theme::unselected()),
            if name_active {
                Span::styled("█", theme::cursor())
            } else {
                Span::raw("")
            },
        ]));
        lines.push(Line::raw(""));

        // Environment field
        let env_active = matches!(self.active_field, Field::Environment);
        let indicator = if env_active { "▶ " } else { "  " };
        let label_style = if env_active { theme::title() } else { theme::help_value() };
        let mut env_spans = vec![Span::styled(format!("  {indicator}Environment: "), label_style)];
        for (i, (_, label)) in ENVIRONMENTS.iter().enumerate() {
            let style = if i == self.env_index {
                theme::selected()
            } else {
                theme::unselected()
            };
            env_spans.push(Span::styled(format!(" {label} "), style));
            if i < ENVIRONMENTS.len() - 1 {
                env_spans.push(Span::styled(" / ", theme::help_sep()));
            }
        }
        lines.push(Line::from(env_spans));
        lines.push(Line::raw(""));

        // Email field
        let email_active = matches!(self.active_field, Field::Email);
        let indicator = if email_active { "▶ " } else { "  " };
        let label_style = if email_active { theme::title() } else { theme::help_value() };
        let email_placeholder = if self.email.is_empty() {
            "you@example.com"
        } else {
            ""
        };
        lines.push(Line::from(vec![
            Span::styled(format!("  {indicator}Email: "), label_style),
            Span::raw(&self.email),
            Span::styled(email_placeholder, theme::unselected()),
            if email_active {
                Span::styled("█", theme::cursor())
            } else {
                Span::raw("")
            },
        ]));
        lines.push(Line::raw(""));

        // YubiKey field
        let yubi_active = matches!(self.active_field, Field::YubiKey);
        let indicator = if yubi_active { "▶ " } else { "  " };
        let label_style = if yubi_active { theme::title() } else { theme::help_value() };
        let yubi_placeholder = if self.yubikey.is_empty() {
            "Leave empty to skip"
        } else {
            ""
        };
        lines.push(Line::from(vec![
            Span::styled(format!("  {indicator}YubiKey ID: "), label_style),
            Span::raw(&self.yubikey),
            Span::styled(yubi_placeholder, theme::unselected()),
            if yubi_active {
                Span::styled("█", theme::cursor())
            } else {
                Span::raw("")
            },
        ]));

        // Footer
        lines.push(Line::raw(""));
        lines.push(Line::styled(
            "  ──────────────────────────────────────────────────",
            theme::help_sep(),
        ));
        lines.push(Line::from(vec![
            Span::raw("  "),
            Span::styled("tab", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("next", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("shift+tab", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("prev", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("enter", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("confirm", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("esc", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("cancel", theme::help_value()),
        ]));

        frame.render_widget(Paragraph::new(lines), frame.area());
    }
}
