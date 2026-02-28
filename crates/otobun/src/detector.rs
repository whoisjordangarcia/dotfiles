use std::fmt;
use std::fs;

#[derive(Debug, Clone)]
pub struct DetectedSystem {
    pub os: String,
    pub distro: String,
    pub system: String,
}

impl fmt::Display for DetectedSystem {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f, "OS:     {}", self.os)?;
        writeln!(f, "Distro: {}", if self.distro.is_empty() { "(n/a)" } else { &self.distro })?;
        write!(f, "System: {}", self.system)
    }
}

pub fn detect() -> DetectedSystem {
    match std::env::consts::OS {
        "macos" => DetectedSystem {
            os: "mac".into(),
            distro: String::new(),
            system: "mac".into(),
        },
        "linux" => {
            let distro = detect_linux_distro();
            let system = if distro.is_empty() || distro == "unknown" {
                "linux".into()
            } else {
                format!("linux_{distro}")
            };
            DetectedSystem {
                os: "linux".into(),
                distro,
                system,
            }
        }
        _ => DetectedSystem {
            os: "unknown".into(),
            distro: String::new(),
            system: "unknown".into(),
        },
    }
}

fn detect_linux_distro() -> String {
    match fs::read_to_string("/etc/os-release") {
        Ok(content) => parse_os_release_content(&content),
        Err(_) => "unknown".into(),
    }
}

pub fn parse_os_release_content(content: &str) -> String {
    for line in content.lines() {
        let line = line.trim();
        if let Some(value) = line.strip_prefix("ID=") {
            return value.trim_matches(|c| c == '"' || c == '\'').to_string();
        }
    }
    "unknown".into()
}
