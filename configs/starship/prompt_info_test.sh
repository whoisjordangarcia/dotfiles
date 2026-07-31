#!/bin/bash
# Tests for the GitHub PR indicator in prompt_info.sh.
# Pure cache-file fixtures + a stub `gh` — no network, no real repo.

PROMPT_INFO_LIB=1
# shellcheck source=./prompt_info.sh
. "$(dirname "$0")/prompt_info.sh"

pass=0
fail=0

check() {
  local label=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    printf '✓ %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '✗ %s\n    expected: %s\n    actual:   %s\n' "$label" \
      "$(printf '%s' "$expected" | cat -v)" "$(printf '%s' "$actual" | cat -v)"
    fail=$((fail + 1))
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
PR_CACHE_DIR=$tmp/cache
mkdir -p "$PR_CACHE_DIR"

# Stub gh: records that it ran, emits a fixed OPEN PR.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/bin/bash
echo ran >> "$GH_STUB_LOG"
printf 'OPEN\t99\thttps://github.com/o/r/pull/99\n'
EOF
chmod +x "$tmp/bin/gh"
PATH=$tmp/bin:$PATH
export GH_STUB_LOG=$tmp/gh.log
: > "$GH_STUB_LOG"

now=${EPOCHSECONDS:-$(date +%s)}
cache_file() { printf '%s/%s__%s' "$PR_CACHE_DIR" "${1//\//_}" "${2//\//_}"; }

seed() { # seed <stamp> <state> <num> <url>
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" > "$(cache_file /r main)"
}

esc=$'\033'
# The zsh hook exports this; without it pr_part must not emit sentinels.
export STARSHIP_PR_LINK=1
render() { pr_part main /r; }

# The refresh is deliberately detached (its stdout is /dev/null and it is forked
# inside a $(...) subshell), so `wait` can't see it — poll the stub's log.
settle() {
  local i=0
  while [ "$i" -lt 100 ]; do
    [ -s "$GH_STUB_LOG" ] && return 0
    sleep 0.02
    i=$((i + 1))
  done
  return 1
}

seed "$now" OPEN 1234 https://x/pull/1234
check "open PR renders green ● + number, url in sentinels" \
  $'\001https://x/pull/1234\002'"${esc}[32m●#1234${esc}[1;36m"$'\003 ' \
  "$(render)"

seed "$now" DRAFT 7 https://x/pull/7
check "draft renders dim ○" \
  $'\001https://x/pull/7\002'"${esc}[90m○#7${esc}[1;36m"$'\003 ' \
  "$(render)"

seed "$now" MERGED 7 https://x/pull/7
check "merged renders magenta ⬥" \
  $'\001https://x/pull/7\002'"${esc}[35m⬥#7${esc}[1;36m"$'\003 ' \
  "$(render)"

seed "$now" CLOSED 7 https://x/pull/7
check "closed renders red ✕" \
  $'\001https://x/pull/7\002'"${esc}[31m✕#7${esc}[1;36m"$'\003 ' \
  "$(render)"

seed "$now" NONE '' ''
check "no PR renders nothing" "" "$(render)"

# A shell without the rewrite hook must degrade to a plain indicator, never
# leak the bare URL as visible prompt text.
seed "$now" OPEN 1234 https://x/pull/1234
check "no hook -> unlinked indicator, no sentinels, no URL" \
  "${esc}[32m●#1234${esc}[1;36m " \
  "$(STARSHIP_PR_LINK= render)"

# Fresh cache must not fork gh — that is the whole point of the cache.
: > "$GH_STUB_LOG"
seed "$now" OPEN 1 https://x/pull/1
render > /dev/null
sleep 0.3
check "fresh cache does not run gh" "" "$(< "$GH_STUB_LOG")"

# Stale cache refreshes, and still renders the stale value this pass.
: > "$GH_STUB_LOG"
seed "$((now - PR_TTL - 1))" OPEN 1 https://x/pull/1
out=$(render)
settle
check "stale cache still renders the cached PR" \
  $'\001https://x/pull/1\002'"${esc}[32m●#1${esc}[1;36m"$'\003 ' "$out"
check "stale cache runs gh" "ran" "$(< "$GH_STUB_LOG")"
# gh having *logged* doesn't mean it has written the cache yet.
i=0
while [ "$i" -lt 100 ]; do
  IFS=$'\t' read -r st state num _ < "$(cache_file /r main)"
  [ "$num" = 99 ] && break
  sleep 0.02
  i=$((i + 1))
done
check "refresh writes gh result to cache" "OPEN 99" "$state $num"

# A second render immediately after must not fan out another gh call.
: > "$GH_STUB_LOG"
render > /dev/null
sleep 0.3
check "refreshed cache is fresh again" "" "$(< "$GH_STUB_LOG")"

# Corrupt stamp is treated as stale rather than blowing up arithmetic.
: > "$GH_STUB_LOG"
seed "garbage" OPEN 1 https://x/pull/1
render > /dev/null 2>&1
settle
check "corrupt stamp is treated as stale" "ran" "$(< "$GH_STUB_LOG")"

# Missing cache entry: nothing to show, but a refresh is queued.
: > "$GH_STUB_LOG"
rm -f "$(cache_file /r other)"
check "unknown branch renders nothing" "" "$(pr_part other /r)"
settle
check "unknown branch queues a refresh" "ran" "$(< "$GH_STUB_LOG")"

# The zsh side, mirroring _starship_pr_prompt in .zshrc.init. The ${(e)…} step
# is load-bearing: under promptsubst starship leaves PROMPT as a *deferred*
# '$(starship prompt …)' substitution, so a precmd hook inspecting $PROMPT sees
# the literal substitution and never the sentinels.
if command -v zsh > /dev/null; then
  zsh_src='
    _raw='"'"'$(printf '"'"'"'"'"'"'"'"'\001https://x/pull/1\002\033[32m●#1\033[1;36m\003 '"'"'"'"'"'"'"'"')'"'"'
    _render() {
      local p=${(e)_raw}
      if [[ $p == *$'"'"'\001'"'"'* ]]; then
        p=${p//$'"'"'\001'"'"'/$'"'"'%{\e]8;;'"'"'}
        p=${p//$'"'"'\002'"'"'/$'"'"'\e\\%}'"'"'}
        p=${p//$'"'"'\003'"'"'/$'"'"'%{\e]8;;\e\\%}'"'"'}
      fi
      print -rn -- $p
    }
  '
  # Rendered: only the glyph + number may remain visible.
  zout=$(zsh -f -c "$zsh_src"'; print -rn -- ${(%)$(_render)}' | sed -e 's/\x1b/E/g')
  check "zsh wrapper builds a valid OSC 8 hyperlink" \
    'E]8;;https://x/pull/1E\E[32m●#1E[1;36mE]8;;E\' "$zout"

  # Everything outside the %{…%} regions is what zsh counts for prompt width.
  # Strip the %{…%} regions (what zsh treats as zero-width) plus bare CSI colour
  # codes — starship wraps those itself; OSC is the sequence it gets wrong, and
  # this fixture stands in for starship's output without them.
  zvis=$(zsh -f -c "$zsh_src"'; print -rn -- $(_render)' \
    | sed -e 's/%{[^%]*%}//g' -e 's/'$'\x1b''\[[0-9;]*m//g')
  check "no URL or escape leaks into zsh's visible-width count" '●#1' "$zvis"
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
  printf 'All %d tests passed\n' "$pass"
else
  printf '%d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi
