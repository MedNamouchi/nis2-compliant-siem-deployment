# NIS2-Compliant SIEM Deployment

A production Security Information and Event Management (SIEM) pipeline, designed and deployed end-to-end for a client of OFIR LTD, in support of the client's compliance obligations under the NIS2 Directive (EU 2022/2555).

**Pipeline**: MikroTik network equipment → Graylog → Wazuh → OpenSearch Dashboards, correlating network and endpoint events with MITRE ATT&CK-mapped detection rules.

This deployment builds on, and improves upon, an architecture originally designed and validated in-house at OFIR: [SIEM-MikroTik-Wazuh-Graylog](https://github.com/MedNamouchi/SIEM-MikroTik-Wazuh-Graylog).

---

## What this project demonstrates

- End-to-end SIEM architecture and deployment, from bare virtual machines to a fully operational detection pipeline
- Infrastructure hardening aligned with baseline cyber-hygiene requirements (NIS2 Article 21.2.g)
- Real-world troubleshooting of a production-grade log collection and correlation stack (MongoDB, OpenSearch, Wazuh, Graylog)
- Regulatory-driven documentation: every technical measure is traceable to a specific NIS2 Article 21 requirement
- A reproducible, phase-by-phase methodology: **implement → validate → document**

## Architecture overview

```
MikroTik Routers
      │  CEF over TLS (port 6514)
      ▼
Graylog — Syslog TCP/TLS Input
      │  Syslog output plugin
      ▼
rsyslog (127.0.0.1:514/tcp) → local log file
      │  monitored via <localfile>
      ▼
Wazuh Agent
      │  AES-256 encrypted
      ▼
Wazuh Manager → Indexer → Dashboard
```

## Repository structure

```
.
├── docs/                          # Step-by-step technical documentation (Markdown + screenshots)
│   ├── 00-scoping/
│   ├── 01-infrastructure-hardening/
│   ├── 02-graylog-setup/
│   ├── 03-wazuh-setup/
│   ├── 04-mikrotik-integration/
│   ├── 05-detection-engineering/
│   ├── 06-active-response/
│   └── 07-maintenance-procedures/
└── configs/                       # Versioned configuration files (decoders, rules, scripts)
    ├── decoders/
    ├── rules/
    └── scripts/
```

The formal NIS2 compliance report (architecture rationale, Article 21 requirements mapping, regulatory notification procedures) is maintained as a separate deliverable provided directly to the client and is not included in this repository.

## Methodology

Each phase follows the same cycle: **implement → validate → document**. Nothing is written up until it has been tested and confirmed working against the real infrastructure — this repository reflects what was actually built, not a plan.

## Progress

| Phase | Status |
|---|---|
| 00 — Scoping | Done |
| 01 — Infrastructure hardening | Done |
| 02 — Graylog (MongoDB, Data Node, Server) | Done |
| 03 — Wazuh (Manager, Indexer, Dashboard) | Done |
| 04 — MikroTik integration | In progress |
| 05 — Detection engineering (MITRE ATT&CK mapping) | Not started |
| 06 — Active response automation | Not started |
| 07 — Maintenance procedures | Not started |

## Regulatory context

The client is classified as an **important entity** under the NIS2 Directive, subject to Article 21 risk-management requirements and Article 23 incident-notification deadlines (24h early warning, 72h notification, 1-month final report).

## About

Deployed by **Mohamed Amine Namouchi**, Cybersecurity Engineer, as part of a professional engagement at OFIR LTD.

## Security note

This is a public repository. All client-identifying information — company name, real IP addresses, hostnames, and credentials — has been redacted or replaced with placeholders throughout. Real values are kept in a private internal document, never in this repository.
