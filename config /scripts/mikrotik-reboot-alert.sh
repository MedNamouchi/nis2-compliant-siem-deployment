#!/bin/bash
# =============================================================================
# Wazuh Active Response — MikroTik reboot / crash notification
# Rules: 100400 (conscious reboot), 100401 (unexpected reboot), 100402 (crash cause)
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-REBOOT"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields

    ROUTER_NAME=$(echo "$ALERT" | jq -r '.data.router_name // "Unknown"')

    case "$RULE_ID" in
        100400)
            EVENT="CONSCIOUS REBOOT"
            USER=$(echo "$ALERT"   | jq -r '.data.dstuser        // "N/A"')
            SRCIP=$(echo "$ALERT"  | jq -r '.data.srcip          // "N/A"')
            METHOD=$(echo "$ALERT" | jq -r '.data.reboot_method  // "N/A"')
            EXTRA_INFO="User          : ${USER}
Source IP     : ${SRCIP}
Method        : ${METHOD}"
            MM_EXTRA_INFO="**User:** ${USER}
**Source IP:** ${SRCIP}
**Method:** ${METHOD}"
            ;;
        100401)
            EVENT="UNEXPECTED REBOOT"
            EXTRA_INFO="Cause         : No user triggered — unplanned reboot"
            MM_EXTRA_INFO="**Cause:** No user triggered — unplanned reboot"
            ;;
        *)
            EVENT="CRASH / WATCHDOG"
            CAUSE=$(echo "$ALERT" | jq -r '.data.extra_data // "N/A"')
            EXTRA_INFO="Cause         : ${CAUSE}"
            MM_EXTRA_INFO="**Cause:** ${CAUSE}"
            ;;
    esac

    SUBJECT="[WAZUH] ${EVENT} MikroTik - Level ${LEVEL} - Router ${ROUTER_NAME}"

    BODY="
========================================================
   WAZUH SECURITY ALERT - MIKROTIK ${EVENT}
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
${EXTRA_INFO}
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

    MM_TEXT="**${EVENT}**
**Router:** ${ROUTER_NAME}
${MM_EXTRA_INFO}
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15
**Fired:** ${FIRED} times
**Timestamp:** ${TIMESTAMP}
**Agent:** ${AGENT} (${AGENT_IP})"

    ar_send_mail "AR-REBOOT" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-REBOOT" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-REBOOT" "DELETE action - no cleanup needed"
fi

exit 0
