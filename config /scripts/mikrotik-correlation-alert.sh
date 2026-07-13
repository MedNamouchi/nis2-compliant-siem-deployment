#!/bin/bash
# =============================================================================
# Wazuh Active Response — Coordinated attack notification
# Multi-source correlation: MikroTik brute force + SSH brute force, same IP
# Rules: 100800, 100801 (Level 15, CRITICAL)
#
# Both rules share this same script, since they represent the same detection
# (MikroTik + SSH brute force correlated on source IP) against two different
# native Wazuh SSH rule IDs (5712, 5763) — the alert content is identical
# either way, only the underlying SSH rule differs.
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-CORRELATION"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields
    ar_extract_mitre_fields

    SRCIP=$(echo "$ALERT" | jq -r '.data.srcip // "N/A"')

    ar_geolocate_ip "$SRCIP"
    ar_count_occurrences "$SRCIP"
    ar_check_blocked_status "$SRCIP"

    SUBJECT="[WAZUH] CRITICAL - COORDINATED ATTACK - Level ${LEVEL}/15 - IP ${SRCIP} (${GEO_COUNTRY})"

    BODY="
========================================================
   WAZUH CRITICAL ALERT - COORDINATED ATTACK DETECTED
========================================================

ALERT DETAILS
-------------
Rule ID        : ${RULE_ID}
Description    : ${RULE_DESC}
Severity Level : ${LEVEL}/15  <- MAXIMUM
Fired Times    : ${FIRED}
Timestamp      : ${TIMESTAMP}
Dashboard      : ${WAZUH_DASHBOARD}

ATTACK INFORMATION
------------------
Source IP      : ${SRCIP}
Attack Vector  : MikroTik Brute Force + SSH Brute Force
AR Status      : ${AR_STATUS}
Occurrences    : ${OCCURRENCES} times in alerts.log

GEOLOCATION
-----------
Country        : ${GEO_COUNTRY}
City           : ${GEO_CITY}
Organization   : ${GEO_ORG}

MITRE ATT&CK
------------
Technique ID   : ${MITRE_ID}
Tactic         : ${MITRE_TACTIC}
Technique      : ${MITRE_TECH}

WAZUH AGENT
-----------
Agent Name     : ${AGENT}
Agent IP       : ${AGENT_IP}

IMMEDIATE ACTIONS REQUIRED
--------------------------
[1] Block IP on all routers: MikroTik -> Firewall -> DROP src=${SRCIP}
[2] Block IP on Graylog: iptables -A INPUT -s ${SRCIP} -j DROP
[3] Check logins: grep \"${SRCIP}\" /var/log/auth.log
[4] Verify no persistence: /etc/passwd, /etc/crontab, ~/.ssh/authorized_keys

FULL LOG
--------
${FULL_LOG}

========================================================
Wazuh SIEM - CRITICAL LEVEL - Immediate action required.
========================================================
"

    MM_TEXT="**COORDINATED ATTACK DETECTED**
**Source IP:** ${SRCIP} — ${GEO_CITY}, ${GEO_COUNTRY} (${GEO_ORG})
**Attack:** MikroTik Brute Force + SSH Brute Force from SAME IP
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15 <- MAXIMUM
**Fired:** ${FIRED} times | **Total occurrences:** ${OCCURRENCES}
**AR Status:** ${AR_STATUS}
**Timestamp:** ${TIMESTAMP}
**Agent:** ${AGENT} (${AGENT_IP})

**MITRE ATT&CK**
Technique: ${MITRE_ID} — ${MITRE_TECH}
Tactic: ${MITRE_TACTIC}

**IMMEDIATE ACTION REQUIRED:**
- Block IP ${SRCIP} on all routers
- Block IP ${SRCIP} on Graylog server
- Check for successful logins
- Verify no persistence established

Dashboard: ${WAZUH_DASHBOARD}"

    ar_send_mail "AR-CORRELATION" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-CORRELATION" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-CORRELATION" "DELETE action"
fi

exit 0
