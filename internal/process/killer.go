package process

import (
	"fmt"
	"syscall"
	"time"
)

// KillFunc sends a signal to a process. Abstracted for testability.
type KillFunc func(pid int, sig syscall.Signal) error

// DefaultKill uses syscall.Kill.
func DefaultKill(pid int, sig syscall.Signal) error {
	return syscall.Kill(pid, sig)
}

// KillResult reports the outcome of killing a process.
type KillResult struct {
	PID      int
	Killed   bool
	Survivor bool
	Err      error
}

// Kill sends SIGTERM to the given PIDs, waits briefly, then checks for survivors.
func Kill(pids []int, killFn KillFunc) []KillResult {
	results := make([]KillResult, len(pids))

	for i, pid := range pids {
		results[i].PID = pid
		err := killFn(pid, syscall.SIGTERM)
		if err != nil {
			results[i].Err = fmt.Errorf("SIGTERM pid %d: %w", pid, err)
		}
	}

	time.Sleep(500 * time.Millisecond)

	// Check which processes are still alive
	for i, pid := range pids {
		if results[i].Err != nil {
			continue
		}
		err := killFn(pid, 0) // signal 0 = alive check
		if err != nil {
			// Process is gone — success
			results[i].Killed = true
		} else {
			results[i].Survivor = true
		}
	}

	return results
}

// ForceKill sends SIGKILL to the given PIDs.
func ForceKill(pids []int, killFn KillFunc) []KillResult {
	results := make([]KillResult, len(pids))

	for i, pid := range pids {
		results[i].PID = pid
		err := killFn(pid, syscall.SIGKILL)
		if err != nil {
			results[i].Err = fmt.Errorf("SIGKILL pid %d: %w", pid, err)
		} else {
			results[i].Killed = true
		}
	}

	return results
}

// Survivors returns the PIDs that survived a Kill operation.
func Survivors(results []KillResult) []int {
	var pids []int
	for _, r := range results {
		if r.Survivor {
			pids = append(pids, r.PID)
		}
	}
	return pids
}
