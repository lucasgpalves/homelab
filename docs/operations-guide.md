# Homelab operations guide

[Português](guia-operacao.md) | **English**

Hands-on guide to bring up, maintain, and debug the environment.  
Complements `README.en.md` with day-to-day how-to.

---

## 1. Overview

```text
Client (Windows)
  DNS → Ubuntu IP (e.g. 10.1.1.10)
  Browser → https://*.homelab.local
        │
        ▼
Ubuntu
  dnsmasq (:53, host network) → *.homelab.local → LAN IP
  nginx (:80 redirect, :443 TLS) → containers on homelab-net
  db (Postgres) on gitea-net + zabbix-net
```

| Network | Used by | Purpose |
|---------|---------|---------|
| `homelab-net` | nginx + proxied apps | Internal HTTP/HTTPS traffic |
| `gitea-net` | `db` + `gitea` | Gitea Postgres |
| `zabbix-net` | `db` + zabbix + grafana | Zabbix Postgres |
| `drone-net` | drone-server + runner | Drone RPC |

**One Postgres, multiple databases:** `db` instance with `gitea` and `zabbix` users/DBs (script under `db/init/` on the first volume start).

---

## 2. Bootstrap

```bash
cd ~/projetos/homelab

cp dnsmasq/dnsmasq.conf.example dnsmasq/dnsmasq.conf
cp dnsmasq/dnsmasq.hosts.example dnsmasq/dnsmasq.hosts
cp db/.env.db.example db/.env
cp gitea/.env.gitea.example gitea/.env
cp zabbix/.env.zabbix.example zabbix/.env
cp grafana/.env.grafana.example grafana/.env
cp nginx/.env.nginx.example nginx/.env
cp drone/.env.drone.example drone/.env
cp semaphore/.env.semaphore.example semaphore/.env
```

Required edits:

1. `dnsmasq.conf` → `listen-address=<LAN_IP>`
2. `dnsmasq.hosts` → every line uses `<LAN_IP>`
3. `db/.env` aligned with `gitea/.env` and `zabbix/.env`
4. Gitea: `GITEA_DB_HOST=db:5432`
5. Zabbix: `ZABBIX_POSTGRES_HOST=db`
6. Nginx: `DNS_SERVER=127.0.0.11` (Docker DNS, **not** dnsmasq)

```bash
make up
```

> Postgres init runs only on the **first** creation of the `db-data` volume.

---

## 3. Makefile

| Command | Purpose |
|---------|---------|
| `make help` | List targets |
| `make networks` | Create external networks |
| `make check-env` | Validate `.env` files |
| `make tls-certs` | Generate mkcert CA/certs |
| `make up` / `down` / `restart` | Lifecycle |
| `make up-infra` / `up-apps` | Infra vs apps |
| `make ps` | Containers |
| `make logs STACK=zabbix` | Logs |
| `make gitea` (etc.) | Single stack |

---

## 4. DNS (dnsmasq)

### Conflict with systemd-resolved

Do not use `listen-address=0.0.0.0` — it clashes with `127.0.0.53:53`. Bind only to the LAN IP:

```conf
listen-address=10.1.1.10
bind-interfaces
```

Test on the server:

```bash
docker ps --filter name=dnsmasq
dig @10.1.1.10 gitea.homelab.local +short
```

### Windows

1. On the **connected** interface (Wi‑Fi if Ethernet is off): DNS = `LAN_IP`
2. Chrome → `chrome://settings/security` → **Use secure DNS** → Off
3. `ipconfig /flushdns`
4. `nslookup gitea.homelab.local LAN_IP`

Shortcut (`hosts` file):

```text
10.1.1.10  gitea.homelab.local
10.1.1.10  drone.homelab.local
10.1.1.10  zabbix.homelab.local
10.1.1.10  grafana.homelab.local
10.1.1.10  semaphore.homelab.local
```

---

## 5. TLS (mkcert + Nginx)

```bash
make tls-certs
cd nginx && docker compose up -d --force-recreate
```

| File | Use |
|------|-----|
| `nginx/certs/homelab.pem` | Site certificate |
| `nginx/certs/homelab-key.pem` | Private key |
| `nginx/certs/rootCA.pem` | Import on Windows |
| `nginx/certs/rootCA-key.pem` | CA key (server only) |

On Windows: install `rootCA.pem` under **Local Machine** → **Trusted Root Certification Authorities** → restart Chrome.

HTTP (80) redirects to HTTPS (443). Let’s Encrypt does not issue for `.local`.

With TLS for Drone: `DRONE_SERVER_PROTO=https` and `DRONE_SERVER_HOST=drone.homelab.local`.

---

## 6. New service (checklist)

1. Folder + `compose.yaml` (+ `.env.example`)
2. `homelab-net` if exposed via Nginx
3. Postgres: user/db in init or manual SQL + `db` network
4. Entry in `dnsmasq.hosts`
5. `nginx/conf.d/<service>.conf` (redirect + `proxy_pass`)
6. Recreate/reload dnsmasq and nginx
7. Add to the `Makefile` if you want automation

---

## 7. Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| `DNS_PROBE_FINISHED_NXDOMAIN` | Client not using dnsmasq / DoH | Fix NIC DNS; disable Secure DNS |
| `nslookup` timeout | dnsmasq down or wrong IP | `docker logs dnsmasq`; check `listen-address` |
| Certificate warning | CA not imported | Install `rootCA.pem` |
| App has no database | Init did not run / wrong network | `\l` in psql; `docker network inspect` |
| Nginx TLS fails to start | Missing certs | `make tls-certs` |

Debug order: **DNS → port/Nginx → upstream → app → TLS**.

---

## 8. Audit before GitHub

```bash
# No real .env should be tracked
git ls-files | grep -E '\.env$' || echo OK

# No certificates
git ls-files | grep -E '\.pem$' || echo OK

# Quick scan for literal passwords (adjust patterns as needed)
git grep -iE 'PASSWORD=.+' $(git rev-list --all) | grep -v '<change me>' | grep -v '\${'
```

If a secret **already** landed in history, rotate it on the service and scrub Git with `git filter-repo` (or BFG) **before** a public push — deleting it in a new commit alone does not remove it from history.
