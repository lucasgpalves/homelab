# Homelab

**Português** | [English](README.en.md)

Mini-servidor doméstico com **Ubuntu Server 24.04** em *mini-desktops* (i3-8100, 8 GB RAM, 256 GB SSD), orquestrado com Docker Compose.

Objetivo: praticar infraestrutura próxima de cenários reais — Git, CI/CD, observabilidade, DNS interno e proxy reverso — sem depender só de VMs.

---

## Stack

| Camada | Serviço | Função |
|--------|---------|--------|
| DNS | dnsmasq | Resolve `*.homelab.local` na LAN |
| Proxy | Nginx | Entrada HTTP→HTTPS (`:80` / `:443`) |
| TLS | mkcert | CA local + certificado `*.homelab.local` |
| Banco | PostgreSQL 15 | Instância única, DBs `gitea`, `zabbix` e `vaultwarden` |
| Git | Gitea | Repositórios |
| CI/CD | Drone | Pipelines integrados ao Gitea |
| Monitoramento | Zabbix + Grafana | Métricas e dashboards |
| Automação | Semaphore | Ansible (uso futuro) |
| Armazenamento de senhas | Vaultwarden | Armazenas credenciais de admin |

Redes Docker externas: `homelab-net`, `gitea-net`, `zabbix-net`.

---

## Início rápido

```bash
# Dependências
sudo apt install -y make   # opcional, mas recomendado
docker compose version

# Config local (não versionada)
cp dnsmasq/dnsmasq.conf.example dnsmasq/dnsmasq.conf
cp dnsmasq/dnsmasq.hosts.example dnsmasq/dnsmasq.hosts
cp db/.env.db.example db/.env
cp gitea/.env.gitea.example gitea/.env
cp zabbix/.env.zabbix.example zabbix/.env
cp grafana/.env.grafana.example grafana/.env
cp nginx/.env.nginx.example nginx/.env
cp drone/.env.drone.example drone/.env
cp semaphore/.env.semaphore.example semaphore/.env
cp vaultwarden/.env.vaultwarden.example vaultwarden/.env

# Ajuste IP da LAN em dnsmasq.conf / dnsmasq.hosts e as senhas nos .env

make up
```

Comandos úteis: `make help`, `make ps`, `make logs STACK=gitea`, `make tls-certs`, `make down`.

Guia completo (DNS no Windows, TLS, troubleshooting): **[docs/guia-operacao.md](docs/guia-operacao.md)** · [English](docs/operations-guide.md)

---

## Estrutura

```text
homelab/
├── Makefile
├── docs/        # Guias de operação (PT/EN)
├── db/          # Postgres compartilhado + init dos databases
├── dnsmasq/     # DNS da LAN
├── nginx/       # Proxy + TLS
├── gitea/
├── drone/
├── zabbix/
├── grafana/
├── semaphore/
└── vaultwarden/
```

Arquivos locais (ignorados pelo Git): `.env`, `dnsmasq.conf`, `dnsmasq.hosts`, `nginx/certs/`.

---

## Segurança do repositório

Antes de publicar no GitHub, confira:

- **Não** versionar `.env`, certificados (`.pem`) nem IPs/senhas reais
- Usar apenas os `*.example` com placeholders (`<change me>`)
- Após gerar TLS, importe `nginx/certs/rootCA.pem` só nas máquinas clientes — a chave da CA (`rootCA-key.pem`) permanece no servidor

Este repositório foi auditado para não conter senhas reais nos commits atuais. Veja notas no guia de operação se for necessário limpar histórico antigo (e-mails, IPs de exemplo).

---

## Aprendizados (resumo)

- **Zabbix + MySQL** foi instável neste setup; **PostgreSQL** é o caminho suportado.
- **dnsmasq** em `network_mode: host` precisa escutar só no IP da LAN para não conflitar com `systemd-resolved` (`127.0.0.53:53`).
- No Windows/Chrome, `DNS_PROBE_FINISHED_NXDOMAIN` quase sempre é DNS da placa errada ou **DNS seguro (DoH)** do Chrome — não é problema de certificado.
- **Let’s Encrypt** não emite para `.local`; mkcert resolve o cadeado em rede doméstica.

---

## Licença / uso

Projeto pessoal de laboratório. Adapte IPs, senhas e domínios antes de usar em qualquer ambiente compartilhado.
