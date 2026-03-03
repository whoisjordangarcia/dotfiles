use std::fs;
use tempfile::tempdir;

#[test]
fn test_runner_executes_script() {
    let dir = tempdir().unwrap();

    // Create minimal log.sh and symlink.sh stubs
    let common_dir = dir.path().join("script/common");
    fs::create_dir_all(&common_dir).unwrap();
    fs::write(common_dir.join("log.sh"), "# stub").unwrap();
    fs::write(common_dir.join("symlink.sh"), "# stub").unwrap();

    // Create a simple test component
    let comp_dir = dir.path().join("script/test_component");
    fs::create_dir_all(&comp_dir).unwrap();
    fs::write(comp_dir.join("setup.sh"), "echo 'hello from test'").unwrap();

    let cfg = otobun::config::DotConfig {
        name: "Test".into(),
        email: "test@test.com".into(),
        environment: "personal".into(),
        system: "linux_arch".into(),
        yubikey: "".into(),
    };

    let runner = otobun::installer::runner::Runner::new(dir.path(), &cfg);
    let mut output = Vec::new();
    let result = runner.run_component("test_component", &mut output);
    assert!(result.is_ok(), "run_component failed: {:?}", result.err());

    let output_str = String::from_utf8(output).unwrap();
    assert!(output_str.contains("hello from test"));
}

#[test]
fn test_runner_missing_script() {
    let dir = tempdir().unwrap();
    let cfg = otobun::config::DotConfig::default();

    let runner = otobun::installer::runner::Runner::new(dir.path(), &cfg);
    let mut output = Vec::new();
    assert!(runner.run_component("nonexistent", &mut output).is_err());
}

#[test]
fn test_runner_sets_env_vars() {
    let dir = tempdir().unwrap();
    let common_dir = dir.path().join("script/common");
    fs::create_dir_all(&common_dir).unwrap();
    fs::write(common_dir.join("log.sh"), "# stub").unwrap();
    fs::write(common_dir.join("symlink.sh"), "# stub").unwrap();

    let comp_dir = dir.path().join("script/env_test");
    fs::create_dir_all(&comp_dir).unwrap();
    fs::write(
        comp_dir.join("setup.sh"),
        "echo \"name=$DOT_NAME env=$DOT_ENVIRONMENT symlink=$DOT_SYMLINK_MODE\"",
    )
    .unwrap();

    let cfg = otobun::config::DotConfig {
        name: "Jordan".into(),
        email: "j@test.com".into(),
        environment: "work".into(),
        system: "mac".into(),
        yubikey: "".into(),
    };

    let runner = otobun::installer::runner::Runner::new(dir.path(), &cfg);
    let mut output = Vec::new();
    runner.run_component("env_test", &mut output).unwrap();

    let output_str = String::from_utf8(output).unwrap();
    assert!(output_str.contains("name=Jordan"));
    assert!(output_str.contains("env=work"));
    assert!(output_str.contains("symlink=override"));
}

#[test]
fn test_runner_work_env_sets_work_env() {
    let dir = tempdir().unwrap();
    let common_dir = dir.path().join("script/common");
    fs::create_dir_all(&common_dir).unwrap();
    fs::write(common_dir.join("log.sh"), "# stub").unwrap();
    fs::write(common_dir.join("symlink.sh"), "# stub").unwrap();

    let comp_dir = dir.path().join("script/work_test");
    fs::create_dir_all(&comp_dir).unwrap();
    fs::write(comp_dir.join("setup.sh"), "echo \"WORK_ENV=$WORK_ENV\"").unwrap();

    let cfg = otobun::config::DotConfig {
        environment: "work".into(),
        ..Default::default()
    };

    let runner = otobun::installer::runner::Runner::new(dir.path(), &cfg);
    let mut output = Vec::new();
    runner.run_component("work_test", &mut output).unwrap();

    let output_str = String::from_utf8(output).unwrap();
    assert!(output_str.contains("WORK_ENV=1"));
}
