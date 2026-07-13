# Phase 4 — Wazuh Agent Integration

## Objective

Deploy and connect the Wazuh Agent on the Graylog server, as preparation for the future MikroTik log source. This phase does **not** cover MikroTik-side configuration (CEF export, TLS, Graylog input, rsyslog) — that work is tracked separately and will only begin once the MikroTik equipment is reachable over the client's VPN.

## What has been done

Only the Wazuh Agent deployment on the Graylog server has been completed so far (documented below).

## Status

| Item | Status |
|---|---|
| Wazuh Agent installed on the Graylog server | Done |
| Wazuh Agent enrolled and verified active | Done |

MikroTik-side integration (VPN connectivity, CEF/TLS export, Graylog input, rsyslog) is out of scope for this phase and is not yet started — see [Next steps](#next-steps) below.

## Wazuh Agent deployment (on the Graylog server)

The agent is installed on the Graylog server , since that is where `rsyslog` will write the local log file monitored via `<localfile>` (see [Architecture](../../README.md#architecture-overview)).

### 1. Add the Wazuh repository

```bash
sudo apt-get install -y gnupg apt-transport-https
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring \
  --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
sudo chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
  sudo tee -a /etc/apt/sources.list.d/wazuh.list
sudo apt-get update
```

### 2. Install with automatic enrollment

```bash
sudo WAZUH_MANAGER='siem-wazuh.internal' apt-get install -y wazuh-agent
```

The internal hostname (rather than a raw IP address) is used here, consistent with the addressing strategy established in [Phase 0](../00-scoping/).

### 3. Start and pin the version

```bash
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo apt-mark hold wazuh-agent
```

Pinning the package prevents an unattended update from silently breaking compatibility with the Manager version.

## Validation

```bash
sudo /var/ossec/bin/wazuh-control status
```

Confirmed in the Wazuh Dashboard under **Agents management → Summary**: the new agent is listed with status `Active`.

## NIS2 relevance

A verified, monitored agent-to-manager connection is a prerequisite for the incident-detection capabilities required under **Article 21.2.b**; deploying and validating it ahead of the live log source ensures no detection gap once MikroTik traffic begins.

## Next steps

MikroTik integration (CEF export over TLS, Graylog Syslog TCP/TLS input, output plugin, rsyslog, end-to-end test) is a separate piece of work, not yet scheduled, pending the MikroTik equipment being reachable over the client's VPN. It will be documented in its own phase once that work begins.

The custom decoders and detection rules that will interpret MikroTik events once they arrive have already been reviewed and prepared ahead of time — see [05 — Detection Engineering](../05-detection-engineering/).

---

**Previous phase**: [03 — Wazuh Setup](../03-wazuh-setup/)
**Next phase**: [05 — Detection Engineering](../05-detection-engineering/)
