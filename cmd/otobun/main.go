package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--help", "-h":
			fmt.Println("otobun - dotfiles manager")
			fmt.Println()
			fmt.Println("Usage:")
			fmt.Println("  otobun             Interactive setup & install")
			fmt.Println("  otobun --setup     Force setup wizard")
			fmt.Println("  otobun --config    Show current configuration")
			fmt.Println("  otobun --system    Show detected system")
			return
		}
	}
	fmt.Println("otobun: coming soon")
}
