#!/usr/bin/env bash
set -u

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
failures=0

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	failures=$((failures + 1))
}

pass() {
	printf 'OK: %s\n' "$1"
}

check_bash_syntax() {
	local checked=0
	local file first_line

	while IFS= read -r file; do
		first_line=$(head -n 1 "$file" 2>/dev/null || true)
		if [[ "$first_line" == *bash* || "$file" == *.sh ]]; then
			checked=$((checked + 1))
			bash -n "$file" || fail "bash syntax: ${file#$ROOT_DIR/}"
		fi
	done < <(find "$ROOT_DIR/bin" "$ROOT_DIR/script" -type f | sort)

	pass "checked bash syntax for $checked scripts"
}

check_installation_modules() {
	local missing=0
	local file module

	while IFS=: read -r file module; do
		if [[ ! -f "$ROOT_DIR/script/$module/setup.sh" ]]; then
			printf 'missing module script: %s -> script/%s/setup.sh\n' "${file#$ROOT_DIR/}" "$module" >&2
			missing=$((missing + 1))
		fi
	done < <(
		awk '
			/component_installation=\(/ { in_array=1; next }
			in_array && /^\)/ { in_array=0; next }
			in_array {
				sub(/#.*/, "")
				gsub(/[ \t]/, "")
				if (length($0)) print FILENAME ":" $0
			}
		' "$ROOT_DIR"/script/*_installation.sh
	)

	if [[ $missing -gt 0 ]]; then
		fail "$missing installation modules point at missing setup scripts"
	else
		pass "all installation modules have setup scripts"
	fi
}

check_retired_surface() {
	local banned_files banned_refs
	local retired_pattern="otobun|cargo|Cargo|Rust|crates/otobun|linux_ubuntu|linux_fedora|Ubuntu|Fedora|WSL|apps/fedora|apps/ubuntu|lazygit/fedora|polybar|configs/i3"

	banned_files=$(find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o \( \
		-iname '*otobun*' \
		-o -iname '*fedora*' \
		-o -iname '*ubuntu*' \
		-o -name 'Cargo.toml' \
		-o -name 'Cargo.lock' \
	\) -print)
	if [[ -n "$banned_files" ]]; then
		printf '%s\n' "$banned_files" | sed "s#^$ROOT_DIR/##" >&2
		fail "retired files are present"
	else
		pass "no retired Ubuntu/Fedora/Rust/Otobun files found"
	fi

	if command -v rg >/dev/null 2>&1; then
		banned_refs=$(rg -n \
			--glob '!script/dev/check.sh' \
			"$retired_pattern" \
			"$ROOT_DIR/README.md" \
			"$ROOT_DIR/CLAUDE.md" \
			"$ROOT_DIR/AGENTS.md" \
			"$ROOT_DIR/bin" \
			"$ROOT_DIR/script" \
			"$ROOT_DIR/configs/hypr" \
			"$ROOT_DIR/docs/modular-zsh-integration.md" 2>/dev/null || true)
	else
		banned_refs=$(grep -REn "$retired_pattern" \
			"$ROOT_DIR/README.md" \
			"$ROOT_DIR/CLAUDE.md" \
			"$ROOT_DIR/AGENTS.md" \
			"$ROOT_DIR/bin" \
			"$ROOT_DIR/script" \
			"$ROOT_DIR/configs/hypr" \
			"$ROOT_DIR/docs/modular-zsh-integration.md" 2>/dev/null |
			grep -v 'script/dev/check.sh' || true)
	fi
	if [[ -n "$banned_refs" ]]; then
		printf '%s\n' "$banned_refs" | sed "s#^$ROOT_DIR/##" >&2
		fail "retired references are present in first-party files"
	else
		pass "no retired references found in first-party files"
	fi
}

main() {
	check_bash_syntax
	check_installation_modules
	check_retired_surface

	if [[ $failures -gt 0 ]]; then
		printf '\n%d health check(s) failed.\n' "$failures" >&2
		return 1
	fi

	printf '\nAll health checks passed.\n'
}

main "$@"
