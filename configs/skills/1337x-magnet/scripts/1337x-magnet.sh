#!/usr/bin/env bash
# 1337x magnet lookup — attach to an existing CDP browser, search, return magnet.
#
# Usage:
#   1337x-magnet.sh "Skyrim Special Edition FitGirl"          # search + auto-pick
#   1337x-magnet.sh "Skyrim" --filter "fitgirl"                # narrow by regex
#   1337x-magnet.sh "Skyrim" --list                            # show candidates only
#   1337x-magnet.sh "Skyrim" --id 4196293                      # fetch a known id
#   1337x-magnet.sh --check                                    # is a browser attached?
#
# Env:
#   CDP_PORT   default 9222
#
# Always 1337x.to — mirrors are deliberately not supported.

set -uo pipefail

CDP_PORT="${CDP_PORT:-9222}"
DOMAIN="1337x.to"
# --pin-tab is required: without it each invocation binds the FIRST page tab, so a
# freshly opened tab is invisible and every eval reads about:blank.
TAB="agent-browser --cdp ${CDP_PORT} --pin-tab"

QUERY=""; FILTER=""; ID=""; LIST=0; CHECK=0

die() { printf '%s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --filter) FILTER="${2:-}"; shift 2 ;;
    --id)     ID="${2:-}"; shift 2 ;;
    --list)   LIST=1; shift ;;
    --check)  CHECK=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    -*)       die "unknown flag: $1" ;;
    *)        QUERY="${1:-}"; shift ;;
  esac
done

command -v agent-browser >/dev/null || die "agent-browser not on PATH"

# --- attachment ------------------------------------------------------------
attached() { curl -sf -m 3 "http://127.0.0.1:${CDP_PORT}/json/version" >/dev/null 2>&1; }

if [ "$CHECK" = 1 ]; then
  attached && { echo "attached: CDP :${CDP_PORT} live, target ${DOMAIN}"; exit 0; }
  echo "no browser listening on CDP :${CDP_PORT}"
  exit 2
fi

if ! attached; then
  cat >&2 <<EOF
No browser is listening on CDP port ${CDP_PORT}.

Launch one against your real profile (keeps a valid cf_clearance cookie):

  open -na "Brave Browser" --args --remote-debugging-port=${CDP_PORT} --restore-last-session

That exposes a debugging port on your real browser — any local process can drive it.
Quit and relaunch Brave without the flag when you're done.
EOF
  exit 2
fi

# NOTE: never call `tab list` here — it re-binds the pin to the first page tab
# (usually about:blank) and every later eval then reads the wrong tab.

nav() { $TAB open "$1" >/dev/null 2>&1 || $TAB tab new "$1" >/dev/null 2>&1; }

# agent-browser eval prints JS strings wrapped in double quotes — strip them.
js() { $TAB eval "$1" 2>/dev/null | sed 's/^"//; s/"$//'; }
# Same, but for multi-line output: eval escapes newlines as literal \n, so
# `head -1` on the raw form returns the whole blob as one line.
jsl() { $TAB eval "$1" 2>/dev/null | sed 's/^"//; s/"$//' | python3 -c 'import sys;sys.stdout.write(sys.stdin.read().replace("\\n","\n"))' 2>/dev/null; }

# Add the search provenance and pretty-print the JSON object.
fmt() {
  local raw="$1" q="$2"
  [ -z "$raw" ] && { echo "!! no data extracted from the page" >&2; return 1; }
  printf '%s' "$raw" | python3 -c '
import json,sys
t=sys.stdin.read()
def load(t):
    try: return json.loads(t)
    except Exception: pass
    # agent-browser sometimes prints a JS string as a backslash-escaped blob
    # ({\"a\":1}) with no wrapping quotes; unwrap it before parsing.
    try: return json.loads(json.loads("\""+t.strip().strip("\"")+"\""))
    except Exception: pass
    try: return json.loads(t.replace(chr(92)+chr(34),chr(34)))
    except Exception: sys.exit(1)
d=load(t)
d["searched"]=sys.argv[1]
if d.get("seeders") or d.get("leechers"):
    d["s_l"]="%s se / %s le"%(d.get("seeders"),d.get("leechers"))
print(json.dumps(d,indent=2,ensure_ascii=False))' "$q" 2>/dev/null \
    || printf '%s\n' "$raw"
}

# Shared extractor: magnet + infohash + the stat row (size/seeds/leechers/downloads)
# + a description excerpt. Emits one JSON object.
read -r -d '' EXTRACT <<'JSEOF'
(function(){
  var t=document.body.innerText, g=function(r){var m=t.match(r);return m?m[1].trim():null;},
      m=document.querySelector('a[href^=magnet]'),
      d=document.querySelector('.torrent-desc,#description,.torrent-description,[id*=description]');
  var desc=d?d.innerText.trim():'';
  if(!desc){var i=t.search(/DESCRIPTION[\s\S]{0,400}?TRACKER LIST/);
    if(i>=0) desc=t.slice(i).replace(/^[\s\S]{0,400}?TRACKER LIST/,'');}
  return JSON.stringify({
    title:document.title.replace(/^Download /,'').replace(/ Torrent \| 1337x.*$/,''),
    magnet:m?m.href:null,
    infohash:g(/INFOHASH[^:\n]*:\s*([0-9A-Fa-f]{40})/i),
    size:g(/Total size\s*\n?\s*([^\n]+)/),
    uploaded_by:g(/Uploaded By\s*\n?\s*([^\n]+)/),
    downloads:g(/Downloads\s*\n?\s*([^\n]+)/),
    last_checked:g(/Last checked\s*\n?\s*([^\n]+)/),
    date_uploaded:g(/Date uploaded\s*\n?\s*([^\n]+)/),
    seeders:g(/Seeders\s*\n?\s*([^\n]+)/),
    leechers:g(/Leechers\s*\n?\s*([^\n]+)/),
    language:g(/Language\s*\n?\s*([^\n]+)/),
    description:desc?desc.slice(0,1500).replace(/\n{3,}/g,'\n\n'):null,
    url:location.href});
})()
JSEOF

