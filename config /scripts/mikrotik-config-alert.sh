#!/bin/bash
# =============================================================================
# Wazuh Active Response — MikroTik configuration change notification
# Rule: 100403 (config changed by a user)
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-CONFIG"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields

    ROUTER_NAME=$(echo "$ALERT" | jq -r '.data.router_name    // "Unknown"')
    USER=$(echo "$ALERT"        | jq -r '.data.dstuser        // "N/A"')
    SRCIP=$(echo "$ALERT"       | jq -r '.data.srcip          // "N/A"')
    METHOD=$(echo "$ALERT"      | jq -r '.data.access_method  // "N/A"')
    CHANGE=$(echo "$ALERT"      | jq -r '.data.extra_data     // "N/A"')

    SUBJECT="[WAZUH] CONFIG CHANGE MikroTik - Level ${LEVEL} - Router ${ROUTER_NAME} - User ${USER}"

    BODY="
========================================================
   WAZUH SECURITY ALERT - MIKROTIK CONFIG CHANGE
========================================================
ALERT DETAILS
-------------
Rule ID        : ${RULE_ID}
Description    : ${RULE_DESC}
Severity Level : ${LEVEL}/15
Fired Times    : ${FIRED}
Timestamp      : ${TIMESTAMP}
EVENT INFORMATION
-----------------
Router         : ${ROUTER_NAME}
User           : ${USER}
Source IP      : ${SRCIP}
Access Method  : ${METHOD}
Change         : ${CHANGE}
WAZUH AGENT
-----------
Agent Name     : ${AGENT}
Agent IP       : ${AGENT_IP}
FULL LOG (extract)
------------------
${FULL_LOG}
========================================================
This alert was generated automatically by Wazuh SIEM.
Do not reply to this email.
========================================================
"

    MM_TEXT="**CONFIG CHANGE DETECTED**
**Router:** ${ROUTER_NAME}
**User:** ${USER}
**Source IP:** ${SRCIP}
**Access Method:** ${METHOD}
**Change:** ${CHANGE}
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15
**Fired:** ${FIRED} times
**Timestamp:** ${TIMESTAMP}
**Agent:** ${AGENT} (${AGENT_IP})"

    ar_send_mail "AR-CONFIG" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-CONFIG" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-CONFIG" "DELETE action - no cleanup needed"
fi

exit 0
