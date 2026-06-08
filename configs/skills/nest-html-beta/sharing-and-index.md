# Sharing and Docs Index

Use when uploading generated docs/decks to S3 or refreshing the Nest docs landing page.

## Sharing via S3 (optional)

After writing the file, ask: *"Want me to upload this to S3 (`yoda-app-origin-tst/nest-docs/`) so you can share it with the team?"*

If yes, capture the uploader's email from `git config user.email` first, then upload with that as object metadata:

```bash
UPLOADER=$(git config user.email)
aws s3 cp <local-path> s3://yoda-app-origin-tst/nest-docs/<filename>.html \
  --profile tst-account-administrator-role \
  --content-type "text/html; charset=utf-8" \
  --metadata "uploaded-by=$UPLOADER" \
  --cache-control "no-cache"
```

The `uploaded-by` metadata is what the docs index reads to attribute each row to its uploader. Without it, the index shows "—" for that row.

**Never back-fill `uploaded-by` metadata on existing files you didn't just upload.** If a row in the index shows "—", that means the file was uploaded before this convention OR by a tool that didn't set the metadata — both cases mean the real uploader is unknown. Do not stamp it with the current user's email or any guessed value: that's writing attribution you can't verify, and it pollutes the team's source-of-truth for who shipped what. If accurate historical attribution is needed, look at CloudTrail (`aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=<key>`) for whatever is still in retention. Otherwise leave it as "—".

- Bucket: `yoda-app-origin-tst`
- Key prefix: `nest-docs/`
- AWS profile: **`tst-account-administrator-role`** (as defined in `~/.aws/config` under `[profile tst-account-administrator-role]`)
- Use the same filename as the local file unless the user specifies a different key.
- If the object already exists, `aws s3 cp` will overwrite it — that's the "update" path; confirm with the user first if the filename looks generic (e.g. `summary.html`).
- **Always pass `--cache-control "no-cache"`** so CloudFront and browsers revalidate via ETag on every request. Without it, updates can take hours to appear (CloudFront default TTL + browser heuristic caching). With it, re-uploads are picked up immediately and no CloudFront invalidation is needed.

If the SSO session has expired, the upload will fail with `The SSO session associated with this profile has expired`. Ask the user to run `aws sso login --profile tst-account-administrator-role` (this is interactive — they need to do it themselves), then retry the `aws s3 cp`.

### Sharing the URL

After a successful upload, report the URL:

```
https://tst.yoda.nestgenomics.com/nest-docs/<filename>.html
```

- CloudFront caches responses at the edge, but the `--cache-control "no-cache"` header above forces revalidation on every request, so updates appear immediately without needing a CloudFront invalidation. (If a file was uploaded *without* the `no-cache` header in the past, a one-time `aws cloudfront create-invalidation --distribution-id E3NT3KZTMT0HA1 --paths "/nest-docs/<filename>.html" --profile tst-account-administrator-role` will clear the stale entry.)
- Do not use the raw `https://yoda-app-origin-tst.s3.amazonaws.com/...` URL — that endpoint will 403 since the bucket itself is private.

## Regenerating the docs index (every upload)

After every successful upload, regenerate `s3://yoda-app-origin-tst/nest-docs/index.html` so the docs landing page (`https://tst.yoda.nestgenomics.com/nest-docs/`) lists the most recent docs with the file just uploaded at the top. This is automatic — do not ask the user; it's part of the upload step.

### 1. List the most recent 50 HTML docs

```bash
aws s3api list-objects-v2 \
  --bucket yoda-app-origin-tst \
  --prefix nest-docs/ \
  --profile tst-account-administrator-role \
  --query "reverse(sort_by(Contents[?Key!='nest-docs/index.html' && ends_with(Key, '.html')], &LastModified))[:50].{Key:Key,LastModified:LastModified,Size:Size}" \
  --output json
```

The query:
- Filters to `.html` files only (skips images, PDFs, etc. if those ever land in the prefix).
- Excludes `index.html` itself so the index doesn't list itself recursively.
- Sorts by `LastModified` descending so the most-recent doc is first.
- Caps at 50 entries — older docs fall off the index but remain accessible by direct URL.

### 1b. Fetch uploader metadata for each file

`list-objects-v2` does not return per-object metadata, so for each key from step 1 fetch its `uploaded-by` metadata via `head-object`. Run these in parallel — 50 sequential HEAD requests is slow, but parallelized they finish in well under a second.

```bash
# For each key, in parallel:
aws s3api head-object \
  --bucket yoda-app-origin-tst \
  --key "<key>" \
  --profile tst-account-administrator-role \
  --query 'Metadata."uploaded-by"' \
  --output text
```

Output is the email if present, or `None` if the key was uploaded before the metadata convention. Render `None` as `—` (em-dash, dimmed) in the index. For the email, show only the local part (`jordan@nestgenomics.com` → `jordan`) to keep rows compact — full email is recoverable from S3 if needed.

### 2. Render `index.html` from `index-template.html`

Read `index-template.html` from this skill directory (a dedicated index template, separate from `template.html` used for individual docs). It has three placeholders:

