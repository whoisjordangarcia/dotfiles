---
name: show-image
description: Show an image file to the user in a Rex side pane, drawn with the kitty graphics protocol and scaled to the pane. Use in a Rex terminal when the user wants to see a screenshot you captured, an image you generated, or any image on disk ("show me", "let me see", "open that screenshot").
---

Capture screenshots at 2x, as PNG. An image can't gain detail after capture, and this shell defaults to JPEG, so name the format:

```bash
agent-browser --session shot set viewport 1100 800 2   # width height deviceScaleFactor; before open
agent-browser --session shot open "$URL"
agent-browser --session shot screenshot --full --screenshot-format png /path/to/screenshot.png
agent-browser --session shot close
```

Then run the script once per image, with the path you already have:

```bash
python3 ~/.claude/skills/show-image/scripts/show_image.py "/path/to/screenshot.png"
```

**Only open it when the user asked to see an image.** It takes the keyboard: typing goes to the viewer until they press `q`, which returns focus to your pane, or click away. Don't use it for screenshots you take for your own checking.

The image opens in a pane to the right of yours. It fits the pane and follows resizes, and never goes past one image pixel to one device pixel, so a low-resolution image shows smaller rather than stretched.

An image more than twice the pane's height at full width (a full-page capture, usually) fills the pane's width and height, stretching if it has to, and scrolls. `j`/`k` move a third of a pane, space/`b` and PageDown/PageUp 90%, `g`/`G` go to the ends, and the wheel works too. Scrolling is eased. Images at least three times taller than wide lose their blank side margins, and any short block past a blank gutter, such as a fixed sidebar in a full-page capture's first screen.

Tall images are split into tiles and every pixel kept. Other formats are converted with `sips`, and images too big for Rex's image memory, or over 10000 pixels wide, are shrunk.

There is one viewer per agent pane: a new call closes the earlier one and replaces it.

**Done when** the script prints `Shown in a pane:`. That line means the terminal itself confirmed the upload. Any other output is a failure: tell the user what it says.
