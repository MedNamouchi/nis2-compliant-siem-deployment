#!/bin/bash
# =============================================================================
# Wazuh Active Response — MikroTik login / logout notification
# Rules: 100300 (login success), 100303 (logout)
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-AUTH"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields

    ROUTER_NAME=$(echo "$ALERT" | jq -r '.data.router_name // "Unknown"')
    SRCIP=$(echo "$ALERT"       | jq -r '.data.srcip       // "N/A"')
    APP=$(echo "$ALERT"         | jq -r '.data.app         // "N/A"')
    USER=$(echo "$ALERT"        | jq -r '.data.user // .data.dstuser // "N/A"')

    if [ "$RULE_ID" = "100300" ]; then
        EVENT="LOGIN"
    else
        EVENT="LOGOUT"
    fi

    SUBJECT="[WAZUH] ${EVENT} MikroTik - Level ${LEVEL} - Router ${ROUTER_NAME} - User ${USER}"

    BODY="
========================================================
   WAZUH SECURITY ALERT - MIKROTIK ${EVENT} DETECTED
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
Source IP      : ${SRCIP}
User           : ${USER}
Access Method  : ${APP}
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

    MM_TEXT="**${EVENT} DETECTED**
**Router:** ${ROUTER_NAME}
**User:** ${USER}
**Source IP:** ${SRCIP}
**Access Method:** ${APP}
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15
**Fired:** ${FIRED} times
**Timestamp:** ${TIMESTAMP}
**Agent:** ${AGENT} (${AGENT_IP})"

    ar_send_mail "AR-AUTH" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-AUTH" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-AUTH" "DELETE action - no cleanup needed"
fi

exit 0
