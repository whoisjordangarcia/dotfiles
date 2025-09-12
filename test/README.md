# Testing

This directory contains the testing infrastructure for the dotfiles repository.

## Overview

The test suite validates core functionality of the dotfiles management system including:

- **Syntax validation** for all shell scripts
- **System detection** functionality
- **Configuration management** (save/load)
- **CLI interface** functionality

## Running Tests

### Run All Tests

```bash
./test/test_runner.sh
```

### Run Specific Test Suites

```bash
# Only syntax validation
./test/test_runner.sh syntax

# Only functionality tests
./test/test_runner.sh functionality
```

### Run Individual Tests

```bash
# Test system detection
./test/test_system_detection.sh

# Test configuration management
./test/test_config.sh

# Test CLI functionality
./test/test_cli.sh
```

## Test Structure

- `test_runner.sh` - Main test runner that orchestrates all tests
- `test_system_detection.sh` - Tests OS/distribution detection logic
- `test_config.sh` - Tests configuration save/load functionality
- `test_cli.sh` - Tests CLI command-line interface

## What's Tested

### Syntax Validation Tests
- Validates that all shell scripts have correct syntax
- Checks `bin/dot`, `bootstrap.sh`, and all `*_installation.sh` scripts

### System Detection Tests
- Tests OS and distribution detection (mac, linux_ubuntu, etc.)
- Validates available installation script discovery
- Tests auto-selection of appropriate installation scripts

### Configuration Management Tests
- Tests saving configuration to `.dotconfig` file
- Tests loading configuration from file
- Validates configuration file format

### CLI Interface Tests
- Tests `--help` flag functionality
- Tests `--list` flag to show available installations
- Tests `--system` flag for system detection output
- Tests invalid option handling

## Adding New Tests

To add new test functionality:

1. Create a new test file: `test/test_new_feature.sh`
2. Make it executable: `chmod +x test/test_new_feature.sh`
3. Add the test to `test_runner.sh` in the appropriate section
4. Follow the existing pattern for test output and error handling

## Test Requirements

- Tests should be self-contained and not modify the actual dotfiles installation
- Use temporary files when testing file operations
- Clean up any temporary files using trap handlers
- Exit with appropriate codes (0 for success, 1 for failure)