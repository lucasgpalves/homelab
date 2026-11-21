# Guia de operação do Homelab

**Português** | [English](operations-guide.md)

Documento prático para subir, manter e depurar o ambiente.  
Complementa o `README.md` com o “como fazer” do dia a dia.

---

## 1. Visão geral

```text
Cliente (Windows)
  DNS → IP do Ubuntu (ex.: 10.1.1.10)
  Browser → https://*.homelab.local
        │
        ▼
Ubuntu
  dnsmasq (:53, host network) → *.homelab.local → IP LAN
  nginx (:80 redirect, :443 TLS) → containers na homelab-net
  db (Postgres) nas redes gitea-net + zabbix-net
```

| Rede | Quem usa | Objetivo |
|------|----------|----------|
| `homelab-net` | nginx + apps via proxy | Tráfego HTTP/HTTPS interno |
| `gitea-net` | `db` + `gitea` | Postgres do Gitea |
| `zabbix-net` | `db` + zabbix + grafana | Postgres do Zabbix |
| `drone-net` | drone-server + runner | RPC do Drone |

**Um Postgres, vários databases:** instância `db` com users/DBs `gitea` e `zabbix` (script em `db/init/` na primeira subida do volume).

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

Ajustes obrigatórios:

1. `dnsmasq.conf` → `listen-address=<IP_LAN>`
2. `dnsmasq.hosts` → todas as linhas com `<IP_LAN>`
3. `db/.env` alinhado com `gitea/.env` e `zabbix/.env`
4. Gitea: `GITEA_DB_HOST=db:5432`
5. Zabbix: `ZABBIX_POSTGRES_HOST=db`
6. Nginx: `DNS_SERVER=127.0.0.11` (DNS do Docker, **não** o dnsmasq)

```bash
make up
```

> O init do Postgres só roda na **primeira** criação do volume `db-data`.

---

## 3. Makefile

| Comando | Função |
|---------|--------|
| `make help` | Lista alvos |
| `make networks` | Cria redes externas |
| `make check-env` | Valida `.env` |
| `make tls-certs` | Gera CA/certs mkcert |
| `make up` / `down` / `restart` | Ciclo de vida |
| `make up-infra` / `up-apps` | Infra vs apps |
| `make ps` | Containers |
| `make logs STACK=zabbix` | Logs |
| `make gitea` (etc.) | Stack isolado |

---

## 4. DNS (dnsmasq)

### Conflito com systemd-resolved

Não use `listen-address=0.0.0.0` — conflita com `127.0.0.53:53`. Escute só no IP da LAN:

```conf
listen-address=10.1.1.10
bind-interfaces
```

Teste no servidor:

```bash
docker ps --filter name=dnsmasq
dig @10.1.1.10 gitea.homelab.local +short
```

### Windows

1. Na interface **conectada** (Wi‑Fi se Ethernet estiver off): DNS = `IP_LAN`
2. Chrome → `chrome://settings/security` → **Usar DNS seguro** → Desativado
3. `ipconfig /flushdns`
4. `nslookup gitea.homelab.local IP_LAN`

Atalho (`hosts`):

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

| Arquivo | Uso |
|---------|-----|
| `nginx/certs/homelab.pem` | Cert do site |
| `nginx/certs/homelab-key.pem` | Chave |
| `nginx/certs/rootCA.pem` | Importar no Windows |
| `nginx/certs/rootCA-key.pem` | Chave da CA (só no servidor) |

No Windows: instalar `rootCA.pem` em **Máquina local** → **Autoridades de Certificação Raiz Confiáveis** → reiniciar o Chrome.

HTTP (80) redireciona para HTTPS (443). Let’s Encrypt não emite para `.local`.

Com TLS no Drone: `DRONE_SERVER_PROTO=https` e `DRONE_SERVER_HOST=drone.homelab.local`.

---

## 6. Novo serviço (checklist)

1. Pasta + `compose.yaml` (+ `.env.example`)
2. Rede `homelab-net` (se for via Nginx)
3. Postgres: user/db no init ou SQL manual + rede do `db`
4. Linha em `dnsmasq.hosts`
5. `nginx/conf.d/<servico>.conf` (redirect + `proxy_pass`)
6. Recriar/reload dnsmasq e nginx
7. Incluir no `Makefile` se quiser

---

## 7. Troubleshooting

| Sintoma | Causa comum | Ação |
|---------|-------------|------|
| `DNS_PROBE_FINISHED_NXDOMAIN` | Cliente não usa dnsmasq / DoH | DNS da placa + desligar DNS seguro |
| `nslookup` timeout | dnsmasq down ou IP errado | `docker logs dnsmasq`; conferir `listen-address` |
| Aviso de certificado | CA não importada | Instalar `rootCA.pem` |
| App sem banco | Init não rodou / rede | `\l` no psql; `docker network inspect` |
| Nginx não sobe TLS | Sem certs | `make tls-certs` |

Ordem de diagnóstico: **DNS → porta/Nginx → upstream → app → TLS**.

---

## 8. Auditoria antes do GitHub

```bash
# Nenhum .env real deve aparecer
git ls-files | grep -E '\.env$' || echo OK

# Nenhum certificado
git ls-files | grep -E '\.pem$' || echo OK

# Busca rápida por senhas literais (ajuste os padrões)
git grep -iE 'PASSWORD=.+' $(git rev-list --all) | grep -v '<change me>' | grep -v '\${'
```

Se um segredo **já** entrou no histórico, troque a senha no serviço e limpe o Git com `git filter-repo` (ou BFG) **antes** do push público — só apagar no commit novo não remove do histórico.
