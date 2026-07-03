# Phase 0 — Scoping

## Context

Initial engagement phase to define the deployment scope before any infrastructure work begins. The goal: confirm what is being built, on what, and against which regulatory baseline — before writing a single line of configuration.

## Infrastructure provided

| Item | Detail |
|---|---|
| Servers | Two virtual machines, provisioned bare (no OS-level configuration beyond base install) |
| Operating System | Ubuntu Server 24.04 LTS |
| Network access | VPN connection to the client's network; both servers reside on the same subnet |
| Initial firewall state | Only SSH (22/tcp) reachable; all other ports closed by default |

## Role assignment

| Server | Role |
|---|---|
| Server A | Graylog stack — MongoDB, Graylog Data Node, Graylog Server |
| Server B | Wazuh stack — Manager, Indexer, Dashboard (all-in-one) |

## Log source

Network equipment: **MikroTik routers** (RouterOS), exporting logs in CEF format over TLS.

## Regulatory classification

The client has been confirmed as an **important entity** under the NIS2 Directive (EU 2022/2555, Article 3). This classification determines:

- The applicable incident-notification deadlines under Article 23 (24h early warning, 72h detailed notification, 1-month final report)
- The baseline set of risk-management measures required under Article 21

## Naming and addressing strategy

No internal DNS is available on the client's network. To avoid hard-coding IP addresses throughout every service configuration file — and to limit the operational impact of any future re-addressing — internal hostnames are resolved locally via `/etc/hosts` on both servers:

```
<server-A-ip>   siem-graylog.internal
<server-B-ip>   siem-wazuh.internal
```

Service configurations (Graylog, Wazuh, rsyslog) reference these hostnames rather than raw IP addresses wherever the software supports it.

## Outcome

Scope confirmed and validated before proceeding to Phase 1 (infrastructure hardening). No component installation took place during this phase.

---

**Next phase**: [01 — Infrastructure Hardening](../01-infrastructure-hardening/)
