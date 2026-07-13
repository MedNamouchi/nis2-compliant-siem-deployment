#!/bin/bash
# =============================================================================
# Wazuh Active Response — Agent disconnection notification
# Rules: 100600 (agent stopped, graceful), 100601 (agent disconnected unexpectedly)
# =============================================================================

source "$(dirname "$0")/ar-config.sh"
source "$(dirname "$0")/ar-common.sh"

ar_read_input "AR-AGENT"

if [ "$COMMAND" = "add" ]; then
    ar_extract_common_fields

    AGENT_ID=$(echo "$ALERT" | jq -r '.agent.id // "unknown"')

    SUBJECT="[WAZUH] AGENT DOWN - ${AGENT} (${AGENT_IP}) - Level ${LEVEL}"

    BODY="
========================================================
   WAZUH ALERT - AGENT DISCONNECTED
========================================================

ALERT DETAILS
-------------
Rule ID        : ${RULE_ID}
Description    : ${RULE_DESC}
Severity Level : ${LEVEL}/15
Fired Times    : ${FIRED}
Timestamp      : ${TIMESTAMP}

AGENT INFORMATION
-----------------
Agent Name     : ${AGENT}
Agent ID       : ${AGENT_ID}
Agent IP       : ${AGENT_IP}

IMPACT ASSESSMENT
-----------------
If the disconnected agent is the Graylog server:
  -> MikroTik logs are NO LONGER forwarded to Wazuh
  -> Brute-force detection is DISABLED
  -> Active response is DISABLED
  -> Check the Graylog server immediately

For any other agent:
  -> System monitoring for that host is DOWN
  -> Check server status immediately

RECOMMENDED ACTIONS
-------------------
[1] Check server status  : ping ${AGENT_IP}
[2] Check agent service  : systemctl status wazuh-agent
[3] Restart if needed    : systemctl restart wazuh-agent
[4] Check logs           : tail -50 /var/ossec/logs/ossec.log

FULL LOG (extract)
------------------
${FULL_LOG}

========================================================
This alert was generated automatically by Wazuh SIEM.
Do not reply to this email.
========================================================
"

    MM_TEXT="**AGENT DISCONNECTED**
**Agent Name:** ${AGENT}
**Agent ID:** ${AGENT_ID}
**Agent IP:** ${AGENT_IP}
**Rule:** ${RULE_ID} - ${RULE_DESC}
**Level:** ${LEVEL}/15
**Fired:** ${FIRED} times
**Timestamp:** ${TIMESTAMP}

If this is the Graylog server's agent:
-> MikroTik log forwarding is DOWN
-> Brute-force detection is DISABLED
-> Check the Graylog server immediately!"

    ar_send_mail "AR-AGENT" "$SUBJECT" "$BODY"
    ar_send_mattermost "AR-AGENT" "$MM_TEXT"
fi

if [ "$COMMAND" = "delete" ]; then
    ar_log "AR-AGENT" "DELETE action - no cleanup needed"
fi

exit 0
