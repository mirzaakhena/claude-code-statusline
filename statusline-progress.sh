#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# ANSI Colors
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_RED="\033[31m"
FG_WHITE="\033[97m"
FG_GRAY="\033[90m"

# ---------------------------------------------------------------------------
# Gauge glyphs: each dot holds 4 quarter-steps, so a 10-dot bar resolves 2.5%
# ---------------------------------------------------------------------------
DOT_EMPTY="\xe2\x97\x8b"    # U+25CB WHITE CIRCLE                             (0)
DOT_Q1="\xe2\x97\x94"       # U+25D4 CIRCLE WITH UPPER RIGHT QUADRANT BLACK   (1/4)
DOT_Q2="\xe2\x97\x91"       # U+25D1 CIRCLE WITH RIGHT HALF BLACK             (1/2)
DOT_Q3="\xe2\x97\x95"       # U+25D5 CIRCLE WITH ALL BUT UPPER LEFT QUADRANT  (3/4)
DOT_FULL="\xe2\x97\x8f"     # U+25CF BLACK CIRCLE                             (1)

# ---------------------------------------------------------------------------
# Progress bar builder
# $1 = percentage (0-100), $2 = bar width in dots (default 10)
# ---------------------------------------------------------------------------
make_bar() {
    local pct=$1
    local width=${2:-10}
    local max=$(( width * 4 ))

    # Fill level in quarter-steps, rounded to nearest
    local quarters=$(( (pct * max + 50) / 100 ))
    [ "$quarters" -lt 0 ] && quarters=0
    [ "$quarters" -gt "$max" ] && quarters=$max

    # Keep the extremes honest: never draw an empty bar while something is in
    # use, never draw a full bar before it actually is full.
    [ "$quarters" -eq 0 ] && [ "$pct" -gt 0 ] && quarters=1
    [ "$quarters" -eq "$max" ] && [ "$pct" -lt 100 ] && quarters=$(( max - 1 ))

    local full=$(( quarters / 4 ))
    local rem=$(( quarters % 4 ))

    local bar=""
    local drawn=0
    while [ "$drawn" -lt "$full" ]; do
        bar="${bar}${DOT_FULL}"
        drawn=$(( drawn + 1 ))
    done

    case "$rem" in
        1) bar="${bar}${DOT_Q1}"; drawn=$(( drawn + 1 )) ;;
        2) bar="${bar}${DOT_Q2}"; drawn=$(( drawn + 1 )) ;;
        3) bar="${bar}${DOT_Q3}"; drawn=$(( drawn + 1 )) ;;
    esac

    while [ "$drawn" -lt "$width" ]; do
        bar="${bar}${DOT_EMPTY}"
        drawn=$(( drawn + 1 ))
    done

    printf "%b" "$bar"
}

# ---------------------------------------------------------------------------
# Pick a color based on percentage (low=green, mid=yellow, high=red)
# ---------------------------------------------------------------------------
pct_color() {
    local pct=$1
    if [ "$pct" -lt 50 ]; then
        printf "%b" "$FG_GREEN"
    elif [ "$pct" -lt 75 ]; then
        printf "%b" "$FG_YELLOW"
    else
        printf "%b" "$FG_RED"
    fi
}

# ---------------------------------------------------------------------------
# Context window usage
# ---------------------------------------------------------------------------
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

ctx_label=""
if [ -n "$used_pct" ]; then
    used_int=$(printf "%.0f" "$used_pct")
    bar=$(make_bar "$used_int" 10)
    color=$(pct_color "$used_int")
    ctx_label="${BOLD}${FG_WHITE}Context${RESET} ${color}${bar}${RESET} ${color}${used_int}%${RESET}"
else
    ctx_label="${DIM}${FG_GRAY}Context --${RESET}"
fi

# ---------------------------------------------------------------------------
# 5-hour session rate-limit usage
# ---------------------------------------------------------------------------
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

usage_label=""
if [ -n "$five_pct" ]; then
    five_int=$(printf "%.0f" "$five_pct")
    bar=$(make_bar "$five_int" 10)
    color=$(pct_color "$five_int")

    # Build human-readable time-remaining string from resets_at epoch
    time_info=""
    if [ -n "$five_resets" ] && [ "$five_resets" != "null" ]; then
        now=$(date +%s)
        remaining_secs=$(( five_resets - now ))
        if [ "$remaining_secs" -gt 0 ]; then
            rem_h=$(( remaining_secs / 3600 ))
            rem_m=$(( (remaining_secs % 3600) / 60 ))
            time_info=" ${DIM}${FG_GRAY}(${rem_h}h ${rem_m}m / 5h)${RESET}"
        fi
    fi

    usage_label="${BOLD}${FG_WHITE}Usage${RESET} ${color}${bar}${RESET} ${color}${five_int}%${RESET}${time_info}"
else
    usage_label="${DIM}${FG_GRAY}Usage --${RESET}"
fi

# ---------------------------------------------------------------------------
# Separator
# ---------------------------------------------------------------------------
SEP="${DIM}${FG_GRAY} \xe2\x94\x82 ${RESET}"   # U+2502 BOX DRAWINGS LIGHT VERTICAL

# ---------------------------------------------------------------------------
# Final output
# ---------------------------------------------------------------------------
printf "%b%b%b\n" "$ctx_label" "$SEP" "$usage_label"
