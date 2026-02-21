use std::fmt;

#[derive(Debug, Clone)]
pub struct DetectedSystem {
    pub os: String,
    pub distro: String,
    pub system: String,
}

impl fmt::Display for DetectedSystem {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f, "OS:     {}", self.os)?;
        writeln!(f, "Distro: {}", self.distro)?;
        write!(f, "System: {}", self.system)
    }
}

pub fn detect() -> DetectedSystem {
    todo!()
}
