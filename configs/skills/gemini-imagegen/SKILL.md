---
name: gemini-imagegen
description: Use when generating or editing images with the Gemini API in JavaScript/Node.js (Nano Banana Pro). Triggers on text-to-image, image editing, style transfer, logo/text-in-image generation, stickers, product mockups, multi-image composition, or iterative refinement. Requires GEMINI_API_KEY env var.
---

# Gemini Image Generation (JavaScript / Nano Banana Pro)

Generate and edit images using Google's Gemini API from Node.js. The environment variable `GEMINI_API_KEY` must be set — `new GoogleGenAI({})` reads it automatically.

## Quickest Path: Use the Bundled CLI

The skill ships with a self-contained Node CLI at `~/.claude/skills/gemini-imagegen/cli.js` and the `@google/genai` SDK already installed in `node_modules/`. **Prefer this over writing fresh scripts** — it handles model fallback, cost estimation, mime-correct file extensions, and auto-opens the result.

```bash
# Basic
node ~/.claude/skills/gemini-imagegen/cli.js "a cat astronaut, oil painting"

# With aspect ratio + size
node ~/.claude/skills/gemini-imagegen/cli.js "wide cinematic landscape" -a 16:9 -s 2K

# Edit an image
node ~/.claude/skills/gemini-imagegen/cli.js "add a sunset" -i ./photo.jpg -o photo-sunset

# Multi-image composition (extension is auto-derived from mimeType)
node ~/.claude/skills/gemini-imagegen/cli.js "office group photo" -i a.jpg -i b.jpg -i c.jpg

# Multiple variations
node ~/.claude/skills/gemini-imagegen/cli.js "logo for Acme Corp" -n 4 -o acme-logo

# Skip auto-open
node ~/.claude/skills/gemini-imagegen/cli.js "test" --no-open

# How to check Gemini credit / quota balance
node ~/.claude/skills/gemini-imagegen/cli.js --balance

# Full help
node ~/.claude/skills/gemini-imagegen/cli.js --help
```

CLI behaviour:
- Saves to `~/Desktop/gemini-imagegen/` (created if missing).
- File extension is **derived from `inlineData.mimeType`** — never mismatches actual bytes.
- Auto-opens the image (macOS `open`, Linux `xdg-open`, Windows `start`). Disable with `--no-open`.
- Falls back through `gemini-3-pro-image-preview` → `gemini-3.1-flash-image-preview` → `gemini-2.5-flash-image` on 503/429/500.
- Prints estimated cost and token usage per call.

## Cost & Credit Balance

**Per-call cost** is estimated live from `response.usageMetadata` and a static price table inside `cli.js` (the `PRICING` map). Update it if Google changes rates.

**There is no public Gemini API for credit balance.** `cli.js --balance` prints links to the right console:
- Free tier (AI Studio quota): https://aistudio.google.com/apikey
- Paid tier billing: https://console.cloud.google.com/billing
- Live usage: https://aistudio.google.com/usage

## Install (only if writing your own script)

The SDK is already installed in the skill folder. If you write a new project elsewhere:

```bash
npm install @google/genai
```

## Output Directory

CLI default is `~/Desktop/gemini-imagegen/`. If writing your own script, follow the same convention:

```js
import * as os from "node:os";
import * as path from "node:path";
import * as fs from "node:fs";

const OUT_DIR = path.join(os.homedir(), "Desktop", "gemini-imagegen");
fs.mkdirSync(OUT_DIR, { recursive: true });
```

## Default Model

| Model | Resolution | Best For |
|-------|------------|----------|
| `gemini-3-pro-image-preview` | 1K-4K | All image generation (default) |

**Note:** Always use this Pro model. Only use a different model if explicitly requested (e.g. `gemini-3.1-flash-image-preview` for speed, `gemini-2.5-flash-image` for legacy/cheap).

## Quick Reference

### Defaults
- **Model:** `gemini-3-pro-image-preview`
- **Resolution:** `1K` (options: `1K`, `2K`, `4K`)
- **Aspect ratio:** `1:1`

### Aspect Ratios
`1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`

### Response Shape
```js
response.candidates[0].content.parts // Array of:
//   { text: "..." }                  // optional caption/text
//   { inlineData: { mimeType, data } } // base64-encoded image
```

## Core Pattern — Text to Image

```js
import { GoogleGenAI } from "@google/genai";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const OUT_DIR = path.join(os.homedir(), "Desktop", "gemini-imagegen");
fs.mkdirSync(OUT_DIR, { recursive: true });

const ai = new GoogleGenAI({}); // reads GEMINI_API_KEY

const response = await ai.models.generateContent({
  model: "gemini-3-pro-image-preview",
  contents: "A photorealistic nano banana dish in a fancy restaurant, Gemini constellation theme",
  config: {
    responseModalities: ["TEXT", "IMAGE"],
  },
});

for (const part of response.candidates[0].content.parts) {
  if (part.text) {
    console.log(part.text);
  } else if (part.inlineData) {
    const buffer = Buffer.from(part.inlineData.data, "base64");
    const outPath = path.join(OUT_DIR, `output-${Date.now()}.jpg`);
    fs.writeFileSync(outPath, buffer); // see "File Format" warning below
    console.log("Saved:", outPath);
  }
}
```

