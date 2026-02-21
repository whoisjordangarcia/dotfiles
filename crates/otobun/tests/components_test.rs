use std::fs;
use tempfile::tempdir;

#[test]
fn test_parse_components() {
    let dir = tempdir().unwrap();
    let script_dir = dir.path().join("script");
    fs::create_dir_all(&script_dir).unwrap();

    let content = r#"#!/bin/bash
source ./script/common/log.sh

component_installation=(
    apps/arch
    # code
    git
    node
    lazygit/linux
    # essentials
    zsh
    vim
    tmux
)

for component in "${component_installation[@]}"; do
    section "$component"
done
"#;
    fs::write(script_dir.join("linux_arch_installation.sh"), content).unwrap();

    let components = otobun::installer::components::parse_components(dir.path(), "linux_arch").unwrap();
    let names: Vec<&str> = components.iter().map(|c| c.name.as_str()).collect();
    assert_eq!(names, vec!["apps/arch", "git", "node", "lazygit/linux", "zsh", "vim", "tmux"]);
}

#[test]
fn test_parse_components_commented_out() {
    let dir = tempdir().unwrap();
    let script_dir = dir.path().join("script");
    fs::create_dir_all(&script_dir).unwrap();

    let content = r#"#!/bin/bash
component_installation=(
    git
    #zsh
    tmux
    #vim
)
"#;
    fs::write(script_dir.join("mac_installation.sh"), content).unwrap();

    let components = otobun::installer::components::parse_components(dir.path(), "mac").unwrap();
    let names: Vec<&str> = components.iter().map(|c| c.name.as_str()).collect();
    assert_eq!(names, vec!["git", "tmux"]);
}

#[test]
fn test_parse_components_inline_comments() {
    let dir = tempdir().unwrap();
    let script_dir = dir.path().join("script");
    fs::create_dir_all(&script_dir).unwrap();

    let content = r#"#!/bin/bash
component_installation=(
    git     # version control
    zsh     # shell
)
"#;
    fs::write(script_dir.join("mac_installation.sh"), content).unwrap();

    let components = otobun::installer::components::parse_components(dir.path(), "mac").unwrap();
    let names: Vec<&str> = components.iter().map(|c| c.name.as_str()).collect();
    assert_eq!(names, vec!["git", "zsh"]);
}

#[test]
fn test_parse_components_missing_script() {
    let dir = tempdir().unwrap();
    assert!(otobun::installer::components::parse_components(dir.path(), "nonexistent").is_err());
}

#[test]
fn test_parse_components_no_array() {
    let dir = tempdir().unwrap();
    let script_dir = dir.path().join("script");
    fs::create_dir_all(&script_dir).unwrap();

    let content = "#!/bin/bash\necho hello\n";
    fs::write(script_dir.join("mac_installation.sh"), content).unwrap();

    assert!(otobun::installer::components::parse_components(dir.path(), "mac").is_err());
}
