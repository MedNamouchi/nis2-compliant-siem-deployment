# Phase 5 — Detection Engineering

## Objective

Adapt the MikroTik decoders and detection rules validated in-house at OFIR to this client's deployment: understand each rule's logic, remove client-inapplicable assumptions, standardize inconsistencies, and map detections to MITRE ATT&CK.

Configuration files: [`config/decoders/mikrotik-decoders.xml`](../../config/decoders/mikrotik-decoders.xml), [`config/rules/mikrotik-rules.xml`](../../config/rules/mikrotik-rules.xml).

## Detection strategy

Before describing individual decoders and rules, it is worth explaining the reasoning behind the overall detection architecture — the design choices exist for specific reasons, not just because that is how the reference implementation happened to be written.

### Why decoders and rules are separate layers

Wazuh splits log processing into two distinct stages: **decoders** parse an unstructured log line into named fields (who, what, from where), and **rules** reason over those fields to decide whether something is worth alerting on, and how urgently. Keeping these separate means the same decoded event (e.g. "authentication failure from IP X on router Y") can feed multiple, independent detection logics — a single failure is low-severity noise, but five failures from the same IP within 60 seconds becomes a brute-force alert, and the same event contributes differently again to a cross-source correlation rule. Coupling parsing and detection logic into a single step would mean rewriting the parsing every time a new detection angle is needed on the same data.

### Why a parent/child decoder hierarchy

The parent decoder (`mikrotik_graylog_identity`) exists to do two things cheaply: identify that a log line is a MikroTik event at all, and extract a minimal baseline (router name, log type) that is useful even if no more specific child decoder matches. This acts as a safety net — an unrecognized MikroTik log type is still attributed to the correct router and categorized broadly, rather than being dropped or left completely unstructured. Child decoders then handle the specific grammar of each known event type. The tradeoff (discussed in the decoder section below) is that child decoders cannot inherit the parent's captured fields — a limitation of the underlying engine, not a design choice made here — so some duplication across files is unavoidable.

### Why rule severity levels are graduated, not binary

Rules are not simply "alert" or "don't alert" — they carry a severity level (3 to 15 in this ruleset) reflecting how actionable or urgent an event is on its own. A single login is level 3 (informational, useful for audit trails but not urgent); a confirmed brute-force pattern is level 10; a coordinated attack detected across two independent log sources (MikroTik and SSH) is level 15. This gradation matters operationally: without it, a SOC analyst either drowns in low-value alerts treated with the same urgency as real incidents, or misses genuinely low-noise signals that only matter in aggregate. Graduated severity is what allows dashboards and notification thresholds to be tuned meaningfully instead of firing on everything equally.

### Why correlation rules exist on top of single-event rules

Several rules (port scan detection, brute force, password spraying, distributed attacks, MikroTik+SSH correlation) do not fire on a single log line — they use Wazuh's `frequency`/`timeframe` and `if_matched_sid` mechanisms to reason over patterns across multiple events. This reflects a basic detection-engineering principle: many attack techniques are only recognizable as a *sequence*, not as any single event in isolation. A single failed login is meaningless; the same failed login as the fifth in sixty seconds from one IP is a different story entirely. Building this into the ruleset, rather than relying on a human noticing a pattern across scattered alerts, is what makes the pipeline a detection system rather than just a log viewer.

### Why every rule is mapped to MITRE ATT&CK

Each detection rule carries a MITRE ATT&CK technique ID, not as decoration, but because it ties every alert back to a documented adversary behavior with known context (how it is typically used, what usually precedes or follows it). This is what allows the ruleset to be reasoned about as a coverage map — which adversary techniques are we actually positioned to detect on this infrastructure — rather than an arbitrary list of alerts, and is the basis for the NIS2 risk-analysis mapping in Section [NIS2 relevance](#nis2-relevance) below.

## Decoders

Ten PCRE2 decoders translate raw MikroTik syslog messages into structured fields (router name, event type, source/destination IP, action, etc.): one parent decoder (`mikrotik_graylog_identity`) providing message routing and baseline field extraction, and nine child decoders handling specific event types (authentication success/failure/logout, conscious and unconscious reboot, crash cause, configuration change, resource usage, firewall).

### Router name pattern standardization

The reference decoders captured the router hostname using inconsistent regular expressions between the parent decoder and its children — some accepted underscores, some did not, and all were restricted to uppercase letters only. This was standardized to a single pattern applied identically across all ten decoders:

```
([A-Za-z0-9_\-\.]+)
```

This is both a correctness fix — the client's naming convention was not confirmed at review time, so the pattern now accepts mixed case, underscores, hyphens, and dots — and a maintainability improvement: any future change to the naming pattern only needs to be reasoned about once, even though the Wazuh decoder engine still requires it to be applied to each decoder file individually. Child decoders do not inherit field captures from their parent; each independently re-matches the full message against its own regex.

## Detection rules

Wazuh correlation rules (ID range 100200–100801) were reviewed with the same principle: every rule referencing an OFIR-specific value was identified and either generalized or explicitly parked pending client-specific information, rather than copied as-is.

### Rules deferred pending client configuration

Two rules depend on values not yet known at the time of writing — the client's primary/critical router and the WireGuard VPN interface name — both to be defined during MikroTik configuration (a task scheduled separately). Rather than hard-coding the now-obsolete OFIR-specific values (a router hostname and interface name that will never occur in this client's environment, leaving the rule permanently inert without explanation), these rules are retained with explicit placeholder values and inline `ACTION REQUIRED` comments:

- **Rule 100203** (main router monitoring) — placeholder: `ROUTER_NAME_PLACEHOLDER`
- **Rule 100207** (VPN interface traffic) — placeholder: `VPN_INTERFACE_PLACEHOLDER`

### Correlation rules — dependency on native rule IDs

Rules 100800/100801 (MikroTik + SSH coordinated brute-force correlation) reference native Wazuh SSH rule IDs `5712` and `5763`. Configuration testing (`wazuh-analysisd -t`) validates XML syntax but does **not** verify that referenced rule IDs actually exist in the installed ruleset. Presence was confirmed manually:

```bash
sudo grep -r "id=\"5712\"\|id=\"5763\"" /var/ossec/ruleset/rules/
```

Both confirmed present in `0095-sshd_rules.xml` for Wazuh 4.14.6.

## MITRE ATT&CK mapping

| Rule group | Technique(s) |
|---|---|
| Firewall / external traffic | T1071 (Application Layer Protocol) |
| Port scan | T1046 (Network Service Discovery) |
| Authentication failure / brute force | T1110, T1110.001 (Brute Force) |
| Password spraying / distributed attack | T1110.003 |
| Successful login | T1078 (Valid Accounts) |
| Reboot / crash | T1529 (System Shutdown/Reboot) |
| Configuration change | T1562 (Impair Defenses) |
| Agent disconnected | T1562.001 |

## Validation

Configuration tested for syntax correctness before any Manager restart:

```bash
sudo /var/ossec/bin/wazuh-analysisd -t
```

## NIS2 relevance

The reviewed ruleset maps detected events to MITRE ATT&CK techniques, directly supporting the risk-analysis and detection-engineering expectations of **Article 21.2.a**.

## Outcome

Decoders standardized and validated. Rules generalized where possible, explicitly parked with documented placeholders where client-specific values are still pending. Ready for live MikroTik traffic once Phase 4's remaining steps are complete.

---

**Previous phase**: [04 — Wazuh Agent Integration](../04-wazuh-agent-integration/)
**Next phase**: [06 — Active Response](../06-active-response/)