## Custom Resolution & Aspect Ratio

```js
const response = await ai.models.generateContent({
  model: "gemini-3-pro-image-preview",
  contents: prompt,
  config: {
    responseModalities: ["TEXT", "IMAGE"],
    imageConfig: {
      aspectRatio: "16:9", // wide
      imageSize: "2K",     // 1K | 2K | 4K
    },
  },
});
```

## Editing an Existing Image

Pass the image as an `inlineData` part alongside the text instruction:

```js
import * as fs from "node:fs";

const base64Image = fs.readFileSync("input.jpg").toString("base64");

const response = await ai.models.generateContent({
  model: "gemini-3-pro-image-preview",
  contents: [
    { text: "Add a sunset to this scene, keep the subject unchanged" },
    { inlineData: { mimeType: "image/jpeg", data: base64Image } },
  ],
  config: { responseModalities: ["TEXT", "IMAGE"] },
});
```

## Multi-Image Composition (up to 14 references)

```js
const refs = ["person1.jpg", "person2.jpg", "person3.jpg"].map((p) => ({
  inlineData: {
    mimeType: "image/jpeg",
    data: fs.readFileSync(p).toString("base64"),
  },
}));

const response = await ai.models.generateContent({
  model: "gemini-3-pro-image-preview",
  contents: [
    { text: "An office group photo of these people making funny faces" },
    ...refs,
  ],
  config: {
    responseModalities: ["TEXT", "IMAGE"],
    imageConfig: { aspectRatio: "5:4", imageSize: "2K" },
  },
});
```

## Multi-Turn Refinement (chat)

Use a chat session to iteratively refine the same image:

```js
const chat = ai.chats.create({
  model: "gemini-3-pro-image-preview",
  config: { responseModalities: ["TEXT", "IMAGE"] },
});

let res = await chat.sendMessage({ message: "Create a logo for 'Acme Corp'" });
saveImageParts(res, path.join(OUT_DIR, "logo-v1.jpg"));

res = await chat.sendMessage({ message: "Make the text bolder, add a blue gradient" });
saveImageParts(res, path.join(OUT_DIR, "logo-v2.jpg"));

function saveImageParts(res, outPath) {
  for (const part of res.candidates[0].content.parts) {
    if (part.inlineData) {
      fs.writeFileSync(outPath, Buffer.from(part.inlineData.data, "base64"));
    }
  }
}
```

## Google Search Grounding

Generate images based on real-time data:

```js
const response = await ai.models.generateContent({
  model: "gemini-3-pro-image-preview",
  contents: "Visualize today's weather in Tokyo as an infographic",
  config: {
    responseModalities: ["TEXT", "IMAGE"],
    tools: [{ googleSearch: {} }],
  },
});
```

Note: image-only mode (`responseModalities: ["IMAGE"]`) is **incompatible** with Google Search grounding — keep `TEXT` in the modalities list.

## Prompting Best Practices

- **Photorealistic:** include camera details — *"85mm lens, soft golden hour light, shallow depth of field"*
- **Stylized:** name the style — *"kawaii sticker, bold outlines, cel-shading, white background"*
- **Text in images:** specify font + placement — *"clean sans-serif text 'Daily Grind', centered, black on white"*
- **Product mockups:** describe lighting — *"three-point softbox, 45° angle, polished concrete surface"*
- **Editing:** describe the change conversationally; the model handles semantic masking

## File Format — Trust the mimeType Field

`inlineData.mimeType` is reliable: derive the extension from it instead of guessing. Verified 2026-05-06: `gemini-2.5-flash-image` returned PNG bytes with `mimeType: "image/png"`, matching what `file(1)` reported.

```js
const mime = part.inlineData.mimeType || "image/png";
const ext = mime === "image/jpeg" ? ".jpg"
          : mime === "image/webp" ? ".webp"
          : mime === "image/gif"  ? ".gif"
          : ".png";
fs.writeFileSync(`output${ext}`, Buffer.from(part.inlineData.data, "base64"));
```

The bundled `cli.js` does this automatically — pass `-o name` (no extension) and it'll append the right one.

To force a specific format, decode and re-encode via `sharp`:

```js
import sharp from "sharp";
await sharp(buffer).jpeg().toFile("output.jpg");
```

## Limits & Notes

- All generated images include a **SynthID watermark**
- Gemini 3 Pro: up to **14 input images**, 5 with high-fidelity character consistency
- Gemini 3.1 Flash: up to 10 objects, 4 characters consistency
- Gemini 2.5 Flash: max 3 input images
- Default to `1K` for speed; use `2K`/`4K` when quality matters
- Returned `inlineData.data` is **base64** — always `Buffer.from(data, "base64")` before writing

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Writing `inlineData.data` to disk directly | It's base64 — decode with `Buffer.from(data, "base64")` first |
| Hardcoding `.jpg` or `.png` extension | Derive extension from `inlineData.mimeType` instead |
| Using `["IMAGE"]` with `googleSearch` | Tools require `TEXT` in `responseModalities` |
| Hardcoding API key | Rely on `GEMINI_API_KEY` env var; `new GoogleGenAI({})` picks it up |
| Old SDK (`@google/generative-ai`) | Use `@google/genai` — the new unified SDK |
