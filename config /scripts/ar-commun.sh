#!/bin/bash
# =============================================================================
# Wazuh Active Response — Shared functions
# =============================================================================
# Sourced by every mikrotik-*-alert.sh / agent-down-alert.sh script.
# Provides: input parsing, structured logging, mail delivery, Mattermost
# delivery, and IP geolocation/enrichment helpers shared across all alerts.
#
# Requires ar-config.sh (see ar-config.sh.example) to be sourced BEFORE this
# file, since it relies on MAIL_TO, MATTERMOST_WEBHOOK, WAZUH_DASHBOARD, and
# LOG_FILE being already defined.
# =============================================================================

# --- Logging -----------------------------------------------------------------
# ar_log <script_tag> <message>
# Example: ar_log "AR-AUTH" "MAIL SENT - LOGIN - Router X"
ar_log() {
    local tag="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [${tag}] ${message}" >> "$LOG_FILE"
}

# --- Input parsing -------------------------------------------------------------
# Reads Wazuh's JSON payload from stdin, validates it, and extracts
# COMMAND and ALERT as global variables. Exits 1 on invalid/missing input.
# Usage: ar_read_input "AR-AUTH"
ar_read_input() {
    local tag="$1"
    INPUT=$(timeout 3 cat)
    ar_log "$tag" "Script triggered"

    if ! echo "$INPUT" | jq -e . > /dev/null 2>&1; then
        ar_log "$tag" "ERROR: Invalid JSON input"
        exit 1
    fi

    COMMAND=$(echo "$INPUT" | jq -r '.command // empty')
    ALERT=$(echo "$INPUT" | jq -c '.parameters.alert // empty')

    if [ -z "$COMMAND" ] || [ -z "$ALERT" ]; then
        ar_log "$tag" "ERROR: Missing command or alert"
        exit 1
    fi
}

# --- Common alert field extraction ---------------------------------------------
# Populates RULE_ID, RULE_DESC, LEVEL, FIRED, TIMESTAMP, FULL_LOG, AGENT,
# AGENT_IP from $ALERT. Fields specific to one alert type (srcip, router_name,
# etc.) are extracted individually in each script, since not every alert
# carries every field.
ar_extract_common_fields() {
    RULE_ID=$(echo "$ALERT"    | jq -r '.rule.id          // "unknown"')
    RULE_DESC=$(echo "$ALERT"  | jq -r '.rule.description // "unknown"')
    LEVEL=$(echo "$ALERT"      | jq -r '.rule.level       // "0"')
    FIRED=$(echo "$ALERT"      | jq -r '.rule.firedtimes  // "1"')
    TIMESTAMP=$(echo "$ALERT"  | jq -r '.timestamp        // "N/A"')
    FULL_LOG=$(echo "$ALERT"   | jq -r '.full_log         // "no log"' | head -c 800)
    AGENT=$(echo "$ALERT"      | jq -r '.agent.name       // "unknown"')
    AGENT_IP=$(echo "$ALERT"   | jq -r '.agent.ip         // "unknown"')
}

# --- MITRE ATT&CK field extraction ---------------------------------------------
# Populates MITRE_ID, MITRE_TACTIC, MITRE_TECH. Only meaningful for rules
# that carry a <mitre> block — callers should expect "N/A" otherwise.
ar_extract_mitre_fields() {
    MITRE_ID=$(echo "$ALERT"     | jq -r '.rule.mitre.id[0]        // "N/A"')
    MITRE_TACTIC=$(echo "$ALERT" | jq -r '.rule.mitre.tactic[0]    // "N/A"')
    MITRE_TECH=$(echo "$ALERT"   | jq -r '.rule.mitre.technique[0] // "N/A"')
}

# --- IP enrichment: geolocation --------------------------------------------
# ar_geolocate_ip <ip>
# Populates GEO_COUNTRY, GEO_CITY, GEO_ORG. Defaults to "Unknown" on any
# failure (offline lookup service, invalid IP, timeout) rather than aborting
# the alert — enrichment is best-effort, not a delivery blocker.
ar_geolocate_ip() {
    local ip="$1"
    GEO_COUNTRY="Unknown"; GEO_CITY="Unknown"; GEO_ORG="Unknown"

    if [ -z "$ip" ] || [ "$ip" = "N/A" ] || [ "$ip" = "unknown" ]; then
        return
    fi

    local geo
    geo=$(curl -s --max-time 3 "https://ipapi.co/${ip}/json/" 2>/dev/null)
    if echo "$geo" | jq -e . > /dev/null 2>&1; then
        GEO_COUNTRY=$(echo "$geo" | jq -r '.country_name // "Unknown"')
        GEO_CITY=$(echo "$geo"    | jq -r '.city         // "Unknown"')
        GEO_ORG=$(echo "$geo"     | jq -r '.org          // "Unknown"')
    fi
}

# --- IP enrichment: occurrence count in alerts.log --------------------------
# ar_count_occurrences <ip>
# Populates OCCURRENCES. Requires ALERTS_LOG to be set in ar-config.sh.
ar_count_occurrences() {
    local ip="$1"
    OCCURRENCES=0
    if [ -n "$ALERTS_LOG" ] && [ -f "$ALERTS_LOG" ] && [ -n "$ip" ] && [ "$ip" != "N/A" ]; then
        OCCURRENCES=$(grep -c "$ip" "$ALERTS_LOG" 2>/dev/null || echo "0")
    fi
}

# --- IP enrichment: active-response block status -----------------------------
# ar_check_blocked_status <ip>
# Populates AR_STATUS. Best-effort: requires read access to iptables rules.
ar_check_blocked_status() {
    local ip="$1"
    AR_STATUS="Not blocked"
    if iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
        AR_STATUS="BLOCKED by iptables"
    fi
}

# --- Delivery: mail --------------------------------------------------------
# ar_send_mail <tag> <subject> <body>
# Returns 0 on success, 1 on failure. Caller decides whether mail failure
# should be fatal (historically: yes, exit 1) — kept as caller's choice here
# since Mattermost delivery should still be attempted even if mail fails.
ar_send_mail() {
    local tag="$1"
    local subject="$2"
    local body="$3"

    if echo "$body" | mail -s "$subject" "$MAIL_TO" 2>> "$LOG_FILE"; then
        ar_log "$tag" "MAIL SENT - ${subject}"
        return 0
    else
        ar_log "$tag" "ERROR: Mail sending failed"
        return 1
    fi
}

# --- Delivery: Mattermost ----------------------------------------------------
# ar_send_mattermost <tag> <message_text>
# Returns 0 on success (HTTP 200), 1 otherwise. Never fatal to the caller —
# a Mattermost outage should not prevent the mail channel (or vice versa)
# from delivering the alert.
ar_send_mattermost() {
    local tag="$1"
    local text="$2"

    local payload
    payload=$(jq -n --arg text "$text" '{text: $text}')

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$MATTERMOST_WEBHOOK")

    if [ "$http_code" = "200" ]; then
        ar_log "$tag" "MATTERMOST SENT"
        return 0
    else
        ar_log "$tag" "ERROR: Mattermost failed (HTTP ${http_code})"
        return 1
    fi
}
