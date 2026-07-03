# Phase 3 — Wazuh Setup

## Objective

Deploy the analysis and detection layer: Wazuh Manager, Indexer, and Dashboard, on the dedicated Wazuh server defined in [Phase 0](../00-scoping/).

## Components and versions

| Component | Version |
|---|---|
| Wazuh (Manager, Indexer, Dashboard) | 4.14.6 |

## 1. Installation

```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
sudo bash wazuh-install.sh -a
```

The all-in-one installer deploys the Wazuh Indexer (OpenSearch-based), Manager, and Dashboard in a single pass, generating internal certificates and a credentials file (`wazuh-install-files.tar`) containing the admin password and internal service credentials.

**Note**: verify available disk space and RAM before installing — the Indexer component alone can require over 1 GB during installation, on top of the Manager, Dashboard, and Filebeat packages.

## 2. Retrieving credentials

```bash
sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
```

This file lists the initial passwords for all internal service accounts (`admin`, `kibanaserver`, `wazuh-wui`, etc.). Store it securely and remove it from the server once credentials have been recorded elsewhere — it is excluded from version control via `.gitignore`.

## 3. Credential management across components

**Configuration remark**: the Wazuh stack maintains credentials in two independent locations, both of which must be kept in sync whenever a password is rotated:

1. **Dashboard-to-Indexer connection** — stored in the Dashboard's OpenSearch keystore:

```bash
echo '<new-password>' | sudo /usr/share/wazuh-dashboard/bin/opensearch-dashboards-keystore \
  --allow-root add -f --stdin opensearch.password
```

2. **Dashboard-to-Manager API connection** — stored in `/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml`:

```yaml
hosts:
  - default:
      url: https://127.0.0.1
      port: 55000
      username: wazuh-wui
      password: "<new-password>"
      run_as: true
```

Rotating a password in the Indexer alone (e.g. via `wazuh-passwords-tool.sh`) does **not** propagate to either location automatically. After any password rotation, restart the affected services and verify connectivity directly rather than relying on the Dashboard UI alone:

```bash
# Verify Indexer authentication
curl -k -u admin:'<password>' https://localhost:9200

# Verify Manager API authentication
curl -k -u wazuh-wui:'<password>' -X POST "https://localhost:55000/security/user/authenticate"
```

A successful response from both confirms credentials are correctly synchronized before trusting the Dashboard's connection status indicator.

## 4. Rotating the API password (`wazuh-wui`)

```bash
sudo /var/ossec/bin/wazuh-keystore -f api -k username -v wazuh-wui
sudo /var/ossec/bin/wazuh-keystore -f api -k password -v '<new-password>'
sudo systemctl restart wazuh-manager
```

This updates the Manager-side credential store. Remember this is separate from the Dashboard-side `wazuh.yml` update in step 3 — both are required for the Dashboard's Server API connection to show `Online`.

## Validation

```bash
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard --no-pager
```

In the Dashboard, under **Server APIs**, confirm the `default` connection status shows `Online` rather than `Offline` / `Invalid credentials`.

## NIS2 relevance

The credential-synchronization procedure documented above is part of the operational runbook supporting **Article 21.2.b (incident handling)** — ensuring the platform's own access controls remain consistent and auditable after routine maintenance operations such as password rotation.

## Outcome

Wazuh Manager, Indexer, and Dashboard operational, with API connectivity verified independently of the Dashboard UI.

---

**Previous phase**: [02 — Graylog Setup](../02-graylog-setup/)
**Next phase**: [04 — MikroTik Integration](../04-mikrotik-integration/)
