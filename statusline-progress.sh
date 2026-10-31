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
# Rate-limit usage
#
# Show the 5-hour window whenever Claude Code reports it (Pro, Max, unverified
# Ultra). Verified Ultra accounts have no 5-hour limit, so the window is absent
# and the weekly one is shown instead. Decided from the data, not the plan: the
# status line input does not name the plan, and the same plan can go either way.
# ---------------------------------------------------------------------------
limit_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
limit_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
limit_span="5h"

if [ -z "$limit_pct" ]; then
    limit_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
    limit_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
    limit_span="7d"
fi

usage_label=""
if [ -n "$limit_pct" ]; then
    limit_int=$(printf "%.0f" "$limit_pct")
    bar=$(make_bar "$limit_int" 10)
    color=$(pct_color "$limit_int")

    # Build human-readable time-remaining string from resets_at epoch
    time_info=""
    if [ -n "$limit_resets" ]; then
        now=$(date +%s)
        remaining_secs=$(( limit_resets - now ))
        if [ "$remaining_secs" -gt 0 ]; then
            rem_d=$(( remaining_secs / 86400 ))
            rem_h=$(( (remaining_secs % 86400) / 3600 ))
            rem_m=$(( (remaining_secs % 3600) / 60 ))
            if [ "$rem_d" -gt 0 ]; then
                remaining="${rem_d}d ${rem_h}h"
            else
                remaining="${rem_h}h ${rem_m}m"
            fi
            time_info=" ${DIM}${FG_GRAY}(${remaining} / ${limit_span})${RESET}"
        fi
    fi

    usage_label="${BOLD}${FG_WHITE}Usage${RESET} ${color}${bar}${RESET} ${color}${limit_int}%${RESET}${time_info}"
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