# --- locate the working tab -------------------------------------------------
# The bound tab can point at about:blank after a navigation; find or open a page tab.
ensure_tab() {
  local cur i
  for i in 1 2 3; do
    cur="$($TAB eval 'location.href' 2>/dev/null | tr -d '"')"
    case "$cur" in
      ""|*about:blank*|*chrome-error*|*'127.0.0.1'*) $TAB tab new "$1" >/dev/null 2>&1; sleep 3 ;;
      *) nav "$1"; return 0 ;;
    esac
  done
}

# --- mode: fetch a specific torrent id -------------------------------------
if [ -n "$ID" ]; then
  ensure_tab "https://${DOMAIN}/"
  slug=$(js "Array.from(document.querySelectorAll('a')).map(a=>a.href).find(h=>/torrent\/${ID}\//.test(h))||''")
  [ -z "$slug" ] && slug="https://${DOMAIN}/torrent/${ID}/"
  nav "$slug"; sleep 3
  case "$(js "document.querySelector('a[href^=magnet]')?'has-magnet':'no-magnet'")" in
    has-magnet) ;;
    *) die "no torrent page at ${slug} (id ${ID} not on ${DOMAIN}).
    Use the search form instead:  $0 '<title>'" ;;
  esac
  for i in 1 2 3 4 5; do
    sleep 2
    out="$(js "$EXTRACT")"
    case "$out" in *'"magnet":"magnet:'*) fmt "$out" "--id ${ID}"; exit 0 ;; esac
  done
  die "page at ${slug} loaded but exposed no magnet link"
  exit 0
fi

[ -z "$QUERY" ] && die "need a search query (or --id / --check)"

# --- search -----------------------------------------------------------------
# The 1337x searchbox ignores multi-word queries and returns nothing, so reduce
# the request to its single most distinctive token and filter the rows in JS.
# "Skyrim Special Edition FitGirl" -> "skyrim"; "The Matrix" -> "matrix".
kw=$(printf '%s' "$QUERY" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cs '[:alnum:]' '\n' \
      | grep -vE '^(the|a|an|of|and|edition|ed|repack|version|complete|goty|fitgirl|fit|girl|multi[0-9]*|dlc|remastered)$' \
      | grep -v '^$' | head -1)
[ -z "$kw" ] && kw=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | grep -v '^$' | head -1)
[ -z "$kw" ] && die "could not derive a search keyword from '$QUERY'"

ensure_tab "https://${DOMAIN}/home/"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  t=$(js 'document.title')
  case "$t" in *"Just a moment"*|"") sleep 3 ;; *) break ;; esac
done
case "$t" in
  *"Just a moment"*)
    cat >&2 <<EOF
Cloudflare is still challenging this browser on ${DOMAIN}.

A fresh automated Chrome never clears this; it needs a profile that has passed the
challenge before. Confirm the port is attached to a REAL browser (not an agent-browser
-launched one) with:

  agent-browser --cdp ${CDP_PORT} eval "navigator.userAgent"

Or open https://1337x.to/home/ in that browser, pass the challenge by hand, and rerun.
EOF
    exit 3 ;;
esac

kw_set=$(js "(function(){var s=document.querySelector('input[type=search],input[name=q],input[placeholder*=Search i]');if(!s)return 'NOSEARCHBOX';s.focus();var set=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;set.call(s,'${kw}');s.dispatchEvent(new Event('input',{bubbles:true}));return 'OK';})()")
[ "$kw_set" = "NOSEARCHBOX" ] && die "no search box found on ${DOMAIN}"
# A synthetic form.submit() is ignored; the site only reacts to a real keypress.
$TAB press Enter >/dev/null 2>&1
sleep 5
case "$(js 'location.href')" in
  */search/*) ;;
  *) $TAB open "https://${DOMAIN}/search/${kw}/1/" >/dev/null 2>&1; sleep 5 ;;
esac

if [ "$LIST" = 1 ]; then
  lsel="Array.from(document.querySelectorAll('a')).map(a=>a.textContent.trim()+' | '+a.href)
        .filter(s=>/torrent\/\d+/.test(s) && /${kw}/i.test(s))"
  [ -n "$FILTER" ] && lsel="$lsel.filter(s=>/${FILTER}/i.test(s))"
  jsl "$lsel.slice(0,20).join('\n')"
  exit 0
fi

# --- pick + fetch -----------------------------------------------------------
sel="Array.from(document.querySelectorAll('a')).map(a=>({t:a.textContent.trim(),h:a.href}))
      .filter(o=>/torrent\/\d+/.test(o.h) && /${kw}/i.test(o.t))"
[ -n "$FILTER" ] && sel="$sel.filter(o=>/${FILTER}/i.test(o.t))"
cand=$(jsl "$sel.slice(0,20).map(o=>o.h).join('\n')")
[ -z "$cand" ] && die "no results for '${QUERY}' on ${DOMAIN} (searched '${kw}')"

best=$(printf '%s\n' "$cand" | head -1)
nav "$best"
# nav falls back to `tab new`, which leaves the pin on a tab that is still loading.
for i in 1 2 3 4 5; do
  sleep 2
  out="$(js "$EXTRACT")"
  case "$out" in *'"magnet":"magnet:'*) break ;; esac
done
fmt "$out" "${QUERY} (searched: ${kw})"
