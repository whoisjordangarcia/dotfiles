# Sharing and Docs Index

Use when uploading/updating/deleting generated docs/decks on the Nest docs site.

## Sharing via the docs API (optional)

**Always use this docs API path first** — for everyone, engineers included. It is
the only path non-engineers have, and the only one that regenerates the index
server-side. Engineers may fall back to the AWS CLI (see **Engineer fallback**
below) **only** if the docs API is unavailable.

Docs are managed through tst-only **client-api GraphQL mutations**
(`uploadNestDoc` / `deleteNestDoc`) at `$NEST_DOCS_API_BASE/graphql`,
authenticated with a **Frontegg M2M** credential (or a user personal token) — no
AWS SSO / admin profile. The server regenerates the docs index on every
write/delete, so there is no client-side index work.

### Credentials (one-time)

Stored in `~/.config/nest-skills/nest-docs.env` (mode `600`, never committed):

`NEST_DOCS_API_BASE` is always required (tst: `https://dev.api.nestgenomics.com`;
local: `http://localhost:3000`). The upload accepts **either** of two auth shapes:

- **Engineers (M2M):** `NEST_DOCS_M2M_CLIENT_ID` + `NEST_DOCS_M2M_SECRET` — a
  Frontegg M2M client with the `NestDocsUploader` role (and `NestDocsAdmin` for
  delete).
- **Non-engineers (personal token):** `NEST_DOCS_USER_TOKEN` — a yoda personal
  token. Run the setup script and pick **Nest Docs** to generate + save it:
  `curl -fsSL https://raw.githubusercontent.com/Nest-Genomics/ai-skills/main/setup-credentials.sh | bash`.
  A user token can upload but **cannot delete** (delete is M2M-admin only).

Load whichever is configured before any request (bare `KEY=value` file, so
auto-export):

```bash
set -a; source ~/.config/nest-skills/nest-docs.env; set +a
```

If neither shape is set, tell the user to run the Nest Docs credential setup above.
Only if the docs API itself is unavailable may an **engineer** use the **Engineer
fallback: direct S3 upload (AWS CLI)** section below.

### Upload / update (upsert)

After writing the file, ask: *"Want me to upload this so you can share it with the
team?"* The same endpoint creates or updates — uploading an existing filename
overwrites it:

Uploads go through the **`uploadNestDoc` GraphQL mutation** at `$NEST_DOCS_API_BASE/graphql`.
The M2M guard reads the **same `client-id`/`secret` headers** (or a personal bearer
token) and exchanges them internally — the auth is identical to the old REST path;
only the URL and body shape changed.

```bash
set -a; source ~/.config/nest-skills/nest-docs.env; set +a
UPLOADER=$(git config user.email)   # uploader email for attribution; if empty, ask the user for it
FILENAME="<name>.html"          # safe name: ^[A-Za-z0-9._-]+\.html$
LOCAL="<local-path>"

# Pick auth: M2M client-id/secret (engineers) or a personal bearer token (non-engineers).
if [ -n "${NEST_DOCS_M2M_CLIENT_ID:-}" ]; then
  AUTH=(-H "client-id: $NEST_DOCS_M2M_CLIENT_ID" -H "secret: $NEST_DOCS_M2M_SECRET")
else
  AUTH=(-H "Authorization: Bearer $NEST_DOCS_USER_TOKEN")
fi

curl -fsS -X POST "$NEST_DOCS_API_BASE/graphql" \
  "${AUTH[@]}" \
  -H "Content-Type: application/json" \
  --data-binary @<(jq -n \
    --arg filename "$FILENAME" \
    --rawfile html "$LOCAL" \
    --arg uploadedBy "$UPLOADER" \
    '{query:"mutation($input: UploadNestDocInput!){ uploadNestDoc(input:$input){ key url preexisted } }",
      variables:{input:{filename:$filename, html:$html, uploadedBy:$uploadedBy}}}')
```

Response: `{ "data": { "uploadNestDoc": { "key": "...", "url": "https://tst.yoda.nestgenomics.com/nest-docs/<name>.html", "preexisted": <bool> } } }`.
The result is under `.data.uploadNestDoc` — parse with `jq -r '.data.uploadNestDoc.url'`.

> **GraphQL error handling:** a GraphQL endpoint returns **HTTP 200 even on failure**,
> with the problem in an `errors` array — so `curl -f` will *not* catch an auth or
> validation failure. After the call, check `.errors`: if
> `jq -e '.errors' <response>` is non-empty, treat it as a failure and surface
> `.errors[0].message` (e.g. `Only 'm2m' account users can call this endpoint`,
> or the unsafe-filename / reserved-`index.html` messages).

