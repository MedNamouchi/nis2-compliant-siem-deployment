# Phase 6 — Active Response

## Objective

Adapt the Mattermost/email active-response scripts validated in-house at OFIR to this client's deployment: eliminate code duplication across scripts, remove hardcoded secrets, fix a dormant bug, and generalize logic that assumed OFIR-specific infrastructure.

Scripts: [`config/scripts/`](../../config/scripts/).

## Design approach

The original OFIR scripts (seven independent shell scripts, one per alert type) shared roughly 70% identical code: JSON input parsing, structured logging, mail delivery, and Mattermost delivery were each re-implemented from scratch in every file. This was refactored into a shared-library pattern:

- **`ar-common.sh`** — reusable functions for logging, input parsing, common/MITRE field extraction, IP enrichment (geolocation, occurrence count, block status), and delivery (mail, Mattermost). Sourced by every alert script.
- **`ar-config.sh`** — deployment-specific configuration (notification channels, dashboard URL, log paths). Sourced before `ar-common.sh`. The real file is never committed to version control (see [Secrets handling](#secrets-handling) below); [`ar-config.sh.example`](../../configs/scripts/ar-config.sh.example) documents its structure with placeholder values.
- **Seven alert scripts**, each reduced to only the logic specific to its event type (which fields to extract, how to format the message) — the surrounding plumbing that used to be duplicated seven times now lives in one place.

This mirrors the same reasoning applied to the decoders in [Phase 5](../05-detection-engineering/): shared logic factored out once is easier to reason about and to fix than the same logic copy-pasted with small, hard-to-track divergences.

## Scripts

| Script | Triggering rule(s) | Purpose |
|---|---|---|
| `mikrotik-auth-alert.sh` | 100300, 100303 | Login / logout notification |
| `mikrotik-bruteforce-alert.sh` | 100302 | Brute-force detection, enriched with geolocation, occurrence count, block status |
| `mikrotik-config-alert.sh` | 100403 | Configuration change notification |
| `mikrotik-reboot-alert.sh` | 100400, 100401, 100402 | Conscious reboot, unexpected reboot, and crash-cause notification |
| `mikrotik-resource-alert.sh` | 100500, 100501 | CPU / memory high-usage notification |
| `mikrotik-correlation-alert.sh` | 100800, 100801 | Coordinated MikroTik + SSH brute-force correlation (CRITICAL) |
| `agent-down-alert.sh` | 100600, 100601 | Wazuh agent disconnection notification |

## Corrections made during review


### Mail and Mattermost delivery made independent

In the reference scripts, a mail delivery failure (`exit 1`) prevented Mattermost delivery from being attempted at all — the two channels were coupled through the script's control flow rather than by design. This was changed so each channel is attempted independently: if one is down, the other still delivers. This was validated directly during testing (see [Validation](#validation) below), where a missing mail transport agent did not prevent Mattermost delivery.

### Two correlation rules merged into one script

Rules 100800 and 100801 detect the same condition (coordinated MikroTik + SSH brute force from the same IP) against two different native Wazuh SSH rule IDs; their alert content is identical. Rather than maintaining duplicate scripts, both rules are bound to a single `mikrotik-correlation-alert.sh`.

## Secrets handling

`ar-config.sh` (containing the real Mattermost webhook, notification addresses, and dashboard URL) is deployed directly to `/var/ossec/etc/active-response/bin/` on the Wazuh server and excluded from version control via `.gitignore`. File permissions are set to restrict read access to the `wazuh` group only:

```bash
sudo chown root:wazuh /var/ossec/etc/active-response/bin/ar-config.sh
sudo chmod 640 /var/ossec/etc/active-response/bin/ar-config.sh
```

All alert scripts are deployed with execute permissions restricted the same way:

```bash
sudo chown root:wazuh /var/ossec/etc/active-response/bin/<script>.sh
sudo chmod 750 /var/ossec/etc/active-response/bin/<script>.sh
```

## Wiring rules to scripts (`ossec.conf`)

Each script is registered as a Wazuh command and bound to its triggering rule ID(s):

```xml
<command>
  <name>mikrotik-auth-alert</name>
  <executable>mikrotik-auth-alert.sh</executable>
  <timeout_allowed>no</timeout_allowed>
</command>

<active-response>
  <command>mikrotik-auth-alert</command>
  <location>local</location>
  <rules_id>100300,100303</rules_id>
</active-response>
```

The same pattern is repeated for all seven scripts (see the [Scripts](#scripts) table above for the rule ID groupings).

## Validation

Configuration syntax:
```bash
sudo /var/ossec/bin/wazuh-analysisd -t
```

Decoder and rule matching, without triggering active response:
```bash
echo 'msg: TEST-ROUTER[INFO]: user testuser logged in from 192.168.1.99 via winbox' | sudo /var/ossec/bin/wazuh-logtest
```

Active-response execution, tested directly against a script with a synthetic alert payload (bypassing the decoder/rule engine, to validate script logic and delivery independently):

```bash
echo '{"command": "add", "parameters": {"alert": {"rule": {"id": "100300", ...}, "data": {...}, "agent": {...}}}}' \
  | sudo /var/ossec/etc/active-response/bin/mikrotik-auth-alert.sh

sudo tail -20 /var/ossec/logs/active-responses.log
```

## Mail relay configuration
 
Mail delivery requires a mail transfer agent (Postfix) configured with an outbound SMTP relay, since a server sending mail directly (without a relay) is typically rejected or flagged as spam by major providers due to poor IP reputation. A dedicated OFIR mailbox was provisioned for this purpose rather than using a personal email account -- appropriate for a client-facing production system, since access to a dedicated organizational account is not tied to any individual.
 
### Setup
 
```bash
sudo apt install -y postfix mailutils
```
 
Configuration (`/etc/postfix/main.cf`):
 
```
relayhost = [mail.ofir.hr]:465
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_tls_wrappermode = yes
smtp_tls_security_level = encrypt
```
 
Authentication credentials (`/etc/postfix/sasl_passwd`, excluded from version control):
 
```
[mail.ofir.hr]:465    <dedicated-mailbox>:<password>
```
 
```bash
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl enable --now postfix
```
 
**Port 465 requires explicit TLS wrapper mode.** Port 465 (SMTPS) uses implicit TLS — the connection is encrypted from the first byte — as opposed to port 587 (STARTTLS), which begins in plaintext and upgrades to TLS mid-connection. Postfix requires `smtp_tls_wrappermode = yes` for port 465, but this setting alone produced a configuration warning and failed deliveries (`relay=none, server unavailable`) until `smtp_tls_security_level = encrypt` was also set. Both parameters are required together for port 465; omitting either results in a delivery failure that is not obviously related to TLS configuration from the error message alone.
 
### Validation
 
```bash
echo "Test message" | mail -s "Test" <recipient>
sudo tail -20 /var/log/mail.log
```
 
A successful relay shows `status=sent (250 OK ...)` with `relay=mail.ofir.hr[...]:465` in the log -- confirming the message was accepted by the relay for final delivery.
 

## NIS2 relevance
 
Automated, multi-channel incident notification (mail and chat) with contextual enrichment (MITRE mapping, geolocation, prior-occurrence count) directly supports **Article 21.2.b (incident handling)** — ensuring detected events reach a human promptly and with enough context for triage, and **Article 23** notification-timeline compliance by minimizing detection-to-awareness delay.
 
## Outcome
 
Seven active-response scripts refactored, deployed, and validated for configuration syntax, Mattermost delivery, and mail delivery. Recipient address(es) for alerts remain to be finalized (see [Open item: alert recipients](#open-item-alert-recipients)). Full end-to-end validation will follow once live MikroTik traffic is available.
 
---
 
**Previous phase**: [05 — Detection Engineering](../05-detection-engineering/)
**Next phase**: [07 — Maintenance Procedures](../07-maintenance-procedures/)
 
 
