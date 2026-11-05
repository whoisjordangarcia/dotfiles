---
name: show-html
description: Show a local HTML file or a URL live and interactive in a Rex pane, rendered by headless Chrome and drawn with the kitty graphics protocol, so the user can scroll, click and type in it from the terminal. Rex terminals only. Use when the user asks to see a page in a pane ("show this HTML", "open the page in a pane", "as a pane"). Only when asked; never open it on your own.
---

Run the script once, with the path or URL:

```bash
python3 ~/.claude/skills/show-html/scripts/show_html.py "/path/to/page.html"
python3 ~/.claude/skills/show-html/scripts/show_html.py "http://127.0.0.1:3000/"
```

The page opens in a pane to the right of yours and takes focus, so keys work straight away. `q` closes it and returns focus to your pane, unless a text field in the page has focus; Ctrl-C always closes it. Wheel, clicks, hover, arrows, PageUp/PageDown, Home/End, space, Tab, Enter and typing go to the page.

There is one viewer per agent pane: a new call closes the earlier one and replaces it. Chrome runs on a throwaway profile, removed on close. The user's own browser and profile are not touched. It needs Google Chrome, Brave, Chromium or a Playwright Chromium on macOS, and nothing else.

**Done when** the script prints `Shown in a pane:`. That line means the terminal itself confirmed the frame's upload. Any other output is a failure: tell the user what it says.

## Limits

- **No sign-in.** The profile is empty, so a page behind a login shows its login screen, and the redirect to another origin is blocked anyway. Don't try to work around it.
- **Stays on the page.** A local file stays on that file; a URL stays on its origin. Other links, redirects and new tabs are blocked and named in the footer. Downloads are refused and dialogs dismissed.
- **Soft while moving.** Measured on a 100x78 pane (1600x2418 px): 45 fps during scrolling with frames cut to about 1 megapixel, then a 1:1 sharp frame a quarter to half a second after it stops. Full-size frames only reached 15 fps, because Rex takes about 60 ms to draw each one. Smaller panes get sharper motion. Chrome uses about 1 GB.
- **Scale is fixed at launch.** Chosen from the pane's width (1.25x to 2x, aiming for a 1080 px wide layout). Resizing re-lays out the page at that scale; it does not change text size.
- **The confirmation is Rex's, not the screen's.** If the pane's window isn't on screen, Rex still confirms the upload and the pane has no pixel size yet, so the scale is chosen from a guess.
- **Scrollbars are hidden**, so they can't be dragged, and pages that overflow sideways can still be panned.