- `preexisted: true` means it was an update — the server **preserves the original
  `uploaded-by`** and only refreshes `updated-by`/`updated-at`. You never manage
  metadata by hand. If the filename is generic (e.g. `summary.html`) and would
  overwrite someone else's doc, confirm first.
- The server sets `content-type` + `cache-control: no-cache` and **regenerates the
  index** itself — there is no separate index step.
- If both formats were generated (page + deck), upload both; both URLs go in the report.

### Delete (requires the `NestDocsAdmin` role)

Confirm with the user first (show the filename):

Delete is the **`deleteNestDoc` GraphQL mutation** (M2M `NestDocsAdmin` only):

```bash
set -a; source ~/.config/nest-skills/nest-docs.env; set +a
curl -fsS -X POST "$NEST_DOCS_API_BASE/graphql" \
  -H "client-id: $NEST_DOCS_M2M_CLIENT_ID" \
  -H "secret: $NEST_DOCS_M2M_SECRET" \
  -H "Content-Type: application/json" \
  --data-binary @<(jq -n --arg filename "<name>.html" \
    '{query:"mutation($filename: String!){ deleteNestDoc(filename:$filename){ key deleted } }",
      variables:{filename:$filename}}')
```

Response: `{ "data": { "deleteNestDoc": { "key": "...", "deleted": true } } }` (check
`.errors` as above — HTTP is 200 even on failure). The bucket is versioned (deletes
recoverable for 30 days); `index.html` cannot be deleted (the server refuses it).

### Reporting the URL

Report the `url` from the response (`jq -r '.data.uploadNestDoc.url'`):

```
https://tst.yoda.nestgenomics.com/nest-docs/<name>.html
```

- Reachable only from the Nest Tailscale network. The docs index at
  `https://tst.yoda.nestgenomics.com/nest-docs/` is refreshed server-side; the new
  entry appears immediately (`no-cache` forces ETag revalidation — no CloudFront
  invalidation needed).
- Do not use the raw `https://yoda-app-origin-tst.s3.amazonaws.com/...` URL — the
  bucket is private and it will 403.

### Notes

- **tst only** — the mutations resolve to "not found" (the `NestDocsEnvironmentGuard`
  rejects) in any other environment by design.
- The GraphQL API is the default and the `nest-docs` service owns the index. The
  `aws s3 cp --profile tst-account-administrator-role` upload + client-side index
  regeneration survive **only** as the **Engineer fallback** below — don't use them
  unless the API is unavailable. `index-template.html` in this skill dir is both the
  server-side template's design reference and the fallback's index template.
- **Errors arrive in the GraphQL `errors` array with HTTP 200** — always check
  `.errors`, don't rely on the HTTP status. Common `.errors[0].message`:
  authentication/role failures (missing/invalid M2M credential, or non-`m2m` tenant
  on delete); unsafe filename (must match `^[A-Za-z0-9._-]+\.html$`) or the reserved
  `index.html`. A transport-level `404` on `/graphql` itself means
  `NEST_DOCS_API_BASE` points at a non-tst host.

## Engineer fallback: direct S3 upload (AWS CLI)

Use this **only if you are an engineer** with the `tst-account-administrator-role`
AWS profile **and** the docs API above is unavailable. It bypasses the server, so
you must also regenerate the index yourself (covered below). Everyone else — and
engineers by default — should use the docs API above.

Capture the uploader's email from `git config user.email`, then upload with it as
object metadata:

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

#### Sharing the URL

After a successful upload, report the URL:

```
https://tst.yoda.nestgenomics.com/nest-docs/<filename>.html
```

- CloudFront caches responses at the edge, but the `--cache-control "no-cache"` header above forces revalidation on every request, so updates appear immediately without needing a CloudFront invalidation. (If a file was uploaded *without* the `no-cache` header in the past, a one-time `aws cloudfront create-invalidation --distribution-id E3NT3KZTMT0HA1 --paths "/nest-docs/<filename>.html" --profile tst-account-administrator-role` will clear the stale entry.)
- Do not use the raw `https://yoda-app-origin-tst.s3.amazonaws.com/...` URL — that endpoint will 403 since the bucket itself is private.

### Regenerating the docs index (every upload)

