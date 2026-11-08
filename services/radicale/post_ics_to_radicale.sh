#!/usr/bin/env bash
set -euo pipefail

# Configuration: Set these via environment variables or edit here
RADICALE_USER="${RADICALE_USER:-your_username}"
RADICALE_PASS="${RADICALE_PASS:-your_password}"
RADICALE_URL="${RADICALE_URL:-http://localhost:5232}"
RADICALE_CALENDAR="${RADICALE_CALENDAR:-my_calendar}"

# URL-encode a string using pure bash (no external dependencies).
# Usage: urlencode "some string"
urlencode() {
    local LC_ALL=C
    local str="$1"
    local out=""
    local i c
    for (( i = 0; i < ${#str}; i++ )); do
        c="${str:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) out+="$c" ;;
            *) out+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    printf '%s' "$out"
}

# Percent-encode credentials for use in the userinfo part of a URL.
# RFC 3986 allows unreserved chars + sub-delims + ':' but we encode conservatively.
urlencode_userinfo() {
    local LC_ALL=C
    local str="$1"
    local out=""
    local i c
    for (( i = 0; i < ${#str}; i++ )); do
        c="${str:i:1}"
        case "$c" in
            [a-zA-Z0-9._~-]) out+="$c" ;;
            *) out+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    printf '%s' "$out"
}

ENC_USER=$(urlencode "$RADICALE_USER")
ENC_CALENDAR=$(urlencode "$RADICALE_CALENDAR")

# Target path: /<user>/<calendar>
TARGET_URL="${RADICALE_URL%/}/${ENC_USER}/${ENC_CALENDAR}"

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <url_to_ics_file>"
    exit 1
fi

ICS_URL="$1"
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

echo "Downloading ICS from: $ICS_URL"
# -L follows redirects, -f fails on HTTP errors
if ! curl -fsSL -o "$TEMP_FILE" "$ICS_URL"; then
    echo "Error: Failed to download ICS file." >&2
    exit 1
fi

# Optional: sanity check
if ! head -n 1 "$TEMP_FILE" | grep -qi "BEGIN:VCALENDAR"; then
    echo "Warning: The downloaded file does not start with 'BEGIN:VCALENDAR'. Uploading anyway." >&2
fi

echo "Uploading to Radicale: $TARGET_URL"
# Use -u with the *raw* credentials (curl handles auth encoding itself),
# and use the *encoded* URL for the request path.
if curl -fsS -u "${RADICALE_USER}:${RADICALE_PASS}" \
    -X PUT "$TARGET_URL" \
    --data-binary "@${TEMP_FILE}"; then
    echo "Success: Calendar updated."
else
    echo "Error: Upload failed. Check credentials and URL." >&2
    exit 1
fi
