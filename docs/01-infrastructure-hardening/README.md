# Phase 1 — Infrastructure Hardening

## Objective

Establish a common security baseline on both servers before installing any SIEM component. No service is exposed to the network until this baseline is in place.

## Applied identically to both servers

### 1. System updates

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Ensures the latest kernel and security patches are applied before any service is installed on top.

### 2. Time synchronization

Accurate, synchronized timestamps are required to correlate events across MikroTik, Graylog, and Wazuh — without it, event correlation across the pipeline is unreliable.

```bash
sudo apt install -y chrony
sudo systemctl enable --now chrony
chronyc tracking
```

### 3. Firewall

Default-deny inbound policy, ports opened only as strictly required by each service (detailed per-server below).

```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw enable
```

### 4. Brute-force protection

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
```

Protects SSH against automated credential-guessing attempts, using default jail configuration.

### 5. Administrative access

A dedicated account with `sudo` privileges is used for all operations — no direct `root` usage. This provides per-action traceability, a requirement supporting NIS2 Article 21.2.d (access control).

```bash
sudo -l -U <admin-user>
```

**Open item**: SSH key-based authentication and disabling `root` login are deferred to project close-out and tracked in [07 — Maintenance Procedures](../07-maintenance-procedures/).

### 6. Internal hostname resolution

```bash
echo "<server-A-ip>   siem-graylog.internal" | sudo tee -a /etc/hosts
echo "<server-B-ip>   siem-wazuh.internal" | sudo tee -a /etc/hosts
```

See [00 — Scoping](../00-scoping/) for the rationale.

## Per-server port allocation

| Server | Port | Purpose |
|---|---|---|
| Graylog server | 6514/tcp | Syslog TLS input, MikroTik → Graylog |
| Graylog server | 9000/tcp | Graylog web interface (admin access) |
| Wazuh server | 1514/tcp | Agent → Manager, restricted to the Graylog server's IP |
| Wazuh server | 1515/tcp | Agent enrollment, restricted to the Graylog server's IP |
| Wazuh server | 443/tcp | Wazuh Dashboard (admin access) |

Example — Wazuh server firewall rules, agent ports scoped to a single source rather than opened broadly:

```bash
sudo ufw allow from <graylog-server-ip> to any port 1514 proto tcp
sudo ufw allow from <graylog-server-ip> to any port 1515 proto tcp
sudo ufw allow 443/tcp
```

## NIS2 relevance

This phase directly supports **Article 21.2.g (basic cyber hygiene)**: patched systems, time-synchronized logging, a restrictive firewall posture, and brute-force protection — all established before any service exposure.

## Outcome

Both servers hardened to a common baseline. Verified: system up to date, `chrony` synchronized, `ufw` active with only required ports open, `fail2ban` running.

---

**Previous phase**: [00 — Scoping](../00-scoping/)
**Next phase**: [02 — Graylog Setup](../02-graylog-setup/)
