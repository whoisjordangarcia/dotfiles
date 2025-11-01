#!/bin/bash

# Configuration
SOURCE="/home/jordan"
DEST="/home/jordan/mounts/vault-single/backup"
LOGFILE="$HOME/.vault-backup-logs/rsync-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "$(dirname "$LOGFILE")"

# Check if destination is mounted
if ! mountpoint -q "/home/jordan/mounts/vault-single"; then
	echo "ERROR: Samba share not mounted at /home/jordan/mounts/vault-single"
	notify-send "Backup Failed" "Vault drive not mounted" 2>/dev/null
	exit 1
fi

# Rsync with good defaults
rsync -avh \
	--delete \
	--exclude='.cache/' \
	--exclude='.local/share/Trash/' \
	--exclude='*.tmp' \
	--exclude='Downloads/' \
	--exclude='.steam/' \
	--exclude='mounts/' \
	--log-file="$LOGFILE" \
	"$SOURCE/" "$DEST/" 2>&1 | tee -a "$LOGFILE"

RSYNC_EXIT=$?

# Keep only last 10 logs
ls -t "$HOME/.vault-backup-logs/"rsync-*.log 2>/dev/null | tail -n +11 | xargs -r rm

# Notification on completion
if [ $RSYNC_EXIT -eq 0 ]; then
	notify-send "Backup Complete" "Synced to vault-single" 2>/dev/null
else
	notify-send "Backup Warning" "Check logs at $LOGFILE" 2>/dev/null
fi

exit $RSYNC_EXIT
