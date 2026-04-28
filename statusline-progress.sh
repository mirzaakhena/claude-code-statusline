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
# Progress bar builder
# $1 = percentage (0-100), $2 = bar width (default 10)
# ---------------------------------------------------------------------------
make_bar() {
    local pct=$1
    local width=${2:-10}
    local filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    local empty=$(( width - filled ))

    local bar=""
    local i=0
    while [ "$i" -lt "$filled" ]; do
        bar="${bar}\xe2\x96\x88"   # U+2588 FULL BLOCK
        i=$(( i + 1 ))
    done
    i=0
    while [ "$i" -lt "$empty" ]; do
        bar="${bar}\xe2\x96\x91"   # U+2591 LIGHT SHADE
        i=$(( i + 1 ))
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
