#!/bin/bash
# Open today's daily note in a floating popup
# Finds an existing note for today or creates a new one from template

VAULT="${OBSIDIAN_VAULT:-$HOME/dev/notes}"
NOTES_DIR="$VAULT/03 - Daily Notes"
TODAY=$(date +%Y-%m-%d)
EDITOR="${EDITOR:-nvim}"

# Find an existing note for today (any title suffix)
existing=$(find "$NOTES_DIR" -maxdepth 1 -name "${TODAY}*.md" 2>/dev/null | sort | head -1)

if [ -n "$existing" ]; then
    "$EDITOR" "$existing"
else
    # Create new plain daily note
    new_note="$NOTES_DIR/${TODAY}.md"
    cat > "$new_note" << 'TEMPLATE'
## Notes

---

## Tasks

- [ ] Initial
TEMPLATE
    "$EDITOR" "$new_note"
fi
