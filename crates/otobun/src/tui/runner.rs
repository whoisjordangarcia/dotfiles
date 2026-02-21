use crate::config::DotConfig;
use crate::installer::components::Component;
use crate::installer::runner::OwnedRunner;
use crate::tui::theme;
use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};
use ratatui::Frame;
use std::path::PathBuf;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

enum ComponentStatus {
    Pending,
    Running,
    Success,
    Failed(String),
    Skipped,
}

enum FailureAction {
    Retry,
    Skip,
    Abort,
}

enum RunnerMsg {
    OutputChunk(String),
    ComponentDone(usize, Result<(), String>),
}

pub struct InstallRunner {
    components: Vec<Component>,
    selected: Vec<bool>,
    statuses: Vec<ComponentStatus>,
    current: usize,
    output: String,
    done: bool,
    dry_run: bool,
    failure_prompt: Option<usize>,
    dotfiles_dir: PathBuf,
    config: DotConfig,
    rx: Option<mpsc::Receiver<RunnerMsg>>,
}

impl InstallRunner {
    pub fn new(
        components: Vec<Component>,
        selected: Vec<bool>,
        dotfiles_dir: PathBuf,
        config: DotConfig,
        dry_run: bool,
    ) -> Self {
        let statuses = components
            .iter()
            .enumerate()
            .map(|(i, _)| {
                if selected[i] {
                    ComponentStatus::Pending
                } else {
                    ComponentStatus::Skipped
                }
            })
            .collect();

        Self {
            components,
            selected,
            statuses,
            current: 0,
            output: String::new(),
            done: false,
            dry_run,
            failure_prompt: None,
            dotfiles_dir,
            config,
            rx: None,
        }
    }

    pub fn run(mut self, terminal: &mut ratatui::DefaultTerminal) -> anyhow::Result<()> {
        if self.dry_run {
            return self.run_dry(terminal);
        }

        // Find first selected component
        self.advance_to_next_selected();
        self.start_current_component();

        while !self.done {
            // Process messages from background thread
            // Take rx out to avoid borrow conflicts when mutating self
            let msgs: Vec<_> = if let Some(ref rx) = self.rx {
                rx.try_iter().collect()
            } else {
                Vec::new()
            };
            for msg in msgs {
                match msg {
                    RunnerMsg::OutputChunk(chunk) => {
                        self.output.push_str(&chunk);
                    }
                    RunnerMsg::ComponentDone(idx, result) => match result {
                        Ok(()) => {
                            self.statuses[idx] = ComponentStatus::Success;
                            self.current += 1;
                            self.advance_to_next_selected();
                            if self.current < self.components.len() {
                                self.start_current_component();
                            } else {
                                self.done = true;
                            }
                        }
                        Err(err) => {
                            self.statuses[idx] = ComponentStatus::Failed(err);
                            self.failure_prompt = Some(idx);
                        }
                    },
                }
            }

            terminal.draw(|frame| self.draw(frame))?;

            if event::poll(Duration::from_millis(50))? {
                if let Event::Key(key) = event::read()? {
                    if key.kind == KeyEventKind::Press {
                        if self.failure_prompt.is_some() {
                            match Self::handle_failure_key(key.code) {
                                Some(FailureAction::Retry) => {
                                    let idx = self.failure_prompt.take().unwrap();
                                    self.statuses[idx] = ComponentStatus::Pending;
                                    self.current = idx;
                                    self.start_current_component();
                                }
                                Some(FailureAction::Skip) => {
                                    self.failure_prompt = None;
                                    self.current += 1;
                                    self.advance_to_next_selected();
                                    if self.current < self.components.len() {
                                        self.start_current_component();
                                    } else {
                                        self.done = true;
                                    }
                                }
                                Some(FailureAction::Abort) => {
                                    self.failure_prompt = None;
                                    self.done = true;
                                }
                                None => {}
                            }
                        } else if key.code == KeyCode::Char('q') {
                            self.done = true;
                        }
                    }
                }
            }
        }

        // Draw final state and wait for q to quit
        loop {
            terminal.draw(|frame| self.draw(frame))?;
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press && key.code == KeyCode::Char('q') {
                    break;
                }
            }
        }