After every successful upload, refresh `s3://yoda-app-origin-tst/nest-docs/index.html` so the docs landing page (`https://tst.yoda.nestgenomics.com/nest-docs/`) shows the file you just uploaded at the top. This is automatic — do not ask the user; it's part of the upload step.

**Default to the append fast path.** You already know everything about the one row that changed — the filename, the uploader (`$UPLOADER` from `git config user.email`, captured during the upload), the size (the local file), and the date (today). So rather than re-deriving all 50 rows from S3, fetch the live index, splice in one new row, and re-upload. This skips the ~50 `head-object` round-trips the full rebuild pays on every upload. Fall back to the full rebuild only when the index is missing or unparseable, or when the user explicitly asks to "regenerate the docs index" from scratch.

#### Fast path: prepend the new row (default)

1. **Download the current index** to a temp path:

   ```bash
   aws s3 cp s3://yoda-app-origin-tst/nest-docs/index.html /tmp/nest-docs-index.html \
     --profile tst-account-administrator-role
   ```

   If this fails (e.g. `NoSuchKey` — first-ever upload) **or** the downloaded file contains no `<ul class="docs-list">` … `</ul>` block, abandon the fast path and run the **Full rebuild** below instead. Those are the only two fallback triggers.

2. **Build the new `<li>`** for the file you just uploaded, using the exact row markup and escaping rules in the Full rebuild's *Render* step below. The values come from what you already have — no S3 metadata lookup:
   - **uploader** = local part of `$UPLOADER` (e.g. `jordan@nestgenomics.com` → `jordan`). If `$UPLOADER` is empty, render `—` (never guess — same rule as the upload step).
   - **size** = `Math.round(<local file bytes> / 1024)` KB (`stat -f%z <local-path>` on macOS).
   - **dates** = today's `YYYY-MM-DD`, used for both the ISO line and the `data-date` attribute.

3. **Splice the rows** inside the `<ul class="docs-list">` … `</ul>` block:
   - **Dedupe:** remove any existing `<li>` whose `<a href="…">` equals the new file's URL-encoded filename. A re-upload overwrote the doc in place, so its old row must not linger below the new one (otherwise the same file appears twice).
   - **Prepend** the new `<li>` as the first child. The "Latest" pill and the highlighted first-row layout are CSS `:first-child` rules, so they move to the new row automatically — don't hand-edit any row to add/remove the pill.
   - **Trim** to the first 50 `<li>` rows. Older rows fall off the index but stay reachable by direct URL — same 50-cap as the full rebuild.

4. **Update the two header values** in the rendered HTML (they're plain text now, not `{{...}}` placeholders):
   - the number inside `<span class="accent">N</span>` → the new row total.
   - the date after `Last regenerated ` → today (`YYYY-MM-DD`).

5. **Upload the spliced file** back to `index.html` (see *Upload the regenerated index*).

The fast path never reads `uploaded-by` from S3: the only new row's uploader is the email captured at upload time, and every row below is copied verbatim from the index they were already rendered into. A row that already shows `—` stays `—` when carried forward — do not "fix" it (same no-back-fill rule as the upload step).

#### Full rebuild (fallback, or on explicit "regenerate" request)

Use this only when the fast path can't run — no existing `index.html`, an index missing the `<ul class="docs-list">` block, or the user asks to regenerate the whole index from scratch. It re-derives every row from S3, which is why it pays the per-file `head-object` cost.

#### List the most recent 50 HTML docs

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

#### Fetch uploader metadata for each file

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

#### Render `index.html` from `index-template.html`

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

#### Upload the regenerated index (both paths)

```bash
aws s3 cp <local-index-path> s3://yoda-app-origin-tst/nest-docs/index.html \
  --profile tst-account-administrator-role \
  --content-type "text/html; charset=utf-8"
```

Save the local index to `~/Desktop/nest-docs-index.html` (or a temp path) — it's regenerated on every upload, so it doesn't need a permanent local home.

#### Tell the user (both paths)

After both uploads succeed, report:

- The direct URL to the new doc.
- That the docs index has been refreshed at `https://tst.yoda.nestgenomics.com/nest-docs/`.
- A reminder that CloudFront caches `index.html` for ~5 minutes (per the `default_ttl` on the `nest-docs/*` cache behavior), so the new entry may take a few minutes to appear.

If only the index needs to be regenerated (e.g. after a manual `aws s3 cp` that bypassed the skill), the user can ask "regenerate the docs index" and the skill should run the **Full rebuild** (then upload + report) without uploading a new doc.


