# Homelab

[Português](README.md) | **English**

Home lab mini-server running **Ubuntu Server 24.04** on mini-desktops (i3-8100, 8 GB RAM, 256 GB SSD), orchestrated with Docker Compose.

Goal: practice near-real infrastructure — Git, CI/CD, observability, internal DNS, and reverse proxy — without relying only on VMs.

---

## Stack

| Layer | Service | Role |
|-------|---------|------|
| DNS | dnsmasq | Resolves `*.homelab.local` on the LAN |
| Proxy | Nginx | HTTP→HTTPS entrypoint (`:80` / `:443`) |
| TLS | mkcert | Local CA + `*.homelab.local` certificate |
| Database | PostgreSQL 15 | Single instance, `gitea` and `zabbix` DBs |
| Git | Gitea | Repositories |
| CI/CD | Drone | Pipelines integrated with Gitea |
| Monitoring | Zabbix + Grafana | Metrics and dashboards |
| Automation | Semaphore | Ansible (planned use) |

External Docker networks: `homelab-net`, `gitea-net`, `zabbix-net`.

---

## Quick start

```bash
# Dependencies
sudo apt install -y make   # optional, but recommended
docker compose version

# Local config (not tracked by Git)
cp dnsmasq/dnsmasq.conf.example dnsmasq/dnsmasq.conf
cp dnsmasq/dnsmasq.hosts.example dnsmasq/dnsmasq.hosts
cp db/.env.db.example db/.env
cp gitea/.env.gitea.example gitea/.env
cp zabbix/.env.zabbix.example zabbix/.env
cp grafana/.env.grafana.example grafana/.env
cp nginx/.env.nginx.example nginx/.env
cp drone/.env.drone.example drone/.env
cp semaphore/.env.semaphore.example semaphore/.env

# Set your LAN IP in dnsmasq.conf / dnsmasq.hosts and passwords in the .env files

make up
```

Useful commands: `make help`, `make ps`, `make logs STACK=gitea`, `make tls-certs`, `make down`.

Full guide (Windows DNS, TLS, troubleshooting): **[docs/operations-guide.md](docs/operations-guide.md)**

---

## Layout

```text
homelab/
├── Makefile
├── docs/        # Operations guides (PT/EN)
├── db/          # Shared Postgres + database init
├── dnsmasq/     # LAN DNS
├── nginx/       # Reverse proxy + TLS
├── gitea/
├── drone/
├── zabbix/
├── grafana/
└── semaphore/
```

Local files (gitignored): `.env`, `dnsmasq.conf`, `dnsmasq.hosts`, `nginx/certs/`.

---

## Repository security

Before publishing to GitHub, make sure you:

- **Do not** commit `.env` files, certificates (`.pem`), or real IPs/passwords
- Keep only `*.example` files with placeholders (`<change me>`)
- After generating TLS, import `nginx/certs/rootCA.pem` on client machines only — keep the CA key (`rootCA-key.pem`) on the server

This repository was checked so current commits do not contain real passwords. See the operations guide if you need to scrub older history (emails, sample IPs).

---

## Lessons learned (short)

- **Zabbix + MySQL** was unstable in this setup; **PostgreSQL** is the supported path.
- **dnsmasq** with `network_mode: host` should listen only on the LAN IP to avoid clashing with `systemd-resolved` (`127.0.0.53:53`).
- On Windows/Chrome, `DNS_PROBE_FINISHED_NXDOMAIN` is usually the wrong NIC DNS or Chrome **Secure DNS (DoH)** — not a certificate issue.
- **Let’s Encrypt** does not issue for `.local`; mkcert covers the padlock on a home network.

---

## License / usage

Personal lab project. Change IPs, passwords, and domains before using it in any shared environment.
