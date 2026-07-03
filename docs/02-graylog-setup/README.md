# Phase 2 — Graylog Setup

## Objective

Deploy the log ingestion layer: MongoDB, Graylog Data Node (embedded OpenSearch), and Graylog Server, on the dedicated Graylog server defined in [Phase 0](../00-scoping/).

## Components and versions

| Component | Version |
|---|---|
| MongoDB | 8.0.26 |
| Graylog Data Node | 7.0.9 (embedded OpenSearch 2.19.3) |
| Graylog Server | 7.0.9 |

## 1. MongoDB

```bash
sudo apt install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt update
sudo apt install -y mongodb-org
sudo apt-mark hold mongodb-org
```

**Note**: MongoDB 8.0 requires an AVX-capable CPU. On virtualized environments without AVX support, use MongoDB 7.0 instead to avoid a `signal=ILL` crash at startup. Verify with:

```bash
grep -c avx /proc/cpuinfo
```

Network configuration (`/etc/mongod.conf`):

```yaml
net:
  port: 27017
  bindIpAll: true
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mongod
```

## 2. Graylog Data Node

```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count = 262144" | sudo tee /etc/sysctl.d/99-graylog-datanode.conf

wget https://packages.graylog2.org/repo/packages/graylog-7.0-repository_latest.deb
sudo dpkg -i graylog-7.0-repository_latest.deb
sudo apt update
sudo apt install -y graylog-datanode
```

### Configuration remark — `password_secret`

The Data Node requires a `password_secret` value in `/etc/graylog/datanode/datanode.conf`, left blank by default. This value encrypts sensitive configuration data stored in MongoDB and **must be identical** to the one used in Graylog Server's configuration (see step 3).

```bash
pwgen -N 1 -s 96
```

```ini
# /etc/graylog/datanode/datanode.conf
password_secret = <generated-96-char-secret>
```

```bash
sudo systemctl enable --now graylog-datanode.service
```

## 3. Graylog Server

```bash
sudo apt install -y graylog-server
```

Configuration (`/etc/graylog/server/server.conf`):

```ini
password_secret = <same-96-char-secret-as-datanode>
root_timezone = <client-timezone>
http_bind_address = 0.0.0.0:9000
http_external_uri = http://siem-graylog.internal:9000/
mongodb_uri = mongodb://localhost:27017/graylog
```

**Configuration remark**: the `password_secret` value must match **exactly**, character for character, between `datanode.conf` and `server.conf`. A mismatch causes Graylog Server to fail its startup preflight check with `Invalid password_secret! Failed to decrypt values from MongoDB`, since the Data Node has already registered its own secret with MongoDB. Compare both files before starting the service if this error occurs:

```bash
sudo grep "^password_secret" /etc/graylog/datanode/datanode.conf
sudo grep "^password_secret" /etc/graylog/server/server.conf
```

```bash
sudo systemctl enable --now graylog-server.service
```

## 4. Initial setup

On first start, Graylog Server launches a preflight setup interface on port 9000, displaying a temporary admin username and password in the service logs:

```bash
sudo journalctl -u graylog-server -f
```

Complete the guided setup in the web interface — this step also finalizes the TLS certificate exchange between Graylog Server and the Data Node.

## Validation

```bash
sudo systemctl status mongod graylog-datanode graylog-server --no-pager
curl -k -I http://localhost:9000
```

A `200 OK` response (rather than `401` with `realm=preflight-config`) confirms Graylog Server has exited preflight mode and is running normally.

## NIS2 relevance

The `password_secret` mechanism underpins Graylog's at-rest encryption of sensitive configuration values in MongoDB, supporting **Article 21.2.i (cryptography)**.

## Outcome

MongoDB, Graylog Data Node, and Graylog Server operational and verified end to end.

---

**Previous phase**: [01 — Infrastructure Hardening](../01-infrastructure-hardening/)
**Next phase**: [03 — Wazuh Setup](../03-wazuh-setup/)
