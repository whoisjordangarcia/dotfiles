#!/usr/bin/env node
import { GoogleGenAI } from "@google/genai";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { parseArgs } from "node:util";
import { spawn } from "node:child_process";

const OUT_DIR = path.join(os.homedir(), "Desktop", "gemini-imagegen");

const HELP = `gemini-imagegen — generate or edit images via Gemini API

Usage:
  node ~/.claude/skills/gemini-imagegen/cli.js "<prompt>" [options]
  node ~/.claude/skills/gemini-imagegen/cli.js --balance

Options:
  -o, --out <name>        Output filename (default: timestamped). Saved under ~/Desktop/gemini-imagegen/
  -a, --aspect <ratio>    1:1, 16:9, 9:16, 4:3, 3:4, 5:4, 4:5, 21:9, 2:3, 3:2 (default: 1:1)
  -s, --size <res>        1K | 2K | 4K (default: 1K)
  -m, --model <id>        Model id. Default: gemini-3-pro-image-preview. Falls back to flash on 503.
  -i, --image <path>      Input image (repeat for editing/composition; up to 14)
  -g, --grounding         Enable Google Search grounding
  -n, --count <n>         Number of generations (sequential, default: 1)
  --balance               Show how to view Gemini credit balance (no API exposes it)
  -h, --help              Show this help

Env:
  GEMINI_API_KEY          Required.

Examples:
  cli.js "a cat astronaut, oil painting" -a 16:9 -s 2K
  cli.js "add a sunset" -i ./photo.jpg -o photo-sunset.jpg
  cli.js "group photo" -i a.jpg -i b.jpg -i c.jpg
`;

// Estimated pricing (USD). Image output is billed as tokens against the
// model's output token rate. Update if Google changes rates.
// Sources: ai.google.dev/pricing (paid tier).
const PRICING = {
  // $/1M output tokens, image-token cost per generated image at given size
  "gemini-3-pro-image-preview":     { perImage: { "1K": 0.134, "2K": 0.134, "4K": 0.24 } },
  "gemini-3.1-flash-image-preview": { perImage: { "1K": 0.039, "2K": 0.039, "4K": 0.078 } },
  "gemini-2.5-flash-image":         { perImage: { "1K": 0.039, "2K": 0.039 } },
};

function estimateCost(model, size, imagesProduced, usageMetadata) {
  const card = PRICING[model];
  if (!card) return null;
  const per = card.perImage[size] ?? card.perImage["1K"];
  return {
    perImage: per,
    images: imagesProduced,
    estimateUSD: +(per * imagesProduced).toFixed(4),
    promptTokens: usageMetadata?.promptTokenCount,
    candidatesTokens: usageMetadata?.candidatesTokenCount,
    totalTokens: usageMetadata?.totalTokenCount,
  };
}

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    out: { type: "string", short: "o" },
    aspect: { type: "string", short: "a", default: "1:1" },
    size: { type: "string", short: "s", default: "1K" },
    model: { type: "string", short: "m", default: "gemini-3-pro-image-preview" },
    image: { type: "string", short: "i", multiple: true, default: [] },
    grounding: { type: "boolean", short: "g", default: false },
    count: { type: "string", short: "n", default: "1" },
    balance: { type: "boolean", default: false },
    open: { type: "boolean", default: true },
    "no-open": { type: "boolean", default: false },
    help: { type: "boolean", short: "h", default: false },
  },
});

if (values.balance) {
  console.log(`Gemini credit / quota balance
─────────────────────────────────────────────
There is NO public Gemini API endpoint that returns your credit balance.
Check it directly in the relevant console:

  • Free tier (AI Studio quota):
      https://aistudio.google.com/apikey

  • Paid tier (Google Cloud billing & spend):
      https://console.cloud.google.com/billing

  • Per-model rate limits & current usage (AI Studio):
      https://aistudio.google.com/usage

This CLI estimates per-call cost from response.usageMetadata + a static
price table — see the PRICING map at the top of cli.js.`);
  process.exit(0);
}

if (values.help || positionals.length === 0) {
  console.log(HELP);
  process.exit(values.help ? 0 : 1);
}

if (!process.env.GEMINI_API_KEY) {
  console.error("ERROR: GEMINI_API_KEY is not set in the environment.");
  process.exit(2);
}

