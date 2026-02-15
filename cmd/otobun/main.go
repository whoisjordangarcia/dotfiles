package main

import (
	"fmt"
	"os"

	"github.com/whoisjordangarcia/dotfiles/internal/config"
	"github.com/whoisjordangarcia/dotfiles/internal/detector"
	"github.com/whoisjordangarcia/dotfiles/internal/tui"
)

func main() {
	dotfilesDir, err := tui.FindDotfilesDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--help", "-h":
			printUsage()
			return
		case "--config", "-c":
			showConfig(dotfilesDir)
			return
		case "--system", "-s":
			showSystem()
			return
		case "--setup":
			if err := tui.Run(dotfilesDir, true); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			return
		default:
			fmt.Fprintf(os.Stderr, "Unknown option: %s\n", os.Args[1])
			printUsage()
			os.Exit(1)
		}
	}

	// Default: full TUI flow
	if err := tui.Run(dotfilesDir, false); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("otobun - dotfiles manager")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  otobun             Interactive setup & install")
	fmt.Println("  otobun --setup     Force setup wizard")
	fmt.Println("  otobun --config    Show current configuration")
	fmt.Println("  otobun --system    Show detected system")
	fmt.Println("  otobun --help      Show this help")
}

func showConfig(dotfilesDir string) {
	if !config.Exists(dotfilesDir) {
		fmt.Println("No configuration found. Run 'otobun --setup' to configure.")
		return
	}
	cfg, err := config.Load(dotfilesDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Name:        %s\n", cfg.Name)
	fmt.Printf("Email:       %s\n", cfg.Email)
	fmt.Printf("Environment: %s\n", cfg.Environment)
	fmt.Printf("System:      %s\n", cfg.System)
	fmt.Printf("YubiKey:     %s\n", cfg.YubiKey)
}

func showSystem() {
	sys := detector.Detect()
	fmt.Printf("OS:     %s\n", sys.OS)
	fmt.Printf("Distro: %s\n", sys.Distro)
	fmt.Printf("System: %s\n", sys.System)
}
