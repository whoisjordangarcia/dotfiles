---
name: diagnose-crash
description: Read crash logs (coredumps + journal) on a Linux box — defaults to the Arch desktop `archbtw` (192.168.1.220). Use when the user says an app crashed, quit, closed unexpectedly, segfaulted, or asks "why did X die", "what crashed", "show crash logs", "any crashes", "diagnose crash", "check coredumps". Read-only.
allowed-tools: Bash(/usr/bin/ssh:*), Bash(coredumpctl:*), Bash(journalctl:*)
---

# diagnose-crash

Read-only. Never delete dumps, never change `coredump.conf`, never restart units.

## Target

Default host is the Arch desktop: `/usr/bin/ssh jordan@192.168.1.220 '<cmd>'`.
Use `/usr/bin/ssh`, not Homebrew ssh — macOS LAN TCC is per-binary and the
Homebrew one gets `EHOSTUNREACH`.

If ssh times out the box is asleep. Wake it, then poll for up to 2 min:

```bash
/usr/bin/python3 -c "
import socket
p=b'\xff'*6+bytes.fromhex('d45d64d5e7f4')*16
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1)
s.sendto(p,('192.168.1.255',9))"
```

Running on a Linux box directly? Drop the ssh wrapper, same commands.

## The three commands

Crash capture is already wired: `core_pattern` pipes to `systemd-coredump`, so
every SIGSEGV/SIGABRT/SIGILL/SIGFPE/SIGBUS on the machine is recorded with no
per-app setup. Nothing notifies you — you have to ask.

```bash
coredumpctl list --no-pager                  # everything, oldest first
coredumpctl list --since "2 days ago" -r     # recent first
coredumpctl list /usr/bin/hypridle           # one binary
coredumpctl info <PID|/path|-1>              # signal + backtrace ("-1" = latest)
```

Cores land in `/var/lib/systemd/coredump/`, vacuumed after ~3 days on defaults
(`Storage=external`, `MaxUse` unset → 10% of the fs). A dump listed as `missing`
aged out — the journal metadata survives, the core doesn't.

For crashes that leave no core (OOM kill, systemd unit failure, GPU/driver
resets), the journal is the source:

```bash
journalctl -b -p err --no-pager                        # this boot, errors up
journalctl -b -1 -p err --no-pager                     # previous boot (after a hard lockup)
journalctl --since "1 hour ago" -g 'segfault|oom|killed|Xid|reset' --no-pager
journalctl -u <unit> -p err --no-pager
systemctl --failed ; systemctl --user --failed
```

## Reading the output

1. `coredumpctl list` first — get the signal, binary, and timestamp.
2. `coredumpctl info` on the one that matches the user's complaint. The
   backtrace is usually enough to name the faulting library.
3. Only if there's no core, or the story doesn't add up, fall to `journalctl`
   around that timestamp for what led up to it.

Interpreting signals: SIGSEGV = bad pointer, usually a real bug or a bad
driver; SIGABRT = the app called `abort()` itself, so its own stderr in the
journal is more informative than the backtrace; nothing at all + gone = check
for the OOM killer.

Ignore session-teardown noise: on this box `awww-daemon`, `hypridle`,
`hyprlock`, and `start-hyprland` SIGABRT together every time the Hyprland
session cycles. Same trio + same timestamp = logout, not a crash to chase.

Backtraces need debug symbols to be readable. Arch ships them separately — if
the trace is all `??`, say so rather than guessing at frames.

## Report back

Name the binary, the signal, when, and whether it repeats. If it's a repeat,
say how often. Don't propose a fix from a `??` backtrace.
