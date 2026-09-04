#!/usr/bin/env bash
# Rendering tests for the quarter-resolution gauge. Each case pipes a fixed
# JSON sample into statusline-progress.sh and asserts the exact bar string.
#
# One dot holds four quarter-steps, so a 10-dot bar resolves 2.5%:
#   ○ (0)  ◔ (1/4)  ◐ (1/2)  ◕ (3/4)  ● (full)

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
assert_bar 25 "●●◐○○○○○○○"
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

echo
echo "All render tests passed."
