#!/usr/bin/env bash
# Rendering tests for the quarter-resolution gauge. Each case pipes a fixed
# JSON sample into statusline-progress.sh and asserts the exact bar string.
#
# One dot holds four quarter-steps, so a 10-dot bar resolves 2.5%:
#   ○ (0)  ◔ (1/4)  ◑ (1/2)  ◕ (3/4)  ● (full)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/statusline-progress.sh"

render() {
    local pct="$1"
    printf '{"context_window":{"used_percentage":%s},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":9999999999}}}' \
        "$pct" "$pct" | bash "$SOURCE_SCRIPT"
}

assert_bar() {
    local pct="$1" expected="$2"
    local output
    output="$(render "$pct")"
    if printf '%s' "$output" | grep -qF -- "$expected"; then
        echo "  PASS: ${pct}% renders $expected"
    else
        echo "  FAIL: ${pct}% did not render $expected"
        echo "    In output: $output"
        exit 1
    fi
}

assert_absent() {
    local desc="$1" pct="$2" needle="$3"
    local output
    output="$(render "$pct")"
    if printf '%s' "$output" | grep -qF -- "$needle"; then
        echo "  FAIL: $desc"
        echo "    Did not expect '$needle' in: $output"
        exit 1
    fi
    echo "  PASS: $desc"
}

echo "Test 1: whole-dot boundaries"
assert_bar 0   "○○○○○○○○○○"
assert_bar 50  "●●●●●○○○○○"
assert_bar 100 "●●●●●●●●●●"

echo "Test 2: quarter steps within a dot"
assert_bar 23 "●●◔○○○○○○○"
assert_bar 25 "●●◑○○○○○○○"
assert_bar 68 "●●●●●●◕○○○"

echo "Test 3: a non-zero percentage never renders an empty bar"
assert_bar 1 "◔○○○○○○○○○"
assert_absent "0% has no filled glyph" 0 "◔"

echo "Test 4: a bar is only full at exactly 100%"
assert_bar 99 "●●●●●●●●●◕"
assert_absent "100% has no empty glyph" 100 "○"

echo "Test 5: missing fields fall back to placeholders"
out="$(printf '{}' | bash "$SOURCE_SCRIPT")"
for needle in "Context --" "Usage --"; do
    if printf '%s' "$out" | grep -qF -- "$needle"; then
        echo "  PASS: renders '$needle' when the field is absent"
    else
        echo "  FAIL: expected '$needle' in: $out"
        exit 1
    fi
done

strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }

assert_usage() {
    local desc="$1" json="$2" expected="$3" output
    output="$(printf '%s' "$json" | bash "$SOURCE_SCRIPT" | strip_ansi)"
    if printf '%s' "$output" | grep -qF -- "$expected"; then
        echo "  PASS: $desc"
    else
        echo "  FAIL: $desc"
        echo "    Expected '$expected' in: $output"
        exit 1
    fi
}

now="$(date +%s)"
in_2h=$(( now + 2 * 3600 + 630 ))
in_36h=$(( now + 36 * 3600 + 630 ))

echo "Test 6: the 5-hour window wins when it is reported (Pro, Max, unverified Ultra)"
assert_usage "both windows show the 5-hour one" \
    "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":33,\"resets_at\":$in_2h},\"seven_day\":{\"used_percentage\":61,\"resets_at\":$in_36h}}}" \
    "33% (2h 10m / 5h)"

echo "Test 7: weekly window when no 5-hour window is reported (verified Ultra)"
assert_usage "weekly over a day away shows days and hours" \
    "{\"rate_limits\":{\"seven_day\":{\"used_percentage\":61,\"resets_at\":$in_36h}}}" \
    "61% (1d 12h / 7d)"
assert_usage "weekly under a day away shows hours and minutes" \
    "{\"rate_limits\":{\"seven_day\":{\"used_percentage\":61,\"resets_at\":$in_2h}}}" \
    "61% (2h 10m / 7d)"
assert_usage "explicit null 5-hour window also falls back" \
    "{\"rate_limits\":{\"five_hour\":null,\"seven_day\":{\"used_percentage\":61,\"resets_at\":$in_36h}}}" \
    "61% (1d 12h / 7d)"

echo "Test 8: empty rate_limits keeps the placeholder"
assert_usage "no windows renders the placeholder" '{"rate_limits":{}}' "Usage --"

echo
echo "All render tests passed."
