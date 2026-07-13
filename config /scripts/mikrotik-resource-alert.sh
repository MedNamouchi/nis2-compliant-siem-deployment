#!/bin/bash
# =============================================================================
# Wazuh Active Response — MikroTik CPU/Memory high usage notification
# Rules: 100500 (CPU high), 100501 (Memory high)
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-RESOURCE"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields

    ROUTER_NAME=$(echo "$ALERT"    | jq -r '.data.router_name    // "Unknown"')
    RESOURCE_TYPE=$(echo "$ALERT"  | jq -r '.data.resource_type  // "N/A"')
    RESOURCE_VAL=$(echo "$ALERT"   | jq -r '.data.resource_value // "N/A"')

    SUBJECT="[WAZUH] ${RESOURCE_TYPE} HIGH - Router ${ROUTER_NAME} - ${RESOURCE_VAL}% usage"

    BODY="
========================================================
   WAZUH ALERT - MIKROTIK ${RESOURCE_TYPE} HIGH
========================================================
ALERT DETAILS
-------------
Rule ID        : ${RULE_ID}
Description    : ${RULE_DESC}
Severity Level : ${LEVEL}/15
Fired Times    : ${FIRED}
Timestamp      : ${TIMESTAMP}
RESOURCE INFORMATION
--------------------
Router         : ${ROUTER_NAME}
Resource       : ${RESOURCE_TYPE}
Usage          : ${RESOURCE_VAL}%
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

    MM_TEXT="**${RESOURCE_TYPE} HIGH DETECTED**
**Router:** ${ROUTER_NAME}
**${RESOURCE_TYPE} Usage:** ${RESOURCE_VAL}%
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15
**Fired:** ${FIRED} times
**Timestamp:** ${TIMESTAMP}
**Agent:** ${AGENT} (${AGENT_IP})"

    ar_send_mail "AR-RESOURCE" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-RESOURCE" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-RESOURCE" "DELETE action - no cleanup needed"
fi

exit 0
