use std::fs;
use tempfile::tempdir;

#[test]
fn test_load_config() {
    let dir = tempdir().unwrap();
    let content = r#"# Dotfiles configuration
DOT_NAME="Jordan Garcia"
DOT_EMAIL="arickho@gmail.com"
DOT_ENVIRONMENT="personal"
DOT_SYSTEM="linux_arch"
DOT_YUBIKEY=""
"#;
    fs::write(dir.path().join(".dotconfig"), content).unwrap();

    let cfg = otobun::config::DotConfig::load(dir.path()).unwrap();
    assert_eq!(cfg.name, "Jordan Garcia");
    assert_eq!(cfg.email, "arickho@gmail.com");
    assert_eq!(cfg.environment, "personal");
    assert_eq!(cfg.system, "linux_arch");
    assert_eq!(cfg.yubikey, "");
}

#[test]
fn test_load_config_not_found() {
    let dir = tempdir().unwrap();
    assert!(otobun::config::DotConfig::load(dir.path()).is_err());
}

#[test]
fn test_save_and_load_roundtrip() {
    let dir = tempdir().unwrap();
    let cfg = otobun::config::DotConfig {
        name: "Test User".into(),
        email: "test@example.com".into(),
        environment: "work".into(),
        system: "mac".into(),
        yubikey: "ABC123".into(),
    };

    cfg.save(dir.path()).unwrap();
    let loaded = otobun::config::DotConfig::load(dir.path()).unwrap();
    assert_eq!(loaded.name, "Test User");
    assert_eq!(loaded.email, "test@example.com");
    assert_eq!(loaded.environment, "work");
    assert_eq!(loaded.system, "mac");
    assert_eq!(loaded.yubikey, "ABC123");
}

#[test]
fn test_config_exists() {
    let dir = tempdir().unwrap();
    assert!(!otobun::config::DotConfig::exists(dir.path()));
    fs::write(dir.path().join(".dotconfig"), "DOT_NAME=\"x\"\n").unwrap();
    assert!(otobun::config::DotConfig::exists(dir.path()));
}

#[test]
fn test_config_to_env() {
    let cfg = otobun::config::DotConfig {
        name: "Jordan Garcia".into(),
        email: "test@example.com".into(),
        environment: "personal".into(),
        system: "linux_arch".into(),
        yubikey: "".into(),
    };

    let env = cfg.to_env();
    assert!(env.contains(&("DOT_NAME".into(), "Jordan Garcia".into())));
    assert!(env.contains(&("DOT_EMAIL".into(), "test@example.com".into())));
    assert!(env.contains(&("DOT_ENVIRONMENT".into(), "personal".into())));
    assert!(env.contains(&("DOT_SYSTEM".into(), "linux_arch".into())));
    assert!(env.contains(&("DOT_YUBIKEY".into(), "".into())));
}
