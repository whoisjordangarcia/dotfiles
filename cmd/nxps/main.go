package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/whoisjordangarcia/dotfiles/internal/nxps"
)

func main() {
	listMode := flag.Bool("list", false, "Non-interactive styled list output")
	flag.Parse()

	var err error
	if *listMode {
		err = nxps.PrintList()
	} else {
		err = nxps.RunTUI()
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "nxps: %v\n", err)
		os.Exit(1)
	}
}