const prompt = positionals.join(" ");
const count = Math.max(1, parseInt(values.count, 10) || 1);
fs.mkdirSync(OUT_DIR, { recursive: true });

const ai = new GoogleGenAI({});

function mimeFor(p) {
  const ext = path.extname(p).toLowerCase();
  if (ext === ".png") return "image/png";
  if (ext === ".webp") return "image/webp";
  if (ext === ".gif") return "image/gif";
  return "image/jpeg";
}

const imageParts = values.image.map((p) => ({
  inlineData: {
    mimeType: mimeFor(p),
    data: fs.readFileSync(p).toString("base64"),
  },
}));

const contents = imageParts.length
  ? [{ text: prompt }, ...imageParts]
  : prompt;

const config = {
  responseModalities: ["TEXT", "IMAGE"],
  imageConfig: { aspectRatio: values.aspect, imageSize: values.size },
};
if (values.grounding) config.tools = [{ googleSearch: {} }];

const fallbackChain = [
  values.model,
  "gemini-3.1-flash-image-preview",
  "gemini-2.5-flash-image",
];

async function generateOnce(seq) {
  let response;
  let usedModel;
  for (const m of fallbackChain) {
    try {
      console.log(`[${seq}] requesting ${m}...`);
      response = await ai.models.generateContent({ model: m, contents, config });
      usedModel = m;
      break;
    } catch (e) {
      const status = e.status || e?.error?.code;
      console.log(`  ${m} failed (${status || "?"}): ${(e.message || "").slice(0, 140)}`);
      if (status && status !== 503 && status !== 429 && status !== 500) throw e;
      await new Promise((r) => setTimeout(r, 1500));
    }
  }
  if (!response) throw new Error("All models exhausted.");

  let saved = 0;
  for (const part of response.candidates[0].content.parts) {
    if (part.text) {
      console.log(`  caption: ${part.text.slice(0, 200)}`);
    } else if (part.inlineData) {
      const buffer = Buffer.from(part.inlineData.data, "base64");
      const stamp = Date.now();
      // Derive the extension from the actual mimeType so the file is honest.
      const mime = part.inlineData.mimeType || "image/png";
      const ext = mime === "image/jpeg" ? ".jpg"
                : mime === "image/webp" ? ".webp"
                : mime === "image/gif"  ? ".gif"
                : ".png";
      const userBase = values.out ? path.parse(values.out).name : null;
      const base = userBase
        ? (count > 1 ? `${userBase}-${seq}${ext}` : `${userBase}${ext}`)
        : `gen-${stamp}-${seq}${ext}`;
      const outPath = path.isAbsolute(base) ? base : path.join(OUT_DIR, base);
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, buffer);
      console.log(`  saved: ${outPath}  (${buffer.length} bytes, mime=${mime}, model=${usedModel})`);
      saved++;
      if (values.open && !values["no-open"]) {
        const opener = process.platform === "darwin" ? "open"
                     : process.platform === "win32" ? "start"
                     : "xdg-open";
        spawn(opener, [outPath], { detached: true, stdio: "ignore" }).unref();
      }
    }
  }
  if (saved === 0) console.warn(`  WARN: no image parts returned by ${usedModel}`);

  const cost = estimateCost(usedModel, values.size, saved, response.usageMetadata);
  if (cost) {
    console.log(
      `  cost: ~$${cost.estimateUSD} ` +
      `(${saved}× @ $${cost.perImage}/img on ${usedModel} ${values.size}) | ` +
      `tokens: prompt=${cost.promptTokens ?? "?"} out=${cost.candidatesTokens ?? "?"} total=${cost.totalTokens ?? "?"}`
    );
  } else {
    console.log(`  cost: unknown (no price entry for ${usedModel}); usage=${JSON.stringify(response.usageMetadata)}`);
  }
  return { saved, costUSD: cost?.estimateUSD ?? 0 };
}

let totalImages = 0;
let totalCost = 0;
for (let i = 1; i <= count; i++) {
  const { saved, costUSD } = await generateOnce(i);
  totalImages += saved;
  totalCost += costUSD;
}
console.log(
  `Done. ${totalImages} image(s) saved to ${OUT_DIR}. ` +
  `Estimated total: ~$${totalCost.toFixed(4)} ` +
  `(run with --balance for how to check actual credit).`
);