| Placeholder | Fill with |
|---|---|
| `{{COUNT}}` | The number of rows being rendered (e.g. `15`). |
| `{{REGEN_DATE}}` | Today's date in `YYYY-MM-DD`. |
| `{{ROWS}}` | The HTML for all `<li>` rows, concatenated. |

The template already includes:
- The full Nest brand stylesheet (themes, modes, widths, settings panel).
- A "Latest" pill auto-applied to the first row via CSS `:first-child::before`.
- Client-side JS that computes relative time from `data-date="YYYY-MM-DD"` (so "3 days ago" stays accurate even when CloudFront serves a stale cached copy).
- The Tailscale-restricted footer.

The listing HTML must be a single `<ul class="docs-list">` with one `<li>` per file (the template's CSS only styles `<li>` rows — don't substitute a `<table>` or other structure).

**Safety: escape every value before substituting it into the row markup.** S3 keys and `uploaded-by` metadata can legally contain spaces, quotes, `<`, `>`, `&`, `#`, or other markup-like characters. If those land in `{{ROWS}}` un-escaped, you get broken links at best and stored XSS at worst (the index is served from the Tailscale-restricted CloudFront origin, but Tailscale is a perimeter, not a sanitizer — anyone who can write to `nest-docs/` can poison the index for everyone who reads it).

- **HTML-escape** the displayed title text and the uploader's local part. Replace `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&#39;`. Apply this BEFORE inserting the value between tags or into attribute values.
- **URL-encode** the relative `href` (the filename). Use `encodeURIComponent` (or equivalent) on the filename component, joined with `/`-separated path segments. A file named `meeting notes.html` becomes `href="meeting%20notes.html"`.

Concrete escaped row (filename `nes-4326 plan.html` with uploader `jordan@nestgenomics.com`):

```html
<li>
  <a href="nes-4326%20plan.html">NES-4326 plan</a>
  <span class="doc-meta">
    <span class="meta-row"><span class="uploader">jordan</span> &middot; 46 KB</span>
    <span class="meta-row">2026-05-01</span>
    <span class="meta-row dim" data-date="2026-05-01"></span>
  </span>
</li>
```

For each entry:

- **Filename without `.html`**, slugged into a human title (e.g. `nes-4326-plan` → `NES-4326 plan`). Keep it simple — the `<a>` text is the basename with hyphens replaced by spaces and obvious ticket prefixes uppercased.
- **`href`** = `<filename>` (relative to the index, since the index lives in the same prefix).
- **Last modified date** in a `<span class="meta">` next to the link, formatted `YYYY-MM-DD`.

Each row shows three pieces of metadata stacked in a right-aligned block:

1. **uploader · size** on line 1 — uploader is the local part of `uploaded-by` (e.g. `jordan@nestgenomics.com` → `jordan`) or an em-dash if absent. Size is the `Size` from `list-objects-v2` rounded to the nearest KB (`Math.round(bytes / 1024)`).
2. **ISO date** on line 2 (`YYYY-MM-DD`) — the absolute timestamp.
3. **Relative time** on line 3 — populated by the template's JS from `data-date="YYYY-MM-DD"`. The skill emits an empty `<span>` with the data attribute; the browser fills in `today`, `3 days ago`, `2 weeks ago`, etc. on page load.

Example list item:

```html
<li>
  <a href="nes-4326-plan.html">NES-4326 plan</a>
  <span class="doc-meta">
    <span class="meta-row"><span class="uploader">jordan</span> &middot; 46 KB</span>
    <span class="meta-row">2026-05-01</span>
    <span class="meta-row dim" data-date="2026-05-01"></span>
  </span>
</li>
```

Entries with no `uploaded-by` metadata (legacy uploads or files written by tools that didn't set the metadata — these stay as `—`, never back-filled with a guess):

```html
<span class="meta-row"><span class="dim">&mdash;</span> &middot; 88 KB</span>
```

All listing CSS (rows, "Latest" pill, uploader styling) is already in `index-template.html`. Don't add CSS in `{{ROWS}}` — just emit the `<li>` markup and the template handles the rest.

### 3. Upload the regenerated index

```bash
aws s3 cp <local-index-path> s3://yoda-app-origin-tst/nest-docs/index.html \
  --profile tst-account-administrator-role \
  --content-type "text/html; charset=utf-8"
```

Save the local index to `~/Desktop/nest-docs-index.html` (or a temp path) — it's regenerated on every upload, so it doesn't need a permanent local home.

### 4. Tell the user

After both uploads succeed, report:

- The direct URL to the new doc.
- That the docs index has been refreshed at `https://tst.yoda.nestgenomics.com/nest-docs/`.
- A reminder that CloudFront caches `index.html` for ~5 minutes (per the `default_ttl` on the `nest-docs/*` cache behavior), so the new entry may take a few minutes to appear.

If only the index needs to be regenerated (e.g. after a manual `aws s3 cp` that bypassed the skill), the user can ask "regenerate the docs index" and the skill should run steps 1–4 without uploading a new doc.
