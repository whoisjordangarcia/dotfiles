#[test]
fn test_detect_returns_valid_system() {
    let sys = otobun::detector::detect();
    assert!(!sys.os.is_empty(), "OS should not be empty");
    assert!(!sys.system.is_empty(), "System should not be empty");

    #[cfg(target_os = "macos")]
    {
        assert_eq!(sys.os, "mac");
        assert_eq!(sys.system, "mac");
    }

    #[cfg(target_os = "linux")]
    {
        assert_eq!(sys.os, "linux");
        assert!(!sys.distro.is_empty(), "Distro should not be empty on linux");
    }
}

#[test]
fn test_parse_os_release_arch() {
    let content = "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n";
    assert_eq!(otobun::detector::parse_os_release_content(content), "arch");
}

#[test]
fn test_parse_os_release_ubuntu() {
    let content = "NAME=\"Ubuntu\"\nVERSION=\"22.04.3 LTS\"\nID=ubuntu\n";
    assert_eq!(otobun::detector::parse_os_release_content(content), "ubuntu");
}

#[test]
fn test_parse_os_release_fedora() {
    let content = "NAME=\"Fedora Linux\"\nID=fedora\n";
    assert_eq!(otobun::detector::parse_os_release_content(content), "fedora");
}

#[test]
fn test_parse_os_release_quoted() {
    let content = "ID=\"manjaro\"\n";
    assert_eq!(otobun::detector::parse_os_release_content(content), "manjaro");
}

#[test]
fn test_parse_os_release_missing_id() {
    let content = "NAME=\"Some OS\"\n";
    assert_eq!(otobun::detector::parse_os_release_content(content), "unknown");
}
