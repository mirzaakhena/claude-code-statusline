#!/usr/bin/env bash
# Runtime-side tests for the STYLE shell variable. Each case patches a
# temp copy of statusline-progress.sh, pipes a fixed JSON sample, and
# asserts the rendered characters. The runtime script does not read any
# env var; STATUSLINE_STYLE is an install-time concept only.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/statusline-progress.sh"

# A 50% / 30% snapshot. With width 10 that's 5 filled + 5 empty for Context.
SAMPLE_JSON='{"context_window":{"used_percentage":50},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":9999999999}}}'

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -q -- "$needle"; then
        echo "  PASS: $desc"
    else
        echo "  FAIL: $desc"
        echo "    Expected to find: $needle"
        echo "    In output:        $haystack"
        exit 1
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if ! printf '%s' "$haystack" | grep -q -- "$needle"; then
        echo "  PASS: $desc"
    else
        echo "  FAIL: $desc"
        echo "    Did not expect:  $needle"
        echo "    In output:       $haystack"
        exit 1
    fi
}

run_with_style() {
    local style="$1"
    local tmp
    tmp="$(mktemp -t statusline-runtime.XXXXXX)"
    cp "$SOURCE_SCRIPT" "$tmp"
    sed -i.bak "s/^STYLE=.*/STYLE=\"$style\"/" "$tmp"
    rm -f "$tmp.bak"
    chmod +x "$tmp"
    local output
    output="$(printf '%s' "$SAMPLE_JSON" | bash "$tmp")"
    rm -f "$tmp"
    printf '%s' "$output"
}

echo "Test 1: STYLE=blocks renders block characters"
out="$(run_with_style blocks)"
assert_contains "output contains █ (U+2588)" "$out" $'\xe2\x96\x88'
assert_contains "output contains ░ (U+2591)" "$out" $'\xe2\x96\x91'

echo "Test 2: STYLE=circles renders circle characters"
out="$(run_with_style circles)"
assert_contains "output contains ● (U+25CF)" "$out" $'\xe2\x97\x8f'
assert_contains "output contains ○ (U+25CB)" "$out" $'\xe2\x97\x8b'
assert_not_contains "output has no block char" "$out" $'\xe2\x96\x88'

echo "Test 3: STYLE=invalid falls back to blocks"
out="$(run_with_style bogus)"
assert_contains "output contains █ (fallback)" "$out" $'\xe2\x96\x88'
assert_not_contains "output has no circle char" "$out" $'\xe2\x97\x8f'

echo
echo "All runtime style tests passed."
