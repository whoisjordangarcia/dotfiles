use crate::installer::components::Component;
use crate::tui::theme;
use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

pub struct SelectorResult {
    pub components: Vec<Component>,
    pub selected: Vec<bool>,
    pub confirmed: bool,
}

pub struct Selector {
    components: Vec<Component>,
    selected: Vec<bool>,
    cursor: usize,
    system: String,
    done: bool,
    confirmed: bool,
}

impl Selector {
    pub fn new(components: Vec<Component>, system: String) -> Self {
        let selected = vec![true; components.len()];
        Self {
            components,
            selected,
            cursor: 0,
            system,
            done: false,
            confirmed: false,
        }
    }

    pub fn run(mut self, terminal: &mut ratatui::DefaultTerminal) -> anyhow::Result<SelectorResult> {
        while !self.done {
            terminal.draw(|frame| self.draw(frame))?;
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    self.handle_key(key.code);
                }
            }
        }
        Ok(SelectorResult {
            components: self.components,
            selected: self.selected,
            confirmed: self.confirmed,
        })
    }

    fn handle_key(&mut self, key: KeyCode) {
        match key {
            KeyCode::Char('j') | KeyCode::Down => {
                if self.cursor < self.components.len().saturating_sub(1) {
                    self.cursor += 1;
                }
            }
            KeyCode::Char('k') | KeyCode::Up => {
                if self.cursor > 0 {
                    self.cursor -= 1;
                }
            }
            KeyCode::Char(' ') | KeyCode::Char('x') => {
                self.selected[self.cursor] = !self.selected[self.cursor];
            }
            KeyCode::Char('a') => {
                self.selected.fill(true);
            }
            KeyCode::Char('n') => {
                self.selected.fill(false);
            }
            KeyCode::Enter => {
                self.confirmed = true;
                self.done = true;
            }
            KeyCode::Char('q') | KeyCode::Esc => {
                self.confirmed = false;
                self.done = true;
            }
            _ => {}
        }
    }

    fn draw(&self, frame: &mut Frame) {
        let area = frame.area();

        let selected_count = self.selected.iter().filter(|s| **s).count();
        let total = self.components.len();

        let mut lines = Vec::new();

        // Logo
        lines.push(Line::styled("  otobun", theme::logo()));
        lines.push(Line::raw(""));

        // Title with badge
        lines.push(Line::from(vec![
            Span::styled("  Module Selection ", theme::title()),
            Span::styled(format!("[{selected_count}/{total}] "), theme::badge()),
            Span::styled(&self.system, theme::subtitle()),
        ]));
        lines.push(Line::styled(
            "  ──────────────────────────────────────────────────",
            theme::help_sep(),
        ));
        lines.push(Line::raw(""));

        // Component list
        for (i, comp) in self.components.iter().enumerate() {
            let is_cursor = i == self.cursor;
            let is_selected = self.selected[i];

            let cursor_str = if is_cursor { "  ❯ " } else { "    " };
            let check = if is_selected { "●" } else { "○" };

            let check_style = if is_selected {
                theme::selected()
            } else {
                theme::unselected()
            };
            let name_style = if is_cursor {
                theme::active_item()
            } else if is_selected {
                ratatui::style::Style::default().fg(theme::WHITE)
            } else {
                theme::unselected()
            };

            lines.push(Line::from(vec![
                Span::styled(cursor_str, theme::cursor()),
                Span::styled(check, check_style),
                Span::raw(" "),
                Span::styled(&comp.name, name_style),
            ]));
        }

        // Footer
        lines.push(Line::raw(""));
        lines.push(Line::styled(
            "  ──────────────────────────────────────────────────",
            theme::help_sep(),
        ));
        lines.push(Line::from(vec![
            Span::raw("  "),
            Span::styled("space", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("toggle", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("a", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("all", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("n", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("none", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("↵", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("install", theme::help_value()),
            Span::styled(" · ", theme::help_sep()),
            Span::styled("q", theme::help_key()),
            Span::styled(": ", theme::help_sep()),
            Span::styled("quit", theme::help_value()),
        ]));

        let paragraph = Paragraph::new(lines);
        frame.render_widget(paragraph, area);
    }
}
