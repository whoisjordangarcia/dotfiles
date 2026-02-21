package tui

import (
	"github.com/whoisjordangarcia/dotfiles/internal/process"
)

// processesLoadedMsg is sent when process collection completes.
type processesLoadedMsg struct {
	Groups []process.WorktreeGroup
	Err    error
}

// killStartedMsg signals that a kill operation has begun.
type killStartedMsg struct{}

// killDoneMsg carries the results of a kill operation.
type killDoneMsg struct {
	Results   []process.KillResult
	Survivors []int
}

// forceKillDoneMsg carries the results of a force-kill.
type forceKillDoneMsg struct {
	Results []process.KillResult
}
