package process

import (
	"fmt"
	"syscall"
	"testing"
)

func TestKill_AllDie(t *testing.T) {
	killed := map[int]bool{}
	mockKill := func(pid int, sig syscall.Signal) error {
		if sig == syscall.SIGTERM {
			killed[pid] = true
			return nil
		}
		if sig == 0 {
			// Process is dead after SIGTERM
			if killed[pid] {
				return fmt.Errorf("no such process")
			}
			return nil
		}
		return nil
	}

	results := Kill([]int{100, 200, 300}, mockKill)

	for _, r := range results {
		if !r.Killed {
			t.Errorf("pid %d should be killed", r.PID)
		}
		if r.Survivor {
			t.Errorf("pid %d should not be survivor", r.PID)
		}
	}
}

func TestKill_WithSurvivors(t *testing.T) {
	stubbornPID := 200
	mockKill := func(pid int, sig syscall.Signal) error {
		if sig == syscall.SIGTERM {
			return nil
		}
		if sig == 0 {
			if pid == stubbornPID {
				return nil // still alive
			}
			return fmt.Errorf("no such process")
		}
		return nil
	}

	results := Kill([]int{100, 200, 300}, mockKill)

	survivors := Survivors(results)
	if len(survivors) != 1 || survivors[0] != 200 {
		t.Errorf("survivors = %v, want [200]", survivors)
	}
}

func TestForceKill(t *testing.T) {
	var sigkilled []int
	mockKill := func(pid int, sig syscall.Signal) error {
		if sig == syscall.SIGKILL {
			sigkilled = append(sigkilled, pid)
			return nil
		}
		return nil
	}

	results := ForceKill([]int{100, 200}, mockKill)

	if len(sigkilled) != 2 {
		t.Errorf("expected 2 SIGKILLs, got %d", len(sigkilled))
	}
	for _, r := range results {
		if !r.Killed {
			t.Errorf("pid %d should be killed", r.PID)
		}
	}
}

func TestKill_TermError(t *testing.T) {
	mockKill := func(pid int, sig syscall.Signal) error {
		if sig == syscall.SIGTERM {
			return fmt.Errorf("operation not permitted")
		}
		return nil
	}

	results := Kill([]int{100}, mockKill)

	if results[0].Err == nil {
		t.Error("expected error for failed SIGTERM")
	}
	if results[0].Killed || results[0].Survivor {
		t.Error("should neither be killed nor survivor on SIGTERM error")
	}
}
