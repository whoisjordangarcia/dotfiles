#!/usr/bin/env bash
# Opens today's Obsidian daily note in $EDITOR.
# If no note exists for today, creates one from template.

VAULT="$HOME/dev/notes"
DAILY_DIR="$VAULT/03 - Daily Notes"
TODAY=$(date +%Y-%m-%d)
EDITOR="${EDITOR:-nvim}"

# Find existing note for today (may have a title suffix)
existing=$(find "$DAILY_DIR" -maxdepth 1 -name "${TODAY}*" -type f | head -1)

if [ -n "$existing" ]; then
  exec "$EDITOR" "$existing"
else
  # Create a new daily note with the standard template
  note="$DAILY_DIR/${TODAY}.md"
  cat > "$note" << 'EOF'
# Daily Note

## Notes

---

## Tasks

- [ ] Initial
EOF
  exec "$EDITOR" "$note"
fi