        Ok(())
    }

    fn run_dry(mut self, terminal: &mut ratatui::DefaultTerminal) -> anyhow::Result<()> {
        loop {
            terminal.draw(|frame| self.draw_dry(frame))?;
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press
                    && matches!(key.code, KeyCode::Char('q') | KeyCode::Esc | KeyCode::Enter)
                {
                    break;
                }
            }
        }
        Ok(())
    }

    fn advance_to_next_selected(&mut self) {
        while self.current < self.components.len() && !self.selected[self.current] {
            self.current += 1;
        }
    }

    fn start_current_component(&mut self) {
        if self.current >= self.components.len() {
            self.done = true;
            return;
        }

        let idx = self.current;
        self.statuses[idx] = ComponentStatus::Running;
        self.output
            .push_str(&format!("\n━━━ {} ━━━\n", self.components[idx].name));

        let (tx, rx) = mpsc::channel();
        self.rx = Some(rx);

        let component_name = self.components[idx].name.clone();
        let dotfiles_dir = self.dotfiles_dir.clone();
        let config = self.config.clone();

        let tx_output = tx.clone();
        thread::spawn(move || {
            let runner = OwnedRunner::new(dotfiles_dir, config);
            let mut output_buf = Vec::new();
            let result = runner.run_component(&component_name, &mut output_buf);

            let output_str = String::from_utf8_lossy(&output_buf).to_string();
            let _ = tx_output.send(RunnerMsg::OutputChunk(output_str));

            let result = result.map_err(|e| e.to_string());
            let _ = tx.send(RunnerMsg::ComponentDone(idx, result));
        });
    }

    fn handle_failure_key(key: KeyCode) -> Option<FailureAction> {
        match key {
            KeyCode::Char('r') => Some(FailureAction::Retry),
            KeyCode::Char('s') => Some(FailureAction::Skip),
            KeyCode::Char('a') => Some(FailureAction::Abort),
            _ => None,
        }
    }

    fn draw(&self, frame: &mut Frame) {
        let area = frame.area();
        let chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(30), Constraint::Percentage(70)])
            .split(area);

        self.draw_module_list(frame, chunks[0]);
        self.draw_output(frame, chunks[1]);
    }

    fn draw_module_list(&self, frame: &mut Frame, area: Rect) {
        let mut lines = Vec::new();

        // Header
        let succeeded = self
            .statuses
            .iter()
            .filter(|s| matches!(s, ComponentStatus::Success))
            .count();
        let failed = self
            .statuses
            .iter()
            .filter(|s| matches!(s, ComponentStatus::Failed(_)))
            .count();
        let total_selected = self.selected.iter().filter(|s| **s).count();

        if self.done {
            lines.push(Line::from(vec![
                Span::styled("⚡ Done! ", theme::title_accent()),
                Span::styled(format!("✓ {succeeded}"), theme::success()),
                Span::raw("  "),
                if failed > 0 {
                    Span::styled(format!("✗ {failed}"), theme::error())
                } else {
                    Span::raw("")
                },
            ]));
        } else {
            lines.push(Line::styled(
                "⚡ Installing dotfiles",
                theme::title_accent(),
            ));
        }
        lines.push(Line::raw(""));

        for (i, comp) in self.components.iter().enumerate() {
            if !self.selected[i] {
                continue;
            }
            let (icon, style) = match &self.statuses[i] {
                ComponentStatus::Success => ("✓", theme::success()),
                ComponentStatus::Failed(_) => ("✗", theme::error()),
                ComponentStatus::Running => ("⠼", theme::spinner()),
                ComponentStatus::Pending => ("·", theme::unselected()),
                ComponentStatus::Skipped => continue,
            };
            lines.push(Line::from(vec![
                Span::styled(format!(" {icon} "), style),
                Span::raw(&comp.name),
            ]));
        }

        // Progress bar
        lines.push(Line::raw(""));
        let done_count = self
            .statuses
            .iter()
            .filter(|s| matches!(s, ComponentStatus::Success | ComponentStatus::Failed(_)))
            .count();
        let percent = if total_selected > 0 {
            done_count as f64 / total_selected as f64
        } else {
            0.0
        };
        let bar_width = area.width.saturating_sub(12);
        lines.push(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                theme::progress_bar(bar_width, percent),
                ratatui::style::Style::default().fg(theme::GREEN),
            ),
            Span::styled(
                format!(" [{done_count}/{total_selected}]"),
                theme::badge(),
            ),
        ]));

        // Failure prompt
        if let Some(idx) = self.failure_prompt {
            lines.push(Line::raw(""));
            lines.push(Line::styled(
                format!(" ✗ {} failed", self.components[idx].name),
                theme::error(),
            ));
            lines.push(Line::from(vec![
                Span::raw(" "),
                Span::styled("[r]", theme::help_key()),
                Span::styled("etry ", theme::help_value()),
                Span::styled("[s]", theme::help_key()),
                Span::styled("kip ", theme::help_value()),
                Span::styled("[a]", theme::help_key()),
                Span::styled("bort", theme::help_value()),
            ]));
        }

        // Footer
        if self.done {
            lines.push(Line::raw(""));
            lines.push(Line::from(vec![
                Span::raw("  "),
                Span::styled("q", theme::help_key()),
                Span::styled(": quit", theme::help_value()),
            ]));
        }

        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(ratatui::style::Style::default().fg(theme::HIGHLIGHT))
            .title(Span::styled(" modules ", theme::subtitle()));

        let paragraph = Paragraph::new(lines).block(block);
        frame.render_widget(paragraph, area);
    }

    fn draw_output(&self, frame: &mut Frame, area: Rect) {
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(ratatui::style::Style::default().fg(theme::HIGHLIGHT))
            .title(Span::styled(" output ", theme::subtitle()));

        let paragraph = Paragraph::new(self.output.as_str())
            .block(block)
            .wrap(Wrap { trim: false })
            .scroll((
                self.output
                    .lines()
                    .count()
                    .saturating_sub(area.height as usize - 2) as u16,
                0,
            ));

        frame.render_widget(paragraph, area);
    }

    fn draw_dry(&self, frame: &mut Frame) {
        let mut lines = Vec::new();

        lines.push(Line::styled(
            "  ⚡ Dry Run — no scripts will be executed",
            theme::warning(),
        ));
        lines.push(Line::styled(
            "  ─────────────────────────────────────────",
            theme::help_sep(),
        ));
        lines.push(Line::raw(""));

        let selected_components: Vec<_> = self
            .components
            .iter()
            .enumerate()
            .filter(|(i, _)| self.selected[*i])
            .collect();

        lines.push(Line::styled(
            format!("  Would install {} components:", selected_components.len()),
            theme::title(),
        ));
        lines.push(Line::raw(""));

        for (num, (_, comp)) in selected_components.iter().enumerate() {
            lines.push(Line::from(vec![
                Span::styled(format!("    {}. ", num + 1), theme::badge()),
                Span::styled(&comp.name, theme::active_item()),
                Span::styled(
                    format!("  → script/{}/setup.sh", comp.name),
                    theme::subtitle(),
                ),
            ]));
        }

        lines.push(Line::raw(""));
        lines.push(Line::styled(
            "  ──────────────────────────────────────────────────",
            theme::help_sep(),
        ));
        lines.push(Line::from(vec![
            Span::raw("  "),
            Span::styled("q", theme::help_key()),
            Span::styled(": quit", theme::help_value()),
        ]));

        frame.render_widget(Paragraph::new(lines), frame.area());
    }
}
