#!/bin/sh
# Restart mpd whenever the macOS default audio output device changes, so its
# CoreAudio stream re-opens on the new device.
#
# Why restart instead of `mpc disable CoreAudio && mpc enable CoreAudio` (which
# the mpd.conf comment suggests): verified 2026-07-27 that close/reopen does NOT
# clear a wedged CoreAudio output. The output went back to `is enabled` and
# stayed silent; only a full mpd restart recovered it.
#
# The wedge is invisible from `mpc status` because the cava FIFO output keeps
# draining PCM, so the transport clock advances and state stays [playing] with
# nothing audible. To check by hand: `mpc disable 2`, watch the clock for 5s,
# `mpc enable 2` — a frozen clock or a flip to [paused] means CoreAudio is dead.
#
# ponytail: 2s poll. SwitchAudioSource has no watch mode, and a real
# kAudioHardwarePropertyDefaultOutputDevice listener needs a compiled helper.
# Swap in that helper only if 2s of wrong-device audio ever actually annoys.

SAS=/opt/homebrew/bin/SwitchAudioSource
MPC=/opt/homebrew/bin/mpc
MPD=/opt/homebrew/bin/mpd
CONF="$HOME/.config/mpd/mpd.conf"

# Without this the loop would poll a missing binary forever, `continue`-ing on an
# empty $cur with two empty log files — a KeepAlive daemon busy doing nothing.
# Exiting non-zero puts the reason in the log and lets launchd throttle it.
[ -x "$SAS" ] || {
	echo "SwitchAudioSource not found at $SAS — install switchaudio-osx"
	exit 1
}

last=$("$SAS" -c -t output 2>/dev/null)

while sleep 2; do
	cur=$("$SAS" -c -t output 2>/dev/null)
	[ -n "$cur" ] || continue
	[ "$cur" != "$last" ] || continue

	# Record the new device before acting. If the restart below fails we do not
	# want to retry it every 2s for as long as the device stays selected.
	last="$cur"

	# Nothing to re-point if mpd isn't running — the rmpc() wrapper starts it.
	pgrep -x mpd >/dev/null 2>&1 || continue

	echo "$(date '+%Y-%m-%d %H:%M:%S') default output -> $cur, restarting mpd"

	# grep -c always prints a count, even if mpc is missing, so the -eq test
	# below can never blow up on an empty string.
	was_playing=$("$MPC" status 2>/dev/null | grep -c '^\[playing\]')

	# Bounded waits, not a fixed `sleep 1`. A *wedged* mpd — the whole reason
	# this script exists — may not die promptly on SIGTERM, and the music dir is
	# an SMB mount that can be slow to reopen. Since `last` was already updated
	# above, a silent failure here leaves mpd down forever, so say so out loud.
	pkill -x mpd
	n=0
	while pgrep -x mpd >/dev/null 2>&1 && [ "$n" -lt 25 ]; do
		n=$((n + 1))
		sleep 0.2
	done

	"$MPD" "$CONF" || {
		echo "  mpd failed to restart — leaving it down"
		continue
	}

	n=0
	while ! "$MPC" status >/dev/null 2>&1 && [ "$n" -lt 25 ]; do
		n=$((n + 1))
		sleep 0.2
	done

	# mpd restores the queue and position from state_file but comes back paused,
	# so resume only if we interrupted actual playback.
	if [ "$was_playing" -eq 1 ]; then
		"$MPC" -q play || echo "  mpd is up but resume failed"
	fi
done
