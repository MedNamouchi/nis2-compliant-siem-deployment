#!/bin/bash
# =============================================================================
# Wazuh Active Response — MikroTik brute-force notification
# Rule: 100302 (5+ auth failures from same IP within 60s)
# Enriched with geolocation, occurrence count, block status, and MITRE mapping.
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-BRUTEFORCE"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields
    ar_extract_mitre_fields

    ROUTER_NAME=$(echo "$ALERT" | jq -r '.data.router_name // "Unknown"')
    SRCIP=$(echo "$ALERT"       | jq -r '.data.srcip       // "N/A"')
    DSTUSER=$(echo "$ALERT"     | jq -r '.data.dstuser     // "N/A"')
    APP=$(echo "$ALERT"        | jq -r '.data.app          // "N/A"')

    ar_geolocate_ip "$SRCIP"
    ar_count_occurrences "$SRCIP"
    ar_check_blocked_status "$SRCIP"

    DASHBOARD_LINK="${WAZUH_DASHBOARD}/app/security-alerts"

    SUBJECT="[WAZUH] BRUTE FORCE MikroTik - Level ${LEVEL} - Router ${ROUTER_NAME} - IP ${SRCIP} (${GEO_COUNTRY})"

    BODY="
========================================================
   WAZUH SECURITY ALERT - MIKROTIK BRUTE FORCE DETECTED
========================================================

ALERT DETAILS
-------------
Rule ID        : ${RULE_ID}
Description    : ${RULE_DESC}
Severity Level : ${LEVEL}/15
Fired Times    : ${FIRED}
Timestamp      : ${TIMESTAMP}
Dashboard      : ${DASHBOARD_LINK}

ATTACK INFORMATION
------------------
Router         : ${ROUTER_NAME}
Source IP      : ${SRCIP}
Target User    : ${DSTUSER}
Access Method  : ${APP}
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

RECOMMENDED ACTIONS
-------------------
[1] Block IP immediately : iptables -A INPUT -s ${SRCIP} -j DROP
[2] Check router logs    : MikroTik -> Log -> Filter by IP ${SRCIP}
[3] Verify user account  : Check if '${DSTUSER}' is still active
[4] Restrict access      : Limit Winbox/SSH to trusted IPs only

FULL LOG (extract)
------------------
${FULL_LOG}

========================================================
This alert was generated automatically by Wazuh SIEM.
Do not reply to this email.
========================================================
"

    MM_TEXT="**BRUTE FORCE DETECTED**
**Router:** ${ROUTER_NAME}
**Source IP:** ${SRCIP} — ${GEO_CITY}, ${GEO_COUNTRY} (${GEO_ORG})
**Target User:** ${DSTUSER}
**Access Method:** ${APP}
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15
**Fired:** ${FIRED} times | **Total occurrences:** ${OCCURRENCES}
**AR Status:** ${AR_STATUS}
**Timestamp:** ${TIMESTAMP}
**Agent:** ${AGENT} (${AGENT_IP})

**MITRE ATT&CK**
Technique: ${MITRE_ID} — ${MITRE_TECH}
Tactic: ${MITRE_TACTIC}

Dashboard: ${DASHBOARD_LINK}"

    ar_send_mail "AR-BRUTEFORCE" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-BRUTEFORCE" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-BRUTEFORCE" "DELETE action - no cleanup needed"
fi

exit 0
